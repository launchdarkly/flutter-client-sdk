#!/usr/bin/env bash
# Stop hook: block session end until `melos run analyze` and `melos run test` pass.
# Reads Claude Code's Stop-hook JSON on stdin. Exit 2 tells Claude to keep going;
# stderr is surfaced back to the model as the reason.

set -u

input=$(cat)

if [ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}" || {
  echo "stop-lint-test.sh: could not cd to project root" >&2
  exit 2
}

if ! analyze_output=$(melos run analyze 2>&1); then
  printf '%s\n\nmelos run analyze failed — fix analyzer errors before ending the task.\n' "$analyze_output" >&2
  exit 2
fi

if ! test_output=$(melos run test 2>&1); then
  printf '%s\n\nmelos run test failed — fix failing tests before ending the task.\n' "$test_output" >&2
  exit 2
fi

exit 0
