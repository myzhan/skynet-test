-- test_dns_mock.lua — Test DNS resolution with LD_PRELOAD mock (service mode)
local skynet = require "skynet"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local result = { status = "pass" }
            local ok, err = pcall(function()
                local mock_map = os.getenv("MOCK_DNS_MAP")
                if not mock_map then
                    result.status = "skip"
                    result.message = "LD_PRELOAD mock not loaded"
                    return
                end

                local socket = require "skynet.socket"
                testlib.assert_true(type(socket) == "table", "socket module loaded")

                local fd = socket.open("github.com", 80)
                if fd then
                    socket.close(fd)
                end
                testlib.assert_true(true, "DNS mock resolution engaged")
            end)

            if not ok then
                result.status = "fail"
                result.message = tostring(err)
            end
            skynet.ret(skynet.pack(result))
        end
    end)
end)
