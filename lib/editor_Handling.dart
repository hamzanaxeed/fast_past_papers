import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'log.dart';

class EditorHandlingScreen extends StatefulWidget {
  const EditorHandlingScreen({Key? key}) : super(key: key);

  @override
  State<EditorHandlingScreen> createState() => _EditorHandlingScreenState();
}

class _EditorHandlingScreenState extends State<EditorHandlingScreen> {
  late Future<List<Map<String, dynamic>>> _editorsFuture;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allEditors = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _editorsFuture = _fetchEditors();
    logUserEvent('Editor Handling Screen Opened');
  }

  Future<List<Map<String, dynamic>>> _fetchEditors() async {
    try {
      final response = await Supabase.instance.client
          .from('Editors')
          .select('Editor_Email')
          .order('Editor_Email');
      if (response is List) {
        _allEditors = response.cast<Map<String, dynamic>>();
        return _allEditors;
      }
      return [];
    } catch (e) {
      _showError('Failed to fetch editors: $e');
      return [];
    }
  }

  Future<void> _addEditor(String email) async {
    try {
      await Supabase.instance.client
          .from('Editors')
          .insert([
        {'Editor_Email': email.trim()}
      ])
          .select();
      setState(() {
        _editorsFuture = _fetchEditors();
      });
      _showSuccess('Editor added successfully.');
      logUserEvent('Editor Added', details: email.trim());
    } catch (e) {
      _showError('Failed to add editor: $e');
      logUserEvent('Editor Add Failed', details: '$email | $e');
    }
  }

  Future<void> _deleteEditor(String email) async {
    try {
      await Supabase.instance.client
          .from('Editors')
          .delete()
          .eq('Editor_Email', email.trim())
          .select();
      setState(() {
        _editorsFuture = _fetchEditors();
      });
      _showSuccess('Editor deleted successfully.');
      logUserEvent('Editor Deleted', details: email.trim());
    } catch (e) {
      _showError('Failed to delete editor: $e');
      logUserEvent('Editor Delete Failed', details: '$email | $e');
    }
  }

  void _showAddEditorDialog() {
    _emailController.clear();
    logUserEvent('Add Editor Dialog Opened');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Add Editor'),
        content: TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Editor Email',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF46C2CB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 2,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            onPressed: () async {
              final email = _emailController.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                _showError('Please enter a valid email address.');
                return;
              }
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Add'),
                  content: Text('Add "$email" as an editor?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
                  ],
                ),
              );
              if (confirm == true) {
                await _addEditor(email);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showDeleteEditorDialog(String email) {
    logUserEvent('Delete Editor Dialog Opened', details: email);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Editor'),
        content: Text('Are you sure you want to remove "$email" as an editor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 2,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            onPressed: () async {
              await _deleteEditor(email);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    logUserEvent('Editor Handling Error', details: message);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showSuccess(String message) {
    logUserEvent('Editor Handling Success', details: message);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _filteredEditors(List<Map<String, dynamic>> editors) {
    if (_searchQuery.isEmpty) return editors;
    logUserEvent('Editor Search', details: _searchQuery);
    return editors
        .where((e) => (e['Editor_Email'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Editors', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1976D2),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: "Add Editor",
            onPressed: _showAddEditorDialog,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFF7FAF9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search editor email...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(width: 10),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _editorsFuture,
                  builder: (context, snapshot) {
                    final count = snapshot.data?.length ?? 0;
                    return Chip(
                      label: Text('Total: $count'),
                      backgroundColor: Colors.blue.shade100,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _editorsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final editors = _filteredEditors(snapshot.data ?? []);
                  if (editors.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.person_off, color: Colors.grey, size: 48),
                          SizedBox(height: 8),
                          Text('No editors found.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: editors.length,
                    itemBuilder: (context, i) {
                      final email = editors[i]['Editor_Email'] ?? 'unknown';
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade300,
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                          child:ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            leading: const CircleAvatar(
                              radius: 18,
                              backgroundColor: Color(0xFF1976D2),
                              child: Icon(Icons.person, color: Colors.white, size: 18),
                            ),
                            title: Text(
                              email,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              tooltip: "Delete Editor",
                              splashRadius: 20,
                              onPressed: () => _showDeleteEditorDialog(email),
                            ),
                            horizontalTitleGap: 8, // Reduce gap between avatar and title
                            minLeadingWidth: 0,    // Reduce default spacing if needed
                          )

                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

}
