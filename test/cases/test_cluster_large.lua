-- test_cluster_large.lua — Test cluster multi-part message (>32KB) pack/unpack cycle
local skynet = require "skynet"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                local cluster_core = require "skynet.cluster.core"

                -- Create a message larger than MULTI_PART (0x8000 = 32768 bytes)
                local large_data = string.rep("X", 40000)
                local msg, sz = skynet.pack(large_data)

                -- packrequest with large message returns 3 values:
                -- (first_packet, new_session, multi_parts_table)
                local session = 1
                local packed, new_session, parts = cluster_core.packrequest(0x100, session, msg, sz)
                testlib.assert_true(packed ~= nil, "packrequest large should return first packet")
                testlib.assert_eq(session + 1, new_session, "new session should increment")
                testlib.assert_true(type(parts) == "table", "large msg should produce multi-part table")
                testlib.assert_true(#parts > 0, "multi-part table should have entries")

                -- Simulate what clusteragent does when receiving multi-part messages:
                -- 1. Unpack first packet (strip 2-byte length header)
                local first_payload = packed:sub(3)
                local addr, sess, req_msg, req_sz, padding, is_push = cluster_core.unpackrequest(first_payload)
                testlib.assert_eq(0x100, addr, "first packet addr")
                testlib.assert_eq(session, sess, "first packet session")
                testlib.assert_eq(nil, req_msg, "first packet msg should be nil")
                testlib.assert_true(type(req_sz) == "number", "first packet sz should be total size number")
                testlib.assert_true(req_sz > 0, "total size should be positive")
                testlib.assert_true(padding, "first packet should have padding=true")

                -- 2. Build the reassembly table like clusteragent does:
                --    dispatch_request calls cluster.append(req, msg, sz)
                --    For first packet: msg=nil, sz=total_size → stores total_size at table[1]
                local req = { addr = addr, is_push = is_push }
                cluster_core.append(req, req_msg, req_sz)

                -- Verify table[1] is the total size (this is what concat expects)
                testlib.assert_true(type(req[1]) == "number", "after first append, table[1] should be total size number")
                testlib.assert_eq(req_sz, req[1], "table[1] should equal the total expected size")

                -- 3. Unpack and append each multi-part piece
                for i, part_str in ipairs(parts) do
                    local part_payload = part_str:sub(3) -- strip 2-byte length header
                    local p_addr, p_sess, p_msg, p_sz, p_padding = cluster_core.unpackrequest(part_payload)
                    testlib.assert_eq(session, p_sess, "part session should match")
                    testlib.assert_true(p_msg ~= nil, "part should have message data")
                    testlib.assert_true(p_sz > 0, "part should have positive size")

                    cluster_core.append(req, p_msg, p_sz)

                    if i < #parts then
                        testlib.assert_true(p_padding, "middle parts should have padding=true")
                    else
                        testlib.assert_false(p_padding, "last part should have padding=false")
                    end
                end

                -- 4. Call concat to reassemble
                local reassembled_msg, reassembled_sz = cluster_core.concat(req)
                testlib.assert_true(reassembled_msg ~= nil, "concat should return reassembled message")
                testlib.assert_true(reassembled_sz > 0, "concat size should be positive")
                testlib.assert_eq(req_sz, reassembled_sz, "reassembled size should match total size")

                -- 5. Verify the reassembled data matches the original
                local decoded = skynet.unpack(reassembled_msg, reassembled_sz)
                testlib.assert_eq(large_data, decoded, "reassembled data should match original")
                skynet.trash(reassembled_msg, reassembled_sz)
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
