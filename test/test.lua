local discordia = require 'discordia'
local client = discordia.Client()

local config = require '../config.lua'
local kana = require '../src/kana.lua'
local ut = require '../src/utils.lua'
local dict = require '../src/dict.lua'
local judge = require '../src/judge.lua'
local case = require './case.lua'

client:run('Bot ' .. config.discordBotToken)

local function test(name, func, case)
    local passed, failed = 0, 0
    local function eq(res, req)
        if type(req) ~= 'table' then
            return req == res[1]
        else
            for key, val in pairs(req) do
                if val ~= res[key] then
                    return false
                end
            end
            return true
        end
    end
    local function xTbl(t)
        if type(t) == 'table' then
            local str = '{ '
            for key, val in pairs(t) do
                str = str .. key .. ' = ' .. xTbl(val) .. ', '
            end
            return str:sub(1, -3) .. ' }'
        end
        return tostring(t)
    end
    print('\n--- TESTING: ', name, ' ---\n')
    for i, case in ipairs(case) do
        local res = { func(case[1]) }
        if eq(res, case[2]) then
            print('\x1b[42m\x1b[30m PASSED \x1b[0m case ' .. i, case[1])
            passed = passed + 1
        else
            print('\x1b[41m\x1b[30m FAILED \x1b[0m case ' .. i, case[1], 'returns', xTbl(res), 'should be',
                xTbl(case[2]))
            failed = failed + 1
        end
    end
    print(
        '\nResult:\n',
        passed .. ' tests passed,',
        failed .. ' tests failed,',
        math.ceil(passed * 100 / #case) .. '%'
    )
    return failed
end


client:on(
    'ready',
    function()
        judge.test()
        local ret =
            test('Kana conversion', kana.katakana_to_hiragana, case.kana) and
            test('Preprocessor', ut.preprocess, case.preprocess) and
            test('Dictionary search', dict.searchDic, case.dict) and
            test('Kanji engine', judge.process, case.kanji) and
            test('Shiritori engine', judge.judge, case.shiritori)
        os.exit(ret)
    end
)
