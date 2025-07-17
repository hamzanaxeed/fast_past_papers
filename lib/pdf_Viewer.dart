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
      final request = http.Request('GET', Uri.parse(widget.url));
      final response = await request.send();

      if (response.statusCode != 200) {
        setState(() {
          error = 'Failed to load PDF (status ${response.statusCode}). Please check your internet connection or try again later.';
          loading = false;
        });
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.name}');
      final sink = file.openWrite();
      int received = 0;
      final total = response.contentLength ?? 0;

      // Use StatefulBuilder to update progress inside dialog
      late void Function(void Function()) dialogSetState;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setStateDialog) {
            dialogSetState = setStateDialog;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Downloading PDF...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: total > 0 ? received / total : null,
                    minHeight: 8,
                    backgroundColor: Colors.blue.shade100,
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(height: 12),
                  Text('${total > 0 ? ((received / total) * 100).toStringAsFixed(0) : '...'}%', style: const TextStyle(fontSize: 16)),
                ],
              ),
            );
          },
        ),
      );

      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        dialogSetState(() {});
      }
      await sink.close();

      if (context.mounted) Navigator.of(context).pop();
      setState(() {
        localPath = file.path;
        loading = false;
      });
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      setState(() {
        error = e is SocketException
            ? 'Failed to load PDF: No internet connection. Please check your network and try again.'
            : e.toString().contains('storage')
                ? 'Failed to load PDF: Unable to access device storage. Please check permissions.'
                : 'Failed to load PDF: ${e.toString().replaceAll('Exception: ', '')}';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF9),
      appBar: AppBar(
        title: Text(
          widget.name,
          style: const TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1976D2),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 2,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1976D2)))
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
