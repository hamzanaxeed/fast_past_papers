import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'log.dart'; // <-- Add this import

// Feedback dialog for non-admins
void showFeedbackDialog(BuildContext context) {
  final controller = TextEditingController();
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Theme.of(context).cardColor,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.feedback, color: Color(0xFF1976D2), size: 48),
            const SizedBox(height: 12),
            Text(
              'We value your feedback!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1976D2),
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 5,
              minLines: 3,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                hintText: 'Share your thoughts or suggestions...',
                hintStyle: TextStyle(color: Theme.of(context).hintColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close, color: Color(0xFF1976D2)),
                    label: const Text('Cancel', style: TextStyle(color: Color(0xFF1976D2))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1976D2), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send, color: Colors.white),
                    label: const Text('Submit', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 2,
                      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    onPressed: () async {
                      final feedback = controller.text.trim();
                      if (feedback.isEmpty) return;

                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null || user.isAnonymous) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('You must be signed in to do this action'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                        return;
                      }
                      final email = user.email ?? 'anonymous';

                      try {
                        await Supabase.instance.client.from('Feedback').insert({
                          'Message': feedback,
                          'Email': email,
                          'Time': DateTime.now().toIso8601String(),
                        });

                        // Log feedback event
                        logUserEvent('Sent Feedback', details: feedback);

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: const [
                                  Icon(Icons.check_circle, color: Colors.white, size: 22),
                                  SizedBox(width: 10),
                                  Expanded(child: Text('Thank you for your feedback!')),
                                ],
                              ),
                              backgroundColor: const Color(0xFF46C2CB),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: const [
                                  Icon(Icons.error, color: Colors.white, size: 22),
                                  SizedBox(width: 10),
                                  Expanded(child: Text('Failed to submit feedback.')),
                                ],
                              ),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// Admin feedback screen in a modal bottom sheet
void showAdminFeedbackScreen(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AdminFeedbackSheet(),
  );
}

class _AdminFeedbackSheet extends StatefulWidget {
  @override
  State<_AdminFeedbackSheet> createState() => _AdminFeedbackSheetState();
}

class _AdminFeedbackSheetState extends State<_AdminFeedbackSheet> {
  bool showRead = false;

  Future<List<Map<String, dynamic>>> _fetchFeedbacks() async {
    final response = await Supabase.instance.client
        .from('Feedback')
        .select()
        .eq('Read', showRead)
        .order('Time', ascending: false);
    if (response is List) {
      return response.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<void> _deleteFeedback(int id) async {
    try {
      await Supabase.instance.client
          .from('Feedback')
          .delete()
          .eq('id', id)
          .select();
      setState(() {});
      logUserEvent('Feedback Deleted', details: 'Feedback ID: $id');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.delete, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Expanded(child: Text('Feedback deleted.')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      logUserEvent('Feedback Delete Failed', details: 'Feedback ID: $id | $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Expanded(child: Text('Failed to delete feedback.')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showDeleteDialog(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Feedback'),
        content: const Text('Are you sure you want to delete this feedback? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _deleteFeedback(id);
    }
  }

  void _showFeedbackDetailDialog(Map<String, dynamic> fb, bool isRead) {
    final formattedTime = fb['Time'] != null
        ? DateFormat('yyyy-MM-dd  hh:mm a').format(DateTime.tryParse(fb['Time']) ?? DateTime.now())
        : '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(
              isRead ? Icons.mark_email_read : Icons.feedback,
              color: isRead ? Colors.green : const Color(0xFF1976D2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fb['Email'] ?? 'anonymous',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fb['Message'] ?? '',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.access_time, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  formattedTime,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (!isRead)
            ElevatedButton.icon(
              icon: const Icon(Icons.done, size: 18),
              label: const Text('Mark as read'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                try {
                  await Supabase.instance.client
                      .from('Feedback')
                      .update({'Read': true})
                      .eq('id', fb['id'])
                      .select();
                  Navigator.pop(context);
                  setState(() {});
                  logUserEvent('Feedback Marked Read', details: 'Feedback ID: ${fb['id']}');
                } catch (e) {
                  logUserEvent('Feedback Mark Read Failed', details: 'Feedback ID: ${fb['id']} | $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: const [
                            Icon(Icons.error, color: Colors.white, size: 22),
                            SizedBox(width: 10),
                            Expanded(child: Text('Failed to mark as read.')),
                          ],
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                }
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(
                width: 60,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'User Feedbacks',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Text('Show:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text('Unread'),
                      selected: !showRead,
                      onSelected: (selected) {
                        if (showRead) {
                          setState(() {
                            showRead = false;
                          });
                        }
                      },
                      selectedColor: const Color(0xFF1976D2),
                      labelStyle: TextStyle(color: !showRead ? Colors.white : Colors.black),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Read'),
                      selected: showRead,
                      onSelected: (selected) {
                        if (!showRead) {
                          setState(() {
                            showRead = true;
                          });
                        }
                      },
                      selectedColor: const Color(0xFF1976D2),
                      labelStyle: TextStyle(color: showRead ? Colors.white : Colors.black),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchFeedbacks(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final feedbacks = snapshot.data ?? [];
                    if (feedbacks.isEmpty) {
                      return Center(child: Text(showRead ? 'No read feedbacks found.' : 'No unread feedbacks found.', style: TextStyle(fontSize: 18, color: Colors.grey)));
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: feedbacks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final fb = feedbacks[i];
                        final isRead = fb['Read'] == true;
                        final formattedTime = fb['Time'] != null
                            ? DateFormat('yyyy-MM-dd  hh:mm a').format(DateTime.tryParse(fb['Time']) ?? DateTime.now())
                            : '';
                        return GestureDetector(
                          onTap: () => _showFeedbackDetailDialog(fb, isRead),
                          onLongPress: () {
                            if (fb['id'] != null) {
                              _showDeleteDialog(fb['id'] as int);
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isRead ? Colors.grey[100] : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  isRead ? Icons.mark_email_read : Icons.feedback,
                                  color: isRead ? Colors.green : const Color(0xFF1976D2),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              fb['Email'] ?? 'anonymous',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isRead)
                                            const Padding(
                                              padding: EdgeInsets.only(left: 8.0),
                                              child: Text(
                                                'Read',
                                                style: TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        fb['Message'] ?? '',
                                        style: const TextStyle(fontSize: 15),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time, size: 15, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            formattedTime,
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
