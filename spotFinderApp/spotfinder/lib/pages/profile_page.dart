import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatefulWidget {
  final String userEmail;

  const ProfilePage({super.key, required this.userEmail});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();

  void _saveVehicleInfo() {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) {
      return;
    }

    FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: widget.userEmail)
        .get()
        .then((querySnapshot) {
      querySnapshot.docs.forEach((document) {
        try {
          FirebaseFirestore.instance
              .collection('users')
              .doc(document.id)
              .update({
            'vehicle': {
              'brand': _brandController.text,
              'model': _modelController.text,
              'color': _colorController.text,
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Vehicle information saved successfully!'),
          ));
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to save vehicle information'),
          ));
          print('Error saving vehicle info: $e');
        }
      });
    });
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                'Add Vehicle Information',
                style: TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _brandController,
                      decoration: const InputDecoration(
                        labelText: 'Brand',
                      ),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Please enter a brand';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: 'Model',
                      ),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Please enter a model';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _colorController,
                      decoration: const InputDecoration(
                        labelText: 'Color',
                      ),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Please enter a color';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveVehicleInfo,
                child: const Text('Save Vehicle Info'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
