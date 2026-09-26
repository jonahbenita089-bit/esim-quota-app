# A Flutter app for managing daily eSIM data quotas.

This project is a prototype for a phone-number based registration app where each user receives a daily quota of 10GB.

## Features

- Register with a phone number and password
- Log in to an existing account
- Track daily data usage per user
- Automatically reset each user's usage every day
- Block additional data usage once 10GB is reached

## Project structure

- `lib/main.dart` — main app logic and screens
- `pubspec.yaml` — Flutter dependencies

## Getting started

1. Install Flutter.
2. Run:

```bash
flutter pub get
flutter run
```

## Notes

This is a local prototype for demonstration purposes. A real production eSIM app would need backend services, secure authentication, and carrier integration.
