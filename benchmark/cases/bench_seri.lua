local skynet = require "skynet"

local test_data = {
    cmd = "login",
    uid = 123456,
    token = "abcdef1234567890",
    params = {1, 2, 3, "hello", true},
}

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local hpc = skynet.hpc
            local iterations = 200000

            local packed, sz = skynet.pack(test_data)
            for _ = 1, 1000 do
                skynet.pack(test_data)
                skynet.unpack(packed, sz)
            end

            collectgarbage("stop")

            local t0 = hpc()
            for _ = 1, iterations do
                skynet.pack(test_data)
            end
            local cpu_encode = (hpc() - t0) / 1e9

            t0 = hpc()
            for _ = 1, iterations do
                skynet.unpack(packed, sz)
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
                detail = string.format("pack %.0f ops/s, unpack %.0f ops/s", encode_ops, decode_ops),
            }))
        end
    end)
end)
