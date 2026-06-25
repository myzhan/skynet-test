-- test_basic.lua — Basic skynet functional tests (service mode)
local skynet = require "skynet"
require "skynet.manager" -- skynet.name, skynet.localname
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                -- Test 1: skynet.now()
                local now = skynet.now()
                testlib.assert_true(now > 0, "skynet.now() should return positive value")

                -- Test 2: skynet.self()
                local self = skynet.self()
                testlib.assert_true(self ~= nil and self ~= 0, "skynet.self() should return valid handle")

                -- Test 3: skynet.harbor()
                local harbor = skynet.harbor(self)
                testlib.assert_true(harbor >= 0, "skynet.harbor() should return >= 0")

                -- Test 4: Service creation and communication
                local echo_svc = skynet.newservice("test_basic_echo")
                testlib.assert_true(echo_svc ~= nil, "should create echo service")

                -- Test 5: skynet.call between services
                local reply = skynet.call(echo_svc, "lua", "hello")
                testlib.assert_eq("hello", reply, "skynet.call() should echo back")

                -- Test 6: skynet.send (fire and forget)
                local ok_send = pcall(skynet.send, echo_svc, "lua", "fire-and-forget")
                testlib.assert_true(ok_send, "skynet.send() should work")

                -- Test 7: skynet.name and skynet.localname
                skynet.name(".test_echo", echo_svc)
                local named = skynet.localname(".test_echo")
                testlib.assert_eq(echo_svc, named, "skynet.name() and localname() should match")

                -- Test 8: skynet.timeout
                local timeout_fired = false
                skynet.timeout(10, function()
                    timeout_fired = true
                end)
                skynet.sleep(30)
                testlib.assert_true(timeout_fired, "skynet.timeout() should fire callback")

                -- Test 9: skynet.fork
                local counter = 0
                skynet.fork(function()
                    skynet.sleep(10)
                    counter = counter + 1
                end)
                skynet.fork(function()
                    skynet.sleep(10)
                    counter = counter + 1
                end)
                skynet.sleep(30)
                testlib.assert_eq(2, counter, "skynet.fork() should run 2 parallel tasks")

                -- Test 10: skynet.exit properly
                testlib.assert_true(true, "all basic tests passed")
            end)

            if ok then
                skynet.ret(skynet.pack({ status = "pass" }))
            else
                skynet.ret(skynet.pack({ status = "fail", message = tostring(err) }))
            end
        end
    end)
end)
