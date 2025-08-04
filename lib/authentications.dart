import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'log.dart';
import 'login_Type.dart';
import 'homeScreen.dart';
import 'options_Screen.dart'; // Import OptionsScreen

final loginType = LoginType();

class EmailAuthScreen extends StatelessWidget {
  const EmailAuthScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7), Color(0xFF91EAE4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Hero(
                  tag: 'past_paper_icon',
                  child: CircleAvatar(
                    radius: 54,
                    backgroundColor: Colors.deepPurple.withOpacity(0.18),
                    child: Image.asset('assets/logo.jpg', width: 70, height: 70),
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  elevation: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  color: Colors.white,
                  shadowColor: Colors.deepPurple.withOpacity(0.12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Everything you need fastians',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                            letterSpacing: 0.7,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Divider(
                          color: Colors.blue.shade100,
                          thickness: 1.2,
                          height: 28,
                        ),
                        _LoginForm(),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.blue.shade100)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text("or", style: TextStyle(color: Colors.grey[600])),
                            ),
                            Expanded(child: Divider(color: Colors.blue.shade100)),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _SocialLoginButtons(),
                        const SizedBox(height: 10),
                        // Add "Forgot Password?" button
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                              );
                            },
                            child: const Text(
                              "Forgot Password?",
                              style: TextStyle(
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) => const EmailSignUpScreen(),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                  return FadeTransition(opacity: animation, child: child);
                                },
                              ),
                            );
                          },
                          child: const Text(
                            "Don't have an account? Sign Up",
                            style: TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatefulWidget {
  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;

  // Fetch admin emails from Supabase
  Future<List<String>> fetchAdminEmails() async {
    try {
      final response = await Supabase.instance.client
          .from('Admins')
          .select('admin_Email');
      if (response is List) {
        return response
            .map((e) => e['admin_Email']?.toString().toLowerCase())
            .where((email) => email != null)
            .cast<String>()
            .toList();
      }
    } catch (e) {
      logUserEvent('AdminEmailFetchFail', details: e.toString());
    }
    return [];
  }

  String _getFriendlyError(String? code, String? message) {
    switch (code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
        return 'No user found for this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in or use another email.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      default:
        return message ?? 'An unknown error occurred. Please try again.';
    }
  }

  Future<void> _signInWithEmail() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );

      if (FirebaseAuth.instance.currentUser?.emailVerified == false) {
        setState(() {
          _error = "Please verify your email address before logging in. Check your inbox for a verification email.";
        });
        await FirebaseAuth.instance.signOut();
        logUserEvent('LoginFail', details: 'Email not verified');
        return;
      }

      await loginType.fetchEditorEmails();

      String? email = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
      String message = "Logged in as user";
      final adminEmails = await fetchAdminEmails();
      if (adminEmails.contains(email)) {
        message = "Logged in as admin";
        logUserEvent('AdminLogin', details: email);
      } else {
        final response = await Supabase.instance.client
            .from('Editors')
            .select('Editor_Email');
        if (response is List) {
          final editors = response
              .map((e) => e['Editor_Email']?.toString().toLowerCase())
              .where((e) => e != null)
              .cast<String>()
              .toList();

          if (editors.contains(email)) {
            message = "Logged in as editor";
            logUserEvent('EditorLogin', details: email);
          } else {
            logUserEvent('UserLogin', details: email);
          }
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const OptionsScreen(), // <-- Change to OptionsScreen
          ),
        );
        Future.delayed(const Duration(milliseconds: 300), () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.teal,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = _getFriendlyError(e.code, e.message);
      });
      logUserEvent('LoginFail', details: e.code);
    } catch (e) {
      setState(() {
        _error = "An unexpected error occurred. Please try again.";
      });
      logUserEvent('LoginFail', details: 'Unexpected: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            child: TextFormField(
              controller: _email,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                labelStyle: const TextStyle(color: Colors.black87),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  logUserEvent('Login Validation Failed', details: 'Email empty');
                  return 'Please enter your email address';
                }
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                  logUserEvent('Login Validation Failed', details: 'Invalid email format');
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 14),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            child: TextFormField(
              controller: _password,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                labelStyle: const TextStyle(color: Colors.black87),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                    logUserEvent('Password Visibility Toggled', details: _obscurePassword ? 'Hidden' : 'Visible');
                  },
                ),
              ),
              obscureText: _obscurePassword,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  logUserEvent('Login Validation Failed', details: 'Password empty');
                  return 'Please enter your password';
                }
                if (value.length < 6) {
                  logUserEvent('Login Validation Failed', details: 'Password too short');
                  return 'Password must be at least 6 characters long';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 14),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: AnimatedOpacity(
                opacity: _error != null ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                elevation: 5,
              ),
              onPressed: _loading
                  ? null
                  : () {
                      if (_formKey.currentState!.validate()) {
                        _signInWithEmail();
                      }
                    },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Login'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialLoginButtons extends StatefulWidget {
  @override
  State<_SocialLoginButtons> createState() => _SocialLoginButtonsState();
}

