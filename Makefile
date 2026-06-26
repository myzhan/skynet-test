# Skynet Test Project — Top-level Makefile
# ==========================================

PLAT ?= linux
FORMAT ?= console
CONFIG ?= default

# Ensure system tools take precedence over cross-compiler toolchains (ESP32 etc.)
export PATH := /usr/bin:/bin:$(PATH)

SKYNET_DIR := skynet
SKYNET_BIN := $(SKYNET_DIR)/skynet
BUILD_DIR := build
RESULT_DIR := $(BUILD_DIR)/results
COV_DIR := $(BUILD_DIR)/coverage
BENCH_RESULT_DIR := $(BUILD_DIR)/benchmarks
MOCK_DIR := mock

# ASAN flags
ASAN_CFLAGS := -fsanitize=address -fno-omit-frame-pointer -g -O1
ASAN_LDFLAGS := -fsanitize=address

# Coverage flags
COV_CFLAGS := --coverage -g -O0
COV_LDFLAGS := --coverage

# Default Lua
LUA ?= lua

# Mock env vars for DNS mock tests
MOCK_ENV = LD_PRELOAD=../mock/mock_getaddrinfo.so MOCK_DNS_MAP=github.com:10.0.0.1

.PHONY: all build build-asan build-cov build-mock test test-asan test-cov benchmark clean cleanall clean-cov help

help:
	@echo "Skynet Test Project"
	@echo "==================="
	@echo "make build              - Build skynet"
	@echo "make test [FORMAT=console|junit] [CONFIG=default|mockdns]"
	@echo "make test-asan [FORMAT=console|junit]"
	@echo "make test-cov           - Run tests with C coverage HTML report"
	@echo "make benchmark          - Run performance benchmarks"
	@echo "make clean              - Clean test artifacts"
	@echo "make cleanall           - Clean everything including skynet build"

# ============================================
# Build targets
# ============================================

build:
	@echo "=== Building skynet ==="
	$(MAKE) -C $(SKYNET_DIR) $(PLAT)
	@mkdir -p $(BUILD_DIR)

build-asan:
	@echo "=== Building skynet with ASAN ==="
	$(MAKE) -C $(SKYNET_DIR) $(PLAT) MYCFLAGS="$(ASAN_CFLAGS)" LDFLAGS="$(ASAN_LDFLAGS)"
	@mkdir -p $(BUILD_DIR)

build-cov:
	@echo "=== Building skynet with coverage ==="
	$(MAKE) -C $(SKYNET_DIR) $(PLAT) MYCFLAGS="$(COV_CFLAGS)" LDFLAGS="$(COV_LDFLAGS)"
	@mkdir -p $(BUILD_DIR)

build-mock:
	@echo "=== Building mock libraries ==="
	$(MAKE) -C $(MOCK_DIR)

# ============================================
# Test targets
# ============================================

test: build build-mock
	@echo "=== Running functional tests [config=$(CONFIG), format=$(FORMAT)] ==="
	@mkdir -p $(RESULT_DIR)
	@cd $(SKYNET_DIR) && \
		$(if $(findstring mockdns,$(CONFIG)),$(MOCK_ENV),) \
		./skynet ../test/config/config.$(CONFIG) \
		> ../$(RESULT_DIR)/test_output.log 2>&1; \
		EXIT_CODE=$$?; \
		if [ $$EXIT_CODE -ne 0 ]; then \
			echo "skynet exited with code $$EXIT_CODE"; \
		fi
	@if [ "$(FORMAT)" = "junit" ]; then \
		$(LUA) scripts/generate_junit.lua $(RESULT_DIR)/result.json $(RESULT_DIR)/junit.xml; \
		echo "JUnit report: $(RESULT_DIR)/junit.xml"; \
	else \
		grep -A 1000 '^+---' $(RESULT_DIR)/test_output.log 2>/dev/null | grep -B 1000 '^=== Results' || cat $(RESULT_DIR)/result.json 2>/dev/null || true; \
	fi
	@echo "=== Tests complete ==="

test-asan: build-asan build-mock
	@echo "=== Running ASAN functional tests [config=$(CONFIG), format=$(FORMAT)] ==="
	@mkdir -p $(RESULT_DIR)
	@cd $(SKYNET_DIR) && \
		ASAN_OPTIONS=log_path=../$(RESULT_DIR)/asan:exitcode=1 \
		$(if $(findstring mockdns,$(CONFIG)),$(MOCK_ENV),) \
		./skynet ../test/config/config.$(CONFIG) \
		> ../$(RESULT_DIR)/test_output.log 2>&1; \
		EXIT_CODE=$$?; \
		if [ $$EXIT_CODE -ne 0 ]; then \
			echo "skynet exited with code $$EXIT_CODE"; \
		fi
	@# Check for ASAN reports
	@if ls $(RESULT_DIR)/asan.* 1>/dev/null 2>&1; then \
		echo "=== ASAN ERRORS DETECTED ==="; \
		cat $(RESULT_DIR)/asan.*; \
		echo "See $(RESULT_DIR)/asan.* for details"; \
		exit 1; \
	else \
		echo "=== No ASAN errors detected ==="; \
	fi
	@if [ "$(FORMAT)" = "junit" ]; then \
		$(LUA) scripts/generate_junit.lua $(RESULT_DIR)/result.json $(RESULT_DIR)/junit.xml; \
		echo "JUnit report: $(RESULT_DIR)/junit.xml"; \
	fi

test-cov: clean-cov build-cov build-mock
	@echo "=== Running coverage tests [config=$(CONFIG)] ==="
	@mkdir -p $(RESULT_DIR) $(COV_DIR)
	@cd $(SKYNET_DIR) && \
		$(if $(findstring mockdns,$(CONFIG)),$(MOCK_ENV),) \
		./skynet ../test/config/config.$(CONFIG) \
		> ../$(RESULT_DIR)/test_output.log 2>&1
	@grep -A 1000 '^+---' $(RESULT_DIR)/test_output.log 2>/dev/null | grep -B 1000 '^=== Results' || cat $(RESULT_DIR)/result.json 2>/dev/null || true
	@echo "=== Generating C coverage HTML report ==="
	@scripts/cov_report.sh . $(COV_DIR)
	@echo ""
	@echo "=== Coverage complete ==="
	@echo "Coverage report: $(COV_DIR)/index.html"

clean-cov:
	@echo "=== Cleaning coverage data and build artifacts ==="
	@find $(SKYNET_DIR) -name "*.gcda" -delete 2>/dev/null || true
	@find $(SKYNET_DIR) -name "*.gcno" -delete 2>/dev/null || true
	$(MAKE) -C $(SKYNET_DIR) clean

# ============================================
# Benchmark targets
# ============================================

benchmark: build
	@echo "=== Running benchmarks ==="
	@mkdir -p $(BENCH_RESULT_DIR)
	@TIMESTAMP=$$(date +%Y%m%d_%H%M%S); \
	cd $(SKYNET_DIR) && \
		./skynet ../benchmark/config \
		> ../$(BENCH_RESULT_DIR)/bench_$$TIMESTAMP.log 2>&1
	@echo "=== Benchmarks complete ==="
	@echo "Results: $(BENCH_RESULT_DIR)/"
	@ls -t $(BENCH_RESULT_DIR)/bench_*.log | head -1 | xargs cat

# ============================================
# Clean targets
# ============================================

clean:
	rm -rf $(BUILD_DIR)
	$(MAKE) -C $(MOCK_DIR) clean

cleanall: clean
	$(MAKE) -C $(SKYNET_DIR) clean
