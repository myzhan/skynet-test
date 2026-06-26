-- test_sharedata_core.lua — Tests for lua-sharedata.c core functions
local skynet = require "skynet"
require "skynet.manager"
local T = require "testlib"

T.case("core.new and core.len", function()
    local core = require "skynet.sharedata.core"
    local ptr = core.new({ 10, 20, 30 })
    T.assert_true(ptr ~= nil, "new returns pointer")
    local len = core.len(ptr)
    T.assert_eq(3, len, "len == 3")
    core.delete(ptr)
end)

T.case("core.hashlen", function()
    local core = require "skynet.sharedata.core"
    local ptr = core.new({ x = 1, y = 2, z = 3 })
    local hlen = core.hashlen(ptr)
    T.assert_eq(3, hlen, "hashlen == 3")
    core.delete(ptr)
end)

T.case("core.getref and incref and decref", function()
    local core = require "skynet.sharedata.core"
    local ptr = core.new({ data = 1 })
    T.assert_eq(0, core.getref(ptr), "initial ref 0")
    T.assert_eq(1, core.incref(ptr), "incref to 1")
    T.assert_eq(0, core.decref(ptr), "decref to 0")
    core.delete(ptr)
end)

T.case("core.markdirty and isdirty", function()
    local core = require "skynet.sharedata.core"
    local ptr = core.new({ data = 1 })
    T.assert_eq(false, core.isdirty(ptr), "not dirty")
    core.markdirty(ptr)
    T.assert_eq(true, core.isdirty(ptr), "dirty")
    core.delete(ptr)
end)

T.case("core.index with integer key (array)", function()
    local core = require "skynet.sharedata.core"
    local ptr = core.new({ 10, 20, 30 })
    T.assert_eq(10, core.index(ptr, 1), "arr[1]")
    T.assert_eq(30, core.index(ptr, 3), "arr[3]")
    core.delete(ptr)
end)

T.case("core.index with string key", function()
    local core = require "skynet.sharedata.core"
    local ptr = core.new({ count = 42 })
    local count = core.index(ptr, "count")
    T.assert_eq(42, count, "int field")
    core.delete(ptr)
end)

T.case("core.index returns nil for missing key", function()
    local core = require "skynet.sharedata.core"
    local ptr = core.new({ x = 1 })
    T.assert_eq(nil, core.index(ptr, "nokey"), "missing key nil")
    core.delete(ptr)
end)

T.case("core.index with large integer keys in hash part", function()
    local core = require "skynet.sharedata.core"
    -- Integer keys > sizearray go into hash, exercises lookup_key KEYTYPE_INTEGER
    local ptr = core.new({ [100] = 42, [200] = 99 })
    T.assert_eq(42, core.index(ptr, 100), "hash int key 100")
    T.assert_eq(99, core.index(ptr, 200), "hash int key 200")
    T.assert_eq(nil, core.index(ptr, 300), "missing hash int key")
    core.delete(ptr)
end)

T.case("core.nextkey with array keys", function()
    local core = require "skynet.sharedata.core"
    -- nextkey with integer array keys exercises the array iteration path
    local ptr = core.new({ 10, 20, 30 })
    local keys = {}
    local k = core.nextkey(ptr, nil)
    while k ~= nil do
        keys[#keys + 1] = k
        k = core.nextkey(ptr, k)
    end
    T.assert_eq(3, #keys, "3 array keys")
    core.delete(ptr)
end)

T.case("core.nextkey with hash integer keys (key > sizearray)", function()
    local core = require "skynet.sharedata.core"
    -- When key > sizearray, nextkey goes through the hash part integer path
    local ptr = core.new({ [100] = 42, [200] = 99 })
    local keys = {}
    local k = core.nextkey(ptr, nil)
    while k ~= nil do
        keys[#keys + 1] = k
        k = core.nextkey(ptr, k)
    end
    T.assert_true(#keys == 2, "2 hash int keys")
    core.delete(ptr)
end)

T.case("core.nextkey iteration", function()
    local core = require "skynet.sharedata.core"
    local ptr = core.new({ a = 1, b = 2 })
    local k = core.nextkey(ptr, nil)
    T.assert_true(k ~= nil, "first key not nil")
    local k2 = core.nextkey(ptr, k)
    T.assert_true(k2 ~= nil, "second key not nil")
    local k3 = core.nextkey(ptr, k2)
    T.assert_eq(nil, k3, "no third key")
    core.delete(ptr)
end)

T.case("core.delete with nested tables", function()
    local core = require "skynet.sharedata.core"
    local ptr = core.new({ nested = { deep = { x = 1 } }, arr = {1, 2} })
    core.delete(ptr)
    T.assert_true(true, "delete nested ok")
end)

T.case("high-level sharedata create query delete", function()
    local sharedata = require "skynet.sharedata"
    sharedata.new("sd_core_hl", {
        str = "hello", int_val = 100,
        nested = { x = 1 }, arr = { 10, 20, 30 },
    })
    local obj = sharedata.query("sd_core_hl")
    T.assert_eq("hello", obj.str, "string value")
    T.assert_eq(100, obj.int_val, "int value")
    T.assert_eq(1, obj.nested.x, "nested x")
    T.assert_eq(3, #obj.arr, "array length")
    local count = 0
    for k, v in pairs(obj) do count = count + 1 end
    T.assert_true(count >= 3, "pairs finds entries")
    sharedata.delete("sd_core_hl")
    skynet.sleep(10)
end)

T.run()
