# Google Tasks Mac Widget

A macOS app and widget that displays and manages your Google Tasks lists.

## How to run this project

### Prerequisites

- **Xcode** (from the Mac App Store or [developer.apple.com](https://developer.apple.com/xcode/))
- **CocoaPods**: `sudo gem install cocoapods` or `brew install cocoapods`
- **Google Cloud setup**: Create OAuth credentials (iOS/macOS client) and add the Client ID and URL scheme in the app. See `XCODE_GOOGLE_SETUP.md` in this repo for details.

### Build and run

1. Clone the repo:
   ```bash
   git clone https://github.com/ConniCodes/Google-Tasks-Mac-App.git
   cd Google-Tasks-Mac-App
   ```

2. Install CocoaPods dependencies and open the workspace:
   ```bash
   pod install
   open TasksWidgetXcode.xcworkspace
   ```

3. In Xcode, select the **TasksWidgetXcode** scheme and run (⌘R).

**Note:** Always open `TasksWidgetXcode.xcworkspace` (not the `.xcodeproj`) so that the Pods are included.
