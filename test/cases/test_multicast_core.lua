-- test_multicast_core.lua — Test lua-multicast.c pack/unpack/bind/close/remote/nextid
local skynet = require "skynet"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                local mc = require "skynet.multicast.core"
                testlib.assert_true(type(mc) == "table", "multicast.core should be a table")

                -- Test nextid: takes a channel id, returns id+256 with high bit cleared
                local id1 = mc.nextid(0)
                testlib.assert_eq(256, id1, "nextid(0) should return 256")
                local id2 = mc.nextid(id1)
                testlib.assert_eq(512, id2, "nextid(256) should return 512")
                local id3 = mc.nextid(id2)
                testlib.assert_eq(768, id3, "nextid(512) should return 768")

                -- Test nextid wraps with high bit clear
                local big_id = mc.nextid(0x7FFFFF00)
                testlib.assert_true(big_id >= 0, "nextid should clear high bit")

                -- Test pack (packlocal): takes lightuserdata + size
                -- Returns mc_package** lightuserdata + sizeof(mc_package*)
                local msg, sz = skynet.pack("multicast test", 42, true)
                local pack_ud, pack_sz = mc.pack(msg, sz)
                testlib.assert_true(pack_ud ~= nil, "pack should return lightuserdata")
                testlib.assert_true(type(pack_sz) == "number", "pack should return size")
                testlib.assert_true(pack_sz > 0, "pack size should be positive")

                -- Test bind (bindrefer): sets reference count, must be called before close
                -- bind(mc_package**, ref_count) → mc_package*
                local mc_pkg = mc.bind(pack_ud, 2)
                testlib.assert_true(mc_pkg ~= nil, "bind should return mc_package*")

                -- Test unpack (unpacklocal): takes mc_package** + size
                -- returns: mc_package*, data_lightuserdata, data_size
                local mc_pkg2, data_ud, data_sz = mc.unpack(pack_ud, pack_sz)
                testlib.assert_true(mc_pkg2 ~= nil, "unpack should return mc_package*")
                testlib.assert_true(data_ud ~= nil, "unpack should return data pointer")
                testlib.assert_true(type(data_sz) == "number", "unpack should return data size")
                testlib.assert_eq(sz, data_sz, "unpacked data size should match original")

                -- Verify the unpacked data matches original
                local v1, v2, v3 = skynet.unpack(data_ud, data_sz)
                testlib.assert_eq("multicast test", v1, "multicast data round-trip v1")
                testlib.assert_eq(42, v2, "multicast data round-trip v2")
                testlib.assert_eq(true, v3, "multicast data round-trip v3")

                -- Test close (closelocal): decrements reference, frees when reaches 0
                mc.close(mc_pkg) -- ref 2→1
                mc.close(mc_pkg) -- ref 1→0, freed

                -- Test packremote: copies data (for remote dispatch)
                -- packremote copies the data, so the original msg is NOT consumed
                local msg2, sz2 = skynet.pack("remote msg")
                local remote_ud, remote_sz = mc.packremote(msg2, sz2)
                testlib.assert_true(remote_ud ~= nil, "packremote should return lightuserdata")
                testlib.assert_true(remote_sz > 0, "packremote size should be positive")

                -- Bind and unpack the remote package
                local remote_pkg = mc.bind(remote_ud, 1)
                local remote_pkg2, remote_data, remote_data_sz = mc.unpack(remote_ud, remote_sz)
                testlib.assert_true(remote_pkg2 ~= nil, "unpack remote should work")
                testlib.assert_true(remote_data ~= nil, "remote data should exist")
                testlib.assert_eq(sz2, remote_data_sz, "remote data size should match")

                -- Verify remote data content
                local rv = skynet.unpack(remote_data, remote_data_sz)
                testlib.assert_eq("remote msg", rv, "remote data round-trip")

                -- Close remote package (frees since ref=1)
                mc.close(remote_pkg)

                -- Free original msg2 (packremote copied it, so original still needs freeing)
                skynet.trash(msg2, sz2)

                -- Test remote: extracts data from mc_package**, frees the wrapper
                -- remote(mc_package**) → data_lightuserdata, data_size
                local msg3, sz3 = skynet.pack("another test")
                local pack3_ud, pack3_sz = mc.pack(msg3, sz3)
                -- remote frees the mc_package struct and ptr, returns raw data
                local data3_ud, data3_sz = mc.remote(pack3_ud)
                testlib.assert_true(data3_ud ~= nil, "remote should return data lightuserdata")
                testlib.assert_true(data3_sz > 0, "remote size should be positive")
                testlib.assert_eq(sz3, data3_sz, "remote data size should match original")

                -- Verify the data extracted by remote
                local rv3 = skynet.unpack(data3_ud, data3_sz)
                testlib.assert_eq("another test", rv3, "remote extracted data round-trip")
                -- data3_ud is the raw data that was inside mc_package, we need to free it
                skynet.trash(data3_ud, data3_sz)

                -- Test pack with larger data
                local big_msg, big_sz = skynet.pack(string.rep("X", 10000))
                local big_pack_ud, big_pack_sz = mc.pack(big_msg, big_sz)
                testlib.assert_true(big_pack_ud ~= nil, "pack large should work")
                local big_pkg = mc.bind(big_pack_ud, 1)
                mc.close(big_pkg)
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
