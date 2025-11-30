#!/bin/bash

# setup-secrets.sh
# Script to set up secrets configuration for MediaCloset

set -e

echo "🔐 Setting up secrets configuration for MediaCloset..."

# Check if we're in the right directory
if [ ! -f "MediaCloset.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Please run this script from the MediaCloset project root directory"
    exit 1
fi

# Create Configs directory if it doesn't exist
mkdir -p Configs

# Check if Local.secrets.xcconfig exists, if not copy from example
if [ ! -f "Configs/Local.secrets.xcconfig" ]; then
    if [ -f "Configs/Local.secrets.xcconfig.example" ]; then
        echo "📝 Creating Local.secrets.xcconfig from example..."
        cp Configs/Local.secrets.xcconfig.example Configs/Local.secrets.xcconfig
        echo "✅ Created Local.secrets.xcconfig"
        echo "⚠️  Please edit Configs/Local.secrets.xcconfig with your actual secrets"
    else
        echo "❌ Error: Local.secrets.xcconfig.example not found"
        exit 1
    fi
else
    echo "✅ Local.secrets.xcconfig already exists"
fi

echo ""
echo "🔧 Next steps:"
echo "1. Open MediaCloset.xcodeproj in Xcode"
echo "2. Add Configs/Secrets.xcconfig to your project"
echo "3. Add Configs/Local.secrets.xcconfig to your project"
echo "4. Set the xcconfig files as configuration files in build settings:"
echo "   - Go to project settings → Info → Configurations"
echo "   - Set 'Debug' and 'Release' to use 'Secrets.xcconfig'"
echo "5. Edit Configs/Local.secrets.xcconfig with your actual secrets"
echo ""
echo "📱 For detached iPhone usage:"
echo "   - The app will automatically store secrets in iOS Keychain"
echo "   - Secrets will be available even when not connected to Xcode"
echo ""
echo "✅ Setup complete!"
