import 'package:flutter/material.dart';
import '../../modules/pos_unicaja/pos_main.dart';
import '../../modules/agenda/agenda_main.dart';

class ModuleRouter {
  static Widget load(String moduleName) {
    switch (moduleName) {

      case "pos":
        return const PosMainScreen();

      case "agenda":
        return const AgendaMainScreen();

      default:
        return const Center(child: Text("Módulo no encontrado"));
    }
  }
}
