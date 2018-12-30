local json = require 'json'
local http = require 'coro-http'

local config = require './config.lua'
local ut = require './utils.lua'

local _M = {}

local lastword, wordlist = '', {}
local testing = false

local comboLtr, comboLng = {times = 0, letter = ''}, {times = 0, length = 0}
local shibariLtrEndTime, shibariLngEndTime = 0, 0

function _M.setWord(yomi)
    lastword = yomi
end

function _M.getWord()
    return lastword
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
    local hiragana
    local retry = 1
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

        if type(hiragana.converted) ~= 'string' then
            rt.sleep(retry)
            retry = retry * 2
        else
            break
        end
    end
    return hiragana.converted
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

local function inDic(dic, string)
    local _, body =
        http.request(
        'GET',
        buildGetUrl(
            'http://public.dejizo.jp/NetDicV09.asmx/SearchDicItemLite',
            {
                Word = string,
                Dic = dic,
                Scope = 'HEADWORD',
                Match = 'EXACT',
                Merge = 'AND',
                Prof = 'XHTML',
                PageSize = 1,
                PageIndex = 0
            }
        ),
        {
            {'content-type', 'text/xml'}
        }
    )
    return body:match '<TotalHitCount>(%d*)</TotalHitCount>' ~= '0'
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
                srsearch = title,
                srlimit = 1,
                srsort = 'just_match'
            }
        ),
        {}
    )
    local res = json.decode(body).query
    if res.searchinfo.totalhits > 0 then
        return res.search[1].snippet:gsub('<[^>]*>', ''):gsub('。.*', '。')
    else
        return false
    end
end

function _M.process(kanji)
    local dicres = seekWiki(kanji)
    if not (inDic('EdictJE', kanji) or dicres or inDic('EJdict', kanji)) then
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
    local smallLtr = {'ゃ', 'ゅ', 'ょ', 'っ', 'ぁ', 'ぃ', 'ぅ', 'ぇ', 'ぉ'}

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
        return '我輩の辞書に「' .. content .. '」はありません。[' .. lastword .. ']'
    end

    local prefix = processed:sub(1, #lastword)
    local function timediff(time)
        return math.ceil((time - os.time()) / 60)
    end

    local judgements = {
        {
            cond = suffix == 'ん',
            ret = 'んで終わっています。'
        },
        {
            cond = #lastword ~= 0 and lastword ~= prefix,
            ret = hiragana .. '。しりとりじゃないじゃん。'
        },
        {
            cond = shibariLtrEndTime > os.time() and lastword ~= prefix and comboLtr.times < config.shibaredMessages,
            ret = '[' .. comboLtr.letter .. '] 縛り！残' .. timediff(shibariLtrEndTime) .. '分'
        },
        {
            cond = shibariLngEndTime > os.time() and comboLng.length ~= yomilen and
                comboLng.times < config.shibaredMessages,
            ret = comboLng.length .. '音縛り！' .. hiragana .. '=' .. yomilen .. '音。残' .. timediff(shibariLngEndTime) .. '分'
        },
        {
            cond = ut.includes(wordlist, hiragana),
            ret = '残念、もう出てます。'
        }
    }

    for _, cd in ipairs(judgements) do
        if cd.cond then
            return cd.ret .. '[' .. lastword .. ']'
        end
    end

    table.insert(wordlist, hiragana)
    if #wordlist > config.historyLength then
        table.remove(wordlist, 1)
    end

    lastword = suffix
    local ret = ''

    -- 文字コンボ判定
    if comboLtr.letter == suffix then
        comboLtr.times = comboLtr.times + 1
        suffix = suffix .. ' (' .. suffix .. comboLtr.times + 1 .. ')'
        if comboLtr.times == config.shibariThreshold and shibariLngEndTime <= os.time() then
            shibariLtrEndTime = os.time() + config.shibariLasts * 60
            ret = ret .. '[' .. lastword .. '] 縛り発動！残' .. tostring(config.shibariLasts) .. '分\n'
        end
    else
        comboLtr.times, comboLtr.letter = 0, suffix
    end

    -- 音数コンボ判定
    if comboLng.length == yomilen then
        comboLng.times = comboLng.times + 1
        suffix = suffix .. ' <' .. yomilen .. '音>'
        if comboLng.times == config.shibariThreshold and shibariLtrEndTime <= os.time() then
            shibariLngEndTime = os.time() + config.shibariLasts * 60
            ret = ret .. yomilen .. '音縛り発動！残' .. tostring(config.shibariLasts) .. '分\n'
        end
    else
        comboLng.times, comboLng.length = 0, yomilen
    end

    -- 無事受理されました
    return ret .. hiragana .. ' [' .. suffix .. ']', unchik
end

return _M
