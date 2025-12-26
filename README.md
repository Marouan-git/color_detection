# Traffic Sensor Detection App

Traffic Sensor Detection Application for stock status management.

## Milestone 2: Static Detection & Analysis

### 🔍 How algorithm works
1. **QR Detection**: The app first scans for QR codes in the image to locate the products.
2. **Cone Search**: Once the QR codes are located, the algorithm computes a cone shape above each QR code to locate the LED indicator.
3. **LED Color Detection**: It then analyzes the light indicator to detect the color (Green, Yellow, or Red).
4. **Status Detection**: Based on the detected color, the stock status of the corresponding product is determined and updated automatically.

### Features
- **Static Analysis (Cone Search)**:
  - **Methods**: Analyze stock by **taking a new picture** or **uploading an image** from your device.
  - **Automated Status Update**:
    - **In Stock**: Green color detected.
    - **Low Stock**: Yellow color detected.
    - **Out of Stock**: Red color detected.
  - **Live Sync**: If detection results are found, the product's status is **automatically updated** on the Dashboard.
  - **Visual Feedback**: View the analyzed image with detection directly in the app.

- **Enhanced Dashboard**:
  - **Status Overview**: Summary cards at the top showing total products and counts for each stock status.
  - **Sorting & Filtering**:
    - Filter products by specific stock status (In Stock, Low Stock, Out of Stock).
    - Auto-sorts table by "Last Updated" (most recent first).
  - **Detailed Tracking**: "Last Updated" timestamp column added to the table and CSV export.
  - **Live Synchronization**: Status changes from analysis are immediately reflected on the dashboard.

- **Product Management**:
  - **Core Features**: Create and delete products.
  - **QR Codes**: Generate and print QR codes for products.
  - **CSV Export**: Export products data to a CSV file.

---

### 📦 How to Install

1. **Receive the File**: You will receive a file named `app-release.apk` (or similar).
2. **Download**: Save this file to your Android phone.
3. **Install**:
   - Tap on the APK file in your phone's file manager.
   - If prompted, allow installation from "Unknown Sources".
   - Tap **Install**.
4. **Open**: Once installed, look for the app called "color_detection".

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
Run the full test suite (including new sorting and algorithm tests):
```bash
flutter test
```
