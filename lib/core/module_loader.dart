class ModuleLoader {
  // Lista de módulos activos en esta compilación
  static List<String> activeModules = [];

  static void loadModules(List<String> modules) {
    activeModules = modules;
  }

  static bool isActive(String module) {
    return activeModules.contains(module);
  }
}
