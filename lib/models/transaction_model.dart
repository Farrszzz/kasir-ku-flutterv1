import 'package:hive/hive.dart';
import 'package:kasir_ku/models/transaction_item_model.dart';

part 'transaction_model.g.dart';

@HiveType(typeId: 2)
enum SyncStatus {
  @HiveField(0)
  pending,

  @HiveField(1)
  synced,
}

@HiveType(typeId: 3)
class TransactionModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final List<TransactionItemModel> items;

  @HiveField(2)
  final double total;

  @HiveField(3)
  final double payment;

  @HiveField(4)
  final double change;

  @HiveField(5)
  final String cashier;

  @HiveField(6)
  final SyncStatus status;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  DateTime? syncedAt;

  TransactionModel({
    required this.id,
    required this.items,
    required this.total,
    required this.payment,
    required this.change,
    required this.cashier,
    required this.status,
    required this.createdAt,
    this.syncedAt,
  });

  // Konversi dari Firestore Document
  factory TransactionModel.fromFirestore(Map<String, dynamic> data, String docId) {
    final List<dynamic> itemsData = data['items'] ?? [];
    final List<TransactionItemModel> items = itemsData
        .map((item) => TransactionItemModel.fromMap(item))
        .toList();

    return TransactionModel(
      id: docId,
      items: items,
      total: (data['total'] ?? 0).toDouble(),
      payment: (data['payment'] ?? 0).toDouble(),
      change: (data['change'] ?? 0).toDouble(),
      cashier: data['cashier'] ?? '',
      status: SyncStatus.synced,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as dynamic).toDate()
          : DateTime.now(),
      syncedAt: data['syncedAt'] != null
          ? (data['syncedAt'] as dynamic).toDate()
          : DateTime.now(),
    );
  }

  // Konversi ke Map untuk Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'items': items.map((item) => item.toMap()).toList(),
      'total': total,
      'payment': payment,
      'change': change,
      'cashier': cashier,
      'date': createdAt, // untuk kompatibilitas dengan kode lama
      'createdAt': createdAt,
      'syncedAt': DateTime.now(),
    };
  }

  // Membuat salinan dengan nilai yang diperbarui
  TransactionModel copyWith({
    String? id,
    List<TransactionItemModel>? items,
    double? total,
    double? payment,
    double? change,
    String? cashier,
    SyncStatus? status,
    DateTime? createdAt,
    DateTime? syncedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      items: items ?? this.items,
      total: total ?? this.total,
      payment: payment ?? this.payment,
      change: change ?? this.change,
      cashier: cashier ?? this.cashier,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  // Mengubah status transaksi menjadi synced
  TransactionModel markAsSynced() {
    return copyWith(
      status: SyncStatus.synced,
      syncedAt: DateTime.now(),
    );
  }
}