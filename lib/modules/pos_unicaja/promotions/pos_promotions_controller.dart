import 'package:flutter/foundation.dart';
import 'pos_promotion.dart';
import '../data/database/promotions_dao.dart';

class PosPromotionsController extends ChangeNotifier {
  PosPromotionsController._();
  static final PosPromotionsController instance = PosPromotionsController._();

  bool _loaded = false;
  bool _loading = false;
  final List<PosPromotion> _items = [];
  List<PosPromotion> get promotions => List.unmodifiable(_items);

  Future<void> ensureLoaded() async {
    if (_loaded || _loading) return;
    _loading = true;
    try {
      final list = await PromotionsDao.instance.getAll();
      _items..clear()..addAll(list);
      await _autoDisableExpiredIfNeeded();
    } catch(e) { if (kDebugMode) print("Error promos SQL: $e"); }
    finally { _loaded = true; _loading = false; notifyListeners(); }
  }

  Future<void> _autoDisableExpiredIfNeeded() async {
    final now = DateTime.now();
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].enabled && _items[i].endsAt != null && now.isAfter(_items[i].endsAt!)) {
        _items[i] = _items[i].copyWith(enabled: false);
        await PromotionsDao.instance.upsert(_items[i]);
      }
    }
  }

  Future<void> upsert(PosPromotion promo) async {
    await ensureLoaded();
    final normalized = promo; 
    final idx = _items.indexWhere((p) => p.id == normalized.id);
    if (idx >= 0) _items[idx] = normalized; else _items.add(normalized);
    _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
    await PromotionsDao.instance.upsert(normalized);
  }

  Future<void> remove(String id) async {
    await ensureLoaded();
    _items.removeWhere((p) => p.id == id);
    notifyListeners();
    await PromotionsDao.instance.delete(id);
  }
  
  Future<void> setEnabled(String id, bool enabled) async {
    await ensureLoaded();
    final idx = _items.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final updated = _items[idx].copyWith(enabled: enabled);
    _items[idx] = updated;
    notifyListeners();
    await PromotionsDao.instance.upsert(updated);
  }
}