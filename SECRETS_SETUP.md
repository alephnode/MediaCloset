# Secrets Configuration Setup

This document explains how to set up secure secrets management for the MediaCloset iOS app.

## Overview

The app uses a multi-layered approach to secrets management:

1. **Build-time Configuration**: Secrets are embedded during build using xcconfig files
2. **iOS Keychain**: Secrets are stored in the iOS Keychain for offline access
3. **Environment Variables**: Fallback for development scenarios

This approach ensures secrets are:
- ✅ Not committed to version control
- ✅ Not included in the app bundle (except when stored in Keychain)
- ✅ Available when iPhone is detached from Xcode
- ✅ Secure and encrypted in iOS Keychain

## Setup Instructions

### 1. Automatic Setup (Recommended)

Run the setup script from the project root:

```bash
./scripts/setup-secrets.sh
```

### 2. Manual Setup

If you prefer to set up manually:

1. **Copy the example secrets file:**
   ```bash
   cp Configs/Local.secrets.xcconfig.example Configs/Local.secrets.xcconfig
   ```

2. **Edit your secrets:**
   Open `Configs/Local.secrets.xcconfig` and fill in your actual values:
   ```xcconfig
   GRAPHQL_ENDPOINT = https://your-hasura-instance.hasura.app/v1/graphql
   HASURA_ADMIN_SECRET = your-actual-admin-secret-here
   ```

3. **Add xcconfig files to Xcode project:**
   - Open `MediaCloset.xcodeproj` in Xcode
   - Drag `Configs/Secrets.xcconfig` and `Configs/Local.secrets.xcconfig` into the project
   - Make sure they're added to the project (not just referenced)

4. **Configure build settings:**
   - Select the project in Xcode navigator
   - Go to the "Info" tab
   - Under "Configurations", set both Debug and Release to use `Secrets.xcconfig`
   - This will automatically include `Local.secrets.xcconfig` if it exists

## File Structure

```
Configs/
├── Secrets.xcconfig              # Base configuration (committed)
├── Local.secrets.xcconfig        # Your actual secrets (gitignored)
└── Local.secrets.xcconfig.example # Example file (committed)

MediaCloset/
└── Networking/
    ├── SecretsManager.swift      # Secrets management logic
    └── GraphQLHTTPClient.swift   # Updated to use SecretsManager
```

## How It Works

### Build Time
- `Secrets.xcconfig` defines the structure but contains no actual secrets
- `Local.secrets.xcconfig` (gitignored) contains your actual secrets
- Xcode merges these files and embeds the values in the app's Info.plist

### Runtime
The `SecretsManager` class tries to load secrets in this order:

1. **Build-time configuration** (from Info.plist)
2. **iOS Keychain** (for offline access)
3. **Environment variables** (development fallback)

### Keychain Storage
When the app runs and finds secrets in the build configuration, it automatically stores them in the iOS Keychain. This allows the app to work even when:
- The iPhone is detached from Xcode
- The app is installed via TestFlight or App Store
- No environment variables are available

## Security Features

- **No secrets in source code**: All secrets are externalized
- **Gitignore protection**: Local secrets files are never committed
- **iOS Keychain encryption**: Secrets are encrypted by iOS when stored
- **Automatic cleanup**: Debug methods available to clear keychain storage

## Development Workflow

### First Time Setup
1. Run the setup script or follow manual setup
2. Build and run the app
3. Secrets are automatically stored in iOS Keychain

### Updating Secrets
1. Edit `Configs/Local.secrets.xcconfig`
2. Clean build folder (⌘+Shift+K)
3. Build and run again
4. New secrets are automatically stored in Keychain

### Debugging
The `SecretsManager` includes debug logging and status methods:

```swift
// Check which sources have secrets
let status = SecretsManager.shared.secretsStatus
print("Secrets status: \(status)")

// Clear keychain secrets (debug only)
SecretsManager.shared.clearKeychainSecrets()
```

## Troubleshooting

### Secrets Not Loading
1. Check that `Local.secrets.xcconfig` exists and has correct values
2. Verify xcconfig files are properly configured in Xcode build settings
3. Clean build folder and rebuild
4. Check debug logs for specific error messages

### Keychain Issues
1. Delete and reinstall the app to reset Keychain
2. Use the `clearKeychainSecrets()` method in debug builds
3. Check iOS Keychain access permissions

### Build Errors
1. Ensure xcconfig files are added to the Xcode project
2. Check that build configurations are set to use `Secrets.xcconfig`
3. Verify file paths are correct

## Security Notes

- **CRITICAL**: Never commit `Local.secrets.xcconfig` to version control
- **CRITICAL**: No secrets should ever be hardcoded in Swift source files
- Use strong, unique secrets for production
- Rotate secrets regularly
- The example file shows the structure but contains no real secrets
- iOS Keychain provides hardware-backed encryption when available
- If secrets are missing, the app will fail fast in debug mode to catch configuration issues
- Production builds should never have missing secrets if properly configured

## Team Setup

For team members:
1. Each developer should copy `Local.secrets.xcconfig.example` to `Local.secrets.xcconfig`
2. Fill in their own development secrets
3. Never commit the actual secrets file
4. Use different secrets for development vs production environments
