local http = require 'coro-http'

if not os.getenv 'USER' then
	print 'Starting server'
    http.createServer('0.0.0.0', os.getenv 'PORT' + 0, function(head, body)
        local html = ''
        for line in io.lines './html/index.html' do
            html = html .. line
        end
		return {
			version = head.version,
			code = 200,
			keepAlive = false,
			{'Content-type', 'text/html'}
		}, html
	end)
end
