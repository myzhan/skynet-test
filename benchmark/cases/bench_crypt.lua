local skynet = require "skynet"
local crypt = require "skynet.crypt"

local plain_text = "hello skynet benchmark test!!"
local des_key = "12345678"
local base64_input = "SGVsbG8gU2t5bmV0IEJlbmNobWFyayBUZXN0"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local hpc = skynet.hpc
            local iterations = 100000

            local encrypted = crypt.desencode(des_key, plain_text)
            for _ = 1, 1000 do
                crypt.desencode(des_key, plain_text)
                crypt.desdecode(des_key, encrypted)
                crypt.sha1(plain_text)
                crypt.base64encode(plain_text)
                crypt.base64decode(base64_input)
            end

            collectgarbage("stop")

            local t0 = hpc()
            for _ = 1, iterations do
                crypt.desencode(des_key, plain_text)
            end
            local cost_des_enc = (hpc() - t0) / 1e9

            t0 = hpc()
            for _ = 1, iterations do
                crypt.desdecode(des_key, encrypted)
            end
            local cost_des_dec = (hpc() - t0) / 1e9

            t0 = hpc()
            for _ = 1, iterations do
                crypt.sha1(plain_text)
            end
            local cost_sha1 = (hpc() - t0) / 1e9

            t0 = hpc()
            for _ = 1, iterations do
                crypt.base64encode(plain_text)
            end
            local cost_b64enc = (hpc() - t0) / 1e9

            t0 = hpc()
            for _ = 1, iterations do
                crypt.base64decode(base64_input)
            end
            local cost_b64dec = (hpc() - t0) / 1e9

            collectgarbage("restart")

            local total = iterations * 5
            local cpu_total = cost_des_enc + cost_des_dec + cost_sha1 + cost_b64enc + cost_b64dec

            skynet.ret(skynet.pack({
                ops_per_sec = total / cpu_total,
                avg_time_ms = cpu_total / total * 1000,
                iterations = total,
                detail = string.format(
                    "des_enc %.0f, des_dec %.0f, sha1 %.0f, b64_enc %.0f, b64_dec %.0f ops/s",
                    iterations / cost_des_enc,
                    iterations / cost_des_dec,
                    iterations / cost_sha1,
                    iterations / cost_b64enc,
                    iterations / cost_b64dec),
            }))
        end
    end)
end)
