-- bench_echo_service.lua — Echo service for benchmark
local skynet = require "skynet"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, msg)
        skynet.ret(skynet.pack(msg))
    end)
end)
