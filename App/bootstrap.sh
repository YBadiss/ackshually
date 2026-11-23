#!/bin/sh
# Generates App/Ackshually.xcodeproj from App/project.yml (XcodeGen). The project is git-ignored:
# run this after cloning, after pulling, and after editing project.yml. Then: open App/Ackshually.xcodeproj
set -eu
cd "$(dirname "$0")"

required="2.48.0"
if ! command -v xcodegen >/dev/null 2>&1; then
    echo "error: XcodeGen is not installed. Install it with: brew install xcodegen  (needs $required or newer)" >&2
    exit 1
fi
version="$(xcodegen --version | sed -E 's/[^0-9.]//g')"
if [ "$(printf '%s\n%s\n' "$required" "$version" | sort -V | head -n1)" != "$required" ]; then
    echo "error: XcodeGen $version is too old; $required or newer is needed: brew upgrade xcodegen" >&2
    exit 1
fi
xcodegen generate --quiet
echo "Generated Ackshually.xcodeproj (XcodeGen $version). Open it with: open App/Ackshually.xcodeproj"
