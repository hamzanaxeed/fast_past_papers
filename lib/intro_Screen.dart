import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fast_past_papers/main.dart';

class into_Screen extends StatefulWidget {
  const into_Screen({super.key});

  @override
  State<into_Screen> createState() => _into_ScreenState();
}

class _into_ScreenState extends State<into_Screen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF9),
      appBar: AppBar(
        title: const Text("About Fast Past Papers"),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "📘 Fast Past Papers",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Fast Past Papers is a smart and organized app that contains all past paper questions arranged topic-wise, removing the hassle of searching through entire papers.\n\n"
                  "Questions are sorted in descending order by year, making it easier to focus on recent content first.\n\n"
                  "You can download past papers for offline use for easy access anytime.\n\n"
                  "If you want to contribute or have any queries, you can easily send feedback from within the app.\n\n"
                  "By creating an account, you can contribute solutions, add questions, or submit feedback. Guest users can view content but cannot contribute or send feedback.\n\n"
                  "If you're interested, you can also apply to become an editor and help manage or verify content.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            buildCard(
              title: "Developer",
              children: const [
                Text(
                  "Hamza Naveed    (L23-0618)",
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 20),
            buildCard(
              title: "Contributors",
              children: const [
                Text(
                  "• Ayesha Noor (L23-0549)\n"
                      "• Hamza Azam (L23-0945)\n"
                      "• Aliha Wasif (Unknown)",
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('hasSeenIntro', true);

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const MyApp()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                child: const Text("Continue to Login"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1976D2),
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
