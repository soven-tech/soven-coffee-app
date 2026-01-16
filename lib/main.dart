import 'package:flutter/material.dart';
import 'models/user.dart';
import 'screens/device_list.dart';

void main() {
  runApp(const SovenApp());
}

class SovenApp extends StatelessWidget {
  const SovenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Soven',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Color(0xFF2A2A2A),
        primaryColor: Color(0xFF0064FF)
      ),
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // TODO: Load user from storage or create new user
    // For now, use test user from database
    User testUser = User(
      userId: 'b50fd1b2-1b38-4b74-9936-fd26b06a6e3c', // Your test user ID
      name: 'Aaron',
    );

    await Future.delayed(Duration(seconds: 2));

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DeviceListScreen(user: testUser),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF2A2A2A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'SOVEN',
              style: TextStyle(
                color: Color(0xFF0064FF) ,
                fontSize: 48,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Appliances that work for you',
              style: TextStyle(
                color: Color(0xFF3A3A3A),
                fontSize: 16,
              ),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(
              color: Color(0xFF0064FF),
            ),
          ],
        ),
      ),
    );
  }
}