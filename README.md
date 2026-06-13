# KYC Status Livn

A Flutter-based KYC verification prototype that captures a live selfie and performs basic liveness checks using the device camera.

## Overview

This project demonstrates a step-by-step identity verification flow for fintech onboarding. The current implementation uses:

- Flutter for the mobile UI
- `camera` for live camera preview and capture
- `google_mlkit_face_detection` for face, smile, blink, and head-pose detection
- `permission_handler` for runtime camera permissions
- native haptics for step-completion feedback

The verification flow currently includes:

1. Live face capture
2. Smile detection
3. Blink detection
4. Turn head left
5. Turn head right
6. Look straight

## Features

- Polished onboarding screen with verification instructions
- Camera permission handling
- Front-camera liveness capture
- Stricter head-turn detection to reduce false positives
- Haptic feedback after each successful step
- Final selfie capture after all steps complete

## Project Structure

- `lib/main.dart` - app entry point and theme setup
- `lib/home_page.dart` - onboarding screen and permission flow
- `lib/kyc_liveness_capture_page.dart` - camera capture and liveness logic
- `android/` - Android native configuration
- `ios/` - iOS native configuration

## Requirements

- Flutter SDK 3.10 or newer
- Android device or emulator with a camera
- iPhone or iPad with camera support

## Setup

1. Get dependencies:

```bash
flutter pub get
```

2. Run the app:

```bash
flutter run
```

## Platform Permissions

### Android

Camera permission is declared in:

- `android/app/src/main/AndroidManifest.xml`

### iOS

Camera usage description is declared in:

- `ios/Runner/Info.plist`

## How the Flow Works

1. The user opens the app.
2. The app checks for camera permission.
3. The user starts verification.
4. The front camera opens with a face frame overlay.
5. ML Kit evaluates the face for each required step.
6. A vibration is triggered after each successful step.
7. After the final step, the app captures a selfie and returns the result to the home screen.


