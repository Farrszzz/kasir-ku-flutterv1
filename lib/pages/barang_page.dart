import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:kasir_ku/pages/barcode_scanner_page.dart';
import 'package:kasir_ku/models/item_model.dart';
import 'package:kasir_ku/services/sync_service.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

// ====================== HALAMAN UTAMA BARANG ======================

class BarangPage extends StatefulWidget {
  BarangPage({Key? key}) : super(key: key);

  @override
  _BarangPageState createState() => _BarangPageState();
}

class _BarangPageState extends State<BarangPage> {
  String searchQuery = "";
  String selectedCategory = "All";
  SyncService? _syncService;
  
  @override
  void initState() {
    super.initState();
  }
  
  // Get categories from Firestore snapshots
  Stream<List<String>> _getCategoriesStream() {
    return _syncService?.getCollectionSnapshots('items') 
        .map((snapshot) {
          final categories = <String>{};
          for (final doc in snapshot.docs) {
            final data = doc.data();
            if (data['category'] != null) {
              categories.add(data['category'].toString());
            }
          }
          return ['All', ...categories.toList()];
        }) ?? Stream.value(['All']);
  }

  // format currency
  String formatCurrency(num value) {
    final format = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp');
    return format.format(value);
  }

  // open form tambah / edit barang
  void _openForm({ItemModel? item, DocumentSnapshot? productSnapshot}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9, // Make form wider
          child: AddProductForm(product: item, productSnapshot: productSnapshot),
        ),
      ),
    );
  }

  // hapus produk
  void _deleteProduct(String id) async {
    try {
      // Add delete operation to sync queue
      await _syncService?.addPendingOperation(
        collection: 'items',
        type: OperationType.delete,
        documentId: id,
        data: {},
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produk berhasil dihapus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus produk: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncService = Provider.of<SyncService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text("Product Management"),
        centerTitle: true,
        actions: [
          // Sync status indicator
          StreamBuilder<bool>(
            stream: _syncService?.connectionStream,
            initialData: _syncService?.isOnline ?? false,
            builder: (context, snapshot) {
              final isOnline = snapshot.data ?? false;
              return Container(
                margin: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOnline ? Icons.cloud_done : Icons.cloud_off,
                      color: isOnline ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOnline ? Colors.green : Colors.grey,
                      ),
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
      body: Column(
        children: [
          // search bar
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: "Search product or barcode...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  searchQuery = val.toLowerCase();
                });
              },
            ),
          ),

          // filter by category
          StreamBuilder<List<String>>(
            stream: _getCategoriesStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final categories = snapshot.data!;
              
              // Ensure selectedCategory is valid
              if (!categories.contains(selectedCategory)) {
                selectedCategory = 'All';
              }
              
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: DropdownButtonFormField<String>(
                  value: selectedCategory,
                  items: categories
                      .map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat),
                          ))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      selectedCategory = val!;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: "Filter by Category",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                    ),
                  ),
                ),
              );
            },
          ),

          SizedBox(height: 10),

          // list produk
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _syncService?.getCollectionSnapshots('items'),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final docs = snapshot.data?.docs ?? [];
                
                // Convert to ItemModel and filter
                final filteredItems = docs.where((doc) {
                  final data = doc.data();
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final barcode = (data['barcode'] ?? '').toString().toLowerCase();
                  final category = (data['category'] ?? '').toString();

                  final matchesSearch = searchQuery.isEmpty ||
                      name.contains(searchQuery.toLowerCase()) ||
                      barcode.contains(searchQuery.toLowerCase());

                  final matchesCategory = selectedCategory == "All" ||
                      category == selectedCategory;

                  return matchesSearch && matchesCategory;
                }).toList();

                if (filteredItems.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Tidak ada produk', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await _syncService?.syncNow();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final doc = filteredItems[index];
                      final data = doc.data();
                      final isFromCache = _syncService?.isFromCache(doc) ?? false;
                      final hasPendingWrites = _syncService?.hasPendingWrites(doc) ?? false;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: hasPendingWrites ? Colors.orange.shade200 : const Color(0xFFE5E5E5), 
                            width: 1
                          ),
                        ),
                        child: Stack(
                          children: [
                            ListTile(
                              title: Text(data['name'] ?? ''),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Price: ${formatCurrency(data['price'] ?? 0)}",
                                  ),
                                  Text(
                                    "Stock: ${data['stock'] ?? 0} | Category: ${data['category'] ?? ''}",
                                  ),
                                  if (data['barcode'] != null && data['barcode'].toString().isNotEmpty)
                                    Text(
                                      "Barcode: ${data['barcode']}",
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _openForm(productSnapshot: doc),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteProduct(doc.id),
                                  ),
                                ],
                              ),
                            ),
                            // Sync status indicator
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (hasPendingWrites)
                                    Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.sync_problem,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    )
                                  else if (isFromCache)
                                    Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.cloud_off,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.cloud_done,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        label: Text("Tambah Barang"),
        icon: Icon(Icons.add),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ====================== FORM TAMBAH / EDIT PRODUK ======================

