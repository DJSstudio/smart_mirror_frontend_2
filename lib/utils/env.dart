class Env {
  // Set at runtime via discovery or manual selection.
  static String baseUrl = "";

  // You can dynamically update this when switching mirrors
  static void updateBaseUrl(String newUrl) {
    baseUrl = newUrl;
  }
}
