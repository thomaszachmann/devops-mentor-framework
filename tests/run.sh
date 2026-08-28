#!/usr/bin/env bash
# Runs every test in this directory. No test framework dependency.
set -uo pipefail
cd "$(dirname "$0")"
command -v jq >/dev/null 2>&1 || { echo "jq is required to run the tests"; exit 1; }
fail=0
for t in test_*.sh; do
  printf '\n== %s ==\n' "$t"
  ./"$t" || fail=1
done

# The global constraint says bash 3.2. Development machines usually run a
# much newer bash from Homebrew, so a green suite here proves nothing about
# a stock macOS. /bin/bash on macOS is 3.2 - run everything again under it.
if [ -x /bin/bash ] && /bin/bash --version | head -1 | grep -q 'version 3'; then
  printf '\n== re-running under /bin/bash (3.2) ==\n'
  for t in test_*.sh; do
    /bin/bash ./"$t" >/dev/null 2>&1 \
      && printf 'ok   %s under bash 3.2\n' "$t" \
      || { printf 'FAIL %s under bash 3.2\n' "$t"; fail=1; }
  done
else
  printf '\nnote: no bash 3.2 available, 3.2 compatibility unverified\n'
fi

printf '\n'
[ "$fail" = 0 ] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit "$fail"
