import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/sync_service.dart';
import '../providers/app_provider.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
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
        ],
      ),
      body: Consumer<SyncService>(
        builder: (context, syncService, child) {
          return StreamBuilder(
            stream: syncService.getCollectionSnapshots('transactions'),
            builder: (context, transactionSnapshot) {
              return StreamBuilder(
                stream: syncService.getCollectionSnapshots('items'),
                builder: (context, itemSnapshot) {
                  if (transactionSnapshot.connectionState == ConnectionState.waiting ||
                      itemSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final todayTransactions = _getTodayTransactions(transactionSnapshot.data?.docs ?? []);
                  final items = itemSnapshot.data?.docs ?? [];

                  double todayRevenue = 0;
                  int todayTransactionCount = todayTransactions.length;
                  int todayItemsSold = 0;

                  for (var doc in todayTransactions) {
                    final data = doc.data();
                    todayRevenue += (data['total'] ?? 0).toDouble();
                    final transactionItems = data['items'] as List<dynamic>? ?? [];
                    for (var item in transactionItems) {
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
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.now()),
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
                              '${items.length}',
                              Icons.inventory,
                              Colors.purple,
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Transaction Chart
                        Text(
                          'Grafik Transaksi (7 Hari Terakhir)',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTransactionChart(transactionSnapshot.data?.docs ?? []),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  List<dynamic> _getTodayTransactions(List<dynamic> allTransactions) {
    final startOfDay = _getStartOfDay();
    final endOfDay = DateTime(startOfDay.year, startOfDay.month, startOfDay.day, 23, 59, 59);
    
    return allTransactions.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = data['createdAt'];
      DateTime transactionDate;
      
      if (createdAt is Timestamp) {
        transactionDate = createdAt.toDate();
      } else if (createdAt is String) {
        transactionDate = DateTime.parse(createdAt);
      } else {
        return false;
      }
      
      return transactionDate.isAfter(startOfDay) && transactionDate.isBefore(endOfDay);
    }).toList();
  }

  Widget _buildTransactionChart(List<dynamic> allTransactions) {
    final chartData = _getChartData(allTransactions);
    
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: chartData.isEmpty ? 10 : chartData.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${rod.toY.round()} transaksi',
                  const TextStyle(color: Colors.white),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final date = DateTime.now().subtract(Duration(days: 6 - value.toInt()));
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      DateFormat('dd/MM').format(date),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: chartData.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.y,
                  color: Colors.blue,
                  width: 16,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  List<FlSpot> _getChartData(List<dynamic> allTransactions) {
    final now = DateTime.now();
    final chartData = <FlSpot>[];
    
    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final nextDate = date.add(const Duration(days: 1));
      
      final dayTransactions = allTransactions.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = data['createdAt'];
        DateTime transactionDate;
        
        if (createdAt is Timestamp) {
          transactionDate = createdAt.toDate();
        } else if (createdAt is String) {
          transactionDate = DateTime.parse(createdAt);
        } else {
          return false;
        }
        
        return transactionDate.isAfter(date) && transactionDate.isBefore(nextDate);
      }).length;
      
      chartData.add(FlSpot((6 - i).toDouble(), dayTransactions.toDouble()));
    }
    
    return chartData;
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


  DateTime _getStartOfDay() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
