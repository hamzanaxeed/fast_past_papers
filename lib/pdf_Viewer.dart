import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String name;

  const PdfViewerScreen({Key? key, required this.url, required this.name}) : super(key: key);

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  String? localPath;
  bool loading = true;
  String? error;
  int _totalPages = 0;
  int _currentPage = 0;
  PDFViewController? _pdfViewController;

  @override
  void initState() {
    super.initState();
    _downloadPdf();
  }

  Future<void> _downloadPdf() async {
    try {
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${widget.name}');
        await file.writeAsBytes(response.bodyBytes, flush: true);
        setState(() {
          localPath = file.path;
          loading = false;
        });
      } else {
        setState(() {
          error = 'Failed to load PDF (status ${response.statusCode})';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Failed to load PDF: $e';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.name,
          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        iconTheme: Theme.of(context).appBarTheme.iconTheme,
        elevation: 2,
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
          : error != null
          ? Center(child: Text(error!, style: const TextStyle(color: Colors.red)))
          : localPath == null
          ? const Center(child: Text('PDF file not found.'))
          : Stack(
        children: [
          PDFView(
            filePath: localPath!,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: true,
            pageFling: true,
            onRender: (_pages) {
              setState(() {
                _totalPages = _pages ?? 0;
              });
            },
            onViewCreated: (controller) {
              _pdfViewController = controller;
            },
            onPageChanged: (current, _) {
              setState(() {
                _currentPage = (current ?? 0) + 1;
              });
            },
          ),
          if (_totalPages > 0)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Page $_currentPage of $_totalPages',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
