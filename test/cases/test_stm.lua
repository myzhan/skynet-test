-- test_stm.lua — Test skynet.stm (Software Transactional Memory)
local skynet = require "skynet"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                local stm = require "skynet.stm"
                testlib.assert_true(type(stm) == "table", "stm module should be a table")
                testlib.assert_true(type(stm.new) == "function", "stm.new should be a function")
                testlib.assert_true(type(stm.copy) == "function", "stm.copy should be a function")
                testlib.assert_true(type(stm.newcopy) == "function", "stm.newcopy should be a function")

                -- Test stm.new creates a writer object
                local writer = stm.new(skynet.pack(1, 2, 3))
                testlib.assert_true(writer ~= nil, "stm.new should return writer")

                -- Test stm.copy creates a copy handle (lightuserdata)
                local copy = stm.copy(writer)
                testlib.assert_true(copy ~= nil, "stm.copy should return copy handle")

                -- Test stm.newcopy creates a reader from copy handle
                local reader = stm.newcopy(copy)
                testlib.assert_true(reader ~= nil, "stm.newcopy should return reader")

                -- Test reader can read value
                local succ, a, b, c = reader(skynet.unpack)
                testlib.assert_true(succ, "reader should read successfully")
                testlib.assert_eq(1, a, "stm read value a")
                testlib.assert_eq(2, b, "stm read value b")
                testlib.assert_eq(3, c, "stm read value c")

                -- Test writer update
                writer(skynet.pack("hello", "world"))

                -- Read again - should get new value
                local succ2, v1, v2 = reader(skynet.unpack)
                testlib.assert_true(succ2, "reader should read updated value")
                testlib.assert_eq("hello", v1, "updated value 1")
                testlib.assert_eq("world", v2, "updated value 2")

                -- Test reading same value again (no update) returns false
                local succ3 = reader(skynet.unpack)
                testlib.assert_false(succ3, "reader should return false when no new update")

                -- Test update again
                writer(skynet.pack(42))
                local succ4, val = reader(skynet.unpack)
                testlib.assert_true(succ4, "reader should see second update")
                testlib.assert_eq(42, val, "second update value")
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
