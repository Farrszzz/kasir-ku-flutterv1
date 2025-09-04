import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/receipt_helper.dart';

class PengaturanPage extends StatefulWidget {
  const PengaturanPage({super.key});

  @override
  State<PengaturanPage> createState() => _PengaturanPageState();
}

class _PengaturanPageState extends State<PengaturanPage> {
  final TextEditingController _namaTokoController = TextEditingController();
  final TextEditingController _alamatController = TextEditingController();
  final TextEditingController _nomorHPController = TextEditingController();
  final TextEditingController _namaKasirController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    try {
      final storeInfo = await ReceiptHelper.getStoreInfo();
      setState(() {
        _namaTokoController.text = storeInfo['storeName'] ?? '';
        _alamatController.text = storeInfo['storeAddress'] ?? '';
        _nomorHPController.text = storeInfo['storePhone'] ?? '';
        _namaKasirController.text = storeInfo['cashierName'] ?? '';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading settings: $e')),
      );
    }
  }

  void _saveSettings() async {
    try {
      await ReceiptHelper.saveStoreInfo(
        storeName: _namaTokoController.text,
        storeAddress: _alamatController.text,
        storePhone: _nomorHPController.text,
        cashierName: _namaKasirController.text,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengaturan berhasil disimpan'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving settings: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informasi Toko',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _namaTokoController,
              decoration: const InputDecoration(labelText: 'Nama Toko'),
            ),
            TextField(
              controller: _alamatController,
              decoration: const InputDecoration(labelText: 'Alamat'),
            ),
            TextField(
              controller: _nomorHPController,
              decoration: const InputDecoration(labelText: 'Nomor HP'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: _namaKasirController,
              decoration: const InputDecoration(labelText: 'Nama Kasir'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.save),
              label: const Text('Simpan Pengaturan'),
              onPressed: _saveSettings,
            ),
            const SizedBox(height: 24),
            Text('Preview Struk:', style: Theme.of(context).textTheme.titleMedium),
            Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  '''-------------------------
${_namaTokoController.text}
${_alamatController.text}
${_nomorHPController.text}
Kasir: ${_namaKasirController.text}
-------------------------
Barang...
-------------------------
Total: Rp xxx
Dibayar: Rp xxx
Kembalian: Rp xxx
-------------------------
Barang yang sudah dibeli tidak dapat dikembalikan
TERIMA KASIH, Selamat berbelanja kembali
-------------------------''',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}