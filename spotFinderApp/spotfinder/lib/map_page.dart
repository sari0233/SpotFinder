import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart' show InteractiveFlag;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    _showParkingLocations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Spot Finder'),
        actions: [
          IconButton(
            icon: Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: _buildMap(),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      options: MapOptions(
          center: LatLng(51.1267117, 4.4411588),
          zoom: 17.0,
          minZoom: 16.0,
          maxZoom: 18.0,
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
    });
  }

  Stream<QuerySnapshot> _getParkingLocations() {
    CollectionReference parkingSpots =
        FirebaseFirestore.instance.collection('parkingSpots');
    return parkingSpots.snapshots();
  }

  void _showParkingLocations() {
    _getParkingLocations().listen((querySnapshot) {
      querySnapshot.docChanges.forEach((change) {
        if (change.type == DocumentChangeType.added) {
          GeoPoint geoPoint = change.doc['location'];
          DateTime endTime = change.doc['endTime'].toDate();

          Marker marker = Marker(
            width: 80.0,
            height: 80.0,
            point: LatLng(geoPoint.latitude, geoPoint.longitude),
            builder: (ctx) => Container(
              child: IconButton(
                icon: Icon(Icons.location_on),
                color: Colors.red,
                iconSize: 45.0,
                onPressed: () {
                  print('Eindtijd: $endTime');
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

  void _getCurrentLocation() async {
    try {
      Position position = await _geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
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
                    content: Form(
                      key: _formKey,
                      child: TextFormField(
                        controller: _endTimeController,
                        decoration: InputDecoration(hintText: "Eindtijd"),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Voer een geldige eindtijd in';
                          }
                          try {
                            DateTime.parse(value);
                          } catch (e) {
                            return 'Ongeldig datumformaat';
                          }
                          return null;
                        },
                      ),
                    ),
                    actions: [
                      TextButton(
                        child: Text('OK'),
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            DateTime endTime =
                                DateTime.parse(_endTimeController.text);
                            _saveParkingLocation(point, endTime);
                            Navigator.of(context).pop();
                          }
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
