import 'package:flutter/material.dart';
import 'package:spotfinder/pages/login_page.dart';
import 'package:spotfinder/pages/privacypolicy_page.dart';
import 'package:spotfinder/pages/termsofservice_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool notificationsEnabled = true;
  bool darkModeEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          /*ListTile(
            title: const Text('Notifications'),
            trailing: Switch(
              value: notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  notificationsEnabled = value;
                });
              },
            ),
          ),
          ListTile(
            title: const Text('Dark mode'),
            trailing: Switch(
              value: darkModeEnabled,
              onChanged: (value) {
                setState(() {
                  darkModeEnabled = value;
                });
              },
            ),
          ),*/
          ListTile(
            title: const Text('Privacy policy'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyPage()),
              );
            },
          ),
          ListTile(
            title: const Text('Terms of service'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const TermsOfServicePage()),
              );
            },
          ),
          ListTile(
            title: const Text('Sign out'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
