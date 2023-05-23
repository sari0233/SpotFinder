import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Privacy Policy',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed volutpat sapien elit, sit amet pharetra est venenatis vel. Fusce sodales, ligula vel placerat eleifend, nisi orci aliquet orci, sed iaculis sapien eros vel lectus. Nam vestibulum orci et malesuada cursus. Aenean laoreet dui sit amet ligula blandit, a fermentum augue malesuada. Nam finibus mauris mauris, eget vestibulum mi sagittis id. Proin egestas lacus sed pharetra finibus. Duis vitae enim turpis. Ut hendrerit, tellus et efficitur vestibulum, mi dolor volutpat nisl, nec euismod velit elit in ex. Sed sed magna pulvinar, vulputate urna ac, laoreet nisl. Integer tristique sollicitudin fermentum. Nam a faucibus lorem. Sed feugiat auctor diam, in facilisis tortor tempus nec. Phasellus tincidunt tortor in suscipit malesuada. Nulla at ultricies mauris.',
            ),
            SizedBox(height: 16),
            Text(
              'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed volutpat sapien elit, sit amet pharetra est venenatis vel. Fusce sodales, ligula vel placerat eleifend, nisi orci aliquet orci, sed iaculis sapien eros vel lectus. Nam vestibulum orci et malesuada cursus. Aenean laoreet dui sit amet ligula blandit, a fermentum augue malesuada. Nam finibus mauris mauris, eget vestibulum mi sagittis id. Proin egestas lacus sed pharetra finibus. Duis vitae enim turpis. Ut hendrerit, tellus et efficitur vestibulum, mi dolor volutpat nisl, nec euismod velit elit in ex. Sed sed magna pulvinar, vulputate urna ac, laoreet nisl. Integer tristique sollicitudin fermentum. Nam a faucibus lorem. Sed feugiat auctor diam, in facilisis tortor tempus nec. Phasellus tincidunt tortor in suscipit malesuada. Nulla at ultricies mauris.',
            ),
          ],
        ),
      ),
    );
  }
}
