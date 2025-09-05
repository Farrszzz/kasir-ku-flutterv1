import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

enum SyncStatus {
  idle,
  syncing,
  success,
  error,
}

enum OperationType {
  create,
  update,
  delete,
}

class PendingOperation {
  final String id;
  final String collection;
  final OperationType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String? localVersion; // For conflict resolution
  final bool isDirty;

  PendingOperation({
    required this.id,
    required this.collection,
    required this.type,
    required this.data,
    required this.timestamp,
    this.localVersion,
    this.isDirty = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'collection': collection,
    'type': type.name,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'localVersion': localVersion,
    'isDirty': isDirty,
  };

  factory PendingOperation.fromJson(Map<String, dynamic> json) => PendingOperation(
    id: json['id'],
    collection: json['collection'],
    type: OperationType.values.firstWhere((e) => e.name == json['type']),
    data: json['data'],
    timestamp: DateTime.parse(json['timestamp']),
    localVersion: json['localVersion'],
    isDirty: json['isDirty'] ?? true,
  );
}

class SyncService extends ChangeNotifier {
  static const String _pendingQueueKey = 'pending_operations_queue';
  static const String _lastSyncKey = 'last_sync_timestamp';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Connectivity _connectivity = Connectivity();
  
  // Stream controllers
  final StreamController<SyncStatus> _syncStatusController = StreamController<SyncStatus>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  
  // State variables
  bool _isOnline = false;
  bool _isSyncing = false;
  String? _lastError;
  Timer? _syncTimer;
  Timer? _connectivityTimer;
  List<PendingOperation> _pendingQueue = [];

  // Getters
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  String? get lastError => _lastError;
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  int get pendingOperationsCount => _pendingQueue.length;

  // Get dirty documents count for UI indicators
  int get dirtyDocumentsCount {
    return _pendingQueue.where((op) => op.isDirty).length;
  }

  SyncService() {
    _initializeService();
  }

  Future<void> _initializeService() async {
    // Load pending operations from SharedPreferences
    await _loadPendingQueue();

    // Start connectivity monitoring
    _startConnectivityMonitoring();

    // Start periodic sync when online
    _startPeriodicSync();

    // Check initial connection
    await _checkConnectivity();
  }

  void _startConnectivityMonitoring() {
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      _checkConnectivity();
    });

