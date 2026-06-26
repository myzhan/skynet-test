-- test_cluster_core.lua — Tests for lua-cluster.c pack/unpack/append/concat
local skynet = require "skynet"
local T = require "testlib"

T.case("packrequest with number address (small msg)", function()
    local cluster = require "skynet.cluster.core"
    local msg, sz = skynet.pack("hello")
    local packed, next_session = cluster.packrequest(1234, 1, msg, sz)
    T.assert_true(type(packed) == "string", "packrequest returns string")
    T.assert_eq(2, next_session, "next_session increments")
end)

T.case("packrequest with string address (small msg)", function()
    local cluster = require "skynet.cluster.core"
    local msg, sz = skynet.pack("test data")
    local packed, next_session = cluster.packrequest("@mynode", 5, msg, sz)
    T.assert_true(type(packed) == "string", "packrequest string addr returns string")
    T.assert_eq(6, next_session, "next_session increments for string addr")
end)

T.case("packrequest with large message (multi-part)", function()
    local cluster = require "skynet.cluster.core"
    -- Create a message > 0x8000 (32K) to trigger multi-part
    local big = string.rep("X", 40000)
    local msg, sz = skynet.pack(big)
    local packed, next_session, parts = cluster.packrequest(100, 1, msg, sz)
    T.assert_true(type(packed) == "string", "multi-part header string")
    T.assert_eq(2, next_session, "next_session for multi-part")
    T.assert_true(type(parts) == "table", "multi-part returns table")
    T.assert_true(#parts > 0, "multi-part table has entries")
end)

T.case("packpush with number address", function()
    local cluster = require "skynet.cluster.core"
    local msg, sz = skynet.pack("push data")
    local packed, next_session = cluster.packpush(999, 1, msg, sz)
    T.assert_true(type(packed) == "string", "packpush returns string")
    T.assert_eq(2, next_session, "packpush next_session")
end)

T.case("packpush with string address", function()
    local cluster = require "skynet.cluster.core"
    local msg, sz = skynet.pack("push msg")
    local packed, next_session = cluster.packpush("@node2", 3, msg, sz)
    T.assert_true(type(packed) == "string", "packpush string addr")
    T.assert_eq(4, next_session, "packpush string next_session")
end)

T.case("packpush with large message (multi-part)", function()
    local cluster = require "skynet.cluster.core"
    local big = string.rep("Y", 40000)
    local msg, sz = skynet.pack(big)
    local packed, next_session, parts = cluster.packpush(200, 1, msg, sz)
    T.assert_true(type(packed) == "string", "packpush multi header")
    T.assert_eq(2, next_session, "packpush multi next_session")
    T.assert_true(type(parts) == "table", "packpush multi parts")
end)

T.case("packtrace", function()
    local cluster = require "skynet.cluster.core"
    local trace_pkt = cluster.packtrace("my_trace_tag")
    T.assert_true(type(trace_pkt) == "string", "packtrace returns string")
    T.assert_true(#trace_pkt > 0, "packtrace non-empty")
end)

T.case("unpackrequest number address (small)", function()
    local cluster = require "skynet.cluster.core"
    local msg, sz = skynet.pack("payload")
    local packed, _ = cluster.packrequest(42, 7, msg, sz)
    -- unpackrequest: strip the 2-byte header
    local content = packed:sub(3)
    local addr, session, rmsg, rsz = cluster.unpackrequest(content)
    T.assert_eq(42, addr, "unpack addr")
    T.assert_eq(7, session, "unpack session")
    T.assert_true(rmsg ~= nil, "unpack msg not nil")
    T.assert_true(rsz > 0, "unpack sz > 0")
    skynet.trash(rmsg, rsz)
end)

T.case("unpackrequest string address (small)", function()
    local cluster = require "skynet.cluster.core"
    local msg, sz = skynet.pack("data")
    local packed, _ = cluster.packrequest("@svc", 10, msg, sz)
    local content = packed:sub(3)
    local addr, session, rmsg, rsz = cluster.unpackrequest(content)
    T.assert_eq("@svc", addr, "unpack string addr")
    T.assert_eq(10, session, "unpack string session")
    T.assert_true(rmsg ~= nil, "unpack string msg")
    skynet.trash(rmsg, rsz)
end)

T.case("unpackrequest multi-part number", function()
    local cluster = require "skynet.cluster.core"
    local big = string.rep("Z", 40000)
    local msg, sz = skynet.pack(big)
    local header, _, parts = cluster.packrequest(50, 1, msg, sz)
    -- Unpack the header (strip 2-byte size prefix)
    local content = header:sub(3)
    local addr, session, rmsg, total_sz, padding, is_push = cluster.unpackrequest(content)
    T.assert_eq(50, addr, "multi unpack addr")
    T.assert_eq(1, session, "multi unpack session")
    T.assert_true(total_sz > 0, "multi total size")
    T.assert_true(padding, "multi padding flag")

    -- Unpack parts
    for i, part in ipairs(parts) do
        local pcontent = part:sub(3)
        local r1, r2, r3, r4, r5 = cluster.unpackrequest(pcontent)
        T.assert_true(r2 ~= nil, "part session")
        if r3 then skynet.trash(r3, r4) end
    end
end)

T.case("unpackrequest multi-part string address", function()
    local cluster = require "skynet.cluster.core"
    local big = string.rep("W", 40000)
    local msg, sz = skynet.pack(big)
    local header, _, parts = cluster.packrequest("@bignode", 2, msg, sz)
    local content = header:sub(3)
    local addr, session, rmsg, total_sz, padding, is_push = cluster.unpackrequest(content)
    T.assert_eq("@bignode", addr, "multi string addr")
    T.assert_eq(2, session, "multi string session")
    T.assert_true(padding, "multi string padding")
end)

T.case("unpackrequest trace packet", function()
    local cluster = require "skynet.cluster.core"
    local trace_pkt = cluster.packtrace("trace_test")
    local content = trace_pkt:sub(3)
    local tag = cluster.unpackrequest(content)
    T.assert_eq("trace_test", tag, "unpack trace tag")
end)

T.case("packresponse ok (small)", function()
    local cluster = require "skynet.cluster.core"
    local msg, sz = skynet.pack("response data")
    local resp = cluster.packresponse(100, true, msg, sz)
    T.assert_true(type(resp) == "string", "packresponse returns string")
    T.assert_true(#resp > 0, "packresponse non-empty")
end)

T.case("packresponse error", function()
    local cluster = require "skynet.cluster.core"
    local resp = cluster.packresponse(200, false, "error message")
    T.assert_true(type(resp) == "string", "packresponse error")
end)

T.case("packresponse with large data (multi-part)", function()
    local cluster = require "skynet.cluster.core"
    local big = string.rep("R", 40000)
    local msg, sz = skynet.pack(big)
    local resp = cluster.packresponse(300, true, msg, sz)
    T.assert_true(type(resp) == "table", "large packresponse returns table")
    T.assert_true(#resp > 1, "large packresponse has multiple parts")
end)

T.case("unpackresponse ok", function()
    local cluster = require "skynet.cluster.core"
    local msg, sz = skynet.pack("resp payload")
    local resp = cluster.packresponse(55, true, msg, sz)
    -- strip 2-byte header
    local content = resp:sub(3)
    local session, ok, data = cluster.unpackresponse(content)
    T.assert_eq(55, session, "unpackresponse session")
    T.assert_true(ok, "unpackresponse ok")
    T.assert_true(type(data) == "string", "unpackresponse data")
end)

T.case("unpackresponse error", function()
    local cluster = require "skynet.cluster.core"
    local resp = cluster.packresponse(77, false, "some error")
    local content = resp:sub(3)
    local session, ok, errmsg = cluster.unpackresponse(content)
    T.assert_eq(77, session, "unpackresponse err session")
    T.assert_true(not ok, "unpackresponse not ok")
    T.assert_eq("some error", errmsg, "unpackresponse error msg")
end)

T.case("unpackresponse multi-part", function()
    local cluster = require "skynet.cluster.core"
    local big = string.rep("M", 40000)
    local msg, sz = skynet.pack(big)
    local parts = cluster.packresponse(88, true, msg, sz)
    T.assert_true(type(parts) == "table", "multi resp is table")

    -- First part is multi-begin header
    local header = parts[1]:sub(3)
    local session, ok, total_size, padding = cluster.unpackresponse(header)
    T.assert_eq(88, session, "multi resp session")
    T.assert_true(ok, "multi resp ok")
    T.assert_true(total_size > 0, "multi resp total size")
    T.assert_true(padding, "multi resp padding flag")

    -- Middle/end parts
    for i = 2, #parts do
        local part = parts[i]:sub(3)
        local s, o, d, p = cluster.unpackresponse(part)
        T.assert_eq(88, s, "multi resp part session")
        T.assert_true(o, "multi resp part ok")
    end
end)

T.case("append with lightuserdata", function()
    local cluster = require "skynet.cluster.core"
    local t = {}
    local msg, sz = skynet.pack("append test")
    cluster.append(t, msg, sz)
    T.assert_eq(1, #t, "append adds to table")
    T.assert_true(type(t[1]) == "string", "append converts to string")
end)

T.case("append with nil", function()
    local cluster = require "skynet.cluster.core"
    local t = {}
    cluster.append(t, nil, "some string value")
    T.assert_eq(1, #t, "append nil adds to table")
end)

T.case("concat reassembles parts", function()
    local cluster = require "skynet.cluster.core"
    local s1 = "hello"
    local s2 = " world"
    local t = { #s1 + #s2, s1, s2 }
    local ptr, sz = cluster.concat(t)
    T.assert_true(ptr ~= nil, "concat returns pointer")
    T.assert_eq(11, sz, "concat size")
    skynet.trash(ptr, sz)
end)

T.case("isname with @ prefix", function()
    local cluster = require "skynet.cluster.core"
    T.assert_true(cluster.isname("@node1"), "@ prefix is name")
    T.assert_true(not cluster.isname("node1"), "no @ is not name")
    T.assert_true(not cluster.isname(nil), "nil is not name")
end)

T.case("nodename returns string", function()
    local cluster = require "skynet.cluster.core"
    local name = cluster.nodename()
    T.assert_true(type(name) == "string", "nodename is string")
    T.assert_true(#name > 0, "nodename non-empty")
end)

T.run()
