# Milestone 1: App Foundation & Environment Setup

## Goal
The primary goal of this milestone is to establish the application foundation and provide tools to "label" sensors (via QR codes) and gather raw image/video data for computer vision calibration. This data will be crucial for the success of subsequent milestones.

## Deliverables

1.  **Product Management UI**: A simple interface to input and manage Product IDs.
2.  **QR Generator**: Functionality to generate a unique QR code for a given Product ID and save/export it as an Image or PDF for printing.
3.  **Data Capture Tool**: A dedicated camera interface to capture photos and videos. It should aim to capture "raw" data with minimal automatic post-processing (HDR, color correction) to ensure accurate computer vision analysis later.
4.  **Data Export**: A mechanism to zip and share the captured data.

## User Stories

### Product & QR Management
-   **US1.1**: As a user, I want to input a "Product Name" or "Product ID" so that I can uniquely identify a sensor location.
-   **US1.2**: As a user, I want to generate a QR code for a specific Product ID so that I can print it and attach it near the sensor.
-   **US1.3**: As a user, I want to save the generated QR code as an Image (PNG/JPG) or PDF so that I can easily print it.

### Data Capture
-   **US1.4**: As a user, I want to open a camera screen within the app so that I can capture test data.
-   **US1.5**: As a user, I want to take a photo of the sensor (with the QR code visible) so that I can provide static data for calibration.
-   **US1.6**: As a user, I want to record a short video of the sensor so that I can provide dynamic data for calibration.
-   **US1.7**: As a user, I want dependencies like HDR or heavy color correction to be minimized (if possible via the Camera API) so that the data represents the "raw" sensor colors.

### Export
-   **US1.8**: As a user, I want to export all captured photos and videos as a single ZIP file so that I can easily send the training data to the developer.

## Pages / Screens

### 1. Home / Product Screen
-   **Description**: The landing screen of the app, now with Supplier and Stock Status.
-   **UI Elements**:
    -   Text Input: "Product ID" (Uniqueness check required).
    -   Text Input: "Supplier Name".
    -   Dropdown: "Stock Status" (In/Low/Out).
    -   Button: "Generate QR".
    -   Buttons: Navigation to "Dashboard", "Data Capture", "Gallery".

### 2. QR Preview Screen (or Dialog)
-   **Description**: Displays the generated QR code.
-   **UI Elements**:
    -   Large display of the QR Code.
    -   Button: "Save as PDF" (Must be visible in Dark Mode).
    -   (Disabled) Button: "Share/Print".

### 3. Data Capture Screen
-   **Description**: A custom camera viewfinder.
-   **UI Elements**:
    -   Viewfinder: Full-screen camera preview.
    -   Toggle: Switch between "Photo" and "Video" mode.
    -   Buttons: Shutter (Click for Photo, Click to Start/Stop Video - Manual).
    -   Gallery Thumbnail: Interactive preview (Open Gallery).
    -   Top-positioned Snackbars for feedback.

### 4. Gallery Screen (Dashboard Action)
-   **Description**: Manage captured data.
-   **UI Elements**:
    -   Grid view of Photos/Videos (Separate folders internally).
    -   Delete File capability.
    -   Export Data (ZIP): "Download" to phone (Save to Files) option.
    -   Clear All Data option.

### 5. Dashboard Screen
-   **Description**: Table view of registered products.
-   **UI Elements**:
    -   Table: Product ID, Supplier, Stock Status (In=Green, Low=Orange, Out=Red), Actions.
    -   Horizontal Scroll indication.
    -   Actions: View QR, Delete Product.
    -   Global Actions: Print All QRs (PDF), Export Data (CSV Spreadsheet).

## Technical Constraints & Notes
-   **Platform**: Android (APK export required).
-   **Camera Package**: use `camera` package for lower-level control to attempt avoiding auto-enhancements.
-   **QR Package**: use `qr_flutter` for rendering and `pdf` package for document generation.
-   **Storage**: Use `path_provider` to store files locally in the app's documents directory.
-   **Theme**: Main color Blue (as per Project Rules).
