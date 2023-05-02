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

class HomePage extends StatelessWidget {
  final String userEmail;
  HomePage({Key? key, required this.userEmail}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: Column(
        children: [
          Expanded(child: MapPage(userEmail: userEmail)),
          const SizedBox(height: 5),
          Container(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.home),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.history),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.person),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {},
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

  MapPage({Key? key, required this.userEmail}) : super(key: key);

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
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(minutes: 1), (timer) {
      _checkExpiredParkingSpots();
    });
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
          'startTime': doc['nextStartTime'],
          'endTime': doc['nextEndTime'],
          'userEmail': doc['nextUserEmail'],
          'reserved': false,
          'nextStartTime': null,
          'nextEndTime': null,
          'nextUserEmail': null,
        });
      } else {
        await doc.reference.delete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Spot Finder'),
      ),
      body: _buildMap(),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        child: Icon(Icons.my_location),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildMap() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getParkingLocations(),
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
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
                markerColor = Colors.blue;
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
                  center: LatLng(51.1442944, 4.4662784),
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
                MarkerLayerOptions(markers: _firestoreMarkers + _userMarkers),
              ],
            );
        }
      },
    );
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
    if (isNew) {
      _showEndTimeInputDialog(location);
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Gegevens parkeerplaats',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Adres: $address'),
                SizedBox(height: 10),
                Text(
                  'Huidige sessie: ${startTime != null ? DateFormat('dd-MM-yyyy HH:mm').format(startTime) : 'Niet ingesteld'} - ${endTime != null ? DateFormat('dd-MM-yyyy HH:mm').format(endTime) : 'Niet ingesteld'}',
                ),
                endTime != null
                    ? RemainingTimeWidget(endTime: endTime)
                    : SizedBox.shrink(),
                Text('Gebruiker: $userEmail'),
                SizedBox(height: 15),
                nextUserEmail != null
                    ? Text(
                        'Volgende sessie: ${nextStartTime != null ? DateFormat('dd-MM-yyyy HH:mm').format(nextStartTime) : 'Niet ingesteld'} - ${nextEndTime != null ? DateFormat('dd-MM-yyyy HH:mm').format(nextEndTime) : 'Niet ingesteld'}',
                      )
                    : SizedBox.shrink(),
                nextUserEmail != null
                    ? Text('Volgende gebruiker: $nextUserEmail')
                    : SizedBox.shrink(),
              ],
            ),
            actions: [
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              doc != null
                  ? userEmail == widget.userEmail
                      ? TextButton(
                          child: Text('Verleng'),
                          onPressed: () {
                            _showExtendInputDialog(doc, context);
                          },
                        )
                      : TextButton(
                          child: Text('Reserveer'),
                          onPressed: () {
                            _onReserveButtonPressed(doc, context);
                          },
                        )
                  : SizedBox.shrink(),
            ],
          );
        },
      );
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
      'nextUserEmail': null, // Voeg dit toe
      'nextStartTime': null, // Voeg dit toe
      'nextEndTime': null, // Voeg dit toe
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
      _remainingTime = 'Resterende tijd: $hours uren en $minutes minuten';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(_remainingTime);
  }
}
