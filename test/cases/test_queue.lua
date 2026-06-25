-- test_queue.lua — Test skynet.queue message serialization
local skynet = require "skynet"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                local make_queue = require "skynet.queue"
                testlib.assert_true(type(make_queue) == "function", "skynet.queue should be a function")

                -- Test queue serializes callbacks
                local results = {}
                local q = make_queue()
                skynet.fork(function()
                    q(function()
                        results[1] = 1
                        skynet.sleep(10)
                    end)
                end)
                skynet.fork(function()
                    q(function()
                        results[2] = results[1] and 2 or -1
                    end)
                end)
                skynet.sleep(30)
                testlib.assert_eq(2, results[2], "queue should serialize execution")
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
