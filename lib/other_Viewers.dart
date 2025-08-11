import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart'; // For clipboard copy
import 'image_Viewer.dart'; // Add this import

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
  bool _webViewLoading = false; // Add this
  late final WebViewController _webViewController;

  String? _textPreview;
  bool _textLoading = false;
  String? _textError;

  // Supported for Google Docs Viewer
  bool get isSupportedForDocsViewer {
    final ext = widget.name.toLowerCase();
    return ext.endsWith('.pptx') ||
        ext.endsWith('.docx') ||
        ext.endsWith('.xlsx') ||
        ext.endsWith('.pdf');
  }

  // Supported for in-app text preview
  bool get isSupportedForTextPreview {
    final ext = widget.name.toLowerCase();
    return ext.endsWith('.csv') ||
        ext.endsWith('.html') ||
        ext.endsWith('.xml') ||
        ext.endsWith('.json') ||
        ext.endsWith('.md') ||
        ext.endsWith('.txt') ||
        ext.endsWith('.rtf');
  }

  // Supported for archive info
  bool get isArchiveFile {
    final ext = widget.name.toLowerCase();
    return ext.endsWith('.zip') || ext.endsWith('.rar');
  }

  // Add image file support
  bool get isImageFile {
    final ext = widget.name.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.gif') ||
        ext.endsWith('.bmp') ||
        ext.endsWith('.webp') ||
        ext.endsWith('.jpj');
  }

  bool get isHttps => widget.url.toLowerCase().startsWith('https://');

  @override
  void initState() {
    super.initState();
    // No need to load anything for images
    if (isSupportedForDocsViewer && isHttps) {
      final fileUrl = Uri.encodeComponent(widget.url);
      final viewerUrl = 'https://docs.google.com/gview?embedded=true&url=$fileUrl';
      _webViewLoading = true;
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onPageStarted: (_) {
            setState(() {
              _webViewLoading = true;
            });
          },
          onPageFinished: (_) {
            setState(() {
              _webViewReady = true;
              _webViewLoading = false;
            });
          },
          onWebResourceError: (error) {
            setState(() {
              _webViewError = true;
              _webViewLoading = false;
            });
          },
        ))
        ..loadRequest(Uri.parse(viewerUrl));
      // Always show WebView for supported types
      _webViewReady = false;
    } else if (isSupportedForTextPreview) {
      _loadTextPreview();
    }
  }

  Future<void> _loadTextPreview() async {
    setState(() {
      _textLoading = true;
      _textError = null;
      _textPreview = null;
    });
    try {
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode == 200) {
        // Limit preview to first 100 KB for performance
        final text = response.body.length > 100000
            ? response.body.substring(0, 100000) + '\n\n--- Preview truncated ---'
            : response.body;
        setState(() {
          _textPreview = text;
          _textLoading = false;
        });
      } else {
        setState(() {
          _textError = 'Failed to load preview.';
          _textLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        if (e.toString().contains('SocketException') ||
            e.toString().toLowerCase().contains('network')) {
          _textError = 'Network error: Please check your internet connection and try again.';
        } else {
          _textError = 'Error loading preview.';
        }
        _textLoading = false;
      });
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
        // Handle permission denied error
        String userError;
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('os error') && errStr.contains('permission denied')) {
          userError = 'Permission denied: Please allow storage access in your device settings and try again.';
        } else if (errStr.contains('socketexception') ||
            errStr.contains('network') ||
            errStr.contains('connection')) {
          userError = 'Network error: Please check your internet connection and try again.';
        } else if (e is SocketException) {
          userError = 'Download failed: No internet connection. Please check your network and try again.';
        } else if (errStr.contains('storage')) {
          userError = 'Download failed: Unable to access device storage. Please check permissions.';
        } else {
          userError = 'Download failed. Please try again.';
        }
        _error = userError;
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
    // Image preview
    if (isImageFile) {
      return ImageViewer(url: widget.url, name: widget.name);
    }

    // Google Docs Viewer preview
    if (isSupportedForDocsViewer && isHttps) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          elevation: 2,
        ),
        body: Stack(
          children: [
            AnimatedOpacity(
              opacity: (_webViewReady && !_webViewLoading && !_webViewError) ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: _webViewError
                  ? const SizedBox.shrink()
                  : WebViewWidget(controller: _webViewController),
            ),
            if (_webViewLoading && !_webViewError)
              const Center(child: CircularProgressIndicator()),
            if (_webViewError)
              Center(
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
              ),
            // ...existing download/error widgets...
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
            ),
          ],
        ),
      );
    }

    // Text-based preview
    if (isSupportedForTextPreview) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          elevation: 2,
          actions: [
            if (_textPreview != null)
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy to clipboard',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _textPreview!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard'), backgroundColor: Colors.green),
                  );
                },
              ),
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Open externally',
              onPressed: _openInExternalViewer,
            ),
          ],
        ),
        body: Stack(
          children: [
            AnimatedOpacity(
              opacity: (_textPreview != null && !_textLoading && _textError == null) ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: _textPreview != null
                  ? Scrollbar(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          _textPreview!,
                          style: const TextStyle(fontSize: 15, fontFamily: 'monospace'),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            if (_textLoading)
              const Center(child: CircularProgressIndicator()),
            if (_textError != null)
              Center(child: Text(_textError!, style: const TextStyle(color: Colors.red))),
          ],
        ),
      );
    }

    // Archive file info
    if (isArchiveFile) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          elevation: 2,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.archive, size: 64, color: Colors.orange),
                const SizedBox(height: 20),
                Text(
                  'Archive file (.zip/.rar)\nPreview not supported inside app.\nYou can download and open with an appropriate app.',
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
                    backgroundColor: Colors.orange,
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
                      backgroundColor: Colors.orange.shade100,
                      color: Colors.orange,
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
      );
    }

    // Fallback for unsupported formats
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
      ));
    }
  }

