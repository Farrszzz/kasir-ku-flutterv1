import 'package:flutter/material.dart';
import 'package:kasir_ku/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppProvider extends ChangeNotifier {
  // Services
  late final SyncService syncService;
  
  // Status
  String _cashierName = '';
  
  // Getters
  String get cashierName => _cashierName;
  
  // Konstruktor
  AppProvider() {
    _initializeProvider();
  }
  
  // Inisialisasi provider
  Future<void> _initializeProvider() async {
    // Inisialisasi services
    syncService = SyncService();
    
    // Ambil nama kasir dari SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    _cashierName = prefs.getString('cashierName') ?? '';
    
    notifyListeners();
  }
  
  // Menyimpan nama kasir
  Future<void> setCashierName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cashierName', name);
    _cashierName = name;
    notifyListeners();
  }
  
  // Memulai sinkronisasi manual
  Future<bool> syncNow() async {
    try {
      await syncService.syncPendingOperations();
      return true;
    } catch (e) {
      print('Error during manual sync: $e');
      return false;
    }
  }
  
  // Memeriksa apakah ada transaksi yang belum disinkronkan
  bool hasPendingTransactions() {
    return syncService.hasPendingTransactions();
  }
  
  // Menutup resources
  @override
  void dispose() {
    syncService.dispose();
    super.dispose();
  }
}