local json = require 'json'
local http = require 'coro-http'

local config = require './config.lua'

local _M = {}

function _M:includes(obj, fn)
	for i, itm in ipairs(obj) do
		if ( type(fn) == 'function' and fn(itm) ) or ( itm == fn) then
			return true
		end
		return false
	end
end

function _M:yomiOf(kanji)
	local res, body = http.request(
		'POST',
		'https://labs.goo.ne.jp/api/hiragana',
		{
			{ 'Content-Type', 'application/json' }
		},
		json.encode {
			app_id = config.yomiApiId,
			sentence = kanji,
			output_type = 'hiragana'
		}
	)
	local hiragana = json.decode(body)
	return hiragana.converted
end

function _M:process(kanji)
	print(kanji)
	local hiragana, words = self:yomiOf(kanji):gsub('[!-~]', ''):gsub(' ','')
	local processed = hiragana:gsub('ー', '')
	local count = -3
	local yomiLen = #hiragana
	local smallLtr = {'ゃ', 'ゅ', 'ょ', 'っ', 'ぁ', 'ぃ', 'ぅ', 'ぇ', 'ぉ'}

	if
	self:includes(smallLtr,	function(itm)
		return processed:find(itm, -3) ~= nil
	end)
	then
		count = -6
	end

	table.remove(smallLtr, 4)

	for i, ltr in ipairs(smallLtr) do
		local _, occurrences = hiragana:gsub(ltr, '')
		yomiLen = yomiLen - occurrences
	end

	return hiragana, words, processed, processed:sub(count), yomiLen
end

return _M