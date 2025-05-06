local json = require 'json'
local http = require 'coro-http'

local config = require './config.lua'
local ut = require './utils.lua'

local _M = {}

local lastWord, wordList = '', {}
local testing = false

local comboLtr, comboLng = { times = 0, letter = '' }, { times = 0, length = 0 }
local shibariLtrEndTime, shibariLngEndTime = 0, 0

function _M.setWord(yomi)
    lastWord = yomi
end

function _M.getWord()
    return lastWord
end

function _M.test()
    testing = true
end

local function debug(...)
    if not testing then
        print(...)
    end
end

local function yomiOf(kanji)
    local hiragana = ''
    local result
    local retry = 1
    while true do
        local _, body =
            http.request(
                'POST',
                'https://jlp.yahooapis.jp/FuriganaService/V2/furigana',
                {
                    { 'Content-Type', 'application/json' },
                    { 'User-Agent',   'Yahoo AppID: ' .. config.yomiApiId }
                },
                json.encode {
                    id = 'shiritolua',
                    jsonrpc = '2.0',
                    method = 'jlp.furiganaservice.furigana',
                    params = {
                        q = kanji,
                        grade = 1,
                    }
                }
            )
        result = json.decode(body)

        if result and  type(result.jsonrpc) ~= 'string' then
            rt.sleep(retry)
            retry = retry * 2
        else
            break
        end
    end

    -- result.result.word をなめる
    for _, word in ipairs(result.result.word) do
        if type(word.furigana) == 'string' then
            hiragana = hiragana .. word.furigana
        elseif type(word.surface) == 'string' then
            hiragana = hiragana .. word.surface
        end
    end

    return hiragana
end

local function encode(string)
    local ret = ''
    string = tostring(string)
    for i = 1, #string do
        local char = string:byte(i)
        if char > 0x7f then
            ret = ret .. string.format('%%%X', char)
        else
            ret = ret .. string.char(char)
        end
    end
    return ret
end

local function buildGetUrl(url, query)
    if not query then
        return url
    end
    url = url .. '?'
    for key, val in pairs(query) do
        url = url .. '&' .. key .. '=' .. encode(val)
    end
    return url:gsub('?&', '?')
end

local function inDic(string)
    local head =
        http.request(
            'GET',
            'https://www.weblio.jp/content/' .. string,
            {
                { 'content-type', 'text/xml' }
            }
        )
    return head.code == 200
end

local function seekWiki(title)
    local _, body =
        http.request(
            'GET',
            buildGetUrl(
                'https://ja.wikipedia.org/w/api.php',
                {
                    action = 'query',
                    format = 'json',
                    list = 'search',
                    utf8 = 1,
                    srsearch = '"' .. title .. '"',
                    srlimit = 1,
                    srsort = 'just_match',
                    redirects = 1
                }
            ),
            {}
        )
    local res = json.decode(body).query
    if res.searchinfo.totalhits > 0 then
        return res.search[1].snippet:gsub('<[^>]*>', ''):gsub('。.*', '。'):gsub(
                title,
                '**' .. title .. '**'
            ) ..
            ' - ' .. res.search[1].title
    else
        return false
    end
end

function _M.process(kanji)
    local dicres = seekWiki(kanji)
    if not inDic(kanji) then
        return false
    end
    local hiragana = yomiOf(kanji)
    local hiraganar = {
        '[!-~]',
        '\xe3\x82[\x97-\x9f]', -- 平仮名特殊記号 ゛ など
        '・',
        ' ',
        '\xe3\x83[\xbd-\xbf]' -- カタカナ特殊記号
    }
    -- 記号を除く
    for _, str in ipairs(hiraganar) do
        hiragana = hiragana:gsub(str, '')
    end
    local resh = ''
    for i = 1, #hiragana do
        local mt = hiragana:sub(i, i + 2):match '\xe3[\x81-\x83][\x80-\xbf]'
        if mt then
            resh = resh .. mt
        end
    end

    local processed = resh:gsub('ー', '')
    local count, yomiLen = -3, math.floor(#resh / 3)
    local smallLtr = { 'ゃ', 'ゅ', 'ょ', 'っ', 'ぁ', 'ぃ', 'ぅ', 'ぇ', 'ぉ' }

    -- 最終音は何バイトか？
    if
        ut.includes(
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
        local _, occurrences = resh:gsub(ltr, '')
        yomiLen = yomiLen - occurrences
    end

    debug(kanji, hiragana, processed, yomiLen)

    return resh, processed, processed:sub(count), yomiLen, dicres
end

function _M.judge(content)
    local hiragana, processed, suffix, yomilen, unchik = _M.process(content)
    if hiragana == false then
        return '我輩の辞書に「' .. content .. '」はありません。[' .. lastWord .. ']'
    end

    local prefix = processed:sub(1, #lastWord)
    local function timeDiff(time)
        return math.ceil((time - os.time()) / 60)
    end

    local judgments = {
        {
            cond = suffix == 'ん',
            ret = 'んで終わっています。'
        },
        {
            cond = #lastWord ~= 0 and lastWord ~= prefix,
            ret = hiragana .. '。しりとりじゃないじゃん。'
        },
        {
            cond = shibariLtrEndTime > os.time() and lastWord ~= prefix and
                comboLtr.times < config.shibaredMessages,
            ret = '[' ..
                comboLtr.letter ..
                '] 縛り！残' .. timeDiff(shibariLtrEndTime) .. '分'
        },
        {
            cond = shibariLngEndTime > os.time() and comboLng.length ~= yomilen and
                comboLng.times < config.shibaredMessages,
            ret = comboLng.length ..
                '音縛り！' ..
                hiragana ..
                '=' ..
                yomilen ..
                '音。残' .. timeDiff(shibariLngEndTime) .. '分'
        },
        {
            cond = ut.includes(wordList, hiragana),
            ret = '残念、もう出てます。'
        }
    }

    for _, cd in ipairs(judgments) do
        if cd.cond then
            return cd.ret .. '[' .. lastWord .. ']'
        end
    end

    table.insert(wordList, hiragana)
    if #wordList > config.historyLength then
        table.remove(wordList, 1)
    end

    lastWord = suffix
    local ret = ''

    -- 文字コンボ判定
    if comboLtr.letter == suffix then
        comboLtr.times = comboLtr.times + 1
        suffix = suffix .. ' (' .. suffix .. comboLtr.times + 1 .. ')'
        if
            comboLtr.times == config.shibariThreshold and
            shibariLngEndTime <= os.time()
        then
            shibariLtrEndTime = os.time() + config.shibariLasts * 60
            ret =
                ret ..
                '[' ..
                lastWord ..
                '] 縛り発動！残' .. tostring(config.shibariLasts) .. '分\n'
        end
    else
        comboLtr.times, comboLtr.letter = 0, suffix
    end

    -- 音数コンボ判定
    if comboLng.length == yomilen then
        comboLng.times = comboLng.times + 1
        suffix = suffix .. ' <' .. yomilen .. '音>'
        if
            comboLng.times == config.shibariThreshold and
            shibariLtrEndTime <= os.time()
        then
            shibariLngEndTime = os.time() + config.shibariLasts * 60
            ret =
                ret ..
                yomilen .. '音縛り発動！残' .. tostring(config.shibariLasts) .. '分\n'
        end
    else
        comboLng.times, comboLng.length = 0, yomilen
    end

    -- 無事受理されました
    return ret .. hiragana .. ' [' .. suffix .. ']', unchik
end

return _M
