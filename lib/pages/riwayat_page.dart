import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../helpers/receipt_helper.dart' as receipt_helper;
import '../models/transaction_model.dart';
import '../models/transaction_item_model.dart';
import '../services/sync_service.dart';

class RiwayatPage extends StatefulWidget {
  const RiwayatPage({super.key});

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  SyncService? _syncService;

  @override
  void initState() {
    super.initState();
  }

  // Calculate totals from transaction snapshots
  Map<String, double> _calculateTotals(List<QueryDocumentSnapshot> docs) {
    double todayTotal = 0;
    double allTimeTotal = 0;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final total = (data['total'] ?? 0).toDouble();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      
      allTimeTotal += total;
      
      if (createdAt != null) {
        final transactionDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
        if (transactionDate.isAtSameMomentAs(today)) {
          todayTotal += total;
        }
      }
    }
    
    return {'today': todayTotal, 'allTime': allTimeTotal};
  }

  // Count pending transactions
  int _countPendingTransactions(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      return _syncService?.hasPendingWrites(doc) ?? false;
    }).length;
  }

  // Menggunakan ReceiptHelper untuk mencetak struk
  @override
  Widget build(BuildContext context) {
    _syncService = Provider.of<SyncService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        centerTitle: true,
        actions: [
          Consumer<SyncService>(
            builder: (context, syncService, child) {
              return Container(
                margin: const EdgeInsets.only(right: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: syncService.isOnline
                            ? (syncService.isSyncing ? Colors.orange : Colors.green)
                            : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      syncService.isOnline
                          ? (syncService.isSyncing ? 'Syncing' : 'Online')
                          : 'Offline',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
          // Pending operations count
          Consumer<SyncService>(
            builder: (context, syncService, child) {
              final pendingCount = syncService.pendingOperationsCount;
              if (pendingCount > 0) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sync_problem, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        '$pendingCount',
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // Manual sync button
          IconButton(
            icon: Consumer<SyncService>(
              builder: (context, syncService, child) {
                return syncService.isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync);
              },
            ),
            onPressed: () async {
              final success = await _syncService?.syncNow() ?? false;
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Sinkronisasi berhasil' : 'Sinkronisasi gagal'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _syncService?.getCollectionSnapshots('transactions'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final docs = snapshot.data?.docs ?? [];
          final totals = _calculateTotals(docs);
          final pendingCount = _countPendingTransactions(docs);
          final todayTransactionCount = docs.where((doc) {
            final data = doc.data();
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            if (createdAt != null) {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final transactionDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
              return transactionDate.isAtSameMomentAs(today);
            }
            return false;
          }).length;
          
          return Column(
            children: [
              // Summary Cards
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
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
                                    'Rp ${NumberFormat('#,###', 'id_ID').format(totals['today'])}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  Text(
                                    '$todayTransactionCount transaksi',
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
                                    'Rp ${NumberFormat('#,###', 'id_ID').format(totals['allTime'])}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  Text(
                                    '${docs.length} transaksi',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFFE5E5E5), width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.sync_problem,
                              size: 32,
                              color: pendingCount > 0 ? Colors.orange : Colors.green,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Status Sinkronisasi',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  Text(
                                    pendingCount > 0 
                                        ? '$pendingCount transaksi belum disinkronkan'
                                        : 'Semua transaksi telah disinkronkan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: pendingCount > 0 ? Colors.orange : Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (pendingCount > 0)
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final success = await _syncService?.syncNow() ?? false;
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(success ? 'Sinkronisasi berhasil' : 'Sinkronisasi gagal'),
                                        backgroundColor: success ? Colors.green : Colors.red,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.sync),
                                label: const Text('Sinkronkan'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Transaction List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await _syncService?.syncNow();
                  },
                  child: _buildTransactionList(docs),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTransactionList(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
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
            SizedBox(height: 8),
            Text(
              'Transaksi yang dibuat akan muncul di sini',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Sort transactions by date (newest first)
    final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
    sortedDocs.sort((a, b) {
      final aCreatedAt = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      final bCreatedAt = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      if (aCreatedAt == null || bCreatedAt == null) return 0;
      return bCreatedAt.compareTo(aCreatedAt);
    });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedDocs.length,
      itemBuilder: (context, index) {
        final doc = sortedDocs[index];
        final data = doc.data() as Map<String, dynamic>;
        final isPending = _syncService?.hasPendingWrites(doc) ?? false;
        final isFromCache = _syncService?.isFromCache(doc) ?? false;
        
        // Parse transaction data
        final transactionId = doc.id;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final total = (data['total'] ?? 0).toDouble();
        final payment = (data['payment'] ?? 0).toDouble();
        final change = (data['change'] ?? 0).toDouble();
        final itemsData = (data['items'] as List<dynamic>?) ?? [];
        final items = itemsData.map((item) => TransactionItemModel.fromMap(item)).toList();
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isPending ? Colors.orange.shade200 : 
                     isFromCache ? Colors.grey.shade200 : 
                     const Color(0xFFE5E5E5), 
              width: 1
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isPending ? Colors.orange : 
                             isFromCache ? Colors.grey :
                             Theme.of(context).primaryColor,
              child: Icon(
                isPending ? Icons.sync_problem : 
                isFromCache ? Icons.cloud_off :
                Icons.receipt,
                color: Colors.white,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Transaksi #${transactionId.substring(0, min(8, transactionId.length))}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                  ),
                ),
                if (isPending)
                  Tooltip(
                    message: 'Belum disinkronkan',
                    child: Icon(Icons.sync_problem, size: 16, color: Colors.orange),
                  )
                else if (isFromCache)
                  Tooltip(
                    message: 'Data dari cache offline',
                    child: Icon(Icons.cloud_off, size: 16, color: Colors.grey),
                  )
                else
                  Tooltip(
                    message: 'Tersinkronisasi',
                    child: Icon(Icons.cloud_done, size: 16, color: Colors.green),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(createdAt),
                ),
                Text('${items.length} item'),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rp ${NumberFormat('#,###', 'id_ID').format(total)}',
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
            onTap: () => _showTransactionDetail(context, transactionId, createdAt, total, payment, change, items, isPending, isFromCache),
          ),
        );
      },
    );
  }

  void _showTransactionDetail(
    BuildContext context, 
    String transactionId, 
    DateTime createdAt, 
    double total, 
    double payment, 
    double change, 
    List<TransactionItemModel> items, 
    bool isPending, 
    bool isFromCache
  ) {
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Detail Transaksi #${transactionId.substring(0, min(8, transactionId.length))}', 
                style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)
              ),
            ),
            if (isPending)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sync_problem, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Belum Sync',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_done, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Tersinkron',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
                ),
              ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tanggal: ${DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(createdAt)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              if (!isPending && !isFromCache)
                const Text(
                  'Status: Tersinkronisasi',
                  style: TextStyle(fontSize: 12, color: Colors.green),
                )
              else if (isFromCache)
                const Text(
                  'Status: Data dari cache offline',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
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
                      child: Text('${item.name} x${item.quantity}'),
                    ),
                    Text('Rp ${NumberFormat('#,###', 'id_ID').format(item.subtotal)}'),
                  ],
                ),
              )),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    'Rp ${NumberFormat('#,###', 'id_ID').format(total)}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Dibayar:'),
                  Text('Rp ${NumberFormat('#,###', 'id_ID').format(payment)}'),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kembalian:'),
                  Text('Rp ${NumberFormat('#,###', 'id_ID').format(change)}'),
                ],
              ),
              if (isPending)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Transaksi ini belum disinkronkan ke server. Akan otomatis disinkronkan saat terhubung ke internet.',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
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
          if (isPending && (_syncService?.isOnline ?? false))
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final success = await _syncService?.syncNow() ?? false;
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Sinkronisasi berhasil' : 'Sinkronisasi gagal'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Sinkronkan Sekarang'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _printReceipt(transactionId, total, payment, change, items);
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
  void _printReceipt(
    String transactionId, 
    double total, 
    double payment, 
    double change, 
    List<TransactionItemModel> items
  ) async {
    try {
      // Convert transaction items to cart items format
      final cartItems = items.map((item) => receipt_helper.CartItem(
        id: item.id,
        name: item.name,
        price: item.price,
        quantity: item.quantity,
      )).toList();
      
      // Menggunakan ReceiptHelper untuk menampilkan dialog printer dan mencetak struk
      await receipt_helper.ReceiptHelper.showPrinterDialog(
        context: context, 
        transactionId: transactionId, 
        cart: cartItems, 
        total: total, 
        payment: payment, 
        change: change,
        isReprint: true, // Menandakan ini adalah cetak ulang
      );
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error preparing receipt: $e')),
        );
      }
    }
  }

  // Fungsi cetak struk telah dipindahkan ke receipt_helper.dart
}

// CartItem class telah dipindahkan ke receipt_helper.dart
