import 'package:flutter/material.dart';
import '../controllers/agenda_controller.dart';
import '../models/client.dart';

class ClientListView extends StatelessWidget {
  final AgendaController controller;

  ClientListView({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: controller.clients.map((client) {
        return ListTile(
          title: Text(client.name),
          subtitle: Text('${client.email} | ${client.phone}'),
        );
      }).toList(),
    );
  }
}
