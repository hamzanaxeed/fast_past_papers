import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> showStartupMessage(BuildContext context) async {
  try {
    final response = await Supabase.instance.client
        .from('message_Table')
        .select('Message')
        .limit(1)
        .maybeSingle();

    final message = response != null ? response['Message']?.toString() : null;
    if (message != null && message.trim().isNotEmpty) {
      // ignore: use_build_context_synchronously
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Admin Message',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    elevation: 4,
                    color: Colors.deepPurple.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        message,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('OK'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  } catch (e) {
    // Optionally log or ignore
  }
}

void showManageMessagesDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => const ManageMessagesDialog(),
  );
}

class ManageMessagesDialog extends StatefulWidget {
  const ManageMessagesDialog({Key? key}) : super(key: key);

  @override
  State<ManageMessagesDialog> createState() => _ManageMessagesDialogState();
}

class _ManageMessagesDialogState extends State<ManageMessagesDialog> {
  String? _message;
  bool _loading = true;
  String? _error;
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMessage();
  }

  Future<void> _fetchMessage() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await Supabase.instance.client
          .from('message_Table')
          .select('Message')
          .limit(1)
          .maybeSingle();

      setState(() {
        _message = response != null ? response['Message']?.toString() : null;
        _messageController.text = _message ?? '';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to fetch message';
        _loading = false;
      });
    }
  }

  Future<void> _addOrUpdateMessage() async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) return;
    setState(() {
      _loading = true;
    });
    try {
      if (_message == null) {
        await Supabase.instance.client
            .from('message_Table')
            .insert({'Message': msg});
      } else {
        await Supabase.instance.client
            .from('message_Table')
            .update({'Message': msg})
            .neq('Message', '');
      }
      await _fetchMessage();
    } catch (_) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _deleteMessage() async {
    setState(() {
      _loading = true;
    });
    try {
      await Supabase.instance.client
          .from('message_Table')
          .delete()
          .neq('Message', '');
      _messageController.clear();
      await _fetchMessage();
    } catch (_) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        child: SizedBox(
          width: 400,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Text(_error!)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Admin Message',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Card(
                          elevation: 4,
                          color: Colors.deepPurple.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                labelText: 'Message',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              minLines: 1,
                              maxLines: 3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: Icon(_message == null ? Icons.add : Icons.save),
                                label: Text(_message == null ? 'Add Message' : 'Update Message'),
                                onPressed: _addOrUpdateMessage,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            if (_message != null) ...[
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.delete),
                                label: const Text('Delete'),
                                onPressed: _deleteMessage,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
