import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../helpers/receipt_helper.dart' as receipt_helper;
import '../helpers/receipt_helper.dart' show ReceiptHelper;
import '../models/transaction_model.dart';
import '../models/transaction_item_model.dart';
import '../models/item_model.dart';
import '../services/sync_service.dart';

class TransaksiPage extends StatefulWidget {
  const TransaksiPage({super.key});

  @override
  State<TransaksiPage> createState() => _TransaksiPageState();
}

class _TransaksiPageState extends State<TransaksiPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _paymentController = TextEditingController();
  final List<CartItem> _cart = [];
  double _total = 0;
  String _searchQuery = '';
  List<dynamic> _searchResults = [];

  // Menggunakan ReceiptHelper untuk cetak struk

  // ---------- CART ITEM (compact) ----------
  Widget _buildCompactCartItem(
      CartItem item, int index, BoxConstraints constraints) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: -4, vertical: -2),
      title: Text(
        item.name,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Rp ${NumberFormat('#,###', 'id_ID').format(item.price)}',
            style: const TextStyle(fontSize: 12),
          ),
          const Text(' × ', style: TextStyle(fontSize: 12)),
          IconButton(
            onPressed: () => _decreaseQuantity(index),
            icon: const Icon(Icons.remove_circle, size: 16),
            color: Colors.red,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
          Text(
            '${item.quantity}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          IconButton(
            onPressed: () => _increaseQuantity(index),
            icon: const Icon(Icons.add_circle, size: 16),
            color: Colors.green,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      trailing: IconButton(
        onPressed: () => _removeFromCart(index),
        icon: const Icon(Icons.delete, size: 16),
        color: Colors.red,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  // ---------- CART ITEM (normal) ----------
  Widget _buildNormalCartItem(CartItem item, int index) {
    return ListTile(
      title: Text(
        item.name,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      subtitle: Text(
        'Rp ${NumberFormat('#,###', 'id_ID').format(item.price)} × ${item.quantity}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _decreaseQuantity(index),
            icon: const Icon(Icons.remove_circle),
            color: Colors.red,
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${item.quantity}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: () => _increaseQuantity(index),
            icon: const Icon(Icons.add_circle),
            color: Colors.green,
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          IconButton(
            onPressed: () => _removeFromCart(index),
            icon: const Icon(Icons.delete),
            color: Colors.red,
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ---------- BUILD ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Transaksi'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;

            return Column(
              children: [
                // -------- Search Section --------
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: isLandscape ? 8 : 16),
                  color: Colors.grey[50],
                  width: double.infinity,
                  constraints: BoxConstraints(minHeight: isLandscape ? 60 : 80),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Cari barang (nama/barcode)...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.symmetric(
                                vertical: isLandscape ? 8 : 12, horizontal: 16),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.toLowerCase();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _scanBarcode,
                        icon: const Icon(Icons.qr_code_scanner),
                        tooltip: 'Scan Barcode',
                        style: IconButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.all(isLandscape ? 8 : 12),
                        ),
                        visualDensity:
                            isLandscape ? VisualDensity.compact : null,
                      ),
                    ],
                  ),
                ),

                // -------- Product List --------
                Expanded(
                  flex: isLandscape ? 2 : 3,
                  child: Consumer<SyncService>(
                    builder: (context, syncService, child) {
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: syncService.getCollectionSnapshots('items'),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}'));
                          }
                          
                          final docs = snapshot.data?.docs ?? [];
                          final products = docs.where((doc) {
                            final data = doc.data();
                            final name = (data['name'] ?? '').toString().toLowerCase();
                            final barcode = (data['barcode'] ?? '').toString().toLowerCase();
                            final stock = (data['stock'] ?? 0) as int;
                            
                            // Only show items with stock > 0
                            if (stock <= 0) return false;
                            
                            return _searchQuery.isEmpty ||
                                name.contains(_searchQuery) ||
                                barcode.contains(_searchQuery);
                          }).toList();

                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              final doc = products[index];
                              final data = doc.data();
                              final stock = (data['stock'] ?? 0) as int;
                              final isFromCache = syncService.isFromCache(doc);
                              final hasPendingWrites = syncService.hasPendingWrites(doc);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: hasPendingWrites ? Colors.orange.shade200 : 
                                           isFromCache ? Colors.grey.shade200 : 
                                           const Color(0xFFE5E5E5),
                                    width: 1,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    LayoutBuilder(
                                      builder: (context, itemCons) {
                                        return ListTile(
                                          dense: itemCons.maxWidth < 350,
                                          visualDensity: itemCons.maxWidth < 350
                                              ? const VisualDensity(
                                                  horizontal: -2, vertical: -2)
                                              : null,
                                          leading: CircleAvatar(
                                            backgroundColor: stock > 0
                                                ? Theme.of(context).colorScheme.primary
                                                : Colors.grey,
                                            child: Text(
                                              (data['name'] ?? '').toString().isNotEmpty
                                                  ? (data['name'] ?? '')
                                                      .toString()[0]
                                                      .toUpperCase()
                                                  : '?',
                                              style:
                                                  const TextStyle(color: Colors.white),
                                            ),
                                          ),
                                          title: Text(
                                            data['name'] ?? '',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('Stok: $stock'),
                                              if (data['barcode'] != null &&
                                                  data['barcode'].toString().isNotEmpty)
                                                Text(
                                                  'Barcode: ${data['barcode']}',
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                            ],
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.only(right: 8.0),
                                                child: Text(
                                                  'Rp ${NumberFormat('#,###', 'id_ID').format(data['price'] ?? 0)}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                onPressed: stock > 0
                                                    ? () => _addToCartFromDoc(doc)
                                                    : null,
                                                icon:
                                                    const Icon(Icons.add_shopping_cart),
                                                iconSize: 20,
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                    // Sync status indicator
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: hasPendingWrites ? Colors.orange :
                                                 isFromCache ? Colors.grey :
                                                 Colors.green,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          hasPendingWrites ? Icons.sync_problem :
                                          isFromCache ? Icons.cloud_off :
                                          Icons.cloud_done,
                                          color: Colors.white,
                                          size: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),

                // -------- Cart Section --------
                Expanded(
                  flex: isLandscape ? 3 : 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: Border(top: BorderSide(color: Colors.grey[300]!)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Keranjang (${_cart.length} item)',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              if (_cart.isNotEmpty)
                                TextButton(
                                  onPressed: _clearCart,
                                  child: const Text('Kosongkan'),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _cart.isEmpty
                              ? const Center(child: Text('Keranjang kosong'))
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  itemCount: _cart.length,
                                  itemBuilder: (context, index) {
                                    final item = _cart[index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: LayoutBuilder(
                                        builder: (context, cons) {
                                          final isNarrow = cons.maxWidth < 350;
                                          return isLandscape || isNarrow
                                              ? _buildCompactCartItem(
                                                  item, index, cons)
                                              : _buildNormalCartItem(
                                                  item, index);
                                        },
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                // -------- Checkout Section --------
                Container(
                  padding: EdgeInsets.all(isLandscape ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: isLandscape
                      ? Row(
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total:',
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Rp ${NumberFormat('#,###', 'id_ID').format(_total)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 200,
                              child: ElevatedButton(
                                onPressed: _cart.isNotEmpty
                                    ? _showCheckoutDialog
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  backgroundColor: Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Checkout',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total:',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Text(
                                  'Rp ${NumberFormat('#,###', 'id_ID').format(_total)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _cart.isNotEmpty
                                    ? _showCheckoutDialog
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Checkout',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------- SCAN ----------
  void _scanBarcode() async {
    try {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => const BarcodeScannerPage(),
        ),
      );

      if (result != null && mounted) {
        setState(() {
          _searchController.text = result;
          _searchQuery = result.toLowerCase();
        });
        _findAndAddProductByBarcode(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning barcode: $e')),
        );
      }
    }
  }

  // ---------- FIND by BARCODE ----------
  void _findAndAddProductByBarcode(String barcode) async {
    try {
      final syncService = Provider.of<SyncService>(context, listen: false);
      final snapshot = await syncService.getCollectionSnapshots('items').first;
      
      QueryDocumentSnapshot<Map<String, dynamic>>? foundDoc;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['barcode'] != null && 
            data['barcode'].toString().toLowerCase() == barcode.toLowerCase()) {
          foundDoc = doc;
          break;
        }
      }

      if (foundDoc != null) {
        final data = foundDoc.data() as Map<String, dynamic>;
        final stock = (data['stock'] ?? 0) as int;
        
        if (stock > 0) {
          _addToCartFromDoc(foundDoc);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${data['name']} ditambahkan ke keranjang'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Barang ditemukan tapi stok habis'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Barang tidak ditemukan'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error mencari barang: $e')),
        );
      }
    }
  }
  
  void _addToCartFromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      final existingIndex = _cart.indexWhere((cartItem) => cartItem.id == doc.id);
      if (existingIndex >= 0) {
        _cart[existingIndex].quantity += 1;
      } else {
        _cart.add(
          CartItem(
            id: doc.id,
            name: data['name'] ?? '',
            price: (data['price'] ?? 0).toDouble(),
            quantity: 1,
          ),
        );
      }
      _updateTotal();
    });
  }

  // ---------- CART OPS ----------
  void _addToCart(String id, Map<String, dynamic> data) {
    setState(() {
      final existingIndex = _cart.indexWhere((item) => item.id == id);
      if (existingIndex >= 0) {
        _cart[existingIndex].quantity += 1;
      } else {
        _cart.add(
          CartItem(
            id: id,
            name: data['name'],
            price: data['price'].toDouble(),
            quantity: 1,
          ),
        );
      }
      _updateTotal();
    });
  }

  void _increaseQuantity(int index) {
    setState(() {
      _cart[index].quantity++;
      _updateTotal();
    });
  }

  void _decreaseQuantity(int index) {
    setState(() {
      if (_cart[index].quantity > 1) {
        _cart[index].quantity--;
      } else {
        _cart.removeAt(index);
      }
      _updateTotal();
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cart.removeAt(index);
      _updateTotal();
    });
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _total = 0;
    });
  }

  void _updateTotal() {
    _total = _cart.fold(0, (sum, item) => sum + (item.price * item.quantity));
  }

  // ---------- CHECKOUT ----------
  void _showCheckoutDialog() {
    _paymentController.clear();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final payment = double.tryParse(_paymentController.text) ?? 0;
          final change = payment >= _total ? payment - _total : 0;

          return AlertDialog(
            title: Text('Checkout', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total: Rp ${NumberFormat('#,###', 'id_ID').format(_total)}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _paymentController,
                    decoration: InputDecoration(
                      labelText: 'Nominal Pembayaran',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                      ),
                      prefixText: 'Rp ',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  if (payment > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: payment >= _total
                            ? Colors.green[50]
                            : Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: payment >= _total ? Colors.green : Colors.red,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Dibayar:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                  'Rp ${NumberFormat('#,###', 'id_ID').format(payment)}'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Kembalian:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                'Rp ${NumberFormat('#,###', 'id_ID').format(change)}',
                                style: TextStyle(
                                  color: payment >= _total
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (payment < _total)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Kurang Rp ${NumberFormat('#,###', 'id_ID').format(_total - payment)}',
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                ),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: payment >= _total ? _processCheckout : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Bayar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _processCheckout() async {
    final payment = double.tryParse(_paymentController.text) ?? 0;

    if (payment < _total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal pembayaran kurang')),
      );
      return;
    }

    final change = payment - _total;
    final transactionId = const Uuid().v4();
    final syncService = Provider.of<SyncService>(context, listen: false);
    
    try {
      // Prepare transaction data
      final transactionItems = _cart.map((item) => {
        'id': item.id,
        'name': item.name,
        'price': item.price,
        'quantity': item.quantity,
        'subtotal': item.price * item.quantity,
      }).toList();

      final transactionData = {
        'items': transactionItems,
        'total': _total,
        'payment': payment,
        'change': change,
        'cashier': 'Kasir', // You can get this from user preferences
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      // Add transaction to sync queue
      await syncService.addPendingOperation(
        collection: 'transactions',
        type: OperationType.create,
        documentId: transactionId,
        data: transactionData,
      );
      
      // Update stock for each item
      for (final item in _cart) {
        // Get current item data from Firestore
        final itemSnapshot = await syncService.getCollectionSnapshots('items')
            .map((snapshot) => snapshot.docs.firstWhere(
                (doc) => doc.id == item.id,
                orElse: () => throw Exception('Item not found')))
            .first;
        
        final currentData = itemSnapshot.data();
        final currentStock = (currentData['stock'] ?? 0) as int;
        final newStock = currentStock - item.quantity;
        
        // Update item stock
        final updatedItemData = Map<String, dynamic>.from(currentData);
        updatedItemData['stock'] = newStock;
        updatedItemData['updatedAt'] = Timestamp.fromDate(DateTime.now());
        
        await syncService.addPendingOperation(
          collection: 'items',
          type: OperationType.update,
          documentId: item.id,
          data: updatedItemData,
        );
      }
      
      print('Transaksi ${transactionId} berhasil disimpan dan akan disinkronkan');
    } catch (e) {
      print('Error saat memproses checkout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saat memproses checkout: $e')),
        );
      }
      return;
    }

    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Transaksi Berhasil', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Total: Rp ${NumberFormat('#,###', 'id_ID').format(_total)}'),
              Text(
                  'Dibayar: Rp ${NumberFormat('#,###', 'id_ID').format(payment)}'),
              Text(
                'Kembalian: Rp ${NumberFormat('#,###', 'id_ID').format(change)}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _printReceipt(transactionId, _cart, _total, payment, change);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).primaryColor,
            ),
            child: const Text('Cetak Struk'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _cart.clear();
                _total = 0;
                _searchController.clear();
                _searchQuery = '';
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  // ---------- PRINT ----------
  void _printReceipt(String transactionId, List<CartItem> cart, double total,
      double payment, double change) async {
    try {
      // Konversi CartItem dari transaksi_page.dart ke CartItem dari receipt_helper.dart
      final receiptCart = cart.map((item) => 
        receipt_helper.CartItem(
          id: item.id,
          name: item.name,
          price: item.price,
          quantity: item.quantity,
        )
      ).toList();
      
      // Menggunakan ReceiptHelper untuk menampilkan dialog printer
      ReceiptHelper.showPrinterDialog(
        context: context,
        transactionId: transactionId,
        cart: receiptCart,
        total: total,
        payment: payment,
        change: change,
        isReprint: false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error menyiapkan struk: $e')),
      );
    }
  }

  // Fungsi cetak struk telah dipindahkan ke receipt_helper.dart
}

// ---------- MODELS ----------
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

// ---------- BARCODE ----------
class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final MobileScannerController controller = MobileScannerController();
  bool _isScanning = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.flash_on, color: Colors.white),
            iconSize: 32.0,
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: MobileScanner(
              controller: controller,
              onDetect: (capture) {
                if (!_isScanning) return;
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null &&
                      barcode.rawValue!.isNotEmpty) {
                    _isScanning = false;
                    Navigator.pop(context, barcode.rawValue!);
                    return;
                  }
                }
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'Arahkan kamera ke barcode',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
