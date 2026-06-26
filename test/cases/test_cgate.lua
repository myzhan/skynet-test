-- test_cgate.lua — Tests for service_gate.c (C gate service)
-- Covers: databuffer.h (push, read, readheader, reset, clear, messagepool)
--         hashid.h (init, insert, lookup, remove, full, clear)
local skynet = require "skynet"
require "skynet.manager"
local socket = require "skynet.socket"

skynet.start(function()
    skynet.dispatch("lua", function(_, source, cmd)
        if cmd == "run" then
            local ok, err = xpcall(function()
                local port = 19960
                local notifications = {}
                local gate = nil

                -- Register text protocol to receive gate notifications
                skynet.register_protocol {
                    name = "text",
                    id = skynet.PTYPE_TEXT,
                    pack = function(text) return text end,
                    unpack = function(msg, sz)
                        return skynet.tostring(msg, sz)
                    end,
                    dispatch = function(_, _, text)
                        notifications[#notifications + 1] = text
                    end,
                }

                -- Launch C gate service
                local addr_hex = string.format(":%08x", skynet.self())
                local parm = string.format("S %s 127.0.0.1:%d 0 32", addr_hex, port)
                gate = skynet.launch("gate", parm)
                assert(gate, "C gate failed to launch")
                skynet.sleep(10)

                -- Connect a client
                local client = socket.open("127.0.0.1", port)
                assert(client, "client connect failed")
                skynet.sleep(20)

                -- Gate should report "open" to watchdog
                assert(#notifications > 0, "no open notification")
                local fd_str = notifications[#notifications]:match("^(%d+) open")
                assert(fd_str, "failed to parse open notification: " .. notifications[#notifications])

                -- Tell gate to start receiving data for this fd
                skynet.send(gate, "text", "start " .. fd_str)
                skynet.sleep(10)

                -- Send framed messages (exercises databuffer_push, readheader, read)
                local payload = "hello_cgate_test"
                socket.write(client, string.char(0, #payload) .. payload)
                skynet.sleep(20)

                -- Send multiple messages
                local msg1 = "msg_one"
                local msg2 = "msg_two_extended"
                socket.write(client, string.char(0, #msg1) .. msg1 ..
                                     string.char(0, #msg2) .. msg2)
                skynet.sleep(20)

                -- Send partial message then complete it
                local partial = "partial_body_for_databuffer"
                socket.write(client, string.char(0, #partial) .. partial:sub(1, 5))
                skynet.sleep(10)
                socket.write(client, partial:sub(6))
                skynet.sleep(20)

                -- Disconnect (exercises hashid_remove, databuffer_clear)
                socket.close(client)
                skynet.sleep(20)

                -- Check close notification
                local got_close = false
                for _, n in ipairs(notifications) do
                    if n:find("close") then got_close = true; break end
                end
                assert(got_close, "no close notification")

                -- Test multiple clients (exercises hashid with multiple entries)
                notifications = {}
                local clients = {}
                for i = 1, 4 do
                    clients[i] = socket.open("127.0.0.1", port)
                    skynet.sleep(5)
                end
                skynet.sleep(20)

                -- Start all clients and send data
                for _, n in ipairs(notifications) do
                    local fd = n:match("^(%d+) open")
                    if fd then
                        skynet.send(gate, "text", "start " .. fd)
                    end
                end
                skynet.sleep(10)

                for i, c in ipairs(clients) do
                    local data = string.format("client%d_data", i)
                    socket.write(c, string.char(0, #data) .. data)
                end
                skynet.sleep(20)

                -- Kick first client
                local first_fd = notifications[1]:match("^(%d+) open")
                if first_fd then
                    skynet.send(gate, "text", "kick " .. first_fd)
                    skynet.sleep(10)
                end

                -- Close remaining clients
                for i = 2, #clients do
                    socket.close(clients[i])
                    skynet.sleep(5)
                end
                skynet.sleep(20)

                -- Close gate
                skynet.send(gate, "text", "close")
                skynet.sleep(10)
                pcall(skynet.kill, gate)

            end, debug.traceback)

            if ok then
                skynet.ret(skynet.pack({ status = "pass" }))
            else
                skynet.ret(skynet.pack({ status = "fail", message = tostring(err) }))
            end
        end
    end)
end)
