local json = require 'json'
local http = require 'coro-http'

local config = require './config.lua'

local _M = {}

--- obj の中に fn に一致するものがあるかどうか調べる
-- @param obj テーブル
-- @param fn チェック関数
-- @param fn 比較対象
-- @return 見つかれば true、見つからなければ false
function _M.includes(obj, fn)
	for _, itm in ipairs(obj) do
		if (type(fn) == 'function' and fn(itm)) or (itm == fn) then
			return true
		end
	end
	return false
end

--- 文字列のよみを取得する
-- @param kanji 文字列
-- @return よみ
function _M.yomiOf(kanji)
	local hiragana
	while true do
		local _, body =
			http.request(
			'POST',
			'https://labs.goo.ne.jp/api/hiragana',
			{
				{'Content-Type', 'application/json'}
			},
			json.encode {
				app_id = config.yomiApiId,
				sentence = kanji,
				output_type = 'hiragana'
			}
		)
		hiragana = json.decode(body)

		-- API からレスポンスがなければ、2秒待って再試行する
		if type(hiragana.converted) ~= 'string' then
			rt.sleep(2)
		else
			break
		end
	end
	return hiragana.converted
end

--- 文字列をよみに変換し、しりとりで使用できるように処理する
-- @param kanji 入力文字列
-- @return よみ
-- @return 文節数 - 1
-- @return しりとり処理用文字列
-- @return 最後の音
-- @return よみの音数
function _M.process(kanji)
	local hiragana, words = _M.yomiOf(kanji):gsub(' ', '')
	local hiraganar = {
		'[!-~]',
		'「',
		'」',
		'！',
		'？',
		'｛',
		'｝',
		'＿',
		'＊',
		'％',
		'。',
		'、',
		'｜',
		'＝',
		'＜',
		'＞',
		'＾',
		'～',
		'￥',
		'＋',
		'・',
		'；',
		'：',
		'…',
		'‥',
		'（',
		'）',
		'’'
	}

	-- 記号を除く
	for _, str in ipairs(hiraganar) do
		hiragana = hiragana:gsub(str, '')
	end

	local processed = hiragana:gsub('ー', '')
	local count = -3
	local yomiLen = math.floor(#hiragana / 3)
	local smallLtr = {'ゃ', 'ゅ', 'ょ', 'っ', 'ぁ', 'ぃ', 'ぅ', 'ぇ', 'ぉ'}

	-- 最終音は何バイトか？
	if
		_M.includes(
			smallLtr,
			function(itm)
				return processed:find(itm, -5) ~= nil
			end
		)
	 then
		count = -6
	end

	-- 「っ」は1音としてカウントする
	table.remove(smallLtr, 4)

	-- 「っ」以外は0音としてカウントする
	for _, ltr in ipairs(smallLtr) do
		local _, occurrences = hiragana:gsub(ltr, '')
		yomiLen = yomiLen - occurrences
	end

	print(kanji, hiragana, processed, yomiLen)

	return hiragana, words, processed, processed:sub(count), yomiLen
end

return _M
