-- test_gate.lua — Test lua-netpack.c filter path via gate service
-- Exercises lfilter with TYPE_DATA/OPEN/CLOSE, filter_data, push_data,
-- push_more, get_queue, lpop, find_uncomplete, save_uncomplete, close_uncomplete
local skynet = require "skynet"
require "skynet.manager"
local socket = require "skynet.socket"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, source, cmd, subcmd, ...)
        if cmd == "run" then
            local ok, err = pcall(function()
                local port = 19901
                local received_data = {}
                local connected = {}
                local disconnected = {}
                local wait_co = nil

                -- Register a handler for messages from gate
                local saved_dispatch = nil

                -- Start gate service
                local gate = skynet.newservice("gate")

                -- We'll use a fork to handle gate notifications
                local notifications = {}
                local notify_count = 0

                -- Replace dispatch to handle socket notifications from gate
                skynet.dispatch("lua", function(_, src, c, sc, ...)
                    if c == "socket" then
                        if sc == "open" then
                            local fd, addr = ...
                            connected[#connected + 1] = fd
                            -- Tell gate to start receiving data for this client
                            skynet.call(gate, "lua", "accept", fd)
                        elseif sc == "data" then
                            local fd, data = ...
                            received_data[#received_data + 1] = { fd = fd, data = data }
                        elseif sc == "close" then
                            local fd = ...
                            disconnected[#disconnected + 1] = fd
                        end
                        notify_count = notify_count + 1
                        if wait_co then
                            skynet.wakeup(wait_co)
                        end
                    elseif c == "run" then
                        -- ignore re-entry
                    end
                end)

                local function wait_notifications(target, timeout)
                    local deadline = skynet.now() + (timeout or 100)
                    while notify_count < target and skynet.now() < deadline do
                        wait_co = coroutine.running()
                        skynet.sleep(5)
                        wait_co = nil
                    end
                end

                -- Open gate, current service is the watchdog
                skynet.call(gate, "lua", "open", {
                    port = port,
                    maxclient = 32,
                    nodelay = true,
                })

                -- Test 1: Simple connect and single message
                local client1 = socket.open("127.0.0.1", port)
                testlib.assert_true(client1 ~= nil, "client1 connect should succeed")
                wait_notifications(1, 50)
                testlib.assert_true(#connected > 0, "gate should notify connect")

                -- Send a properly framed message (2-byte big-endian length + payload)
                local payload1 = "hello gate"
                local frame1 = string.char(0, #payload1) .. payload1
                socket.write(client1, frame1)
                wait_notifications(2, 50)
                testlib.assert_true(#received_data > 0, "should receive data")
                testlib.assert_eq("hello gate", received_data[#received_data].data, "data should match")

                -- Test 2: Multiple messages in one TCP send (exercises push_more path)
                local msg1 = "first"
                local msg2 = "second_msg"
                local batch = string.char(0, #msg1) .. msg1 .. string.char(0, #msg2) .. msg2
                local before_count = #received_data
                socket.write(client1, batch)
                wait_notifications(notify_count + 2, 50)
                testlib.assert_true(#received_data >= before_count + 2, "should receive 2 messages from batch")

                -- Test 3: Split message (partial header) - exercises uncomplete path
                -- Send only the first byte of the 2-byte header
                local split_payload = "split_message"
                socket.write(client1, string.char(0))
                skynet.sleep(5)
                -- Send rest of header + payload
                socket.write(client1, string.char(#split_payload) .. split_payload)
                wait_notifications(notify_count + 1, 50)
                testlib.assert_eq("split_message", received_data[#received_data].data, "split message should reassemble")

                -- Test 4: Partial payload (exercises uncomplete with partial data)
                local partial_payload = "partial_data_here"
                -- Send header + half the payload
                local half = math.floor(#partial_payload / 2)
                socket.write(client1, string.char(0, #partial_payload) .. partial_payload:sub(1, half))
                skynet.sleep(5)
                -- Send the rest
                socket.write(client1, partial_payload:sub(half + 1))
                wait_notifications(notify_count + 1, 50)
                testlib.assert_eq("partial_data_here", received_data[#received_data].data, "partial payload should reassemble")

                -- Test 5: Large message (exercises larger size header)
                local large_payload = string.rep("X", 5000)
                local hi = math.floor(#large_payload / 256)
                local lo = #large_payload % 256
                socket.write(client1, string.char(hi, lo) .. large_payload)
                wait_notifications(notify_count + 1, 50)
                testlib.assert_eq(5000, #received_data[#received_data].data, "large message should arrive intact")

                -- Test 6: Multiple clients (exercises connection multiplexing)
                local client2 = socket.open("127.0.0.1", port)
                testlib.assert_true(client2 ~= nil, "client2 connect should succeed")
                wait_notifications(notify_count + 1, 50)

                local c2_msg = "from_client2"
                socket.write(client2, string.char(0, #c2_msg) .. c2_msg)
                wait_notifications(notify_count + 1, 50)
                testlib.assert_eq("from_client2", received_data[#received_data].data, "client2 message")

                -- Test 7: Client disconnect (exercises close_uncomplete + TYPE_CLOSE)
                socket.close(client1)
                wait_notifications(notify_count + 1, 100)
                testlib.assert_true(#disconnected > 0, "should notify disconnect")

                -- Test 8: Close with pending uncomplete data
                -- Send partial header then close
                socket.write(client2, string.char(0))
                skynet.sleep(5)
                socket.close(client2)
                wait_notifications(notify_count + 1, 100)

                -- Close gate
                skynet.call(gate, "lua", "close")
                skynet.sleep(10)
                pcall(skynet.kill, gate)
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
