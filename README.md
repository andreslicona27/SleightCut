# SleightCut

A native SwiftUI video editor for macOS 13+, designed for magic performances. No Python, FFmpeg, subscriptions, or API keys are needed at runtime.

## First version

- Import a Mac-compatible video and preview it.
- Apply restrained contrast, saturation and luminance sharpening at the original aspect ratio and resolution. This is conventional enhancement, not AI detail restoration or upscaling.
- Apply speech-focused EQ (100 Hz high-pass, 8 kHz low-pass, gentle presence boost).
- Generate timed captions using Apple's on-device Speech recognizer in English, Spanish or French. Review and edit caption text and start/end times in seconds; delete unwanted dialogue before exporting.
- Burn warm-white captions into a burgundy panel with a crimson underline, then export an MP4. The main image keeps its natural colors.
- Preview the finished export and reveal it in Finder. The source video is preserved.

**Speaker separation is not implemented.** Speech clarity reduces rumble and high-frequency noise, including desirable sound in those ranges; it cannot selectively suppress bystanders. Captions include all recognized speech and do not identify the magician or participant. Reliable speaker selection needs a separate model and a speaker-selection workflow.

Automatic captions require Speech Recognition permission and a compatible on-device language model installed on the Mac. Availability varies by hardware/language. Recognition errors are shown in the app; captions remain optional. Start with short clips: Apple's recognizer may impose duration/resource limits. The app requests on-device recognition and does not fall back to sending audio to Apple's servers.

## Build and run

Install matching Apple command line tools / macOS SDK, then run:

```sh
./scripts/build-app.sh
```

Open `dist/SleightCut.app`. Shareable archive: `dist/SleightCut-macOS.zip`. The script builds both Intel x86_64 and Apple Silicon arm64 into one executable. Recipients need macOS 13 or later, not development tools. Actual compatibility needs testing on both hardware families and supported macOS releases.

The package also supports `swift build` for development, but launch the packaged app to use its speech permission description.

The default package is locally ad-hoc signed. Distribution without Gatekeeper warnings requires an Apple Developer ID certificate and Apple notarization. Set `SIGNING_IDENTITY` to your Developer ID Application identity before building to use hardened runtime signing. Notarize the ZIP with your own Apple credentials using `xcrun notarytool submit ... --wait`, staple the app with `xcrun stapler staple dist/SleightCut.app`, and recreate the ZIP with `ditto -c -k --keepParent dist/SleightCut.app dist/SleightCut-macOS.zip`. Signing credentials are not included.

## Manual acceptance checks

1. Import landscape and portrait clips; confirm preview, orientation, output duration and audio synchronization.
2. Generate captions on a short dialogue clip, correct a sentence, adjust timings and delete a bystander caption. Confirm these changes in the exported video.
3. Compare enhancement and speech clarity on/off; verify no clipping or obvious artifacts.
4. Export silent media with captions off; try unsupported media and denied/unavailable speech recognition and verify readable errors.
5. Cancel file dialogs, replace an existing export, and confirm the original stays untouched.
6. Test the packaged app on Intel and Apple Silicon, macOS 13 and a current release. Verify permissions and notarized distribution separately.

Implementation uses Apple's [file-based speech recognition](https://developer.apple.com/documentation/speech/sfspeechurlrecognitionrequest) and [offline audio rendering](https://developer.apple.com/documentation/avfaudio/avaudioengine/manualrenderingmode), plus AVFoundation and Core Image.

## Verification on the development Mac

The universal app compiled for arm64 and x86_64 and passed `codesign --verify --deep --strict`. The installed SwiftPM manifest linker is mismatched, so the packaging script invokes `xcrun swiftc` directly instead of relying on SwiftPM. The x86_64 link emitted a toolchain compatibility-library warning; Intel runtime testing remains necessary.

`checks/Smoke.swift` generates synthetic audio and video and verifies audio frame count, caption rasterization, filtered MP4 export, output decoding, dimensions and duration. Compile it alongside `Sources/SleightCut/Processing.swift` with `xcrun swiftc -parse-as-library -swift-version 5`, then run the resulting executable. Core Audio and video encoding require normal system access. Real speech recognition, visual review, portrait footage, signing/notarization and cross-device compatibility still require the acceptance checks above.


## Video import crash fix (0.1.1)

Two user crash reports from November 9, 2026 show a Swift runtime abort in `_AVKit_SwiftUI` during superclass metadata initialization while mounting the preview. The preview now embeds AppKit's `AVPlayerView` directly through `NSViewRepresentable`, avoiding SwiftUI's `VideoPlayer` bridge. Imports also validate playability, video tracks and duration before replacing the current video; failures show an error and preserve the existing edit.

The native preview mount/layout check is `checks/Preview.swift`, compiled with `Sources/SleightCut/NativeVideoPreview.swift`. The media smoke check additionally covers valid video import and invalid-file rejection. Both checks require normal system access to media and window services.
