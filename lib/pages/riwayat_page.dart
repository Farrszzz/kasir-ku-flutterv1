import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../helpers/receipt_helper.dart';
// Import CartItem dari receipt_helper.dart
import '../helpers/receipt_helper.dart' show CartItem;

class RiwayatPage extends StatefulWidget {
  const RiwayatPage({super.key});

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  // Menggunakan ReceiptHelper untuk mencetak struk
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
      ),
      body: Column(
        children: [
          // Summary Cards
          Container(
            padding: const EdgeInsets.all(16),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('transactions').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allTransactions = snapshot.data!.docs;
                final today = DateTime.now();
                final startOfDay = DateTime(today.year, today.month, today.day);

                double todayTotal = 0;
                double allTimeTotal = 0;
                int todayCount = 0;

                for (var doc in allTransactions) {
                  final data = doc.data() as Map<String, dynamic>;
                  final total = (data['total'] ?? 0).toDouble();
                  allTimeTotal += total;

                  final timestamp = data['date'] as Timestamp?;
                  if (timestamp != null) {
                    final date = timestamp.toDate();
                    if (date.isAfter(startOfDay)) {
                      todayTotal += total;
                      todayCount++;
                    }
                  }
                }

                return Row(
                  children: [
                    Expanded(
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFE5E5E5), width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.today,
                                size: 32,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Hari Ini',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                'Rp ${NumberFormat('#,###', 'id_ID').format(todayTotal)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              Text(
                                '$todayCount transaksi',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFE5E5E5), width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.all_inclusive,
                                size: 32,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Total Keseluruhan',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                'Rp ${NumberFormat('#,###', 'id_ID').format(allTimeTotal)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              Text(
                                '${allTransactions.length} transaksi',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Transaction List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('transactions')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Belum ada transaksi',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final timestamp = data['date'] as Timestamp?;
                    final items = data['items'] as List<dynamic>? ?? [];
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFFE5E5E5), width: 1),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor,
                          child: const Icon(
                            Icons.receipt,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          'Transaksi #${doc.id.substring(0, 8)}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (timestamp != null)
                              Text(
                                DateFormat('dd/MM/yyyy HH:mm', 'id_ID')
                                    .format(timestamp.toDate()),
                              ),
                            Text('${items.length} item'),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Rp ${NumberFormat('#,###', 'id_ID').format(data['total'] ?? 0)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                        onTap: () => _showTransactionDetail(context, doc.id, data),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetail(BuildContext context, String transactionId, Map<String, dynamic> data) {
    final timestamp = data['date'] as Timestamp?;
    final items = data['items'] as List<dynamic>? ?? [];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detail Transaksi #${transactionId.substring(0, 8)}', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (timestamp != null)
                Text(
                  'Tanggal: ${DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(timestamp.toDate())}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              const SizedBox(height: 16),
              const Text(
                'Item:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('${item['name']} x${item['quantity']}'),
                    ),
                    Text('Rp ${NumberFormat('#,###', 'id_ID').format(item['subtotal'] ?? 0)}'),
                  ],
                ),
              )),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    'Rp ${NumberFormat('#,###', 'id_ID').format(data['total'] ?? 0)}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Dibayar:'),
                  Text('Rp ${NumberFormat('#,###', 'id_ID').format(data['payment'] ?? 0)}'),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kembalian:'),
                  Text('Rp ${NumberFormat('#,###', 'id_ID').format(data['change'] ?? 0)}'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).primaryColor,
            ),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _printReceipt(transactionId, data);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Cetak Ulang'),
          ),
        ],
      ),
    );
  }

  // Mencetak struk menggunakan ReceiptHelper
  void _printReceipt(String transactionId, Map<String, dynamic> data) async {
    try {
      // Convert transaction data to cart items format
      final items = data['items'] as List<dynamic>? ?? [];
      final cartItems = items.map((item) => CartItem(
        id: item['id'] ?? '',
        name: item['name'] ?? '',
        price: (item['price'] ?? 0).toDouble(),
        quantity: item['quantity'] ?? 1,
      )).toList();
      
      final total = (data['total'] ?? 0).toDouble();
      final payment = (data['payment'] ?? 0).toDouble();
      final change = (data['change'] ?? 0).toDouble();
      
      // Menggunakan ReceiptHelper untuk menampilkan dialog printer dan mencetak struk
      await ReceiptHelper.showPrinterDialog(
        context: context, 
        transactionId: transactionId, 
        cart: cartItems, 
        total: total, 
        payment: payment, 
        change: change,
        isReprint: true, // Menandakan ini adalah cetak ulang
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error preparing receipt: $e')),
      );
    }
  }

  // Fungsi cetak struk telah dipindahkan ke receipt_helper.dart
}

// CartItem class telah dipindahkan ke receipt_helper.dart
