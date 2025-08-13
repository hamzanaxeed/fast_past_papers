import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fire;
import 'feedback.dart';
import 'message_File.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'options_Screen.dart';
import 'authentications.dart';
import 'editor_Handling.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'contact_Us.dart';

class TargetCgpaCalculatorScreen extends StatefulWidget {
  const TargetCgpaCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<TargetCgpaCalculatorScreen> createState() => _TargetCgpaCalculatorScreenState();
}

class _TargetCgpaCalculatorScreenState extends State<TargetCgpaCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _attemptedCreditsController = TextEditingController();
  final _currentCgpaController = TextEditingController();
  final _currentCreditsController = TextEditingController();
  final _finalCgpaController = TextEditingController();

  double? _requiredSgpa;

  void _calculateRequiredSgpa() {
    final attemptedCredits = double.tryParse(_attemptedCreditsController.text) ?? 0;
    final currentCgpa = double.tryParse(_currentCgpaController.text) ?? 0;
    final currentCredits = double.tryParse(_currentCreditsController.text) ?? 0;
    final finalCgpa = double.tryParse(_finalCgpaController.text) ?? 0;

    if (attemptedCredits <= 0 || currentCredits <= 0) {
      setState(() => _requiredSgpa = null);
      return;
    }

    final totalPoints = attemptedCredits * currentCgpa;
    final totalCredits = attemptedCredits + currentCredits;
    final requiredTotalPoints = finalCgpa * totalCredits;
    final requiredSgpa = (requiredTotalPoints - totalPoints) / currentCredits;

    setState(() {
      _requiredSgpa = requiredSgpa.isFinite ? requiredSgpa : null;
    });
  }

  // 3-dot menu for feedback/logout and manage messages for admin
  Widget _buildPopupMenu(BuildContext context) {
    final user = fire.FirebaseAuth.instance.currentUser;
    return FutureBuilder<bool>(
      future: _isAdmin(user),
      builder: (context, snapshot) {
        final isAdmin = snapshot.data ?? false;
        return PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onSelected: (value) async {
            if (value == 'feedback') {
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
              await showFeedbackOrAdminScreen(context);
            } else if (value == 'logout') {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const EmailAuthScreen()),
                    (route) => false,
              );
            } else if (value == 'manage_messages') {
              showManageMessagesDialog(context);
            } else if (value == 'about_us') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContactUsScreen()),
              );
            }
          },
          itemBuilder: (context) => [
            if (isAdmin)
              PopupMenuItem(
                value: 'editors',
                child: Row(
                  children: const [
                    Icon(Icons.manage_accounts, color: Color(0xFF1976D2)),
                    SizedBox(width: 10),
                    Text('Manage Editors'),
                  ],
                ),
              ),
            if (isAdmin)
              PopupMenuItem(
                value: 'logs',
                child: Row(
                  children: const [
                    Icon(Icons.list_alt, color: Color(0xFF1976D2)),
                    SizedBox(width: 10),
                    Text('View Logs'),
                  ],
                ),
              ),
            if (isAdmin)
              PopupMenuItem(
                value: 'manage_messages',
                child: Row(
                  children: const [
                    Icon(Icons.message, color: Color(0xFF1976D2)),
                    SizedBox(width: 10),
                    Text('Manage Messages'),
                  ],
                ),
              ),
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
            PopupMenuItem(
              value: 'about_us',
              child: Row(
                children: const [
                  Icon(Icons.contact_mail, color: Color(0xFF1976D2)),
                  SizedBox(width: 10),
                  Text('About Us'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _isAdmin(fire.User? user) async {
    if (user == null || user.email == null) return false;
    final response = await supa.Supabase.instance.client
        .from('Admins')
        .select('admin_Email')
        .eq('admin_Email', user.email!.toLowerCase())
        .maybeSingle();
    return response != null;
  }

  @override
  void dispose() {
    _attemptedCreditsController.dispose();
    _currentCgpaController.dispose();
    _currentCreditsController.dispose();
    _finalCgpaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient background for consistency
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
            title: const Text('Target CGPA Calculator'),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.white,
            actions: [
              _buildPopupMenu(context),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [Colors.purple, Colors.deepPurple]),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: const Icon(Icons.flag, color: Colors.white, size: 32),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Target CGPA Calculator",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                              shadows: [Shadow(color: Colors.white54, blurRadius: 8, offset: Offset(1, 2))],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                    Card(
                      color: Colors.purple.shade50,
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
                        child: const Text(
                          "Calculate the SGPA you need in your current semester to reach your target CGPA.",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _attemptedCreditsController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Attempted Credit Hours',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.numbers, color: Colors.purple),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter attempted credit hours';
                        final numVal = double.tryParse(v);
                        if (numVal == null) return 'Enter a valid number';
                        if (numVal < 0) return 'No negative values';
                        return null;
                      },
                      onChanged: (v) {
                        if (v.startsWith('-')) {
                          _attemptedCreditsController.text = v.replaceFirst('-', '');
                          _attemptedCreditsController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _attemptedCreditsController.text.length),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _currentCgpaController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Current CGPA',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.school, color: Colors.purple),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter current CGPA';
                        final numVal = double.tryParse(v);
                        if (numVal == null) return 'Enter a valid number';
                        if (numVal < 0) return 'No negative values';
                        if (numVal > 4) return 'Max CGPA is 4.0';
                        return null;
                      },
                      onChanged: (v) {
                        if (v.startsWith('-')) {
                          _currentCgpaController.text = v.replaceFirst('-', '');
                          _currentCgpaController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _currentCgpaController.text.length),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _currentCreditsController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Current Semester Credit Hours',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.numbers, color: Colors.purple),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter current semester credit hours';
                        final numVal = double.tryParse(v);
                        if (numVal == null) return 'Enter a valid number';
                        if (numVal < 0) return 'No negative values';
                        return null;
                      },
                      onChanged: (v) {
                        if (v.startsWith('-')) {
                          _currentCreditsController.text = v.replaceFirst('-', '');
                          _currentCreditsController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _currentCreditsController.text.length),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _finalCgpaController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Target (Final) CGPA',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.flag, color: Colors.purple),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter target CGPA';
                        final numVal = double.tryParse(v);
                        if (numVal == null) return 'Enter a valid number';
                        if (numVal < 0) return 'No negative values';
                        if (numVal > 4) return 'Max CGPA is 4.0';
                        return null;
                      },
                      onChanged: (v) {
                        if (v.startsWith('-')) {
                          _finalCgpaController.text = v.replaceFirst('-', '');
                          _finalCgpaController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _finalCgpaController.text.length),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.flag),
                        label: const Text('Calculate Required SGPA'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 6,
                        ),
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            _calculateRequiredSgpa();
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_requiredSgpa != null)
                      Card(
                        color: Colors.green.shade50,
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
                          child: Row(
                            children: [
                              Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(colors: [Colors.green, Colors.lightGreenAccent]),
                                ),
                                padding: const EdgeInsets.all(8),
                                child: const Icon(Icons.emoji_events, color: Colors.white, size: 36),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Text(
                                  "Required SGPA: ${_requiredSgpa!.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_requiredSgpa != null && (_requiredSgpa! > 4.0 || _requiredSgpa! < 0))
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          "Note: The required SGPA is out of the possible range. Please check your inputs.",
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
