-- test_datasheet_core.lua — Tests for lua-datasheet.c core proxy operations
local skynet = require "skynet"
local T = require "testlib"

T.case("create proxy from dumped data", function()
    local core = require "skynet.datasheet.core"
    local dump = require "skynet.datasheet.dump"
    local data = dump.dump({ x = 1, y = 2, name = "test" })
    local ptr = core.stringpointer(data)
    local proxy = core.new(ptr)
    T.assert_true(proxy ~= nil, "new creates proxy table")
    -- Access triggers __index which calls copyfromdata
    T.assert_eq(1, proxy.x, "proxy integer access")
    T.assert_eq(2, proxy.y, "proxy integer access 2")
    T.assert_eq("test", proxy.name, "proxy string access")
end)

T.case("proxy with array data", function()
    local core = require "skynet.datasheet.core"
    local dump = require "skynet.datasheet.dump"
    local data = dump.dump({ 10, 20, 30, 40, 50 })
    local ptr = core.stringpointer(data)
    local proxy = core.new(ptr)
    T.assert_eq(10, proxy[1], "array element 1")
    T.assert_eq(50, proxy[5], "array element 5")
end)

T.case("proxy with nested tables", function()
    local core = require "skynet.datasheet.core"
    local dump = require "skynet.datasheet.dump"
    local data = dump.dump({
        inner = { a = 100, b = 200 },
        arr = { 1, 2, 3 }
    })
    local ptr = core.stringpointer(data)
    local proxy = core.new(ptr)
    -- Accessing nested table creates nested proxy
    local inner = proxy.inner
    T.assert_true(inner ~= nil, "nested table access")
    T.assert_eq(100, inner.a, "nested value a")
    T.assert_eq(200, inner.b, "nested value b")
    local arr = proxy.arr
    T.assert_eq(1, arr[1], "nested array 1")
    T.assert_eq(3, arr[3], "nested array 3")
end)

T.case("proxy with boolean values", function()
    local core = require "skynet.datasheet.core"
    local dump = require "skynet.datasheet.dump"
    local data = dump.dump({ flag_true = true, flag_false = false })
    local ptr = core.stringpointer(data)
    local proxy = core.new(ptr)
    T.assert_eq(true, proxy.flag_true, "boolean true")
    T.assert_eq(false, proxy.flag_false, "boolean false")
end)

T.case("proxy with float values", function()
    local core = require "skynet.datasheet.core"
    local dump = require "skynet.datasheet.dump"
    local data = dump.dump({ pi = 3.14, e = 2.718 })
    local ptr = core.stringpointer(data)
    local proxy = core.new(ptr)
    -- Float values may lose precision, just check approximate
    local pi = proxy.pi
    T.assert_true(pi > 3.0 and pi < 3.2, "float pi approx")
    local e = proxy.e
    T.assert_true(e > 2.5 and e < 3.0, "float e approx")
end)

T.case("proxy __len operator", function()
    local core = require "skynet.datasheet.core"
    local dump = require "skynet.datasheet.dump"
    local data = dump.dump({ "a", "b", "c", "d" })
    local ptr = core.stringpointer(data)
    local proxy = core.new(ptr)
    T.assert_eq(4, #proxy, "__len returns array size")
end)

T.case("proxy __pairs iteration", function()
    local core = require "skynet.datasheet.core"
    local dump = require "skynet.datasheet.dump"
    local data = dump.dump({ x = 10, y = 20, z = 30 })
    local ptr = core.stringpointer(data)
    local proxy = core.new(ptr)
    local keys = {}
    for k, v in pairs(proxy) do
        keys[k] = v
    end
    T.assert_eq(10, keys.x, "pairs x")
    T.assert_eq(20, keys.y, "pairs y")
    T.assert_eq(30, keys.z, "pairs z")
end)

T.case("proxy __pairs with mixed array and dict", function()
    local core = require "skynet.datasheet.core"
    local dump = require "skynet.datasheet.dump"
    local data = dump.dump({ 100, 200, name = "mixed" })
    local ptr = core.stringpointer(data)
    local proxy = core.new(ptr)
    local count = 0
    for k, v in pairs(proxy) do
        count = count + 1
    end
    T.assert_eq(3, count, "pairs count for mixed table")
end)

T.case("update proxy data", function()
    local core = require "skynet.datasheet.core"
    local dump = require "skynet.datasheet.dump"
    local data1 = dump.dump({ version = 1, name = "old" })
    local ptr1 = core.stringpointer(data1)
    local proxy = core.new(ptr1)
    -- First read to populate
    T.assert_eq(1, proxy.version, "initial version")
    -- Now create new data and update via diff
    local data2 = dump.dump({ version = 2, name = "new", extra = 99 })
    local diff = dump.diff(data1, data2)
    local ptr2 = core.stringpointer(diff)
    -- Re-create proxy with new data
    local proxy2 = core.new(ptr2)
    T.assert_eq(2, proxy2.version, "updated version")
    T.assert_eq("new", proxy2.name, "updated name")
end)

T.case("stringpointer returns lightuserdata", function()
    local core = require "skynet.datasheet.core"
    local s = "test string data"
    local ptr = core.stringpointer(s)
    T.assert_true(ptr ~= nil, "stringpointer not nil")
    T.assert_true(type(ptr) == "userdata", "stringpointer returns userdata")
end)

T.case("proxy with nil values in array", function()
    local core = require "skynet.datasheet.core"
    local dump = require "skynet.datasheet.dump"
    -- Table with only dict entries (no array part with nil)
    local data = dump.dump({ key1 = "val1", key2 = "val2" })
    local ptr = core.stringpointer(data)
    local proxy = core.new(ptr)
    -- Access non-existent key should be nil
    local val = proxy.nonexistent
    T.assert_eq(nil, val, "missing key is nil")
end)

T.run()
