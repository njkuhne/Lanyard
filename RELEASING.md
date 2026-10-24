# Releasing Lanyard

Every tag is a release. To cut one from a clean, pushed `main`:

```sh
scripts/release.sh minor        # or patch, major, 1.4.0, 1.5.0-beta.1
```

That bumps the version, commits, tags `vX.Y.Z` and pushes. GitHub then tests,
builds the DMG, writes release notes from the commits since the last tag, and
publishes the release marked **Latest**. A tag with a suffix (`v1.5.0-beta.1`)
becomes a pre-release instead. You can also push a tag by hand, or use
**Actions → Release → Run workflow**. Every push to `main` also builds a DMG you
can grab from the run's Artifacts.

Without signing secrets the DMG is unsigned, and macOS asks people to approve it
in System Settings → Privacy & Security on first open. To ship a DMG that opens
cleanly, it needs a **Developer ID Application** certificate and notarization.
Add these repository secrets (details in `.github/workflows/release.yml`):
`DEVELOPER_ID`, `DEVELOPER_ID_P12`, `DEVELOPER_ID_P12_PASSWORD`,
`NOTARY_KEY_P8`, `NOTARY_KEY_ID` and `NOTARY_ISSUER`.

To sign and notarize locally instead:

```sh
xcrun notarytool store-credentials lanyard-notary   # once
DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE=lanyard-notary scripts/make-dmg.sh
```
