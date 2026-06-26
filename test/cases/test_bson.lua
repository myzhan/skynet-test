-- test_bson.lua — Test lua-bson.c (BSON encode/decode)
local skynet = require "skynet"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                local bson = require "bson"
                testlib.assert_true(type(bson) == "table", "bson module should be a table")
                testlib.assert_true(type(bson.encode) == "function", "bson.encode should exist")
                testlib.assert_true(type(bson.decode) == "function", "bson.decode should exist")

                -- bson.encode returns a bson userdata, decode via :decode() or bson.decode(ud)
                local encoded = bson.encode({ name = "test", value = 42 })
                testlib.assert_true(encoded ~= nil, "encode should return bson object")

                local decoded = bson.decode(encoded)
                testlib.assert_eq("test", decoded.name, "decoded name")
                testlib.assert_eq(42, decoded.value, "decoded value")

                -- Test with string values
                local str_enc = bson.encode({ msg = "hello world", path = "/usr/local/bin" })
                local str_dec = bson.decode(str_enc)
                testlib.assert_eq("hello world", str_dec.msg, "decoded msg")
                testlib.assert_eq("/usr/local/bin", str_dec.path, "decoded path")

                -- Test with boolean values
                local bool_enc = bson.encode({ active = true, deleted = false })
                local bool_dec = bson.decode(bool_enc)
                testlib.assert_eq(true, bool_dec.active, "decoded bool true")
                testlib.assert_eq(false, bool_dec.deleted, "decoded bool false")

                -- Test with nested documents
                local nest_enc = bson.encode({ outer = { inner = { deep = "value" } } })
                local nest_dec = bson.decode(nest_enc)
                testlib.assert_eq("value", nest_dec.outer.inner.deep, "nested decode")

                -- Test with arrays
                local arr_enc = bson.encode({ items = { 10, 20, 30, 40, 50 } })
                local arr_dec = bson.decode(arr_enc)
                testlib.assert_eq(10, arr_dec.items[1], "array[1]")
                testlib.assert_eq(50, arr_dec.items[5], "array[5]")

                -- Test with floating point
                local float_enc = bson.encode({ pi = 3.14159, neg = -2.5 })
                local float_dec = bson.decode(float_enc)
                testlib.assert_true(math.abs(float_dec.pi - 3.14159) < 0.0001, "float pi")
                testlib.assert_eq(-2.5, float_dec.neg, "float neg")

                -- Test bson.null
                testlib.assert_true(bson.null ~= nil, "bson.null should exist")

                -- Test bson.objectid
                local oid = bson.objectid()
                testlib.assert_true(oid ~= nil, "objectid should return value")

                -- generate two objectids - should be different
                local oid2 = bson.objectid()
                testlib.assert_ne(tostring(oid), tostring(oid2), "objectids should be unique")

                -- Test bson.date
                local date = bson.date(1000000)
                testlib.assert_true(date ~= nil, "bson.date should return value")

                -- Test bson.timestamp
                local ts = bson.timestamp(1234567890, 1)
                testlib.assert_true(ts ~= nil, "bson.timestamp should return value")

                -- Test bson.int64
                local i64 = bson.int64(123456789012345)
                testlib.assert_true(i64 ~= nil, "bson.int64 should return value")

                -- Test encode with int64
                local i64_enc = bson.encode({ bignum = bson.int64(9007199254740992) })
                local i64_dec = bson.decode(i64_enc)
                testlib.assert_true(i64_dec.bignum ~= nil, "int64 should decode")

                -- Test bson.binary
                local bin = bson.binary("raw binary data")
                testlib.assert_true(bin ~= nil, "bson.binary should return value")

                -- Test bson.regex
                local rgx = bson.regex("^hello.*$", "i")
                testlib.assert_true(rgx ~= nil, "bson.regex should return value")

                -- Test encode_order (ordered keys)
                local ordered = bson.encode_order("b", 2, "a", 1, "c", 3)
                testlib.assert_true(ordered ~= nil, "encode_order should return bson")
                local ordered_dec = bson.decode(ordered)
                testlib.assert_eq(2, ordered_dec.b, "ordered b")
                testlib.assert_eq(1, ordered_dec.a, "ordered a")
                testlib.assert_eq(3, ordered_dec.c, "ordered c")

                -- Test empty document
                local empty_enc = bson.encode({})
                local empty_dec = bson.decode(empty_enc)
                testlib.assert_true(type(empty_dec) == "table", "empty doc should decode to table")

                -- Test #bson returns length
                local len = #encoded
                testlib.assert_true(type(len) == "number", "bson length should be number")
                testlib.assert_true(len > 0, "bson length should be positive")

                -- Test tostring on bson object
                local str = tostring(encoded)
                testlib.assert_true(type(str) == "string", "tostring should work on bson")
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
