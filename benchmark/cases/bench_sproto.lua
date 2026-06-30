local skynet = require "skynet"
local sproto = require "sproto"

local sp = sproto.parse [[
.Person {
    name 0 : string
    age 1 : integer
    email 2 : string
    scores 3 : *integer
}
]]

local test_data = {
    name = "benchmark_user",
    age = 30,
    email = "bench@test.com",
    scores = {100, 95, 88, 72, 60},
}

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local iterations = 100000

            local hpc = skynet.hpc
            local encoded = sp:encode("Person", test_data)
            for _ = 1, 1000 do
                sp:encode("Person", test_data)
                sp:decode("Person", encoded)
            end

            collectgarbage("stop")

            local t0 = hpc()
            for _ = 1, iterations do
                sp:encode("Person", test_data)
            end
            local cpu_encode = (hpc() - t0) / 1e9

            t0 = hpc()
            for _ = 1, iterations do
                sp:decode("Person", encoded)
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
