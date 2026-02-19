import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const OxynicApp());
}

class OxynicApp extends StatelessWidget {
  const OxynicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {

  final String baseUrl = "https://oxynicpharma.co.in/sfa/web/";
  final String dashboardUrl = "https://oxynicpharma.co.in/sfa/web/dashboard.php";

  late WebViewController controller;
  bool isLoading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    initWebView();
  }

  Future<void> initWebView() async {

    final prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool("isLoggedIn") ?? false;

    late final PlatformWebViewControllerCreationParams params;

    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    controller = WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              isLoading = true;
              hasError = false;
            });
          },
          onPageFinished: (url) async {
            setState(() => isLoading = false);

            // ✅ If Dashboard loaded → Save login state
            if (url.contains("dashboard.php")) {
              await prefs.setBool("isLoggedIn", true);
            }

            // ❌ Prevent going back to login page
            if (url == baseUrl && isLoggedIn) {
              controller.loadRequest(Uri.parse(dashboardUrl));
            }
          },
          onWebResourceError: (error) {
            setState(() {
              hasError = true;
              isLoading = false;
            });
          },
        ),
      );

    // ✅ Load correct page on start
    if (isLoggedIn) {
      controller.loadRequest(Uri.parse(dashboardUrl));
    } else {
      controller.loadRequest(Uri.parse(baseUrl));
    }

    setState(() {});
  }

  // ✅ Custom Back Button Logic
  Future<bool> _onWillPop() async {

    if (await controller.canGoBack()) {

      String? currentUrl = await controller.currentUrl();

      // ❌ If current page is dashboard → Ask exit instead of going back
      if (currentUrl != null && currentUrl.contains("dashboard.php")) {
        return await _showExitDialog();
      }

      controller.goBack();
      return false;
    }

    return await _showExitDialog();
  }

  Future<bool> _showExitDialog() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Exit App"),
        content: const Text("Are you sure you want to exit?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Yes"),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [

              if (!hasError)
                WebViewWidget(controller: controller),

              // ✅ Loading Indicator
              if (isLoading)
                const Center(
                  child: CircularProgressIndicator(),
                ),

              // ✅ Internet Error Screen
              if (hasError)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, size: 80, color: Colors.grey),
                      const SizedBox(height: 20),
                      const Text(
                        "No Internet Connection",
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            hasError = false;
                            isLoading = true;
                          });
                          controller.loadRequest(Uri.parse(baseUrl));
                        },
                        child: const Text("Retry"),
                      )
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
