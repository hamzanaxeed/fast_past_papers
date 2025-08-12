import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'log.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  Future<void> _launchEmail(BuildContext context) async {
    await logUserEvent('Clicked Email', details: 'contact us screen');
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
    await logUserEvent('Clicked LinkedIn', details: 'contact us screen');
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
        title: const Text("Contact Us"),
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
              "📘 Fast Past Papers",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "📚 Fast Past Papers\n"
                  "A smart and organized app that contains all past paper questions arranged topic-wise, removing the hassle of searching through entire papers.\n\n"
                  "🗂 Organized by Year\n"
                  "Questions are sorted in descending order by year, making it easier to focus on recent content first.\n\n"
                  "📥 Offline Access\n"
                  "You can download past papers for offline use for easy access anytime.\n\n"
                  "🗓 Timetable Feature\n"
                  "View your timetable directly in the app and download it for offline reference.\n\n"
                  "📊 CGPA/SGPA Calculator\n"
                  "Easily calculate your CGPA/SGPA and set a target CGPA/SGPA to help you plan your studies more effectively.\n\n"
                  "💬 Feedback & Contributions\n"
                  "If you want to contribute or have any queries, you can easily send feedback from within the app.\n\n"
                  "👤 Account Features\n"
                  "By creating an account, you can contribute solutions, add questions, or submit feedback. Guest users can view content but cannot contribute or send feedback.\n\n"
                  "📝 Become an Editor\n"
                  "If you're interested, you can also apply to become an editor and help manage or verify content.\n",
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 10),
            SelectableText.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: "For any queries, contact us via email at ",
                    style: TextStyle(fontSize: 16, height: 1.5, color: Colors.black),
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: GestureDetector(
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
                  ),
                  const TextSpan(
                    text: ".\n",
                    style: TextStyle(fontSize: 16, height: 1.5, color: Colors.black),
                  ),
                  const TextSpan(
                    text: "LinkedIn: ",
                    style: TextStyle(fontSize: 16, height: 1.5, color: Colors.black),
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: GestureDetector(
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
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
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

