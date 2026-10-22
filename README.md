# Clipboard Fix

**Took an exam with Respondus LockDown Browser and now copy on your iPhone / paste on your Mac
doesn't work anymore?** This is a one-button macOS app that brings Universal Clipboard back.

## Why

Exam lockdown browsers like Respondus LockDown Browser cut off everything that could leak
content in or out of the exam, Universal Clipboard included. Mine never put it back: Handoff
worked, AirDrop worked, the local clipboard worked, but nothing copied on the iPhone ever showed up
on the Mac, for months, through reboots and Bluetooth toggles.

What was left behind: a `ClipboardSharingEnabled = 0` in the plain user domain of
`com.apple.coreservices.useractivityd`. The real setting lives in the `-currentHost` domain (that's
the one System Settings manages, and it said `1`), so nothing in the UI shows the stray one and
toggling Handoff doesn't touch it. Removing it and restarting the clipboard service fixed it.

To be fair to Respondus: I couldn't prove its binary writes that exact key. It's simply the only thing
on the machine that had a reason to, and it's what changed before clipboard sharing broke.

## What the button does

The window shows whether clipboard sharing looks blocked, and **Fix clipboard**:

1. removes the stray `ClipboardSharingEnabled` key from the plain user domain (if present), and
2. restarts `useractivityd` and `pboard` (launchd relaunches them immediately). That restart alone
   often unsticks it, so it's worth pressing even when the status is green.

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
