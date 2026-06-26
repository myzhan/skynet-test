-- test_seri_extra.lua — Additional serialization tests for lua-seri.c coverage
-- Targets: QWORD integers, very long strings, large arrays, __pairs metamethods
local skynet = require "skynet"
local T = require "testlib"

T.case("qword integers (> 2^31)", function()
    local big = 2^53
    local v = select(1, skynet.unpack(skynet.pack(big)))
    T.assert_eq(big, v, "2^53 should round-trip")

    local big2 = 2^40 + 123456
    local v2 = select(1, skynet.unpack(skynet.pack(big2)))
    T.assert_eq(big2, v2, "2^40+123456 should round-trip")

    local big_neg = -(2^40)
    local v3 = select(1, skynet.unpack(skynet.pack(big_neg)))
    T.assert_eq(big_neg, v3, "negative qword should round-trip")

    local max_int = math.maxinteger
    local v4 = select(1, skynet.unpack(skynet.pack(max_int)))
    T.assert_eq(max_int, v4, "math.maxinteger should round-trip")

    local min_int = math.mininteger
    local v5 = select(1, skynet.unpack(skynet.pack(min_int)))
    T.assert_eq(min_int, v5, "math.mininteger should round-trip")
end)

T.case("very long strings (> 65535 bytes)", function()
    local long_str = string.rep("A", 70000)
    local v = select(1, skynet.unpack(skynet.pack(long_str)))
    T.assert_eq(70000, #v, "70KB string length should round-trip")
    T.assert_eq(long_str, v, "70KB string content should round-trip")

    local very_long = string.rep("B", 200000)
    local v2 = select(1, skynet.unpack(skynet.pack(very_long)))
    T.assert_eq(200000, #v2, "200KB string should round-trip")
end)

T.case("large array tables (>= 31 elements)", function()
    local arr = {}
    for i = 1, 50 do
        arr[i] = i * 10
    end
    local v = select(1, skynet.unpack(skynet.pack(arr)))
    T.assert_eq(50, #v, "50-element array length")
    T.assert_eq(10, v[1], "arr[1]")
    T.assert_eq(500, v[50], "arr[50]")

    -- Exactly 31 elements (MAX_COOKIE-1 threshold)
    local arr31 = {}
    for i = 1, 31 do arr31[i] = i end
    local v31 = select(1, skynet.unpack(skynet.pack(arr31)))
    T.assert_eq(31, #v31, "31-element array")
    T.assert_eq(31, v31[31], "arr31[31]")

    -- 100 elements
    local arr100 = {}
    for i = 1, 100 do arr100[i] = string.format("item_%d", i) end
    local v100 = select(1, skynet.unpack(skynet.pack(arr100)))
    T.assert_eq(100, #v100, "100-element array")
    T.assert_eq("item_100", v100[100], "arr100[100]")
end)

T.case("table with __pairs metamethod", function()
    local mt = {}
    mt.__pairs = function(t)
        local keys = {"x", "y", "z"}
        local i = 0
        return function()
            i = i + 1
            if keys[i] then
                return keys[i], t[keys[i]]
            end
        end
    end
    local obj = setmetatable({x = 1, y = 2, z = 3}, mt)
    local v = select(1, skynet.unpack(skynet.pack(obj)))
    T.assert_eq(1, v.x, "metapairs x")
    T.assert_eq(2, v.y, "metapairs y")
    T.assert_eq(3, v.z, "metapairs z")
end)

T.case("lightuserdata serialization", function()
    -- skynet.pack internally handles lightuserdata (pointers)
    local msg, sz = skynet.pack("inner_data")
    -- Pack the lightuserdata pointer itself
    local packed = skynet.packstring(msg, sz)
    T.assert_true(type(packed) == "string", "packstring should return string")
    -- Unpack it back
    local ud, ud_sz = skynet.unpack(packed)
    T.assert_true(ud ~= nil, "should get lightuserdata back")
    T.assert_eq(sz, ud_sz, "size should match")
    -- Verify inner data
    local inner = skynet.unpack(ud, ud_sz)
    T.assert_eq("inner_data", inner, "inner data round-trip")
    skynet.trash(ud, ud_sz)
end)

T.case("mixed large table with dict part", function()
    local mixed = {}
    for i = 1, 40 do mixed[i] = i end
    mixed.name = "test"
    mixed.flag = true
    mixed.value = 3.14
    local v = select(1, skynet.unpack(skynet.pack(mixed)))
    T.assert_eq(40, #v, "array part length")
    T.assert_eq(40, v[40], "array value")
    T.assert_eq("test", v.name, "dict part name")
    T.assert_eq(true, v.flag, "dict part flag")
end)

T.case("unpack from string (not lightuserdata)", function()
    -- skynet.packstring returns a string that can be unpacked directly
    local packed = skynet.packstring("hello", 42, true)
    T.assert_true(type(packed) == "string", "packstring returns string")
    local a, b, c = skynet.unpack(packed)
    T.assert_eq("hello", a)
    T.assert_eq(42, b)
    T.assert_eq(true, c)
end)

T.case("empty arguments", function()
    -- Pack with no arguments
    local msg, sz = skynet.pack()
    T.assert_true(msg ~= nil, "pack() should return something")
    -- Unpack empty should return nothing
    local count = select("#", skynet.unpack(msg, sz))
    T.assert_eq(0, count, "unpack empty should return 0 values")
    skynet.trash(msg, sz)
end)

T.run()
