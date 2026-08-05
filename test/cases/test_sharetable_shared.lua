-- test_sharetable_shared.lua — Regression tests for sharetable read-only invariants.
--
-- Guards two low-level fixes from cloudwu/skynet #2161 (both in 3rd/lua):
--
--   1. ltable.c luaH_set() must reject writes to a shared table. luaH_pset()
--      stores an EXISTING key in place and returns HOK, so the isshared() guard
--      inside luaH_finishset() is never reached — lua_rawset could silently
--      overwrite shared data. The fix adds the guard at luaH_set()'s entry,
--      matching luaH_setint().
--
--   2. lgc.c traversearray() must use ispurewhite() (== iswhite && !isshared),
--      not a bare iswhite(). Shared objects are never swept, so their colour
--      stays white forever; a bare iswhite() lets a consumer VM mark and
--      traverse the shared subgraph held in the ARRAY part of a plain table,
--      inflating its own GCmarked and stalling automatic GC.
--
-- Both bugs reproduced on the pre-fix submodule (rawset corrupted shared data;
-- GC growth ran ~38MB). After the fix both invariants hold.
local skynet = require "skynet"
local sharetable = require "skynet.sharetable"
local T = require "testlib"

-- sharetable spawns its backing service lazily on first use; let it come up.
T.setup(function()
    skynet.sleep(10)
end)

T.case("rawset cannot modify a shared table", function()
    sharetable.loadtable("st_ro_guard", { existing = 1, [1] = 10 })
    local shared = assert(sharetable.query("st_ro_guard"), "query returned nil")

    -- Existing string key: on a broken build luaH_pset stores in place and
    -- returns HOK, bypassing the guard. The fix makes luaH_set reject it.
    local ok = pcall(rawset, shared, "existing", 99)
    T.assert_false(ok, "rawset on an existing string key must be rejected")
    T.assert_eq(1, shared.existing, "shared string value must stay unchanged")

    -- Existing integer key (routes via psetint, not luaH_setint).
    local ok_int = pcall(rawset, shared, 1, 88)
    T.assert_false(ok_int, "rawset on an existing integer key must be rejected")
    T.assert_eq(10, shared[1], "shared array value must stay unchanged")

    -- Control: adding a new key was already refused via luaH_finishset.
    local ok_new = pcall(rawset, shared, "brandnew", 77)
    T.assert_false(ok_new, "rawset adding a new key must be rejected")
    T.assert_eq(nil, shared.brandnew, "new key must not be inserted")
end)

T.case("consumer GC does not absorb shared array-part payload", function()
    local ITEMS = 200000
    local GARBAGE = 300000
    local LIMIT_KB = 1024   -- fixed build stays a few KB; broken build ran ~38MB

    -- Owner (matrix) state publishes a large config table.
    local cfg = {}
    for i = 1, ITEMS do
        cfg[i] = { id = i, v = i * 3 }
    end
    sharetable.loadtable("st_gc_accounting", cfg)
    cfg = nil
    collectgarbage("collect")

    local shared = assert(sharetable.query("st_gc_accounting"), "query returned nil")

    -- The shared reference must sit in the ARRAY part of a plain table and stay
    -- reachable: that is the path guarded by traversearray().
    local cache = { shared }
    collectgarbage("collect")   -- sets GCmarked, which setpause() turns into the next threshold

    -- From here rely on the automatic collector while producing garbage.
    local base = collectgarbage("count")
    for i = 1, GARBAGE do
        local _ = { i, i * 2, tostring(i) }
    end
    local growth = collectgarbage("count") - base

    T.assert_true(cache[1] ~= nil, "cache must stay alive through the measurement")
    T.assert_true(growth < LIMIT_KB,
        string.format("automatic GC memory growth %.0fKB must stay below %dKB "
            .. "(inflated growth means the consumer marked the shared subgraph)",
            growth, LIMIT_KB))
end)

T.run()
