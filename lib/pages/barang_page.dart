import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:kasir_ku/pages/barcode_scanner_page.dart';

// ====================== HALAMAN UTAMA BARANG ======================

class BarangPage extends StatefulWidget {
  BarangPage({Key? key}) : super(key: key);

  @override
  _BarangPageState createState() => _BarangPageState();
}

class _BarangPageState extends State<BarangPage> {
  String searchQuery = "";
  String selectedCategory = "All";

  // ambil kategori unik dari firestore untuk filter & suggestion
  Future<List<String>> _getCategories() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('products').get();
      final categories = snapshot.docs
          .map((doc) => (doc['category'] ?? "").toString())
          .where((cat) => cat.isNotEmpty)
          .toSet()
          .toList();
      categories.sort();
      return categories;
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
    }
  }

  // format currency
  String formatCurrency(num value) {
    final format = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp');
    return format.format(value);
  }

  // open form tambah / edit barang
  void _openForm({DocumentSnapshot? product}) {
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
          child: AddProductForm(product: product),
        ),
      ),
    );
  }

  // hapus produk
  void _deleteProduct(String id) {
    try {
      FirebaseFirestore.instance.collection('products').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produk berhasil dihapus')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus produk: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Product Management"),
        centerTitle: true,
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
          FutureBuilder<List<String>>(
            future: _getCategories(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return SizedBox();
              final categories = ["All", ...snapshot.data!];
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
                  
                final docs = snapshot.data!.docs.where((doc) {
                  final name = (doc['name'] ?? "").toString().toLowerCase();
                  final barcode = (doc['barcode'] ?? "").toString().toLowerCase();
                  final category = (doc['category'] ?? "").toString();
                  final matchesSearch = name.contains(searchQuery) || 
                                        barcode.contains(searchQuery);
                  final matchesCategory =
                      selectedCategory == "All" || category == selectedCategory;
                  return matchesSearch && matchesCategory;
                }).toList();

                if (docs.isEmpty) {
                  return Center(child: Text("Tidak ada produk"));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final data = docs[i];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFFE5E5E5), width: 1),
                      ),
                      child: ListTile(
                        title: Text(data['name'] ?? ""),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Price: ${formatCurrency(data['price'] ?? 0)}",
                            ),
                            Text(
                              "Stock: ${data['stock'] ?? 0} | Category: ${data['category'] ?? '-'}",
                            ),
                            if ((data['barcode'] ?? "").isNotEmpty)
                              Text(
                                "Barcode: ${data['barcode']}",
                                style: TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.orange),
                              onPressed: () => _openForm(product: data),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteProduct(data.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
  final DocumentSnapshot? product;
  AddProductForm({this.product});

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
      nameCtrl.text = p['name'] ?? "";
      categoryCtrl.text = p['category'] ?? "";
      priceCtrl.text = (p['price'] ?? "").toString();
      stockCtrl.text = (p['stock'] ?? "").toString();
      barcodeCtrl.text = p['barcode'] ?? "";
    }
  }

  Future<void> _loadCategories() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('products').get();
      setState(() {
        categorySuggestions = snapshot.docs
            .map((d) => (d['category'] ?? "").toString())
            .where((c) => c.isNotEmpty)
            .toSet()
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
      if (widget.product == null) {
        // tambah baru
        await FirebaseFirestore.instance.collection('products').add({
          'name': nameCtrl.text,
          'category': categoryCtrl.text,
          'price': double.tryParse(priceCtrl.text) ?? 0.0,
          'stock': int.tryParse(stockCtrl.text) ?? 0,
          'barcode': barcodeCtrl.text,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Produk berhasil ditambahkan')),
        );
      } else {
        // update
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.product!.id)
            .update({
          'name': nameCtrl.text,
          'category': categoryCtrl.text,
          'price': double.tryParse(priceCtrl.text) ?? 0.0,
          'stock': int.tryParse(stockCtrl.text) ?? 0,
          'barcode': barcodeCtrl.text,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Produk berhasil diperbarui')),
        );
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
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
