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
# Your work domains, plus whatever SSO or VPN portal they bounce through.
hosts = ["localhost", "example.com", "login.microsoftonline.com"]
browser = "Google Chrome"
profile = "Work"

[[rule]]
# No `hosts` = catch-all. Keep this last.
browser = "Google Chrome"
profile = "Personal"
```

- **hosts** — matched exactly or as a suffix. `example.com` matches
  `example.com` and `foo.example.com`, but not `notexample.com`. Local files
  match `localhost` — the default browser is also the default HTML handler, and
  VPN clients like GlobalProtect log you in by opening a temp `.html`.
- **browser** — application name in `/Applications`.
- **profile** — Chrome profile as shown in Chrome's own UI (`Work`), or the
  literal directory (`Profile 3`). Two profiles can share a display name; use
  the directory to disambiguate.

Rules are tried in order, first match wins. Edits apply on the next click — no
restart. If nothing matches — no catch-all, or a missing or malformed config —
the URL goes to Chrome's currently active profile (Safari if Chrome isn't
installed).

Anything that would drop a click — an unparseable config, a `browser` that
isn't installed — raises an alert as well as being logged. An alert rather than
a Notification Center banner, because Focus modes silence banners.

## Watching where the time goes

Every click is logged to the unified log with per-step timings:

```sh
$ log stream --predicate 'subsystem == "com.mmikulicic.persnickety"'
received https://example.com/
matched Google Chrome [Profile 3] in 0.9ms
spawned pid 40123 at 1.4ms
chrome handed off (exit 0) at 214.7ms
```

Past clicks: `log show --last 10m --predicate 'subsystem ==
"com.mmikulicic.persnickety"'`. In Console.app, search `persnickety`.

Reading it:

- **`launched pid …` right before a `received`** — the click cold-started us;
  that gap is macOS launching the app, not routing.
- **`matched` slow** — config reload (a `config reloaded` line says so) or
  Chrome's `Local State` parse.
- **`chrome handed off` late** — the time is Chrome's, not ours: each URL
  spawns a fresh Chrome binary that relays to the running instance and exits.
- **no `chrome handed off` at all** — Chrome wasn't running, so that spawned
  process *became* Chrome. All the delay is Chrome's cold start.

Chrome only for profiles. Other browsers launch, but ignore `profile`.

## Checking a rule

```sh
$ persnickety --route https://foo.example.com
Google Chrome	Profile 3
```

Prints the decision and launches nothing.

## Notes

Chrome is launched by running its binary directly rather than through
`NSWorkspace`, because `NSWorkspace` drops `configuration.arguments` when the
app is already running — which would silently ignore `--profile-directory` and
send every URL to whichever profile Chrome happened to open last.

To go back to Finicky, pick it again in System Settings.

## License

Apache License 2.0 — see [LICENSE](LICENSE).

Depends on [TOMLDecoder](https://github.com/dduan/TOMLDecoder) (MIT).
