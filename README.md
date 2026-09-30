# Voice Clock

A digital clock you talk to. Built for the [Flutter Clock challenge](https://flutter.dev/clock) (early 2020).

<img src="voice_clock/digital.gif" width="350" alt="Voice Clock demo">

Say **"Hey Pico"** to wake it up, then give a command:

| Say | Effect |
|---|---|
| "light" / "dark" | Switch theme |
| "12" / "24" | Switch hour format |
| "over" | Stop listening |

The wake word runs fully on device with [Picovoice Porcupine](https://picovoice.ai/platform/porcupine/), wired to Flutter through a method channel. Once awake, the clock uses the `speech_to_text` plugin to transcribe the command, and it reads back what it understood. Hotword detection is Android only; on iOS the clock still works, without the wake word.

## Layout

- `voice_clock/` · the Flutter app
- `flutter_clock_helper/` · the model and customizer provided by the challenge
- `porcupine/` · Porcupine native libraries and keyword files for Android and iOS

## Running

```bash
cd voice_clock
flutter pub get
flutter run
```

Requires a device or emulator with a microphone.
