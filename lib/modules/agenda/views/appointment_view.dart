import 'package:flutter/material.dart';
import '../controllers/agenda_controller.dart';
import '../models/appointment.dart';

class AppointmentView extends StatelessWidget {
  final AgendaController controller;

  AppointmentView({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: controller.appointments.map((a) {
        return ListTile(
          title: Text(a.client.name),
          subtitle: Text('${a.dateTime} - ${a.notes}'),
        );
      }).toList(),
    );
  }
}
