import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart' show InteractiveFlag;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:geocoding/geocoding.dart';
import 'package:collection/collection.dart';
import 'package:spotfinder/pages/history_page.dart';
import 'package:spotfinder/pages/profile_page.dart';
import 'package:spotfinder/pages/settings_page.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class HomePage extends StatelessWidget {
  final String userEmail;
  final Map<String, dynamic>? activeVehicle;
  HomePage({Key? key, required this.userEmail, required this.activeVehicle})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: Column(
        children: [
          Expanded(
              child:
                  MapPage(userEmail: userEmail, activeVehicle: activeVehicle)),
          const SizedBox(height: 5),
          Container(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.map_sharp),
                  onPressed: () {},
                ),
                IconButton(
                    icon: const Icon(Icons.history),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => HistoryPage(currentUserEmail: userEmail)),
                      );
                    }),
                IconButton(
                    icon: const Icon(Icons.directions_car),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                ProfilePage(userEmail: userEmail)),
                      );
                    }),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SettingsPage()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MapPage extends StatefulWidget {
  final String userEmail;
  final Map<String, dynamic>? activeVehicle;

  MapPage({Key? key, required this.userEmail, required this.activeVehicle})
      : super(key: key);

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final GeolocatorPlatform _geolocator = GeolocatorPlatform.instance;
  List<Marker> _firestoreMarkers = [];
  List<Marker> _userMarkers = [];
  final _endTimeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Timer? _timer;
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? activeVehicle;
  @override
  void initState() {
    super.initState();
    _checkExpiredParkingSpots();
    activeVehicle = widget.activeVehicle;
    _timer = Timer.periodic(Duration(minutes: 1), (timer) {
      _checkExpiredParkingSpots();
    });
  }

  Future<List<dynamic>> _getUserVehicles() async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: widget.userEmail)
        .get();
    return querySnapshot.docs.first['vehicles'] ?? [];
  }

  Future<void> _updateActiveVehicle(
      String userEmail, Map<String, dynamic> vehicle) async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        DocumentSnapshot userDoc = querySnapshot.docs.first;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .update({'activeVehicle': vehicle});
      }
    } catch (e) {
      print('Error updating active vehicle: $e');
    }
  }

  Widget _buildVehicleButton() {
    String buttonText = activeVehicle != null
        ? '${activeVehicle!['brand']} ${activeVehicle!['model']}'
        : 'Selecteer een voertuig';

    return FutureBuilder<List<dynamic>>(
      future: _getUserVehicles(),
      builder: (BuildContext context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (snapshot.hasError) {
          return const Text('Error: Could not load vehicles');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        }

        final vehicles = snapshot.data!;

        return PopupMenuButton<dynamic>(
          padding: EdgeInsets.zero,
          itemBuilder: (BuildContext context) {
            return vehicles.map((vehicle) {
              return PopupMenuItem<dynamic>(
                value: vehicle,
                child: Text('${vehicle['brand']} ${vehicle['model']}'),
              );
            }).toList();
          },
          onSelected: (dynamic vehicle) {
            setState(() {
              activeVehicle = vehicle;
            });
            _updateActiveVehicle(widget.userEmail, vehicle);
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              buttonText,
              style: TextStyle(color: Colors.black, fontSize: 16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVehicleSelector() {
    return FutureBuilder<List<dynamic>>(
      future: _getUserVehicles(),
      builder: (BuildContext context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (snapshot.hasError) {
          return const Text('Error: Could not load vehicles');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        }
        final vehicles = snapshot.data!;
        return ListView.builder(
          itemCount: vehicles.length,
          itemBuilder: (BuildContext context, int index) {
            final vehicle = vehicles[index];
            return ListTile(
              title: Text('${vehicle['brand']} ${vehicle['model']}'),
              onTap: () {
                setState(() {
                  activeVehicle = vehicle;
                });
                _updateActiveVehicle(widget.userEmail, vehicle);
                Navigator.of(context).pop();
              },
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkExpiredParkingSpots() async {
    CollectionReference parkingSpots =
        FirebaseFirestore.instance.collection('parkingSpots');

    QuerySnapshot querySnapshot =
        await parkingSpots.where('endTime', isLessThan: DateTime.now()).get();

    for (var doc in querySnapshot.docs) {
      if (doc['reserved'] == true &&
          doc['nextStartTime'] != null &&
          doc['nextEndTime'] != null &&
          doc['nextUserEmail'] != null) {
        await doc.reference.update({
          'previousUserEmail': doc['userEmail'],
          'startTime': doc['nextStartTime'],
          'endTime': doc['nextEndTime'],
          'userEmail': doc['nextUserEmail'],
          'vehicle': doc['nextVehicle'],
          'reserved': false,
          'nextStartTime': null,
          'nextEndTime': null,
          'nextUserEmail': null,
          'nextVehicle': null,
          'rated': false
        });
      } else {
        await doc.reference.delete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /*appBar: AppBar(
        title: Text('Spot Finder'),
      ),*/
      body: _buildMap(),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        child: Icon(Icons.my_location),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildMap() {
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: _getParkingLocations(),
          builder:
              (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            switch (snapshot.connectionState) {
              case ConnectionState.waiting:
                return Center(child: CircularProgressIndicator());
              default:
                _firestoreMarkers = snapshot.data!.docs.map((doc) {
                  GeoPoint geoPoint = doc['location'];
                  DateTime endTime = doc['endTime'].toDate();
                  bool reserved = doc['reserved'];
                  String markerUserEmail = doc['userEmail'];
                  Color markerColor;
                  if (markerUserEmail == widget.userEmail) {
                    if (reserved) {
                      markerColor = Color.fromARGB(255, 86, 0, 198);
                    } else {
                      markerColor = Colors.blue;
                    }
                  } else {
                    markerColor = reserved
                        ? Color.fromARGB(255, 86, 0, 198)
                        : _calculateMarkerColor(endTime);
                  }
                  return Marker(
                    width: 80.0,
                    height: 80.0,
                    point: LatLng(geoPoint.latitude, geoPoint.longitude),
                    builder: (ctx) => Container(
                      child: IconButton(
                        icon: Icon(Icons.location_on),
                        color: markerColor,
                        iconSize: 45.0,
                        onPressed: () {
                          _markerOnPressed(doc, markerColor);
                        },
                      ),
                    ),
                  );
                }).toList();
                return FlutterMap(
                  options: MapOptions(
                      center: LatLng(51.2300204, 4.4161833),
                      zoom: 17.0,
                      minZoom: 16.0,
                      maxZoom: 18.0,
                      onTap: (_, latlng) {
                        _addMarker(latlng);
                      },
                      interactiveFlags: InteractiveFlag.pinchZoom |
                          InteractiveFlag.doubleTapZoom),
                  layers: [
                    TileLayerOptions(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: ['a', 'b', 'c'],
                    ),
                    MarkerLayerOptions(
                        markers: _firestoreMarkers + _userMarkers),
                  ],
                );
            }
          },
        ),
        Positioned(
          top: 10,
          left: 0,
          right: 0,
          child: Center(child: _buildVehicleButton()),
        ),
      ],
    );
  }

  Future<double> _getUserRating(String userEmail) async {
    double rating = 0;
    QuerySnapshot userQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: userEmail)
        .get();

    if (userQuery.docs.isNotEmpty) {
      DocumentSnapshot userDoc = userQuery.docs.first;
      List<dynamic> ratings = userDoc['ratings'];
      rating = ratings[0] / ratings[1];
    }

    return rating;
  }

  void _markerOnPressed(DocumentSnapshot? doc, Color markerColor,
      {bool isNew = false}) async {
    DateTime? startTime = doc?['startTime']?.toDate();
    String userEmail = doc != null ? doc['userEmail'] : 'Niet ingesteld';
    LatLng location;
    DateTime? endTime;
    bool reserved = false;
    String? nextUserEmail = doc?['nextUserEmail'];
    DateTime? nextStartTime = doc?['nextStartTime']?.toDate();
    DateTime? nextEndTime = doc?['nextEndTime']?.toDate();
    String? vehicleBrand = doc?['vehicle']['brand'];
    String? vehicleModel = doc?['vehicle']['model'];
    String? vehicleColor = doc?['vehicle']['color'];
    String? previousUserEmail = doc?['previousUserEmail'];

    if (doc != null) {
      GeoPoint geoPoint = doc['location'];
      endTime = doc['endTime']?.toDate();
      reserved = doc['reserved'] ?? false;
      nextUserEmail = doc['nextUserEmail'];
      nextStartTime = doc['nextStartTime']?.toDate();
      nextEndTime = doc['nextEndTime']?.toDate();
      location = LatLng(geoPoint.latitude, geoPoint.longitude);
    } else {
      location = _userMarkers.last.point;
    }
    String address =
        await _getAddressFromLatLng(location.latitude, location.longitude);
    double userRating =
        userEmail != 'Niet ingesteld' ? await _getUserRating(userEmail) : 0;

    if (isNew) {
      _showEndTimeInputDialog(location);
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          bool showPreviousUser = widget.userEmail == userEmail &&
              previousUserEmail != null &&
              !(doc?['rated'] ?? false);

          return AlertDialog(
            title: Text('Gegevens parkeerplaats',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Adres:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('$address'),
                  SizedBox(height: 10),
                  if (endTime != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Resterende tijd:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        RemainingTimeWidget(endTime: endTime),
                      ],
                    ),
                  SizedBox(height: 10),
                  Text('Gebruiker:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$userEmail'),
                      SizedBox(height: 10),
                      RatingBarIndicator(
                        rating: userRating,
                        itemBuilder: (context, index) => Icon(
                          Icons.star,
                          color: Colors.amber,
                        ),
                        itemCount: 5,
                        itemSize: 20.0,
                        direction: Axis.horizontal,
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  if (vehicleBrand != null &&
                      vehicleModel != null &&
                      vehicleColor != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Voertuig:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('$vehicleBrand $vehicleModel, $vehicleColor'),
                      ],
                    ),
                  SizedBox(height: 15),
                  if (nextUserEmail != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Volgende sessie:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '${nextStartTime != null ? DateFormat('dd-MM-yyyy HH:mm').format(nextStartTime) : 'Niet ingesteld'} - ${nextEndTime != null ? DateFormat('dd-MM-yyyy HH:mm').format(nextEndTime) : 'Niet ingesteld'}',
                        ),
                        Text('$nextUserEmail'),
                      ],
                    ),
                  if (showPreviousUser)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 10),
                        Text('Vorige gebruiker:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('$previousUserEmail'),
                        TextButton(
                          child: Text('Beoordeel'),
                          onPressed: () {
                            _ratePreviousUser(previousUserEmail, doc: doc);
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              if (doc != null)
                userEmail == widget.userEmail && !reserved
                    ? TextButton(
                        child: Text('Verleng'),
                        onPressed: () {
                          _showExtendInputDialog(doc, context);
                        },
                      )
                    : !reserved
                        ? TextButton(
                            child: Text('Reserveer'),
                            onPressed: () {
                              _onReserveButtonPressed(doc, context);
                            },
                          )
                        : SizedBox.shrink()
            ],
          );
        },
      );
    }
  }

  Future<void> _ratePreviousUser(String? previousUserEmail,
      {DocumentSnapshot? doc}) async {
    TextEditingController _ratingController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Beoordeel de vorige gebruiker'),
              content: Form(
                child: TextFormField(
                  controller: _ratingController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(hintText: "Beoordeling (0-5)"),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^(\d{0,1})(\.\d{0,1})?$')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Voer een beoordeling in';
                    }
                    double? rating = double.tryParse(value);
                    if (rating == null || rating < 0 || rating > 5) {
                      return 'Voer een geldige beoordeling in (0-5)';
                    }
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  child: Text('OK'),
                  onPressed: () async {
                    double rating = double.parse(_ratingController.text);

                    // Zoek naar een gebruiker met een e-mailadres dat overeenkomt met previousUserEmail
                    QuerySnapshot userQuery = await FirebaseFirestore.instance
                        .collection('users')
                        .where('email', isEqualTo: previousUserEmail)
                        .get();

                    if (userQuery.docs.isNotEmpty) {
                      DocumentSnapshot userDoc = userQuery.docs.first;
                      List<dynamic> ratings = userDoc['ratings'];
                      double newSumOfRatings = ratings[0] + rating;
                      int newNumberOfRatings = ratings[1] + 1;

                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(userDoc.id)
                          .update({
                        'ratings': [newSumOfRatings, newNumberOfRatings]
                      });
                      await _updateParkingSpotRatedStatus(doc?.id);
                    } else {
                      print(
                          'Geen gebruiker gevonden met e-mail: $previousUserEmail');
                    }

                    _ratingController.clear();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateParkingSpotRatedStatus(String? docId) async {
    // Voeg een korte vertraging toe voordat u het document bijwerkt
    await Future.delayed(Duration(milliseconds: 200));

    if (docId != null) {
      DocumentReference docRef =
          FirebaseFirestore.instance.collection('parkingSpots').doc(docId);
      DocumentSnapshot docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        await docRef.update({'rated': true});
      } else {
        print('Document niet gevonden: $docId');
      }
    } else {
      print('Ongeldig document ID');
    }
  }

  void _showExtendInputDialog(DocumentSnapshot doc, BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Voer de nieuwe eindtijd in'),
          content: TextField(
            controller: _endTimeController,
            keyboardType: TextInputType.datetime,
            decoration: InputDecoration(hintText: "Eindtijd (HH:mm)"),
          ),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () async {
                DateTime parsedTime =
                    DateFormat('HH:mm').parse(_endTimeController.text);
                DateTime now = DateTime.now();
                DateTime endTime = DateTime(now.year, now.month, now.day,
                    parsedTime.hour, parsedTime.minute);
                await doc.reference.update({
                  'endTime': endTime,
                });
                _endTimeController.clear();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showEndTimeInputDialog(LatLng location) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Voer de eindtijd in'),
          content: TextField(
            controller: _endTimeController,
            keyboardType: TextInputType.datetime,
            decoration: InputDecoration(hintText: "Eindtijd (HH:mm)"),
          ),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () async {
                DateTime parsedTime =
                    DateFormat('HH:mm').parse(_endTimeController.text);
                DateTime now = DateTime.now();
                DateTime endTime = DateTime(now.year, now.month, now.day,
                    parsedTime.hour, parsedTime.minute);
                await _saveParkingLocation(location, endTime);
                _endTimeController.clear();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveParkingLocation(LatLng location, DateTime endTime) async {
    CollectionReference parkingSpots =
        FirebaseFirestore.instance.collection('parkingSpots');

    await parkingSpots.add({
      'location': GeoPoint(location.latitude, location.longitude),
      'startTime': DateTime.now(),
      'endTime': endTime,
      'reserved': false,
      'userEmail': widget.userEmail,
      'nextUserEmail': null,
      'nextStartTime': null,
      'nextEndTime': null,
      'vehicle': activeVehicle,
      'nextVehicle': null,
      'previousUserEmail': null,
      'rated': false
    });
    setState(() {
      _userMarkers.removeLast();
    });
    Color markerColor = _calculateMarkerColor(endTime);
    Marker newMarker = Marker(
      width: 80.0,
      height: 80.0,
      point: location,
      builder: (ctx) => Container(
        child: IconButton(
          icon: Icon(Icons.location_on),
          color: markerColor,
          iconSize: 45.0,
          onPressed: () async {
            DocumentSnapshot<Object?>? doc;
            try {
              doc = (await parkingSpots
                      .where('location',
                          isEqualTo:
                              GeoPoint(location.latitude, location.longitude))
                      .get())
                  .docs
                  .firstWhereOrNull((element) => true);
            } catch (e) {
              print("Error retrieving document: $e");
            }

            if (doc != null) {
              _markerOnPressed(doc, markerColor);
            }
          },
        ),
      ),
    );
    setState(() {
      _firestoreMarkers.add(newMarker);
    });
  }

  Stream<QuerySnapshot> _getParkingLocations() {
    CollectionReference parkingSpots =
        FirebaseFirestore.instance.collection('parkingSpots');
    return parkingSpots.snapshots();
  }

  void _onReserveButtonPressed(
      DocumentSnapshot doc, BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Voer de eindtijd in voor uw reservering'),
              content: TextField(
                controller: _endTimeController,
                keyboardType: TextInputType.datetime,
                decoration: InputDecoration(hintText: "Eindtijd (HH:mm)"),
              ),
              actions: [
                TextButton(
                  child: Text('OK'),
                  onPressed: () async {
                    DateTime parsedTime =
                        DateFormat('HH:mm').parse(_endTimeController.text);
                    DateTime now = DateTime.now();
                    DateTime endTime = DateTime(now.year, now.month, now.day,
                        parsedTime.hour, parsedTime.minute);

                    await doc.reference.update({
                      'nextStartTime': doc['endTime'],
                      'nextEndTime': endTime,
                      'reserved': true,
                      'nextUserEmail': widget.userEmail,
                      'nextVehicle': widget.activeVehicle
                    });

                    _endTimeController.clear();

                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String> _getAddressFromLatLng(
      double latitude, double longitude) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);
      Placemark place = placemarks[0];
      return "${place.street}, ${place.postalCode} ${place.locality}";
    } catch (e) {
      print("Error retrieving address: $e");
      return "Address not found";
    }
  }

  Color _calculateMarkerColor(DateTime endTime) {
    Duration timeDifference = endTime.difference(DateTime.now());
    if (timeDifference.inHours >= 2) {
      return Colors.red;
    } else if (timeDifference.inHours >= 1) {
      return Colors.orange;
    } else if (timeDifference.inMinutes >= 30) {
      return Colors.yellow;
    } else {
      return Colors.green;
    }
  }

  void _addMarker(LatLng latlng) {
    // Controleer of er een activeVehicle is geselecteerd
    if (activeVehicle != null && activeVehicle!.isNotEmpty) {
      Marker marker = Marker(
        width: 80.0,
        height: 80.0,
        point: latlng,
        builder: (ctx) => Container(
          child: IconButton(
            icon: Icon(Icons.location_on),
            color: Colors.blue,
            iconSize: 45.0,
            onPressed: () {
              _markerOnPressed(null, Colors.blue, isNew: true);
            },
          ),
        ),
      );

      setState(() {
        _userMarkers.add(marker);
      });
    } else {
      // Toon een bericht als er geen activeVehicle is geselecteerd
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Geen voertuig geselecteerd'),
            content: Text(
                'Selecteer een voertuig voordat u een parkeerplaats markeert.'),
            actions: [
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  void _getCurrentLocation() async {
    try {
      Position position = await _geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      print('Huidige locatie: $position');
      LatLng point = LatLng(position.latitude, position.longitude);

      setState(() {
        _userMarkers.removeWhere((m) => m.point == point);
      });

      _addMarker(point);
    } catch (e) {
      print('Fout bij het ophalen van de huidige locatie: $e');
    }
  }
}

class RemainingTimeWidget extends StatefulWidget {
  final DateTime endTime;
  RemainingTimeWidget({Key? key, required this.endTime}) : super(key: key);

  @override
  _RemainingTimeWidgetState createState() => _RemainingTimeWidgetState();
}

class _RemainingTimeWidgetState extends State<RemainingTimeWidget> {
  Timer? _timer;
  String _remainingTime = '';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      _updateRemainingTime();
    });
    _updateRemainingTime();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateRemainingTime() {
    Duration remaining = widget.endTime.difference(DateTime.now());
    int hours = remaining.inHours;
    int minutes = remaining.inMinutes.remainder(60);

    setState(() {
      _remainingTime = '$hours uren en $minutes minuten';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(_remainingTime);
  }
}
