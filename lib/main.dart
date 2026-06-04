// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';

import 'providers/auth_provider.dart';

import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/customer/customer_home_screen.dart';
import 'screens/customer/laundry_detail_screen.dart';
import 'screens/customer/order_status_screen.dart';
import 'screens/owner/owner_home_screen.dart';
import 'screens/owner/manage_laundry_screen.dart';
import 'screens/owner/manage_services_screen.dart';
import 'screens/owner/order_manage_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await GoogleSignIn.instance.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..loadSession(),
        ),
      ],
      child: const LondreeApp(),
    ),
  );
}

class LondreeApp extends StatelessWidget {
  const LondreeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Londree - Laundry Service',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: Colors.grey.shade50,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Colors.white,
          foregroundColor: Colors.blue,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/customer-home': (context) => const CustomerHomeScreen(),
        '/laundry-detail': (context) => const LaundryDetailScreen(),
        '/order-status': (context) => const OrderStatusScreen(),
        '/owner-home': (context) => const OwnerHomeScreen(),
        '/manage-laundry': (context) => const ManageLaundryScreen(),
        '/manage-services': (context) => const ManageServicesScreen(),
        '/order-manage': (context) => const OrderManageScreen(),
      },
    );
  }
}