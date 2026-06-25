-- test_inject.lua — Test skynet.inject / skynet.injectcode
local skynet = require "skynet"
require "skynet.manager"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                -- inject is a function that evaluates code in a service
                local inject = require "skynet.inject"
                testlib.assert_true(type(inject) == "function", "inject should be a function")

                -- injectcode is also a function for code injection at a specific level
                local injectcode = require "skynet.injectcode"
                testlib.assert_true(type(injectcode) == "function", "injectcode should be a function")

                -- inject(skynet_module, source_code, filename, args...)
                -- inject(skynet, source, filename, args_table)
                local result = { inject(skynet, "return 1 + 1", "(inject_test)", { n = 0 }) }
                testlib.assert_true(result[1] == true, "inject should succeed")
            end)
            skynet.ret(skynet.pack(ok and { status = "pass" } or { status = "fail", message = tostring(err) }))
        end
    end)
end)
