#!/bin/bash

# Favorites Loading Debug Script
# Run this to diagnose why favorites aren't loading

echo "🔍 Favorites Loading Diagnostic Script"
echo "========================================"
echo ""

# Kill any running flutter processes
echo "1️⃣ Stopping any running Flutter apps..."
pkill -f "flutter" 2>/dev/null
sleep 2

# Clear build cache
echo "2️⃣ Cleaning build cache..."
cd "$(dirname "$0")"
flutter clean > /dev/null 2>&1

# Build and run with debug output
echo "3️⃣ Starting app with debug logging..."
echo ""
echo "📝 Watch for these log messages:"
echo "   👤 = FavoritesProvider auth check"
echo "   ⭐ = Favorites loaded count"
echo "   🚀 = RiverRunProvider initialization"
echo "   💾 = Cache operations"
echo "   ⚡ = Cache hits"
echo "   🔍 = Screen checking favorites"
echo "   🔄 = Favorites changed trigger"
echo "   📥 = Loading favorite runs"
echo ""
echo "Press Ctrl+C to stop"
echo "========================================"
echo ""

# Run the app and filter for our debug markers
flutter run --debug 2>&1 | grep --line-buffered -E "(👤|⭐|🚀|💾|⚡|🔍|🔄|📥|ℹ️|⏳|❌|FavoritesProvider|FavouritesScreen|RiverRunProvider)" | while read line; do
    echo "[$(date +%H:%M:%S)] $line"
done
