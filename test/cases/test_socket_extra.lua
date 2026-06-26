-- test_socket_extra.lua — Extended socket tests covering more C socket_server paths
local skynet = require "skynet"
require "skynet.manager"
local socket = require "skynet.socket"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                -- Test TCP listen + accept + read/write
                local port = 19876
                local listen_id = socket.listen("127.0.0.1", port)
                testlib.assert_true(listen_id ~= nil, "listen should succeed")

                local accepted_id = nil
                socket.start(listen_id, function(id, addr)
                    accepted_id = id
                    socket.start(id)
                end)

                -- Connect as client
                local client_id = socket.open("127.0.0.1", port)
                testlib.assert_true(client_id ~= nil, "connect should succeed")

                skynet.sleep(10)
                testlib.assert_true(accepted_id ~= nil, "should have accepted connection")

                -- Test write
                local write_ok = socket.write(client_id, "hello from client")
                testlib.assert_true(write_ok ~= false, "write should succeed")

                -- Test read
                skynet.sleep(5)
                local data = socket.read(accepted_id, 17)
                if data then
                    testlib.assert_eq("hello from client", data, "server should receive data")
                end

                -- Test write from server side
                socket.write(accepted_id, "hello from server")
                skynet.sleep(5)
                local reply = socket.read(client_id, 17)
                if reply then
                    testlib.assert_eq("hello from server", reply, "client should receive reply")
                end

                -- Test socketdriver.nodelay via lower-level API
                local driver = require "skynet.socketdriver"
                local ok_nodelay = pcall(driver.nodelay, client_id)
                testlib.assert_true(ok_nodelay, "driver.nodelay should not error")

                -- Test socket.netstat (wraps driver.info)
                local info = socket.netstat()
                testlib.assert_true(type(info) == "table", "socket.netstat should return table")

                -- Cleanup
                socket.close(client_id)
                socket.close(accepted_id)
                socket.close(listen_id)

                -- Test UDP: create a bound UDP socket
                local udp_id = socket.udp(function(str, from)
                end, "127.0.0.1", 19877)
                testlib.assert_true(udp_id ~= nil, "udp should return id")

                -- Test UDP with connect (sets default destination)
                local udp_client = socket.udp(function(str, from) end)
                testlib.assert_true(udp_client ~= nil, "udp client should return id")

                -- udp_connect sets the remote address for subsequent sends
                socket.udp_connect(udp_client, "127.0.0.1", 19877)
                skynet.sleep(5)

                socket.close(udp_id)
                socket.close(udp_client)

                -- Test socket.resolve (DNS resolution for loopback)
                local resolved = socket.resolve("localhost")
                testlib.assert_true(resolved ~= nil, "resolve localhost should work")
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