class _SocialLoginButtonsState extends State<_SocialLoginButtons> {
  bool _loading = false;

  Future<List<String>> fetchAdminEmails() async {
    try {
      final response = await Supabase.instance.client
          .from('Admins')
          .select('admin_Email');
      if (response is List) {
        return response
            .map((e) => e['admin_Email']?.toString().toLowerCase())
            .where((email) => email != null)
            .cast<String>()
            .toList();
      }
    } catch (e) {
      logUserEvent('AdminEmailFetchFail', details: e.toString());
    }
    return [];
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);

    try {
      logUserEvent('GoogleLoginStart');
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _loading = false);
        logUserEvent('GoogleLoginCancel');
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      await loginType.fetchEditorEmails();

      String? email = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
      String message = "Logged in as user";
      final adminEmails = await fetchAdminEmails();
      if (adminEmails.contains(email)) {
        message = "Logged in as admin";
        logUserEvent('AdminGoogleLogin', details: email);
      } else {
        final response = await Supabase.instance.client
            .from('Editors')
            .select('Editor_Email');
        if (response is List) {
          final editors = response
              .map((e) => e['Editor_Email']?.toString().toLowerCase())
              .where((e) => e != null)
              .cast<String>()
              .toList();
          if (editors.contains(email)) {
            message = "Logged in as editor";
            logUserEvent('EditorGoogleLogin', details: email);
          } else {
            logUserEvent('UserGoogleLogin', details: email);
          }
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OptionsScreen()), // <-- Change to OptionsScreen
        );
        Future.delayed(const Duration(milliseconds: 300), () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.teal,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        });
      }
    } on FirebaseAuthException catch (e) {
      logUserEvent('GoogleLoginFail', details: e.code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Google sign-in failed. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      logUserEvent('GoogleLoginFail', details: 'Unexpected: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Google sign-in failed. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _signInAnonymously() async {
    setState(() => _loading = true);
    try {
      logUserEvent('Guest Login Started');
      await FirebaseAuth.instance.signInAnonymously();
      await loginType.fetchEditorEmails();

      logUserEvent('Guest Login');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OptionsScreen()), // <-- Change to OptionsScreen
        );
        Future.delayed(const Duration(milliseconds: 300), () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Logged in as user"),
              backgroundColor: Colors.teal,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        });
      }
    } on FirebaseAuthException catch (e) {
      logUserEvent('Guest Login Failed', details: 'Code: ${e.code}, Message: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Guest login failed. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      logUserEvent('Guest Login Failed', details: 'Unexpected error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Guest login failed. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.account_circle, size: 20),
            label: const Text('Google'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              elevation: 5,
            ),
            onPressed: _loading ? null : _signInWithGoogle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.person_outline, size: 20),
            label: const Text('Guest'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              elevation: 5,
            ),
            onPressed: _loading ? null : _signInAnonymously,
          ),
        ),
      ],
    );
  }
}

class EmailSignUpScreen extends StatefulWidget {
  const EmailSignUpScreen({Key? key}) : super(key: key);

  @override
  State<EmailSignUpScreen> createState() => _EmailSignUpScreenState();
}

