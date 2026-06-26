-- test_framework.lua — Verify the multi-case test framework itself
local T = require "testlib"

local shared_state = {}

T.setup(function()
    shared_state.initialized = true
    shared_state.counter = 0
end)

T.teardown(function()
    shared_state = {}
end)

T.before_each(function()
    shared_state.counter = shared_state.counter + 1
end)

T.case("setup runs before cases", function()
    T.assert_true(shared_state.initialized, "setup should have run")
end)

T.case("before_each increments counter", function()
    T.assert_true(shared_state.counter > 0, "before_each should have run")
end)

T.case("assertions work in sub-cases", function()
    T.assert_eq(1, 1, "eq")
    T.assert_ne(1, 2, "ne")
    T.assert_true(true, "true")
    T.assert_false(false, "false")
    T.assert_error(function() error("x") end, "error")
    T.assert_not_error(function() end, "not_error")
end)

T.case("multiple cases are independent", function()
    local local_val = 42
    T.assert_eq(42, local_val, "local state is isolated")
end)

T.run()
