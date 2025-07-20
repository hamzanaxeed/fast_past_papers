import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:supabase_flutter/supabase_flutter.dart';

// Concise user event log
Future<void> logUserEvent(String event, {String? details}) async {
  try {
    final user = fb_auth.FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'anonymous';
    if (email.toLowerCase().contains('admin')) return; // skip admin logs

    await Supabase.instance.client.from('log_table').insert({
      'Email': email,
      'Event': event.length > 24 ? event.substring(0, 24) : event,
      if (details != null && details.isNotEmpty)
        'Details': details.length > 48 ? details.substring(0, 48) : details,
      'Time': DateTime.now().toIso8601String(),
    });
  } catch (_) {}
}

// Concise edit log
Future<void> logEditEvent(String email, String event) async {
  try {
    await Supabase.instance.client.from('Edit_Log').insert({
      'Email': email,
      'Event': event.length > 32 ? event.substring(0, 32) : event,
      'Time': DateTime.now().toIso8601String(),
    });
  } catch (_) {}
}
