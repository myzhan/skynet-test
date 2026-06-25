#!/usr/bin/env lua
-- generate_junit.lua — Convert test result JSON to JUnit XML
-- Usage: lua generate_junit.lua <result.json> [output.xml]

local function read_json(filepath)
    local f = io.open(filepath, "r")
    if not f then
        io.stderr:write("ERROR: Cannot open " .. filepath .. "\n")
        os.exit(1)
    end
    local content = f:read("*a")
    f:close()

    -- Simple JSON parser for our known format
    local results = {
        cases = {},
    }

    -- Parse top-level fields
    results.total = tonumber(content:match('"total":%s*(%d+)')) or 0
    results.passed = tonumber(content:match('"passed":%s*(%d+)')) or 0
    results.failed = tonumber(content:match('"failed":%s*(%d+)')) or 0
    results.errors = tonumber(content:match('"errors":%s*(%d+)')) or 0
    results.skipped = tonumber(content:match('"skipped":%s*(%d+)')) or 0
    results.duration = tonumber(content:match('"duration":%s*(%d+%.?%d*)')) or 0

    -- Parse cases array
    for name, suite, status, duration, message in content:gmatch('"name":%s*"([^"]*)"[^}]-"suite":%s*"([^"]*)"[^}]-"status":%s*"([^"]*)"[^}]-"duration":%s*(%d+%.?%d*)()') do
        local msg = nil
        -- Check for message field after this position
        local after_dur = content:sub(message)
        local msg_match = after_dur:match('^[^}]-"message":%s*"([^"]*)"')
        if msg_match then
            msg = msg_match:gsub('\\n', '\n'):gsub('\\"', '"')
        end

        results.cases[#results.cases + 1] = {
            name = name,
            suite = suite,
            status = status,
            duration = tonumber(duration) or 0,
            message = msg,
        }
    end

    return results
end

local function xml_escape(s)
    s = tostring(s)
    s = s:gsub("&", "&amp;")
    s = s:gsub("<", "&lt;")
    s = s:gsub(">", "&gt;")
    s = s:gsub('"', "&quot;")
    s = s:gsub("'", "&apos;")
    return s
end

local function generate_xml(results)
    local total = results.total or 0
    local passed = results.passed or 0
    local failed = results.failed or 0
    local errors = results.errors or 0
    local skipped = results.skipped or 0
    local duration = results.duration or 0
    local timestamp = os.date("!%Y-%m-%dT%H:%M:%S")

    local lines = {}
    lines[#lines + 1] = '<?xml version="1.0" encoding="UTF-8"?>'
    lines[#lines + 1] = string.format(
        '<testsuite name="skynet" tests="%d" failures="%d" errors="%d" skipped="%d" time="%.3f" timestamp="%s">',
        total, failed, errors, skipped, duration, timestamp
    )

    for _, case in ipairs(results.cases or {}) do
        local case_time = case.duration or 0
        lines[#lines + 1] = string.format(
            '  <testcase classname="skynet.%s" name="%s" time="%.3f">',
            xml_escape(case.suite or "default"),
            xml_escape(case.name or "unknown"),
            case_time
        )

        if case.status == "fail" then
            local msg = xml_escape(case.message or "Test failed")
            lines[#lines + 1] = string.format('    <failure message="%s"/>', msg)
        elseif case.status == "error" then
            local msg = xml_escape(case.message or "Internal error")
            lines[#lines + 1] = string.format('    <error message="%s"/>', msg)
        elseif case.status == "skip" then
            lines[#lines + 1] = '    <skipped/>'
        end

        lines[#lines + 1] = '  </testcase>'
    end

    lines[#lines + 1] = '</testsuite>'
    return table.concat(lines, "\n")
end

-- Main
if #arg < 1 then
    io.stderr:write("Usage: lua generate_junit.lua <result.json> [output.xml]\n")
    os.exit(1)
end

local input_file = arg[1]
local output_file = arg[2] or "junit.xml"

local results = read_json(input_file)
local xml = generate_xml(results)
local f = io.open(output_file, "w")
if f then
    f:write(xml)
    f:close()
    print("JUnit XML written to " .. output_file)
else
    io.stderr:write("ERROR: Cannot write " .. output_file .. "\n")
    os.exit(1)
end
