local discordia = require 'discordia'
local client = discordia.Client()

local lastword, wordlist = '', {}

local comboLtr, comboLng = {times = 0, letter = ''}, {times = 0, length = 0}
local shibariLtrEndTime, shibariLngEndTime = 0, 0

local config = require './config.lua'
local ut = require './utils.lua'

client:on(
	'messageCreate',
	function(message)
		local minutes = 60
		local content = message.content:gsub('[0-9!-~]', '')

		-- 対象チャンネルでなければ、さよなら
		local outOfKaya =
			not ut.includes(
			config.reactChannels,
			function(itm)
				return '<#' .. itm .. '>' == message.channel.mentionString
			end
		)
		-- Bot の発言と空メッセージはさよなら
		if outOfKaya or message.author.bot or #content == 0 or #message.mentionedUsers ~= 0 or #message.mentionedChannels then
			return
		end

		message.channel:broadcastTyping()

		local hiragana, words, processed, suffix, yomilen = ut.process(content)
		local prefix = processed:sub(1, #lastword)

		-- 文節数が多いのはダメ
		if words >= config.maxwords then
			message.channel:send '長すぎです。'
			return
		end

		-- しりとりになっていなければダメ
		if #lastword ~= 0 and lastword ~= prefix then
			message.channel:send(hiragana .. '。[' .. lastword .. '] から始めてくださいよ。')
			return
		end

		-- 文字縛り
		if shibariLtrEndTime > os.time() and prefix ~= suffix then
			message.channel:send(
				'[' .. comboLtr.letter .. '] 縛り持続中！残' .. tostring(math.ceil((shibariLtrEndTime - os.time()) / minutes)) .. '分'
			)
			return
		end
		-- 音数縛り
		if shibariLngEndTime > os.time() and comboLng.length ~= yomilen then
			message.channel:send(
				tostring(comboLng.length) ..
					'音縛り持続中！' ..
						hiragana ..
							'は' .. tostring(yomilen) .. '音です。残' .. tostring(math.ceil((shibariLngEndTime - os.time()) / minutes)) .. '分'
			)
			return
		end

		-- 既出語はダメ
		if ut.includes(wordlist, hiragana) then
			message.channel:send '残念、もう出てます。'
			return
		end
		table.insert(wordlist, hiragana)
		if #wordlist > config.historyLength then
			table.remove(wordlist, 1)
		end

		lastword = suffix

		-- 文字コンボ判定
		if comboLtr.letter == suffix then
			comboLtr.times = comboLtr.times + 1
			suffix = suffix .. ' (' .. tostring(comboLtr.times + 1) .. ')'

			if comboLtr.times == config.shibariThreshold and shibariLngEndTime <= os.time() then
				shibariLtrEndTime = os.time() + config.shibariLasts * minutes
				message.channel:send('[' .. lastword .. '] 縛り発動！残' .. tostring(config.shibariLasts) .. '分')
			end
		else
			comboLtr.times, comboLtr.letter = 0, suffix
		end

		-- 音数コンボ判定
		if comboLng.length == yomilen then
			comboLng.times = comboLng.times + 1

			if comboLng.times == config.shibariThreshold and shibariLtrEndTime <= os.time() then
				shibariLngEndTime = os.time() + config.shibariLasts * minutes
				message.channel:send(tostring(yomilen) .. '音縛り発動！残' .. tostring(config.shibariLasts) .. '分')
			end
		else
			comboLng.times, comboLng.length = 0, yomilen
		end

		-- 無事受理されました
		local msg = message.channel:send(hiragana .. ' = ' .. tostring(yomilen) .. '音 [' .. suffix .. ']')
		print(msg)
	end
)

client:run('Bot ' .. config.discordBotToken)
