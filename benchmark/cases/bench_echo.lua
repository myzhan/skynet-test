-- bench_echo.lua — Benchmark echo service RPC performance
local skynet = require "skynet"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local echo_svc = skynet.newservice("bench_echo_service")
            local iterations = 5000

            -- Warm up
            for i = 1, 100 do
                skynet.call(echo_svc, "lua", "warmup")
            end

            -- Sequential benchmark (thread CPU time)
            local cpu_start = skynet.stat("cpu")
            for i = 1, iterations do
                skynet.call(echo_svc, "lua", "test")
            end
            local cpu_elapsed = skynet.stat("cpu") - cpu_start
            local ops = iterations / cpu_elapsed
            local avg = cpu_elapsed / iterations * 1000

            skynet.ret(skynet.pack({
                ops_per_sec = ops,
                avg_time_ms = avg,
                iterations = iterations,
            }))
        end
    end)
end)
