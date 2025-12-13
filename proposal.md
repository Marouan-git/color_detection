# Proposal: Traffic light sensor detection

## Purpose

Build a functional MVP that can be used locally. Allows to monitor stock
levels by detecting sensor lights via a mobile device. The solution uses
a hybrid approach: QR Codes for product identification and spatial
mapping, and Computer Vision for color status detection. Stock status is
updated in a local database and can be exported to a spreadsheet or
visible on a mini-dashboard within the app.

## Technical approach

**Stack:** Flutter (for Android & iOS cross-platform compatibility) +
OpenCV (Computer Vision).

**Method:** The app identifies the specific product via QR code and
analyzes the adjacent sensor light to update stock status in a local
database.

## Milestone 1: App Foundation & Environment Setup

**Goal:** Label the sensors and gather the required data for the
detection calibration.

### Deliverables

-   Product Management UI: Ability to input a "Product Name/ID".
-   QR Generator: App generates a unique QR code for that product (Save
    as Image/PDF to print).
-   Data Capture Tool (Photo & Video): A specialized camera interface to
    capture data for testing. For this initial data collection phase,
    please hold the phone directly facing the sensor (perpendicular) to
    ensure we capture accurate baseline measurements for calibration.

**Why:** Standard camera apps apply automatic filters (HDR, color
correction) that distort the color values needed for accurate detection.
This custom tool captures raw data optimized for computer vision
analysis.

### Acceptance criteria

-   App installs and opens successfully on the Android device.
-   Can input a Product ID and generate a scannable QR code (PDF/Image).
-   Can successfully record a video and capture a photo using the camera
    interface.
-   A "Share/Export" button successfully creates a zip file of the data
    to send to me.

**Time frame:** 1 week\
**Price:** 400\$

## Milestone 2: Static Detection & Spreadsheet Export

**Goal:** The core MVP. Analyze the photos taken in M1 and export
results.

**Prerequisite:** Photos captured in M1.

### Deliverables

-   Computer vision integration: Implement the algorithm to locate the
    QR code, find the relative position of the sensor, and read the HSV
    value for color detection.
-   Static Analysis: Take a picture → QR codes are scanned, colors
    detected, and status registered in a local database.
-   Excel/CSV Export: Button to export the scanned inventory list to a
    spreadsheet.

### Acceptance criteria

-   Successfully identifies the QR code and locates the target region
    for the sensor light in a static photo.
-   Correctly classifies clearly visible "Red" and "Yellow" states in
    the test images provided during M1.
-   The "Export" button generates a .csv file that accurately lists the
    scanned Product IDs and their statuses.

**Time frame:** 2 weeks\
**Price:** 900\$

## Milestone 3: Real-Time Live Feed & Dashboard

**Goal:** Improve UX to video mode and polish.

**Prerequisite:** Short videos captured in M1.

### Deliverables

-   Continuous Scanning: Point the camera and scan continuously. QR
    codes and color status are updated instantly.
-   Mini-Dashboard: A view in the app showing a summary (e.g., "5
    products out of stock") and list of products with their
    corresponding status.

### Acceptance criteria

-   App runs in live mode displaying the camera feed and detecting stock
    status.
-   Database updates status automatically when a QR code and color are
    detected in the live feed.
-   Dashboard view correctly summarizes counts based on the local
    database.

**Time frame:** 1.5 weeks\
**Price:** 700\$

## Project totals

-   **Time frame:** \~4--5 weeks\
-   **Price:** 2000\$

## Deliverables

-   Compiled Mobile App (APK for Android)
-   Full Source Code
-   Setup documentation

## Assumptions / Notes

1.  Testing on Android is free. iOS build requires an Apple Developer
    Account for TestFlight.
2.  QR codes must be attached in a consistent position relative to the
    sensor light.
3.  Algorithm works under standard lighting. Glare, darkness, or
    obstruction may impact accuracy.
4.  Out of Scope: Authentication, cloud database, desktop app,
    subscriptions, etc.

Development can begin as soon as the proposal is accepted.
