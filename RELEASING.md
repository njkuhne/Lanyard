# Releasing dotlocal

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

## Signing and notarization

The DMG is signed with the **Developer ID Application: Nicholas Kuhne (WYMF4736GN)**
certificate (in the login keychain) and notarized with the App Store Connect API
key `XWFYLU4573` (Developer role), whose `.p8` lives in
`~/.appstoreconnect/private_keys/`. Without the secrets below, CI builds an
unsigned DMG that macOS asks people to approve on first open.

CI secrets (set them all with `scripts/set-ci-secrets.sh path/to/DeveloperID.p12`,
after exporting the identity from Keychain Access → My Certificates → Export):
`DEVELOPER_ID`, `DEVELOPER_ID_P12`, `DEVELOPER_ID_P12_PASSWORD`,
`NOTARY_KEY_P8`, `NOTARY_KEY_ID` and `NOTARY_ISSUER`.

To sign and notarize locally:

```sh
DEVELOPER_ID="Developer ID Application: Nicholas Kuhne (WYMF4736GN)" \
NOTARY_KEY=~/.appstoreconnect/private_keys/AuthKey_XWFYLU4573.p8 \
NOTARY_KEY_ID=XWFYLU4573 NOTARY_ISSUER=69a6de74-0c7e-47e3-e053-5b8c7c11a4d1 \
scripts/make-dmg.sh
spctl -a -vvv -t install build/dotlocal-*.dmg   # expect "Notarized Developer ID"
```

## Mac App Store

App Store Connect app ID 6827214815, bundle ID `net.nickopolis.dotlocal`, free.
Listing text and screenshots: `docs/appstore/`. Signing uses the Apple
Distribution and 3rd Party Mac Developer Installer certificates plus the
"dotlocal Mac App Store" provisioning profile (all in the login keychain /
Xcode). To build and upload (each upload needs a new build number):

```sh
ASC_KEY_ID=XWFYLU4573 ASC_ISSUER=69a6de74-0c7e-47e3-e053-5b8c7c11a4d1 scripts/appstore/upload.sh
```

The App Store Connect version must match the app's version (e.g. 0.3.1).
