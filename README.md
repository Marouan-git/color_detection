# Traffic Sensor Detection App

Traffic Sensor Detection Application for managing products and capturing data (photos/videos) for AI model training.

## Milestone 1: App Foundation & Data Capture

### Features
- **Product Management**: Input Product IDs and generate QR codes.
- **QR Code Tools**: Save QR codes as PDF or share as images.
- **Data Capture**:
  - Custom camera interface to capture photos and videos.
  - Raw capture mode to minimize post-processing.
  - Saves captures locally.
- **Data Export**:
  - View list of captured files.
  - Export all data as a ZIP file.

### How to Run
1. **Prerequisites**: Flutter SDK installed.
2. **Setup**:
   ```bash
   flutter pub get
   ```
3. **Run**:
   ```bash
   flutter run
   ```
   (Connect a device or emulator. Camera features require a real device or a camera-enabled emulator).

### Testing
Run tests with:
```bash
flutter test
```
