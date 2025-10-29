# iOS Launch Screen - BrownClaw

## 🎨 Design Overview

A modern, brand-aligned launch screen featuring:
- **Rich brown gradient background** (#8B4513 - BrownClaw brown)
- **Teal accent wave** at the bottom (#009688 - BrownClaw teal, 30% opacity)
- **Centered app icon** (200x200pt)
- **Bold "BrownClaw" title** (40pt, white, drop shadow)
- **Tagline**: "Track Your Whitewater Adventures" (17pt, light teal)
- **Dark mode support** with deeper brown gradient

## 📱 Features

- **Adaptive layout** - Works on all iPhone sizes (SE to Pro Max)
- **Dark mode aware** - Gradient adjusts automatically
- **Brand consistent** - Uses official BrownClaw colors
- **Clean & modern** - Minimal design, maximum impact

## 🎯 Colors Used

### Light Mode
- Background: Brown (#8B4513 / RGB 139, 69, 19)
- Text: White with subtle shadow
- Accent: Teal 30% opacity (#009688)

### Dark Mode
- Background: Deep Brown (#644931 / RGB 100, 49, 13)
- Accent: Teal 40% opacity (slightly more visible in dark)

## 📝 Files Modified/Created

1. `LaunchScreen.storyboard` - Main storyboard with layout
2. `Assets.xcassets/LaunchGradientTop.colorset/` - Brown gradient color
3. `Assets.xcassets/LaunchAccent.colorset/` - Teal accent color

## 🚀 Testing

To test the launch screen:
```bash
# Clean build
flutter clean
rm -rf ios/Pods ios/Podfile.lock

# Rebuild iOS
cd ios
pod install
cd ..

# Run on simulator or device
flutter run -d <device-id>
```

The launch screen will appear briefly before the app loads.

## 🎨 Design Notes

The wave accent at the bottom creates a dynamic "water" feel that ties into the whitewater theme while remaining subtle and professional. The gradient provides depth and visual interest without being overwhelming.

The centered layout ensures the design works on all screen sizes, and the drop shadow on the title provides depth and readability against the brown background.
