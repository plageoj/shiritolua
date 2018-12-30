local discordia = require 'discordia'
local client = discordia.Client()

local config = require '../config.lua'
local ut = require '../utils.lua'
local judge = require '../judge.lua'
local case = require './case.lua'

client:run('Bot ' .. config.discordBotToken)

local function test(name, func, case)
    local numpass, numfail = 0, 0
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
    print('\n--- TESTING: ', name, ' ---\n')
    for i, case in ipairs(case) do
        local res = {func(case[1])}
        if eq(res, case[2]) then
            print('\x1b[42m\x1b[30m PASSED \x1b[0m case ' .. i, case[1])
            numpass = numpass + 1
        else
            print('\x1b[41m\x1b[30m FAILED \x1b[0m case ' .. i, case[1], 'returns', res, 'should be', case[2])
            numfail = numfail + 1
        end
    end
    print(
        '\nResult:\n',
        numpass .. ' tests passed,',
        numfail .. ' tests failed,',
        math.ceil(numpass * 100 / #case) .. '%'
    )
    return numfail
end

judge.test()

client:on(
    'ready',
    function()
        local retval =
            test('preprocessor', ut.preprocess, case.preprocess) and test('Kanji engine', judge.process, case.kanji) and
            test('Shiritori engine', judge.judge, case.shiritori)
        os.exit(retval)
    end
)
