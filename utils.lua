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

return _M
