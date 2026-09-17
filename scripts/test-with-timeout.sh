#!/usr/bin/env bash
# Wrapper to run tests with a timeout
# Usage: test-with-timeout.sh <seconds> [test-args...]

TIMEOUT=${1:-15}
shift

# Run tests in background
bash scripts/test "$@" &
TEST_PID=$!

# Start timer in background
timed_out_file=$(mktemp)
rm -f "${timed_out_file}"
(
    sleep "$TIMEOUT"
    touch "${timed_out_file}"
    echo ""
    echo "Tests timed out after ${TIMEOUT}s"
    kill -TERM $TEST_PID 2>/dev/null
) &
TIMER_PID=$!

# Wait for tests to complete
wait $TEST_PID
RESULT=$?

# Kill timer if tests finished normally
kill $TIMER_PID 2>/dev/null
wait $TIMER_PID 2>/dev/null

# Distinct exit code (124, like GNU timeout) so timeouts are identifiable
if [[ -f "${timed_out_file}" ]]; then
  rm -f "${timed_out_file}"
  exit 124
fi
rm -f "${timed_out_file}"

exit $RESULT
