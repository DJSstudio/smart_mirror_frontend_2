class Env {
  // Default backend base URL (LAN / local testing)
  static String baseUrl = "http://192.168.1.8:8000/api";
  // static String baseUrl = "http://127.0.0.1:8000/api";
  // static String baseUrl = "https://192.168.1.15/api";

  // You can dynamically update this when switching mirrors
  static void updateBaseUrl(String newUrl) {
    baseUrl = newUrl;
  }
}
