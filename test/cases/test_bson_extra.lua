-- test_bson_extra.lua — Additional BSON type coverage for lua-bson.c
local skynet = require "skynet"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                local bson = require "bson"

                -- Test encoding/decoding with bson.null
                local null_enc = bson.encode({ val = bson.null })
                local null_dec = bson.decode(null_enc)
                testlib.assert_eq(bson.null, null_dec.val, "null value should round-trip")

                -- Test encoding with bson.binary subtypes
                local bin_data = "binary\x00data\xFF\xFE"
                local bin = bson.binary(bin_data)
                local bin_enc = bson.encode({ data = bin })
                local bin_dec = bson.decode(bin_enc)
                testlib.assert_true(bin_dec.data ~= nil, "binary should decode")

                -- Test bson.regex with various patterns
                local rgx1 = bson.regex("^test$", "im")
                local rgx_enc = bson.encode({ pattern = rgx1 })
                local rgx_dec = bson.decode(rgx_enc)
                testlib.assert_true(rgx_dec.pattern ~= nil, "regex should decode")

                -- Test bson.regex with empty flags
                local rgx2 = bson.regex("simple", "")
                local rgx2_enc = bson.encode({ r = rgx2 })
                local rgx2_dec = bson.decode(rgx2_enc)
                testlib.assert_true(rgx2_dec.r ~= nil, "regex with empty flags")

                -- Test bson.date with various timestamps
                local date0 = bson.date(0)
                local date_enc = bson.encode({ d = date0 })
                local date_dec = bson.decode(date_enc)
                testlib.assert_true(date_dec.d ~= nil, "date(0) should round-trip")

                local date_large = bson.date(1719388800000)
                local dlg_enc = bson.encode({ d = date_large })
                local dlg_dec = bson.decode(dlg_enc)
                testlib.assert_true(dlg_dec.d ~= nil, "large date should decode")

                -- Test bson.timestamp with various values
                local ts1 = bson.timestamp(0, 0)
                local ts1_enc = bson.encode({ ts = ts1 })
                local ts1_dec = bson.decode(ts1_enc)
                testlib.assert_true(ts1_dec.ts ~= nil, "timestamp(0,0) should decode")

                local ts2 = bson.timestamp(2147483647, 100)
                local ts2_enc = bson.encode({ ts = ts2 })
                local ts2_dec = bson.decode(ts2_enc)
                testlib.assert_true(ts2_dec.ts ~= nil, "large timestamp should decode")

                -- Test bson.int64 with various values
                local i64_zero = bson.int64(0)
                local i64z_enc = bson.encode({ n = i64_zero })
                local i64z_dec = bson.decode(i64z_enc)
                testlib.assert_true(i64z_dec.n ~= nil, "int64(0) should decode")

                local i64_neg = bson.int64(-1000000)
                local i64n_enc = bson.encode({ n = i64_neg })
                local i64n_dec = bson.decode(i64n_enc)
                testlib.assert_true(i64n_dec.n ~= nil, "negative int64 should decode")

                local i64_max = bson.int64(9007199254740992)
                local i64m_enc = bson.encode({ n = i64_max })
                local i64m_dec = bson.decode(i64m_enc)
                testlib.assert_true(i64m_dec.n ~= nil, "large int64 should decode")

                -- Test objectid: multiple generations should be unique
                local oids = {}
                for i = 1, 10 do
                    oids[i] = tostring(bson.objectid())
                end
                for i = 2, 10 do
                    testlib.assert_ne(oids[i-1], oids[i], "objectids should be unique")
                end

                -- Test encoding with int32 range numbers
                local int_enc = bson.encode({
                    small = 1,
                    medium = 1000,
                    large = 2147483647,
                    neg_small = -1,
                    neg_large = -2147483648,
                    zero = 0,
                })
                local int_dec = bson.decode(int_enc)
                testlib.assert_eq(1, int_dec.small, "int32 small")
                testlib.assert_eq(1000, int_dec.medium, "int32 medium")
                testlib.assert_eq(2147483647, int_dec.large, "int32 max")
                testlib.assert_eq(-1, int_dec.neg_small, "int32 -1")
                testlib.assert_eq(-2147483648, int_dec.neg_large, "int32 min")
                testlib.assert_eq(0, int_dec.zero, "int32 zero")

                -- Test encoding with various float values
                local float_enc = bson.encode({
                    inf = math.huge,
                    neg_inf = -math.huge,
                    tiny = 1e-300,
                    big = 1e300,
                })
                local float_dec = bson.decode(float_enc)
                testlib.assert_eq(math.huge, float_dec.inf, "inf should round-trip")
                testlib.assert_eq(-math.huge, float_dec.neg_inf, "neg inf should round-trip")

                -- Test encoding with empty string
                local es_enc = bson.encode({ s = "" })
                local es_dec = bson.decode(es_enc)
                testlib.assert_eq("", es_dec.s, "empty string should round-trip")

                -- Test encoding with long string
                local long_str = string.rep("abcdefgh", 1000)
                local ls_enc = bson.encode({ s = long_str })
                local ls_dec = bson.decode(ls_enc)
                testlib.assert_eq(long_str, ls_dec.s, "long string should round-trip")

                -- Test encoding with deeply nested document
                local deep = { level = 1 }
                local current = deep
                for i = 2, 10 do
                    current.child = { level = i }
                    current = current.child
                end
                local deep_enc = bson.encode({ root = deep })
                local deep_dec = bson.decode(deep_enc)
                testlib.assert_eq(1, deep_dec.root.level, "deep level 1")

                -- Test encoding with mixed array and document
                local mixed = bson.encode({
                    doc = { key = "val" },
                    arr = { 1, 2, 3 },
                    num = 42,
                    str = "hello",
                    bool_t = true,
                    bool_f = false,
                    null_val = bson.null,
                })
                local mixed_dec = bson.decode(mixed)
                testlib.assert_eq("val", mixed_dec.doc.key, "mixed doc field")
                testlib.assert_eq(2, mixed_dec.arr[2], "mixed array field")
                testlib.assert_eq(42, mixed_dec.num, "mixed num field")
                testlib.assert_eq(true, mixed_dec.bool_t, "mixed bool true")
                testlib.assert_eq(false, mixed_dec.bool_f, "mixed bool false")

                -- Test encode_order with many fields
                local ordered = bson.encode_order(
                    "z", 26, "y", 25, "x", 24, "w", 23,
                    "v", 22, "u", 21, "t", 20
                )
                local ordered_dec = bson.decode(ordered)
                testlib.assert_eq(26, ordered_dec.z, "ordered z")
                testlib.assert_eq(20, ordered_dec.t, "ordered t")

                -- Test encode_order with special types
                local ordered2 = bson.encode_order(
                    "oid", bson.objectid(),
                    "date", bson.date(1000),
                    "bin", bson.binary("test"),
                    "i64", bson.int64(999)
                )
                local ordered2_dec = bson.decode(ordered2)
                testlib.assert_true(ordered2_dec.oid ~= nil, "ordered objectid")
                testlib.assert_true(ordered2_dec.date ~= nil, "ordered date")
                testlib.assert_true(ordered2_dec.bin ~= nil, "ordered binary")
                testlib.assert_true(ordered2_dec.i64 ~= nil, "ordered int64")

                -- Test encode/decode of document with many keys
                local many_keys = {}
                for i = 1, 50 do
                    many_keys["key_" .. i] = i * 10
                end
                local many_enc = bson.encode(many_keys)
                local many_dec = bson.decode(many_enc)
                testlib.assert_eq(100, many_dec.key_10, "many keys: key_10")
                testlib.assert_eq(500, many_dec.key_50, "many keys: key_50")

                -- Test tostring on special types
                local oid_str = tostring(bson.objectid())
                testlib.assert_true(#oid_str > 0, "objectid tostring should be non-empty")

                -- Test int64 arithmetic
                local a = bson.int64(100)
                local b = bson.int64(200)
                testlib.assert_true(a ~= nil, "int64 a")
                testlib.assert_true(b ~= nil, "int64 b")
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
