local discordia = require 'discordia'
local client = discordia.Client()

local config = require './config.lua'
local ut = require './utils.lua'
local judge = require './judge.lua'

client:on(
	'ready',
	function()
		local nerr, yomi =
			pcall(
			function()
				local msg =
					client:getChannel(config.reactChannels[1]):getMessages():toArray(
					'createdAt',
					function(msg)
						return msg.author.id == '522728315824635906' and msg.content:match('%[')
					end
				)
				return table.remove(msg).content:match('%[(.*)%]')
			end
		)
		if nerr then
			print(yomi)
			judge.setWord(yomi)
		end
	end
)

client:on(
	'messageCreate',
	function(message)
		-- 対象チャンネルでなければ、さよなら
		local outOfKaya =
			not ut.includes(
			config.reactChannels,
			function(itm)
				return '<#' .. itm .. '>' == message.channel.mentionString
			end
		)
		-- Bot の発言と他チャンネルはさよなら
		if outOfKaya or message.author.bot or #message.mentionedUsers ~= 0 or #message.mentionedChannels ~= 0  then
			return
		end

		local content = ut.preprocess(message.content)

		if not content then
			return
		end

		message.channel:broadcastTyping()

		local reply, unchik = judge.judge(content)

		if reply then
			if unchik then
				reply = reply .. '\n' .. unchik
			end
			message:reply(reply)
		end
	end
)

client:run('Bot ' .. config.discordBotToken)
