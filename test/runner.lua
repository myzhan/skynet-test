-- runner.lua — Skynet test runner service
-- Discovers test cases, launches them as services, collects results

local skynet = require "skynet"
require "skynet.manager" -- for skynet.abort()

local RESULT_FILE = "../build/results/result.json"

local HELPER_SUFFIXES = { "_echo", "_service", "_helper", "_svc" }

local function is_helper_name(name)
    for _, suffix in ipairs(HELPER_SUFFIXES) do
        if name:sub(-#suffix) == suffix then
            return true
        end
    end
    return false
end

local function file_has_run_handler(filepath)
    local f = io.open(filepath, "r")
    if not f then return false end
    local content = f:read("*a")
    f:close()
    local stripped = content:gsub("%-%-[^\n]*", "") -- strip single-line comments
    -- Legacy pattern: skynet.dispatch + "run"
    if stripped:find('skynet%.dispatch') and stripped:find('"run"') then
        return true
    end
    -- New pattern: T.run() or testlib.run()
    if stripped:find('%.run%(') and stripped:find('%.case%(') then
        return true
    end
    return false
end

local function discover_cases()
    local cases = {}
    local handle = io.popen('ls ../test/cases/test_*.lua 2>/dev/null')
    if handle then
        for file in handle:lines() do
            local name = file:match("test_(.+)%.lua$")
            if name and name ~= "" and not is_helper_name(name) then
                if file_has_run_handler(file) then
                    cases[#cases + 1] = {
                        name = name,
                        file = file,
                    }
                end
            end
        end
        handle:close()
    end
    return cases
end

local function run_case(case)
    local svc_name = "test_" .. case.name
    local ok, svc = pcall(skynet.newservice, svc_name)
    if not ok then
        return {
            status = "error",
            message = "Failed to launch service: " .. tostring(svc),
        }
    end

    -- Call the test service to run
    local ok2, result = pcall(skynet.call, svc, "lua", "run")
    -- Clean up
    pcall(skynet.kill, svc)

    if not ok2 then
        return {
            status = "error",
            message = "Test service error: " .. tostring(result),
        }
    end

    return result
end

skynet.start(function()
    print("=== Skynet Test Runner ===")
    print("")

    local cases = discover_cases()
    print(string.format("Discovered %d test case(s)", #cases))
    print("")

    local results = {
        total = #cases,
        passed = 0,
        failed = 0,
        errors = 0,
        skipped = 0,
        duration = 0,
        cases = {},
    }

    local start_time = skynet.now()

    for _, case in ipairs(cases) do
        local case_start = skynet.now()

        local ok, result = pcall(run_case, case)
        local elapsed = (skynet.now() - case_start) / 100.0

        if not ok then
            -- Runner-level error
            local case_result = {
                name = case.name,
                suite = case.name,
                status = "error",
                duration = elapsed,
                message = "Runner error: " .. tostring(result),
            }
            results.errors = results.errors + 1
            results.cases[#results.cases + 1] = case_result
        elseif result.cases then
            -- Multi-case result: expand sub-cases
            for _, sub in ipairs(result.cases) do
                local case_result = {
                    name = case.name .. "/" .. sub.name,
                    suite = case.name,
                    status = sub.status or "error",
                    duration = sub.duration or 0,
                    message = sub.message,
                }
                if case_result.status == "pass" then
                    results.passed = results.passed + 1
                elseif case_result.status == "fail" then
                    results.failed = results.failed + 1
                elseif case_result.status == "error" then
                    results.errors = results.errors + 1
                elseif case_result.status == "skip" then
                    results.skipped = results.skipped + 1
                end
                results.cases[#results.cases + 1] = case_result
            end
            results.total = results.total + #result.cases - 1
        else
            -- Legacy single-case result
            local case_result = {
                name = case.name,
                suite = case.name,
                status = result.status or "error",
                duration = elapsed,
                message = result.message,
            }
            if case_result.status == "pass" then
                results.passed = results.passed + 1
            elseif case_result.status == "fail" then
                results.failed = results.failed + 1
            elseif case_result.status == "error" then
                results.errors = results.errors + 1
            elseif case_result.status == "skip" then
                results.skipped = results.skipped + 1
            end
            results.cases[#results.cases + 1] = case_result
        end
    end

    results.duration = (skynet.now() - start_time) / 100.0

    -- Print results as a table
    local name_width = 4
    for _, c in ipairs(results.cases) do
        if #c.name > name_width then name_width = #c.name end
    end
    name_width = name_width + 2

    local sep = "+" .. string.rep("-", name_width + 2) .. "+" .. string.rep("-", 10) .. "+" .. string.rep("-", 10) .. "+" .. string.rep("-", 40) .. "+"
    local hdr = string.format("| %-" .. name_width .. "s | %-8s | %-8s | %-38s |", "Name", "Status", "Duration", "Message")

    print(sep)
    print(hdr)
    print(sep)
    for _, c in ipairs(results.cases) do
        local status_str = c.status:upper()
        local dur_str = string.format("%.3fs", c.duration)
        local msg = c.message or ""
        if #msg > 38 then msg = msg:sub(1, 35) .. "..." end
        print(string.format("| %-" .. name_width .. "s | %-8s | %-8s | %-38s |", c.name, status_str, dur_str, msg))
    end
    print(sep)

    print("")
    print(string.format("=== Results: %d total, %d passed, %d failed, %d errors, %d skipped (%.3fs) ===",
        results.total, results.passed, results.failed, results.errors, results.skipped, results.duration))

    -- Write JSON result
    local json_parts = {}
    json_parts[#json_parts + 1] = '{\n'
    json_parts[#json_parts + 1] = string.format('  "total": %d,\n', results.total)
    json_parts[#json_parts + 1] = string.format('  "passed": %d,\n', results.passed)
    json_parts[#json_parts + 1] = string.format('  "failed": %d,\n', results.failed)
    json_parts[#json_parts + 1] = string.format('  "errors": %d,\n', results.errors)
    json_parts[#json_parts + 1] = string.format('  "skipped": %d,\n', results.skipped)
    json_parts[#json_parts + 1] = string.format('  "duration": %.3f,\n', results.duration)
    json_parts[#json_parts + 1] = '  "cases": [\n'
    for i, case in ipairs(results.cases) do
        json_parts[#json_parts + 1] = '    {\n'
        local name = case.name:gsub('"', '\\"')
        json_parts[#json_parts + 1] = string.format('      "name": "%s",\n', name)
        json_parts[#json_parts + 1] = string.format('      "suite": "%s",\n', case.suite or "default")
        json_parts[#json_parts + 1] = string.format('      "status": "%s",\n', case.status)
        json_parts[#json_parts + 1] = string.format('      "duration": %.4f', case.duration or 0)
        if case.message then
            local msg = case.message:gsub('"', '\\"'):gsub('\n', '\\n')
            json_parts[#json_parts + 1] = string.format(',\n      "message": "%s"', msg)
        end
        json_parts[#json_parts + 1] = '\n    }'
        if i < #results.cases then
            json_parts[#json_parts + 1] = ','
        end
        json_parts[#json_parts + 1] = '\n'
    end
    json_parts[#json_parts + 1] = '  ]\n'
    json_parts[#json_parts + 1] = '}\n'
    local f = io.open(RESULT_FILE, "w")
    if f then
        f:write(table.concat(json_parts))
        f:close()
        print("Results written to " .. RESULT_FILE)
    end

    os.exit(0)
end)
