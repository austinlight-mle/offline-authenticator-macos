# Version 1.5.0 (community fork)
- Renamed the app to Altosec Authenticator (bundle identifiers `me.altosec.*`, app group,
  keychain service, iCloud container and backup file names) so it can be installed next to the
  original app without conflicts; Proton remains the name of the optional sync service
- Native macOS app: the Xcode project now builds for "My Mac" with a narrow, phone-like window
  (420 pt wide by default, capped at 560 pt) that lists codes one per line; Debug builds are
  signed to run locally so no Apple developer team is required
- Groups: create, rename, recolor, reorder and delete groups, move codes between groups from
  their menu, filter the list with the new group bar and pick a group when creating a code
- Icons: 260+ bundled brand icons (Simple Icons, CC0) used offline for well known issuers, plus
  per code icon overrides (brand icon, SF Symbol with color, or a picture from your files);
  Google, Gmail, Chrome, Google Play, YouTube and Microsoft use their full color logos
- macOS shows onboarding inline instead of in a sheet (the sheet collapsed in the narrow window
  and blocked Quit while presented)
- Biometric lock on macOS: the lock screen now replaces the code list (and its toolbar) until
  Touch ID succeeds, with an Unlock button to retry, and every new launch starts locked
- Settings no longer shows Proton service items (Pass banner, Sync via Proton, Discover Proton,
  Tell a friend / Rate, Report an issue); the macOS Settings sheet has a Close button and all
  macOS sheets and the main window are narrower (window 340 pt by default, 300 to 480 pt)
- New shield app icon for all platforms; the macOS window defaults to 370 x 550 pt and text uses
  the native macOS text style sizes (with a slight width based scale) so sheets stay neat
- Groups and icon overrides are stored locally next to the encrypted entries; the encrypted
  entry format, Proton sync, backups and import/export are unchanged
- macOS no longer uses the keychain (which asked for access at every launch of a locally signed
  build): keys and small secrets are kept in an encrypted vault file in the app's sandbox
  container, bound to the Mac's hardware UUID; existing keychain items are migrated once
- Fixed the mangled `APP_VERSION_IDENTIFIER` / `IS_QA_BUILD` placeholders in the public export
- Swift 6.4 (Xcode 27) compatibility: `SimpleToast` is vendored with an initialiser fix,
  the scanner's corner shape is `nonisolated`, and the
  macOS Info.plist disables Go async preemption to avoid a sporadic launch abort in GoLibs

# Version 1.4.4
- Upgraded Rust library from 1.3.0 to 1.7.2
- Disabled VoiceOver when the app is locked
- Added options to refer the app and rate it
- Added the ability to create a dedicated backup folder within the selected directory.

# Version 1.4.3
- Improved animations for a smoother scrolling experience
- Fixed issues with search functionality

# Version 1.4.2
- Added back iCloud sync
- Some bug fixes and performance improvements

# Version 1.4.1
Improvements:
- Prompt before disabling automatic backups
- Show a toast message after manually creating a backup
- Handle inactive user keys

# Version 1.4.0
Liquid Glass design: The app now embraces the latest design language, delivering a more modern and native experience.
More reliable backup: Due to reliability issues with Apple's iCloud SDK, we've switched to the new backup.

- Upgraded Rust library from 0.28.8 to 1.3.0
- Upgraded core libraries from 35.0.0 to 36.0.3

# Version 1.3.3
- Fixed an issue where the iCloud sync error popup was shown repeatedly
- Improved logging during encryption and decryption operations
- Upgraded Rust library from 0.27.0 to 0.28.8
- Upgraded core libraries from 33.5.1 to 35.0.0

# Version 1.3.2
Fixed crashes on Apple Watch

# Version 1.3.1
Copy next code: you can now tap to copy the next code

Improvements:
- Show a warning when iCloud sync issues are detected.
- Log decryption states

# Version 1.3.0
Sort options: you can now sort entries in 7 different modes

Improvements:
- Authentication required when enabling or disabling iCloud sync
- Added option to delete all data
- Fixed codes not updating when app returns to foreground
- Updated requirement to watchOS 10 instead of 11
- Upgraded Rust library from 0.25.10 to 0.25.11

# Version 1.2.0
Secure data export: you can now protect your exported data with a password for enhanced security.
Apple Watch complications: quickly access Altosec Authenticator with four new complication options.

Improvements:
- Fix for an issue where scanning a Google QR code occasionally created duplicate entries
- Support otpauth URIs with colons
- Fix iPad entries not reloading after delete
- Upgraded Rust library from 0.25.9 to 0.25.10

# Version 1.1.4
- Fixed occasional code disappearing
- Fixed occasional login sessions not persisting
- Upgraded Rust library from 0.25.8 to 0.25.9

# Version 1.1.3
- Fixed codes failing to update in search mode
- Fixed crashes when reordering list entries
- Resolved "scanning unavailable" error on some devices
- Upgraded Rust library from 0.25.6 to 0.25.8

# Version 1.1.2
- Fixed flickering biometric lock
- Improved import process
- Resolved FIDO key authentication issue
- Upgraded Rust library from 0.25.2 to 0.25.6 
- Upgraded core library from 32.4.0 to 32.8.1

# Version 1.1.1
- Improved the import process to resolve issues with certain data sources
- Improved log messages

# Version 1.1.0
Added support for Apple Watch

# Version 1.0.0
Initial version
