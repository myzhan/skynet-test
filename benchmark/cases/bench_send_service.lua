local skynet = require "skynet"
require "skynet.debug"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "barrier" then
            skynet.ret(skynet.pack(nil))
        end
    end)
end)
