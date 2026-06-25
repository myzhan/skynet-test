-- test_sharetable.lua — Test skynet.sharetable (shared tables)
local skynet = require "skynet"
require "skynet.manager"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                -- sharetable creates a service lazily — wait for it
                skynet.sleep(10)

                local sharetable = require "skynet.sharetable"
                testlib.assert_true(type(sharetable) == "table", "sharetable module should be a table")

                -- Test loadtable and query
                local ok_lt = pcall(sharetable.loadtable, "test_st1", { x = 1, y = { "hello" }, ["key"] = true })
                testlib.assert_true(ok_lt, "loadtable should succeed")
                if not ok_lt then return end

                local t = sharetable.query("test_st1")
                testlib.assert_true(t ~= nil, "query should return table")
                if t then
                    testlib.assert_eq(1, t.x, "x should be 1")
                    testlib.assert_eq(true, t.key, "key should be true")
                end
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
