// Main App Structure
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'ActiveOrderScreen.dart';
import 'LoginScreen.dart';
import 'TableScreen.dart';
import 'TakeawayScreen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // required for FlutterFire
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Restaurant Waiter App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;
          if (user == null) {
            return LoginScreen();
          }
          return MainWaiterApp();
        }
        return Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}

class MainWaiterApp extends StatefulWidget {
  @override
  _MainWaiterAppState createState() => _MainWaiterAppState();
}

class _MainWaiterAppState extends State<MainWaiterApp> {
  int _selectedIndex = 0;
  final Color primaryColor = Color(0xFF1976D2);

  // Build screen lazily - only the active screen is rendered
  // This prevents all Firestore streams from running simultaneously
  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return TablesScreen();
      case 1:
        return ActiveOrdersScreen();
      case 2:
        return TakeawayOrderScreen();
      default:
        return TablesScreen();
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No global appBar - each screen handles its own
      // Using conditional rendering instead of IndexedStack for better performance
      body: _buildScreen(_selectedIndex),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: primaryColor,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white70,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            elevation: 0,
            selectedFontSize: 12,
            unselectedFontSize: 10,
            items: [
              BottomNavigationBarItem(
                icon: Container(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.table_restaurant),
                ),
                activeIcon: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.table_restaurant),
                ),
                label: 'Tables',
              ),

              BottomNavigationBarItem(
                icon: Container(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.newspaper_outlined),
                ),
                activeIcon: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.newspaper_rounded),
                ),
                label: 'Orders',
              ),

              BottomNavigationBarItem(
                icon: Container(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.shopping_bag_outlined),
                ),
                activeIcon: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.shopping_bag),
                ),
                label: 'Takeaway',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
