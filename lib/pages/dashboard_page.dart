import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('transactions')
            .where('date', isGreaterThanOrEqualTo: _getStartOfDay())
            .snapshots(),
        builder: (context, transactionSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance.collection('products').snapshots(),
            builder: (context, productSnapshot) {
              if (transactionSnapshot.connectionState ==
                      ConnectionState.waiting ||
                  productSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final todayTransactions = transactionSnapshot.data?.docs ?? [];
              final products = productSnapshot.data?.docs ?? [];

              double todayRevenue = 0;
              int todayTransactionCount = todayTransactions.length;
              int todayItemsSold = 0;

              for (var doc in todayTransactions) {
                final data = doc.data() as Map<String, dynamic>;
                todayRevenue += (data['total'] ?? 0).toDouble();
                final items = data['items'] as List<dynamic>? ?? [];
                for (var item in items) {
                  todayItemsSold += (item['quantity'] ?? 0) as int;
                }
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selamat datang di Kasir-ku',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    Text(
                      DateFormat('EEEE, dd MMMM yyyy', 'id_ID')
                          .format(DateTime.now()),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 24),

                    // Summary Cards
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                      children: [
                        _buildSummaryCard(
                          context,
                          'Total Penghasilan',
                          'Rp ${NumberFormat('#,###', 'id_ID').format(todayRevenue)}',
                          Icons.monetization_on,
                          Colors.green,
                        ),
                        _buildSummaryCard(
                          context,
                          'Total Transaksi',
                          '$todayTransactionCount',
                          Icons.receipt_long,
                          Colors.blue,
                        ),
                        _buildSummaryCard(
                          context,
                          'Penjualan Hari Ini',
                          '$todayItemsSold item',
                          Icons.shopping_bag,
                          Colors.orange,
                        ),
                        _buildSummaryCard(
                          context,
                          'Total Barang',
                          '${products.length}',
                          Icons.inventory,
                          Colors.purple,
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Quick Actions
                    Text(
                      'Aksi Cepat',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionCard(
                            context,
                            'Kelola Barang',
                            Icons.inventory_2,
                            Colors.blue,
                            () => _navigateToPage(context, 1),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildQuickActionCard(
                            context,
                            'Transaksi Baru',
                            Icons.add_shopping_cart,
                            Colors.green,
                            () => _navigateToPage(context, 2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: _buildQuickActionCard(
                        context,
                        'Lihat Riwayat',
                        Icons.history,
                        Colors.orange,
                        () => _navigateToPage(context, 3),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E5E5), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: theme.primaryColor,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E5E5), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: theme.primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: theme.primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToPage(BuildContext context, int pageIndex) {
    // Find the parent navigation state and update the index
    final navigator = Navigator.of(context);
    navigator.pop();
    // This will be handled by the main navigation
  }

  DateTime _getStartOfDay() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
