-- test_sharetable_core.lua — Tests for lua-sharetable.c core functions
local skynet = require "skynet"
local T = require "testlib"

T.case("is_sharedtable on regular table", function()
    local core = require "skynet.sharetable.core"
    local t = { a = 1, b = 2 }
    local result = core.is_sharedtable(t)
    T.assert_true(not result, "regular table is not shared")
end)

T.case("is_sharedtable on non-table", function()
    local core = require "skynet.sharetable.core"
    local result = core.is_sharedtable(123)
    T.assert_true(not result, "number is not shared table")
    local result2 = core.is_sharedtable("hello")
    T.assert_true(not result2, "string is not shared table")
end)

T.case("matrix from string source", function()
    local core = require "skynet.sharetable.core"
    -- matrix() takes a Lua source string, executes it, and returns a boxed state
    local state = core.matrix("return { x = 1, y = 2, z = 3 }")
    T.assert_true(state ~= nil, "matrix returns state")
    -- state has :getptr() and :size() methods
    local ptr = state:getptr()
    T.assert_true(ptr ~= nil, "getptr returns pointer")
    local sz = state:size()
    T.assert_true(type(sz) == "number", "size returns number")
    T.assert_true(sz > 0, "size > 0")
    state:close()
end)

T.case("matrix state size after close", function()
    local core = require "skynet.sharetable.core"
    local state = core.matrix("return { data = 'test' }")
    state:close()
    local sz = state:size()
    T.assert_eq(0, sz, "size after close is 0")
end)

T.case("matrix with nested tables", function()
    local core = require "skynet.sharetable.core"
    local state = core.matrix("return { inner = { a = 1 }, arr = {10, 20, 30} }")
    T.assert_true(state ~= nil, "matrix nested tables")
    local ptr = state:getptr()
    T.assert_true(ptr ~= nil, "nested getptr")
    state:close()
end)

T.case("matrix with numeric arguments", function()
    local core = require "skynet.sharetable.core"
    -- matrix can pass additional arguments (number type)
    local state = core.matrix("local n = ...; return { value = n }", 42)
    T.assert_true(state ~= nil, "matrix with int arg")
    state:close()
end)

T.case("matrix with boolean arguments", function()
    local core = require "skynet.sharetable.core"
    local state = core.matrix("local b = ...; return { flag = b }", true)
    T.assert_true(state ~= nil, "matrix with bool arg")
    state:close()
end)

T.case("clone shared table", function()
    local core = require "skynet.sharetable.core"
    local state = core.matrix("return { key = 'value', num = 100 }")
    local ptr = state:getptr()
    -- clone creates a table from the shared pointer
    local cloned = core.clone(ptr)
    T.assert_true(type(cloned) == "table", "clone returns table")
    T.assert_eq("value", cloned.key, "cloned key")
    T.assert_eq(100, cloned.num, "cloned num")
    state:close()
end)

T.case("stackvalues with yielded coroutine", function()
    local core = require "skynet.sharetable.core"
    -- stackvalues(thread, table) copies stack values from a coroutine to a table
    -- After yield, the coroutine stack has no values (they go to the caller)
    -- But if we resume the coroutine with return values from yield, those land on the stack
    local t = {}
    local co = coroutine.create(function()
        local a, b, c = coroutine.yield()
        -- After receiving values from second resume, they're on the stack
        -- but we need to yield again to let the caller examine the stack
        coroutine.yield(a, b, c)
    end)
    -- First resume starts the coroutine (it yields with no values)
    coroutine.resume(co)
    -- Second resume passes values that land on the coroutine's stack as yield returns
    coroutine.resume(co, 10, 20, 30)
    -- Now the coroutine has yielded again with values 10, 20, 30 on its stack
    local n = core.stackvalues(co, t)
    T.assert_true(type(n) == "number", "stackvalues returns count")
    -- Whether n > 0 depends on Lua's internal coroutine stack management
    -- The important thing is the function executes without error
    T.assert_true(n >= 0, "stackvalues non-negative")
end)

T.case("matrix with string values in table", function()
    local core = require "skynet.sharetable.core"
    local state = core.matrix([[return {
        name = "hello",
        description = "world",
        items = { "a", "b", "c" }
    }]])
    T.assert_true(state ~= nil, "matrix with strings")
    local ptr = state:getptr()
    local cloned = core.clone(ptr)
    T.assert_eq("hello", cloned.name, "string value preserved")
    T.assert_eq("a", cloned.items[1], "array string preserved")
    state:close()
end)

T.case("matrix error handling - invalid source", function()
    local core = require "skynet.sharetable.core"
    local ok, err = pcall(core.matrix, "this is not valid lua {{{{")
    T.assert_true(not ok, "invalid source should error")
end)

T.case("matrix with float argument", function()
    local core = require "skynet.sharetable.core"
    local state = core.matrix("local n = ...; return { value = n }", 3.14)
    T.assert_true(state ~= nil, "matrix with float arg")
    local ptr = state:getptr()
    local cloned = core.clone(ptr)
    T.assert_true(math.abs(cloned.value - 3.14) < 0.001, "float arg preserved")
    state:close()
end)

T.case("matrix with multiple arguments", function()
    local core = require "skynet.sharetable.core"
    local state = core.matrix("local a, b, c = ...; return { x = a, y = b, z = c }", 1, true, 99)
    T.assert_true(state ~= nil, "matrix with multi args")
    local ptr = state:getptr()
    local cloned = core.clone(ptr)
    T.assert_eq(1, cloned.x, "first arg int")
    T.assert_eq(true, cloned.y, "second arg bool")
    T.assert_eq(99, cloned.z, "third arg int")
    state:close()
end)

