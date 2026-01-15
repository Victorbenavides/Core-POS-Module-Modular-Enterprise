import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/agenda_controller.dart';
import 'views/client_list_view.dart';
import 'views/appointment_view.dart';
import 'models/client.dart';
import 'models/appointment.dart';

import 'package:framework_as/core/customers/customer_provider.dart';
import 'package:framework_as/core/customers/customer_asset_loader.dart';
import 'package:framework_as/core/i18n/app_strings.dart';
import 'package:framework_as/core/ui/settings_button.dart';


class AgendaMainScreen extends StatefulWidget {
  const AgendaMainScreen({super.key});

  @override
  _AgendaMainScreenState createState() => _AgendaMainScreenState();
}

class _AgendaMainScreenState extends State<AgendaMainScreen> {
  late AgendaController controller;

  @override
  void initState() {
    super.initState();
    controller = AgendaController();

    final client1 =
        Client(name: "Juan Perez", email: "juan@email.com", phone: "123456789");
    final client2 =
        Client(name: "Ana López", email: "ana@email.com", phone: "987654321");

    controller.addClient(client1);
    controller.addClient(client2);

    controller.addAppointment(
      Appointment(
        client: client1,
        dateTime: DateTime.now().add(const Duration(days: 1)),
      ),
    );

    controller.addAppointment(
      Appointment(
        client: client2,
        dateTime: DateTime.now().add(const Duration(days: 2)),
        notes: "Primera consulta",
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();
    final customer = provider.config;
    final language = customer.language;
    final t = (String key) => AppStrings.text(key, language);

    return Scaffold(
      backgroundColor: customer.theme.background,
      appBar: AppBar(
        backgroundColor: customer.theme.primary,
        elevation: 4,
        centerTitle: true,
        title: Text(
          "${t("agenda.title")} — ${customer.name}",
          style: const TextStyle(color: Colors.white),
        ),
        leading: customer.logo.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.all(6.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    customer.branding.roundedCorners ? 8 : 0,
                  ),
                  child: CustomerAssets.image(
                    customer.logo,
                    fit: BoxFit.contain,
                  ),
                ),
              )
            : null,
        actions: const [
          SettingsButton(),
          SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(
                    customer.branding.roundedCorners ? 16 : 0,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClientListView(controller: controller),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: customer.theme.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(
                    customer.branding.roundedCorners ? 16 : 0,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: AppointmentView(controller: controller),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
