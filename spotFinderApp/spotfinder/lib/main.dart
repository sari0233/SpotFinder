import 'package:flutter/material.dart';
import 'map_page.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const firebaseOptions = FirebaseOptions(
    apiKey: "AIzaSyBEyeWRIlcXeKbSD0c5pmNmpz6d5YSdP7k",
    authDomain: "spotfinder-59f59.firebaseapp.com",
    projectId: "spotfinder-59f59",
    storageBucket: "spotfinder-59f59.appspot.com",
    messagingSenderId: "471359135011",
    appId: "1:471359135011:web:bec127c914172643f4c096",
    measurementId: "G-MC262H6QPM",
  );

  runApp(MyApp(
    firebaseInitialization: Firebase.initializeApp(options: firebaseOptions),
  ));
}

class MyApp extends StatelessWidget {
  final Future<FirebaseApp> firebaseInitialization;

  const MyApp({Key? key, required this.firebaseInitialization})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spot Finder',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FutureBuilder(
        future: firebaseInitialization,
        builder: (BuildContext context, AsyncSnapshot<FirebaseApp> snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return MapPage();
          } else {
            return Scaffold(
              appBar: AppBar(
                title: Text('Spot Finder'),
              ),
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
        },
      ),
    );
  }
}
