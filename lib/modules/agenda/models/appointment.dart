import 'client.dart';

class Appointment {
  Client client;
  DateTime dateTime;
  String notes;

  Appointment({required this.client, required this.dateTime, this.notes = ""});
}
