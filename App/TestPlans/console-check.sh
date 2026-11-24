#!/bin/sh
# Console check: runs the Smoke UI tests on your simulator and fails on anything the app logged that isn't
# known noise (App/TestPlans/console-allowlist.txt). It reads the simulator's unified log for the Ackshually
# process: error and fault messages, plus any message naming a SwiftUI/UIKit view bug (AttributeGraph cycles,
# Observation feedback loops, onChange several times per frame, publishing or modifying state during a view
# update, unsatisfiable constraints, main-thread I/O). Offending lines are printed with their counts.
#
#   App/TestPlans/console-check.sh <simulator-udid> [more xcodebuild arguments]
#       e.g. … -derivedDataPath /tmp/dd    or    … -only-testing:AckshuallyUITests/ConsoleTourUITests
#   App/TestPlans/console-check.sh <simulator-udid> --since "2026-11-24 18:40:00"
#       check the log since then without running tests (after running the app by hand)
#   App/TestPlans/console-check.sh --file console.txt
#       check a console copied from Xcode
#
# Exit status: 1 if the tests or the check failed. Runs xcodebuild under `taskpolicy -b`, serially, on the one
# simulator given (no clones). Set CONSOLE_CHECK_PLAN to run another test plan.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
allowlist="$here/console-allowlist.txt"
project="$here/../Ackshually.xcodeproj"

usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
[ $# -ge 1 ] || usage

# Error/fault messages from the app, plus default-level ones that name a view bug.
predicate='process == "Ackshually" AND (messageType == error OR messageType == fault
  OR subsystem == "com.apple.runtime-issues" OR subsystem == "com.apple.attributegraph"
  OR eventMessage CONTAINS[c] "cycle detected" OR eventMessage CONTAINS "feedback loop"
  OR eventMessage CONTAINS "multiple times per frame" OR eventMessage CONTAINS "Publishing changes from within view updates"
  OR eventMessage CONTAINS "Modifying state during view update" OR eventMessage CONTAINS "Unable to simultaneously satisfy constraints"
  OR eventMessage CONTAINS "on the main thread")'

# The filter (Python, from the Xcode command line tools); the log comes on stdin.
filter=$(cat <<'PY'
import re, sys
mode, allowlist = sys.argv[1], sys.argv[2]

patterns, bad = [], []
for n, line in enumerate(open(allowlist, encoding="utf-8"), 1):
    line = line.rstrip("\n")
    if not line.strip() or line.lstrip().startswith("#"):
        continue
    pattern, sep, reason = line.rpartition(" # ")
    if not sep or not pattern.strip() or not reason.strip():
        bad.append(f"{allowlist}:{n}: needs a reason: '<pattern>   # why it's noise'")
        continue
    try:
        patterns.append((re.compile(pattern.strip()), pattern.strip()))
    except re.error as e:
        bad.append(f"{allowlist}:{n}: bad regex: {e}")
if bad:
    print("\n".join(bad)); sys.exit(2)

# Messages: in `log show --style compact`, an entry starts with a timestamp; other lines continue it.
stamp = re.compile(r"^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d+ +(\w+) +\S+ (?:\[[^\]]*\] |\([^)]*\) )?(.*)$")
messages = []
for raw in sys.stdin.read().splitlines():
    if mode == "log":
        m = stamp.match(raw)
        if m:
            messages.append(m.group(2))
        elif messages and not raw.startswith(("Timestamp", "Filtering the log data", "getpwuid")):
            messages[-1] += " " + raw.strip()
    else:  # an Xcode console: one message per line, except the constraint dumps
        if messages and messages[-1].startswith("Unable to simultaneously satisfy") and "may also be helpful" not in messages[-1]:
            messages[-1] += " " + raw.strip()
        elif raw.strip():
            messages.append(raw.strip())

allowed, offending = {}, {}
for m in messages:
    hit = next((p for rx, p in patterns if rx.search(m)), None)
    if hit:
        allowed[hit] = allowed.get(hit, 0) + 1
    else:
        key = re.sub(r"0x[0-9a-f]+|\d+", "N", m)[:300]
        count, first = offending.get(key, (0, m))
        offending[key] = (count + 1, first)

if allowed:
    print(f"Ignored as known noise ({sum(allowed.values())} lines):")
    for p, c in sorted(allowed.items(), key=lambda x: -x[1]):
        print(f"  {c:5}  {p[:110]}")
if offending:
    print(f"\nCONSOLE CHECK FAILED: {sum(c for c, _ in offending.values())} line(s) from the app aren't known noise:")
    for c, first in sorted(offending.values(), key=lambda x: -x[0]):
        print(f"  {c:5}× {first[:600]}")
    print("\nFix the cause (a console message is a bug, see CLAUDE.md). Only system noise goes into"
          f"\n{allowlist}, with a reason.")
    sys.exit(1)
print("Console check passed: nothing unexpected from the app.")
PY
)
check() { /usr/bin/python3 -c "$filter" "$1" "$allowlist"; } # $1: "log" (log show --style compact) or "file" (Xcode console)

if [ "$1" = "--file" ]; then
    [ $# -eq 2 ] || usage
    check file < "$2"
    exit $?
fi

udid="$1"; shift
if [ "${1:-}" = "--since" ]; then
    [ $# -eq 2 ] || usage
    start="$2"
    tests=0
else
    # The simulator's log uses the Mac's clock.
    start="$(date '+%Y-%m-%d %H:%M:%S')"
    tests=0
    taskpolicy -b xcodebuild test -project "$project" -scheme Ackshually -destination "id=$udid" \
        -testPlan "${CONSOLE_CHECK_PLAN:-Smoke}" "$@" || tests=$?
    [ "$tests" -eq 0 ] || echo "xcodebuild test failed ($tests); checking the console anyway." >&2
fi

echo "Console since $start (simulator $udid):"
status=0
xcrun simctl spawn "$udid" log show --start "$start" --style compact --predicate "$predicate" 2>/dev/null \
    | check log || status=$?
[ "$tests" -eq 0 ] || status=1
exit "$status"
