import 'package:flutter/material.dart';
import 'other_Viewers.dart';

class PdfViewerScreen extends StatelessWidget {
  final String url;
  final String name;

  const PdfViewerScreen({Key? key, required this.url, required this.name}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator for a short moment before showing OtherViewer
    return FutureBuilder(
      future: Future.delayed(const Duration(milliseconds: 150)),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return OtherViewer(url: url, name: name);
      },
    );
  }
}
