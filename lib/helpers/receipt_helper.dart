import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReceiptHelper {
  static final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  // Mendapatkan informasi toko dari SharedPreferences
  static Future<Map<String, String>> getStoreInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'storeName': prefs.getString('storeName') ?? 'Kasir-ku',
      'storeAddress': prefs.getString('storeAddress') ?? '',
      'storePhone': prefs.getString('storePhone') ?? '',
      'cashierName': prefs.getString('cashierName') ?? '',
    };
  }

  // Menyimpan informasi toko ke SharedPreferences
  static Future<void> saveStoreInfo({
    required String storeName,
    required String storeAddress,
    required String storePhone,
    required String cashierName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('storeName', storeName);
    await prefs.setString('storeAddress', storeAddress);
    await prefs.setString('storePhone', storePhone);
    await prefs.setString('cashierName', cashierName);
  }

  // Menampilkan dialog pemilihan printer
  static Future<void> showPrinterDialog({
    required BuildContext context,
    required String transactionId,
    required List<CartItem> cart,
    required double total,
    required double payment,
    required double change,
    bool isReprint = false,
  }) async {
    try {
      // Dapatkan informasi toko
      final storeInfo = await getStoreInfo();
      final storeName = storeInfo['storeName'] ?? 'Kasir-ku';
      final storeAddress = storeInfo['storeAddress'] ?? '';
      final storePhone = storeInfo['storePhone'] ?? '';
      final cashierName = storeInfo['cashierName'] ?? '';

      // Dapatkan daftar printer Bluetooth
      List<BluetoothDevice> devices = [];
      try {
        devices = await bluetooth.getBondedDevices();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error mendapatkan perangkat Bluetooth: $e')),
        );
        return;
      }

      // Tampilkan dialog pemilihan printer
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pilih Printer'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: devices.isEmpty
                  ? const Center(
                      child: Text('Tidak ada printer Bluetooth yang terpasang'))
                  : ListView.builder(
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        return ListTile(
                          title: Text(device.name ?? 'Unknown Device'),
                          subtitle: Text(device.address ?? ''),
                          onTap: () {
                            Navigator.pop(context);
                            connectAndPrint(
                              context: context,
                              device: device,
                              storeName: storeName,
                              storeAddress: storeAddress,
                              storePhone: storePhone,
                              cashierName: cashierName,
                              transactionId: transactionId,
                              cart: cart,
                              total: total,
                              payment: payment,
                              change: change,
                              isReprint: isReprint,
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                showReceiptPreview(
                  context: context,
                  storeName: storeName,
                  storeAddress: storeAddress,
                  storePhone: storePhone,
                  cashierName: cashierName,
                  transactionId: transactionId,
                  cart: cart,
                  total: total,
                  payment: payment,
                  change: change,
                  isReprint: isReprint,
                );
              },
              child: const Text('Preview'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error menyiapkan struk: $e')),
      );
    }
  }

  // Menghubungkan ke printer dan mencetak struk
  static Future<void> connectAndPrint({
    required BuildContext context,
    required BluetoothDevice device,
    required String storeName,
    required String storeAddress,
    required String storePhone,
    required String cashierName,
    required String transactionId,
    required List<CartItem> cart,
    required double total,
    required double payment,
    required double change,
    bool isReprint = false,
  }) async {
    try {
      // Tampilkan dialog loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: SingleChildScrollView(
            child: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Menyiapkan printer...'),
              ],
            ),
          ),
        ),
      );

      // Periksa apakah printer sudah terhubung
      bool? isConnected = await bluetooth.isConnected;

      // Jika belum terhubung, lakukan koneksi
      if (isConnected != true) {
        try {
          // Coba hubungkan ke printer
          await bluetooth.connect(device);

          // Verifikasi koneksi berhasil
          isConnected = await bluetooth.isConnected;
          if (isConnected != true) {
            throw Exception('Gagal terhubung ke printer');
          }
        } catch (e) {
          // Tutup dialog loading
          if (context.mounted) Navigator.pop(context);

          // Tampilkan pesan error
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error menghubungkan printer: $e')),
            );
          }
          return;
        }
      }

      // Tutup dialog loading
      if (context.mounted) Navigator.pop(context);

      // Cetak struk
      try {
        // Konversi dari CartItem ke format Map yang dibutuhkan oleh fungsi printThermalReceipt baru
        List<Map<String, dynamic>> transaksiItems = cart
            .map((item) => {
                  'nama': item.name,
                  'jumlah': item.quantity,
                  'harga': item.price,
                })
            .toList();

        await printThermalReceipt(
          tokoName: storeName,
          tokoAddress: storeAddress,
          tokoPhone: storePhone,
          kasirName: cashierName,
          transaksi: transaksiItems,
          total: total,
          bayar: payment,
          kembali: change,
        );

        // Tampilkan pesan sukses
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isReprint
                  ? 'Struk berhasil dicetak ulang!'
                  : 'Struk berhasil dicetak!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        // Tampilkan pesan error jika gagal mencetak
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal mencetak struk: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Tutup dialog loading jika masih terbuka
      if (context.mounted) {
        Navigator.pop(context);
        // Tampilkan pesan error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error mencetak: $e')),
        );
      }
    }
  }

  // Mencetak struk thermal
  static Future<void> printThermalReceipt({
    required String tokoName,
    required String tokoAddress,
    required String tokoPhone,
    required String kasirName,
    required List<Map<String, dynamic>> transaksi,
    required double total,
    required double bayar,
    required double kembali,
  }) async {
    bool? isConnected = await bluetooth.isConnected;
    if (isConnected == true) {
      // Header
      bluetooth.printCustom(tokoName, 3, 1);
      bluetooth.printCustom(tokoAddress, 1, 1);
      bluetooth.printCustom('Telp: $tokoPhone', 1, 1);
      bluetooth.printCustom('Kasir: $kasirName', 1, 1);
      bluetooth.printNewLine();

      // Info transaksi
      bluetooth.printCustom(
          'Tanggal: ${DateTime.now().toString().substring(0, 19)}', 1, 0);
      bluetooth.printCustom('--------------------------------', 1, 1);

      // Item list
      for (var item in transaksi) {
        String nama = item['nama'];
        int jumlah = item['jumlah'];
        double harga = item['harga'];
        double subtotal = jumlah * harga;

        bluetooth.printCustom(
            '$nama (${jumlah}x${harga.toStringAsFixed(0)})', 1, 0);
        bluetooth.printCustom('Rp ${subtotal.toStringAsFixed(0)}', 1, 2);
      }

      bluetooth.printCustom('--------------------------------', 1, 1);

      // Total, Bayar, Kembali
      bluetooth.printCustom(
          'TOTAL   :              Rp ${total.toStringAsFixed(0)}', 1, 0);
      bluetooth.printCustom(
          'BAYAR   :              Rp ${bayar.toStringAsFixed(0)}', 1, 0);
      bluetooth.printCustom(
          'KEMBALI :              Rp ${kembali.toStringAsFixed(0)}', 1, 0);

      bluetooth.printCustom('================================', 1, 1);

      // Footer
      bluetooth.printCustom('Barang yang sudah dibeli', 1, 1);
      bluetooth.printCustom('tidak dapat dikembalikan', 1, 1);
      bluetooth.printNewLine();
      bluetooth.printCustom('TERIMA KASIH', 2, 1);
      bluetooth.printCustom('Selamat berbelanja kembali', 1, 1);
      bluetooth.printCustom('================================', 1, 1);

      // Tambahkan spasi bawah agar bisa disobek
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.printNewLine();
    } else {
      print("Printer tidak terhubung");
    }
  }

  // Menampilkan preview struk
  static void showReceiptPreview({
    required BuildContext context,
    required String storeName,
    required String storeAddress,
    required String storePhone,
    required String cashierName,
    required String transactionId,
    required List<CartItem> cart,
    required double total,
    required double payment,
    required double change,
    bool isReprint = false,
  }) {
    // Konversi dari CartItem ke format Map yang dibutuhkan oleh fungsi generateReceiptText yang diperbarui
    List<Map<String, dynamic>> transaksiItems = cart
        .map((item) => {
              'nama': item.name,
              'jumlah': item.quantity,
              'harga': item.price,
            })
        .toList();

    final receiptText = generateReceiptText(
      tokoName: storeName,
      tokoAddress: storeAddress,
      tokoPhone: storePhone,
      kasirName: cashierName,
      transaksiId: transactionId,
      transaksi: transaksiItems,
      total: total,
      bayar: payment,
      kembali: change,
      isReprint: isReprint,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preview Struk'),
        content: SingleChildScrollView(
          child: Text(
            receiptText,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  // Menghasilkan teks struk
  static String generateReceiptText({
    required String tokoName,
    required String tokoAddress,
    required String tokoPhone,
    required String kasirName,
    required String transaksiId,
    required List<Map<String, dynamic>> transaksi,
    required double total,
    required double bayar,
    required double kembali,
    bool isReprint = false,
  }) {
    final now = DateTime.now();

    String receipt = '';
    receipt += '================================\n';
    receipt += '${tokoName.toUpperCase()}\n';
    if (tokoAddress.isNotEmpty) receipt += '$tokoAddress\n';
    if (tokoPhone.isNotEmpty) receipt += 'Telp: $tokoPhone\n';
    receipt += '================================\n';

    // Tambahkan teks cetak ulang jika diperlukan
    if (isReprint) {
      receipt += 'CETAK ULANG STRUK\n';
      receipt += 'Tanggal Cetak: ${now.toString().substring(0, 19)}\n';
    } else {
      receipt += 'Tanggal: ${now.toString().substring(0, 19)}\n';
    }

    receipt += 'Kasir: $kasirName\n';
    receipt += 'ID Transaksi: ${transaksiId.substring(0, 8)}\n';
    receipt += '--------------------------------\n';

    for (final item in transaksi) {
      String nama = item['nama'];
      int jumlah = item['jumlah'];
      double harga = item['harga'];
      double subtotal = jumlah * harga;

      receipt += '$nama\n';
      receipt += '${jumlah}x${harga.toStringAsFixed(0)}';
      receipt += ' = Rp ${subtotal.toStringAsFixed(0)}\n';
    }

    receipt += '--------------------------------\n';
    receipt += 'TOTAL    :                   Rp ${total.toStringAsFixed(0)}\n';
    receipt += 'BAYAR    :                   Rp ${bayar.toStringAsFixed(0)}\n';
    receipt +=
        'KEMBALI  :                   Rp ${kembali.toStringAsFixed(0)}\n';
    receipt += '================================\n';
    receipt += 'Barang yang sudah dibeli\n';
    receipt += 'tidak dapat dikembalikan\n';
    receipt += '\n';
    receipt += 'TERIMA KASIH\n';
    receipt += 'Selamat berbelanja kembali\n';
    receipt += '================================\n';

    return receipt;
  }
}

// Model CartItem untuk digunakan di helper
class CartItem {
  final String id;
  final String name;
  final double price;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
  });
}
