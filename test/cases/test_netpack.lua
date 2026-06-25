-- test_netpack.lua — Test skynet.netpack and skynet.seri
local skynet = require "skynet"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                local netpack = require "skynet.netpack"
                testlib.assert_true(type(netpack) == "table", "netpack module should be a table")

                -- Test netpack.pack creates binary package (returns userdata + size)
                local packed, sz = netpack.pack("test_payload")
                testlib.assert_true(packed ~= nil, "pack should return data")
                testlib.assert_true(type(sz) == "number", "pack should return size")

                -- Test netpack.tostring unpacks to readable form
                if netpack.tostring then
                    local ts = netpack.tostring(packed, sz)
                    testlib.assert_true(type(ts) == "string", "tostring should return string")
                end

                -- skynet.pack returns either (string) or (userdata, size)
                local function pack_unpack(...)
                    local data, sz = skynet.pack(...)
                    if sz then
                        return skynet.unpack(data, sz)
                    else
                        return skynet.unpack(data)
                    end
                end

                local a, b, c, d = pack_unpack("hello", 42, true, { a = 1 })
                testlib.assert_eq("hello", a, "unpack value 1")
                testlib.assert_eq(42, b, "unpack value 2")
                testlib.assert_eq(true, c, "unpack value 3")
                testlib.assert_eq(1, d.a, "unpack nested table")

                -- Test pack/unpack with various types
                local x1, x2, x3, x4 = pack_unpack(nil, 0, -1, 3.14)
                testlib.assert_eq(nil, x1)
                testlib.assert_eq(0, x2)
                testlib.assert_eq(-1, x3)
                testlib.assert_eq(3.14, x4)

                -- Test large string round-trip
                local large_str = string.rep("x", 1000)
                local ls = pack_unpack(large_str)
                testlib.assert_eq(1000, #ls, "large string round-trip")
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
