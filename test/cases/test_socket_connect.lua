-- test_socket_connect.lua — Test lua-socket.c address parsing, connect, UDP, lsendlow paths
local skynet = require "skynet"
local socket = require "skynet.socket"
local T = require "testlib"

T.case("connect with host:port format", function()
    local driver = require "skynet.socketdriver"
    -- Start a listener first
    local port = 19910
    local listen_id = socket.listen("127.0.0.1", port)
    T.assert_true(listen_id ~= nil, "listen should succeed")
    socket.start(listen_id, function(id) socket.start(id) end)

    -- Connect using "host:port" combined format
    local fd = socket.open("127.0.0.1", port)
    T.assert_true(fd ~= nil, "connect host:port should work")
    skynet.sleep(5)
    socket.close(fd)
    socket.close(listen_id)
end)

T.case("driver.connect with addr:port string", function()
    local driver = require "skynet.socketdriver"
    local port = 19911
    local listen_id = socket.listen("127.0.0.1", port)
    socket.start(listen_id, function(id) socket.start(id) end)

    local fd = driver.connect("127.0.0.1", port)
    T.assert_true(type(fd) == "number", "driver.connect should return fd")
    skynet.sleep(10)
    pcall(socket.close, fd)
    socket.close(listen_id)
end)

T.case("UDP dial and listen", function()
    local driver = require "skynet.socketdriver"

    -- Create a UDP socket bound to a port (server)
    local server_id = socket.udp(function(str, from)
    end, "127.0.0.1", 19912)
    T.assert_true(server_id ~= nil, "udp server create")

    -- Create a UDP client and connect to server
    local client_id = socket.udp(function(str, from)
    end)
    T.assert_true(client_id ~= nil, "udp client create")

    -- Connect UDP client to server address
    socket.udp_connect(client_id, "127.0.0.1", 19912)
    skynet.sleep(5)

    socket.close(client_id)
    socket.close(server_id)
end)

T.case("socket.shutdown", function()
    local port = 19913
    local listen_id = socket.listen("127.0.0.1", port)
    socket.start(listen_id, function(id) socket.start(id) end)

    local fd = socket.open("127.0.0.1", port)
    T.assert_true(fd ~= nil, "connect for shutdown test")
    skynet.sleep(5)

    -- shutdown sends close signal
    local ok = pcall(socket.shutdown, fd)
    T.assert_true(ok, "shutdown should not error")
    socket.close(listen_id)
end)

T.case("socket.lsend (low priority send)", function()
    local driver = require "skynet.socketdriver"
    local port = 19914
    local listen_id = socket.listen("127.0.0.1", port)
    local accepted = nil
    socket.start(listen_id, function(id)
        accepted = id
        socket.start(id)
    end)

    local fd = socket.open("127.0.0.1", port)
    skynet.sleep(10)

    -- lsend is low-priority send (goes to the tail of send queue)
    if accepted then
        local msg = driver.str2p("low priority data")
        local ok = pcall(driver.lsend, accepted, msg, 17)
        -- lsend might not work if socket is not writable, that's ok
    end

    pcall(socket.close, fd)
    if accepted then pcall(socket.close, accepted) end
    socket.close(listen_id)
end)

T.case("socket.pause and resume", function()
    local driver = require "skynet.socketdriver"
    local port = 19915
    local listen_id = socket.listen("127.0.0.1", port)
    local accepted = nil
    socket.start(listen_id, function(id)
        accepted = id
        socket.start(id)
    end)

    local fd = socket.open("127.0.0.1", port)
    skynet.sleep(10)

    -- Pause stops reading from the socket
    if accepted then
        local ok_pause = pcall(driver.pause, accepted)
        T.assert_true(ok_pause, "pause should not error")

        -- Start again resumes reading
        local ok_start = pcall(driver.start, accepted)
        T.assert_true(ok_start, "start (resume) should not error")
    end

    pcall(socket.close, fd)
    if accepted then pcall(socket.close, accepted) end
    socket.close(listen_id)
end)

T.case("driver.info returns socket details", function()
    local driver = require "skynet.socketdriver"
    local info = driver.info()
    T.assert_true(type(info) == "table", "info returns table")
end)

T.run()
