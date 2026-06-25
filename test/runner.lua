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
    -- Strip comments before checking
    local stripped = content:gsub("%-%-[^\n]*", "") -- strip single-line comments
    return stripped:find('skynet%.dispatch') and stripped:find('"run"')
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
        local case_result = {
            name = case.name,
            suite = "default",
            status = "error",
            duration = (skynet.now() - case_start) / 100.0,
        }

        if not ok then
            case_result.status = "error"
            case_result.message = "Runner error: " .. tostring(result)
        else
            case_result.status = result.status or "error"
            case_result.message = result.message
        end

        local symbol = ({ pass = "PASS", fail = "FAIL", error = "ERROR", skip = "SKIP" })[case_result.status] or "FAIL"
        print(string.format("  [%s] %s (%.3fs)", symbol, case.name, case_result.duration))
        if case_result.message then
            print("        " .. case_result.message)
        end

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

    results.duration = (skynet.now() - start_time) / 100.0

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

    skynet.abort()
end)
