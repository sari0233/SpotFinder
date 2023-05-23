import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final CollectionReference _reservationCollection =
      FirebaseFirestore.instance.collection('parkingSpots');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Text(
              'Active Reservations',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _reservationCollection.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var reservationData =
                          snapshot.data!.docs[index].data() as Map<String, dynamic>;
                      var reservationId = snapshot.data!.docs[index].id;
                      var startTime = reservationData['startTime'];
                      var endTime = reservationData['endTime'];
                      var mail = reservationData['userEmail'];

                      var formattedStartTime =
                          DateFormat('dd-MM-yyyy HH:mm').format(startTime.toDate());
                      var formattedEndTime =
                          DateFormat('dd-MM-yyyy HH:mm').format(endTime.toDate());

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reservation ID: $reservationId',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text('Start time: $formattedStartTime'),
                                Text('End time: $formattedEndTime'),
                                Text('Email: $mail'),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                } else {
                  return const Center(
                    child: Text('No active reservations found.'),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
