local discordia = require 'discordia'
local client = discordia.Client()

local json = require 'json'
local http = require 'coro-http'

local lastword, wordlist = '', {}

local comboLtr, comboLng = { times = 0, letter = '' }, { times = 0, length = 0 }
local shibariLtrEndTime, shibariLngEndTime = 0, 0

local config = require './config.lua'
local ut = require './utils.lua'

if not os.getenv 'USER' then
	print 'Starting server'
	http.createServer('0.0.0.0', os.getenv 'PORT' + 0)
end

client:on('ready', function()
	print(client.user.username)
end)

client:on('messageCreate', function(message)
	local minutes = 60
	local outOfKaya = not ut:includes(config.reactChannels, function(itm)
		return '<#'..itm..'>' == message.channel.mentionString
	end)
	if outOfKaya or message.author.bot then
		return
	end

	local hiragana, words, processed, suffix, yomilen = ut:process(message.content)
	local prefix = processed:sub(1, #lastword)

	if words >= config.maxwords then
		message.channel:send '長すぎです。'
		return
	end

	if #lastword ~= 0 and lastword ~= prefix then
		message.channel:send(hiragana..'。['..lastword..'] から始めてくださいよ。')
		return
	end

	if shibariLtrEndTime > os.time() and prefix ~= suffix then
		message.channel:send('['..comboLtr.letter..'] 縛り持続中！残'..tostring(math.ceil((shibariLtrEndTime - os.time()) / minutes))..'分')
		return
	end
	if shibariLngEndTime > os.time() and comboLng.length ~= yomilen then
		message.channel:send(tostring(comboLng.length)..'音縛り持続中！'..hiragana..'は'..tostring(yomilen)..'音です。残'..tostring(math.ceil((shibariLngEndTime - os.time()) / minutes))..'分')
		return
	end

	if ut:includes(wordlist, hiragana) then
		message.channel:send '残念、もう出てます。'
		return
	end
	table.insert(wordlist, hiragana)
	if #wordlist > config.historyLength then
		table.remove(wordlist, 1)
	end

	lastword = suffix

	if comboLtr.letter == suffix then
		comboLtr.times = comboLtr.times + 1
		suffix = suffix .. ' (' .. tostring(comboLtr.times + 1) .. ')'

		if comboLtr.times == config.shibariThreshold and shibariLngEndTime <= os.time() then
			shibariLtrEndTime = os.time() + config.shibariLasts * minutes
			message.channel:send('['..lastword..'] 縛り発動！残'..tostring(config.shibariLasts)..'分')
		end
	else
		comboLtr.times, comboLtr.letter = 0, suffix
	end

	if comboLng.length == yomilen then
		comboLng.times = comboLng.times + 1

		if comboLng.times == config.shibariThreshold and shibariLtrEndTime <= os.time() then
			shibariLngEndTime = os.time() + config.shibariLasts * minutes
			message.channel:send(tostring(yomilen)..'音縛り発動！残'..tostring(config.shibariLasts)..'分')
		end
	else
		comboLng.times, comboLng.length = 0, yomilen
	end

	message.channel:send(hiragana.. ' = ' .. tostring(yomilen)..'音 ['..suffix..']')
end)

client:run('Bot ' .. config.discordBotToken)