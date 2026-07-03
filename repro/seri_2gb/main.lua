-- main.lua — reproduce the >2GB cross-service serialization crash.
--
-- skynet.call packs its arguments with the C serializer in
-- skynet/lualib-src/lua-seri.c. That serializer tracks the output length
-- in a 32-bit signed int (struct write_block.len). Once the serialized
-- payload exceeds 2^31 bytes (2GB) the counter overflows to a negative
-- value, seri() then calls skynet_malloc() with a huge size (NULL result)
-- and the process crashes.
local skynet = require "skynet"

local MB = 1024 * 1024

skynet.start(function()
    -- One 512MB string, referenced COUNT times in the table. The table only
    -- costs 512MB of source memory, but serializes to CHUNK * COUNT bytes.
    local CHUNK = 512 * MB
    local COUNT = 5                       -- 5 * 512MB = 2560MB serialized (> 2GB)

    skynet.error("=== lua-seri >2GB cross-service reproduction ===")
    skynet.error(string.format(
        "building table: %d refs to a %dMB string => serialized ~%dMB",
        COUNT, CHUNK // MB, (CHUNK * COUNT) // MB))

    local s = string.rep("x", CHUNK)
    local big = {}
    for i = 1, COUNT do
        big[i] = s
    end

    local sink = skynet.newservice("sink")

    skynet.error("sending big table to sink via skynet.call (this packs >2GB) ...")
    skynet.call(sink, "lua", big)

    -- Reaching here means the bug did NOT reproduce.
    skynet.error("!!! call returned normally — bug did not reproduce on this build")
    skynet.exit()
end)
