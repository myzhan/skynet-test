-- test_coroutine.lua — Test skynet.coroutine module
local skynet = require "skynet"
local skynetco = require "skynet.coroutine"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                -- Test create/resume
                local co = skynetco.create(function(a, b)
                    return a + b
                end)
                testlib.assert_true(co ~= nil, "create should return a coroutine")

                local ok_co, result = skynetco.resume(co, 1, 2)
                testlib.assert_true(ok_co, "resume should succeed")
                testlib.assert_eq(3, result, "1 + 2 = 3")

                -- Test status
                local status = skynetco.status(co)
                testlib.assert_eq("dead", status, "completed coroutine should be dead")

                -- Test isyieldable
                local yieldable = skynetco.isyieldable()
                testlib.assert_true(yieldable, "main thread should be yieldable")

                -- Test wrap
                local wrapped = skynetco.wrap(function(x)
                    return x * 2
                end)
                testlib.assert_eq(10, wrapped(5), "wrap should return function")

                -- Test yield
                local co2 = skynetco.create(function()
                    skynetco.yield("hello")
                    return "world"
                end)
                skynetco.resume(co2)
                local ok2, val = skynetco.resume(co2)
                testlib.assert_true(ok2, "resume after yield should work")
                testlib.assert_eq("world", val, "yield then resume")
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
