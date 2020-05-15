-- custom string.format function that handles the parameter field (https://en.wikipedia.org/wiki/Printf_format_string#Parameter_field)
_G.f = function(str, ...)
	local args, order = {...}, {}

	str = str:gsub("%%(%d+)%$", function(i)
		table.insert(order, args[tonumber(i)])
		return "%"
	end)

	return str:format(table.unpack(order))
end

local discordia = require("discordia")
local http = require("coro-http")
local timer = require("timer")
local json = require("json")
local utils = require("miscUtils")
local sql = require("sqlite3")
local fs = require("fs")
local options = require("options")
discordia.storage.options = options

local conn = sql.open("yot.db")

discordia.storage.langs = {}
for _, filename in ipairs(fs.readdirSync("lang")) do
	if filename:match("%.json$") then
		local lang = json.decode(fs.readFileSync("lang/"..filename))
		lang.pl = function(entry, num)
			assert(entry.default~=nil, "entry has no default value")
			num = tostring(num)
			return entry[num] or entry.default
		end
		discordia.storage.langs[filename:gsub("%.json","")] = lang
	end
end
local defaultLang = discordia.storage.langs[options.defaultLanguage]

local client = discordia.Client(options.clientOptions)
local clock = discordia.Clock()
discordia.extensions()

local commandHandler = require("commandHandler")
commandHandler.load()
local moduleHandler = require("moduleHandler")
moduleHandler.load()

local statusVersion
local function setGame()
	local changelog = fs.readFileSync("changelog.txt")
	local version = changelog and changelog:match("%*%*([^%*]+)%*%*") or "error"
	if version~=statusVersion then
		statusVersion = version
		client:setGame({name=options.defaultPrefix.."help | "..version, url="https://www.twitch.tv/ThisIsAFakeTwitchLink"})
	end
end

local function setupGuild(id)
	local disabledModules = {}
	for modName, mod in pairs(moduleHandler.modules) do
		if mod.disabledByDefault then
			disabledModules[modName] = true
		end
	end
	local disabledModulesStr = json.encode(disabledModules)
	conn:exec("INSERT INTO guild_settings (guild_id, disabled_modules) VALUES ('"..id.."', '"..disabledModulesStr.."')")
end

local function doModulesPcall(event, guild, conn, ...)
	local success, err = pcall(function(...)
		local guildSettings = utils.getGuildSettings(guild.id, conn)
		if not guildSettings then
			setupGuild(guild.id)
			guildSettings = utils.getGuildSettings(guild.id, conn)
		end
		moduleHandler.doModules(event, guildSettings, ...)
	end, ...)
	if not success then
		utils.logError(guild, defaultLang, err)
		print(defaultLang.error.bot_crashed.." "..f(defaultLang.g.guild_str, guild.name, guild.id).."\n"..err)
	end
end

clock:on("min", function()
	for guild in client.guilds:iter() do
		doModulesPcall(moduleHandler.tree.clock.min, guild, conn, guild, conn)
	end
	setGame()
end)

client:on("ready", function()
	setGame()
end)

client:on("guildCreate", function(guild)
	if not utils.getGuildSettings(guild.id, conn) then
		setupGuild(guild.id)
	end
end)

client:on("memberJoin", function(member)
	doModulesPcall(moduleHandler.tree.client.memberJoin, member.guild, conn, member, conn)
end)

client:on("memberLeave", function(member)
	doModulesPcall(moduleHandler.tree.client.memberLeave, member.guild, conn, member, conn)
end)

client:on("userBan", function(user, guild)
	doModulesPcall(moduleHandler.tree.client.userBan, guild, conn, user, guild, conn)
end)

client:on("messageCreate", function(message)
	local success, err = pcall(function()
		if message.author.bot then return end
		if message.channel.type == discordia.enums.channelType.private then
			local dmLogChannel = client:getChannel(options.dmLogChannel)
			if not dmLogChannel then return end
			utils.sendEmbed(message.channel, defaultLang.dm.message_forwarded, "00ff00")
			utils.sendEmbed(dmLogChannel, "**"..f(defaultLang.dm.from, message.author.tag).."**", "00ff00", f(defaultLang.g.user_id, message.author.id))
			dmLogChannel:send(message)
			return
		end
		if not message.guild then return end
		local guildSettings = utils.getGuildSettings(message.guild.id, conn)
		if not guildSettings then
			setupGuild(message.guild.id)
			guildSettings = utils.getGuildSettings(message.guild.id, conn)
		end

		local lang = discordia.storage.langs[guildSettings.language]

		moduleHandler.doModules(moduleHandler.tree.client.messageCreate, guildSettings, lang, message, conn)

		commandHandler.doCommands(message, guildSettings, lang, conn)
	end)
	if not success then
		utils.logError(message.guild, defaultLang, err)
		print(defaultLang.error.bot_crashed.." "..f(defaultLang.g.guild_str, message.guild.name, message.guild.id).."\n"..err)
	end
end)

client:on("messageUpdate", function(message)
	if not message.guild then return end
	doModulesPcall(moduleHandler.tree.client.messageUpdate, message.guild, conn, message, conn)
end)

client:on("messageDelete", function(message)
	if not message.guild then return end
	doModulesPcall(moduleHandler.tree.client.messageDelete, message.guild, conn, message, conn)
end)

clock:start()
client:run("Bot "..options.token)