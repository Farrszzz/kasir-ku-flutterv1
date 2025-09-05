import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'pages/dashboard_page.dart';
import 'pages/barang_page.dart';
import 'pages/transaksi_page.dart';
import 'pages/riwayat_page.dart';
import 'pages/pengaturan_page.dart';
import 'providers/app_provider.dart';
import 'services/hive_service.dart';
import 'services/sync_service.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inisialisasi Firebase
  await Firebase.initializeApp();
  
  // Konfigurasi Firestore untuk mode hybrid dengan persistensi offline
  // Hanya aktifkan persistence sekali saja
  try {
    await FirebaseFirestore.instance.enablePersistence(
      const PersistenceSettings(synchronizeTabs: true)
    );
  } catch (e) {
    // Persistence sudah diaktifkan sebelumnya atau tidak didukung
    print('Firestore persistence: $e');
  }
  
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  
  // Inisialisasi Hive untuk penyimpanan lokal
  await HiveService.init();
  
  // Inisialisasi format tanggal lokal Indonesia
  await initializeDateFormatting('id_ID', null);
  
  runApp(const KasirKuApp());
}

class KasirKuApp extends StatelessWidget {
  const KasirKuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => SyncService()),
        ChangeNotifierProvider(create: (context) => AppProvider()),
      ],
      child: MaterialApp(
        title: 'Kasir-ku',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(),
        home: const MainNavigationPage(),
      ),
    );
  }
}

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DashboardPage(),
    BarangPage(), // Removed const as per requirement
    const TransaksiPage(),
    const RiwayatPage(),
    const PengaturanPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.white,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Barang',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Transaksi',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}
