# Changelog

All notable changes to Brown Paw will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-10-20

### Added
- ✨ Beautiful launch screen with app branding and loading animation
- 📊 Comprehensive performance logging system to track startup bottlenecks
- 🎨 Enhanced auth screen with loading states and error handling
- 📝 Changelog support in version checking system
- 🔍 Detailed performance monitoring for all initialization phases

### Changed
- ⚡ Optimized brownclaw.png asset from 4267x4267 (226KB) to 512x512 (28KB) - 87% reduction
- 🖼️ Improved image loading with caching (cacheWidth/cacheHeight)
- 🚀 Added asset preloading in index.html
- 📱 Enhanced update banner to display changelog items
- 🎯 Better error handling and fallbacks for image loading

### Performance
- 🏃 Auth screen first frame: 437ms (down from ~2700ms) - 84% faster
- ⏱️ Total startup time: ~3.6s on Chrome/Safari (consistent performance)
- 📦 Asset size reduction: 87% smaller images
- 🌐 Web-specific optimizations for faster initial load

### Developer Experience
- 📋 Added PERFORMANCE_LOGGING.md documentation
- 📊 Added PERFORMANCE_TEST_RESULTS.md with analysis
- 🧪 Created test_performance.sh script for easy testing
- 🔧 Performance logger utility for debugging
- 📝 Enhanced version control with changelog support

## [1.0.1] - 2025-10-18

### Fixed
- Various bug fixes and improvements

### Changed
- Updated dependencies

## [1.0.0] - Initial Release

### Added
- 🏞️ River run tracking and favorites
- 📖 Logbook for recording descents
- 🌊 Live water data integration
- 🔍 River search functionality
- 💳 Premium subscription via Stripe
- 🎨 Dark/light theme support
- 📱 Responsive web design
- 🔐 Google sign-in authentication
- ⭐ Rating system for river runs
- 📊 Analytics integration

---

## Version Numbering

Format: `MAJOR.MINOR.PATCH+BUILD`

- **MAJOR**: Breaking changes or major feature releases
- **MINOR**: New features (backwards compatible)
- **PATCH**: Bug fixes (backwards compatible)
- **BUILD**: Build number (incremented with each deployment)

Example: `1.1.0+3` = Version 1.1.0, Build 3
