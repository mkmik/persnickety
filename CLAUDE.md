# persnickety

A macOS default-browser handler that routes each URL to a specific browser — and a specific profile within that browser — based on user-defined rules.

Conceptually: "finicky, but our implementation." The name pun is earned — **"snick"** is a real word meaning a small click, so *persnickety* already contains the click that gets routed.

## Scope

Minimum feature set (the subset of finicky actually exercised by `~/.finicky.js`):

- Register as the macOS default handler for `http` / `https`
- Match incoming URLs by hostname (regex or similar)
- Launch the chosen browser
- Launch that browser in a specific **profile** — Chrome profiles are the first-class case (the user keeps a Work and a Personal window open simultaneously)

Explicit non-goals unless revisited:

- URL rewriting
- Menu-bar UI / config-editor app
- Arbitrary scripting in config

## Prior art and motivations

- `~/.finicky.js` — the user's existing finicky config; canonical source for the target feature subset.
- github.com/johnste/finicky — reference implementation. Pain points we explicitly want to avoid: brittle config parsing across upgrades, lack of first-class browser-profile support, v3→v4 migration friction.

## Status

v1 implemented, not yet committed. Swift + SwiftPM, one source file
(`Sources/persnickety/main.swift`), TOML config at
`~/.config/persnickety/config.toml`, packaged as a faceless menubar `.app` by
`scripts/build.sh`. See `README.md` for config format and install steps.

Matching is hostname suffix, not regex — every rule in the old `~/.finicky.js`
is a suffix, so the regex engine bought nothing. Add it when a rule needs it.

Chrome is launched by exec'ing its binary directly; `NSWorkspace` drops
`configuration.arguments` for an already-running app, which would silently
discard `--profile-directory`.
