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
  String? _downloadPath;
  String? _error;
  bool _webViewError = false;
  bool _webViewReady = false;
  late final WebViewController _webViewController;

  bool get isPptx => widget.name.toLowerCase().endsWith('.pptx');
  bool get isHttps => widget.url.toLowerCase().startsWith('https://');

  @override
  void initState() {
    super.initState();
    if (isPptx && isHttps) {
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
      _error = null;
      _downloadPath = null;
    });

    try {
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode != 200) {
        throw Exception('Failed to download (status ${response.statusCode})');
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

      if (saveDir == null) throw Exception('Could not access storage directory.');

      await saveDir.create(recursive: true);
      final savePath = '${saveDir.path}/${widget.name}';
      final file = File(savePath);
      await file.writeAsBytes(response.bodyBytes, flush: true);

      setState(() {
        _downloadPath = savePath;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded to $savePath'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      await OpenFile.open(savePath);
    } catch (e) {
      setState(() {
        _error = 'Download failed: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
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
    if (isPptx && isHttps) {
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
                              'Unable to preview PPTX file.\nTry opening with an external viewer or download.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.black54),
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Open with External Viewer'),
                              onPressed: _openInExternalViewer,
                            ),
                          ],
                        ),
                      ),
                    )
                  : (_webViewReady
                      ? WebViewWidget(controller: _webViewController)
                      : const Center(child: CircularProgressIndicator())),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open with External Viewer'),
                    onPressed: _openInExternalViewer,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: _downloading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download_rounded),
                    label: Text(_downloading ? 'Downloading...' : 'Download & Open'),
                    onPressed: _downloading ? null : _downloadAndOpenFile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
            if (_downloadPath != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Saved to: $_downloadPath',
                  style: const TextStyle(fontSize: 14, color: Colors.green),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_error != null)
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
        elevation: 2,
      ),
      body: Center(
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
                label: Text(_downloading ? 'Downloading...' : 'Download & Open'),
                onPressed: _downloading ? null : _downloadAndOpenFile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open with External Viewer'),
                onPressed: _openInExternalViewer,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              if (_downloadPath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'Saved to: $_downloadPath',
                    style: const TextStyle(fontSize: 14, color: Colors.green),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_error != null)
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
}
