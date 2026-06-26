-- test_skynet_core.lua — Test skynet core C functions (lua-skynet.c, skynet_env, skynet_server)
local skynet = require "skynet"
require "skynet.manager"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                -- Test skynet.hpc (high performance counter)
                testlib.assert_true(type(skynet.hpc) == "function", "skynet.hpc should be a function")
                local hpc1 = skynet.hpc()
                testlib.assert_true(type(hpc1) == "number", "hpc should return number")
                local hpc2 = skynet.hpc()
                testlib.assert_true(hpc2 >= hpc1, "hpc should be monotonically increasing")

                -- Test skynet.now returns time in centiseconds
                local now1 = skynet.now()
                testlib.assert_true(type(now1) == "number", "skynet.now should return number")
                testlib.assert_true(now1 >= 0, "skynet.now should be non-negative")

                -- Test skynet.time returns wall-clock seconds
                local time = skynet.time()
                testlib.assert_true(type(time) == "number", "skynet.time should return number")
                testlib.assert_true(time > 1000000000, "skynet.time should be unix timestamp")

                -- Test skynet.starttime
                local start_time = skynet.starttime()
                testlib.assert_true(type(start_time) == "number", "starttime should return number")
                testlib.assert_true(start_time > 1000000000, "starttime should be unix timestamp")
                testlib.assert_true(start_time <= time, "starttime should be <= current time")

                -- Test skynet.self returns valid handle
                local self = skynet.self()
                testlib.assert_true(type(self) == "number", "skynet.self should return number")
                testlib.assert_true(self > 0, "skynet.self should be positive")

                -- Test skynet.address
                local addr_str = skynet.address(self)
                testlib.assert_true(type(addr_str) == "string", "skynet.address should return string")
                testlib.assert_true(addr_str:match("^:") ~= nil, "address should start with :")

                -- Test skynet.harbor
                local harbor_id = skynet.harbor(self)
                testlib.assert_true(type(harbor_id) == "number", "harbor should return number")
                testlib.assert_eq(0, harbor_id, "single-node harbor should be 0")

                -- Test skynet.genid
                local id1 = skynet.genid()
                testlib.assert_true(type(id1) == "number", "genid should return number")
                local id2 = skynet.genid()
                testlib.assert_ne(id1, id2, "genid should return unique ids")
                local id3 = skynet.genid()
                testlib.assert_ne(id2, id3, "genid consecutive should differ")

                -- Test skynet.getenv / skynet.setenv
                skynet.setenv("test_env_var_xyz", "hello_world")
                local val = skynet.getenv("test_env_var_xyz")
                testlib.assert_eq("hello_world", val, "setenv/getenv round-trip")

                -- Test getenv for non-existent key
                local nonexist = skynet.getenv("surely_this_does_not_exist_xyz123")
                testlib.assert_eq(nil, nonexist, "getenv non-existent key should be nil")

                -- Test setenv with numeric value
                skynet.setenv("test_env_num", "12345")
                testlib.assert_eq("12345", skynet.getenv("test_env_num"), "setenv numeric string")

                -- Test skynet.error (should not crash)
                local ok_err = pcall(skynet.error, "test error message from test_skynet_core")
                testlib.assert_true(ok_err, "skynet.error should not crash")

                -- Test skynet.tostring on pack result (lightuserdata + size)
                local data, sz = skynet.pack("test_tostring_data")
                if sz then
                    local str = skynet.tostring(data, sz)
                    testlib.assert_true(type(str) == "string", "skynet.tostring should return string")
                    testlib.assert_eq(sz, #str, "skynet.tostring length should match size")
                end

                -- Test skynet.trash frees memory
                if sz then
                    local data2, sz2 = skynet.pack("trash_test")
                    local ok_trash = pcall(skynet.trash, data2, sz2)
                    testlib.assert_true(ok_trash, "skynet.trash should not crash")
                end

                -- Test skynet.packstring
                local pstr = skynet.packstring("hello", "world")
                testlib.assert_true(type(pstr) == "string", "packstring should return string")
                local ps1, ps2 = skynet.unpack(pstr)
                testlib.assert_eq("hello", ps1, "packstring unpack 1")
                testlib.assert_eq("world", ps2, "packstring unpack 2")

                -- Test multiple genid calls create incrementing sequence
                local ids = {}
                for i = 1, 10 do
                    ids[i] = skynet.genid()
                end
                for i = 2, 10 do
                    testlib.assert_true(ids[i] > ids[i-1], "genid should increment: " .. i)
                end
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
