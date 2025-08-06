import 'package:fast_past_papers/intro_Screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'getfiles.dart';

import 'authentications.dart';
import 'log.dart';
import 'options_Screen.dart'; // <-- Add this import
import 'message_File.dart'; // <-- Add this import
import 'getfiles.dart';
import 'homeScreen.dart';
import 'dart:io' as io;

late final SupabaseClient tempSupabaseClient;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Supabase.initialize(
    url: 'https://seutsksnrtvazixtrraq.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNldXRza3NucnR2YXppeHRycmFxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTExODQ1OTIsImV4cCI6MjA2Njc2MDU5Mn0.AmVZJewqpcB9Om0T0olCDgSCbDr5vzNpWCHeyLL0GPI',
  );
  tempSupabaseClient = SupabaseClient(
    'https://yzvmemyxwgcjrjelrsjy.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl6dm1lbXl4d2djanJqZWxyc2p5Iiwicm9zZSI6ImFub24iLCJpYXQiOjE3NTM4MTczNTYsImV4cCI6MjA2OTM5MzM1Nn0.UtFhYpJUstSjZPtYdjvglmsrGriXA2iu6ElFBVLRqro'
  );

  // Define the provider before using it
  final pastPaperProvider = PastPaperProvider();

  final prefs = await SharedPreferences.getInstance();
  final hasSeenIntro = prefs.getBool('hasSeenIntro') ?? false;

  runApp(
    ChangeNotifierProvider<PastPaperProvider>.value(
      value: pastPaperProvider,
      child: MaterialApp(
        home: hasSeenIntro
            ? const MyApp()
            : const into_Screen(),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF7FAF9),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1976D2),
            iconTheme: IconThemeData(color: Colors.white),
            elevation: 0,
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
            toolbarTextStyle: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
              letterSpacing: 1,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              elevation: 4,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1976D2),
              side: const BorderSide(color: Color(0xFF1976D2), width: 1.5),
              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            ),
          ),
          cardTheme: const CardThemeData(
            color: Colors.white,
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(22)),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            labelStyle: const TextStyle(color: Colors.black87),
          ),
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: Color(0xFF1976D2),
            contentTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            behavior: SnackBarBehavior.floating,
          ),
          iconTheme: const IconThemeData(color: Color(0xFF1976D2)),
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: Color(0xFF1976D2),
            selectionColor: Color(0xFF90CAF9),
            selectionHandleColor: Color(0xFF1976D2),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF1976D2),
            foregroundColor: Colors.white,
          ),
          progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: Color(0xFF1976D2),
          ),
        ),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const int currentAppVersion = 1;
  bool _versionBlocked = false;

  // Helper to check if current user is admin
  Future<bool> _isAdminUser() async {
    try {
      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) return false;
      final response = await Supabase.instance.client
          .from('Admins')
          .select('admin_Email')
          .eq('admin_Email', user.email!.toLowerCase())
          .maybeSingle();
      return response != null;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _storeCurrentVersion();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkVersionAndShowAlert(context);
      // Start prefetch in background after UI loads
      final provider = Provider.of<PastPaperProvider>(context, listen: false);
      provider.prefetchAll();
    });
  }

  Future<void> _storeCurrentVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('currentAppVersion', currentAppVersion);
  }

  Future<int?> _fetchLatestVersion() async {
    try {
      final response = await Supabase.instance.client
          .from('version')
          .select('current_Version')
          .order('current_Version', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && response['current_Version'] != null) {
        print('Latest version fetched: ${response['current_Version']}');
        return response['current_Version'] as int;
      }
    } catch (e) {
      print("Error fetching version: $e");
    }
    return null;
  }

  Future<void> _checkVersionAndShowAlert(BuildContext context) async {
    final latestVersion = await _fetchLatestVersion();

    if (latestVersion != null && latestVersion > currentAppVersion) {
      // ignore: use_build_context_synchronously
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Update Required'),
          content: const Text(
              'This version is not the latest. Please update the app for a seamless experience.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  // Only check version for non-admin users after login
  Future<void> _checkIfVersionIsWorkingForUser(BuildContext context) async {
    try {
      final isAdmin = await _isAdminUser();
      if (isAdmin) return; // Admins bypass version check

      final response = await Supabase.instance.client
          .from('version')
          .select('current_Version, working')
          .eq('current_Version', currentAppVersion)
          .maybeSingle();

      if (response != null && response['working'] == false) {
        setState(() {
          _versionBlocked = true;
        });
        // ignore: use_build_context_synchronously
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              title: const Text('App Disabled'),
              content: const Text(
                  'This version of the app is currently disabled. Please update or try again later.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Future.delayed(const Duration(milliseconds: 100), () {
                      io.exit(0);
                    });
                  },
                  child: const Text('Exit'),
                ),
              ],
            ),
          ),
        );
        Future.delayed(const Duration(milliseconds: 100), () {
          io.exit(0);
        });
      }
    } catch (e) {
      print("Error checking working: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_versionBlocked) {
      return WillPopScope(
        onWillPop: () async => false,
        child: const Scaffold(
          body: Center(
            child: Text(
              'This version of the app is currently disabled.',
              style: TextStyle(fontSize: 18, color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return MaterialApp(
      title: 'Fast Past Papers',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7FAF9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1976D2),
          iconTheme: IconThemeData(color: Colors.white),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
          toolbarTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 1,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            elevation: 4,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1976D2),
            side: const BorderSide(color: Color(0xFF1976D2), width: 1.5),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          ),
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(22)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          labelStyle: const TextStyle(color: Colors.black87),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF1976D2),
          contentTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
          behavior: SnackBarBehavior.floating,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1976D2)),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFF1976D2),
          selectionColor: Color(0xFF90CAF9),
          selectionHandleColor: Color(0xFF1976D2),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF1976D2),
          foregroundColor: Colors.white,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFF1976D2),
        ),
      ),
      // Always show OptionsScreen as the first screen after login
      home: StreamBuilder<fb_auth.User?>(
        stream: fb_auth.FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            final user = snapshot.data;
            if (user != null) {
              logUserEvent('App Opened');
              _checkIfVersionIsWorkingForUser(context).then((_) {
                showStartupMessage(context);
              });
              return const OptionsScreen(); // <-- Change to OptionsScreen
            } else {
              // Only show intro button on login page
              return Stack(
                children: [
                  const EmailAuthScreen(),
                  Positioned(
                    bottom: 24,
                    right: 24,
                    child: FloatingActionButton(
                      onPressed: () {
                        logUserEvent('Intro Screen Opened');
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => const into_Screen(),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                          ),
                        );
                      },
                      tooltip: 'View Intro Screen',
                      child: const Icon(Icons.info_outline),
                    ),
                  ),
                ],
              );
            }
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}

// No code changes required for this error.
// The error is due to network/DNS issues, not code.
