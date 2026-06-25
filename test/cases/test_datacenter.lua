-- test_datacenter.lua — Test skynet.datacenter module
local skynet = require "skynet"
local dc = require "skynet.datacenter"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                -- Set and get
                local ok_set = pcall(dc.set, "test_key", "hello_dc")
                testlib.assert_true(ok_set, "datacenter.set should succeed")

                local val = dc.get("test_key")
                testlib.assert_eq("hello_dc", val, "datacenter.get should return set value")

                -- Test wait (returns immediately if key exists)
                local val2 = dc.wait("test_key")
                testlib.assert_eq("hello_dc", val2, "datacenter.wait should return existing value")

                -- Set a nonexistent key
                local val3 = dc.get("nonexistent_key_12345")
                testlib.assert_eq(nil, val3, "nonexistent key should return nil")
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
