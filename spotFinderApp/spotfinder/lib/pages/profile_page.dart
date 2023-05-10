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
  List<dynamic> vehicles = [];
  List<DocumentSnapshot> vehicleDocs = [];

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
            'vehicles': FieldValue.arrayUnion([
              {
                'brand': _brandController.text,
                'model': _modelController.text,
                'color': _colorController.text,
              }
            ])
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
              const Text(
                'My Vehicles',
                style: TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 20),
              Container(
                height: 300,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('email', isEqualTo: widget.userEmail)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text('Error loading vehicles');
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }

                    return _buildVehicleList(snapshot.data!);
                  },
                ),
              ),
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

  Widget _buildVehicleList(QuerySnapshot querySnapshot) {
    vehicleDocs = querySnapshot.docs; // Wijzig deze regel
    vehicles = vehicleDocs
        .expand((doc) => (doc.data() as Map<String, dynamic>)['vehicles'])
        .toList();

    return ListView.builder(
      itemCount: vehicles.length,
      itemBuilder: (context, index) {
        final vehicle = vehicles[index];

        return ListTile(
          title: Text('${vehicle['brand']} ${vehicle['model']}'),
          subtitle: Text('Color: ${vehicle['color']}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  _showEditVehicleDialog(index);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  _showDeleteVehicleConfirmation(index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditVehicleDialog(int index) async {
    final vehicle = vehicles[index];
    final editBrandController = TextEditingController(text: vehicle['brand']);
    final editModelController = TextEditingController(text: vehicle['model']);
    final editColorController = TextEditingController(text: vehicle['color']);

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Vehicle Information'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                TextFormField(
                  controller: editBrandController,
                  decoration: const InputDecoration(
                    labelText: 'Brand',
                  ),
                ),
                TextFormField(
                  controller: editModelController,
                  decoration: const InputDecoration(
                    labelText: 'Model',
                  ),
                ),
                TextFormField(
                  controller: editColorController,
                  decoration: const InputDecoration(
                    labelText: 'Color',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _updateVehicleInfo(index, editBrandController.text,
                    editModelController.text, editColorController.text);
                Navigator.of(context).pop();
              },
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteVehicleConfirmation(int index) async {
    final vehicle = vehicles[index];

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete Vehicle'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text(
                    'Are you sure you want to delete the vehicle ${vehicle['brand']} ${vehicle['model']}?'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _deleteVehicleInfo(index);
                Navigator.of(context).pop();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _updateVehicleInfo(int index, String brand, String model, String color) {
    final updatedVehicle = {
      'brand': brand,
      'model': model,
      'color': color,
    };

    FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: widget.userEmail)
        .get()
        .then((querySnapshot) {
      querySnapshot.docs.forEach((document) {
        List<dynamic> updatedVehicles =
            List<dynamic>.from(document['vehicles']);
        updatedVehicles[index] = updatedVehicle;

        FirebaseFirestore.instance
            .collection('users')
            .doc(document.id)
            .update({'vehicles': updatedVehicles}).then((_) {
          setState(() {
            vehicles[index] = updatedVehicle;
          });
        });
      });
    });
  }

  void _deleteVehicleInfo(int index) {
    FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: widget.userEmail)
        .get()
        .then((querySnapshot) {
      querySnapshot.docs.forEach((document) {
        List<dynamic> updatedVehicles =
            List<dynamic>.from(document['vehicles']);
        updatedVehicles.removeAt(index);

        FirebaseFirestore.instance
            .collection('users')
            .doc(document.id)
            .update({'vehicles': updatedVehicles}).then((_) {
          setState(() {
            vehicles.removeAt(index);
          });
        });
      });
    });
  }

  void _setActiveVehicle(int index) {
    FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: widget.userEmail)
        .get()
        .then((querySnapshot) {
      querySnapshot.docs.forEach((document) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(document.id)
            .update({'activeVehicle': vehicles[index]}).then((_) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Active vehicle set successfully!'),
          ));
        });
      });
    });
  }
}
