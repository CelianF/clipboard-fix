# Clipboard Fix

A tiny macOS app with one button that restores Universal Clipboard (copy on iPhone, paste on Mac).

It shows whether clipboard sharing looks blocked, and **Fix clipboard**:

1. removes a stray `ClipboardSharingEnabled` key from the plain user domain of
   `com.apple.coreservices.useractivityd` (the real setting lives in the `-currentHost` domain,
   which System Settings manages; exam lockdown tools can leave a `0` behind), and
2. restarts `useractivityd` and `pboard` (launchd relaunches them immediately).

No admin rights needed. The equivalent by hand:

```bash
defaults delete com.apple.coreservices.useractivityd ClipboardSharingEnabled
killall useractivityd pboard
```

If the app says **Handoff is off**, turn on System Settings → General → AirDrop & Handoff → Allow Handoff
(and Handoff on the iPhone: Settings → General → AirPlay & Continuity).

## Build

```bash
./build.sh
```

Signs with a Developer ID Application certificate when the keychain has one, otherwise Apple Development
(fine on your own Mac). Releases: push a `v*` tag; the workflow signs and notarizes using the
`CSC_LINK`, `CSC_KEY_PASSWORD`, `APPLE_API_KEY`, `APPLE_API_KEY_ID`, `APPLE_API_ISSUER` secrets.
