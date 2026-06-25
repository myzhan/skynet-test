-- test_basic_echo.lua — Echo service helper (NOT a test case, no skynet.dispatch for "run")
local skynet = require "skynet"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, msg)
        skynet.ret(skynet.pack(msg))
    end)
end)
