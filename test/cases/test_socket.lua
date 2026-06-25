-- test_socket.lua — Test skynet.socket operations
local skynet = require "skynet"
require "skynet.manager"
local socket = require "skynet.socket"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                testlib.assert_true(type(socket) == "table", "socket module should be a table")

                -- Test socket.listen
                local listen_id = socket.listen("127.0.0.1", 8888)
                if not listen_id then
                    -- Port might be in use, try another
                    listen_id = socket.listen("127.0.0.1", 18888)
                end
                testlib.assert_true(listen_id ~= nil, "listen should return socket id")

                if listen_id then
                    -- Test socket.start
                    local accept_called = false
                    socket.start(listen_id, function(id, addr)
                        accept_called = true
                        socket.close(id)
                    end)

                    -- Test socket.open as client
                    local client = socket.open("127.0.0.1", 8888)
                    if not client then
                        client = socket.open("127.0.0.1", 18888)
                    end
                    if client then
                        socket.close(client)
                    end
                    skynet.sleep(10)

                    -- Cleanup
                    socket.close(listen_id)
                end
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
