import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: Column(
        children: [
          const Expanded(child: MyMap2()),
          const SizedBox(height: 16),
          Expanded(
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

class MyMap2 extends StatefulWidget {
  const MyMap2({super.key});

  @override
  _MyMapState createState() => _MyMapState();
}

class _MyMapState extends State<MyMap2> {
  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        center: LatLng(51.230412, 4.416810),
        zoom: 17.0,
      ),
      layers: [
        TileLayerOptions(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: ['a', 'b', 'c'],
        ),
      ],
    );
  }
}
