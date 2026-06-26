-- test_sharedata_extra.lua — Test lua-sharedata.c core operations (new/delete/box/index/nextkey/len/etc)
local skynet = require "skynet"
require "skynet.manager"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                local sharedata = require "skynet.sharedata"

                skynet.sleep(10)

                -- Test creating sharedata with various data types
                sharedata.new("sd_extra_001", {
                    str = "hello",
                    num = 3.14,
                    int_val = 100,
                    bool_val = true,
                    nested = { x = 1, y = 2, z = { deep = "value" } },
                    arr = { 10, 20, 30, 40, 50 },
                })

                -- Query and verify all types
                local obj = sharedata.query("sd_extra_001")
                testlib.assert_true(obj ~= nil, "query should return object")
                testlib.assert_eq("hello", obj.str, "string value")
                testlib.assert_true(math.abs(obj.num - 3.14) < 0.001, "float value")
                testlib.assert_eq(100, obj.int_val, "int value")
                testlib.assert_eq(true, obj.bool_val, "bool value")

                -- Test nested access (exercises index operation)
                testlib.assert_eq(1, obj.nested.x, "nested x")
                testlib.assert_eq(2, obj.nested.y, "nested y")
                testlib.assert_eq("value", obj.nested.z.deep, "deep nested")

                -- Test array access (exercises index with numeric keys)
                testlib.assert_eq(10, obj.arr[1], "arr[1]")
                testlib.assert_eq(50, obj.arr[5], "arr[5]")

                -- Test # operator (exercises len)
                testlib.assert_eq(5, #obj.arr, "array length")

                -- Test pairs iteration (exercises nextkey)
                local keys = {}
                for k, v in pairs(obj) do
                    keys[k] = true
                end
                testlib.assert_true(keys.str, "pairs should find str")
                testlib.assert_true(keys.num, "pairs should find num")
                testlib.assert_true(keys.nested, "pairs should find nested")
                testlib.assert_true(keys.arr, "pairs should find arr")

                -- Test pairs on nested table
                local nested_keys = {}
                for k, v in pairs(obj.nested) do
                    nested_keys[k] = true
                end
                testlib.assert_true(nested_keys.x, "nested pairs should find x")
                testlib.assert_true(nested_keys.y, "nested pairs should find y")
                testlib.assert_true(nested_keys.z, "nested pairs should find z")

                -- Test ipairs on array
                local arr_count = 0
                for i, v in ipairs(obj.arr) do
                    arr_count = arr_count + 1
                end
                testlib.assert_eq(5, arr_count, "ipairs should iterate 5 elements")

                -- Test update: modify existing shared data
                sharedata.update("sd_extra_001", {
                    str = "world",
                    num = 2.71,
                    int_val = 200,
                    bool_val = false,
                    nested = { x = 10, y = 20 },
                    arr = { 100, 200, 300 },
                })
                skynet.sleep(20)

                -- Verify update propagated
                testlib.assert_eq("world", obj.str, "updated string")
                testlib.assert_eq(200, obj.int_val, "updated int")
                testlib.assert_eq(false, obj.bool_val, "updated bool")
                testlib.assert_eq(10, obj.nested.x, "updated nested x")
                testlib.assert_eq(3, #obj.arr, "updated array length")

                -- Test creating another sharedata entry
                sharedata.new("sd_extra_002", {
                    items = { { id = 1, name = "a" }, { id = 2, name = "b" } },
                    config = { timeout = 30, retries = 3 },
                })
                local obj2 = sharedata.query("sd_extra_002")
                testlib.assert_eq(1, obj2.items[1].id, "nested array item id")
                testlib.assert_eq("b", obj2.items[2].name, "nested array item name")
                testlib.assert_eq(30, obj2.config.timeout, "config timeout")

                -- Test delete
                sharedata.delete("sd_extra_002")
                skynet.sleep(10)

                -- Test flush (refreshes all cached objects)
                sharedata.flush()

                -- Clean up
                sharedata.delete("sd_extra_001")
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
