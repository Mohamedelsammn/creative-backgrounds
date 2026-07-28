# Creative Backgrounds

A premium Android wallpaper app built with Flutter. Users can explore and search a wallpaper catalog, preview and apply wallpapers, and customize them with live clock overlays, depth effects, and a transparent live wallpaper mode that renders the rear camera feed in real time.

**Key features:**
- Explore, search, and view-all browsing of the wallpaper catalog
- Wallpaper details, favorites, and apply-to-device flow
- Customization: live clock overlay, depth-based parallax effects
- Transparent live wallpaper (real-time rear-camera background)
- Offline-aware (connectivity handling) with local caching

## Repository structure

- **Flutter app:** [`/app`](./app) — the Flutter client application
- **Backend:** [`/backend`](./backend) — placeholder for the backend service (to be implemented)

## Build instructions

The Flutter app lives in `/app`. All commands below are run from that directory:

```bash
cd app
flutter pub get
flutter analyze
flutter build apk
```

Requires a working Flutter SDK installation. See [app/README.md](./app/README.md) for Flutter-specific setup notes.
