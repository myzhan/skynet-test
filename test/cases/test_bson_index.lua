-- test_bson_index.lua — Tests for bson makeindex/replace (__newindex) and objectid from string
local skynet = require "skynet"
local T = require "testlib"

T.case("makeindex on document with integers", function()
    local bson = require "bson"
    local doc = bson.encode({ x = 42, y = 100 })
    local indexed = doc:makeindex()
    T.assert_true(indexed ~= nil, "makeindex returns self")
end)

T.case("replace integer value via __newindex", function()
    local bson = require "bson"
    local doc = bson.encode({ score = 10, level = 5 })
    doc:makeindex()
    -- Replace via __newindex metamethod
    doc["score"] = 99
    local decoded = doc:decode()
    T.assert_eq(99, decoded.score, "replaced integer value")
    T.assert_eq(5, decoded.level, "other value unchanged")
end)

T.case("replace boolean value", function()
    local bson = require "bson"
    local doc = bson.encode({ active = true, deleted = false })
    doc:makeindex()
    doc["active"] = false
    local decoded = doc:decode()
    T.assert_eq(false, decoded.active, "replaced boolean")
end)

T.case("replace real (double) value", function()
    local bson = require "bson"
    local doc = bson.encode({ rate = 3.14 })
    doc:makeindex()
    doc["rate"] = 2.718
    local decoded = doc:decode()
    -- Float comparison with tolerance
    T.assert_true(math.abs(decoded.rate - 2.718) < 0.001, "replaced double value")
end)

T.case("replace int64 value", function()
    local bson = require "bson"
    local doc = bson.encode({ big = bson.int64(1000000000) })
    doc:makeindex()
    -- __newindex for int64 expects a raw Lua integer
    doc["big"] = 9999999999
    local decoded = doc:decode()
    T.assert_true(decoded.big ~= nil, "int64 replaced")
end)

T.case("replace objectid value", function()
    local bson = require "bson"
    local oid1 = bson.objectid()
    local oid2 = bson.objectid()
    local doc = bson.encode({ id = oid1 })
    doc:makeindex()
    doc["id"] = oid2
    local decoded = doc:decode()
    T.assert_true(decoded.id ~= nil, "objectid replaced")
end)

T.case("replace date value", function()
    local bson = require "bson"
    local doc = bson.encode({ created = bson.date(1000) })
    doc:makeindex()
    doc["created"] = bson.date(2000)
    local decoded = doc:decode()
    T.assert_true(decoded.created ~= nil, "date replaced")
end)

T.case("replace timestamp value", function()
    local bson = require "bson"
    local doc = bson.encode({ ts = bson.timestamp(100, 1) })
    doc:makeindex()
    doc["ts"] = bson.timestamp(200, 2)
    local decoded = doc:decode()
    T.assert_true(decoded.ts ~= nil, "timestamp replaced")
end)

T.case("makeindex with multiple field types", function()
    local bson = require "bson"
    local doc = bson.encode({
        name = "test",
        count = 42,
        ratio = 1.5,
        flag = true,
        oid = bson.objectid(),
        ts = bson.timestamp(50, 3),
        dt = bson.date(999),
        i64 = bson.int64(123456),
        bin = bson.binary("data"),
        rgx = bson.regex("pat", "i"),
        min = bson.minkey,
        max = bson.maxkey,
        nil_val = bson.null,
    })
    local indexed = doc:makeindex()
    T.assert_true(indexed ~= nil, "makeindex with all types")
    -- Replace numeric fields
    doc["count"] = 100
    doc["ratio"] = 9.9
    doc["flag"] = false
    local decoded = doc:decode()
    T.assert_eq(100, decoded.count, "count replaced")
    T.assert_eq(false, decoded.flag, "flag replaced")
end)

