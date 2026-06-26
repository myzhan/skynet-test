-- test_skynet_extra.lua — Additional skynet core tests for lua-skynet.c coverage
-- Targets: trace, redirect, command variants, send with name
local skynet = require "skynet"
require "skynet.manager"
local T = require "testlib"

T.case("skynet.tracelog with tag and user string", function()
    -- skynet.tracelog = c.trace (raw C function)
    -- ltrace(tag, user) just logs, doesn't return a value
    local ok = pcall(skynet.tracelog, "TEST", "trace message")
    T.assert_true(ok, "tracelog(tag, user) should not error")
end)

T.case("skynet.tracelog with level", function()
    -- ltrace(tag, user, level) - level triggers stack trace
    local ok = pcall(skynet.tracelog, "TEST", "with level", 1)
    T.assert_true(ok, "tracelog with level should not error")
end)

T.case("skynet.tracelog with coroutine", function()
    local co = coroutine.create(function()
        local x = 1
        local y = 2
        coroutine.yield()
        return x + y
    end)
    coroutine.resume(co)
    -- ltrace(tag, user, co, level)
    local ok = pcall(skynet.tracelog, "TEST", "with coroutine", co, 1)
    T.assert_true(ok, "tracelog with coroutine should not error")
end)

T.case("skynet.tracelog with deep stack (3 frames)", function()
    local function level3()
        skynet.tracelog("TEST", "deep stack", 1)
    end
    local function level2()
        level3()
    end
    local function level1()
        level2()
    end
    local ok = pcall(level1)
    T.assert_true(ok, "tracelog with deep stack should not error")
end)

T.case("skynet.tracelog with 2 stack frames", function()
    local function wrapper()
        skynet.tracelog("TEST", "two frames", 1)
    end
    local ok = pcall(wrapper)
    T.assert_true(ok, "tracelog with 2 frames")
end)

T.case("skynet.tracelog with invalid level (default path)", function()
    -- level 999 has no stack frames → index stays 0 → default case
    local ok = pcall(skynet.tracelog, "TEST", "no frames", 999)
    T.assert_true(ok, "tracelog with no valid frames")
end)

T.case("skynet.self returns address", function()
    local addr = skynet.self()
    T.assert_true(type(addr) == "number", "self should return number")
    T.assert_true(addr > 0, "self should be positive")
end)

T.case("skynet.localname", function()
    -- Register a name for this service
    skynet.register(".test_skynet_extra_svc")
    local addr = skynet.localname(".test_skynet_extra_svc")
    T.assert_true(addr ~= nil, "localname should find registered name")
    T.assert_eq(skynet.self(), addr, "localname should match self")
end)

T.case("skynet.time and now", function()
    local t = skynet.time()
    T.assert_true(type(t) == "number", "time should return number")
    T.assert_true(t > 0, "time should be positive")

    local n = skynet.now()
    T.assert_true(type(n) == "number", "now should return number")
    T.assert_true(n >= 0, "now should be non-negative")
end)

T.case("skynet.hpc returns high-precision counter", function()
    local t1 = skynet.hpc()
    T.assert_true(type(t1) == "number", "hpc should return number")
    local t2 = skynet.hpc()
    T.assert_true(t2 >= t1, "hpc should be monotonic")
end)

T.case("skynet.harbor returns harbor id", function()
    local h = skynet.harbor(skynet.self())
    T.assert_true(type(h) == "number", "harbor should return number")
    T.assert_eq(0, h, "harbor should be 0 in standalone mode")
end)

T.case("skynet.error logs message", function()
    local ok = pcall(skynet.error, "test error message from test_skynet_extra")
    T.assert_true(ok, "error logging should not fail")
end)

T.case("skynet.genid returns unique IDs", function()
    local id1 = skynet.genid()
    local id2 = skynet.genid()
    T.assert_true(type(id1) == "number", "genid returns number")
    T.assert_ne(id1, id2, "genid should return unique IDs")
end)

T.case("skynet.packstring and tostring", function()
    local msg, sz = skynet.pack("test", 42, true, {key = "val"})
    -- packstring converts lightuserdata+size to string
    local str = skynet.packstring(msg, sz)
    T.assert_true(type(str) == "string", "packstring returns string")

    -- tostring converts lightuserdata+size to string (raw copy)
    local raw = skynet.tostring(msg, sz)
    T.assert_true(type(raw) == "string", "tostring returns string")
    T.assert_eq(sz, #raw, "tostring length matches size")

    skynet.trash(msg, sz)
end)

T.case("skynet.address formatting", function()
    local addr = skynet.self()
    local str = skynet.address(addr)
    T.assert_true(type(str) == "string", "address returns string")
    T.assert_true(str:match("^:") ~= nil, "address starts with :")
end)

T.run()
