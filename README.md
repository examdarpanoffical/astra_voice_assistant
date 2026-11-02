# Astra Voice Assistant

A Flutter voice assistant starter app with speech recognition, spoken responses, and command shortcuts.

## Features

- Speech-to-text using `speech_to_text`
- Text-to-speech using `flutter_tts`
- Open YouTube and search for a spoken query
- Search Google
- Open WhatsApp or a WhatsApp chat link
- Open the phone dialer with a number for the user to review
- Hindi (India) and English (India) speech locale selection
- Type commands when voice recognition is unavailable

## Create / run

Install the Flutter SDK, then from this repository run:

```bash
flutter create .
flutter pub get
flutter run
```

If Flutter asks to overwrite existing files, keep the existing `pubspec.yaml` and `lib/main.dart`. The `flutter create .` command generates the remaining platform scaffolding for the installed Flutter SDK.

## Android permissions

The app needs microphone permission for voice recognition and internet access for speech services and opening web links. Ensure the Android manifest includes:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

The app requests microphone permission at runtime.

## Example commands

- “YouTube search cricket highlights”
- “Google search Rajasthan CET”
- “Open WhatsApp”
- “WhatsApp 919876543210”
- “Call 919876543210”
- “Help”

## Safety behavior

A phone command opens the system dialer; it does not place a call automatically. A WhatsApp command opens the chat; it does not send a message automatically. Review the destination and take the final action yourself.

## Notes

Speech recognition availability and supported languages depend on the device's installed speech services. Test on a physical Android device as well as an emulator.
