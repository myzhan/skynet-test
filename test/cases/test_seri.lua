-- test_seri.lua — Test lua-seri.c serialization edge cases
local skynet = require "skynet"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                local function roundtrip(...)
                    local data, sz = skynet.pack(...)
                    if sz then
                        return skynet.unpack(data, sz)
                    else
                        return skynet.unpack(data)
                    end
                end

                -- Test nil
                local v = roundtrip(nil)
                testlib.assert_eq(nil, v, "nil roundtrip")

                -- Test booleans
                testlib.assert_eq(true, roundtrip(true), "true roundtrip")
                testlib.assert_eq(false, roundtrip(false), "false roundtrip")

                -- Test number zero
                testlib.assert_eq(0, roundtrip(0), "zero roundtrip")

                -- Test small integers (byte range)
                testlib.assert_eq(1, roundtrip(1), "byte int 1")
                testlib.assert_eq(127, roundtrip(127), "byte int 127")
                testlib.assert_eq(255, roundtrip(255), "byte int 255")

                -- Test word-sized integers
                testlib.assert_eq(256, roundtrip(256), "word int 256")
                testlib.assert_eq(65535, roundtrip(65535), "word int 65535")

                -- Test dword-sized integers
                testlib.assert_eq(65536, roundtrip(65536), "dword int 65536")
                testlib.assert_eq(2147483647, roundtrip(2147483647), "dword int max")

                -- Test negative integers
                testlib.assert_eq(-1, roundtrip(-1), "negative -1")
                testlib.assert_eq(-128, roundtrip(-128), "negative -128")
                testlib.assert_eq(-32768, roundtrip(-32768), "negative -32768")
                testlib.assert_eq(-2147483648, roundtrip(-2147483648), "negative min int32")

                -- Test large integers (qword)
                local big = 2^53 - 1
                testlib.assert_eq(big, roundtrip(big), "large int 2^53-1")

                -- Test floating point
                testlib.assert_eq(3.14, roundtrip(3.14), "float 3.14")
                testlib.assert_eq(-0.5, roundtrip(-0.5), "float -0.5")
                testlib.assert_eq(1e100, roundtrip(1e100), "float 1e100")
                testlib.assert_eq(1e-100, roundtrip(1e-100), "float 1e-100")

                -- Test empty string
                testlib.assert_eq("", roundtrip(""), "empty string")

                -- Test short strings (1 to 31 bytes encoded directly in cookie)
                for i = 1, 31 do
                    local s = string.rep("a", i)
                    testlib.assert_eq(s, roundtrip(s), "short string len " .. i)
                end

                -- Test long string (> 31 bytes)
                local long_str = string.rep("x", 100)
                testlib.assert_eq(long_str, roundtrip(long_str), "long string 100")

                local very_long = string.rep("y", 10000)
                testlib.assert_eq(very_long, roundtrip(very_long), "very long string 10000")

                -- Test empty table
                local t = roundtrip({})
                testlib.assert_true(type(t) == "table", "empty table roundtrip")

                -- Test array table
                local arr = {1, 2, 3, 4, 5}
                local a1, a2, a3, a4, a5 = roundtrip(arr)[1], roundtrip(arr)[2], roundtrip(arr)[3], roundtrip(arr)[4], roundtrip(arr)[5]
                testlib.assert_eq(1, a1, "array[1]")
                testlib.assert_eq(5, a5, "array[5]")

                -- Test hash table
                local ht = roundtrip({ name = "test", value = 42 })
                testlib.assert_eq("test", ht.name, "hash table name")
                testlib.assert_eq(42, ht.value, "hash table value")

                -- Test nested tables
                local nested = roundtrip({ a = { b = { c = "deep" } } })
                testlib.assert_eq("deep", nested.a.b.c, "nested table")

                -- Test mixed table (array + hash)
                local mixed = roundtrip({ 1, 2, 3, key = "val" })
                testlib.assert_eq(1, mixed[1], "mixed[1]")
                testlib.assert_eq("val", mixed.key, "mixed.key")

                -- Test multiple return values
                local r1, r2, r3, r4, r5 = roundtrip("a", 1, true, nil, "b")
                testlib.assert_eq("a", r1, "multi val 1")
                testlib.assert_eq(1, r2, "multi val 2")
                testlib.assert_eq(true, r3, "multi val 3")
                testlib.assert_eq(nil, r4, "multi val 4")
                testlib.assert_eq("b", r5, "multi val 5")

                -- Test table with boolean keys
                local bool_tbl = roundtrip({ [true] = "yes", [false] = "no" })
                testlib.assert_eq("yes", bool_tbl[true], "bool key true")
                testlib.assert_eq("no", bool_tbl[false], "bool key false")

                -- Test table with integer keys
                local int_tbl = roundtrip({ [100] = "hundred", [1000] = "thousand" })
                testlib.assert_eq("hundred", int_tbl[100], "int key 100")
                testlib.assert_eq("thousand", int_tbl[1000], "int key 1000")

                -- Test pack with no arguments (empty pack)
                local empty_data, empty_sz = skynet.pack()
                testlib.assert_true(empty_data ~= nil, "pack() should return data")

                -- Test string containing NUL bytes
                local nul_str = "hello\0world\0"
                testlib.assert_eq(nul_str, roundtrip(nul_str), "string with NUL bytes")

                -- Test deeply nested table (up to reasonable depth)
                local deep = {}
                local cur = deep
                for i = 1, 15 do
                    cur.child = {}
                    cur = cur.child
                end
                cur.value = "leaf"
                local deep_rt = roundtrip(deep)
                local check = deep_rt
                for i = 1, 15 do
                    check = check.child
                end
                testlib.assert_eq("leaf", check.value, "deep nesting")
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
