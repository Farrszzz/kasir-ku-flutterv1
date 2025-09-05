import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:kasir_ku/models/item_model.dart';
import 'package:kasir_ku/models/transaction_model.dart';
import 'package:kasir_ku/models/transaction_item_model.dart';

class HiveService {
  static const String itemBoxName = 'items';
  static const String transactionBoxName = 'transactions';

  // Inisialisasi Hive
  static Future<void> init() async {
    // Inisialisasi Hive dengan direktori penyimpanan
    final appDocumentDir = await path_provider.getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);
    
    // Registrasi adapter
    Hive.registerAdapter(ItemModelAdapter());
    Hive.registerAdapter(TransactionItemModelAdapter());
    Hive.registerAdapter(TransactionModelAdapter());
    Hive.registerAdapter(SyncStatusAdapter());
    
    // Buka box
    await Hive.openBox<ItemModel>(itemBoxName);
    await Hive.openBox<TransactionModel>(transactionBoxName);
  }

  // Mendapatkan box items
  static Box<ItemModel> getItemBox() {
    return Hive.box<ItemModel>(itemBoxName);
  }

  // Mendapatkan box transactions
  static Box<TransactionModel> getTransactionBox() {
    return Hive.box<TransactionModel>(transactionBoxName);
  }

  // Menutup semua box
  static Future<void> closeBoxes() async {
    await Hive.close();
  }
}