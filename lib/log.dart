import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// Concise user event log
Future<void> logUserEvent(String event, {String? details}) async {
  try {
    final user = fb_auth.FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'anonymous';
    print('[DEBUG] logUserEvent called by: $email, event: $event, details: $details');
    if (email.toLowerCase().contains('admin')) return; // skip admin logs

    await Supabase.instance.client.from('log_table').insert({
      'Email': email,
      'Event': event.length > 24 ? event.substring(0, 24) : event,
      if (details != null && details.isNotEmpty)
        'Details': details.length > 48 ? details.substring(0, 48) : details,
      'Time': DateTime.now().toIso8601String(),
    });
  } catch (e) {
    print('[DEBUG] logUserEvent error: $e');
  }
}

// Concise edit log
Future<void> logEditEvent(String event) async {
  try {

    final user = fb_auth.FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'anonymous';
    print('[DEBUG] logEditEvent called by: $email, event: $event');

    await Supabase.instance.client.from('Edit_Log').insert({
      'Email': email,
      'Event': event.length > 100 ? event.substring(0, 100) : event,
      'Time': DateTime.now().toIso8601String(),
    });
    print('[DEBUG] logEditEvent insert success');
  } catch (e) {
    print('[DEBUG] logEditEvent error: $e');
  }
}

// Example log viewing widget with correct time formatting
class LogViewer extends StatelessWidget {
  const LogViewer({super.key});

  Future<List<Map<String, dynamic>>> _fetchLogs() async {
    final response = await Supabase.instance.client
        .from('log_table')
        .select()
        .order('Time', ascending: false);
    if (response is List) return response.cast<Map<String, dynamic>>();
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logs')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
            return const Center(child: Text('No logs found.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) {
              final log = logs[i];
              String formattedTime = '';
              if (log['Time'] != null) {
                try {
                  final dt = DateTime.parse(log['Time']);
                  formattedTime = DateFormat('HH:mm').format(dt); // hour:min (24-hour)
                } catch (_) {
                  formattedTime = log['Time'].toString();
                }
              }
              return ListTile(
                title: Text(log['Event'] ?? ''),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (log['Details'] != null) Text(log['Details']),
                    Text(formattedTime, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                trailing: Text(log['Email'] ?? '', style: const TextStyle(fontSize: 12)),
              );
            },
          );
        },
      ),
    );
  }
}
