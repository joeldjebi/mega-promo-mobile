# mega_promo

A new Flutter project.

## Observability

Sentry is optional and enabled only when a DSN is provided at build time:

```sh
flutter run \
  --dart-define=SENTRY_DSN=https://example.ingest.sentry.io/project \
  --dart-define=SENTRY_ENVIRONMENT=production \
  --dart-define=SENTRY_TRACES_SAMPLE_RATE=0.1
```

Crashlytics remains active when Firebase is available. Sentry receives the same
fatal and non-fatal errors through `AppTelemetryService`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
