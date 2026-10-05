# Fork changes

This fork tracks [Beingpax/VoiceInk](https://github.com/Beingpax/VoiceInk) and keeps a small diff. This file lists every intentional change and how to carry it through an upstream merge. `git diff <last merged upstream ref> main` must agree with it; update it in the same commit as any fork change.

Last synced: upstream v2.22 (tag @ 302cc74).

## Build settings

`VoiceInk.xcodeproj/project.pbxproj`, app target, Debug and Release:

| Setting | Fork value | Why |
|---|---|---|
| base configuration | `Fork.xcconfig` | holds the bundle ID and team, read from the gitignored `Fork.local.xcconfig`; the target sets neither `PRODUCT_BUNDLE_IDENTIFIER` nor `DEVELOPMENT_TEAM` |
| `CODE_SIGN_ENTITLEMENTS` | `VoiceInk/VoiceInk.local.entitlements` | no iCloud, Keychain Sharing, or Push |
| `ENABLE_APP_SANDBOX` | `NO` | the Accessibility API needs it |
| `SWIFT_ACTIVE_COMPILATION_CONDITIONS` | adds `LOCAL_BUILD` | turns on upstream's local-build code paths |
| Debug `PRODUCT_NAME`, `INFOPLIST_KEY_CFBundleDisplayName` | `$(TARGET_NAME)`, `VoiceInk` | upstream's Debug build is a separate "VoiceInk Dev" app; the fork's Debug build is the installed app and `deploy-local.sh` expects `Debug/VoiceInk.app` |

`LocalBuild.xcconfig`, `VoiceInk.local.entitlements`, and the `#if LOCAL_BUILD` code are upstream's. With `LOCAL_BUILD`, API keys go to the login keychain under service `com.prakashjoshipax.VoiceInk.Local` (`KeychainService.swift`), CloudKit dictionary sync is off (`VoiceInk.swift`), and licensing is not enforced (`LicenseViewModel.swift`). Keychain access is keyed to the code signature, so keep builds signed with the same identity.

## Swift changes

| File | Change | Why |
|---|---|---|
| `VoiceInk/Features/Shortcuts/Coordination/RecordingShortcutManager.swift` | `shortcutPressCooldown` 0.5 → 0.25 | lets fast stop-and-restart and quick re-taps through while still blocking accidental double presses |
| `VoiceInk/Infrastructure/SystemIntegration/Paste/CursorPaster.swift` | `prePasteDelay` 0.10 → 0.05 | paste lands about 50 ms sooner |
| `VoiceInk/Infrastructure/SystemIntegration/Paste/CursorPaster.swift` | remote-desktop paste: when Screen Sharing is frontmost, run the `remoteClipboardPushCommand` preference (if set) to put the text on the remote Mac's clipboard, otherwise wait 0.8 s; then paste through AppleScript | only System Events keystrokes keep ⌘ when forwarded, and Apple's shared clipboard sync is slow and can replay stale contents |
| `VoiceInk/App/Updates/UpdaterViewModel.swift` | under `#if LOCAL_BUILD`, automatic update checks stay off; manual checks still work | fork builds update by rebuilding, and upstream's feed offers the paid app |

Fork edits are marked `// Fork tuning:` or gated by `#if LOCAL_BUILD`. Add no fork-only Swift files.

Remote paste setup: `defaults write <bundle ID> remoteClipboardPushCommand "ssh -o BatchMode=yes -o ConnectTimeout=2 user@host pbcopy"`, and turn off Edit → Use Shared Clipboard in the Screen Sharing viewer. If the preference seems ignored, remove any stale `~/Library/Containers/<bundle ID>`: `defaults` writes there while the unsandboxed app reads `~/Library/Preferences/<bundle ID>.plist`.

## Fork-only files

- `AGENTS.md`, `docs/fork-changes.md`
- `Fork.xcconfig`, `Fork.local.xcconfig.example`
- `scripts/deploy-local.sh`: Debug build, install to `/Applications`, open
- `scripts/build-signed.sh`, `scripts/local.env.example`, `scripts/dmg-assets/`: Developer ID-signed, notarized, universal DMG
- `.gitignore`: ignores `Fork.local.xcconfig`, `scripts/local.env`, `LOCAL.md`

## Merging upstream

```bash
git fetch upstream --tags
git log --oneline main..upstream/main
git merge upstream/main        # or the release tag, e.g. v2.23
```

Expect conflicts in `project.pbxproj` in the app target's Debug and Release build settings.

- Keep ours: the base configuration reference to `Fork.xcconfig`; no `PRODUCT_BUNDLE_IDENTIFIER` or `DEVELOPMENT_TEAM` lines in the app target; `LOCAL_BUILD`; `VoiceInk.local.entitlements`; `ENABLE_APP_SANDBOX = NO`; in Debug, `PRODUCT_NAME = "$(TARGET_NAME)"` and `INFOPLIST_KEY_CFBundleDisplayName = VoiceInk` (the display-name line merges without a conflict, so check it).
- Take theirs: `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`, everything else.
- When upstream moves source folders, Git carries the Swift edits across; update the paths in this file.

Verify:

```bash
rg -n "baseConfigurationReference|CODE_SIGN_ENTITLEMENTS|DEVELOPMENT_TEAM|ENABLE_APP_SANDBOX|PRODUCT_BUNDLE_IDENTIFIER|PRODUCT_NAME|CFBundleDisplayName|SWIFT_ACTIVE_COMPILATION_CONDITIONS" VoiceInk.xcodeproj/project.pbxproj
git diff <merged upstream ref> --stat -- '*.swift'   # expect: UpdaterViewModel, RecordingShortcutManager, CursorPaster
git diff --check
./scripts/deploy-local.sh --build --open
```

Then update "Last synced" above and commit the merge with this file.
