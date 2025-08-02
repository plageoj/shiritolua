local json = require 'json'
local http = require 'coro-http'
local querystring = require 'querystring'

local kana = require './kana.lua'

local _M = {}

local sudachiVersion = os.getenv('SUDACHI_VERSION')
if not sudachiVersion then
    error('SUDACHI_VERSION environment variable is not set.')
end


local function execute_cmd(cmd)
    local handle = io.popen(cmd)
    if not handle then
        error('Failed to execute command: ' .. cmd)
        return nil
    end
    local result = handle:read('*a')
    handle:close()

    return result
end

local function split(str, ts)
    -- 引数がないときは空tableを返す
    if ts == nil then return {} end

    local t = {}
    local i = 1
    for s in string.gmatch(str, '(.-)' .. ts) do
        t[i] = s
        i = i + 1
    end

    return t
end

function _M.searchDic(string)
    local analyzedText = execute_cmd('echo "' ..
        string .. '" | java -jar sudachi/sudachi-' .. sudachiVersion .. '.jar -a -p sudachi')
    if analyzedText == nil or analyzedText == '' then
        return false
    end
    -- 複数の単語からなるものは認めない（EOSに1行使うので2で判定する）
    local lines = split(analyzedText, '\n')
    if #lines > 2 then
        return false, ''
    end

    local katakana = ''
    for _, line in ipairs(lines) do
        -- 各行をタブで分割
        local parts = split(line, '\t')
        if parts[5] ~= nil then
            katakana = katakana .. parts[5]
        end
    end

    -- sudachiの出力に未知語(OOV)が含まれていれば、辞書にないと判断
    return not analyzedText:find('(OOV)'), kana.katakana_to_hiragana(katakana)
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
        url = url .. '&' .. key .. '=' .. querystring.urlencode(val)
    end
    return url:gsub('?&', '?')
end

function _M.seekWiki(title)
    local _, body =
        http.request(
            'GET',
            buildGetUrl(
                'https://api.wikimedia.org/core/v1/wikipedia/ja/search/page',
                {
                    q = '"' .. title .. '"',
                    limit = 1,
                }
            ),
            {
                ['User-Agent'] = 'Shiritolua/equaaqua@hotmail.com'
            }
        )
    local res = json.decode(body)
    if not res or not res.pages or #res.pages == 0 then
        return false
    end
    local page = res.pages[1]

    local excerpt = page.excerpt:gsub(
        '<[^>]*>', ''):gsub(
        '&quot;', '"'):gsub(
        '&lt;', '<'):gsub(
        '&gt;', '>'):gsub(
        '&amp;', '&')
    local snippets = split(excerpt, '。')
    local snippet = excerpt
    local maxHits = 0
    for _, s in ipairs(snippets) do
        local hits = 0
        for _ in s:gmatch(title) do
            hits = hits + 1
        end
        if hits > maxHits then
            maxHits = hits
            snippet = s .. '。'
        end
    end

    local description = ''
    if page.description ~= nil then
        description = '/' .. page.description
    end

    return snippet:gsub(title, '**' .. title .. '**')
        .. ' - [' .. page.title .. '](https://ja.wikipedia.org/wiki/'
        .. querystring.urlencode(page.title) .. ')' .. description
end

return _M
