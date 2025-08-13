import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'log.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  Future<void> _launchEmail(BuildContext context) async {
    await logUserEvent('Clicked Email', details: 'About us screen');
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'l230618@lhr.nu.edu.pk',
      query: Uri.encodeFull('subject=Fast Past Papers Query'),
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri, mode: LaunchMode.externalApplication);
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Email'),
          content: const Text(
            'Could not open your email app. Please copy the email address and send your query manually.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Clipboard.setData(const ClipboardData(text: 'l230618@lhr.nu.edu.pk'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email address copied to clipboard.')),
                );
              },
              child: const Text('Copy Email'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _launchLinkedIn(BuildContext context) async {
    await logUserEvent('Clicked LinkedIn', details: 'About us screen');
    const url = 'https://www.linkedin.com/in/hamza-naveed-3aa01b289?lipi=urn%3Ali%3Apage%3Ad_flagship3_profile_view_base_contact_details%3BshURbEmgS%2BylqPOif7kdjQ%3D%3D';
    final uri = Uri.parse(url);

    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {}
    if (!launched) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
    if (!launched) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('LinkedIn'),
          content: const Text(
            'Could not open LinkedIn. Please copy the link and open it manually in your browser.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Clipboard.setData(const ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('LinkedIn URL copied to clipboard.')),
                );
              },
              child: const Text('Copy Link'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("About Us"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "📌 Fast Past Papers – About Us",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 18),
            _sectionTitle("Who We Are"),
            const Text(
              "Fast Past Papers is built for students. We understand the struggle of digging through dozens of past papers just to find the right question — so we decided to make it simple, fast, and smart.",
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 18),
            _sectionTitle("Our Mission"),
            const Text(
              "We aim to make exam preparation stress-free by providing:\n\n"
              "• Topic-wise organized past paper questions 📚\n"
              "• Recent-to-old sorting so you can focus on the latest trends 📅\n"
              "• Offline access to your downloaded papers and timetable 📥",
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 18),
            _sectionTitle("Why We Built This App"),
            const Text(
              "Studying should be efficient, not exhausting. With built-in CGPA/SGPA calculators, timetable downloads, and the ability to contribute questions, we give you all the tools you need in one place.",
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 18),
            _sectionTitle("Get Involved"),
            const Text(
              "We welcome contributions from students . You can:\n\n"
              "• Add questions or solutions ✏️\n"
              "• Share feedback 💬\n"
              "• Apply to become an editor to help maintain quality content",
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 18),
            _sectionTitle("Contact Us"),
            const SizedBox(height: 8),

            Text(
              "Have questions, suggestions ? Reach out to us!",
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text("📧 Email: ", style: TextStyle(fontSize: 16)),
                GestureDetector(
                  onTap: () => _launchEmail(context),
                  child: Text(
                    "l230618@lhr.nu.edu.pk",
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                const Text("🔗 LinkedIn: ", style: TextStyle(fontSize: 16)),
                GestureDetector(
                  onTap: () => _launchLinkedIn(context),
                  child: Text(
                    "Hamza Naveed",
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildCard(
              title: "Developer",
              children: const [
                Text(
                  "Hamza Naveed    (L23-0618)",
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildCard(
              title: "Contributors",
              children: const [
                Text(
                  "• Ayesha Noor      (L23-0549)\n"
                  "• Hamza Azam     (L23-0945)\n"
                  "• Aliha Wasif         (L23-0921)\n"
                  "• Maham Gull        (L23-0736)\n",
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.bold,
        color: Colors.deepPurple,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Colors.deepPurpleAccent,
            blurRadius: 12,
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
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
