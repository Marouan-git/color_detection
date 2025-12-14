# Traffic Sensor Detection App

Traffic Sensor Detection Application for managing products and capturing data (photos/videos) for AI model training.

## Milestone 1: App Foundation & Data Capture

### Features
- **Product Management**: 
  - Input Product IDs and Supplier names.
  - Set Stock Status (In Stock, Low Stock, Out of Stock).
  - Persistence of product data.
- **Dashboard**:
  - View all registered products in a table.
  - Visual indicators for stock status.
  - Bulk print all QR codes to a single PDF.
- **QR Code Tools**: Save QR codes as PDF (share image disabled for now).
- **Data Capture**:
  - Custom camera interface to capture photos and videos.
  - Toggle between Photo and Video modes.
  - Separate folders for images and videos.
  - In-session gallery preview.
- **Gallery & Data Export**:
  - View and delete captured images and videos.
  - Export all data as a ZIP file (Download/Share).

---

### 📦 How to Install (For Client)

1. **Receive the File**: You will receive a file named `app-release.apk`.
2. **Download**: Save this file to your Android phone (e.g., via WhatsApp, Email, or Google Drive).
3. **Install**:
   - Tap on the `app-release.apk` file in your phone's file manager or downloads folder.
   - If prompted, allow installation from "Unknown Sources" (this is normal for apps not from the Play Store).
   - Tap **Install**.
4. **Open**: Once installed, look for "Traffic Sensor App" (or "Color Detection") on your home screen.

*Note: Allow camera and storage permissions when the app first opens to ensure all features work.*

---

### How to Run (Development)
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
