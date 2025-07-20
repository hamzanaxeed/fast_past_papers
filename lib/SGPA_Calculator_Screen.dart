import 'package:flutter/material.dart';

class SgpaCalculatorScreen extends StatefulWidget {
  const SgpaCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<SgpaCalculatorScreen> createState() => _SgpaCalculatorScreenState();
}

class _SgpaCalculatorScreenState extends State<SgpaCalculatorScreen> with SingleTickerProviderStateMixin {
  final List<Subject> _subjects = [Subject(name: '', grade: 'A', credits: 3)];

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
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addSubject() {
    setState(() {
      _subjects.add(Subject(name: '', grade: 'A', credits: 3));
    });
  }

  void _removeSubject(int index) {
    if (_subjects.length > 1) {
      setState(() {
        _subjects.removeAt(index);
      });
    }
  }

  void _calculateSGPA() {
    double totalGradePoints = 0;
    int totalCredits = 0;

    for (var subject in _subjects) {
      final gp = gradePoints[subject.grade] ?? 0;
      totalGradePoints += gp * subject.credits;
      totalCredits += subject.credits;
    }

    setState(() {
      sgpa = totalCredits > 0 ? totalGradePoints / totalCredits : 0;
      _controller.forward(from: 0);
    });
  }

  int get totalCredits => _subjects.fold(0, (sum, subj) => sum + subj.credits);
  int get totalSubjects => _subjects.length;

  Widget _buildSubjectTile(int index) {
    final subject = _subjects[index];

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
                    initialValue: subject.name,
                    decoration: InputDecoration(
                      labelText: 'Subject Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      prefixIcon: const Icon(Icons.edit, color: Colors.deepPurple),
                    ),
                    onChanged: (value) {
                      subject.name = value;
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
                    value: subject.grade,
                    decoration: InputDecoration(
                      labelText: 'Grade',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      prefixIcon: const Icon(Icons.grade, color: Colors.deepPurple),
                    ),
                    items: gradePoints.keys.map((String grade) {
                      return DropdownMenuItem<String>(
                        value: grade,
                        child: Text(grade),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        subject.grade = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: subject.credits.toString(),
                    decoration: InputDecoration(
                      labelText: 'Credits',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      prefixIcon: const Icon(Icons.numbers, color: Colors.deepPurple),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      subject.credits = int.tryParse(value) ?? 0;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      // Move "Calculate SGPA" to floatingActionButton and "Add Subject" as a regular button
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
      ),
      body: Stack(
        children: [
          // Gradient background that covers the whole screen
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
          SafeArea(
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
                  // Improved "Add Subject" button with full width and better style
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
        ],
      ),
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
