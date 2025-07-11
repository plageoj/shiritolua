local config = require '../config.lua'
local ut = require './utils.lua'
local dict = require './dict.lua'

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

function _M.process(kanji)
    local wikiEntry = dict.seekWiki(kanji)
    local hasDicEntry, hiragana = dict.searchDic(kanji)
    if (not (hasDicEntry or wikiEntry)) or (hiragana == nil) then
        return false
    end
    local removals = {
        '[!-~]',
        '\xe3\x82[\x97-\x9f]', -- 平仮名特殊記号 ゛ など
        '・',
        ' ',
        '\xe3\x83[\xbd-\xbf]' -- カタカナ特殊記号
    }
    -- 記号を除く
    for _, str in ipairs(removals) do
        hiragana = hiragana:gsub(str, '')
    end
    local mola = ''
    for i = 1, #hiragana do
        local mt = hiragana:sub(i, i + 2):match '\xe3[\x81-\x83][\x80-\xbf]'
        if mt then
            mola = mola .. mt
        end
    end

    local processed = mola:gsub('ー', '')
    local count, yomiLen = -3, math.floor(#mola / 3)
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
        local _, occurrences = mola:gsub(ltr, '')
        yomiLen = yomiLen - occurrences
    end

    debug(kanji, hiragana, processed, yomiLen)

    return mola, processed, processed:sub(count), yomiLen, wikiEntry
end

function _M.judge(content)
    local hiragana, processed, suffix, yomiLen, wikiEntry = _M.process(content)
    if hiragana == false then
        return '我輩の辞書に「' .. content .. '」はありません。[' .. lastWord .. ']'
    end

    local prefix = processed:sub(1, #lastWord)
    local function time_diff(time)
        return math.ceil((time - os.time()) / 60)
    end

    local judgements = {
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
                '] 縛り！残' .. time_diff(shibariLtrEndTime) .. '分'
        },
        {
            cond = shibariLngEndTime > os.time() and comboLng.length ~= yomiLen and
                comboLng.times < config.shibaredMessages,
            ret = comboLng.length ..
                '音縛り！' ..
                hiragana ..
                '=' ..
                yomiLen ..
                '音。残' .. time_diff(shibariLngEndTime) .. '分'
        },
        {
            cond = ut.includes(wordList, hiragana),
            ret = '残念、もう出てます。'
        }
    }

    for _, cd in ipairs(judgements) do
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
    if comboLng.length == yomiLen then
        comboLng.times = comboLng.times + 1
        suffix = suffix .. ' <' .. yomiLen .. '音>'
        if
            comboLng.times == config.shibariThreshold and
            shibariLtrEndTime <= os.time()
        then
            shibariLngEndTime = os.time() + config.shibariLasts * 60
            ret =
                ret ..
                yomiLen .. '音縛り発動！残' .. tostring(config.shibariLasts) .. '分\n'
        end
    else
        comboLng.times, comboLng.length = 0, yomiLen
    end

    -- 無事受理されました
    return ret .. hiragana .. ' [' .. suffix .. ']', wikiEntry
end

return _M
