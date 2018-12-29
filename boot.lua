local discordia = require 'discordia'
local client = discordia.Client()

local config = require './config.lua'
local ut = require './utils.lua'
local judge = require './judge.lua'

local msg

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
		-- 数字はダメ、コメントも反応しない
		local content = message.content:gsub('[0-9]', ''):gsub('//.*', '')

		-- 対象チャンネルでなければ、さよなら
		local outOfKaya =
			not ut.includes(
			config.reactChannels,
			function(itm)
				return '<#' .. itm .. '>' == message.channel.mentionString
			end
		)
		-- Bot の発言と他チャンネルはさよなら
		if outOfKaya or message.author.bot then
			return
		end

		if #content == 0 or #message.mentionedUsers ~= 0 or #message.mentionedChannels ~= 0 then
			return
		end

		-- 絵文字が入ってたら論外
		if message.content:match '\xf0' then
			return
		end

		message.channel:broadcastTyping()

		local reply, unchik = judge.judge(content)

		if reply then
			if msg then
				msg:delete()
			end
			msg = message:reply(reply)
			if unchik then
				message:reply(unchik)
			end
		end
	end
)

client:run('Bot ' .. config.discordBotToken)
