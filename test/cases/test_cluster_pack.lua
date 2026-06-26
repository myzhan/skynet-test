-- test_cluster_pack.lua — Test skynet.cluster.core pack/unpack (C layer)
local skynet = require "skynet"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                local cluster_core = require "skynet.cluster.core"
                testlib.assert_true(type(cluster_core) == "table", "cluster.core module should be a table")

                -- Test isname: returns true for @-prefixed names, nil otherwise
                testlib.assert_true(cluster_core.isname("@hello"), "@ prefix should be a name")
                testlib.assert_eq(nil, cluster_core.isname("hello"), "no @ prefix should return nil")
                testlib.assert_eq(nil, cluster_core.isname(""), "empty string should return nil")

                -- Test nodename: returns hostname + pid as a unique node identifier
                local name = cluster_core.nodename()
                testlib.assert_true(type(name) == "string", "nodename should return string")
                testlib.assert_true(#name > 0, "nodename should be non-empty")

                -- Test packrequest with numeric address
                -- packrequest(addr, session, msg_lightuserdata, msg_size)
                -- returns (packed_string, new_session) — it frees the msg internally
                local msg, sz = skynet.pack("hello", 123)
                local session = 1
                local packed, new_session = cluster_core.packrequest(0x100, session, msg, sz)
                testlib.assert_true(type(packed) == "string", "packrequest should return string")
                testlib.assert_true(#packed > 0, "packed should be non-empty")
                testlib.assert_eq(session + 1, new_session, "new_session should be session + 1")

                -- Test unpackrequest on the packed data (skip 2-byte length header)
                local payload = packed:sub(3)
                local addr, req_session, req_msg, req_sz = cluster_core.unpackrequest(payload)
                testlib.assert_eq(0x100, addr, "unpackrequest addr should match")
                testlib.assert_eq(session, req_session, "unpackrequest session should match")
                testlib.assert_true(req_msg ~= nil, "unpackrequest should return message")
                testlib.assert_true(req_sz > 0, "unpackrequest should return positive size")

                -- Verify the message content round-trips
                local v1, v2 = skynet.unpack(req_msg, req_sz)
                testlib.assert_eq("hello", v1, "round-trip value 1")
                testlib.assert_eq(123, v2, "round-trip value 2")

                -- Test packrequest with string address (@name)
                local msg2, sz2 = skynet.pack("world")
                local packed2, ns2 = cluster_core.packrequest("@myservice", 5, msg2, sz2)
                testlib.assert_true(type(packed2) == "string", "string addr packrequest")
                testlib.assert_eq(6, ns2, "new session for string addr")

                -- Unpack string-addressed request
                local payload2 = packed2:sub(3)
                local addr2, sess2, msg2_ud, msg2_sz = cluster_core.unpackrequest(payload2)
                testlib.assert_eq("@myservice", addr2, "string addr unpackrequest")
                testlib.assert_eq(5, sess2, "string addr session")

                -- Test packresponse/unpackresponse round-trip
                local resp_msg, resp_sz = skynet.pack("response_data", true)
                local packed_resp = cluster_core.packresponse(session, true, resp_msg, resp_sz)
                testlib.assert_true(type(packed_resp) == "string", "packresponse should return string")

                -- unpackresponse expects data without 2-byte header
                local resp_payload = packed_resp:sub(3)
                local resp_session, resp_ok, resp_data, resp_data_sz = cluster_core.unpackresponse(resp_payload)
                testlib.assert_eq(session, resp_session, "unpackresponse session should match")
                testlib.assert_true(resp_ok, "unpackresponse ok should be true")

                -- Test packresponse with error
                local err_resp = cluster_core.packresponse(2, false, nil, 0)
                testlib.assert_true(type(err_resp) == "string", "error packresponse should return string")

                local err_payload = err_resp:sub(3)
                local err_session, err_ok = cluster_core.unpackresponse(err_payload)
                testlib.assert_eq(2, err_session, "error response session")
                testlib.assert_false(err_ok, "error response ok should be false")

                -- Test packtrace
                local trace_tag = "trace123"
                local traced = cluster_core.packtrace(trace_tag)
                testlib.assert_true(type(traced) == "string", "packtrace should return string")
                testlib.assert_true(#traced > 0, "packtrace should be non-empty")

                -- Test concat/append (concat expects table[1]=total_size, table[2..n]=strings)
                local bufs = {}
                local data1, sz1 = skynet.pack("part1")
                local data2, sz2 = skynet.pack("part2")
                cluster_core.append(bufs, data1, sz1)
                cluster_core.append(bufs, data2, sz2)
                -- bufs now has strings at [1] and [2]
                -- concat requires bufs[1] to be a number (total size), reformat:
                local str1 = bufs[1]
                local str2 = bufs[2]
                local concat_input = { #str1 + #str2, str1, str2 }
                local combined_ud, combined_sz = cluster_core.concat(concat_input)
                testlib.assert_true(combined_ud ~= nil, "concat should return lightuserdata")
                testlib.assert_true(combined_sz > 0, "concat size should be positive")
                -- Verify we can read the concatenated data
                local combined_str = skynet.tostring(combined_ud, combined_sz)
                testlib.assert_eq(#str1 + #str2, #combined_str, "concat length should match")
                skynet.trash(combined_ud, combined_sz)
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
