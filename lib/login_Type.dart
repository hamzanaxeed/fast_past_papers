// To revert to the old look, restore the original _cardDecoration and gradient in build().
import 'other_Viewers.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'authentications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'image_Viewer.dart';
import 'pdf_Viewer.dart';
import 'dart:async';
import 'feedback.dart'; // <-- Add this import
import 'editor_Handling.dart'; // <-- Add this import
import 'package:path_provider/path_provider.dart'; // <-- Add this import
import 'package:http/http.dart' as http; // <-- Add this import
import 'log.dart'; // <-- Add this import
import 'view_Logs.dart'; // <-- Add this import
import 'message_File.dart'; // <-- Add this import
import 'options_Screen.dart';
import 'main.dart'; // <-- Import for tempSupabaseClient


class LoginType {
  List<String> adminEmails = [];
  List<String> editorEmails = [];

  bool editorsFetched = false;
  bool adminsFetched = false;

  // Must be accessed after fetch
  bool isAdmin = false;
  bool isEditor = false;

  // Fetch Admin emails from Supabase
  Future<void> fetchAdminEmails() async {
    try {
      final response = await Supabase.instance.client
          .from('Admins')
          .select('admin_Email');

      adminEmails = response
          .map((e) => e['admin_Email']?.toString().toLowerCase())
          .whereType<String>()
          .toList();

      adminsFetched = true;
    } catch (e) {
      print('Error fetching admin emails: $e');
      adminsFetched = false;
    }
  }

  // Fetch Editor emails from Supabase
  Future<void> fetchEditorEmails() async {
    try {
      final response = await Supabase.instance.client
          .from('Editors')
          .select('Editor_Email');

      editorEmails = response
          .map((e) => e['Editor_Email']?.toString().toLowerCase())
          .whereType<String>()
          .toList();

      editorsFetched = true;
    } catch (e) {
      print('Error fetching editor emails: $e');
      editorsFetched = false;
    }
  }

  // Unified method to check role
  Future<void> determineUserRole() async {
    final email = FirebaseAuth.instance.currentUser?.email?.toLowerCase();

    if (email == null) {
      isAdmin = false;
      isEditor = false;
      return;
    }

    await Future.wait([fetchAdminEmails(), fetchEditorEmails()]);

    isAdmin = adminEmails.contains(email);
    isEditor = editorEmails.contains(email) || isAdmin;
  }


}