class _EmailSignUpScreenState extends State<EmailSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _info;
  bool _obscurePassword = true;

  String _getFriendlyError(String? code, String? message) {
    switch (code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in or use another email.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return message ?? 'An unknown error occurred. Please try again.';
    }
  }

  Future<void> _signUp() async {
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      logUserEvent('Signup Started', details: _email.text.trim());
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      setState(() {
        _info = "A verification email has been sent. Please check your inbox (Also spam folder) and verify your email before signing in.";
      });
      await FirebaseAuth.instance.signOut();
      logUserEvent('User Signup', details: _email.text.trim());
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = _getFriendlyError(e.code, e.message);
      });
      logUserEvent('Signup Failed', details: 'Code: ${e.code}, Message: ${e.message}');
    } catch (e) {
      setState(() {
        _error = "An unexpected error occurred. Please try again.";
      });
      logUserEvent('Signup Failed', details: 'Unexpected error: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7), Color(0xFF91EAE4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Hero(
                  tag: 'past_paper_icon',
                  child: CircleAvatar(
                    radius: 54,
                    backgroundColor: Colors.deepPurple.withOpacity(0.18),
                    child: Image.asset('assets/logo.jpg', width: 70, height: 70),
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  elevation: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  color: Colors.white,
                  shadowColor: Colors.deepPurple.withOpacity(0.12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Create Your Account',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Divider(
                            color: Colors.blue.shade100,
                            thickness: 1.2,
                            height: 28,
                          ),
                          TextFormField(
                            controller: _email,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                logUserEvent('Signup Validation Failed', details: 'Email empty');
                                return 'Please enter your email address';
                              }
                              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                                logUserEvent('Signup Validation Failed', details: 'Invalid email format');
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _password,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                  logUserEvent('Signup Password Visibility Toggled', details: _obscurePassword ? 'Hidden' : 'Visible');
                                },
                              ),
                            ),
                            obscureText: _obscurePassword,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                logUserEvent('Signup Validation Failed', details: 'Password empty');
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                logUserEvent('Signup Validation Failed', details: 'Password too short');
                                return 'Password must be at least 6 characters long';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: AnimatedOpacity(
                                opacity: _error != null ? 1 : 0,
                                duration: const Duration(milliseconds: 300),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (_info != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: AnimatedOpacity(
                                opacity: _info != null ? 1 : 0,
                                duration: const Duration(milliseconds: 300),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _info!,
                                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                elevation: 5,
                                shadowColor: Colors.deepPurpleAccent,
                              ),
                              onPressed: _loading
                                  ? null
                                  : () {
                                      if (_formKey.currentState!.validate()) {
                                        _signUp();
                                      }
                                    },
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Sign Up'),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () {
                                    logUserEvent('Navigate to Login from Signup');
                                    Navigator.pop(context);
                                   },
                            child: Text(
                              "Already have an account? Login",
                              style: TextStyle(
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Add ForgotPasswordScreen
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;
  String? _message;
  String? _error;

  Future<void> _sendResetEmail() async {
    setState(() {
      _loading = true;
      _message = null;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailController.text.trim());
      setState(() {
        _message = "A password reset email has been sent. Please check your inbox (and spam folder).";
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.code == 'user-not-found'
            ? "No user found for this email."
            : "Failed to send reset email: ${e.message}";
      });
    } catch (e) {
      setState(() {
        _error = "An unexpected error occurred. Please try again.";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Forgot Password"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7), Color(0xFF91EAE4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Card(
              elevation: 12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Reset Your Password",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email address';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: AnimatedOpacity(
                            opacity: _error != null ? 1 : 0,
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (_message != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: AnimatedOpacity(
                            opacity: _message != null ? 1 : 0,
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _message!,
                                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            elevation: 5,
                          ),
                          onPressed: _loading
                              ? null
                              : () {
                                  if (_formKey.currentState!.validate()) {
                                    _sendResetEmail();
                                  }
                                },
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Send Reset Email'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () {
                                Navigator.pop(context);
                              },
                        child: const Text(
                          "Back to Login",
                          style: TextStyle(
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
