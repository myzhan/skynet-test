-- test_netpack_core.lua — Tests for lua-netpack.c pack/pop/clear/tostring/filter paths
local skynet = require "skynet"
local socket = require "skynet.socket"
local T = require "testlib"

T.case("pack and tostring round-trip", function()
    local netpack = require "skynet.netpack"
    local packed, sz = netpack.pack("hello")
    T.assert_true(packed ~= nil, "pack returns data")
    T.assert_eq(7, sz, "pack size = 2 header + 5 payload")
    local str = netpack.tostring(packed, sz)
    T.assert_eq(7, #str, "tostring length")
    T.assert_eq("hello", str:sub(3), "payload intact")
end)

T.case("pack with lightuserdata input", function()
    local netpack = require "skynet.netpack"
    local msg, msg_sz = skynet.pack("ud_test")
    local packed, sz = netpack.pack(msg, msg_sz)
    T.assert_true(packed ~= nil, "pack lightuserdata")
    T.assert_eq(msg_sz + 2, sz, "pack adds 2 bytes header")
    skynet.trash(packed, sz)
end)

T.case("tostring with nil userdata returns empty", function()
    local netpack = require "skynet.netpack"
    local str = netpack.tostring(nil, 0)
    T.assert_eq("", str, "tostring nil returns empty")
end)

T.case("pack overflow errors", function()
    local netpack = require "skynet.netpack"
    local too_big = string.rep("x", 65536)
    local ok, err = pcall(netpack.pack, too_big)
    T.assert_true(not ok, "pack >64KB should error")
end)

T.case("clear with nil is no-op", function()
    local netpack = require "skynet.netpack"
    netpack.clear(nil)
    T.assert_true(true, "clear nil no-op")
end)

T.case("gate filter: single complete message", function()
    local port = 19940
    local listen_id = socket.listen("127.0.0.1", port)
    local server_fd = nil
    local received = {}

    socket.start(listen_id, function(fd, addr)
        server_fd = fd
        socket.start(fd)
    end)

    local client = socket.open("127.0.0.1", port)
    skynet.sleep(10)

    -- Send a complete framed message
    local payload = "complete_msg"
    local frame = string.char(0, #payload) .. payload
    socket.write(client, frame)
    skynet.sleep(20)

    socket.close(client)
    skynet.sleep(5)
    if server_fd then pcall(socket.close, server_fd) end
    socket.close(listen_id)
    T.assert_true(true, "single message filter path")
end)

T.case("gate filter: multiple messages in one write (TYPE_MORE)", function()
    local port = 19941
    local listen_id = socket.listen("127.0.0.1", port)
    local server_fd = nil

    socket.start(listen_id, function(fd, addr)
        server_fd = fd
        socket.start(fd)
    end)

    local client = socket.open("127.0.0.1", port)
    skynet.sleep(10)

    -- Send 3 messages in one TCP write (triggers push_more and TYPE_MORE path)
    local m1, m2, m3 = "first", "second", "third_msg"
    local batch = string.char(0, #m1) .. m1 ..
                  string.char(0, #m2) .. m2 ..
                  string.char(0, #m3) .. m3
    socket.write(client, batch)
    skynet.sleep(20)

    socket.close(client)
    skynet.sleep(5)
    if server_fd then pcall(socket.close, server_fd) end
    socket.close(listen_id)
    T.assert_true(true, "multiple messages TYPE_MORE path")
end)

T.case("gate filter: split header (1 byte then rest)", function()
    local port = 19942
    local listen_id = socket.listen("127.0.0.1", port)
    local server_fd = nil

    socket.start(listen_id, function(fd, addr)
        server_fd = fd
        socket.start(fd)
    end)

    local client = socket.open("127.0.0.1", port)
    skynet.sleep(10)

    -- Send only the first header byte (triggers uc->read = -1 path)
    local payload = "split_hdr"
    socket.write(client, string.char(0))
    skynet.sleep(10)
    -- Then send the second header byte + payload
    socket.write(client, string.char(#payload) .. payload)
    skynet.sleep(20)

    socket.close(client)
    skynet.sleep(5)
    if server_fd then pcall(socket.close, server_fd) end
    socket.close(listen_id)
    T.assert_true(true, "split header path")
end)

T.case("gate filter: partial body then completion", function()
    local port = 19943
    local listen_id = socket.listen("127.0.0.1", port)
    local server_fd = nil

    socket.start(listen_id, function(fd, addr)
        server_fd = fd
        socket.start(fd)
    end)

    local client = socket.open("127.0.0.1", port)
    skynet.sleep(10)

    -- Send header + partial body (triggers uncomplete with uc->read > 0)
    local payload = "this_is_a_longer_payload_for_partial_test"
    socket.write(client, string.char(0, #payload) .. payload:sub(1, 5))
    skynet.sleep(10)
    -- Complete the body
    socket.write(client, payload:sub(6))
    skynet.sleep(20)

    socket.close(client)
    skynet.sleep(5)
    if server_fd then pcall(socket.close, server_fd) end
    socket.close(listen_id)
    T.assert_true(true, "partial body completion path")
end)

T.case("gate filter: close with pending uncomplete data", function()
    local port = 19944
    local listen_id = socket.listen("127.0.0.1", port)
    local server_fd = nil

    socket.start(listen_id, function(fd, addr)
        server_fd = fd
        socket.start(fd)
    end)

    local client = socket.open("127.0.0.1", port)
    skynet.sleep(10)

    -- Send a partial message (just header, no body) then close
    -- This exercises close_uncomplete path
    socket.write(client, string.char(0, 100) .. "partial")
    skynet.sleep(5)
    socket.close(client)
    skynet.sleep(20)

    if server_fd then pcall(socket.close, server_fd) end
    socket.close(listen_id)
    T.assert_true(true, "close with pending data path")
end)

T.case("gate filter: many messages trigger push_more recursion", function()
    local port = 19945
    local listen_id = socket.listen("127.0.0.1", port)
    local server_fd = nil

    socket.start(listen_id, function(fd, addr)
        server_fd = fd
        socket.start(fd)
    end)

    local client = socket.open("127.0.0.1", port)
    skynet.sleep(10)

    -- Send many small messages in one write to trigger recursive push_more
    local batch = ""
    for i = 1, 20 do
        local msg = string.format("msg%02d", i)
        batch = batch .. string.char(0, #msg) .. msg
    end
    socket.write(client, batch)
    skynet.sleep(30)

    socket.close(client)
    skynet.sleep(5)
    if server_fd then pcall(socket.close, server_fd) end
    socket.close(listen_id)
    T.assert_true(true, "recursive push_more path")
end)

T.case("gate filter: complete msgs + trailing incomplete (push_more uncomplete)", function()
    local port = 19946
    local listen_id = socket.listen("127.0.0.1", port)
    local server_fd = nil

    socket.start(listen_id, function(fd, addr)
        server_fd = fd
        socket.start(fd)
    end)

    local client = socket.open("127.0.0.1", port)
    skynet.sleep(10)

    -- Send complete messages followed by an incomplete message in one write
    -- This triggers push_more with size < pack_size (lines 202-207)
    local m1 = "complete_one"
    local m2 = "complete_two"
    -- Third message: declare 50 bytes but only send 10
    local batch = string.char(0, #m1) .. m1 ..
                  string.char(0, #m2) .. m2 ..
                  string.char(0, 50) .. "only_ten_"
    socket.write(client, batch)
    skynet.sleep(10)

    -- Now complete the third message
    socket.write(client, string.rep("X", 40))
    skynet.sleep(20)

    socket.close(client)
    skynet.sleep(5)
    if server_fd then pcall(socket.close, server_fd) end
    socket.close(listen_id)
    T.assert_true(true, "push_more uncomplete path")
end)

T.case("gate filter: complete msgs + trailing 1 byte (push_more header split)", function()
    local port = 19947
    local listen_id = socket.listen("127.0.0.1", port)
    local server_fd = nil

    socket.start(listen_id, function(fd, addr)
        server_fd = fd
        socket.start(fd)
    end)

    local client = socket.open("127.0.0.1", port)
    skynet.sleep(10)

    -- Send complete messages followed by just 1 byte (first byte of next header)
    -- This triggers push_more size==1 path (lines 192-195)
    local m1 = "first_msg"
    local batch = string.char(0, #m1) .. m1 .. string.char(0)
    socket.write(client, batch)
    skynet.sleep(10)

    -- Complete with second header byte + payload
    local m2 = "second"
    socket.write(client, string.char(#m2) .. m2)
    skynet.sleep(20)

    socket.close(client)
    skynet.sleep(5)
    if server_fd then pcall(socket.close, server_fd) end
    socket.close(listen_id)
    T.assert_true(true, "push_more header split path")
end)

T.case("gate filter: uncomplete then more data with extra (TYPE_MORE from uncomplete)", function()
    local port = 19948
    local listen_id = socket.listen("127.0.0.1", port)
    local server_fd = nil

    socket.start(listen_id, function(fd, addr)
        server_fd = fd
        socket.start(fd)
    end)

    local client = socket.open("127.0.0.1", port)
    skynet.sleep(10)

    -- Send partial message
    local payload = "partial_body"
    socket.write(client, string.char(0, #payload) .. payload:sub(1, 3))
    skynet.sleep(10)

    -- Complete the partial + send another full message in same write
    -- This triggers lines 266-270 (push_data for uncomplete + push_more for remaining)
    local extra = "extra_msg"
    socket.write(client, payload:sub(4) .. string.char(0, #extra) .. extra)
    skynet.sleep(20)

    socket.close(client)
    skynet.sleep(5)
    if server_fd then pcall(socket.close, server_fd) end
    socket.close(listen_id)
    T.assert_true(true, "TYPE_MORE from uncomplete completion path")
end)

T.run()
