-- test_datasheet.lua — Test skynet.datasheet (versioned data sheets)
local skynet = require "skynet"
require "skynet.manager"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                local builder = require "skynet.datasheet.builder"
                local datasheet = require "skynet.datasheet"
                testlib.assert_true(type(builder) == "table", "builder module should be a table")
                testlib.assert_true(type(datasheet) == "table", "datasheet module should be a table")

                -- Create a datasheet
                local ok_new = pcall(builder.new, "test_ds_001", { a = 1, b = { 2, 3 }, c = "hello" })
                testlib.assert_true(ok_new, "builder.new should succeed")

                -- Query the datasheet
                local t = datasheet.query("test_ds_001")
                testlib.assert_true(t ~= nil, "datasheet.query should return table")
                testlib.assert_eq(1, t.a, "t.a should be 1")
                testlib.assert_eq("hello", t.c, "t.c should be 'hello'")

                -- Update the datasheet
                local ok_upd = pcall(builder.update, "test_ds_001", { a = 10, c = "world" })
                testlib.assert_true(ok_upd, "builder.update should succeed")

                -- Wait for update propagation
                skynet.sleep(10)

                -- Verify updates
                testlib.assert_eq(10, t.a, "t.a should be 10 after update")
                testlib.assert_eq("world", t.c, "t.c should be 'world' after update")
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
