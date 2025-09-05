import 'package:hive/hive.dart';
import 'package:kasir_ku/models/item_model.dart';
import 'package:kasir_ku/repositories/item_repository.dart';
import 'package:kasir_ku/services/hive_service.dart';
import 'package:uuid/uuid.dart';

class LocalItemRepository implements ItemRepository {
  final Box<ItemModel> _itemBox = HiveService.getItemBox();
  final _uuid = Uuid();

  @override
  Future<List<ItemModel>> getAllItems() async {
    return _itemBox.values.toList();
  }

  @override
  Future<ItemModel?> getItemById(String id) async {
    return _itemBox.values.firstWhere(
      (item) => item.id == id,
      orElse: () => null as ItemModel,
    );
  }

  @override
  Future<List<ItemModel>> searchItems(String query) async {
    final lowercaseQuery = query.toLowerCase();
    return _itemBox.values
        .where((item) =>
            item.name.toLowerCase().contains(lowercaseQuery) ||
            (item.barcode != null &&
                item.barcode!.toLowerCase().contains(lowercaseQuery)))
        .toList();
  }

  @override
  Future<List<ItemModel>> getItemsByCategory(String category) async {
    return _itemBox.values
        .where((item) => item.category == category)
        .toList();
  }

  @override
  Future<List<String>> getAllCategories() async {
    return _itemBox.values
        .map((item) => item.category)
        .toSet()
        .toList();
  }

  @override
  Future<void> addItem(ItemModel item) async {
    await _itemBox.put(item.id, item);
  }

  @override
  Future<void> updateItem(ItemModel item) async {
    await _itemBox.put(item.id, item);
  }

  @override
  Future<void> deleteItem(String id) async {
    await _itemBox.delete(id);
  }

  @override
  Future<void> updateStock(String id, int newStock) async {
    final item = await getItemById(id);
    if (item != null) {
      item.stock = newStock;
      await updateItem(item);
    }
  }

  // Metode tambahan untuk sinkronisasi
  Future<void> syncFromFirestore(List<ItemModel> firestoreItems) async {
    // Hapus semua item yang tidak ada di Firestore
    final firestoreIds = firestoreItems.map((item) => item.id).toSet();
    final localIds = _itemBox.keys.cast<String>().toSet();
    
    final idsToDelete = localIds.difference(firestoreIds);
    for (final id in idsToDelete) {
      await _itemBox.delete(id);
    }

    // Update atau tambahkan item dari Firestore
    for (final item in firestoreItems) {
      await _itemBox.put(item.id, item);
    }
  }

  // Mendapatkan item yang belum disinkronkan
  Future<List<ItemModel>> getUnsyncedItems() async {
    // Implementasi ini bisa disesuaikan jika ada flag untuk item yang belum disinkronkan
    return [];
  }
}