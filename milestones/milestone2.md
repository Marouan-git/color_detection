# Milestone 2: Static Detection & Spreadsheet Export

**Goal:** Implement a robust algorithm to detect traffic sensor LEDs (Red/Yellow/Green/Off) associated with a QR Code, tackling parallax issues using a "Vector Cone Search" strategy.

## Feature Specifications

### 1. Algorithm Architecture (Strategy Pattern)
*   **Plug-and-Play**: The codebase must support multiple detection algorithms.
*   **UI Selector**: A dropdown or settings menu to let the user switch between algorithms (e.g., "Vector Cone Search v1", "Future Algo v2").

### 2. "Vector Cone Search" Algorithm Logic
1.  **QR Scan**: Find QR code and get 4 corner points.
2.  **Geometry Calculation**:
    *   **Up Vector**: Calculate orientation based on QR corners.
    *   **Search ROI**: Define a trapezoidal "Cone" extending "up" from the QR code (approx 1.5x height).
3.  **Color Masking**:
    *   Convert ROI to HSV.
    *   Apply ranges for Red, Yellow, Green.
    *   **Filter**: Exclude white/glare (Min Saturation > 50, Value > 200).
4.  **Spatial Check**:
    *   Find contours/blobs.
    *   Validate if blob centroid is inside the Cone/ROI.
    *   Select largest matching blob.

### 3. User Interface & Visualization
*   **Input**: Take photo (Camera) or Pick from Gallery.
*   **Visualization (CustomPainter)**:
    *   Draw QR Boundaries (Blue).
    *   Draw Search Cone (Faint White/Gray).
    *   Draw Detected LED (Circle with color).
*   **Feedback**:
    *   "Product X detected: Status Red"
    *   "QR found, but no light in range"

### 4. Data & Gallery
*   **Storage**: Save processed images in `images/<AlgorithmName>/`.
*   **Export**: Existing ZIP export should include these new folders.
*   **Stock Update**: Automatically update the product's status in the local database if positive detection occurs.

## User Stories

### US2.1: Algorithm Configuration
*   **As a** tester,
*   **I want to** choose which detection algorithm to use from a list,
*   **So that** I can compare different approaches later.

### US2.2: Static Image Processing
*   **As a** user,
*   **I want to** take a photo of a sensor,
*   **So that** the app processes it to find the status.

### US2.3: Visual Debugging
*   **As a** user,
*   **I want to** see the "Cone" and the detected regions drawn on the image,
*   **So that** I trust the algorithm and understand why it succeeded or failed.

### US2.4: Auto-Update Stock
*   **As a** warehouse manager,
*   **I want** the app to automatically set the stock status of the detected Product ID,
*   **So that** I don't have to manually edit it.
