# 📂 Flutter Google Drive Manager

A powerful full-stack application enabling seamless interaction with Google Drive. Features secure authentication, advanced file management, document scanning, and intelligent file handling (like automatic Image-to-PDF conversion).

## 🚀 Features

*   **🔐 Google Authentication**: Secure sign-in to access personal Drive storage using Google Sign-In.
*   **📡 Smart Uploads**:
    *   Upload single or multiple files.
    *   **Auto-PDF Conversion**: Select multiple images, and the backend automatically merges them into a single PDF before uploading to Drive.
*   **📷 Document Scanner**: Built-in camera integration (via ML Kit) to scan, auto-crop, and filter physical documents before uploading.
*   **📂 File Management**:
    *   Create Folders.
    *   **Rename** Files and Folders.
    *   **Delete** Items.
    *   Navigate deeply nested folders.
*   **⚡ Optimistic UI**: Instant visual feedback for uploads, renames, and creations for a buttery smooth experience.
*   **🤖 Smart Organization**: Automatically initializes and maintains a folder structure: `Bills`, `Notes`, `Receipts`, and `Certificates` inside your `My Doc` root folder.

---

## 🛠️ Tech Stack

### **Frontend** (Mobile App)
*   **Framework**: Flutter (Dart)
*   **Key Packages**:
    *   `google_sign_in`: Authentication.
    *   `google_mlkit_document_scanner`: Scanning logic.
    *   `http`: API communication.
    *   `file_picker`: File selection.
    *   `url_launcher`: Opening Drive links.

### **Backend** (API Server)
*   **Framework**: FastAPI (Python)
*   **Key Libraries**:
    *   `google-api-python-client`: Drive API interaction.
    *   `img2pdf`, `Pillow`: Image processing and PDF generation.
    *   `uvicorn`: ASGI Server.

---

## ⚙️ Setup & Installation

Follow these steps to run the project locally.

### 1️⃣ Backend Setup

The backend acts as a middleware to handle complex file operations and proxy Drive API requests.

1.  **Navigate to the backend directory**:
    ```bash
    cd backend
    ```
2.  **Create a virtual environment (Optional but Recommended)**:
    ```bash
    python -m venv .venv
    .venv\Scripts\activate  # Windows
    # source .venv/bin/activate # Mac/Linux
    ```
3.  **Install Dependencies**:
    ```bash
    pip install -r requirements.txt
    ```
4.  **Run the Server**:
    ```bash
    uvicorn main:app --reload --host 0.0.0.0 --port 8000
    ```

### 2️⃣ Frontend Setup

1.  **Navigate to the frontend directory**:
    ```bash
    cd frontend
    ```
2.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```
3.  **Configure Connectivity**:
    The app needs to reach the backend running on your computer.

    *   **📱 Option A: Physical Android Device (Recommended)**
        1.  Connect your phone via USB.
        2.  Enable **USB Debugging** in Developer Options.
        3.  Run this command to bridge the connection:
            ```bash
            adb reverse tcp:8000 tcp:8000
            ```
            *(If you have emulators open, use `adb -s <DEVICE_ID> reverse ...`)*
        4.  Ensure `lib/api_service.dart` uses:
            ```dart
            static const String baseUrl = 'http://127.0.0.1:8000';
            ```

    *   **💻 Option B: Android Emulator**
        1.  Ensure `lib/api_service.dart` uses:
            ```dart
            static const String baseUrl = 'http://10.0.2.2:8000';
            ```

4.  **Run the App**:
    ```bash
    flutter run
    ```

---

## 📱 How to Use

1.  **Sign In**: Tap the specific Google account to authenticate.
2.  **Navigate**: You start in `My Doc`. Tap folders to enter them. Swipe back or use the arrow to go up.
3.  **Scan Document**: Tap the **Camera Icon** (Floating Button) to scan receipts or docs. They auto-upload to the current folder.
4.  **Upload Files**: Tap the **Upload Icon** to pick existing files or photos.
5.  **Manage**: Tap the **3-dot menu** on any file to **Rename** or **Delete**.

