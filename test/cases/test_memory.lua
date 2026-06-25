-- test_memory.lua — Test skynet.memory (memory reporting)
local skynet = require "skynet"
require "skynet.manager"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                local memory = require "skynet.memory"
                testlib.assert_true(type(memory) == "table", "memory module should be a table")

                -- Test memory.total returns total memory in KB
                local total = memory.total()
                testlib.assert_true(type(total) == "number", "total should be a number")
                testlib.assert_true(total > 0, "total should be positive")

                -- Test memory.current returns memory for current service
                local self_mem = memory.current()
                testlib.assert_true(type(self_mem) == "number", "current memory should be a number")

                -- Test memory.block returns block count
                local block = memory.block()
                testlib.assert_true(type(block) == "number", "block should be a number")

                -- Test memory.info returns detailed info table
                local info = memory.info()
                testlib.assert_true(type(info) == "table", "info should be a table")
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
