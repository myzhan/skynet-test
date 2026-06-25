#!/bin/bash
# cov_report.sh — Generate C coverage HTML report using gcovr
# Usage: ./cov_report.sh <project_root> <output_dir>

set -e

PROJECT_ROOT="$(realpath "$1")"
OUTPUT_DIR="$2"

if [ -z "$PROJECT_ROOT" ] || [ -z "$OUTPUT_DIR" ]; then
    echo "Usage: $0 <project_root> <output_dir>"
    exit 1
fi

SKYNET_DIR="$PROJECT_ROOT/skynet"
COV_OUT="$PROJECT_ROOT/$OUTPUT_DIR"
mkdir -p "$COV_OUT"

if ! command -v gcovr &>/dev/null; then
    echo "ERROR: gcovr not found. Install via: pip install gcovr"
    exit 1
fi

# gcov expects .gcno/.gcda files named <source>.gcno but skynet build
# produces <binary>-<source>.gcno files. Create symlinks to fix this.
echo "Setting up coverage file symlinks..."
cd "$SKYNET_DIR"

# In the root directory: skynet-<source>.gcno → <source>.gcno
for f in skynet-*.gcno; do
    [ -f "$f" ] || continue
    base="${f#skynet-}"
    ln -sf "$f" "$base" 2>/dev/null
done
for f in skynet-*.gcda; do
    [ -f "$f" ] || continue
    base="${f#skynet-}"
    ln -sf "$f" "$base" 2>/dev/null
done

# In luaclib: <so>-<source>.gcno → <source>.gcno
for subdir in luaclib cservice; do
    if [ -d "$subdir" ]; then
        cd "$subdir"
        for f in *.gcno; do
            [ -f "$f" ] || continue
            base="${f##*-}"
            ln -sf "$f" "$base" 2>/dev/null
        done
        for f in *.gcda; do
            [ -f "$f" ] || continue
            base="${f##*-}"
            ln -sf "$f" "$base" 2>/dev/null
        done
        cd "$SKYNET_DIR"
    fi
done

# Run gcovr from the skynet directory
echo "Generating HTML report..."
gcovr \
    -r "$SKYNET_DIR" \
    --object-directory "$SKYNET_DIR" \
    --filter 'skynet-src/.*' \
    --filter 'lualib-src/.*' \
    --filter 'service-src/.*' \
    --exclude '.*3rd/.*' \
    --exclude '.*jemalloc.*' \
    --exclude '.*lpeg.*' \
    --exclude '.*lua-md5.*' \
    --exclude '.*sproto.*' \
    --gcov-ignore-errors 'no_working_dir_found' \
    --html --html-details \
    -o "$COV_OUT/index.html"

echo ""
echo "Coverage report: $OUTPUT_DIR/index.html"