    // Also check connectivity every 30 seconds
    _connectivityTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkConnectivity();
    });
  }

  Future<void> _checkConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      final wasOnline = _isOnline;

      if (connectivityResult == ConnectivityResult.none) {
        _isOnline = false;
      } else {
        // Test actual internet connectivity by trying to reach Firestore
        try {
          await _firestore.collection('_connectivity_test').limit(1).get(
            const GetOptions(source: Source.server)
          );
          _isOnline = true;
        } catch (e) {
          _isOnline = false;
        }
      }

      // Notify listeners if connection status changed
      if (wasOnline != _isOnline) {
        _connectionController.add(_isOnline);
        notifyListeners();

        // If we just came online, start syncing
        if (_isOnline && !wasOnline) {
          print('Connection restored, starting sync...');
          _syncPendingOperations();
        }
      }
    } catch (e) {
      print('Error checking connectivity: $e');
      _isOnline = false;
    }
  }

  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (_isOnline && !_isSyncing && _pendingQueue.isNotEmpty) {
        _syncPendingOperations();
      }
    });
  }

  // Add pending operation to queue with dirty flag support
  Future<void> addPendingOperation({
    required String collection,
    required OperationType type,
    required String documentId,
    required Map<String, dynamic> data,
    String? localVersion,
  }) async {
    // Add dirty flag and pending action to the data
    final dataWithFlags = Map<String, dynamic>.from(data);
    dataWithFlags['dirty'] = true;
    dataWithFlags['pendingAction'] = type.name;
    dataWithFlags['lastModifiedAt'] = DateTime.now().toIso8601String();

    final operation = PendingOperation(
      id: documentId,
      collection: collection,
      type: type,
      data: dataWithFlags,
      timestamp: DateTime.now(),
      localVersion: localVersion,
      isDirty: true,
    );

    // Remove any existing operation for the same document
    _pendingQueue.removeWhere((op) => 
      op.id == documentId && op.collection == collection);

    _pendingQueue.add(operation);
    await _savePendingQueue();

    // Try to sync immediately if online
    if (_isOnline && !_isSyncing) {
      _syncPendingOperations();
    }

    notifyListeners();
  }

  // Load pending queue from SharedPreferences
  Future<void> _loadPendingQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_pendingQueueKey);

      if (queueJson != null) {
        final List<dynamic> queueList = jsonDecode(queueJson);
        _pendingQueue = queueList.map((json) => PendingOperation.fromJson(json)).toList();
        print('Loaded ${_pendingQueue.length} pending operations from storage');
      }
    } catch (e) {
      print('Error loading pending queue: $e');
      _pendingQueue = [];
    }
  }

  // Save pending queue to SharedPreferences
  Future<void> _savePendingQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = jsonEncode(_pendingQueue.map((op) => op.toJson()).toList());
      await prefs.setString(_pendingQueueKey, queueJson);
    } catch (e) {
      print('Error saving pending queue: $e');
    }
  }

  // Sync all pending operations to Firestore
  Future<void> _syncPendingOperations() async {
    if (_isSyncing || !_isOnline || _pendingQueue.isEmpty) return;

    _isSyncing = true;
    _syncStatusController.add(SyncStatus.syncing);
    notifyListeners();

    try {
      print('Starting sync of ${_pendingQueue.length} pending operations...');

      final operationsToSync = List<PendingOperation>.from(_pendingQueue);
      final syncedOperations = <PendingOperation>[];

      for (final operation in operationsToSync) {
        try {
          await _syncSingleOperation(operation);
          syncedOperations.add(operation);
          print('Successfully synced ${operation.type.name} operation for ${operation.collection}/${operation.id}');
        } catch (e) {
          print('Failed to sync operation ${operation.id}: $e');
          // Don't remove failed operations, they'll be retried later
        }
      }

      // Remove successfully synced operations
      for (final syncedOp in syncedOperations) {
        _pendingQueue.removeWhere((op) => 
          op.id == syncedOp.id && 
          op.collection == syncedOp.collection && 
          op.timestamp == syncedOp.timestamp
        );
      }

      // Save updated queue
      await _savePendingQueue();

      // Update last sync timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

      _syncStatusController.add(SyncStatus.success);
      _lastError = null;

      print('Sync completed. ${syncedOperations.length} operations synced, ${_pendingQueue.length} remaining');

    } catch (e) {
      _lastError = e.toString();
      _syncStatusController.add(SyncStatus.error);
      print('Sync failed: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Sync a single operation to Firestore with conflict resolution
  Future<void> _syncSingleOperation(PendingOperation operation) async {
    final docRef = _firestore.collection(operation.collection).doc(operation.id);

    try {
      switch (operation.type) {
        case OperationType.create:
          // For creates, add metadata for tracking
          final dataWithMetadata = Map<String, dynamic>.from(operation.data);
          dataWithMetadata['dirty'] = false;
          dataWithMetadata['pendingAction'] = null;
          dataWithMetadata['lastSyncedAt'] = FieldValue.serverTimestamp();
          dataWithMetadata['syncVersion'] = DateTime.now().millisecondsSinceEpoch.toString();

          await docRef.set(dataWithMetadata);
          break;

        case OperationType.update:
          // Check for conflicts before updating
          final currentDoc = await docRef.get();

          if (currentDoc.exists) {
            final currentData = currentDoc.data()!;
            final serverVersion = currentData['syncVersion'] as String?;

            // Simple conflict resolution: server wins if versions differ
            if (operation.localVersion != null && 
                serverVersion != null && 
                operation.localVersion != serverVersion) {
              print('Conflict detected for ${operation.id}, server version wins');
              // Skip this update, server data is newer
              return;
            }
          }

          // Apply update with metadata
          final dataWithMetadata = Map<String, dynamic>.from(operation.data);
          dataWithMetadata['dirty'] = false;
          dataWithMetadata['pendingAction'] = null;
          dataWithMetadata['lastSyncedAt'] = FieldValue.serverTimestamp();
          dataWithMetadata['syncVersion'] = DateTime.now().millisecondsSinceEpoch.toString();

          await docRef.set(dataWithMetadata, SetOptions(merge: true));
          break;

        case OperationType.delete:
          await docRef.delete();
          break;
      }
    } catch (e) {
      print('Error syncing operation ${operation.id}: $e');
      rethrow;
    }
  }

  // Manual sync trigger
  Future<bool> syncNow() async {
    if (!_isOnline) {
      _lastError = 'Tidak ada koneksi internet';
      return false;
    }

    await _syncPendingOperations();
    return _lastError == null;
  }

  // Get Firestore snapshots with metadata changes
  Stream<QuerySnapshot<Map<String, dynamic>>> getCollectionSnapshots(
    String collection, {
    Query<Map<String, dynamic>>? query,
  }) {
    final baseQuery = query ?? _firestore.collection(collection);

    return baseQuery.snapshots(includeMetadataChanges: true);
  }

  // Get document snapshots with metadata changes
  Stream<DocumentSnapshot<Map<String, dynamic>>> getDocumentSnapshots(
    String collection,
    String documentId,
  ) {
    return _firestore
        .collection(collection)
        .doc(documentId)
        .snapshots(includeMetadataChanges: true);
  }

  // Check if document is from cache
  bool isFromCache(DocumentSnapshot snapshot) {
    return snapshot.metadata.isFromCache;
  }

  // Check if document has pending writes
  bool hasPendingWrites(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>?;
    return data?['dirty'] == true || data?['pendingAction'] != null;
  }

  // Get sync version of a document
  String? getSyncVersion(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return data?['syncVersion'] as String?;
  }

  // Mark document as clean (synced)
  Future<void> markDocumentClean(String collection, String documentId) async {
    try {
      await _firestore.collection(collection).doc(documentId).update({
        'dirty': false,
        'pendingAction': null,
        'lastSyncedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking document clean: $e');
    }
  }

  // Get all dirty documents from a collection
  Stream<QuerySnapshot<Map<String, dynamic>>> getDirtyDocuments(String collection) {
    return _firestore
        .collection(collection)
        .where('dirty', isEqualTo: true)
        .snapshots(includeMetadataChanges: true);
  }

  // Resolve conflicts by applying server data
  Future<void> resolveConflict(String collection, String documentId, Map<String, dynamic> serverData) async {
    try {
      // Remove from pending queue
      _pendingQueue.removeWhere((op) => 
        op.id == documentId && op.collection == collection);
      await _savePendingQueue();

      // Apply server data locally
      final cleanData = Map<String, dynamic>.from(serverData);
      cleanData['dirty'] = false;
      cleanData['pendingAction'] = null;
      cleanData['lastSyncedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection(collection).doc(documentId).set(cleanData);

      notifyListeners();
    } catch (e) {
      print('Error resolving conflict: $e');
    }
  }

  // Check if there are pending transactions
  bool hasPendingTransactions() {
    return _pendingQueue.any((op) => op.collection == 'transactions');
  }

  // Get pending operations count for a specific collection
  int getPendingOperationsCount(String collection) {
    return _pendingQueue.where((op) => op.collection == collection).length;
  }

  // Get all pending operations for a collection
  List<PendingOperation> getPendingOperations(String collection) {
    return _pendingQueue.where((op) => op.collection == collection).toList();
  }

  // Clear all pending operations (use with caution)
  Future<void> clearPendingOperations() async {
    _pendingQueue.clear();
    await _savePendingQueue();
    notifyListeners();
  }

  // Public method to trigger sync
  Future<void> syncPendingOperations() async {
    await _syncPendingOperations();
  }

  // Manual sync method for compatibility
  Future<void> syncManual() async {
    await _syncPendingOperations();
  }

  // Sync specific collection with bidirectional support
  Future<void> syncCollection(String collection) async {
    if (!_isOnline || _isSyncing) return;

    try {
      // First, sync pending local changes
      final collectionOperations = _pendingQueue
          .where((op) => op.collection == collection)
          .toList();

      for (final operation in collectionOperations) {
        await _syncSingleOperation(operation);
        _pendingQueue.remove(operation);
      }

      await _savePendingQueue();

      // Then, pull server changes for dirty documents
      final dirtyDocs = await _firestore
          .collection(collection)
          .where('dirty', isEqualTo: true)
          .get();

      for (final doc in dirtyDocs.docs) {
        final data = doc.data();
        if (data['pendingAction'] == null) {
          // This is a server-side change, mark as clean
          await markDocumentClean(collection, doc.id);
        }
      }

      notifyListeners();
    } catch (e) {
      print('Error syncing collection $collection: $e');
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _connectivityTimer?.cancel();
    _syncStatusController.close();
    _connectionController.close();
    super.dispose();
  }
}