local skynet = require "skynet"
require "skynet.manager"
local socket = require "skynet.socket"

local PAYLOAD_SIZE = 1024
local PAYLOAD = string.rep("x", PAYLOAD_SIZE)
local HEADER = string.char(math.floor(PAYLOAD_SIZE / 256), PAYLOAD_SIZE % 256)
local PACKET = HEADER .. PAYLOAD
local READ_SZ = PAYLOAD_SIZE + 2
local CONNECTIONS = 4
local ITERATIONS_PER_CONN = 20000

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local svc = skynet.newservice("bench_socket_service")
            local _, port = skynet.call(svc, "lua", "start")

            local fds = {}
            for i = 1, CONNECTIONS do
                fds[i] = socket.open("127.0.0.1", port)
            end

            -- Warm up
            for _, fd in ipairs(fds) do
                for _ = 1, 50 do
                    socket.write(fd, PACKET)
                    socket.read(fd, READ_SZ)
                end
            end

            local total_recv = 0
            local done = 0
            local t0 = skynet.hpc()

            for _, fd in ipairs(fds) do
                -- Writer coroutine
                skynet.fork(function()
                    for _ = 1, ITERATIONS_PER_CONN do
                        socket.write(fd, PACKET)
                    end
                end)
                -- Reader coroutine
                skynet.fork(function()
                    local count = 0
                    for _ = 1, ITERATIONS_PER_CONN do
                        local data = socket.read(fd, READ_SZ)
                        if not data then break end
                        count = count + 1
                    end
                    total_recv = total_recv + count
                    done = done + 1
                end)
            end

            while done < CONNECTIONS do
                skynet.sleep(1)
            end

            local elapsed = (skynet.hpc() - t0) / 1e9

            for _, fd in ipairs(fds) do
                socket.close(fd)
            end
            skynet.kill(svc)

            local ops = total_recv / elapsed
            local throughput = total_recv * PAYLOAD_SIZE / elapsed / 1e6

            skynet.ret(skynet.pack({
                ops_per_sec = ops,
                avg_time_ms = elapsed / total_recv * 1000,
                iterations = total_recv,
                detail = string.format("%dB x %d conns, %.2f MB/s", PAYLOAD_SIZE, CONNECTIONS, throughput),
            }))
        end
    end)
end)
