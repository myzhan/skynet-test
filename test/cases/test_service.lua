-- test_service.lua — Test skynet service operations
local skynet = require "skynet"
require "skynet.manager"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                -- Test uniqueservice creates singleton
                local svc1 = skynet.uniqueservice("test_basic_echo")
                local svc2 = skynet.uniqueservice("test_basic_echo")
                testlib.assert_eq(svc1, svc2, "uniqueservice should return same handle")

                -- Test newservice creates new instances
                local new1 = skynet.newservice("test_basic_echo")
                local new2 = skynet.newservice("test_basic_echo")
                testlib.assert_ne(new1, new2, "newservice should create different instances")

                -- Test named service
                skynet.name(".my_test_svc", new1)
                local named = skynet.localname(".my_test_svc")
                testlib.assert_eq(new1, named, "localname should find named service")

                -- Test querying non-existent name
                local nonexist = skynet.localname(".nonexist_test_xyz")
                testlib.assert_eq(nil, nonexist, "nonexistent name should return nil")

                -- Test call via name
                local reply = skynet.call(".my_test_svc", "lua", "named_call")
                testlib.assert_eq("named_call", reply, "call via name should work")

                -- Cleanup
                skynet.kill(new1)
                skynet.kill(new2)
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
