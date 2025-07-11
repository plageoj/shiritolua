local _M = {}

-- UTF-8 文字列から Unicode コードポイントを取得する関数
local function utf8_to_codepoints(str)
    local codepoints = {}
    for _, c in utf8.codes(str) do
        table.insert(codepoints, c)
    end
    return codepoints
end

-- Unicode コードポイントから UTF-8 文字列を作成する関数
local function codepoints_to_utf8(codepoints)
    local chars = {}
    for _, cp in ipairs(codepoints) do
        table.insert(chars, utf8.char(cp))
    end
    return table.concat(chars)
end

-- カタカナをひらがなに変換する関数
function _M.katakana_to_hiragana(input)
    local result = {}
    for _, code in utf8.codes(input) do
        -- カタカナの範囲: U+30A1～U+30F6 → 対応するひらがな: U+3041～U+3096
        if code >= 0x30A1 and code <= 0x30F6 then
            table.insert(result, code - 0x60)
        else
            table.insert(result, code)
        end
    end
    return codepoints_to_utf8(result)
end

return _M
