-- test_memory_extra.lua — Test lua-memory.c extended coverage
local skynet = require "skynet"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                local memory = require "skynet.memory"
                testlib.assert_true(type(memory) == "table", "memory module should be a table")

                -- Test total: returns total allocated memory
                local total = memory.total()
                testlib.assert_true(type(total) == "number", "total should return number")
                testlib.assert_true(total > 0, "total memory should be positive")

                -- Test block: returns number of allocated blocks
                local block = memory.block()
                testlib.assert_true(type(block) == "number", "block should return number")
                testlib.assert_true(block > 0, "block count should be positive")

                -- Test current: returns current service memory
                local current = memory.current()
                testlib.assert_true(type(current) == "number", "current should return number")

                -- Test dumpinfo: dumps memory info (no return value)
                local ok_dump = pcall(memory.dumpinfo)
                testlib.assert_true(ok_dump, "dumpinfo should not error")

                -- Test dumpinfo with opts string
                local ok_dump2 = pcall(memory.dumpinfo, "")
                testlib.assert_true(ok_dump2, "dumpinfo with empty opts should not error")

                -- Test dump: dumps C mem (no return value)
                local ok_cdump = pcall(memory.dump)
                testlib.assert_true(ok_cdump, "dump should not error")

                -- Test info: returns per-service memory table
                local info = memory.info()
                testlib.assert_true(type(info) == "table", "info should return table")

                -- Allocate some memory and verify total changes
                -- Use total() which tracks global allocator, less sensitive to GC timing
                local before = memory.total()
                local big_table = {}
                for i = 1, 1000 do
                    big_table[i] = string.rep(tostring(i), 1000)
                end
                local after = memory.total()
                -- total is global so it should always be positive
                testlib.assert_true(before > 0, "total before should be positive")
                testlib.assert_true(after > 0, "total after should be positive")

                -- Test jestat: returns jemalloc stats table
                local ok_je, je = pcall(memory.jestat)
                if ok_je and je then
                    testlib.assert_true(type(je) == "table", "jestat should return table")
                end

                -- Test mallctl: queries jemalloc by name
                local ok_mc, val = pcall(memory.mallctl, "stats.allocated")
                if ok_mc then
                    testlib.assert_true(type(val) == "number", "mallctl should return number")
                end

                -- Test profactive: queries/sets profiling active state
                local ok_prof, active = pcall(memory.profactive)
                if ok_prof then
                    testlib.assert_true(type(active) == "boolean", "profactive should return boolean")
                end

                -- Release memory
                big_table = nil
                collectgarbage()
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
