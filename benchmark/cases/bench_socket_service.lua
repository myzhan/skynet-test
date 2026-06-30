local skynet = require "skynet"
local socket = require "skynet.socket"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd, ...)
        if cmd == "start" then
            local listen_id, addr, port = socket.listen("127.0.0.1", 0)
            skynet.retpack(listen_id, port)
            socket.start(listen_id, function(id, addr)
                socket.start(id)
                while true do
                    local data = socket.read(id, 2)
                    if not data then break end
                    local len = data:byte(1) * 256 + data:byte(2)
                    local body = socket.read(id, len)
                    if not body then break end
                    local header = string.char(math.floor(#body / 256), #body % 256)
                    socket.write(id, header .. body)
                end
            end)
        end
    end)
end)
