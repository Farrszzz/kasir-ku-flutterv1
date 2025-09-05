import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:kasir_ku/models/transaction_model.dart';
import 'package:kasir_ku/services/hive_service.dart';

// Interface untuk repository
abstract class TransactionRepository {
  Future<List<TransactionModel>> getAllTransactions();
  Future<TransactionModel?> getTransactionById(String id);
  Future<List<TransactionModel>> getTransactionsByDate(DateTime date);
  Future<void> addTransaction(TransactionModel transaction);
  Future<void> updateTransaction(TransactionModel transaction);
  Future<void> deleteTransaction(String id);
}

// Implementasi Firestore Repository
class FirestoreTransactionRepository implements TransactionRepository {
  final CollectionReference _transactionsCollection = 
      FirebaseFirestore.instance.collection('transactions');

  @override
  Future<List<TransactionModel>> getAllTransactions() async {
    final snapshot = await _transactionsCollection
        .orderBy('createdAt', descending: true)
        .get(const GetOptions(source: Source.serverAndCache));
    
    return snapshot.docs.map((doc) => 
        TransactionModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  @override
  Future<TransactionModel?> getTransactionById(String id) async {
    final doc = await _transactionsCollection.doc(id).get(const GetOptions(source: Source.serverAndCache));
    if (!doc.exists) return null;
    return TransactionModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
  }

  @override
  Future<List<TransactionModel>> getTransactionsByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    final snapshot = await _transactionsCollection
        .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
        .where('createdAt', isLessThanOrEqualTo: endOfDay)
        .orderBy('createdAt', descending: true)
        .get(const GetOptions(source: Source.serverAndCache));
    
    return snapshot.docs.map((doc) => 
        TransactionModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  @override
  Future<void> addTransaction(TransactionModel transaction) async {
    await _transactionsCollection.doc(transaction.id).set(transaction.toFirestore());
  }

  @override
  Future<void> updateTransaction(TransactionModel transaction) async {
    await _transactionsCollection.doc(transaction.id).update(transaction.toFirestore());
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await _transactionsCollection.doc(id).delete();
  }
}

// Implementasi Local Repository dengan Hive
class LocalTransactionRepository implements TransactionRepository {
  late Box<TransactionModel> _transactionBox;

  LocalTransactionRepository() {
    _transactionBox = HiveService.getTransactionBox();
  }

  @override
  Future<List<TransactionModel>> getAllTransactions() async {
    final transactions = _transactionBox.values.toList();
    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Descending order
    return transactions;
  }

  @override
  Future<TransactionModel?> getTransactionById(String id) async {
    return _transactionBox.get(id);
  }

  @override
  Future<List<TransactionModel>> getTransactionsByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    final transactions = _transactionBox.values.where((transaction) {
      return transaction.createdAt.isAfter(startOfDay) && 
             transaction.createdAt.isBefore(endOfDay);
    }).toList();
    
    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Descending order
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

  // Metode tambahan untuk mendapatkan transaksi dengan status pending
  Future<List<TransactionModel>> getPendingTransactions() async {
    return _transactionBox.values
        .where((transaction) => transaction.status == SyncStatus.pending)
        .toList();
  }

  // Metode untuk menandai transaksi sebagai synced
  Future<void> markTransactionAsSynced(String id) async {
    final transaction = await getTransactionById(id);
    if (transaction != null) {
      final syncedTransaction = transaction.markAsSynced();
      await updateTransaction(syncedTransaction);
    }
  }
}