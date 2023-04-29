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

class MapPage extends StatefulWidget {
  MapPage({Key? key}) : super(key: key);

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final GeolocatorPlatform _geolocator = GeolocatorPlatform.instance;
  List<Marker> _markers = [];
  final _endTimeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Timer? _timer;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _showParkingLocations();
    _timer = Timer.periodic(Duration(minutes: 1), (timer) {
      _checkExpiredParkingSpots();
      _updateMarkers();
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
      await doc.reference.delete();
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
    return FlutterMap(
      options: MapOptions(
          center: LatLng(51.1755721, 4.4318436),
          zoom: 17.0,
          minZoom: 16.0,
          maxZoom: 18.0,
          onTap: (_, latlng) {
            _addMarker(latlng);
          },
          interactiveFlags:
              InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom),
      layers: [
        TileLayerOptions(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: ['a', 'b', 'c'],
        ),
        MarkerLayerOptions(markers: _markers),
      ],
    );
  }

  Future<void> _saveParkingLocation(LatLng location, DateTime endTime) async {
    CollectionReference parkingSpots =
        FirebaseFirestore.instance.collection('parkingSpots');

    await parkingSpots.add({
      'location': GeoPoint(location.latitude, location.longitude),
      'endTime': endTime,
      'reserved': false,
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
                  'endTime': endTime,
                  'reserved': true,
                });

                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showParkingLocations() {
    _getParkingLocations().listen((querySnapshot) {
      querySnapshot.docChanges.forEach((change) async {
        // Maak deze functie async
        if (change.type == DocumentChangeType.added) {
          GeoPoint geoPoint = change.doc['location'];
          DateTime endTime = change.doc['endTime'].toDate();
          bool reserved = change.doc['reserved'];

          // Bepaal de kleur van de marker op basis van de resterende tijd
          Color markerColor = reserved
              ? Color.fromARGB(255, 86, 0, 198)
              : _calculateMarkerColor(endTime);

          // Haal het dichtstbijzijnde straatadres op
          String address = await _getAddressFromLatLng(
              geoPoint.latitude, geoPoint.longitude);

          Marker marker = Marker(
            width: 80.0,
            height: 80.0,
            point: LatLng(geoPoint.latitude, geoPoint.longitude),
            builder: (ctx) => Container(
              child: IconButton(
                icon: Icon(Icons.location_on),
                color: markerColor,
                iconSize: 45.0,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Eindtijd en adres'),
                        content: Text(
                            'Eindtijd: ${DateFormat('dd-MM-yyyy HH:mm').format(endTime)}\nAdres: $address'),
                        actions: [
                          TextButton(
                            child: Text('OK'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          TextButton(
                            child: Text('Reserveer'),
                            onPressed: () {
                              _onReserveButtonPressed(change.doc, context);
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          );

          setState(() {
            _markers.add(marker);
          });
        }
      });
    });
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

  void _updateMarkers() {
    setState(() {
      _markers = [];
    });
    _showParkingLocations();
  }

  void _addMarker(LatLng latlng) {
    Marker marker = Marker(
      width: 80.0,
      height: 80.0,
      point: latlng,
      builder: (ctx) => Container(
        child: IconButton(
          icon: Icon(Icons.location_on),
          color: Colors.red,
          iconSize: 45.0,
          onPressed: () {
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
                      onPressed: () {
                        DateTime parsedTime =
                            DateFormat('HH:mm').parse(_endTimeController.text);
                        DateTime now = DateTime.now();
                        DateTime endTime = DateTime(now.year, now.month,
                            now.day, parsedTime.hour, parsedTime.minute);
                        _saveParkingLocation(latlng, endTime);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );

    setState(() {
      _markers.add(marker);
    });
  }

  void _getCurrentLocation() async {
    try {
      Position position = await _geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      print('Huidige locatie: $position');
      LatLng point = LatLng(position.latitude, position.longitude);
      Marker marker = Marker(
        width: 80.0,
        height: 80.0,
        point: point,
        builder: (ctx) => Container(
          child: IconButton(
            icon: Icon(Icons.location_on),
            color: Colors.red,
            iconSize: 45.0,
            onPressed: () {
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
                        onPressed: () {
                          DateTime parsedTime = DateFormat('HH:mm')
                              .parse(_endTimeController.text);
                          DateTime now = DateTime.now();
                          DateTime endTime = DateTime(now.year, now.month,
                              now.day, parsedTime.hour, parsedTime.minute);
                          _saveParkingLocation(point, endTime);
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      );

      setState(() {
        _markers.add(marker);
      });
    } catch (e) {
      print('Fout bij het ophalen van de huidige locatie: $e');
    }
  }
}
