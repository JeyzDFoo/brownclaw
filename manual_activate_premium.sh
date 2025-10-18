#!/bin/bash

# Quick script to manually activate premium for a user
# Run: ./manual_activate_premium.sh YOUR_USER_EMAIL

echo "🔧 Manual Premium Activation Script"
echo "=================================="
echo ""

if [ -z "$1" ]; then
    echo "Usage: ./manual_activate_premium.sh YOUR_EMAIL"
    echo "Example: ./manual_activate_premium.sh user@example.com"
    exit 1
fi

USER_EMAIL="$1"

echo "📧 Looking for user: $USER_EMAIL"
echo ""
echo "Please go to Firebase Console and follow these steps:"
echo ""
echo "1. Open: https://console.firebase.google.com/project/brownclaw/firestore"
echo ""
echo "2. Navigate to the 'users' collection"
echo ""
echo "3. Find the user with email: $USER_EMAIL"
echo "   (You can use the Filter feature)"
echo ""
echo "4. Click on the user document"
echo ""
echo "5. Add or update these fields:"
echo "   - isPremium: true (boolean)"
echo "   - subscriptionStatus: active (string)"
echo ""
echo "6. Save the changes"
echo ""
echo "7. Refresh your app - Premium should now be active! 🎉"
echo ""
echo "=================================="
