#!/bin/bash
# 1. Download Flutter stable branch
echo "Downloading Flutter..."
git clone https://github.com/flutter/flutter.git -b stable

# 2. Add Flutter to the path
export PATH="$PATH:`pwd`/flutter/bin"

# 3. Enable web support (just in case)
flutter config --enable-web

# 4. Build the web application
echo "Building Flutter Web..."
flutter build web --release
