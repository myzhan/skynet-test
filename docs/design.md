# Skynet Test Project — Design Document

## 1. Goals

Provide a complete test framework for the [skynet](https://github.com/cloudwu/skynet) game server framework:

- **Functional testing** with console and JUnit XML report output
- **ASAN testing** to detect memory errors
- **Coverage testing** for both C and Lua code
- **Performance benchmarking**

Skynet is compiled from source (git submodule) and tests run against the compiled binary.

## 2. Architecture

### 2.1 Build Pipeline

```
make build        → Compile skynet from submodule
make test         → build + run test runner + generate report
make test-asan    → build with ASAN flags + run test runner + report + asan check
make test-cov     → build with coverage flags + run test runner + lcov/luacov report
make benchmark    → build + run benchmark runner + report
```

### 2.2 Test Execution Flow

```
1. Build skynet (make linux inside skynet/)
2. Start skynet with appropriate config file
3. runner.lua is the bootstrap service:
   a. Discover test cases from test/cases/ (files matching test_*.lua)
   b. Launch each as a skynet service via skynet.newservice()
   c. Call each via skynet.call(svc, "lua", "run"), collect results
   d. Write result JSON to output file
   e. skynet.exit()
4. Post-process result JSON:
   - FORMAT=console: pretty-print to stdout
   - FORMAT=junit: generate JUnit XML
```

### 2.3 Directory Layout

```
skynet-test/
├── AGENTS.md
├── Makefile
├── docs/
│   └── design.md
├── skynet/                    # git submodule
├── mock/
│   ├── Makefile
│   └── mock_getaddrinfo.c
├── test/
│   ├── runner.lua             # Test runner service
│   ├── lib/
│   │   ├── testlib.lua        # Assertion library
│   │   └── junit.lua          # JUnit XML generator
│   ├── cases/                 # Test cases
│   └── config/                # Skynet config files
├── benchmark/
│   ├── runner.lua
│   └── cases/
├── scripts/
│   ├── generate_junit.lua
│   └── cov_report.sh
└── build/                     # Build output (skynet binary, .gcda files)
```

## 3. Test Framework Design

### 3.1 Test Case Contract

Each test case in `test/cases/` is a skynet service that handles a "run" command:

```lua
local skynet = require "skynet"
local testlib = require "testlib"

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd)
        if cmd == "run" then
            local ok, err = pcall(function()
                -- Test logic using testlib assertions
            end)
            if ok then
                skynet.ret(skynet.pack({ status = "pass" }))
            else
                skynet.ret(skynet.pack({ status = "fail", message = tostring(err) }))
            end
        end
    end)
end)
```

### 3.2 Assertion Library (testlib.lua)

```lua
testlib.assert_true(cond, msg)
testlib.assert_false(cond, msg)
testlib.assert_eq(a, b, msg)
testlib.assert_ne(a, b, msg)
testlib.assert_error(fn, msg)
```

On assertion failure, `error()` is raised and caught by the runner.

### 3.3 Skynet Configuration

Tests run inside skynet with a config that includes test paths:

```lua
luaservice = "skynet/service/?.lua;test/?.lua;test/cases/?.lua"
lua_path   = "skynet/lualib/?.lua;test/lib/?.lua"
```

### 3.4 Report Formats

**Console format**: Human-readable output with pass/fail counts and timing.

**JUnit XML format**: Standard JUnit XML schema, compatible with CI tools (Jenkins, GitHub Actions, etc.).

## 4. ASAN Testing

Compile skynet with AddressSanitizer:

```
MYCFLAGS=-fsanitize=address -fno-omit-frame-pointer
LDFLAGS=-fsanitize=address
```

ASAN errors go to stderr. The Makefile detects ASAN output and includes it in the test report.

## 5. Coverage Testing

### 5.1 C Coverage

- Compile skynet with `--coverage` flag via `MYCFLAGS` and `LDFLAGS`
- After test run, `.gcda` files are generated in the build directory
- `lcov` collects coverage data, `genhtml` produces HTML report

### 5.2 Lua Coverage

- `luacov` is loaded via skynet's `preload` config option
- Coverage data written to `luacov.stats.out`
- Report generated with `luacov` CLI

### 5.3 Combined Report

`scripts/cov_report.sh` generates a unified HTML report with both C and Lua coverage data.

## 6. Benchmark Framework

Benchmark runner measures performance of skynet services:

- Each benchmark case runs a specific workload
- Runner measures: operations per second, average latency, p50/p99
- Results formatted as markdown table

## 7. LD_PRELOAD Mock Library

### 7.1 Design

`mock_getaddrinfo.c` is compiled into a shared library that overrides `getaddrinfo()`.

**Environment variable controls:**

| Variable          | Effect                                          |
|-------------------|--------------------------------------------------|
| `MOCK_DNS_MAP`    | Comma-separated `host:ip` mappings               |
| `MOCK_DNS_FAIL`   | If set to 1, `getaddrinfo` returns EAI_FAIL      |
| `MOCK_DNS_DELAY`  | Delay in milliseconds before returning           |

### 7.2 Use in Tests

```
LD_PRELOAD=./mock/mock_getaddrinfo.so MOCK_DNS_MAP=github.com:10.0.0.1 ./skynet config.mockdns
```

### 7.3 Config for Mock DNS Tests

The `config.mockdns` is identical to `config.default` except it may configure test cases that exercise DNS-dependent code paths.

## 8. Future Extensions

- GitHub Actions CI integration
- Fuzz testing support
- Distributed multi-node testing (skynet harbor)
- Test database (mysql/redis/mongo) integration with docker-compose
