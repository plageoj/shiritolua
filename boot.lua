local discordia = require 'discordia'
local client = discordia.Client()

if os.getenv('SHIRITOLUA_CONFIG') then
    local file = io.open('./config.lua', 'w')
    io.output(file)
    io.write(os.getenv('SHIRITOLUA_CONFIG'))
    io.close(file)
end

local config = require './config.lua'
local util = require './utils.lua'
local judge = require './judge.lua'

client:on(
    'ready',
    function()
        local err, yomi =
            pcall(
                function()
                    local msg =
                        client:getChannel(config.reactChannels[1]):getMessages():toArray(
                            'createdAt',
                            function(msg)
                                return msg.author.id == client.user.id and
                                    msg.content:match('%[[^%] ]*')
                            end
                        )
                    return table.remove(msg).content:match('%[([^%] ]*)')
                end
            )
        if err then
            print(yomi)
            judge.setWord(yomi)
        end
    end
)

client:on(
    'messageCreate',
    function(message)
        -- 対象チャンネルでなければ、反応しない
        local outOfKaya =
            not util.includes(
                config.reactChannels,
                function(item)
                    return '<#' .. item .. '>' == message.channel.mentionString
                end
            )
        -- Bot の発言と他チャンネルはさよなら
        if
            outOfKaya or message.author.bot or #message.mentionedUsers ~= 0 or
            #message.mentionedChannels ~= 0
        then
            return
        end

        local content = util.preprocess(message.content)

        if not content then
            return
        end

        local reply, knowledge = judge.judge(content)

        if reply then
            if knowledge then
                reply = reply .. '\n' .. knowledge
            end
            message:reply(reply)
        end
    end
)

client:run('Bot ' .. config.discordBotToken)
