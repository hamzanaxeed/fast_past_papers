import 'package:fast_past_papers/CGPA_Calculator_Screen.dart';
import 'package:flutter/material.dart';
import 'welcome_Screen.dart';
import 'SGPA_Calculator_Screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'feedback.dart';
import 'target_CGPA_Calculator.dart';

class OptionsScreen extends StatelessWidget {
  const OptionsScreen({Key? key}) : super(key: key);

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color color = Colors.deepPurple,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 32),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            label,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onPressed,
      ),
    );
  }

  // Add 3-dot menu for feedback/logout
  Widget _buildPopupMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) async {
        if (value == 'feedback') {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null || user.isAnonymous) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('You must be signed in to do this action'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            return;
          }
          showAdminFeedbackScreen(context);
        } else if (value == 'logout') {
          await FirebaseAuth.instance.signOut();
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'feedback',
          child: Row(
            children: const [
              Icon(Icons.feedback_outlined, color: Color(0xFF1976D2)),
              SizedBox(width: 10),
              Text('Feedback'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: const [
              Icon(Icons.logout, color: Color(0xFF1976D2)),
              SizedBox(width: 10),
              Text('Logout'),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient background that covers the whole screen, including behind the app bar
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7), Color(0xFF91EAE4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Choose an Option'),
            centerTitle: true,
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            elevation: 4,
            actions: [
              _buildPopupMenu(context),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Header

                    SizedBox(height: 50,),
                    const SizedBox(height: 40),
                    _buildOptionButton(
                      icon: Icons.book,
                      label: 'See Subjects',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const past_Papers_Screen()),
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                    _buildOptionButton(
                      icon: Icons.calculate,
                      label: 'Calculate SGPA',
                      color: Colors.green,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SgpaCalculatorScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildOptionButton(
                      icon: Icons.calculate_outlined,
                      label: 'Calculate CGPA',
                      color: Colors.blue,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CgpaCalculatorScreen()),
                        );

                    },
                  ),
                  const SizedBox(height: 24),
                    _buildOptionButton(
                      icon: Icons.flag,
                      label: 'Target CGPA Calculator',
                      color: Colors.purple,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TargetCgpaCalculatorScreen()),
                        );
                      },
                    ),

                  const SizedBox(height: 24),
                    _buildOptionButton(
                      icon: Icons.schedule,
                      label: 'See Time Table',
                      color: Colors.orange,
                      onPressed: () {
                        // Show SnackBar on click
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Thora sabar krle bhai'),
                            backgroundColor: Colors.deepPurple,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
        )
      ],
    );
  }
}
