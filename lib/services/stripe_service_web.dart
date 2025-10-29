import 'dart:html' as html;

/// Web-specific implementation
class StripeServiceImpl {
  static void redirectToCheckout(String url) {
    html.window.location.href = url;
  }

  static String getCurrentUrl() {
    return html.window.location.href;
  }

  static void reloadPage() {
    html.window.location.reload();
  }
}
