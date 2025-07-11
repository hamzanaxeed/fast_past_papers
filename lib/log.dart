import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:supabase_flutter/supabase_flutter.dart';

// Only log events if not admin
Future<void> logUserEvent(String event, {String? details}) async {
  try {
    final user = fb_auth.FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'anonymous';
    const adminEmail = 'l230618@lhr.nu.edu.pk';

    if (email.toLowerCase() == adminEmail) {
      // Do not log for admin
      return;
    }

    final logData = {
      'Email': email,
      'Event': event,
      'Time': DateTime.now().toIso8601String(),
    };
    if (details != null) {
      logData['Details'] = details;
    }

    await Supabase.instance.client.from('log_table').insert(logData);
  } catch (e) {
    // Optionally handle/log error
  }
}

/// Log an edit event to the Edit_Log table.
/// [email] - The user's email.
/// [event] - The event description (e.g., "folder_Name was created" or "file was created").
Future<void> logEditEvent(String email, String event) async {
  try {
    await Supabase.instance.client.from('Edit_Log').insert({
      'Email': email,
      'Event': event,
      'Time': DateTime.now().toIso8601String(),
    });
  } catch (e) {
    // Optionally handle/log error
  }
}
