-- test_mqueue.lua — Test skynet.mqueue and multicast
local skynet = require "skynet"
require "skynet.manager"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                -- Test multicast.new creates a channel
                local mc = require "skynet.multicast"
                testlib.assert_true(type(mc) == "table", "multicast module should be a table")
                testlib.assert_true(type(mc.new) == "function", "multicast.new should be a function")

                local chan = mc.new()
                testlib.assert_true(chan ~= nil, "multicast.new should return channel")
                testlib.assert_true(chan.channel ~= nil, "channel should have an id")

                -- Test mqueue module
                local mq = require "skynet.mqueue"
                testlib.assert_true(type(mq) == "table", "mqueue module should be a table")

                -- Cleanup
                pcall(chan.delete, chan)
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
