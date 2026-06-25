-- testlib.lua — Assertion library for skynet tests

local M = {}

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

return M
