-- test_netpack_extra.lua — Extended netpack tests for edge cases in lua-netpack.c
local skynet = require "skynet"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                local netpack = require "skynet.netpack"
                testlib.assert_true(type(netpack) == "table", "netpack module loaded")

                -- Test pack with empty string
                local p_empty, sz_empty = netpack.pack("")
                testlib.assert_true(p_empty ~= nil, "pack empty should return data")
                testlib.assert_true(sz_empty >= 2, "pack empty should have at least header bytes")

                -- Test pack with single byte
                local p1, sz1 = netpack.pack("x")
                testlib.assert_true(p1 ~= nil, "pack single byte")
                testlib.assert_true(sz1 >= 3, "pack single byte size")

                -- Test pack with max-ish payload (netpack uses 2-byte big-endian length header)
                local large = string.rep("A", 1024)
                local p_large, sz_large = netpack.pack(large)
                testlib.assert_true(p_large ~= nil, "pack 1KB")
                testlib.assert_eq(1024 + 2, sz_large, "pack 1KB size should be data + 2 byte header")

                -- Test pack with 65535 bytes (max for 2-byte length)
                local max_payload = string.rep("B", 65535)
                local p_max, sz_max = netpack.pack(max_payload)
                testlib.assert_true(p_max ~= nil, "pack 64KB should work")

                -- Test tostring converts lightuserdata+size to string
                local data, sz = netpack.pack("test_tostring")
                if netpack.tostring then
                    local str = netpack.tostring(data, sz)
                    testlib.assert_true(type(str) == "string", "tostring should give string")
                    testlib.assert_eq(sz, #str, "tostring length should match")
                end

                -- Test skynet.pack/unpack with lightuserdata path
                -- When skynet.pack returns userdata + size, we exercise lua-seri userdata path
                local ud, ud_sz = skynet.pack("lightuserdata_test", {1,2,3}, true)
                if ud_sz then
                    -- It's a lightuserdata
                    testlib.assert_true(type(ud_sz) == "number", "pack userdata size")
                    local v1, v2, v3 = skynet.unpack(ud, ud_sz)
                    testlib.assert_eq("lightuserdata_test", v1, "unpack ud v1")
                    testlib.assert_eq(true, v3, "unpack ud v3")
                    -- Free it
                    skynet.trash(ud, ud_sz)
                end

                -- Test skynet.pack with many arguments
                local args = {}
                for i = 1, 50 do args[i] = i end
                local mdata, msz = skynet.pack(table.unpack(args))
                local results = {skynet.unpack(mdata, msz)}
                testlib.assert_eq(50, #results, "pack 50 args")
                testlib.assert_eq(1, results[1], "first arg")
                testlib.assert_eq(50, results[50], "last arg")
                if msz then skynet.trash(mdata, msz) end

                -- Test skynet.pack with nested tables containing various types
                local complex = {
                    str = "hello",
                    num = 42,
                    float = 3.14,
                    bool = true,
                    nested = { a = 1, b = { c = 2 } },
                    arr = {1, "two", 3.0, false},
                }
                local cdata, csz = skynet.pack(complex)
                local cdec = skynet.unpack(cdata, csz)
                testlib.assert_eq("hello", cdec.str, "complex str")
                testlib.assert_eq(42, cdec.num, "complex num")
                testlib.assert_eq(2, cdec.nested.b.c, "complex nested")
                testlib.assert_eq("two", cdec.arr[2], "complex arr[2]")
                if csz then skynet.trash(cdata, csz) end
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
