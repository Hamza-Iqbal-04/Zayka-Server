// firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _branchId = 'Old_Airport';

  // Table Operations
  static Future<void> updateTableStatus(String tableNumber, String status, {String? currentOrderId}) async {
    final updateData = <String, dynamic>{
      'Tables.$tableNumber.status': status,
      'Tables.$tableNumber.statusTimestamp': FieldValue.serverTimestamp(),
    };

    if (currentOrderId != null) {
      updateData['Tables.$tableNumber.currentOrderId'] = currentOrderId;
    } else if (status == 'available') {
      updateData['Tables.$tableNumber.currentOrderId'] = FieldValue.delete();
    }

    await _firestore.collection('Branch').doc(_branchId).update(updateData);
  }

  // Order Operations with Transactions
  static Future<String> createDineInOrder({
    required String tableNumber,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
  }) async {
    return await _firestore.runTransaction((transaction) async {
      // Get daily order number
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final ordersQuery = _firestore
          .collection('Orders')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(startOfDay));

      final ordersSnapshot = await ordersQuery.get();
      final dailyOrderNumber = ordersSnapshot.size + 1;

      // Create order document reference
      final orderRef = _firestore.collection('Orders').doc();

      // Create order data
      final orderData = {
        'Order_type': 'dine_in',
        'tableNumber': tableNumber,
        'items': items,
        'subtotal': totalAmount,
        'totalAmount': totalAmount,
        'status': 'pending',
        'paymentStatus': 'unpaid',
        'timestamp': FieldValue.serverTimestamp(),
        'dailyOrderNumber': dailyOrderNumber,
        'branchId': _branchId,
      };

      // Set order data
      transaction.set(orderRef, orderData);

      // Update table status
      final branchRef = _firestore.collection('Branch').doc(_branchId);
      transaction.update(branchRef, {
        'Tables.$tableNumber.status': 'ordered',
        'Tables.$tableNumber.currentOrderId': orderRef.id,
        'Tables.$tableNumber.statusTimestamp': FieldValue.serverTimestamp(),
      });

      return orderRef.id;
    });
  }

  static Future<void> addToExistingOrder({
    required String orderId,
    required List<Map<String, dynamic>> newItems,
    required double additionalAmount,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final orderRef = _firestore.collection('Orders').doc(orderId);
      final orderDoc = await transaction.get(orderRef);

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;
      final currentItems = List<Map<String, dynamic>>.from(orderData['items'] ?? []);
      final currentTotal = (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final currentSubtotal = (orderData['subtotal'] as num?)?.toDouble() ?? 0.0;

      final mergedItems = _mergeOrderItems(currentItems, newItems);
      final newTotal = currentTotal + additionalAmount;
      final newSubtotal = currentSubtotal + additionalAmount;

      transaction.update(orderRef, {
        'items': mergedItems,
        'subtotal': newSubtotal,
        'totalAmount': newTotal,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> updateOrderStatusWithTable(String orderId, String status, {String? tableNumber}) async {
    await _firestore.runTransaction((transaction) async {
      final orderRef = _firestore.collection('Orders').doc(orderId);
      transaction.update(orderRef, {
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update table status if provided
      if (tableNumber != null) {
        final branchRef = _firestore.collection('Branch').doc(_branchId);
        String tableStatus = 'occupied';
        if (status == 'prepared') tableStatus = 'ordered';
        if (status == 'served') tableStatus = 'occupied';
        if (status == 'paid') tableStatus = 'available';

        transaction.update(branchRef, {
          'Tables.$tableNumber.status': tableStatus,
          'Tables.$tableNumber.statusTimestamp': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  static Future<void> processPayment({
    required String orderId,
    required String paymentMethod,
    required double amount,
    String? tableNumber,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final orderRef = _firestore.collection('Orders').doc(orderId);
      transaction.update(orderRef, {
        'paymentStatus': 'paid',
        'paymentMethod': paymentMethod,
        'paymentTime': FieldValue.serverTimestamp(),
        'paidAmount': amount,
        'status': 'paid',
      });

      // Clear table if dine-in order
      if (tableNumber != null) {
        final branchRef = _firestore.collection('Branch').doc(_branchId);
        transaction.update(branchRef, {
          'Tables.$tableNumber.status': 'available',
          'Tables.$tableNumber.currentOrderId': FieldValue.delete(),
          'Tables.$tableNumber.statusTimestamp': FieldValue.delete(),
        });
      }
    });
  }

  // Cart Operations
  static Future<void> saveCartItems(String tableNumber, List<Map<String, dynamic>> items) async {
    try {
      await _firestore.collection('carts').doc('table_$tableNumber').set({
        'items': items,
        'lastUpdated': FieldValue.serverTimestamp(),
        'tableNumber': tableNumber,
      });
    } catch (e) {
      throw Exception('Failed to save cart: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> loadCartItems(String tableNumber) async {
    try {
      final cartDoc = await _firestore.collection('carts').doc('table_$tableNumber').get();
      if (cartDoc.exists) {
        final cartData = cartDoc.data() as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(cartData['items'] ?? []);
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load cart: $e');
    }
  }

  static Future<void> clearCart(String tableNumber) async {
    try {
      await _firestore.collection('carts').doc('table_$tableNumber').delete();
    } catch (e) {
      throw Exception('Failed to clear cart: $e');
    }
  }

  // Helper Methods
  static List<Map<String, dynamic>> _mergeOrderItems(
      List<Map<String, dynamic>> existingItems, List<Map<String, dynamic>> newItems) {
    final merged = List<Map<String, dynamic>>.from(existingItems);

    for (final newItem in newItems) {
      final existingIndex = merged.indexWhere((item) =>
      item['id'] == newItem['id'] &&
          item['specialInstructions'] == newItem['specialInstructions'] &&
          item['selectedVariant'] == newItem['selectedVariant']);

      if (existingIndex >= 0) {
        merged[existingIndex]['quantity'] += newItem['quantity'];
      } else {
        merged.add(newItem);
      }
    }
    return merged;
  }

  // Stream Getters
  static Stream<DocumentSnapshot> getBranchStream() {
    return _firestore.collection('Branch').doc(_branchId).snapshots();
  }

  static Stream<DocumentSnapshot> getOrderStream(String orderId) {
    return _firestore.collection('Orders').doc(orderId).snapshots();
  }

  static Stream<QuerySnapshot> getActiveOrdersStream(String orderType) {
    Query query = _firestore
        .collection('Orders')
        .where('branchId', isEqualTo: _branchId)
        .where('status', whereIn: ['pending', 'preparing', 'prepared']);

    if (orderType != 'all') {
      query = query.where('Order_type', isEqualTo: orderType);
    }

    return query.orderBy('timestamp', descending: true).snapshots();
  }
}