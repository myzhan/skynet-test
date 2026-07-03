-- sink.lua — receives the large table sent by main.lua
local skynet = require "skynet"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, t)
        skynet.error("sink: received table with " .. tostring(#t) .. " entries")
        skynet.ret(skynet.pack(true))
    end)
end)
