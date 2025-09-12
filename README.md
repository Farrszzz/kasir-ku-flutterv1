# Kasir-ku — Aplikasi POS Flutter

Aplikasi Point of Sale (POS) modern yang mendukung operasi offline dan sinkronisasi online otomatis menggunakan Firebase Cloud Firestore.

## Ringkasan
Kasir-ku dirancang untuk tetap berfungsi tanpa koneksi internet (offline-first) dan akan melakukan sinkronisasi data secara otomatis saat koneksi kembali tersedia. Aplikasi ini menggunakan arsitektur yang sederhana namun tangguh dengan indikator status sinkronisasi yang jelas di setiap halaman.

## Fitur Utama
- **Dashboard interaktif**
  - Ringkasan harian: total penghasilan, jumlah transaksi, item terjual, dan total barang
  - Grafik transaksi 7 hari terakhir menggunakan `fl_chart`
- **Kelola Barang (Items)**
  - CRUD barang, manajemen stok, kategori, dan pencarian berdasarkan nama/barcode
  - Sinkronisasi offline/online otomatis untuk koleksi `items`
- **Transaksi (POS)**
  - Keranjang belanja, perhitungan subtotal/total, pembayaran, dan kembalian
  - Pencarian cepat dan dukungan scan barcode:
    - Kamera (via `mobile_scanner`)
    - Scanner eksternal (mode HID/keyboard) termasuk USB OTG atau Bluetooth HID
- **Riwayat Transaksi**
  - Daftar transaksi, ringkasan total dan harian, serta detail transaksi
  - Cetak ulang struk (melalui helper yang disediakan)
- **Pengaturan**
  - Informasi toko (nama, alamat, telepon, nama kasir) dengan preview struk
- **Offline-First & Sinkronisasi**
  - Antrian operasi lokal dengan flag `dirty` dan `pendingAction`
  - Sinkronisasi dua arah (server wins) saat online kembali
  - Indikator status di AppBar: hijau (online), oranye (syncing), merah (offline)

## Arsitektur Singkat
- `lib/services/sync_service.dart` — Layanan sinkronisasi offline/online:
  - Menyimpan operasi lokal tertunda di SharedPreferences
  - Menandai perubahan lokal dengan `dirty` dan `pendingAction`
  - Menangani konflik sederhana menggunakan `syncVersion` (server-wins)
  - Stream snapshot Firestore dengan `includeMetadataChanges: true`
- `lib/providers/app_provider.dart` — Status aplikasi (nama kasir, trigger sync, dsb.)
- Halaman-halaman utama:
  - `lib/pages/dashboard_page.dart`
  - `lib/pages/barang_page.dart`
  - `lib/pages/transaksi_page.dart`
  - `lib/pages/riwayat_page.dart`
  - `lib/pages/pengaturan_page.dart`

## Teknologi
- Flutter + Material 3
- Firebase (`firebase_core`, `cloud_firestore`) dengan persistence offline
- State management `provider`
- `fl_chart` untuk grafik
- `mobile_scanner` untuk scan kamera
- `shared_preferences` untuk antrian operasi lokal
- `intl`, `uuid`, `permission_handler`, `connectivity_plus`

## Struktur Koleksi Firestore
### Collection: `items`
```json
{
  "name": "string",
  "category": "string",
  "price": "number",
  "stock": "number",
  "barcode": "string",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "dirty": "boolean",
  "pendingAction": "string|null",
  "syncVersion": "string",
  "lastSyncedAt": "timestamp"
}
```

### Collection: `transactions`
```json
{
  "id": "string",
  "items": [
    { "id": "string", "name": "string", "price": "number", "quantity": "number", "subtotal": "number" }
  ],
  "total": "number",
  "payment": "number",
  "change": "number",
  "createdAt": "timestamp"
}
```

### Collection: `settings` (opsional, jika disimpan di Firestore)
```json
{
  "storeName": "string",
  "storeAddress": "string",
  "storePhone": "string",
  "cashierName": "string",
  "updatedAt": "timestamp"
}
```

## Persiapan Proyek
### Prasyarat
- Flutter SDK terinstal
- Akun Firebase & project Firebase aktif
- Perangkat Android/iOS atau emulator/simulator

### Setup Firebase
1. Buat project di [Firebase Console](https://console.firebase.google.com/)
2. Aktifkan Cloud Firestore
3. Unduh berkas konfigurasi:
   - Android: `google-services.json` ke `android/app/`
   - iOS: `GoogleService-Info.plist` ke `ios/Runner/`
4. Pastikan plugin Google Services sudah aktif di project Android (template Flutter biasanya sudah menyiapkan)

### Pengaturan Android (opsional)
- Pastikan perangkat mendukung USB OTG jika ingin memakai scanner USB HID
- Jika memakai kamera: pastikan izin kamera aktif (`permission_handler` akan menangani pada runtime)

## Menjalankan Aplikasi
```bash
flutter pub get
flutter run
```

## Build Produksi
```bash
# Android APK (release)
flutter build apk

# Android AppBundle
flutter build appbundle
```

## Cara Menggunakan (Alur Kasir)
1. Masuk ke halaman `Transaksi`
2. Pilih mode input:
   - Scan dengan kamera, atau
   - Gunakan scanner eksternal (HID/keyboard) dengan memfokuskan `TextField` barcode
3. Tambahkan barang ke keranjang (berdasarkan barcode/nama)
4. Lakukan pembayaran → struk bisa dicetak/diarsip
5. Aplikasi akan menyimpan transaksi dan menyinkronkan saat online

## Dukungan Scanner Barcode USB/Bluetooth (HID)
- Sebagian besar scanner bekerja sebagai **HID (keyboard)**
- Cukup fokuskan `TextField` barcode di halaman Transaksi, hasil scan akan terketik otomatis (biasanya diakhiri Enter)
- Android memerlukan perangkat dengan dukungan **USB OTG** untuk scanner USB
- iOS umumnya memakai scanner Bluetooth HID
- Jika scanner Anda tidak mendukung HID dan memakai mode Serial/SDK vendor, integrasi tambahan diperlukan (di luar cakupan bawaan)

## Troubleshooting
- **Build error terkait `fl_chart`**: pastikan API yang digunakan sesuai versi di `pubspec.yaml`. Pada versi saat ini, properti tooltip tertentu (mis. `tooltipBgColor`) mungkin tidak tersedia — gunakan konfigurasi yang kompatibel.
- **Sinkronisasi tidak jalan**: periksa indikator status di AppBar. Jika offline (merah), koneksi internet belum terdeteksi. Saat online (hijau) dan ada antrian, status akan menjadi oranye (syncing).
- **Data tidak muncul saat offline**: Firestore persistence perlu aktif (sudah diinisialisasi di `main.dart`). Jalankan ulang aplikasi bila perlu.
- **Scanner tidak mengetik**: pastikan field pencarian/barcode fokus, dan scanner dalam mode HID. Untuk USB, cek dukungan OTG.

## Skrip Perintah Umum
```bash
flutter clean && flutter pub get
flutter analyze
flutter test  # (jika ada pengujian unit/widget)
```

## Lisensi
Proyek ini untuk keperluan pembelajaran/demonstrasi. Silakan sesuaikan lisensi sesuai kebutuhan Anda.
