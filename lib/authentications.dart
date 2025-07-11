
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'welcome_Screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // <-- Add this import
import 'log.dart'; // <-- Add this import if not present

class EmailAuthScreen extends StatelessWidget {
  const EmailAuthScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

                CircleAvatar(
                    radius: 54,
              //      backgroundColor: Color(0xFF1976D2).withOpacity(0.18),
                    child: Image.asset('assets/logo.jpg', width: 70, height: 70),
                  ),
                const SizedBox(height: 18),
                Card(
                  elevation: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  color: Colors.white.withOpacity(0.98),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Everything you need fastians',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1976D2),
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),

                        const SizedBox(height: 8),
                        Divider(
                          color: Colors.blue.shade100,
                          thickness: 1.2,
                          height: 28,
                        ),
                        _LoginForm(),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text("or", style: TextStyle(color: Colors.grey[600])),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _SocialLoginButtons(),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EmailSignUpScreen(),
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
        // Log failed login due to unverified email
        logUserEvent('Login Failed', details: 'Email not verified');
        return;
      }

      // Always refresh editor/admin info before navigating
      await WelcomeScreen.fetchEditorEmailsStatic();

      // Determine role for message
      String? email = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
      String message = "Logged in as user";
      if (email == adminEmail) {
        message = "Logged in as admin";
        logUserEvent('Admin Login', details: email);
      } else {
        // Fetch editor emails from Supabase
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
            builder: (_) => const WelcomeScreen(),
          ),
        );

        // Show role message after navigation
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
      // Log failed login with error code
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
          TextFormField(
            controller: _email,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              labelStyle: const TextStyle(color: Colors.black87),
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
          const SizedBox(height: 14),
          TextFormField(
            controller: _password,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
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
                },
              ),
            ),
            obscureText: _obscurePassword,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters long';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor: const Color(0xFF46C2CB),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                elevation: 2,
              ),
              onPressed: _loading
                  ? null
                  : () {
                      if (_formKey.currentState!.validate()) {
                        _signInWithEmail();
                      }
                    },
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Login'),
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

      // Always refresh editor/admin info before navigating
      await WelcomeScreen.fetchEditorEmailsStatic();

      // Determine role for message
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
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
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
      await FirebaseAuth.instance.signInAnonymously();
      // Always refresh editor/admin info before navigating
      await WelcomeScreen.fetchEditorEmailsStatic();

      logUserEvent('Guest Login');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
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
            icon: const Icon(Icons.account_circle, size: 18),
            label: const Text('Google'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              elevation: 2,
            ),
            onPressed: _loading ? null : _signInWithGoogle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.person_outline, size: 18),
            label: const Text('Guest'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              backgroundColor: const Color(0xFF46C2CB),
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              elevation: 2,
            ),
            onPressed: _loading ? null : _signInAnonymously,
          ),
        ),
      ],
    );
  }
}

// --- Sign Up Screen (in the same file) ---
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8F8FF), Color(0xFFE3F2FD)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
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
                  elevation: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  color: Colors.white,
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
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
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
                                borderRadius: BorderRadius.circular(10),
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
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _password,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
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
                                },
                              ),
                            ),
                            obscureText: _obscurePassword,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters long';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          if (_info != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                _info!,
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
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
                              child: _loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Sign Up'),
                            ),
                          ),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () {
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
