import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? username;
  String? email;
  String? imageUrl;
  List<Map<String, dynamic>> chats = [];

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final session = prefs.getStringList('session');
    if (session != null && session.isNotEmpty) {
      String localId = session[0];
      String idToken = session[1];
      final profile = await fetchUserProfile(localId);
      if (profile != null) {
        setState(() {
          username = profile['username'];
          email = profile['email'];
          imageUrl = profile['image_url'];
        });
      }
      final userChats = await fetchUserChats(localId);
      setState(() {
        chats = userChats;
      });
    }
  }

  Future<Map<String, dynamic>?> fetchUserProfile(String localId) async {
    final url = Uri.parse(
      "https://firestore.googleapis.com/v1/projects/dezny-8bf09/databases/(default)/documents/users/$localId",
    );
    final res = await http.get(url);
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final fields = data['fields'];
      return {
        'username': fields['username']['stringValue'],
        'email': fields['email']['stringValue'],
        'image_url': fields['image_url']['stringValue'],
      };
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchUserChats(String localId) async {
    final url = Uri.parse(
      "https://firestore.googleapis.com/v1/projects/dezny-8bf09/databases/(default)/documents/chats",
    );
    final res = await http.get(url);
    final chatsList = <Map<String, dynamic>>[];

    if (res.statusCode == 200) {
      final jsonData = json.decode(res.body);
      final documents = jsonData['documents'] ?? [];

      for (var chat in documents) {
        final fields = chat['fields'];
        if (fields['owner_uid']['stringValue'] == localId) {
          chatsList.add({
            'name': fields['name']['stringValue'],
            'description': fields['description']['stringValue'],
            'image_url': fields['image_url']['stringValue'],
          });
        }
      }
    }
    return chatsList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Welcome $username')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(
                  imageUrl ?? 'https://www.example.com/default-avatar.jpg',
                ),
              ),
            ),
            Text(
              username ?? 'Loading...',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              email ?? 'Loading...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 20),
            // عرض الدردشات
            Text(
              'My Chats',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              itemCount: chats.length,
              itemBuilder: (context, index) {
                return Card(
                  color: Color(0xFF2C2C2C),
                  margin: EdgeInsets.symmetric(vertical: 5, horizontal: 15),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundImage: NetworkImage(
                        chats[index]['image_url'] ??
                            'https://www.example.com/default-chat.jpg',
                      ),
                    ),
                    title: Text(
                      chats[index]['name'] ?? 'Unknown',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      chats[index]['description'] ?? 'No description available',
                      style: TextStyle(color: Colors.grey),
                    ),
                    onTap: () {},
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
