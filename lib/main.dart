import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/qr_display_screen.dart';
import 'screens/recording_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/mirror_list_screen.dart';
import 'screens/main_menu_screen.dart';
import 'screens/mirror_qr_screen.dart';
import 'screens/active_session_screen.dart';
import 'screens/video_player_screen.dart';
import 'screens/export_screen.dart';


void main() {
  runApp(const ProviderScope(child: SmartMirrorApp()));
}

class SmartMirrorApp extends StatelessWidget {
  const SmartMirrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Mirror',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.white,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),      
      // initialRoute: "/login",
      routes: {
        '/mirrors': (c) => const MirrorListScreen(),
        "/menu": (ctx) => const ActiveSessionScreen(),
        "/login": (context) => const QRDisplayScreen(),
        "/record": (c) => const RecordingScreen(),
        "/gallery": (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return GalleryScreen(sessionId: args["session_id"]);
        },
        "/video_player": (context) {
          final url = ModalRoute.of(context)!.settings.arguments as String;
          return MirrorVideoPlayerScreen(videoUrl: url);
        },
        "/export": (_) => const ExportScreen(),
      },
      initialRoute: "/login",
    );
  }
}

class AppHomePlaceholder extends StatelessWidget {
  const AppHomePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Smart Mirror Flutter App Initialized",
          style: TextStyle(fontSize: 20, color: Colors.white),
        ),
      ),
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import 'screens/qr_display_screen.dart';
// import 'screens/recording_screen.dart';
// import 'screens/gallery_screen.dart';
// import 'screens/mirror_list_screen.dart';
// import 'screens/active_session_screen.dart';
// import 'screens/video_player_screen.dart';
// import 'screens/export_screen.dart';

// import 'state/session_provider.dart';

// void main() {
//   runApp(const ProviderScope(child: SmartMirrorApp()));
// }

// class SmartMirrorApp extends ConsumerStatefulWidget {
//   const SmartMirrorApp({super.key});

//   @override
//   ConsumerState<SmartMirrorApp> createState() => _SmartMirrorAppState();
// }

// class _SmartMirrorAppState extends ConsumerState<SmartMirrorApp> {
//   // static const _deepLinkChannel =
//   //     MethodChannel("smartmirror/deeplink");

//   String? _initialRoute;

//   @override
//   void initState() {
//     super.initState();
//     // _handleInitialToken();
//   }

//   // Future<void> _handleInitialToken() async {
//   //   try {
//   //     final token =
//   //         await _deepLinkChannel.invokeMethod<String>("getInitialToken");

//   //     if (token != null && token.isNotEmpty) {
//   //       // 🔐 Activate session using QR token
//   //       await ref
//   //           .read(sessionProvider.notifier)
//   //           .activateWithQrToken(token);

//   //       setState(() {
//   //         _initialRoute = "/menu";
//   //       });
//   //     } else {
//   //       setState(() {
//   //         _initialRoute = "/login";
//   //       });
//   //     }
//   //   } catch (e) {
//   //     // Fallback → QR screen
//   //     setState(() {
//   //       _initialRoute = "/login";
//   //     });
//   //   }
//   // }

//   @override
//   Widget build(BuildContext context) {
//     if (_initialRoute == null) {
//       // Splash / loading
//       return const MaterialApp(
//         debugShowCheckedModeBanner: false,
//         home: Scaffold(
//           backgroundColor: Colors.black,
//           body: Center(
//             child: CircularProgressIndicator(),
//           ),
//         ),
//       );
//     }

//     return MaterialApp(
//       title: 'Smart Mirror',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData.dark().copyWith(
//         scaffoldBackgroundColor: Colors.black,
//         primaryColor: Colors.white,
//         textTheme: const TextTheme(
//           bodyMedium: TextStyle(color: Colors.white),
//         ),
//       ),
//       initialRoute: _initialRoute,
//       routes: {
//         '/mirrors': (c) => const MirrorListScreen(),
//         '/menu': (c) => const ActiveSessionScreen(),
//         '/login': (c) => const QRDisplayScreen(),
//         '/record': (c) => const RecordingScreen(),
//         "/gallery": (context) {
//           final route = ModalRoute.of(context);
//           final args = route?.settings.arguments as Map?;

//           if (args == null || args["session_id"] == null) {
//             return const Scaffold(
//               body: Center(child: Text("Missing session", style: TextStyle(color: Colors.white))),
//             );
//           }

//           return GalleryScreen(sessionId: args["session_id"]);
//         },
//         '/video_player': (context) {
//           final url =
//               ModalRoute.of(context)!.settings.arguments as String;
//           return MirrorVideoPlayerScreen(videoUrl: url);
//         },
//         '/export': (c) => const ExportScreen(),
//       },
//     );
//   }
// }
