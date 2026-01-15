// lib/modules/pos_unicaja/widgets/pos_product_search.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:framework_as/modules/pos_unicaja/models/product.dart';

class PosProductSearchScreen extends StatefulWidget {
  final List<Product> products;

  const PosProductSearchScreen({
    super.key,
    required this.products,
  });

  @override
  State<PosProductSearchScreen> createState() => _PosProductSearchScreenState();
}

class _PosProductSearchScreenState extends State<PosProductSearchScreen> {
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _searchFocus = FocusNode();
  final TextEditingController _queryCtrl = TextEditingController();

  String _query = "";
  int _selectedIndex = -1;

  @override
  void initState() {
    super.initState();

    // Focus al input al abrir la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchFocus.dispose();
    _queryCtrl.dispose();
    super.dispose();
  }

  void _ensureSelectedVisible() {
    if (!_scrollCtrl.hasClients) return;
    if (_selectedIndex < 0) return;

    // Aproximación razonable para ListTile (72px)
    final target = (_selectedIndex * 72.0).clamp(
      0.0,
      _scrollCtrl.position.maxScrollExtent,
    );

    _scrollCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();

    final filtered = widget.products.where((p) {
      final name = p.name.toLowerCase();
      final barcode = p.barcode.toLowerCase();
      return name.contains(q) || barcode.contains(q);
    }).toList();

    // ✅ Clampeo correcto SIN mutar estado dentro de build
    final int newIndex = filtered.isEmpty
        ? -1
        : (_selectedIndex < 0 ? 0 : _selectedIndex.clamp(0, filtered.length - 1));

    if (newIndex != _selectedIndex) {
      // actualiza después del frame para no romper el build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedIndex = newIndex);
      });
    }

    void moveSelection(int delta) {
      if (filtered.isEmpty) return;
      final next = (_selectedIndex + delta).clamp(0, filtered.length - 1);
      if (next == _selectedIndex) return;

      setState(() => _selectedIndex = next);
      _ensureSelectedVisible();
    }

    void selectCurrent() {
      if (filtered.isEmpty) return;
      if (_selectedIndex < 0 || _selectedIndex >= filtered.length) return;

      // ✅ MUY IMPORTANTE: regresar el producto seleccionado
      Navigator.of(context).pop<Product>(filtered[_selectedIndex]);
    }

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.escape): const _SearchEscapeIntent(),
        LogicalKeySet(LogicalKeyboardKey.f10): const _SearchEscapeIntent(), // ✅ NUEVO
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const _SearchDownIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const _SearchUpIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const _SearchEnterIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const _SearchEnterIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SearchEscapeIntent: CallbackAction<_SearchEscapeIntent>(
            onInvoke: (_) {
              Navigator.of(context).pop<Product?>(null);
              return null;
            },
          ),
          _SearchDownIntent: CallbackAction<_SearchDownIntent>(
            onInvoke: (_) {
              moveSelection(1);
              return null;
            },
          ),
          _SearchUpIntent: CallbackAction<_SearchUpIntent>(
            onInvoke: (_) {
              moveSelection(-1);
              return null;
            },
          ),
          _SearchEnterIntent: CallbackAction<_SearchEnterIntent>(
            onInvoke: (_) {
              selectCurrent();
              return null;
            },
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text("Buscar producto"),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _queryCtrl,
                  focusNode: _searchFocus,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: "Nombre o código de barras",
                    border: OutlineInputBorder(),
                  ),
                  // ✅ Enter selecciona el producto aunque el TextField se trague el shortcut
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => selectCurrent(),
                  onChanged: (v) {
                    setState(() {
                      _query = v;
                      _selectedIndex = -1; // se recalcula/clamp arriba
                    });
                  },
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text("Sin resultados."))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final p = filtered[i];

                          return ListTile(
                            selected: i == _selectedIndex,
                            title: Text(p.name),
                            subtitle: Text(
                              'Precio: \$${p.salePrice.toStringAsFixed(2)}'
                              '${p.isWeighed ? " • por ${p.unit.toLowerCase()}" : ""}',
                            ),
                            // ✅ Tap siempre devuelve el producto
                            onTap: () => Navigator.of(context).pop<Product>(p),
                            onLongPress: () => setState(() => _selectedIndex = i),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Intents internos para shortcuts
class _SearchEscapeIntent extends Intent {
  const _SearchEscapeIntent();
}

class _SearchDownIntent extends Intent {
  const _SearchDownIntent();
}

class _SearchUpIntent extends Intent {
  const _SearchUpIntent();
}

class _SearchEnterIntent extends Intent {
  const _SearchEnterIntent();
}
