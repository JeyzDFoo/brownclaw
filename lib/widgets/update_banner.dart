import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/stripe_service_stub.dart'
    if (dart.library.html) '../services/stripe_service_web.dart'
    if (dart.library.io) '../services/stripe_service_mobile.dart';

/// Banner that displays when an app update is available
///
/// Shows a dismissible banner prompting user to refresh
class UpdateBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;
  final List<String>? changelog;

  const UpdateBanner({
    super.key,
    required this.message,
    this.onDismiss,
    this.changelog,
  });

  void _refreshPage() {
    // Force refresh the page to get new version (web only)
    if (kIsWeb) {
      StripeServiceImpl.reloadPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.orange[700],
      elevation: 4,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.system_update, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Update Available',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    if (changelog != null && changelog!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...changelog!
                          .take(3)
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(left: 8, top: 2),
                              child: Text(
                                item,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _refreshPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.orange[700],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: const Text('Refresh Now'),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: onDismiss,
                tooltip: 'Dismiss',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
