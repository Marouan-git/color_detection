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

## Milestone 3: Real-time Detection

### Features

- **Real-time Detection**:
  - **Live Camera Feed**: Point your camera at products with QR codes and LEDs for instant status detection.
  - **Continuous Scanning**: The app automatically detects multiple QR codes and their corresponding LED colors in real-time.
  - **Automatic Updates**: Once a product is detected, its status is immediately updated in the Dashboard.

- **Video Analysis**:
  - **Upload Video**: Analyze pre-recorded videos of your products.
  - **Batch Processing**: Process multiple frames to detect all products in the video.
  - **Automated Status Update**: All detected products are updated automatically.

- **Orders & Order History Management**:
  - **Create Orders**: From the Dashboard, tap any product (order column) to create a new order.
  - **Editable Supplier**: When creating an order, you can modify the supplier (pre-filled with the product's default supplier) and quantity.
  - **Duplicate Detection**: If a pending order already exists for the same product and supplier, you'll be prompted to:
    - **Replace**: Delete existing pending orders and create a new one.
    - **Add Alongside**: Keep existing orders and add a new one.
    - **Cancel**: Don't create the new order.
  - **Order History Screen**: View all orders with filtering by product.
  - **Order Interval Tracking**: See previous order date and time interval between orders (e.g., "5 days, 3 hours ago").
  - **Mark as Delivered**: Update order status to "Delivered" with delivery timestamp.
  - **Delete Pending Orders**: Remove orders that haven't been delivered yet.
  - **CSV Export**: Export order history to CSV with all details including intervals.

- **Cone Calibration**:
  - **Purpose**: Adjust the detection cone's position and size to match your LED placement.
  - **How to Access**: From the Analysis screen, tap the **Calibration** button.
  - **Upload Image**: Take or upload a photo showing your QR code and LED clearly.
  - **Adjust Height**: Use the slider to extend or shrink the detection cone (0.5x to 1.5x).
  - **Adjust Direction**: Use the rotation slider to point the cone toward your LED (0° to 359°). Quick-tap labels for Up, Right, Down, Left.
  - **Save Settings**: Tap **Save** to apply these settings to all future detections.
  - **Hint**: Position the LED inside the green cone preview. Avoid making the cone too large to prevent false detections.

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
