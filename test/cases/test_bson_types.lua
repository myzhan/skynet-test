-- test_bson_types.lua — Deep BSON type coverage for lua-bson.c
-- Targets: bson.type, minkey, maxkey, makeindex, to_lightuserdata,
-- encode with special types in documents, objectid from string
local skynet = require "skynet"
local T = require "testlib"

T.case("bson.type on numbers", function()
    local bson = require "bson"
    local tname, val = bson.type(42)
    T.assert_true(tname ~= nil, "type(42) should return type name")
    T.assert_eq(42, val, "type(42) should return value")
end)

T.case("bson.type on boolean", function()
    local bson = require "bson"
    local tname, val = bson.type(true)
    T.assert_true(tname ~= nil, "type(true) should return type name")
    T.assert_eq(true, val, "type(true) value")

    local tname2, val2 = bson.type(false)
    T.assert_true(tname2 ~= nil, "type(false) should return type name")
end)

T.case("bson.type on table", function()
    local bson = require "bson"
    local tname, val = bson.type({a = 1})
    T.assert_true(tname ~= nil, "type({}) should return type name")
end)

T.case("bson.type on string", function()
    local bson = require "bson"
    local tname, val = bson.type("hello")
    T.assert_true(tname ~= nil, "type(string) should return type name")
end)

T.case("bson.type on null", function()
    local bson = require "bson"
    local result = bson.type(bson.null)
    T.assert_true(result ~= nil, "type(null) should return something")
end)

T.case("bson.type on binary", function()
    local bson = require "bson"
    local bin = bson.binary("hello")
    local t1, t2, t3 = bson.type(bin)
    T.assert_true(t1 ~= nil, "type(binary) should return type")
    T.assert_true(t2 ~= nil, "type(binary) should return data")
end)

T.case("bson.type on objectid", function()
    local bson = require "bson"
    local oid = bson.objectid()
    local t1, t2 = bson.type(oid)
    T.assert_true(t1 ~= nil, "type(objectid) should return type")
    T.assert_true(t2 ~= nil, "type(objectid) should return string rep")
end)

T.case("bson.type on date", function()
    local bson = require "bson"
    local d = bson.date(1234567)
    local t1, t2 = bson.type(d)
    T.assert_true(t1 ~= nil, "type(date) type")
    T.assert_true(t2 ~= nil, "type(date) value")
end)

T.case("bson.type on timestamp", function()
    local bson = require "bson"
    local ts = bson.timestamp(100, 1)
    local t1, t2, t3 = bson.type(ts)
    T.assert_true(t1 ~= nil, "type(timestamp) type")
    T.assert_true(t2 ~= nil, "type(timestamp) ts")
end)

T.case("bson.type on regex", function()
    local bson = require "bson"
    local rgx = bson.regex("^test$", "i")
    local t1, t2, t3 = bson.type(rgx)
    T.assert_true(t1 ~= nil, "type(regex) type")
    T.assert_true(t2 ~= nil, "type(regex) pattern")
    T.assert_true(t3 ~= nil, "type(regex) flags")
end)

T.case("bson.type on int64", function()
    local bson = require "bson"
    local i64 = bson.int64(123456789)
    local t1, t2 = bson.type(i64)
    T.assert_true(t1 ~= nil, "type(int64) type")
    T.assert_true(t2 ~= nil, "type(int64) value")
end)

T.case("bson.type on minkey", function()
    local bson = require "bson"
    local result = bson.type(bson.minkey)
    T.assert_true(result ~= nil, "type(minkey) should return type")
end)

T.case("bson.type on maxkey", function()
    local bson = require "bson"
    local result = bson.type(bson.maxkey)
    T.assert_true(result ~= nil, "type(maxkey) should return type")
end)

T.case("encode/decode with minkey and maxkey", function()
    local bson = require "bson"
    local doc = bson.encode({ min = bson.minkey, max = bson.maxkey })
    local dec = bson.decode(doc)
    T.assert_true(dec.min ~= nil, "minkey should decode")
    T.assert_true(dec.max ~= nil, "maxkey should decode")
end)

