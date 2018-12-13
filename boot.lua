local discordia = require 'discordia'
local client = discordia.Client()

local json = require 'json'
local http = require 'coro-http'

local lastword, lastcount = '', 0
local wordlist = {}

dofile './config.lua'

client:on('ready', function()
	print(client.user.username)
end)

local function yomiOf(kanji)
	local res, body = http.request(
		'POST',
		'https://labs.goo.ne.jp/api/hiragana',
		{
			{ 'Content-Type', 'application/json' }
		},
		json.encode {
			app_id = yomiApiId,
			sentence = kanji,
			output_type = 'hiragana'
		}
	)
	local hiragana = json.decode(body)
	return hiragana.converted
end

client:on('messageCreate', function(message)
	local outOfKaya = true
	for i, str in ipairs(reactChannels) do
		if '<#'..str..'>' == message.channel.mentionString then
			outOfKaya = false
			break
		end
	end
	if outOfKaya or message.author.bot then
		return
	end

	local hiragana, words = yomiOf(message.content):gsub('[!-~]', ''):gsub(' ','')
	local processed = hiragana:gsub('ー', '')
	local count = -3

	for i, str in ipairs {'ゃ', 'ゅ', 'ょ', 'っ', 'ぁ', 'ぃ', 'ぅ', 'ぇ', 'ぉ'} do
		if processed:find(str, -3) then
			count = -6
			break
		end
	end
	if words > 1 then
		message.channel:send '長すぎです。'
	else
		if lastcount == 0 or lastword == processed:sub(1, -lastcount) then
			for i, str in ipairs(wordlist) do
				if str == hiragana then
					message.channel:send '残念、もう出てます。'
					return
				end
			end
			table.insert(wordlist, hiragana)
			if #wordlist > 100 then
				table.remove(wordlist, 1)
			end

			lastword, lastcount = processed:sub(count), count
			message.channel:send(hiragana..' ['..lastword..']')
		else
			message.channel:send(hiragana..'。['..lastword..'] から始めてくださいよ。')
		end
	end
end)

client:run('Bot ' .. discordBotToken)
