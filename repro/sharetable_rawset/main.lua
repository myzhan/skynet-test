-- main.lua — rawset() silently writes into a shared table.
--
-- A sharetable is meant to be read-only: its memory lives in the matrix Lua
-- state and is mapped into every service that queried it, with no locking.
-- Plain assignment is rejected, but rawset() reaches the storage through a
-- different path that is missing the guard:
--
--     rawset  ->  lua_rawset      (lapi.c)
--             ->  aux_rawset      (lapi.c)
--             ->  luaH_set        (ltable.c:1202)   <-- no isshared() check
--             ->  luaH_pset       (ltable.c)
--             ->  luaH_psetshortstr / psetint
--                    existing key: setobj(...) writes in place, returns HOK
--
-- luaH_set only consults luaH_finishset when pset returns something other
-- than HOK:
--
--     int hres = luaH_pset(t, key, value);
--     if (hres != HOK)
--       luaH_finishset(L, t, key, value, hres);
--
-- but luaH_pset is not a pure lookup -- for a key that already exists it
-- performs the store itself and returns HOK. The isshared() check inside
-- luaH_finishset is then never reached.
--
-- Hence the split observed below: overwriting an EXISTING key succeeds and
-- corrupts the shared data, while ADDING a new key is correctly refused
-- (insertkey fails, control falls through to luaH_finishset, guard fires).
--
-- A regression test must cover both. Testing only the "new key" case would
-- report success on a still-broken build.
--
-- Note luaH_setint (ltable.c) *does* carry the check, and so does
-- luaV_finishset (lvm.c) for ordinary assignment -- luaH_set is the odd one out.
local skynet = require "skynet"
local sharetable = require "skynet.sharetable"

skynet.start(function()
    skynet.error("=== sharetable rawset reproduction ===")

    sharetable.loadtable("cfg", { existing = 1, [1] = 10 })
    local shared = assert(sharetable.query("cfg"))
    skynet.error(string.format("published: existing=%s [1]=%s",
        tostring(shared.existing), tostring(shared[1])))

    local reproduced = false

    -- Baseline: ordinary assignment is stopped by luaV_finishset.
    local ok = pcall(function() shared.existing = 2 end)
    skynet.error(string.format("plain assign      -> %s, existing=%s",
        ok and "ACCEPTED" or "rejected", tostring(shared.existing)))

    -- The bug: existing string key takes luaH_pset's in-place store.
    ok = pcall(rawset, shared, "existing", 99)
    skynet.error(string.format("rawset existing   -> %s, existing=%s (expected 1)",
        ok and "ACCEPTED" or "rejected", tostring(shared.existing)))
    if ok or shared.existing ~= 1 then
        reproduced = true
    end

    -- Same for an existing integer key (rawset routes to psetint, not luaH_setint).
    ok = pcall(rawset, shared, 1, 88)
    skynet.error(string.format("rawset [1]        -> %s, [1]=%s (expected 10)",
        ok and "ACCEPTED" or "rejected", tostring(shared[1])))
    if ok or shared[1] ~= 10 then
        reproduced = true
    end

    -- Control: adding a key goes through luaH_finishset and is refused.
    ok = pcall(rawset, shared, "brandnew", 77)
    skynet.error(string.format("rawset new key    -> %s, brandnew=%s (expected nil)",
        ok and "ACCEPTED" or "rejected", tostring(shared.brandnew)))

    if reproduced then
        skynet.error("!!! REPRODUCED: rawset bypassed the read-only guard")
        skynet.error("!!! shared data owned by the matrix state was overwritten")
    else
        skynet.error("bug did NOT reproduce on this build (luaH_set looks fixed)")
    end
    skynet.exit()
end)
