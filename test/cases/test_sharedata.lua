-- test_sharedata.lua — Test skynet.sharedata module
local skynet = require "skynet"
require "skynet.manager"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                local sharedata = require "skynet.sharedata"
                testlib.assert_true(type(sharedata) == "table", "sharedata module should be a table")
                testlib.assert_true(type(sharedata.new) == "function", "sharedata.new should be a function")

                -- Wait for sharedatad to initialize
                skynet.sleep(10)

                -- Test new creates shared data
                local data = {
                    name = "test_sd",
                    count = 42,
                    items = { a = 1, b = 2 },
                }
                local ok_new, obj = pcall(sharedata.new, "test_sd_key_002", data)
                testlib.assert_true(ok_new, "sharedata.new should succeed")

                if ok_new and obj then
                    local obj2 = sharedata.query("test_sd_key_002")
                    testlib.assert_true(obj2 ~= nil, "sharedata.query should return object")
                    if obj2 then
                        testlib.assert_eq(42, obj2.count, "shared data count should be 42")
                        testlib.assert_eq("test_sd", obj2.name, "shared data name should match")
                    end
                end
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
