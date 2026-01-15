import '../models/client.dart';
import '../models/appointment.dart';

class AgendaController {
  List<Client> clients = [];
  List<Appointment> appointments = [];

  void addClient(Client c) => clients.add(c);

  void removeClient(Client c) => clients.remove(c);

  void addAppointment(Appointment a) => appointments.add(a);

  void removeAppointment(Appointment a) => appointments.remove(a);
}
