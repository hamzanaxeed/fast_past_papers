import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'feedback.dart';
import 'message_File.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'options_Screen.dart';
import 'authentications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'contact_Us.dart';

class CgpaCalculatorScreen extends StatefulWidget {
  const CgpaCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<CgpaCalculatorScreen> createState() => _CgpaCalculatorScreenState();
}

class _CgpaCalculatorScreenState extends State<CgpaCalculatorScreen> with SingleTickerProviderStateMixin {
  final List<Semester> _semesters = [Semester(gpa: '')];
  final List<TextEditingController> _controllers = [TextEditingController()];
  double? cgpa;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _loadSavedSemesters();
    super.initState();
  }

  Future<void> _loadSavedSemesters() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('cgpa_semesters');
    setState(() {
      _semesters.clear();
      _controllers.clear();
      if (saved != null && saved.isNotEmpty) {
        for (var gpa in saved) {
          _semesters.add(Semester(gpa: gpa));
          _controllers.add(TextEditingController(text: gpa));
        }
      } else {
        _semesters.add(Semester(gpa: ''));
        _controllers.add(TextEditingController());
      }
    });
  }

  Future<void> _saveSemesters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('cgpa_semesters', _semesters.map((s) => s.gpa).toList());
  }

  void _addSemester() {
    setState(() {
      _semesters.add(Semester(gpa: ''));
      _controllers.add(TextEditingController());
    });
    _saveSemesters();
  }

  void _removeSemester(int index) {
    if (_semesters.length > 1) {
      setState(() {
        _semesters.removeAt(index);
        _controllers.removeAt(index);
      });
      _saveSemesters();
    }
  }

  void _calculateCGPA() async {
    double totalGpa = 0;
    int count = 0;
    bool hasError = false;

    for (int i = 0; i < _semesters.length; i++) {
      final value = _controllers[i].text;
      final gpa = double.tryParse(value);
      if (gpa == null || gpa < 0 || gpa > 4) {
        hasError = true;
        break;
      }
      _semesters[i].gpa = value;
      totalGpa += gpa;
      count++;
    }

    if (hasError || count == 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter valid GPA values (0.0 - 4.0) for all semesters.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() {
        cgpa = null;
      });
      return;
    }

    setState(() {
      cgpa = totalGpa / count;
      _controller.forward(from: 0);
    });
    await _saveSemesters();
  }

  int get totalSemesters => _semesters.length;

  Widget _buildSemesterTile(int index) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.deepPurple.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blue.shade200,
              child: Text(
                "${index + 1}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: _controllers[index],
                decoration: InputDecoration(
                  labelText: 'GPA',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  errorStyle: const TextStyle(color: Colors.red),
                ),
                style: const TextStyle(fontSize: 14),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                onChanged: (value) {
                  // Prevent negative input
                  if (value.startsWith('-')) return;
                  _semesters[index].gpa = value;
                  _saveSemesters();
                },
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  final numVal = double.tryParse(value);
                  if (numVal == null) return 'Enter a valid number';
                  if (numVal < 0) return 'No negative values';
                  if (numVal > 4) return 'Max GPA is 4.0';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 6),
            if (_semesters.length > 1)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => _removeSemester(index),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline, color: Colors.red, size: 22),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [Colors.blue, Colors.deepPurple]),
          ),
          padding: const EdgeInsets.all(6),
          child: const Icon(Icons.school, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 12),
        const Text(
          "CGPA Calculator",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
            shadows: [Shadow(color: Colors.white54, blurRadius: 8, offset: Offset(1, 2))],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      color: Colors.blue.shade50,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
        child: Text(
          "Semesters: $totalSemesters",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildCGPAResult() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: cgpa != null
              ? Card(
            elevation: 10,
            color: Colors.green.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
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
                      "🎓 Your CGPA: ${cgpa!.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        shadows: [Shadow(color: Colors.black12, blurRadius: 8, offset: Offset(1, 2))],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
              : const SizedBox.shrink(),
        );
      },
    );
  }

  // Add 3-dot menu for feedback/logout and manage messages for admin
  Widget _buildPopupMenu(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
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
            } else if (value == 'editors') {
              // Navigate to manage editors screen
            } else if (value == 'logs') {
              // Navigate to view logs screen
            } else if (value == 'contact_us') {
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
              value: 'contact_us',
              child: Row(
                children: const [
                  Icon(Icons.contact_mail, color: Color(0xFF1976D2)),
                  SizedBox(width: 10),
                  Text('Contact Us'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _isAdmin(User? user) async {
    if (user == null || user.email == null) return false;
    final response = await supa.Supabase.instance.client
        .from('Admins')
        .select('admin_Email')
        .eq('admin_Email', user.email!.toLowerCase())
        .maybeSingle();
    return response != null;
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
          floatingActionButton: ElevatedButton.icon(
            onPressed: _calculateCGPA,
            icon: const Icon(Icons.calculate),
            label: const Text("Calculate CGPA"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 6,
            ),
          ),
          appBar: AppBar(
            title: const Text("CGPA Calculator"),
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
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 18),
                  _buildSummaryCard(),
                  const SizedBox(height: 18),
                  ...List.generate(_semesters.length, _buildSemesterTile),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addSemester,
                      icon: const Icon(Icons.add_circle_outline, size: 28),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          "Add Semester",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 8,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildCGPAResult(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class Semester {
  String gpa;

  Semester({required this.gpa});
}
