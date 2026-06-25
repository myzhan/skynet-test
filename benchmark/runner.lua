-- runner.lua — Skynet benchmark runner service
local skynet = require "skynet"
require "skynet.manager" -- for skynet.abort()

local RESULT_FILE = "../build/benchmarks/bench_result.json"

local HELPER_SUFFIXES = { "_echo", "_service", "_helper", "_svc" }

local function is_helper_name(name)
    for _, suffix in ipairs(HELPER_SUFFIXES) do
        if name:sub(-#suffix) == suffix then
            return true
        end
    end
    return false
end

local function discover_cases()
    local cases = {}
    local handle = io.popen('ls ../benchmark/cases/bench_*.lua 2>/dev/null')
    if handle then
        for file in handle:lines() do
            local name = file:match("bench_(.+)%.lua$")
            if name and name ~= "" and not is_helper_name(name) then
                cases[#cases + 1] = { name = name, file = file }
            end
        end
        handle:close()
    end
    return cases
end

local function run_case(case)
    local svc_name = "bench_" .. case.name
    local ok, svc = pcall(skynet.newservice, svc_name)
    if not ok then
        return { error = "Failed to launch service: " .. tostring(svc) }
    end
    local ok2, result = pcall(skynet.call, svc, "lua", "run")
    pcall(skynet.kill, svc)
    if not ok2 then
        return { error = "Benchmark error: " .. tostring(result) }
    end
    return result
end

skynet.start(function()
    print("=== Skynet Benchmark Runner ===")
    print("")

    local cases = discover_cases()
    print(string.format("Discovered %d benchmark case(s)", #cases))
    print("")

    print("┌──────────────────────────────────────────┬──────────────┬────────────┬────────────┐")
    print("│ Benchmark                                 │    Ops/sec   │ Avg Time   │ Iterations │")
    print("├──────────────────────────────────────────┼──────────────┼────────────┼────────────┤")

    local all_results = {}

    for _, case in ipairs(cases) do
        local ok, result = pcall(run_case, case)
        if not ok or result.error then
            print(string.format("│ %-40s │ %12s │ %10s │ %10d │",
                case.name:sub(1, 40), "ERROR", "-", 0))
            all_results[#all_results + 1] = {
                name = case.name,
                error = tostring(result and result.error or ok),
            }
        else
            local ops = result.ops_per_sec or 0
            local avg = result.avg_time_ms or 0
            local iters = result.iterations or 0
            local ops_str = string.format("%.0f", ops)
            local time_str
            if avg < 1 then
                time_str = string.format("%.2f μs", avg * 1000)
            elseif avg < 1000 then
                time_str = string.format("%.2f ms", avg)
            else
                time_str = string.format("%.3f s", avg / 1000)
            end
            print(string.format("│ %-40s │ %12s │ %10s │ %10d │",
                case.name:sub(1, 40), ops_str, time_str, iters))
            all_results[#all_results + 1] = {
                name = case.name,
                ops_per_sec = ops,
                avg_time_ms = avg,
                iterations = iters,
            }
        end
    end

    print("└──────────────────────────────────────────┴──────────────┴────────────┴────────────┘")
    print("")

    -- Write JSON result
    local f = io.open(RESULT_FILE, "w")
    if f then
        f:write("{\n  \"benchmarks\": [\n")
        for i, r in ipairs(all_results) do
            f:write("    {\n")
            f:write(string.format('      "name": "%s"', r.name:gsub('"', '\\"')))
            if r.error then
                f:write(string.format(',\n      "error": "%s"', r.error:gsub('"', '\\"')))
            else
                f:write(string.format(',\n      "ops_per_sec": %d', r.ops_per_sec))
                f:write(string.format(',\n      "avg_time_ms": %.4f', r.avg_time_ms))
                f:write(string.format(',\n      "iterations": %d', r.iterations))
            end
            f:write("\n    }")
            if i < #all_results then f:write(",") end
            f:write("\n")
        end
        f:write("  ]\n}\n")
        f:close()
    end

    print("=== Benchmark complete ===")
    skynet.abort()
end)
