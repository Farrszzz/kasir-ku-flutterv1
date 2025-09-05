import 'package:hive/hive.dart';
import 'package:kasir_ku/models/transaction_model.dart';
import 'package:kasir_ku/repositories/transaction_repository.dart';
import 'package:kasir_ku/services/hive_service.dart';
import 'package:uuid/uuid.dart';

class LocalTransactionRepository implements TransactionRepository {
  final Box<TransactionModel> _transactionBox = HiveService.getTransactionBox();
  final _uuid = Uuid();

  @override
  Future<List<TransactionModel>> getAllTransactions() async {
    final transactions = _transactionBox.values.toList();
    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Urutkan dari terbaru
    return transactions;
  }

  @override
  Future<TransactionModel?> getTransactionById(String id) async {
    return _transactionBox.values.firstWhere(
      (transaction) => transaction.id == id,
      orElse: () => null as TransactionModel,
    );
  }

  @override
  Future<List<TransactionModel>> getTransactionsByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final transactions = _transactionBox.values
        .where((transaction) =>
            transaction.createdAt.isAfter(startOfDay) &&
            transaction.createdAt.isBefore(endOfDay))
        .toList();

    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Urutkan dari terbaru
    return transactions;
  }

  @override
  Future<void> addTransaction(TransactionModel transaction) async {
    await _transactionBox.put(transaction.id, transaction);
  }

  @override
  Future<void> updateTransaction(TransactionModel transaction) async {
    await _transactionBox.put(transaction.id, transaction);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await _transactionBox.delete(id);
  }

  // Metode tambahan untuk sinkronisasi
  
  // Mendapatkan transaksi yang belum disinkronkan (status pending)
  Future<List<TransactionModel>> getPendingTransactions() async {
    return _transactionBox.values
        .where((transaction) => transaction.status == SyncStatus.pending)
        .toList();
  }

  // Mengubah status transaksi menjadi synced
  Future<void> markAsSynced(String id) async {
    final transaction = await getTransactionById(id);
    if (transaction != null && transaction.status == SyncStatus.pending) {
      transaction.syncedAt = DateTime.now();
      final syncedTransaction = TransactionModel(
        id: transaction.id,
        items: transaction.items,
        total: transaction.total,
        payment: transaction.payment,
        change: transaction.change,
        cashier: transaction.cashier,
        createdAt: transaction.createdAt,
        status: SyncStatus.synced,
      );
      syncedTransaction.syncedAt = DateTime.now();
      await updateTransaction(syncedTransaction);
    }
  }
}