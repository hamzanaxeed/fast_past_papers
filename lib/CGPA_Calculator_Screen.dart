import 'package:flutter/material.dart';

class CgpaCalculatorScreen extends StatefulWidget {
  const CgpaCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<CgpaCalculatorScreen> createState() => _CgpaCalculatorScreenState();
}

class _CgpaCalculatorScreenState extends State<CgpaCalculatorScreen> with SingleTickerProviderStateMixin {
  final List<Semester> _semesters = [Semester(gpa: '', credits: '')];

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
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addSemester() {
    setState(() {
      _semesters.add(Semester(gpa: '', credits: ''));
    });
  }

  void _removeSemester(int index) {
    if (_semesters.length > 1) {
      setState(() {
        _semesters.removeAt(index);
      });
    }
  }

  void _calculateCGPA() {
    double totalPoints = 0;
    double totalCredits = 0;

    for (var semester in _semesters) {
      final gpa = double.tryParse(semester.gpa) ?? 0;
      final credits = double.tryParse(semester.credits) ?? 0;
      totalPoints += gpa * credits;
      totalCredits += credits;
    }

    setState(() {
      cgpa = totalCredits > 0 ? totalPoints / totalCredits : 0;
      _controller.forward(from: 0);
    });
  }

  int get totalSemesters => _semesters.length;
  double get totalCredits => _semesters.fold(0, (sum, sem) => sum + (double.tryParse(sem.credits) ?? 0));

  Widget _buildSemesterTile(int index) {
    final semester = _semesters[index];

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
              flex: 3,
              child: TextFormField(
                initialValue: semester.gpa,
                decoration: InputDecoration(
                  labelText: 'GPA',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                ),
                style: const TextStyle(fontSize: 14),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  semester.gpa = value;
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextFormField(
                initialValue: semester.credits,
                decoration: InputDecoration(
                  labelText: 'Credits',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                ),
                style: const TextStyle(fontSize: 14),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  semester.credits = value;
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
          "Semesters: $totalSemesters | Total Credits : $totalCredits",
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
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
        ],
      ),
    );
  }
}

class Semester {
  String gpa;
  String credits;

  Semester({required this.gpa, required this.credits});
}
