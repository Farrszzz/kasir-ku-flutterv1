import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:kasir_ku/models/item_model.dart';
import 'package:kasir_ku/services/hive_service.dart';

// Interface untuk repository
abstract class ItemRepository {
  Future<List<ItemModel>> getAllItems();
  Future<ItemModel?> getItemById(String id);
  Future<List<ItemModel>> searchItems(String query);
  Future<List<ItemModel>> getItemsByCategory(String category);
  Future<List<String>> getAllCategories();
  Future<void> addItem(ItemModel item);
  Future<void> updateItem(ItemModel item);
  Future<void> deleteItem(String id);
  Future<void> updateStock(String id, int newStock);
}

// Implementasi Firestore Repository
class FirestoreItemRepository implements ItemRepository {
  final CollectionReference _itemsCollection = 
      FirebaseFirestore.instance.collection('items');

  @override
  Future<List<ItemModel>> getAllItems() async {
    final snapshot = await _itemsCollection
        .orderBy('createdAt', descending: true)
        .get(const GetOptions(source: Source.serverAndCache));
    return snapshot.docs.map((doc) => 
        ItemModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  @override
  Future<ItemModel?> getItemById(String id) async {
    final doc = await _itemsCollection.doc(id).get(const GetOptions(source: Source.serverAndCache));
    if (!doc.exists) return null;
    return ItemModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
  }

  @override
  Future<List<ItemModel>> searchItems(String query) async {
    final snapshot = await _itemsCollection
        .orderBy('createdAt', descending: true)
        .get(const GetOptions(source: Source.serverAndCache));
    final items = snapshot.docs.map((doc) => 
        ItemModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
    
    final lowercaseQuery = query.toLowerCase();
    return items.where((item) => 
        item.name.toLowerCase().contains(lowercaseQuery) || 
        (item.barcode != null && item.barcode!.toLowerCase().contains(lowercaseQuery)))
        .toList();
  }

  @override
  Future<List<ItemModel>> getItemsByCategory(String category) async {
    final snapshot = await _itemsCollection
        .where('category', isEqualTo: category)
        .get();
    
    return snapshot.docs.map((doc) => 
        ItemModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  @override
  Future<List<String>> getAllCategories() async {
    final snapshot = await _itemsCollection.get();
    final categories = snapshot.docs
        .map((doc) => (doc['category'] ?? "").toString())
        .where((cat) => cat.isNotEmpty)
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  @override
  Future<void> addItem(ItemModel item) async {
    await _itemsCollection.doc(item.id).set(item.toFirestore());
  }

  @override
  Future<void> updateItem(ItemModel item) async {
    await _itemsCollection.doc(item.id).update(item.toFirestore());
  }

  @override
  Future<void> deleteItem(String id) async {
    await _itemsCollection.doc(id).delete();
  }

  @override
  Future<void> updateStock(String id, int newStock) async {
    await _itemsCollection.doc(id).update({'stock': newStock});
  }
}

// Implementasi Local Repository dengan Hive
class LocalItemRepository implements ItemRepository {
  late Box<ItemModel> _itemBox;

  LocalItemRepository() {
    _itemBox = HiveService.getItemBox();
  }

  @override
  Future<List<ItemModel>> getAllItems() async {
    return _itemBox.values.toList();
  }

  @override
  Future<ItemModel?> getItemById(String id) async {
    return _itemBox.get(id);
  }

  @override
  Future<List<ItemModel>> searchItems(String query) async {
    final items = _itemBox.values.toList();
    final lowercaseQuery = query.toLowerCase();
    
    return items.where((item) => 
        item.name.toLowerCase().contains(lowercaseQuery) || 
        (item.barcode != null && item.barcode!.toLowerCase().contains(lowercaseQuery)))
        .toList();
  }

  @override
  Future<List<ItemModel>> getItemsByCategory(String category) async {
    final items = _itemBox.values.toList();
    return items.where((item) => item.category == category).toList();
  }

  @override
  Future<List<String>> getAllCategories() async {
    final items = _itemBox.values.toList();
    final categories = items
        .map((item) => item.category)
        .where((cat) => cat.isNotEmpty)
        .toSet()
        .toList();
    categories.sort();
    return categories;
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
    // Hapus semua item lokal dan ganti dengan data dari Firestore
    await _itemBox.clear();
    
    // Tambahkan semua item dari Firestore ke penyimpanan lokal
    for (var item in firestoreItems) {
      await _itemBox.put(item.id, item);
    }
  }
}