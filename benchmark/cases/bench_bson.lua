local skynet = require "skynet"
local bson = require "bson"

local test_data = {
    name = "benchmark_user",
    age = 30,
    email = "bench@test.com",
    tags = {"lua", "skynet", "gamedev"},
    score = 99.5,
    active = true,
}

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local iterations = 100000

            local hpc = skynet.hpc
            local encoded = bson.encode(test_data)
            for _ = 1, 1000 do
                bson.encode(test_data)
                bson.decode(encoded)
            end

            collectgarbage("stop")

            local t0 = hpc()
            for _ = 1, iterations do
                bson.encode(test_data)
            end
            local cpu_encode = (hpc() - t0) / 1e9

            t0 = hpc()
            for _ = 1, iterations do
                bson.decode(encoded)
            end
            local cpu_decode = (hpc() - t0) / 1e9

            collectgarbage("restart")

            local encode_ops = iterations / cpu_encode
            local decode_ops = iterations / cpu_decode
            local total = iterations * 2
            local cpu_total = cpu_encode + cpu_decode

            skynet.ret(skynet.pack({
                ops_per_sec = total / cpu_total,
                avg_time_ms = cpu_total / total * 1000,
                iterations = total,
                detail = string.format("encode %.0f ops/s, decode %.0f ops/s", encode_ops, decode_ops),
            }))
        end
    end)
end)
