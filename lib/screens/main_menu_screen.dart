import 'package:flutter/material.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Smart Mirror Menu")),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  child: const Text("QR Login (Test)"),
                  onPressed: () => Navigator.pushNamed(context, "/login"),
                ),
                ElevatedButton(
                  child: const Text("Recording Screen"),
                  onPressed: () => Navigator.pushNamed(context, "/record"),
                ),
                ElevatedButton(
                  child: const Text("Gallery"),
                  onPressed: () => Navigator.pushNamed(context, "/gallery"),
                ),
                ElevatedButton(
                  child: const Text("Mirror Discovery"),
                  onPressed: () => Navigator.pushNamed(context, "/mirrors"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
