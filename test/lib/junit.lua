-- junit.lua — JUnit XML report generator
-- Converts test result table to JUnit XML format

local M = {}

local function xml_escape(s)
    s = tostring(s)
    s = s:gsub("&", "&amp;")
    s = s:gsub("<", "&lt;")
    s = s:gsub(">", "&gt;")
    s = s:gsub('"', "&quot;")
    s = s:gsub("'", "&apos;")
    return s
end

function M.generate(results)
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
            lines[#lines + 1] = '    <failure message="' .. xml_escape(case.message or "") .. '">'
            if case.output then
                lines[#lines + 1] = xml_escape(case.output)
            end
            lines[#lines + 1] = '    </failure>'
        elseif case.status == "error" then
            lines[#lines + 1] = '    <error message="' .. xml_escape(case.message or "") .. '">'
            if case.output then
                lines[#lines + 1] = xml_escape(case.output)
            end
            lines[#lines + 1] = '    </error>'
        elseif case.status == "skip" then
            lines[#lines + 1] = '    <skipped/>'
        end

        lines[#lines + 1] = '  </testcase>'
    end

    lines[#lines + 1] = '</testsuite>'
    return table.concat(lines, "\n")
end

return M
