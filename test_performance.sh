#!/bin/bash

# Performance Testing Script for Brown Paw Web App
# This script helps you test the app on different browsers and collect performance data

echo "🚀 Brown Paw Performance Testing Script"
echo "========================================"
echo ""

# Function to show usage
show_usage() {
    echo "Usage: ./test_performance.sh [browser]"
    echo ""
    echo "Browsers:"
    echo "  chrome  - Test in Chrome (default)"
    echo "  safari  - Test in Safari"
    echo "  edge    - Test in Edge"
    echo ""
    echo "Example:"
    echo "  ./test_performance.sh chrome"
    echo ""
}

# Get browser from argument or default to chrome
BROWSER=${1:-chrome}

echo "📊 Starting Flutter app in $BROWSER..."
echo ""
echo "Performance logs will appear in:"
echo "  1. Terminal output below"
echo "  2. Browser Console (press F12 or Cmd+Opt+I)"
echo ""
echo "Look for lines starting with:"
echo "  ⏱️ [PERF] - Dart/Flutter performance logs"
echo "  ⏱️ [WEB]  - Browser/JavaScript performance logs"
echo ""
echo "---------------------------------------------------"
echo ""

# Run Flutter in specified browser
if [ "$BROWSER" == "safari" ]; then
    flutter run -d web-server --web-port=8080 --web-browser-flag="--disable-web-security"
else
    flutter run -d $BROWSER --web-browser-flag="--disable-web-security"
fi

echo ""
echo "---------------------------------------------------"
echo "Testing complete!"
echo ""
echo "To analyze performance:"
echo "1. Check the terminal output above for ⏱️ [PERF] logs"
echo "2. Open browser DevTools and check Console for ⏱️ [WEB] logs"
echo "3. Look for the PERFORMANCE SUMMARY near the end"
echo "4. Identify the slowest phases and optimize accordingly"
echo ""
