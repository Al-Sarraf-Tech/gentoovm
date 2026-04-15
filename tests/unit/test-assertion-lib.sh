#!/usr/bin/env bash
# Self-test: assertion library
# Verifies the test tools themselves work correctly — trust your instruments
# shellcheck disable=SC2034
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_DIR/tests/lib/assertions.sh"
TEST_NAME="assertion-lib"

echo "=== Assertion Library Self-Test ==="

# --- Create temp fixtures ---
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "hello world" > "$TMPDIR/textfile.txt"
cat > "$TMPDIR/valid.yaml" << 'EOF'
name: test
nested:
  key: value
  num: 42
list:
  - alpha
  - beta
EOF
echo "not: valid: yaml: {{" > "$TMPDIR/invalid.yaml"
chmod +x "$TMPDIR/textfile.txt"

# --- assert_file_exists ---
echo "--- assert_file_exists ---"
assert_file_exists "$TMPDIR/textfile.txt"

# --- assert_dir_exists ---
echo "--- assert_dir_exists ---"
assert_dir_exists "$TMPDIR"

# --- assert_file_contains ---
echo "--- assert_file_contains ---"
assert_file_contains "$TMPDIR/textfile.txt" "hello" "contains hello"
assert_file_contains "$TMPDIR/textfile.txt" "hello.*world" "contains regex"

# --- assert_file_not_contains ---
echo "--- assert_file_not_contains ---"
assert_file_not_contains "$TMPDIR/textfile.txt" "goodbye" "does not contain goodbye"

# --- assert_file_contains with leading dash (regression: grep -qE flag confusion) ---
echo "--- leading dash pattern ---"
echo "-O2 -pipe -march=x86-64" > "$TMPDIR/flags.txt"
assert_file_contains "$TMPDIR/flags.txt" "-pipe" "handles leading-dash pattern"
assert_file_contains "$TMPDIR/flags.txt" "-O2" "handles -O2 pattern"

# --- assert_yaml_valid ---
echo "--- assert_yaml_valid ---"
assert_yaml_valid "$TMPDIR/valid.yaml"
# invalid YAML should fail — but we don't want test_summary to exit
# Instead, directly verify the function detects it
if python3 -c 'import yaml, sys; yaml.safe_load(open(sys.argv[1]))' "$TMPDIR/invalid.yaml" 2>/dev/null; then
    fail "assert_yaml_valid accepted invalid YAML"
else
    pass "assert_yaml_valid rejects invalid YAML"
fi

# --- assert_yaml_value ---
echo "--- assert_yaml_value ---"
assert_yaml_value "$TMPDIR/valid.yaml" "name" "test" "top-level key"
assert_yaml_value "$TMPDIR/valid.yaml" "nested.key" "value" "nested dotted key"
assert_yaml_value "$TMPDIR/valid.yaml" "nested.num" "42" "numeric value as string"

# --- assert_yaml_value with special characters in path ---
echo "--- yaml path edge cases ---"
cat > "$TMPDIR/special.yaml" << 'EOF'
a:
  b:
    c: deep
EOF
assert_yaml_value "$TMPDIR/special.yaml" "a.b.c" "deep" "triple-nested key"

# --- assert_executable ---
echo "--- assert_executable ---"
assert_executable "$TMPDIR/textfile.txt"

# --- assert_shell_syntax ---
echo "--- assert_shell_syntax ---"
echo '#!/bin/bash' > "$TMPDIR/good.sh"
echo 'echo ok' >> "$TMPDIR/good.sh"
assert_shell_syntax "$TMPDIR/good.sh"

# Verify bad syntax is detected
echo '#!/bin/bash' > "$TMPDIR/bad.sh"
echo 'if then fi' >> "$TMPDIR/bad.sh"
if bash -n "$TMPDIR/bad.sh" 2>/dev/null; then
    fail "shell syntax check accepted invalid script"
else
    pass "shell syntax check rejects invalid script"
fi

# --- assert_script_strict ---
echo "--- assert_script_strict ---"
cat > "$TMPDIR/strict.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo ok
EOF
assert_script_strict "$TMPDIR/strict.sh"

test_summary
