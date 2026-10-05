# VoiceInk fork

Fork of [Beingpax/VoiceInk](https://github.com/Beingpax/VoiceInk) (GPL v3), a macOS dictation app, built for daily use with `LOCAL_BUILD`. Based on upstream v2.22 @ 302cc74.

If `LOCAL.md` exists, read it: it holds this machine's dictation setup, signing values, and credential notes, and is gitignored.

## Rules

- Keep the diff from upstream small. Every intentional change is listed in `docs/fork-changes.md`; update it in the same commit as any fork change.
- Prefer settings and docs over fork-only Swift. Edit upstream Swift only for a concrete, verified win, mark the edit `// Fork tuning:` or gate it with `#if LOCAL_BUILD`, and add no fork-only Swift files.
- Do not delete unused upstream code (providers, licensing, Sparkle, announcements): it is harmless or disabled by `LOCAL_BUILD`, and every deletion conflicts when upstream touches the file.
- Keep machine-specific values out of tracked files. The bundle ID and team go in `Fork.local.xcconfig`; Apple ID, Developer ID identity, and notary profile go in `scripts/local.env`. Both are gitignored; copy the `.example` files to create them.

## Build and deploy

```bash
./scripts/deploy-local.sh --build --open
```

This builds Debug with `LocalBuild.xcconfig`, signs it with the installed Apple Development identity (ad-hoc if none), moves the installed app to Trash, installs to `/Applications/VoiceInk.app`, and opens it. `--open` alone deploys the existing Xcode Debug build.

- The script refuses to deploy while VoiceInk is running. Quit it without asking: `osascript -e 'tell application "VoiceInk" to quit'`, wait until `pgrep -x VoiceInk` prints nothing, then deploy.
- Keychain access to stored API keys is keyed to the code signature. If "allow keychain access" prompts appear after a deploy, check that `codesign -dr - /Applications/VoiceInk.app` shows an identity-based requirement, not a `cdhash`.
- After a deploy, confirm Accessibility is still granted to VoiceInk (System Settings, Privacy & Security, Accessibility); macOS sometimes asks again after the binary changes.
- VoiceInk Refine needs Apple's Metal Toolchain. On a new Xcode, run `xcodebuild -downloadComponent MetalToolchain` once.

For a build to install on another Mac (Developer ID-signed, notarized, universal DMG): `./scripts/build-signed.sh`, output in `build/releases/`. It needs the Developer ID Application certificate, a notarytool keychain profile, `dmgbuild` (`python3 -m pip install --user dmgbuild`), and `scripts/local.env`.

## Upstream merges

Follow "Merging upstream" in `docs/fork-changes.md`. After the build runs and the app opens, update the "Based on upstream" line above and "Last synced" in `docs/fork-changes.md`, then commit.

## Shipping

Push to the fork, not upstream. Local `main` may track `upstream/main`, so push explicitly:

```bash
git push origin main
```
