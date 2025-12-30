# Milestone 3: Real-time Processing

## Overview
Implement real-time detection on a live camera feed. This allows users to point their camera at products and see the app automatically detect QR codes, locate the sensor cone, identify the LED color, and update the product status in real-time, without manually taking a photo.

## Features

### 1. Real-time Detection Mode
- **Access**: Add a "Real-time Detection" button to the `AnalysisScreen` (alongside "Take a picture" and "Upload an image").
- **Live Feed**: Opens a camera view that processes frames continuously.
- **Workflow**:
    1.  **Scan QR**: Detects QR code in the stream to identify the product.
    2.  **Cone Search**: specific search for cone shape relative to QR.
    3.  **LED Detection**: Analyzes the specific LED area for color.
    4.  **Auto-Update**: If a valid status (Green/Yellow/Red) is detected with high confidence for X consecutive frames (optional stabilization), update the product status automatically.
- **Visual Feedback**:
    - Draw bounding boxes/overlays on the camera preview in real-time.
    - Show the detected QR content and current status/color.

### 2. Implementation Details
- **Camera Stream**: Use `startImageStream` from the `camera` package.
- **Processing**:
    - Convert `CameraImage` to a format suitable for OpenCV/ML Kit.
    - Run the existing `ConeSearchAlgorithm` (or an optimized version) on the stream.
    - Since image stream provides YUV420, conversion to RGB/BGR might be needed for OpenCV.

## Acceptance Criteria
- [ ] "Real-time Detection" button exists on Analysis Screen.
- [ ] User can see camera feed.
- [ ] App detects QR code in live view and identifies product.
- [ ] App detects cone and LED color in live view.
- [ ] Overlays show what is being detected (QR box, Cone box, Color).
- [ ] Product status is updated in the database/dashboard upon successful detection.