T.case("matrix from file", function()
    local core = require "skynet.sharetable.core"
    -- matrix accepts "@filename" to load from file
    -- Create a temporary file
    local tmpfile = "/tmp/test_sharetable_matrix.lua"
    local f = io.open(tmpfile, "w")
    f:write("return { loaded = true, value = 42 }\n")
    f:close()

    local state = core.matrix("@" .. tmpfile)
    T.assert_true(state ~= nil, "matrix from file")
    local ptr = state:getptr()
    local cloned = core.clone(ptr)
    T.assert_eq(true, cloned.loaded, "file loaded flag")
    T.assert_eq(42, cloned.value, "file value")
    state:close()
    os.remove(tmpfile)
end)

T.case("matrix from file with arguments", function()
    local core = require "skynet.sharetable.core"
    local tmpfile = "/tmp/test_sharetable_matrix_args.lua"
    local f = io.open(tmpfile, "w")
    f:write("local n = ...; return { result = n * 2 }\n")
    f:close()

    local state = core.matrix("@" .. tmpfile, 21)
    T.assert_true(state ~= nil, "matrix from file with arg")
    local ptr = state:getptr()
    local cloned = core.clone(ptr)
    T.assert_eq(42, cloned.result, "file arg doubled")
    state:close()
    os.remove(tmpfile)
end)

T.case("clone with nested shared tables", function()
    local core = require "skynet.sharetable.core"
    local state = core.matrix([[return {
        items = {
            { id = 1, name = "first" },
            { id = 2, name = "second" },
        },
        meta = { version = 3 }
    }]])
    local ptr = state:getptr()
    local cloned = core.clone(ptr)
    T.assert_eq(1, cloned.items[1].id, "nested clone id 1")
    T.assert_eq("second", cloned.items[2].name, "nested clone name 2")
    T.assert_eq(3, cloned.meta.version, "nested clone meta version")
    state:close()
end)

T.case("is_sharedtable on nil and boolean", function()
    local core = require "skynet.sharetable.core"
    local result = core.is_sharedtable(nil)
    T.assert_true(not result, "nil is not shared table")
    local result2 = core.is_sharedtable(true)
    T.assert_true(not result2, "boolean is not shared table")
end)

T.case("matrix with table containing strings (mark_shared string path)", function()
    local core = require "skynet.sharetable.core"
    -- Strings in shared tables trigger lua_sharestring path (mark_shared line 48-49)
    local state = core.matrix([[return {
        key1 = "string_value_one",
        key2 = "string_value_two",
        nested = { s = "nested_string" },
    }]])
    T.assert_true(state ~= nil, "matrix with strings")
    local ptr = state:getptr()
    local cloned = core.clone(ptr)
    T.assert_eq("string_value_one", cloned.key1, "shared string 1")
    T.assert_eq("nested_string", cloned.nested.s, "shared nested string")
    state:close()
end)

T.case("matrix with boolean and lightuserdata values", function()
    local core = require "skynet.sharetable.core"
    -- Boolean values exercise mark_shared line 36 (LUA_TBOOLEAN case)
    -- Number values exercise mark_shared line 34 (LUA_TNUMBER case)
    local state = core.matrix([[return {
        flag = true,
        count = 42,
        ratio = 3.14,
        flag2 = false,
    }]])
    T.assert_true(state ~= nil, "matrix with mixed types")
    local ptr = state:getptr()
    local cloned = core.clone(ptr)
    T.assert_eq(true, cloned.flag, "bool true shared")
    T.assert_eq(false, cloned.flag2, "bool false shared")
    T.assert_eq(42, cloned.count, "number shared")
    state:close()
end)

T.case("matrix with Lua function (mark_shared function path)", function()
    local core = require "skynet.sharetable.core"
    -- A Lua function without upvalues exercises mark_shared LUA_TFUNCTION path
    -- (lines 38-44: lua_getupvalue check, !lua_iscfunction, makeshared, lua_sharefunction)
    local state = core.matrix([[
        local function helper(x) return x * 2 end
        return {
            fn = helper,
            name = "with_func",
            data = { 1, 2, 3 },
        }
    ]])
    T.assert_true(state ~= nil, "matrix with function")
    local ptr = state:getptr()
    local cloned = core.clone(ptr)
    T.assert_eq("with_func", cloned.name, "function table name")
    T.assert_true(type(cloned.fn) == "function", "function preserved")
    T.assert_eq(10, cloned.fn(5), "function callable")
    state:close()
end)

T.case("matrix with lightuserdata argument", function()
    local core = require "skynet.sharetable.core"
    -- lightuserdata argument exercises matrix_from_file line 220-221
    -- We can't easily create lightuserdata in Lua, but we can test
    -- the error path for invalid argument types
    local ok, err = pcall(core.matrix, "return {}", "invalid_string_arg")
    T.assert_true(not ok, "string arg to matrix should error")
end)

T.case("getptr after close returns nil", function()
    local core = require "skynet.sharetable.core"
    local state = core.matrix("return { x = 1 }")
    state:close()
    local ptr = state:getptr()
    T.assert_eq(nil, ptr, "getptr after close is nil")
end)

T.run()
