import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class OtherViewer extends StatefulWidget {
  final String url;
  final String name;

  const OtherViewer({Key? key, required this.url, required this.name}) : super(key: key);

  @override
  State<OtherViewer> createState() => _OtherViewerState();
}

class _OtherViewerState extends State<OtherViewer> {
  bool _downloading = false;
  double _downloadProgress = 0.0;
  String? _downloadPath;
  String? _error;
  bool _webViewError = false;
  bool _webViewReady = false;
  late final WebViewController _webViewController;

  bool get isSupportedForDocsViewer {
    final ext = widget.name.toLowerCase();
    return ext.endsWith('.pptx') ||
        ext.endsWith('.docx') ||
        ext.endsWith('.xlsx') ||
        ext.endsWith('.txt');
  }
  bool get isHttps => widget.url.toLowerCase().startsWith('https://');

  @override
  void initState() {
    super.initState();
    if (isSupportedForDocsViewer && isHttps) {
      final fileUrl = Uri.encodeComponent(widget.url);
      final viewerUrl = 'https://docs.google.com/gview?embedded=true&url=$fileUrl';
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) {
            setState(() {
              _webViewReady = true;
            });
          },
          onWebResourceError: (error) {
            setState(() {
              _webViewError = true;
            });
          },
        ))
        ..loadRequest(Uri.parse(viewerUrl));
      _webViewReady = true;
    }
  }

  Future<void> _downloadAndOpenFile() async {
    setState(() {
      _downloading = true;
      _downloadProgress = 0.0;
      _error = null;
      _downloadPath = null;
    });

    try {
      final request = http.Request('GET', Uri.parse(widget.url));
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception('Download failed: Server responded with status ${response.statusCode}. Please check your internet connection or try again later.');
      }

      Directory? saveDir;
      if (Platform.isAndroid) {
        final downloads = Directory('/storage/emulated/0/Download');
        if (await downloads.exists()) {
          saveDir = downloads;
        } else {
          saveDir = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        saveDir = await getApplicationDocumentsDirectory();
      } else {
        saveDir = await getDownloadsDirectory();
      }

      if (saveDir == null) throw Exception('Download failed: Unable to access device storage.');

      await saveDir.create(recursive: true);
      final savePath = '${saveDir.path}/${widget.name}';
      final file = File(savePath);

      final sink = file.openWrite();
      int received = 0;
      final total = response.contentLength ?? 0;

      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        setState(() {
          _downloadProgress = total > 0 ? received / total : 0.0;
        });
      }
      await sink.close();

      setState(() {
        _downloadPath = savePath;
        _downloadProgress = 1.0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text('Download complete! Saved to $savePath')),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      await OpenFile.open(savePath);
    } catch (e) {
      setState(() {
        _error = e is SocketException
            ? 'Download failed: No internet connection. Please check your network and try again.'
            : e.toString().contains('storage')
                ? 'Download failed: Unable to access device storage. Please check permissions.'
                : 'Download failed: ${e.toString().replaceAll('Exception: ', '')}';
        _downloadProgress = 0.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(_error ?? 'Download failed.')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      setState(() {
        _downloading = false;
      });
    }
  }

  Future<void> _openInExternalViewer() async {
    final url = widget.url;
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open in external viewer'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isSupportedForDocsViewer && isHttps) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          elevation: 2,
        ),
        body: Column(
          children: [
            Expanded(
              child: _webViewError
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 48),
                            const SizedBox(height: 16),
                            const Text(
                              'Unable to preview file.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    )
                  : (_webViewReady
                      ? WebViewWidget(controller: _webViewController)
                      : const Center(child: CircularProgressIndicator())),
            ),
            if (_downloading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Text(
                      'Downloading... ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _downloadProgress,
                      minHeight: 8,
                      backgroundColor: Colors.blue.shade100,
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ],
                ),
              ),
            if (_downloadPath != null && !_downloading)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Saved to: $_downloadPath',
                  style: const TextStyle(fontSize: 14, color: Colors.green),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_error != null && !_downloading)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 14, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1976D2),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 2,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFF7FAF9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.file_present_rounded, size: 64, color: Colors.blue),
                const SizedBox(height: 20),
                Text(
                  'Preview not supported inside app.\nYou can download and open with an appropriate app.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: _downloading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download_rounded),
                  label: Text(_downloading
                      ? 'Downloading... ${(_downloadProgress * 100).toStringAsFixed(0)}%'
                      : 'Download & Open'),
                  onPressed: _downloading ? null : _downloadAndOpenFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                if (_downloading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(
                      value: _downloadProgress,
                      minHeight: 8,
                      backgroundColor: Colors.blue.shade100,
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                if (_downloadPath != null && !_downloading)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      'Saved to: $_downloadPath',
                      style: const TextStyle(fontSize: 14, color: Colors.green),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_error != null && !_downloading)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(fontSize: 14, color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
