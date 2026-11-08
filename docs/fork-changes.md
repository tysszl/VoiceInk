# Fork changes

This fork tracks [Beingpax/VoiceInk](https://github.com/Beingpax/VoiceInk) and keeps a small diff. This file lists every intentional change and how to carry it through an upstream merge. `git diff <last merged upstream ref> main` must agree with it; update it in the same commit as any fork change.

Last synced: upstream v2.25 (`228f4217`, "Release version 2.25").

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
| `VoiceInk/Infrastructure/SystemIntegration/Paste/CursorPaster.swift` | `prePasteDelay` 0.20 → 0.05 | paste lands about 150 ms sooner |
| `VoiceInk/Infrastructure/SystemIntegration/Paste/CursorPaster.swift` | when Screen Sharing is frontmost, use upstream's Remote Desktop Typing instead of the selected paste method | a clipboard paste in Screen Sharing pastes the remote Mac's clipboard; upstream only offers remote typing as a global setting |
| `VoiceInk/Features/ModelLibrary/Models/TranscriptionModelRegistry.swift`, `VoiceInk/Features/ModelLibrary/State/FluidAudioModelManager.swift` | adds Fluid Speech Mini (`fluid-speech-mini`), downloaded from `FluidVoice-Labs/fluid-speech-mini-coreml` at a pinned revision, with `JointDecision.mlmodelc` saved as `JointDecisionv3.mlmodelc`; it takes FluidAudio's `.redux` version slot, which VoiceInk does not offer, so it gets its own folder (`FluidAudio/Models/parakeet-redux`) and model cache | a Parakeet V3 drop-in that matches Ultra's accuracy at a fifth of the size and holds up better with other voices in the room; FluidAudio has no repo entry for it. Drop this when FluidAudio or upstream adds it, or if Ultra stays the better choice |
| `VoiceInk/Features/Onboarding/State/OnboardingCoordinator.swift`, `.../Components/TranscriptionModelDownloadCard.swift`, `.../Components/OnboardingTranscriptionSetupCard.swift` | onboarding downloads Fluid Speech Mini instead of Parakeet V3, and its text names Mini and says English | Mini is the recommended model and runs well on Macs with less memory |
| `VoiceInk/Core/Enhancement/AIPrompts.swift` | replaces the cleanup system instructions with a lean version, about half the length; each line was kept or cut by measurement. It includes the list markers (`"1."`, `"- "`) and the “exclamation mark” cue, where a cue replaces the punctuation next to it. It drops `CONTEXT_RULES` (except the Dictionary line) and `OUTPUT_REQUIREMENTS` | about 405 fewer tokens per request. On 111 held-out dictations (3 runs, qwen-3.8-27b): Cleanup 96.5% before and after, Email 100%, Lowercase 91.9% → 89.2%, within its 6-point run spread. `docs/evals/2026-11-lean-template.md` |
| `VoiceInk/Features/Recording/Views/NotchRecorderView.swift` | notch pill springs: expand `response` 0.42 → 0.25, collapse 0.45 → 0.28; content fade-in delay 0.09 → 0.03 s | the notch opens and closes about 40% faster |
| `VoiceInk/App/Updates/UpdaterViewModel.swift` | under `#if LOCAL_BUILD`, automatic update checks stay off; manual checks still work | fork builds update by rebuilding, and upstream's feed offers the paid app |

Fork edits are marked `// Fork tuning:` or gated by `#if LOCAL_BUILD`. Add no fork-only Swift files.

## Fork-only files

- `AGENTS.md`, `docs/fork-changes.md`; `README.md` adds a personal-fork note
- `Fork.xcconfig`, `Fork.local.xcconfig.example`
- `scripts/deploy-local.sh`: Debug build, install to `/Applications`, open
- `scripts/build-signed.sh`, `scripts/local.env.example`, `scripts/dmg-assets/`: Developer ID-signed, notarized, universal DMG
- `evals/cleanup-prompt/`, `docs/evals/`: the cleanup prompt eval and its reports
- `docs/reviews/`: reviews of other dictation apps for ideas worth adopting
- `.gitignore`: ignores `Fork.local.xcconfig`, `scripts/local.env`, `LOCAL.md`, `__pycache__/`

## Merging upstream

```bash
git fetch upstream --tags
git log --oneline main..upstream/main
git merge <release commit>     # the "Release version X" commit on upstream/main
```

Merge the "Release version X" commit, not the tag: upstream tags the commit before it (v2.25) or a commit off `main` (v2.22, whose diagnostics commits `main` never got). Merging from an off-`main` base conflicts in files the fork never touched; make those match upstream and delete files only the old base added.

Expect conflicts in `project.pbxproj` in the app target's Debug and Release build settings. When they tangle, start from upstream's file and re-apply the fork's Debug and Release blocks and the `Fork.xcconfig` reference.

- Keep ours: the base configuration reference to `Fork.xcconfig`; no `PRODUCT_BUNDLE_IDENTIFIER` or `DEVELOPMENT_TEAM` lines in the app target; `LOCAL_BUILD`; `VoiceInk.local.entitlements`; `ENABLE_APP_SANDBOX = NO`; in Debug, `PRODUCT_NAME = "$(TARGET_NAME)"` and `INFOPLIST_KEY_CFBundleDisplayName = VoiceInk` (the display-name line merges without a conflict, so check it).
- Take theirs: `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`, everything else.
- When upstream moves source folders, Git carries the Swift edits across; update the paths in this file.
- `AIPrompts.swift`: keep the fork's template. If upstream changed the rules, port a change only after it passes `evals/cleanup-prompt`, and recheck Lowercase, because single-line edits to this template moved Lowercase scores a lot.

Verify:

```bash
rg -n "baseConfigurationReference|CODE_SIGN_ENTITLEMENTS|DEVELOPMENT_TEAM|ENABLE_APP_SANDBOX|PRODUCT_BUNDLE_IDENTIFIER|PRODUCT_NAME|CFBundleDisplayName|SWIFT_ACTIVE_COMPILATION_CONDITIONS" VoiceInk.xcodeproj/project.pbxproj
git diff <merged upstream ref> --stat -- '*.swift'   # expect: AIPrompts, UpdaterViewModel, NotchRecorderView, CursorPaster, FluidAudioModelManager, TranscriptionModelRegistry, OnboardingCoordinator, TranscriptionModelDownloadCard, OnboardingTranscriptionSetupCard
git diff --check
./scripts/deploy-local.sh --build --open
```

Then update "Last synced" above and commit the merge with this file.
