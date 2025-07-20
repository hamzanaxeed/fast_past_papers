import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'welcome_Screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'log.dart';

class EmailAuthScreen extends StatelessWidget {
  const EmailAuthScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF9),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFF7FAF9)],
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
                    backgroundColor: Colors.blue.withOpacity(0.18),
                    child: Image.asset('assets/logo.jpg', width: 70, height: 70),
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  elevation: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  color: Colors.white,
                  shadowColor: Colors.blue.withOpacity(0.12),
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
                            color: Color(0xFF1976D2),
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
                              color: Color(0xFF1976D2),
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

  static const String adminEmail = 'l230618@lhr.nu.edu.pk';

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
        logUserEvent('Login Failed', details: 'Email not verified');
        return;
      }

      await past_Papers_Screen.fetchEditorEmailsStatic();

      String? email = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
      String message = "Logged in as user";
      if (email == adminEmail) {
        message = "Logged in as admin";
        logUserEvent('Admin Login', details: email);
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
            logUserEvent('Editor Login', details: email);
          } else {
            logUserEvent('User Login', details: email);
          }
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const past_Papers_Screen(),
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
      logUserEvent('Login Failed', details: 'Code: ${e.code}, Message: ${e.message}');
    } catch (e) {
      setState(() {
        _error = "An unexpected error occurred. Please try again.";
      });
      logUserEvent('Login Failed', details: 'Unexpected error: $e');
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
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: const Color(0xFF46C2CB),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                elevation: 3,
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

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);

    try {
      logUserEvent('Google Login Started');
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _loading = false);
        logUserEvent('Google Login Cancelled');
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      await past_Papers_Screen.fetchEditorEmailsStatic();

      String? email = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
      String message = "Logged in as user";
      if (email == _LoginFormState.adminEmail) {
        message = "Logged in as admin";
        logUserEvent('Admin Google Login', details: email);
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
            logUserEvent('Editor Google Login', details: email);
          } else {
            logUserEvent('User Google Login', details: email);
          }
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const past_Papers_Screen()),
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
      logUserEvent('Google Login Failed', details: 'Code: ${e.code}, Message: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Google sign-in failed. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      logUserEvent('Google Login Failed', details: 'Unexpected error: $e');
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
      await past_Papers_Screen.fetchEditorEmailsStatic();

      logUserEvent('Guest Login');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const past_Papers_Screen()),
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
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              elevation: 3,
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
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: const Color(0xFF46C2CB),
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              elevation: 3,
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
      backgroundColor: const Color(0xFFF7FAF9),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFF7FAF9)],
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
                    backgroundColor: Colors.blue.withOpacity(0.18),
                    child: Image.asset('assets/logo.jpg', width: 70, height: 70),
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  elevation: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  color: Colors.white,
                  shadowColor: Colors.blue.withOpacity(0.12),
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
                              color: Color(0xFF1976D2),
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
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                backgroundColor: Colors.teal.shade700,
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                elevation: 5,
                                shadowColor: Colors.tealAccent,
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
                                color: Colors.teal.shade700,
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
