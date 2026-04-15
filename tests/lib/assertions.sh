#!/usr/bin/env bash
# Test assertion library for gentoovm validation
# Source this file from test scripts: source "$(dirname "$0")/../lib/assertions.sh"

set -euo pipefail

_PASS=0
_FAIL=0
_SKIP=0
_TEST_NAME="${TEST_NAME:-$(basename "$0" .sh)}"

pass() { _PASS=$((_PASS+1)); echo "  PASS: $1"; }
fail() { _FAIL=$((_FAIL+1)); echo "  FAIL: $1"; }
skip() { _SKIP=$((_SKIP+1)); echo "  SKIP: $1"; }

# Assert a file exists
assert_file_exists() {
    if [ -f "$1" ]; then
        pass "file exists: $1"
    else
        fail "file missing: $1"
    fi
}

# Assert a directory exists
assert_dir_exists() {
    if [ -d "$1" ]; then
        pass "dir exists: $1"
    else
        fail "dir missing: $1"
    fi
}

# Assert a file contains a pattern (grep -qE)
assert_file_contains() {
    local file="$1" pattern="$2" desc="${3:-$2}"
    if grep -qE -- "$pattern" "$file" 2>/dev/null; then
        pass "$desc"
    else
        fail "$desc (pattern '$pattern' not in $file)"
    fi
}

# Assert a file does NOT contain a pattern
assert_file_not_contains() {
    local file="$1" pattern="$2" desc="${3:-must not match $2}"
    if grep -qE -- "$pattern" "$file" 2>/dev/null; then
        fail "$desc (pattern '$pattern' found in $file)"
    else
        pass "$desc"
    fi
}

# Assert a YAML file parses cleanly
assert_yaml_valid() {
    local file="$1"
    if python3 -c 'import yaml, sys; yaml.safe_load(open(sys.argv[1]))' "$file" 2>/dev/null; then
        pass "valid YAML: $(basename "$file")"
    else
        fail "invalid YAML: $(basename "$file")"
    fi
}

# Assert a YAML key has a specific value (arguments passed via sys.argv, no interpolation)
assert_yaml_value() {
    local file="$1" key="$2" expected="$3"
    local desc="${4:-$key = $expected}"
    local actual
    actual=$(python3 - "$file" "$key" <<'PYEOF'
import yaml, sys
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
for k in sys.argv[2].split('.'):
    if isinstance(data, dict):
        data = data.get(k)
    elif isinstance(data, list):
        data = data[int(k)] if k.isdigit() else None
    else:
        data = None
print(data if data is not None else '')
PYEOF
    )
    if [ "$actual" = "$expected" ]; then
        pass "$desc"
    else
        fail "$desc (got '$actual')"
    fi
}

# Assert a shell script has proper header
assert_script_strict() {
    local file="$1"
    if head -10 "$file" | grep -q 'set -euo pipefail'; then
        pass "strict mode: $(basename "$file")"
    else
        fail "missing set -euo pipefail: $(basename "$file")"
    fi
}

# Assert a file is executable
assert_executable() {
    if [ -x "$1" ]; then
        pass "executable: $(basename "$1")"
    else
        fail "not executable: $(basename "$1")"
    fi
}

# Assert shell syntax is valid
assert_shell_syntax() {
    local file="$1"
    if bash -n "$file" 2>/dev/null; then
        pass "syntax OK: $(basename "$file")"
    else
        fail "syntax error: $(basename "$file")"
    fi
}

# Print summary and exit with appropriate code
test_summary() {
    echo ""
    echo "=== $_TEST_NAME Summary ==="
    echo "PASS: $_PASS | FAIL: $_FAIL | SKIP: $_SKIP"
    if [ "$_FAIL" -gt 0 ]; then
        echo "STATUS: FAILED"
        exit 1
    else
        echo "STATUS: PASSED"
        exit 0
    fi
}
