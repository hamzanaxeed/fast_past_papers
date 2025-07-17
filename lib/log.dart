import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:supabase_flutter/supabase_flutter.dart';

// Log only essential info, concise event and details.
Future<void> logUserEvent(String event, {String? details}) async {
  try {
    final user = fb_auth.FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'anonymous';
    if (email.toLowerCase() == 'l230618@lhr.nu.edu.pk') return; // skip admin

    await Supabase.instance.client.from('log_table').insert({
      'Email': email,
      'Event': event.length > 32 ? event.substring(0, 32) : event,
      if (details != null && details.isNotEmpty)
        'Details': details.length > 64 ? details.substring(0, 64) : details,
      'Time': DateTime.now().toIso8601String(),
    });
  } catch (_) {}
}

// Concise edit log
Future<void> logEditEvent(String email, String event) async {
  try {
    await Supabase.instance.client.from('Edit_Log').insert({
      'Email': email,
      'Event': event.length > 48 ? event.substring(0, 48) : event,
      'Time': DateTime.now().toIso8601String(),
    });
  } catch (_) {}
}
