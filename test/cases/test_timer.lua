-- test_timer.lua — Test timer-related functions
local skynet = require "skynet"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                -- Test skynet.now() consistently increases
                local t1 = skynet.now()
                skynet.sleep(5)
                local t2 = skynet.now()
                testlib.assert_true(t2 > t1, "time should advance")

                -- Test skynet.sleep
                local start = skynet.now()
                skynet.sleep(20)
                local elapsed = skynet.now() - start
                testlib.assert_true(elapsed >= 10, "sleep should wait at least 10cs")

                -- Test skynet.timeout
                local fired = false
                skynet.timeout(30, function()
                    fired = true
                end)
                testlib.assert_false(fired, "timeout should not fire immediately")
                skynet.sleep(50)
                testlib.assert_true(fired, "timeout should fire after waiting")

                -- Test skynet.timeout with zero
                local zero_fired = false
                skynet.timeout(0, function()
                    zero_fired = true
                end)
                skynet.sleep(5)
                testlib.assert_true(zero_fired, "zero timeout should fire immediately")

                -- Multiple timeouts
                local count = 0
                for i = 1, 5 do
                    skynet.timeout(10 * i, function() count = count + 1 end)
                end
                skynet.sleep(100)
                testlib.assert_eq(5, count, "all 5 timeouts should fire")
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
