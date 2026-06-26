-- test_debugchannel.lua — Test skynet.debugchannel (C layer debug IPC)
local skynet = require "skynet"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                local dc = require "skynet.debugchannel"
                testlib.assert_true(type(dc) == "table", "debugchannel module should be a table")
                testlib.assert_true(type(dc.create) == "function", "dc.create should be a function")
                testlib.assert_true(type(dc.connect) == "function", "dc.connect should be a function")
                testlib.assert_true(type(dc.release) == "function", "dc.release should be a function")

                -- dc.create returns (channel_userdata, lightuserdata_pointer)
                local channel, ptr = dc.create()
                testlib.assert_true(channel ~= nil, "create should return channel")
                testlib.assert_true(ptr ~= nil, "create should return pointer")

                -- channel has write method
                testlib.assert_true(type(channel.write) == "function", "channel should have write")
                testlib.assert_true(type(channel.read) == "function", "channel should have read")

                -- write data to channel
                channel:write("hello from debugchannel test")

                -- connect creates a reader from the pointer
                local reader = dc.connect(ptr)
                testlib.assert_true(reader ~= nil, "connect should return reader")
                testlib.assert_true(type(reader.read) == "function", "reader should have read")

                -- read data - should get what we wrote
                local data = reader:read()
                testlib.assert_eq("hello from debugchannel test", data, "read should get written data")

                -- Test writing multiple messages
                channel:write("msg1")
                channel:write("msg2")
                local d1 = reader:read()
                local d2 = reader:read()
                testlib.assert_eq("msg1", d1, "multi msg 1")
                testlib.assert_eq("msg2", d2, "multi msg 2")
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
