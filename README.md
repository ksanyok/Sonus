# Sonus

Sonus is a macOS desktop application for recording, transcribing, and analyzing conversations using OpenAI's Whisper and ChatGPT models.

## Features

- **Recording**: High-quality audio recording with visualization.
- **Transcription**: Uses OpenAI Whisper API.
- **Analytics**: Sentiment analysis, summary, participant detection using ChatGPT.
- **UI**: Modern macOS interface with a mini-window for quick access.
- **Privacy**: Local storage of audio and API keys.

## Setup

### Prerequisites

- macOS 14.0 or later (for best SwiftUI support).
- Xcode 15+ installed.
- OpenAI API Key.

### How to Run

1. **Open in Xcode**:
   - Open the `Sonus` folder in Xcode.
   - Xcode should recognize the `Package.swift` and set up the scheme.

2. **Configure Permissions (Important)**:
   - Since this app uses the Microphone, it requires `NSMicrophoneUsageDescription` in `Info.plist`.
   - If you are generating an Xcode project (`swift package generate-xcodeproj`), you must manually add the `Info.plist` to the target settings.
   - **Recommended**: Create a new macOS App project in Xcode, drag the `Sources` folder into it, and configure the `Info.plist` with the content provided in `Info.plist` file in this repo.
   - Ensure "App Sandbox" is enabled and "Hardware -> Audio Input" is checked in the "Signing & Capabilities" tab.

3. **Build and Run**:
   - Select the target and press `Cmd+R`.

## Architecture

- **MVVM**: ViewModels manage state and business logic.
- **Services**:
  - `AudioRecorder`: Handles `AVAudioRecorder`.
  - `OpenAIClient`: Handles API requests.
  - `PersistenceService`: Manages local JSON storage.
  - `KeychainService`: Securely stores the API key.
- **Views**:
  - `MainWindow`: Main dashboard.
  - `MiniWindow`: Compact always-on-top recorder.

## Hotkeys

- `Cmd+Shift+R`: Start/Stop Recording.
- `Cmd+Shift+M`: Toggle Mini Window.
