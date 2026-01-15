class Role {
  final String name;
  final List<String> permissions;

  Role(this.name, this.permissions);
}

class PermissionManager {
  static final PermissionManager _instance = PermissionManager._internal();
  factory PermissionManager() => _instance;
  PermissionManager._internal();

  // Roles base (se pueden extender por cliente)
  final Map<String, Role> roles = {
    "admin": Role("admin", [
      "pos.read",
      "pos.write",
      "crm.full",
      "finance.full",
    ]),

    "user": Role("user", [
      "pos.read",
    ]),
  };

  bool hasPermission(String role, String permission) {
    return roles[role]?.permissions.contains(permission) ?? false;
  }
}
