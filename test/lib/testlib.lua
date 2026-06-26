-- testlib.lua — Assertion library and test case framework for skynet tests

local M = {}

-- Case registry and hooks
M._cases = {}
M._setup = nil
M._teardown = nil
M._before_each = nil
M._after_each = nil

-- Assertions

local function format_msg(expected, actual, msg)
    local s = ""
    if msg then
        s = msg .. ": "
    end
    return s .. "expected " .. tostring(expected) .. ", got " .. tostring(actual)
end

function M.assert_true(cond, msg)
    if not cond then
        error(format_msg("truthy", tostring(cond), msg), 2)
    end
end

function M.assert_false(cond, msg)
    if cond then
        error(format_msg("falsy", tostring(cond), msg), 2)
    end
end

function M.assert_eq(expected, actual, msg)
    if expected ~= actual then
        error(format_msg(tostring(expected), tostring(actual), msg), 2)
    end
end

function M.assert_ne(expected, actual, msg)
    if expected == actual then
        error("expected not equal to " .. tostring(expected) .. ", but got " .. tostring(actual) .. (msg and ": " .. msg or ""), 2)
    end
end

function M.assert_error(fn, msg)
    local ok, err = pcall(fn)
    if ok then
        error("expected an error but none was raised" .. (msg and ": " .. msg or ""), 2)
    end
end

function M.assert_not_error(fn, msg)
    local ok, err = pcall(fn)
    if not ok then
        error("unexpected error: " .. tostring(err) .. (msg and ": " .. msg or ""), 2)
    end
end

-- Case registration

function M.case(name, fn)
    M._cases[#M._cases + 1] = { name = name, fn = fn }
end

function M.setup(fn)
    M._setup = fn
end

function M.teardown(fn)
    M._teardown = fn
end

function M.before_each(fn)
    M._before_each = fn
end

function M.after_each(fn)
    M._after_each = fn
end

-- Execution

function M.run_cases()
    local skynet = require "skynet"
    local results = {}

    if M._setup then
        local ok, err = pcall(M._setup)
        if not ok then
            for _, c in ipairs(M._cases) do
                results[#results + 1] = {
                    name = c.name,
                    status = "error",
                    message = "setup failed: " .. tostring(err),
                    duration = 0,
                }
            end
            return { cases = results }
        end
    end

    for _, c in ipairs(M._cases) do
        if M._before_each then
            local ok, err = pcall(M._before_each)
            if not ok then
                results[#results + 1] = {
                    name = c.name,
                    status = "error",
                    message = "before_each failed: " .. tostring(err),
                    duration = 0,
                }
                goto continue
            end
        end

        local start = skynet.now()
        local ok, err = pcall(c.fn)
        local duration = (skynet.now() - start) / 100.0

        if ok then
            results[#results + 1] = { name = c.name, status = "pass", duration = duration }
        else
            results[#results + 1] = { name = c.name, status = "fail", message = tostring(err), duration = duration }
        end

        if M._after_each then
            pcall(M._after_each)
        end

        ::continue::
    end

    if M._teardown then
        pcall(M._teardown)
    end

    return { cases = results }
end

function M.run()
    local skynet = require "skynet"
    skynet.start(function()
        skynet.dispatch("lua", function(_, _, cmd)
            if cmd == "run" then
                skynet.ret(skynet.pack(M.run_cases()))
            end
        end)
    end)
end

return M
