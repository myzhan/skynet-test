-- main.lua — a consumer service's GC marks objects owned by the sharetable heap.
--
-- 3rd/lua/lgc.c:520 traversearray() uses a bare iswhite() test:
--
--     GCObject *o = gcvalarr(h, i);
--     if (o != NULL && iswhite(o)) {
--       reallymarkobject(g, o);
--
-- Sharetable objects live in the matrix Lua state and are tagged G_SHARED.
-- Every sweep function skips them (sweeplist/sweep2old/sweepgen all test
-- isshared), so they are NEVER swept and their colour stays white forever.
-- "iswhite(o) is true" therefore does not imply "o belongs to this heap".
--
-- Every other marking site guards with ispurewhite() (== iswhite && !isshared)
-- or the valiswhite() macro that wraps it. traversearray() hand-rolls its loop
-- and lost the !isshared half, so a consumer heap marks -- and fully traverses
-- -- the shared subgraph owned by another Lua state.
--
-- Only the ARRAY part is affected. The hash part goes through markvalue() ->
-- valiswhite() -> ispurewhite(), which is correct. So the bug needs the shared
-- reference to sit in the array part of a plain table:
--
--     local cache = { shared }        -- affected
--     local cache = { cfg = shared }  -- not affected
--
-- Observable effect: reallymarkobject() accumulates g->GCmarked += objsize(o),
-- so the consumer's GCmarked absorbs the whole shared payload. setpause() then
-- computes the next GC threshold from that inflated number, and the consumer's
-- automatic GC effectively stops firing -- garbage accumulates unbounded.
local skynet = require "skynet"
local sharetable = require "skynet.sharetable"

local ITEMS = 200000
local GARBAGE = 300000
local LIMIT_KB = 1024      -- a healthy build stays far below 1MB of growth

skynet.start(function()
    skynet.error("=== sharetable GC accounting reproduction ===")

    -- The owner (matrix) state publishes a large config table.
    local cfg = {}
    for i = 1, ITEMS do
        cfg[i] = { id = i, v = i * 3 }
    end
    sharetable.loadtable("bigcfg", cfg)
    cfg = nil
    collectgarbage("collect")

    local shared = assert(sharetable.query("bigcfg"))
    skynet.error(string.format("published %d items; consumer own mem = %dKB",
        ITEMS, math.floor(collectgarbage("count"))))

    -- The reference must live in the ARRAY part and stay reachable during GC,
    -- otherwise the holder table is collected and never traversed at all.
    local cache = { shared }

    -- One full GC sets GCmarked, which setpause() turns into the next threshold.
    collectgarbage("collect")

    -- From here on rely on the automatic collector: keep producing garbage and
    -- see whether it is still able to keep memory flat.
    local base = collectgarbage("count")
    for i = 1, GARBAGE do
        local _ = { i, i * 2, tostring(i) }
    end
    local growth = collectgarbage("count") - base

    skynet.error(string.format(
        "after %d garbage tables: memory growth = %.0fKB (expected < %dKB)",
        GARBAGE, growth, LIMIT_KB))

    -- Keep 'cache' alive past the measurement.
    assert(cache[1] ~= nil)

    if growth > LIMIT_KB then
        skynet.error(string.format(
            "!!! REPRODUCED: automatic GC stopped keeping up (%.0fKB > %dKB)",
            growth, LIMIT_KB))
        skynet.error("!!! consumer GCmarked was inflated by the shared subgraph")
    else
        skynet.error("bug did NOT reproduce on this build (traversearray looks fixed)")
    end
    skynet.exit()
end)
