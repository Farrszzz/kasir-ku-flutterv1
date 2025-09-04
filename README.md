# Kasir-ku - Flutter POS Application

Aplikasi POS (Point of Sale) modern dengan Firebase backend untuk sinkronisasi multi-device.

## Fitur Utama

### Dashboard
- Ringkasan harian: Total penghasilan, transaksi, penjualan, dan stok barang
- Data real-time dari Firestore
- Aksi cepat ke halaman utama

### Kelola Barang
- CRUD lengkap untuk produk
- Pencarian berdasarkan nama/barcode
- Scan barcode dengan kamera
- Kategori dan manajemen stok

### Transaksi
- Sistem POS lengkap dengan keranjang
- Pencarian produk dan scan barcode
- Checkout dengan perhitungan kembalian otomatis
- Penyimpanan transaksi ke Firestore

### Riwayat Transaksi
- Daftar transaksi dengan ringkasan harian/total
- Detail transaksi lengkap
- Fitur cetak ulang struk

### Pengaturan
- Konfigurasi informasi toko
- Preview format struk
- Pengaturan untuk cetak thermal

## Setup Firebase

1. Buat project Firebase baru di [Firebase Console](https://console.firebase.google.com/)
2. Aktifkan Firestore Database
3. Download `google-services.json` dan letakkan di `android/app/`
4. Untuk iOS, download `GoogleService-Info.plist` dan letakkan di `ios/Runner/`

## Instalasi

```bash
flutter pub get
flutter run
```

## Struktur Database Firestore

### Collection: `products`
```json
{
  "name": "string",
  "category": "string", 
  "price": "number",
  "stock": "number",
  "barcode": "string",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### Collection: `transactions`
```json
{
  "id": "string",
  "items": [
    {
      "id": "string",
      "name": "string",
      "price": "number",
      "quantity": "number",
      "subtotal": "number"
    }
  ],
  "total": "number",
  "payment": "number",
  "change": "number",
  "date": "timestamp",
  "createdAt": "timestamp"
}
```

### Collection: `settings`
```json
{
  "nama_toko": "string",
  "alamat": "string",
  "nomor_hp": "string",
  "nama_kasir": "string",
  "updated_at": "timestamp"
}
```

## Dependencies

- `firebase_core` & `cloud_firestore` - Backend Firebase
- `intl` - Format tanggal dan mata uang Indonesia
- `qr_code_scanner` - Scan barcode/QR code
- `uuid` - Generate ID transaksi
- `permission_handler` - Akses kamera

## Teknologi

- **Flutter** - Framework UI
- **Firebase Firestore** - Database real-time
- **Material 3** - Design system modern
- **Locale Indonesia** - Format tanggal dan mata uang

## Fitur Mendatang

- Integrasi printer thermal Bluetooth
- Backup/restore data
- Laporan penjualan detail
- Multi-user authentication

---

 2024 Kasir-ku. All rights reserved.
