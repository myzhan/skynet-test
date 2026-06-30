local skynet = require "skynet"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local svc = skynet.newservice("bench_send_service")
            local iterations = 100000

            -- Warm up
            for i = 1, 100 do
                skynet.send(svc, "lua", "noop")
            end
            skynet.call(svc, "lua", "barrier")

            -- Reset: get cpu baseline from target service
            local stat0 = skynet.call(svc, "debug", "STAT")
            local cpu_start = stat0.cpu

            for i = 1, iterations do
                skynet.send(svc, "lua", "noop")
            end
            skynet.call(svc, "lua", "barrier")

            local stat1 = skynet.call(svc, "debug", "STAT")
            local cpu_elapsed = stat1.cpu - cpu_start
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
