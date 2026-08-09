#!/usr/bin/env bash
# Routing decisions via --route, against a fixture config. No browsers launched.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release >/dev/null
BIN=.build/release/persnickety

CFG=$(mktemp "${TMPDIR:-/tmp}/persnickety.XXXXXX")
trap 'rm -f "$CFG"' EXIT
cat > "$CFG" <<'TOML'
[[rule]]
hosts = ["localhost", "nvidia.com", "login.microsoftonline.com"]
browser = "Google Chrome"
profile = "Profile 18"

[[rule]]
browser = "Firefox"
TOML

fail=0
check() { # check <url> <expected> <what>
	got=$(PERSNICKETY_CONFIG="$1" "$BIN" --route "$2")
	if [ "$got" = "$(printf '%b' "$3")" ]; then
		echo "ok   $4"
	else
		echo "FAIL $4: got '$got' want '$3'"
		fail=1
	fi
}

check "$CFG" https://foo.bar.nvidia.com/x 'Google Chrome\tProfile 18' "suffix match"
check "$CFG" https://nvidia.com          'Google Chrome\tProfile 18' "exact match"
check "$CFG" http://localhost:3000/       'Google Chrome\tProfile 18' "port ignored"
check "$CFG" https://news.ycombinator.com 'Firefox\t-'                "catch-all rule"
# tighter than finicky's unanchored /login\.microsoftonline\.com$/, which matches this
check "$CFG" https://evillogin.microsoftonline.com 'Firefox\t-'       "suffix needs a dot"
check /nonexistent/config.toml https://nvidia.com  'Safari\t-'        "broken config falls back"

exit $fail
