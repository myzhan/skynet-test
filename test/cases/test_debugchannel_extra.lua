-- test_debugchannel_extra.lua — Extended debug channel tests for lua-debugchannel.c coverage
local skynet = require "skynet"
local T = require "testlib"

T.case("create and connect channel", function()
    local dc = require "skynet.debugchannel"
    local channel, ptr = dc.create()
    T.assert_true(channel ~= nil, "create should return channel")
    T.assert_true(ptr ~= nil, "create should return pointer")

    local reader = dc.connect(ptr)
    T.assert_true(reader ~= nil, "connect should return reader")
end)

T.case("write and read string", function()
    local dc = require "skynet.debugchannel"
    local channel, ptr = dc.create()
    local reader = dc.connect(ptr)

    channel:write("hello debug")
    local msg = reader:read()
    T.assert_eq("hello debug", msg, "should read written string")
end)

T.case("write and read multiple messages", function()
    local dc = require "skynet.debugchannel"
    local channel, ptr = dc.create()
    local reader = dc.connect(ptr)

    channel:write("msg1")
    channel:write("msg2")
    channel:write("msg3")

    local m1 = reader:read()
    local m2 = reader:read()
    local m3 = reader:read()

    T.assert_eq("msg1", m1, "first message")
    T.assert_eq("msg2", m2, "second message")
    T.assert_eq("msg3", m3, "third message")
end)

T.case("write empty string", function()
    local dc = require "skynet.debugchannel"
    local channel, ptr = dc.create()
    local reader = dc.connect(ptr)

    channel:write("")
    local msg = reader:read()
    T.assert_eq("", msg, "empty string should round-trip")
end)

T.case("write large message", function()
    local dc = require "skynet.debugchannel"
    local channel, ptr = dc.create()
    local reader = dc.connect(ptr)

    local big = string.rep("X", 10000)
    channel:write(big)
    local msg = reader:read()
    T.assert_eq(10000, #msg, "large message length")
    T.assert_eq(big, msg, "large message content")
end)

T.case("write requires string argument", function()
    local dc = require "skynet.debugchannel"
    local channel, ptr = dc.create()

    -- write(nil) should error since C code uses luaL_checkstring
    local ok, err = pcall(channel.write, channel, nil)
    T.assert_true(not ok, "write(nil) should error")
end)

T.case("multiple channels independent", function()
    local dc = require "skynet.debugchannel"
    local ch1, ptr1 = dc.create()
    local ch2, ptr2 = dc.create()
    local r1 = dc.connect(ptr1)
    local r2 = dc.connect(ptr2)

    ch1:write("channel1")
    ch2:write("channel2")

    T.assert_eq("channel1", r1:read(), "channel 1 independent")
    T.assert_eq("channel2", r2:read(), "channel 2 independent")
end)

T.run()