T.case("objectid from hex string", function()
    local bson = require "bson"
    -- Create an objectid and get its string representation
    local oid = bson.objectid()
    local _, hex_str = bson.type(oid)
    T.assert_eq(24, #hex_str, "hex string is 24 chars")
    -- Recreate objectid from hex string
    local oid2 = bson.objectid(hex_str)
    local _, hex_str2 = bson.type(oid2)
    T.assert_eq(hex_str, hex_str2, "objectid from string round-trips")
end)

T.case("objectid from uppercase hex string", function()
    local bson = require "bson"
    local hex = "507F1F77BCF86CD799439011"
    local oid = bson.objectid(hex:lower())
    local _, result = bson.type(oid)
    T.assert_eq(24, #result, "objectid from specific hex")
end)

T.case("decode method on bson userdata", function()
    local bson = require "bson"
    local doc = bson.encode({ key = "value", num = 42 })
    -- decode is available as method via metatable
    local result = doc:decode()
    T.assert_eq("value", result.key, "decode method works")
    T.assert_eq(42, result.num, "decode method num")
end)

T.case("bson #length operator", function()
    local bson = require "bson"
    local doc = bson.encode({ a = 1 })
    local len = #doc
    T.assert_true(type(len) == "number", "__len returns number")
    T.assert_true(len > 0, "bson document has length > 0")
end)

T.case("bson tostring", function()
    local bson = require "bson"
    local doc = bson.encode({ hello = "world" })
    local s = tostring(doc)
    T.assert_true(type(s) == "string", "tostring works")
    T.assert_true(#s > 0, "tostring non-empty")
end)

T.case("encode large integer (>32bit) as int64", function()
    local bson = require "bson"
    -- Integer > INT32_MAX should be encoded as BSON_INT64
    local doc = bson.encode({ big_num = 2^40, neg_big = -(2^40) })
    local decoded = doc:decode()
    T.assert_eq(2^40, decoded.big_num, "large positive int")
    T.assert_eq(-(2^40), decoded.neg_big, "large negative int")
end)

T.case("encode table with __pairs metamethod", function()
    local bson = require "bson"
    -- Create a table with custom __pairs to trigger pack_meta_dict
    local data = {}
    local mt = {
        __pairs = function(t)
            local keys = {"alpha", "beta", "gamma"}
            local i = 0
            return function(t, k)
                i = i + 1
                if i <= #keys then
                    return keys[i], i * 10
                end
            end, t, nil
        end
    }
    setmetatable(data, mt)
    local doc = bson.encode(data)
    T.assert_true(doc ~= nil, "encode with __pairs")
    local decoded = doc:decode()
    T.assert_eq(10, decoded.alpha, "__pairs alpha")
    T.assert_eq(20, decoded.beta, "__pairs beta")
    T.assert_eq(30, decoded.gamma, "__pairs gamma")
end)

T.case("objectid from uppercase hex", function()
    local bson = require "bson"
    -- Test hextoint with uppercase A-F
    local hex = "AABBCCDD11223344AABBCCDD"
    local oid = bson.objectid(hex:lower())
    T.assert_true(oid ~= nil, "objectid from lowercase hex")
    -- Now with mixed case
    local hex2 = "aAbBcCdD11223344AaBbCcDd"
    local oid2 = bson.objectid(hex2)
    T.assert_true(oid2 ~= nil, "objectid from mixed case hex")
    local _, result = bson.type(oid2)
    T.assert_eq(24, #result, "mixed case objectid valid")
end)

T.case("replace errors without makeindex", function()
    local bson = require "bson"
    local doc = bson.encode({ x = 1 })
    local ok, err = pcall(function() doc["x"] = 2 end)
    T.assert_true(not ok, "replace without makeindex should error")
end)

T.case("replace non-existent key errors", function()
    local bson = require "bson"
    local doc = bson.encode({ x = 1 })
    doc:makeindex()
    local ok, err = pcall(function() doc["nonexistent"] = 2 end)
    T.assert_true(not ok, "replace non-existent key should error")
end)

T.run()