class AddProductForm extends StatefulWidget {
  final ItemModel? product;
  final DocumentSnapshot? productSnapshot;
  
  AddProductForm({this.product, this.productSnapshot});

  @override
  _AddProductFormState createState() => _AddProductFormState();
}

class _AddProductFormState extends State<AddProductForm> {
  final _formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final categoryCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final stockCtrl = TextEditingController();
  final barcodeCtrl = TextEditingController();

  List<String> categorySuggestions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();

    // isi data jika edit
    if (widget.product != null) {
      final p = widget.product!;
      nameCtrl.text = p.name;
      categoryCtrl.text = p.category;
      priceCtrl.text = p.price.toString();
      stockCtrl.text = p.stock.toString();
      barcodeCtrl.text = p.barcode ?? '';
    } else if (widget.productSnapshot != null) {
      final p = widget.productSnapshot!;
      nameCtrl.text = p['name'] ?? "";
      categoryCtrl.text = p['category'] ?? "";
      priceCtrl.text = (p['price'] ?? "").toString();
      stockCtrl.text = (p['stock'] ?? "").toString();
      barcodeCtrl.text = p['barcode'] ?? "";
    }
  }

  Future<void> _loadCategories() async {
    try {
      final syncService = Provider.of<SyncService>(context, listen: false);
      final snapshot = await syncService.getCollectionSnapshots('items').first;
      final categories = <String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['category'] != null) {
          categories.add(data['category'].toString());
        }
      }
      setState(() {
        categorySuggestions = categories
            .where((c) => c.isNotEmpty)
            .toList();
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  void _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final syncService = Provider.of<SyncService>(context, listen: false);
      
      String itemId;
      DateTime createdAt;
      OperationType operationType;
      
      if (widget.product == null && widget.productSnapshot == null) {
        // tambah baru
        itemId = const Uuid().v4();
        createdAt = DateTime.now();
        operationType = OperationType.create;
      } else {
        // update
        if (widget.product != null) {
          itemId = widget.product!.id;
          createdAt = widget.product!.createdAt ?? DateTime.now();
        } else {
          itemId = widget.productSnapshot!.id;
          createdAt = (widget.productSnapshot!['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        }
        operationType = OperationType.update;
      }
      
      final itemData = {
        'name': nameCtrl.text,
        'category': categoryCtrl.text,
        'price': double.tryParse(priceCtrl.text) ?? 0.0,
        'stock': int.tryParse(stockCtrl.text) ?? 0,
        'barcode': barcodeCtrl.text.isEmpty ? null : barcodeCtrl.text,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };
      
      // Add to sync queue
      await syncService.addPendingOperation(
        collection: 'items',
        type: operationType,
        documentId: itemId,
        data: itemData,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(operationType == OperationType.create 
                ? 'Produk berhasil ditambahkan' 
                : 'Produk berhasil diperbarui'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // scan barcode
  Future<void> _scanBarcode() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BarcodeScannerPage(),
        ),
      );

      // hanya update field, jangan close form
      if (result != null && result is String && mounted) {
        setState(() {
          barcodeCtrl.text = result;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning barcode: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.product == null ? "Tambah Barang" : "Edit Barang",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 15),
            TextFormField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: "Nama Produk",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
            ),
            SizedBox(height: 15),
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') {
                  return const Iterable<String>.empty();
                }
                return categorySuggestions.where((String option) {
                  return option
                      .toLowerCase()
                      .contains(textEditingValue.text.toLowerCase());
                });
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onEditingComplete) {
                controller.text = categoryCtrl.text;
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: "Kategori",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                    ),
                  ),
                  validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
                  onChanged: (v) => categoryCtrl.text = v,
                );
              },
              onSelected: (String selection) {
                categoryCtrl.text = selection;
              },
            ),
            SizedBox(height: 15),
            TextFormField(
              controller: priceCtrl,
              decoration: InputDecoration(
                labelText: "Harga",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
            ),
            SizedBox(height: 15),
            TextFormField(
              controller: stockCtrl,
              decoration: InputDecoration(
                labelText: "Stok",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
            ),
            SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: barcodeCtrl,
                    decoration: InputDecoration(
                      labelText: "Barcode (opsional)",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _scanBarcode,
                  icon: Icon(Icons.qr_code_scanner),
                  label: Text("Scan"),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15, horizontal: 15),
                  ),
                )
              ],
            ),
            SizedBox(height: 25),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _saveProduct,
                    icon: Icon(Icons.save),
                    label: Text("Simpan"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
