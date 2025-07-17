import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'log.dart'; // <-- Add this import

class ViewLogsScreen extends StatefulWidget {
  const ViewLogsScreen({Key? key}) : super(key: key);

  @override
  State<ViewLogsScreen> createState() => _ViewLogsScreenState();
}

enum LogType { login, edit }

class _ViewLogsScreenState extends State<ViewLogsScreen> {
  LogType _selectedLogType = LogType.login;
  late Future<List<Map<String, dynamic>>> _logsFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _logsFuture = _fetchLogs();
    logUserEvent('Opened User Logs Screen');
  }

  Future<List<Map<String, dynamic>>> _fetchLogs() async {
    final table = _selectedLogType == LogType.login ? 'log_table' : 'Edit_Log';
    final response = await Supabase.instance.client
        .from(table)
        .select()
        .order('Time', ascending: false);
    if (response is List) {
      return response.cast<Map<String, dynamic>>();
    }
    return [];
  }

  void _switchLogType(LogType type) {
    setState(() {
      _selectedLogType = type;
      _logsFuture = _fetchLogs();
      _searchQuery = '';
      _searchController.clear();
    });
  }

  int _countUniqueUsers(List<Map<String, dynamic>> logs) {
    final users = <String>{};
    final today = DateTime.now();
    for (final log in logs) {
      final email = (log['Email'] ?? '').toString().toLowerCase();
      final timeStr = log['Time'];
      if (email.isNotEmpty && timeStr != null) {
        final dt = DateTime.tryParse(timeStr);
        if (dt != null &&
            dt.year == today.year &&
            dt.month == today.month &&
            dt.day == today.day) {
          users.add(email);
        }
      }
    }
    return users.length;
  }

  int _countTotalUniqueUsers(List<Map<String, dynamic>> logs) {
    final users = <String>{};
    for (final log in logs) {
      final email = (log['Email'] ?? '').toString().toLowerCase();
      if (email.isNotEmpty) {
        users.add(email);
      }
    }
    return users.length;
  }

  int _countTodayLogs(List<Map<String, dynamic>> logs) {
    final today = DateTime.now();
    int count = 0;
    for (final log in logs) {
      final timeStr = log['Time'];
      if (timeStr != null) {
        final dt = DateTime.tryParse(timeStr);
        if (dt != null &&
            dt.year == today.year &&
            dt.month == today.month &&
            dt.day == today.day) {
          count++;
        }
      }
    }
    return count;
  }

  int _countTotalLogs(List<Map<String, dynamic>> logs) {
    return logs.length;
  }

  List<String> _getUniqueUserEmails(List<Map<String, dynamic>> logs) {
    final users = <String>{};
    final today = DateTime.now();
    for (final log in logs) {
      final email = (log['Email'] ?? '').toString().toLowerCase();
      final timeStr = log['Time'];
      if (email.isNotEmpty && timeStr != null) {
        final dt = DateTime.tryParse(timeStr);
        if (dt != null &&
            dt.year == today.year &&
            dt.month == today.month &&
            dt.day == today.day) {
          users.add(email);
        }
      }
    }
    return users.toList();
  }

  List<String> _getTotalUniqueUserEmails(List<Map<String, dynamic>> logs) {
    final users = <String>{};
    for (final log in logs) {
      final email = (log['Email'] ?? '').toString().toLowerCase();
      if (email.isNotEmpty) {
        users.add(email);
      }
    }
    return users.toList();
  }

  void _showUniqueUsersDialog(List<String> emails, {String title = 'User Emails'}) {
    final sortedEmails = List<String>.from(emails)..sort();
    logUserEvent('Viewed $title Dialog', details: 'Count: ${sortedEmails.length}');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titlePadding: const EdgeInsets.only(left: 24, right: 8, top: 22, bottom: 0),
        title: Row(
          children: [
            const Icon(Icons.people, color: Color(0xFF1976D2)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$title (${sortedEmails.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
        content: SizedBox(
          width: double.maxFinite,
          child: sortedEmails.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No users found.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ),
                )
              : Scrollbar(
                  radius: const Radius.circular(12),
                  thickness: 5,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: sortedEmails.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.blue.shade100, width: 1),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.teal.shade200,
                            child: Text(
                              sortedEmails[i].isNotEmpty ? sortedEmails[i][0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              sortedEmails[i],
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
        actionsPadding: const EdgeInsets.only(right: 10, bottom: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.tryParse(isoString);
      if (dt == null) return isoString;
      return DateFormat('dd-MM-yyyy  mm:hh a (EEE)').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  List<Map<String, dynamic>> _filteredLogs(List<Map<String, dynamic>> logs) {
    if (_searchQuery.isEmpty) return logs;
    logUserEvent('Searched Logs', details: _searchQuery);
    return logs.where((log) {
      final event = (log['Event'] ?? '').toString().toLowerCase();
      final email = (log['Email'] ?? '').toString().toLowerCase();
      final details = (log['Details'] ?? '').toString().toLowerCase();
      return event.contains(_searchQuery.toLowerCase()) ||
          email.contains(_searchQuery.toLowerCase()) ||
          details.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Logs', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1976D2),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: "Refresh",
            onPressed: () {
              setState(() {
                _logsFuture = _fetchLogs();
              });
            },
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Column(
            children: [
              // --- Log type buttons ---
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('Login Log'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedLogType == LogType.login ? Colors.blue : Colors.grey[200],
                        foregroundColor: _selectedLogType == LogType.login ? Colors.white : Colors.black87,
                        elevation: _selectedLogType == LogType.login ? 2 : 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      onPressed: () => _switchLogType(LogType.login),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Edit Log'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedLogType == LogType.edit ? Colors.deepPurple : Colors.grey[200],
                        foregroundColor: _selectedLogType == LogType.edit ? Colors.white : Colors.black87,
                        elevation: _selectedLogType == LogType.edit ? 2 : 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      onPressed: () => _switchLogType(LogType.edit),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // --- Today Log / Total Log Buttons ---
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _logsFuture,
                      builder: (context, snapshot) {
                        final logs = snapshot.data ?? [];
                        final todayLogCount = _countTodayLogs(logs);
                        final totalLogCount = _countTotalLogs(logs);
                        return Row(
                          children: [
                            Card(
                              color: Colors.teal,
                              elevation: 4,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                child: Row(
                                  children: [
                                    const Icon(Icons.today, color: Colors.white, size: 22),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Today Log', style: TextStyle(fontSize: 13, color: Colors.white)),
                                        Text('$todayLogCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Card(
                              color: Colors.blue,
                              elevation: 4,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                child: Row(
                                  children: [
                                    const Icon(Icons.list, color: Colors.white, size: 22),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Total Log', style: TextStyle(fontSize: 13, color: Colors.white)),
                                        Text('$totalLogCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // --- User stats chips ---
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _logsFuture,
                      builder: (context, snapshot) {
                        final logs = snapshot.data ?? [];
                        final uniqueUserCount = _countUniqueUsers(logs);
                        final totalUserCount = _countTotalUniqueUsers(logs);
                        return Row(
                          children: [
                            Chip(
                              label: Row(
                                children: [
                                  Icon(
                                    _selectedLogType == LogType.login ? Icons.list_alt : Icons.edit_note,
                                    size: 18,
                                    color: _selectedLogType == LogType.login ? Color(0xFF1976D2) : Colors.deepPurple,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_selectedLogType == LogType.login ? "Logs" : "Edits"}: ${logs.length}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.blue.shade50,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            const SizedBox(width: 10),
                            Tooltip(
                              message: "Tap to view today's user emails",
                              child: GestureDetector(
                                onTap: () => _showUniqueUsersDialog(
                                  _getUniqueUserEmails(logs),
                                  title: "Today Users",
                                ),
                                child: Chip(
                                  avatar: const Icon(Icons.today, color: Colors.white, size: 20),
                                  label: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Today Users', style: TextStyle(fontSize: 12, color: Colors.white)),
                                      Text('$uniqueUserCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                    ],
                                  ),
                                  backgroundColor: Colors.teal,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  labelPadding: const EdgeInsets.only(left: 2),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Tooltip(
                              message: "Tap to view all unique user emails",
                              child: GestureDetector(
                                onTap: () => _showUniqueUsersDialog(
                                  _getTotalUniqueUserEmails(logs),
                                  title: "Total Users",
                                ),
                                child: Chip(
                                  avatar: const Icon(Icons.people, color: Colors.white, size: 20),
                                  label: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Total Users', style: TextStyle(fontSize: 12, color: Colors.white)),
                                      Text('$totalUserCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                    ],
                                  ),
                                  backgroundColor: Colors.deepPurple,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  labelPadding: const EdgeInsets.only(left: 2),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // --- Search bar ---
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search logs...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(height: 10),
              // --- Logs list ---
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _logsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final logs = _filteredLogs(snapshot.data ?? []);
                    if (logs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.event_busy, color: Colors.grey, size: 48),
                            SizedBox(height: 8),
                            Text('No logs found.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final log = logs[i];
                        return Card(
                          elevation: 7,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          color: Colors.white,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _selectedLogType == LogType.login
                                  ? Colors.teal.shade100
                                  : Colors.deepPurple.shade100,
                              child: Icon(
                                _selectedLogType == LogType.login ? Icons.event_note : Icons.edit,
                                color: _selectedLogType == LogType.login ? Colors.teal : Colors.deepPurple,
                              ),
                            ),
                            title: Text(
                              log['Event'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                fontSize: 17,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('User: ', style: TextStyle(color: Colors.black87)),
                                    Expanded(
                                      child: Text(
                                        log['Email'] ?? '',
                                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (log['Details'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      'Details: ${log['Details']}',
                                      style: const TextStyle(color: Colors.black87, fontSize: 14),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 15, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatDateTime(log['Time']),
                                        style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
