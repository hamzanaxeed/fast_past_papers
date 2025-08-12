import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'feedback.dart';
import 'message_File.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'options_Screen.dart';
import 'authentications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'contact_Us.dart';

class SgpaCalculatorScreen extends StatefulWidget {
  const SgpaCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<SgpaCalculatorScreen> createState() => _SgpaCalculatorScreenState();
}

class _SgpaCalculatorScreenState extends State<SgpaCalculatorScreen> with SingleTickerProviderStateMixin {
  final List<Subject> _subjects = [Subject(name: '', grade: 'A', credits: 3)];
  final List<TextEditingController> _nameControllers = [TextEditingController()];
  final List<TextEditingController> _creditControllers = [TextEditingController(text: '3')];
  final List<String> _gradeControllers = ['A'];

  final Map<String, double> gradePoints = {
    "A+": 4.00,
    "A": 4.00,
    "A-": 3.67,
    "B+": 3.33,
    "B": 3.00,
    "B-": 2.67,
    "C+": 2.33,
    "C": 2.00,
    "C-": 1.67,
    "D+": 1.33,
    "D": 1.00,
  };

  double? sgpa;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _loadSavedSubjects();
    super.initState();
  }

  Future<void> _loadSavedSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    final names = prefs.getStringList('sgpa_names');
    final grades = prefs.getStringList('sgpa_grades');
    final credits = prefs.getStringList('sgpa_credits');
    setState(() {
      _subjects.clear();
      _nameControllers.clear();
      _creditControllers.clear();
      _gradeControllers.clear();
      if (names != null && grades != null && credits != null &&
          names.length == grades.length && grades.length == credits.length && names.isNotEmpty) {
        for (int i = 0; i < names.length; i++) {
          _subjects.add(Subject(
            name: names[i],
            grade: grades[i],
            credits: int.tryParse(credits[i]) ?? 0,
          ));
          _nameControllers.add(TextEditingController(text: names[i]));
          _creditControllers.add(TextEditingController(text: credits[i]));
          _gradeControllers.add(grades[i]);
        }
      } else {
        _subjects.add(Subject(name: '', grade: 'A', credits: 3));
        _nameControllers.add(TextEditingController());
        _creditControllers.add(TextEditingController(text: '3'));
        _gradeControllers.add('A');
      }
    });
  }

  Future<void> _saveSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('sgpa_names', _subjects.map((s) => s.name).toList());
    await prefs.setStringList('sgpa_grades', _subjects.map((s) => s.grade).toList());
    await prefs.setStringList('sgpa_credits', _subjects.map((s) => s.credits.toString()).toList());
  }

  void _addSubject() {
    setState(() {
      _subjects.add(Subject(name: '', grade: 'A', credits: 3));
      _nameControllers.add(TextEditingController());
      _creditControllers.add(TextEditingController(text: '3'));
      _gradeControllers.add('A');
    });
    _saveSubjects();
  }

  void _removeSubject(int index) {
    if (_subjects.length > 1) {
      setState(() {
        _subjects.removeAt(index);
        _nameControllers.removeAt(index);
        _creditControllers.removeAt(index);
        _gradeControllers.removeAt(index);
      });
      _saveSubjects();
    }
  }

  void _calculateSGPA() async {
    double totalGradePoints = 0;
    int totalCredits = 0;
    bool hasError = false;

    for (int i = 0; i < _subjects.length; i++) {
      final name = _nameControllers[i].text;
      final grade = _gradeControllers[i];
      final credits = int.tryParse(_creditControllers[i].text) ?? 0;
      final gp = gradePoints[grade];
      if (gp == null || credits <= 0) {
        hasError = true;
        break;
      }
      _subjects[i].name = name;
      _subjects[i].grade = grade;
      _subjects[i].credits = credits;
      totalGradePoints += gp * credits;
      totalCredits += credits;
    }

    if (hasError || totalCredits == 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter valid grades and credits for all subjects.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() {
        sgpa = null;
      });
      return;
    }

    setState(() {
      sgpa = totalGradePoints / totalCredits;
      _controller.forward(from: 0);
    });
    await _saveSubjects();
  }

  int get totalCredits => _subjects.fold(0, (sum, subj) => sum + subj.credits);
  int get totalSubjects => _subjects.length;

  Widget _buildSubjectTile(int index) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.deepPurple.shade100,
                  child: Text(
                    "${index + 1}",
                    style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _nameControllers[index],
                    decoration: InputDecoration(
                      labelText: 'Subject Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      prefixIcon: const Icon(Icons.edit, color: Colors.deepPurple),
                      errorStyle: const TextStyle(color: Colors.red),
                    ),
                    onChanged: (value) {
                      _subjects[index].name = value;
                      _saveSubjects();
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      if (value.trim().isEmpty) return 'Enter subject name';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                if (_subjects.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeSubject(index),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _gradeControllers[index],
                    decoration: InputDecoration(
                      labelText: 'Grade',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      prefixIcon: const Icon(Icons.grade, color: Colors.deepPurple),
                      errorStyle: const TextStyle(color: Colors.red),
                    ),
                    items: gradePoints.keys.map((String grade) {
                      return DropdownMenuItem<String>(
                        value: grade,
                        child: Text(grade),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _gradeControllers[index] = value!;
                        _subjects[index].grade = value;
                        _saveSubjects();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _creditControllers[index],
                    decoration: InputDecoration(
                      labelText: 'Credits',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      prefixIcon: const Icon(Icons.numbers, color: Colors.deepPurple),
                      errorStyle: const TextStyle(color: Colors.red),
                    ),
                    keyboardType: TextInputType.number,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    onChanged: (value) {
                      if (value.startsWith('-')) return;
                      _subjects[index].credits = int.tryParse(value) ?? 0;
                      _saveSubjects();
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      final numVal = int.tryParse(value);
                      if (numVal == null) return 'Enter a valid number';
                      if (numVal < 0) return 'No negative values';
                      if (numVal == 0) return 'Credits required';
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
            onPressed: _calculateSGPA,
            icon: const Icon(Icons.calculate),
            label: const Text("Calculate SGPA"),
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
            title: const Text("SGPA Calculator"),
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
                  ...List.generate(_subjects.length, _buildSubjectTile),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addSubject,
                      icon: const Icon(Icons.add_circle_outline, size: 28),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          "Add Subject",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
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
                  _buildSGPAResult(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Colors.deepPurple, Colors.blueAccent]),
          ),
          padding: const EdgeInsets.all(6),
          child: const Icon(Icons.school, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 12),
        const Text(
          "SGPA Calculator",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
            shadows: [Shadow(color: Colors.white54, blurRadius: 8, offset: Offset(1, 2))],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      color: Colors.deepPurple.shade50,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
        child: Row(
          children: [
            const Icon(Icons.list_alt, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Text("Subjects: $totalSubjects", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 18),
            const Icon(Icons.numbers, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Text("Total Credits: $totalCredits", style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSGPAResult() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: sgpa != null
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
                      "🎓 Your SGPA: ${sgpa!.toStringAsFixed(2)}",
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
}

class Subject {
  String name;
  String grade;
  int credits;

  Subject({required this.name, required this.grade, required this.credits});
}
