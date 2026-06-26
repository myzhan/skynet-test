-- test_skynet_log.lua — Tests for skynet-src/skynet_log.c
-- Covers: skynet_log_open, skynet_log_close, skynet_log_output, log_blob, log_socket
local skynet = require "skynet"
require "skynet.manager"
local core = require "skynet.core"
local socket = require "skynet.socket"
local T = require "testlib"

T.case("LOGON opens log file and LOGOFF closes it", function()
    local self_addr = skynet.address(skynet.self())

    -- Turn on logging for this service
    core.command("LOGON", self_addr)
    skynet.sleep(5)

    -- Send a message to self — triggers skynet_log_output for non-socket type
    skynet.send(skynet.self(), "lua", "dummy_log_msg")
    skynet.sleep(10)

    -- Turn off logging
    core.command("LOGOFF", self_addr)
    skynet.sleep(5)
end)

T.case("log output with socket message", function()
    local self_addr = skynet.address(skynet.self())

    -- Turn on logging
    core.command("LOGON", self_addr)
    skynet.sleep(5)

    -- Create a socket connection — the socket events dispatched to our service
    -- will trigger log_socket path (PTYPE_SOCKET)
    local port = 19970
    local listen_id = socket.listen("127.0.0.1", port)
    socket.start(listen_id, function(id, addr)
        socket.start(id)
        skynet.sleep(5)
        socket.close(id)
    end)
    skynet.sleep(5)

    -- Connect and disconnect — generates socket messages that get logged
    local client = socket.open("127.0.0.1", port)
    skynet.sleep(10)
    socket.write(client, "log_data_test")
    skynet.sleep(10)
    socket.close(client)
    skynet.sleep(10)

    socket.close(listen_id)

    -- Turn off logging
    core.command("LOGOFF", self_addr)
    skynet.sleep(5)

    -- Clean up the log file
    local handle = skynet.self()
    local logfile = string.format("./%08x.log", handle)
    os.remove(logfile)
end)

T.run()
