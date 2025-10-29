/// Stub implementation for unsupported platforms
class StripeServiceImpl {
  static void redirectToCheckout(String url) {
    throw UnsupportedError('Platform not supported');
  }

  static String getCurrentUrl() {
    throw UnsupportedError('Platform not supported');
  }

  static void reloadPage() {
    throw UnsupportedError('Platform not supported');
  }
}
