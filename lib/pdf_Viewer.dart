import 'package:flutter/material.dart';
import 'other_Viewers.dart';

class PdfViewerScreen extends StatelessWidget {
  final String url;
  final String name;

  const PdfViewerScreen({Key? key, required this.url, required this.name}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Directly use OtherViewer for PDF preview
    return OtherViewer(url: url, name: name);
  }
}
