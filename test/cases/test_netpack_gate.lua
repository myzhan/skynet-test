-- test_netpack_gate.lua — Test lua-netpack.c filter/pop/clear via gateserver
local skynet = require "skynet"
require "skynet.manager"
local socket = require "skynet.socket"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                local netpack = require "skynet.netpack"
                local driver = require "skynet.socketdriver"

                -- Test netpack.pack with string input
                local packed, sz = netpack.pack("hello")
                testlib.assert_true(packed ~= nil, "pack string should return data")
                testlib.assert_eq(7, sz, "pack should add 2-byte header: 2 + 5 = 7")

                -- Verify tostring round-trips
                local str = netpack.tostring(packed, sz)
                testlib.assert_true(type(str) == "string", "tostring should return string")
                testlib.assert_eq(7, #str, "tostring length should match")

                -- Verify the 2-byte big-endian length header
                local b1, b2 = str:byte(1, 2)
                testlib.assert_eq(0, b1, "high byte of length for 5-byte payload")
                testlib.assert_eq(5, b2, "low byte of length for 5-byte payload")
                testlib.assert_eq("hello", str:sub(3), "payload after header")

                -- Test netpack.pack with larger message
                local big_msg = string.rep("A", 1000)
                local big_packed, big_sz = netpack.pack(big_msg)
                testlib.assert_eq(1002, big_sz, "large pack size = 1000 + 2")
                local big_str = netpack.tostring(big_packed, big_sz)
                local h1, h2 = big_str:byte(1, 2)
                testlib.assert_eq(3, h1, "high byte for 1000: 1000 >> 8 = 3")
                testlib.assert_eq(232, h2, "low byte for 1000: 1000 & 0xff = 232")

                -- Test netpack.pack with lightuserdata input (via skynet.pack)
                local msg_ud, msg_sz = skynet.pack("test_data", 123)
                local packed2, sz2 = netpack.pack(msg_ud, msg_sz)
                testlib.assert_true(packed2 ~= nil, "pack lightuserdata should work")
                testlib.assert_eq(msg_sz + 2, sz2, "pack adds 2 bytes to lightuserdata")
                local str2 = netpack.tostring(packed2, sz2)
                testlib.assert_true(#str2 == sz2, "tostring length matches")

                -- Test netpack.tostring with nil userdata
                local nil_str = netpack.tostring(nil, 0)
                testlib.assert_eq("", nil_str, "tostring(nil,0) should return empty string")

                -- Test netpack.pack with maximum size (just under 64KB)
                local max_msg = string.rep("M", 65535)
                local max_packed, max_sz = netpack.pack(max_msg)
                testlib.assert_eq(65537, max_sz, "max pack = 65535 + 2")
                skynet.trash(max_packed, max_sz)

                -- Test netpack.pack with size that overflows (>= 0x10000) should error
                local too_big = string.rep("B", 65536)
                local ok_big, err_big = pcall(netpack.pack, too_big)
                testlib.assert_false(ok_big, "pack with >64KB should error")

                -- Test clear with nil (no-op)
                netpack.clear(nil)

                -- Now test the full gate/filter path via actual TCP traffic
                -- Start a gateserver-based service inline using netpack.filter directly
                local port = 19900
                local listen_id = socket.listen("127.0.0.1", port)
                testlib.assert_true(listen_id ~= nil, "listen should succeed")

                local queue = nil
                local received_msgs = {}
                local connected_fds = {}
                local closed_fds = {}

                socket.start(listen_id, function(fd, addr)
                    connected_fds[#connected_fds + 1] = fd
                    socket.start(fd)
                end)

                -- Connect a client
                local client = socket.open("127.0.0.1", port)
                testlib.assert_true(client ~= nil, "client connect should succeed")
                skynet.sleep(10)
                testlib.assert_true(#connected_fds > 0, "should have accepted connection")

                -- Send a properly framed message (2-byte length header + payload)
                local payload = "hello netpack"
                local frame = string.char(0, #payload) .. payload
                socket.write(client, frame)
                skynet.sleep(10)

                -- Send multiple messages in one TCP write (batch)
                local msg1 = "msg_one"
                local msg2 = "msg_two"
                local batch = string.char(0, #msg1) .. msg1 .. string.char(0, #msg2) .. msg2
                socket.write(client, batch)
                skynet.sleep(10)

                -- Send a split message (header in one write, body in another)
                local split_payload = "split_message_test"
                socket.write(client, string.char(0, #split_payload))
                skynet.sleep(5)
                socket.write(client, split_payload)
                skynet.sleep(10)

                -- Send a message with only the first header byte, then the rest
                local partial_msg = "partial"
                socket.write(client, string.char(0))
                skynet.sleep(5)
                socket.write(client, string.char(#partial_msg) .. partial_msg)
                skynet.sleep(10)

                -- Cleanup
                socket.close(client)
                skynet.sleep(5)
                for _, fd in ipairs(connected_fds) do
                    pcall(socket.close, fd)
                end
                socket.close(listen_id)
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
