local skynet = require "skynet"
local md5 = require "md5"

local short_text = "hello skynet"
local long_text = string.rep("abcdefghijklmnop", 64)

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local hpc = skynet.hpc
            local iterations = 200000

            for _ = 1, 1000 do
                md5.sumhexa(short_text)
                md5.sumhexa(long_text)
            end

            collectgarbage("stop")

            local t0 = hpc()
            for _ = 1, iterations do
                md5.sumhexa(short_text)
            end
            local cost_short = (hpc() - t0) / 1e9

            t0 = hpc()
            for _ = 1, iterations do
                md5.sumhexa(long_text)
            end
            local cost_long = (hpc() - t0) / 1e9

            collectgarbage("restart")

            local total = iterations * 2
            local cpu_total = cost_short + cost_long

            skynet.ret(skynet.pack({
                ops_per_sec = total / cpu_total,
                avg_time_ms = cpu_total / total * 1000,
                iterations = total,
                detail = string.format("short(12B) %.0f ops/s, long(1KB) %.0f ops/s",
                    iterations / cost_short,
                    iterations / cost_long),
            }))
        end
    end)
end)