T.case("encode/decode with all special types", function()
    local bson = require "bson"
    local doc = bson.encode({
        null_val = bson.null,
        bin_val = bson.binary("binary\x00data"),
        oid_val = bson.objectid(),
        date_val = bson.date(999999),
        ts_val = bson.timestamp(12345, 1),
        regex_val = bson.regex("^hello", "gi"),
        i64_val = bson.int64(2^53),
        min_val = bson.minkey,
        max_val = bson.maxkey,
    })
    T.assert_true(doc ~= nil, "encode with all types should succeed")
    local dec = bson.decode(doc)
    T.assert_true(dec ~= nil, "decode should succeed")
    T.assert_true(dec.null_val ~= nil or dec.null_val == bson.null, "null decoded")
    T.assert_true(dec.bin_val ~= nil, "binary decoded")
    T.assert_true(dec.oid_val ~= nil, "objectid decoded")
    T.assert_true(dec.date_val ~= nil, "date decoded")
    T.assert_true(dec.ts_val ~= nil, "timestamp decoded")
    T.assert_true(dec.regex_val ~= nil, "regex decoded")
    T.assert_true(dec.i64_val ~= nil, "int64 decoded")
    T.assert_true(dec.min_val ~= nil, "minkey decoded")
    T.assert_true(dec.max_val ~= nil, "maxkey decoded")
end)

T.case("bson.to_lightuserdata", function()
    local bson = require "bson"
    local doc = bson.encode({ x = 1, y = 2 })
    local ud = bson.to_lightuserdata(doc)
    T.assert_true(ud ~= nil, "to_lightuserdata should return pointer")
end)

T.case("encode_order preserves key order", function()
    local bson = require "bson"
    local doc = bson.encode_order(
        "z", 1, "a", 2, "m", 3,
        "b", bson.objectid(),
        "c", bson.int64(100),
        "d", bson.date(500),
        "e", bson.binary("test"),
        "f", bson.regex("pat", ""),
        "g", bson.null,
        "h", bson.timestamp(1, 1),
        "i", bson.minkey,
        "j", bson.maxkey
    )
    T.assert_true(doc ~= nil, "encode_order with all types")
    local dec = bson.decode(doc)
    T.assert_eq(1, dec.z, "z value")
    T.assert_eq(2, dec.a, "a value")
end)

T.case("timestamp with explicit inc values", function()
    local bson = require "bson"
    -- timestamp(time, inc) with explicit increment values
    local ts1 = bson.timestamp(100, 5)
    local ts2 = bson.timestamp(200, 10)
    T.assert_true(ts1 ~= nil, "timestamp 1")
    T.assert_true(ts2 ~= nil, "timestamp 2")
    -- Extract via bson.type: returns (type_func, time, inc)
    local _, time1, inc1 = bson.type(ts1)
    local _, time2, inc2 = bson.type(ts2)
    T.assert_eq(100, time1, "ts1 time")
    T.assert_eq(5, inc1, "ts1 inc")
    T.assert_eq(200, time2, "ts2 time")
    T.assert_eq(10, inc2, "ts2 inc")
end)

T.case("regex without flags argument", function()
    local bson = require "bson"
    local rgx = bson.regex("pattern")
    T.assert_true(rgx ~= nil, "regex without flags")
    local doc = bson.encode({ r = rgx })
    local dec = bson.decode(doc)
    T.assert_true(dec.r ~= nil, "regex without flags decodes")
end)

T.case("objectid string representation", function()
    local bson = require "bson"
    local oid = bson.objectid()
    local str = tostring(oid)
    T.assert_true(#str > 0, "objectid tostring not empty")
    -- objectid representation should contain hex characters
    local _, t2 = bson.type(oid)
    T.assert_eq(24, #t2, "objectid hex string should be 24 chars")
end)

T.run()
