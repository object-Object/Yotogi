local utils = require("miscUtils")
local muteUtils = require("muteUtils")
local commandHandler = require("commandHandler")

return {
	name = "mute-manager-join",
	visible = false,
	disabledByDefault = false,
	run = function(self, guildSettings, lang, muteMember, conn)
		local entry, _ = conn:exec('SELECT * FROM mutes WHERE guild_id = "'..muteMember.guild.id..'" AND user_id = "'..muteMember.id..'";')
		if not entry then return end
		entry = utils.formatRow(entry)

		local muteUser = muteMember.user
		local name = utils.name(muteUser, muteMember.guild)

		local publicLogChannel = guildSettings.public_log_channel and muteMember.guild:getChannel(guildSettings.public_log_channel)
		local staffLogChannel = guildSettings.staff_log_channel and muteMember.guild:getChannel(guildSettings.staff_log_channel)

		local valid, reasonInvalid, mutedRole = muteUtils.checkValidMute(muteMember, muteUser, muteMember.guild, guildSettings, lang)
		if not valid then
			local text = f(lang.error.remute_fail, name, reasonInvalid)
			utils.sendEmbedSafe(publicLogChannel, text, "ff0000")
			utils.sendEmbedSafe(staffLogChannel, text, "ff0000")
			muteUtils.deleteEntry(muteMember.guild, muteUser, conn)
			return
		end

		local muteFooter = commandHandler.strings.muteFooter(guildSettings, lang, entry.length, os.time()+entry.length, true)

		local mutedDM = utils.sendEmbed(muteUser:getPrivateChannel(), f(lang.mute.you_remuted, muteMember.guild.name), "ffff00", muteFooter)
		local success, err = muteUtils.remute(muteMember, muteUser, mutedRole, muteMember.guild, conn, entry.length)
		if not success then
			if mutedDM then mutedDM:delete() end
			local text = f(lang.error.remute_fail, name, "`"..err.."`").." "..lang.error.report_error
			utils.sendEmbedSafe(publicLogChannel, text, "ff0000")
			utils.sendEmbedSafe(staffLogChannel, text, "ff0000")
			return
		end
		local text = f(lang.mute.user_remuted, name)
		utils.sendEmbedSafe(publicLogChannel, text, "ffff00", muteFooter)
		utils.sendEmbedSafe(staffLogChannel, text, "ffff00", muteFooter)
	end,
	onEnable = function(self, message, guildSettings, conn)
		return true
	end,
	onDisable = function(self, message, guildSettings, conn)
		return true
	end
}