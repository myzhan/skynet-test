# AGENTS.md — Skynet Test Project

## Project Overview

A comprehensive test framework for [cloudwu/skynet](https://github.com/cloudwu/skynet), a lightweight online game server framework. Skynet is included as a git submodule under `skynet/`.

## Key Commands

| Command            | Purpose                                                    |
|--------------------|------------------------------------------------------------|
| `make test`        | Run functional tests, output console or JUnit XML report   |
| `make test-asan`   | Run functional tests with AddressSanitizer                 |
| `make test-cov`    | Run functional tests with C + Lua coverage                 |
| `make benchmark`   | Run performance benchmarks                                 |
| `make build`       | Build skynet (without running tests)                       |
| `make clean`       | Clean build artifacts                                      |

Test output format is controlled via `FORMAT=console` (default) or `FORMAT=junit`.

## Architecture

```
skynet-test/
├── AGENTS.md                  # This file
├── Makefile                   # Top-level build and test orchestration
├── docs/design.md             # Design documentation
├── skynet/                    # Git submodule — cloudwu/skynet
├── mock/                      # LD_PRELOAD mock libraries (C)
│   ├── Makefile
│   └── mock_getaddrinfo.c     # Mock DNS resolution
├── test/                      # Functional test framework
│   ├── runner.lua             # Skynet service: test discovery and execution
│   ├── lib/                   # Lua test utilities
│   │   ├── testlib.lua        # Assertion library (assert_eq, assert_true, etc.)
│   │   └── junit.lua          # JUnit XML report generator
│   ├── cases/                 # Test case scripts (each exports run())
│   └── config/                # Skynet config files for different test modes
├── benchmark/                 # Performance test framework
│   ├── runner.lua             # Benchmark runner service
│   └── cases/                 # Benchmark scripts
└── scripts/                   # Shell helpers
    ├── generate_junit.lua     # Convert test results JSON → JUnit XML
    └── cov_report.sh          # Generate combined C + Lua coverage HTML
```

## How Tests Work

1. Each test case is a Lua module under `test/cases/` that exports a `run()` function
2. `runner.lua` is the skynet bootstrap service: it discovers all cases, runs them, collects results
3. Results are written as JSON to a result file, then post-processed for JUnit XML if needed
4. Test cases use `testlib.lua` for assertions — if any assertion fails, the test fails
5. Tests run with a skynet config that points `luaservice` to include `test/cases/`

## Config Files

- `config.default` — Standard config for most tests
- `config.mockdns` — Config for tests that need LD_PRELOAD DNS mocking

Use `CONFIG=<name>` to select a config: `make test CONFIG=mockdns`.

## Adding a New Test

1. Create `test/cases/test_<name>.lua` with a `run()` function
2. Use `local testlib = require "testlib"` for assertions
3. If it needs a special skynet config, add one in `test/config/`

## Adding a New Benchmark

1. Create `benchmark/cases/bench_<name>.lua` with a `run()` function
2. Return results as a table with metrics (ops/sec, latency, etc.)

## Coverage Details

- **C coverage**: Skynet is compiled with `--coverage`, `.gcda` files collected, `lcov` + `genhtml` produces HTML report at `coverage/c/`
- **Lua coverage**: `luacov` is loaded via `LUA_PRELOAD` in config, coverage data written to `coverage/lua/`
- **Combined**: `scripts/cov_report.sh` generates aggregate report

## Mock Library Details

- `mock_getaddrinfo.so`: Overrides `getaddrinfo()` via LD_PRELOAD
- Controlled by env vars: `MOCK_DNS_MAP=host:ip,...`, `MOCK_DNS_FAIL=1`
- Used automatically when `make test CONFIG=mockdns`
