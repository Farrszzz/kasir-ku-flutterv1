import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final InternetConnectionChecker _connectionChecker = InternetConnectionChecker();
  
  // Stream untuk memantau perubahan koneksi
  late StreamController<bool> connectionStatusController;
  
  ConnectivityService() {
    connectionStatusController = StreamController<bool>.broadcast();
    // Inisialisasi stream dengan status koneksi saat ini
    checkConnection().then((hasConnection) {
      connectionStatusController.add(hasConnection);
    });
    
    // Memantau perubahan koneksi
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      checkConnection().then((hasConnection) {
        connectionStatusController.add(hasConnection);
      });
    });
  }

  // Memeriksa koneksi internet
  Future<bool> checkConnection() async {
    // Pertama periksa konektivitas jaringan
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return false;
    }
    
    // Kemudian periksa koneksi internet yang sebenarnya
    return await _connectionChecker.hasConnection;
  }

  // Mendapatkan stream status koneksi
  Stream<bool> get connectionStream => connectionStatusController.stream;

  // Menutup stream controller
  void dispose() {
    connectionStatusController.close();
  }
}