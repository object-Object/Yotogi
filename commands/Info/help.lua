local discordia = require("discordia")
local commandHandler = require("commandHandler")
local utils = require("miscUtils")

local function appendSubcommands(str, indent, command)
	for subcommandString, subcommand in pairs(command.subcommands) do
		str = str..indent..subcommandString.."\n"
		str = appendSubcommands(str, indent.."  ", subcommand)
	end
	return str
end

local function showMainHelp(message, guildSettings, showSubcommands)
	local fields = {}
	for _, categoryString in ipairs(commandHandler.sortedCategoryNames) do
		local category = commandHandler.sortedCommandNames[categoryString]
		if not categoryString:match("^%.") then
			local output = "```\n"
			for _, commandString in ipairs(category) do
				local command = commandHandler.commands[commandString]
				if command.visible and not guildSettings.disabled_commands[commandString] then
					output = output..guildSettings.prefix..commandString.."\n"
					if showSubcommands then
						output = appendSubcommands(output, "  ", command)
					end
				end
			end
			if output~="```\n" then
				output = output:gsub("\n$","").."```"
				table.insert(fields, {name = categoryString, value = output})
			end
		end
	end
	message.channel:send{
		embed = {
			title = "Help Menu"..(showSubcommands and " + Subcommands" or ""),
			fields = fields,
			color = discordia.Color.fromHex("00ff00").value,
			footer = {
				text = "Do "..guildSettings.prefix.."help [command] for more info on a command."
			}
		}
	}
end

return {
	name = "help", -- name of the command and what users type to use it
	description = "Show the help menu or info for a command.", -- description for help command
	usage = "help [command]", -- usage for help command and errors
	visible = true, -- whether or not this command shows up in help and is togglable by users
	permissions = {}, -- required permissions to use the command
	run = function(self, message, argString, args, guildSettings, lang, conn) -- function called when the command is used
		if argString=="" then
			-- show normal help menu
			showMainHelp(message, guildSettings, false)
		else
			-- show command-specific help
			local baseCommandString = commandHandler.stripPrefix(args[1], guildSettings, message.client)
			local command = commandHandler.commands[baseCommandString]
			if command and command.visible then
				command = commandHandler.subcommandFromString(command, args)
				commandHandler.sendCommandHelp(message.channel, guildSettings, command)
			else
				-- command not found
				showMainHelp(message, guildSettings, false)
			end
		end
	end,
	onEnable = function(self, message, guildSettings) -- function called when this command is enabled, return true if enabling can proceed
		return true
	end,
	onDisable = function(self, message, guildSettings) -- function called when this command is disabled, return true if disabling can proceed
		return true
	end,
	subcommands = {

		subcommands = {
			name = "help subcommands",
			description = "Show the help menu with the subcommands for each command listed.",
			usage = "help subcommands",
			run = function(self, message, argString, args, guildSettings, lang, conn)
				showMainHelp(message, guildSettings, true)
			end,
			subcommands = {}
		}

	}
}