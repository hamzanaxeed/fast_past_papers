import 'package:fast_past_papers/CGPA_Calculator_Screen.dart';
import 'package:flutter/material.dart';
import 'welcome_Screen.dart';
import 'SGPA_Calculator_Screen.dart';

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
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Colors.deepPurple, Colors.blueAccent],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurple.withOpacity(0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(10),
                          child: const Icon(Icons.dashboard, color: Colors.white, size: 38),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          "Options",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                            shadows: [Shadow(color: Colors.white54, blurRadius: 8, offset: Offset(1, 2))],
                          ),
                        ),
                      ],
                    ),
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
                    icon: Icons.schedule,
                    label: 'See Time Table',
                    color: Colors.orange,
                    onPressed: () {
                      // TODO: Implement Time Table screen
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

