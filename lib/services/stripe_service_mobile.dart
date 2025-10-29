/// Mobile-specific implementation
class StripeServiceImpl {
  static void redirectToCheckout(String url) {
    // Mobile doesn't use redirect - will use payment sheet instead
    throw UnsupportedError('Use payment sheet for mobile payments');
  }

  static String getCurrentUrl() {
    return 'brownclaw://stripe-redirect';
  }

  static void reloadPage() {
    // No-op on mobile
  }
}
