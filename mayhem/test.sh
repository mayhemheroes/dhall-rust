#!/usr/bin/env bash
#
# mayhem/test.sh — RUN dhall-rust's own functional test suite (already compiled by
# mayhem/build.sh with the project's normal flags: `cargo test --release --no-run`
# over the whole workspace, exactly what upstream CI runs). This includes the unit
# tests of dhall/dhall_proc_macros/serde_dhall AND the dhall-lang spec suite driven
# by dhall/tests/spec.rs (libtest-mimic; needs the dhall-lang submodule). Asserts
# behavior via libtest pass/fail counts and emits a CTRF summary; exits non-zero
# iff any test failed.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${MAYHEM_JOBS:=$(nproc)}"
cd "$SRC"

# Match build.sh: override upstream's `rust-toolchain` (stable) with the image's
# pinned default toolchain so the pre-built test binaries are reused, not rebuilt.
RUSTUP_TOOLCHAIN="$(rustup default | awk '{print $1}')"
export RUSTUP_TOOLCHAIN

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

# RUN the pre-built suite (build.sh already compiled it with normal flags; this run
# reuses the cached test binaries).
OUT="$(mktemp)"
env -u RUSTFLAGS cargo test --release --workspace 2>&1 | tee "$OUT"

# Sum every libtest "test result:" line: "test result: ok. N passed; M failed; K ignored; ..."
PASSED=0; FAILED=0; IGN=0
while read -r p f i; do
  PASSED=$((PASSED + p)); FAILED=$((FAILED + f)); IGN=$((IGN + i))
done < <(grep -E '^test result:' "$OUT" \
         | sed -E 's/^test result:[^0-9]*([0-9]+) passed; ([0-9]+) failed; ([0-9]+) ignored.*/\1 \2 \3/')
rm -f "$OUT"

if [ "$PASSED" -eq 0 ] && [ "$FAILED" -eq 0 ]; then
  echo "ERROR: no test-result summary parsed — test binaries missing (build.sh bug)?" >&2
  emit_ctrf "cargo-test" 0 1 0
  exit 1
fi

emit_ctrf "cargo-test" "$PASSED" "$FAILED" "$IGN"
