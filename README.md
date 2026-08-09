# persnickety

A macOS default-browser handler. Routes each URL to a browser — and to a
specific Chrome profile — by hostname.

## Build

```sh
./scripts/build.sh     # -> dist/persnickety.app, ad-hoc signed
./scripts/test.sh      # routing assertions, launches nothing
```

## Install

```sh
rm -rf /Applications/persnickety.app   # cp -R into an existing bundle nests a copy inside it
cp -R dist/persnickety.app /Applications/
open /Applications/persnickety.app
```

Then System Settings → Desktop & Dock → Default web browser → **persnickety**.
If it isn't in the list, LaunchServices hasn't seen the bundle yet:

```sh
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f /Applications/persnickety.app
```

It runs as a menubar item (no Dock icon): **Open Config**, **Quit**. Opening
the config writes a starter file if you don't have one yet.

## Config

`~/.config/persnickety/config.toml`

```toml
[[rule]]
# Work SSO/auth domains
hosts = ["localhost", "nvidia.com", "login.microsoftonline.com", "paloaltonetworks.com"]
browser = "Google Chrome"
profile = "Work"

[[rule]]
# No `hosts` = catch-all. Keep this last.
browser = "Google Chrome"
profile = "Personal"
```

- **hosts** — matched exactly or as a suffix. `nvidia.com` matches `nvidia.com`
  and `foo.nvidia.com`, but not `evilnvidia.com`.
- **browser** — application name in `/Applications`.
- **profile** — Chrome profile as shown in Chrome's own UI (`Work`), or the
  literal directory (`Profile 18`). Two profiles can share a display name; use
  the directory to disambiguate.

Rules are tried in order, first match wins. Edits apply on the next click — no
restart. If the config is missing or malformed, URLs go to Safari and the parse
error goes to stderr.

Chrome only for profiles. Other browsers launch, but ignore `profile`.

## Checking a rule

```sh
$ persnickety --route https://foo.nvidia.com
Google Chrome	Profile 18
```

Prints the decision and launches nothing.

## Notes

Chrome is launched by running its binary directly rather than through
`NSWorkspace`, because `NSWorkspace` drops `configuration.arguments` when the
app is already running — which would silently ignore `--profile-directory` and
send every URL to whichever profile Chrome happened to open last.

To go back to Finicky, pick it again in System Settings.
