import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Firebase/FirestoreService.dart';
import 'package:provider/provider.dart';
import '../Providers/UserProvider.dart';

class OrderDetailScreen extends StatefulWidget {
  // Accept an untyped DocumentSnapshot so both query docs and single-get docs work.
  final DocumentSnapshot order;

  OrderDetailScreen({Key? key, required this.order}) : super(key: key);

  @override
  _OrderDetailScreenState createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final Color primaryColor = Color(0xFF1976D2);
  final Color secondaryColor = Color(0xFFE3F2FD);
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    // Safely coerce snapshot data to Map<String, dynamic>. If data is null or not a map, use empty map.
    final Map<String, dynamic> orderData =
        (widget.order.data() as Map<String, dynamic>?) ?? <String, dynamic>{};

    final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);
    final status = orderData['status']?.toString() ?? 'unknown';
    final paymentStatus = orderData['paymentStatus']?.toString() ?? 'unpaid';
    final orderType = orderData['Order_type']?.toString() ?? 'dine_in';
    final tableNumber = orderData['tableNumber']?.toString();
    final dailyOrderNumber = orderData['dailyOrderNumber']?.toString() ?? '';
    final totalAmount = (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final subtotal = (orderData['subtotal'] as num?)?.toDouble() ?? 0.0;
    final timestamp = orderData['timestamp'] as Timestamp?;
    final customerName = orderData['customerName']?.toString();
    final carPlateNumber = orderData['carPlateNumber']?.toString();
    final customerPhone = orderData['customerPhone']?.toString();
    final paymentMethod = orderData['paymentMethod']?.toString();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Order Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Order Header Card
            Container(
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Number and Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #$dailyOrderNumber',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: orderType == 'takeaway'
                                    ? Colors.orange[100]
                                    : Colors.blue[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                orderType.toUpperCase().replaceAll('_', ' '),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: orderType == 'takeaway'
                                      ? Colors.orange[800]
                                      : Colors.blue[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            // Order Status Badge
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _getStatusColor(status),
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: _getStatusColor(status),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            // Payment Status Badge
                            if (status == 'served') ...[
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (paymentStatus == 'paid'
                                              ? Colors.green
                                              : Colors.red)
                                          .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: paymentStatus == 'paid'
                                        ? Colors.green
                                        : Colors.red,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  paymentStatus.toUpperCase(),
                                  style: TextStyle(
                                    color: paymentStatus == 'paid'
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: 16),
                    Divider(color: Colors.grey[300]),
                    SizedBox(height: 16),

                    // Order Info Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoItem(
                            icon: orderType == 'takeaway'
                                ? Icons.shopping_bag
                                : Icons.table_restaurant,
                            label: orderType == 'takeaway' ? 'Pickup' : 'Table',
                            value: orderType == 'takeaway'
                                ? 'Counter'
                                : (tableNumber ?? 'N/A'),
                          ),
                        ),
                        Expanded(
                          child: _buildInfoItem(
                            icon: Icons.access_time,
                            label: 'Ordered',
                            value: timestamp != null
                                ? _formatTime(timestamp.toDate())
                                : 'Unknown',
                          ),
                        ),
                      ],
                    ),

                    // Customer Info (for takeaway)
                    // Customer Info (for takeaway)
                    if (orderType == 'takeaway' &&
                        (customerName != null ||
                            customerPhone != null ||
                            carPlateNumber != null)) ...[
                      SizedBox(height: 12),
                      Row(
                        children: [
                          if (carPlateNumber != null)
                            Expanded(
                              child: _buildInfoItem(
                                icon: Icons.directions_car,
                                label: 'Car Plate',
                                value: carPlateNumber,
                              ),
                            ),
                          if (customerName != null)
                            Expanded(
                              child: _buildInfoItem(
                                icon: Icons.person,
                                label: 'Customer',
                                value: customerName,
                              ),
                            ),
                          if (customerPhone != null)
                            Expanded(
                              child: _buildInfoItem(
                                icon: Icons.phone,
                                label: 'Phone',
                                value: customerPhone,
                              ),
                            ),
                        ],
                      ),
                    ],

                    // Payment Method
                    if (paymentMethod != null) ...[
                      SizedBox(height: 12),
                      _buildInfoItem(
                        icon: paymentMethod == 'cash'
                            ? Icons.money
                            : Icons.credit_card,
                        label: 'Payment',
                        value: paymentMethod.toUpperCase(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Items Section
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Items Header
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.restaurant_menu, color: primaryColor),
                          SizedBox(width: 8),
                          Text(
                            'Order Items (${items.length})',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Items List
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final name =
                              item['name']?.toString() ?? 'Unknown Item';
                          final quantity =
                              (item['quantity'] as num?)?.toInt() ?? 1;
                          final price =
                              (item['price'] as num?)?.toDouble() ?? 0.0;
                          final total = price * quantity;
                          final specialInstructions =
                              item['specialInstructions']?.toString();

                          return Container(
                            margin: EdgeInsets.only(bottom: 12),
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              children: [
                                // Quantity Badge
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$quantity',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 16),

                                // Item Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'QAR ${price.toStringAsFixed(2)} each',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (specialInstructions != null &&
                                          specialInstructions.isNotEmpty) ...[
                                        SizedBox(height: 4),
                                        Text(
                                          'Special: $specialInstructions',
                                          style: TextStyle(
                                            color: Colors.orange[700],
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Total Price
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'QAR ${total.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Total Section
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        children: [
                          if (subtotal != totalAmount)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Subtotal:',
                                  style: TextStyle(fontSize: 16),
                                ),
                                Text(
                                  'QAR ${subtotal.toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          if (subtotal != totalAmount) SizedBox(height: 8),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TOTAL:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              Text(
                                'QAR ${totalAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
      // Action Buttons
      bottomNavigationBar: _buildActionButtons(
        status,
        paymentStatus,
        orderType,
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget? _buildActionButtons(
    String status,
    String paymentStatus,
    String orderType,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status-specific action buttons
          if (status == 'pending') ...[
            // Mark as Preparing button
            ElevatedButton(
              onPressed: _isUpdating ? null : _markAsPreparing,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isUpdating
                  ? CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.restaurant),
                        SizedBox(width: 8),
                        Text(
                          'Mark as Preparing',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
            SizedBox(height: 12),
            // Return/Cancel button for pending orders
            ElevatedButton(
              onPressed: _isUpdating ? null : _returnOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isUpdating
                  ? CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cancel_outlined),
                        SizedBox(width: 8),
                        Text(
                          'Cancel Order',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
          ],

          if (status == 'preparing') ...[
            // Mark as Prepared button
            ElevatedButton(
              onPressed: _isUpdating ? null : _markAsPrepared,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isUpdating
                  ? CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline),
                        SizedBox(width: 8),
                        Text(
                          'Mark as Prepared',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
            SizedBox(height: 12),
            // Return to Pending button
            ElevatedButton(
              onPressed: _isUpdating ? null : _returnToPending,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isUpdating
                  ? CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.undo),
                        SizedBox(width: 8),
                        Text(
                          'Return to Pending',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
          ],

          if (status == 'prepared') ...[
            // Mark as Served button
            ElevatedButton(
              onPressed: _isUpdating ? null : () => _markAsServed(orderType),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isUpdating
                  ? CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.room_service),
                        SizedBox(width: 8),
                        Text(
                          orderType == 'takeaway'
                              ? 'Mark as Picked Up'
                              : 'Mark as Served',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
            SizedBox(height: 12),
            // Return to Preparing button
            ElevatedButton(
              onPressed: _isUpdating ? null : _returnToPreparing,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isUpdating
                  ? CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.undo),
                        SizedBox(width: 8),
                        Text(
                          'Return to Preparing',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
          ],

          if (status == 'served') ...[
            if (paymentStatus == 'unpaid') ...[
              // Mark as Paid button
              ElevatedButton(
                onPressed: _isUpdating ? null : _showPaymentOptions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isUpdating
                    ? CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payment),
                          SizedBox(width: 8),
                          Text(
                            'Mark as Paid',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
              ),
              SizedBox(height: 12),
            ],
            // Return to Prepared button
            ElevatedButton(
              onPressed: _isUpdating ? null : _returnToPrepared,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isUpdating
                  ? CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.undo),
                        SizedBox(width: 8),
                        Text(
                          'Return to Prepared',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
          ],

          if (paymentStatus == 'paid') ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'Order has been paid',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (status == 'cancelled') ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    'Order was cancelled',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'served':
        return Colors.blue;
      case 'prepared':
        return Colors.green;
      case 'preparing':
        return Colors.orange;
      case 'paid':
        return Colors.teal;
      case 'pending':
        return Colors.amber[700]!;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  Future<void> _markAsPreparing() async {
    setState(() => _isUpdating = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final branchId = userProvider.currentBranch;
      if (branchId == null) return;

      await FirestoreService.updateOrderStatusWithTable(
        branchId,
        widget.order.id,
        'preparing',
      );
      _showSuccessSnackbar('Order marked as preparing!');
      Navigator.pop(context);
    } on FirebaseException catch (e) {
      _showErrorSnackbar('Update failed: ${e.message}');
    } catch (e) {
      _showErrorSnackbar('Update failed: ${e.toString()}');
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _markAsPrepared() async {
    setState(() => _isUpdating = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final branchId = userProvider.currentBranch;
      if (branchId == null) return;

      await FirestoreService.updateOrderStatusWithTable(
        branchId,
        widget.order.id,
        'prepared',
      );
      _showSuccessSnackbar('Order marked as prepared!');
      Navigator.pop(context);
    } on FirebaseException catch (e) {
      _showErrorSnackbar('Update failed: ${e.message}');
    } catch (e) {
      _showErrorSnackbar('Update failed: ${e.toString()}');
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _markAsServed(String orderType) async {
    setState(() => _isUpdating = true);
    try {
      final orderData =
          (widget.order.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
      final tableNumber = orderData['tableNumber']?.toString();

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final branchId = userProvider.currentBranch;
      if (branchId == null) return;

      final userProvider2 = Provider.of<UserProvider>(context, listen: false);
      final branchId2 = userProvider2.currentBranch;

      if (branchId2 != null) {
        await FirestoreService.updateOrderStatusWithTable(
          branchId2,
          widget.order.id,
          'served',
          tableNumber: orderType == 'dine_in' ? tableNumber : null,
        );
      }

      _showSuccessSnackbar(
        orderType == 'takeaway'
            ? 'Order marked as picked up!'
            : 'Order marked as served!',
      );
      Navigator.pop(context);
    } on FirebaseException catch (e) {
      _showErrorSnackbar('Update failed: ${e.message}');
    } catch (e) {
      _showErrorSnackbar('Update failed: ${e.toString()}');
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _processPayment(String paymentMethod) async {
    Navigator.pop(context);
    setState(() => _isUpdating = true);

    try {
      final orderData =
          (widget.order.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
      final orderType = orderData['Order_type']?.toString() ?? 'dine_in';
      final totalAmount = (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final tableNumber = orderData['tableNumber']?.toString();

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final branchId = userProvider.currentBranch;
      if (branchId == null) return;

      final userProvider2 = Provider.of<UserProvider>(context, listen: false);
      final branchId2 = userProvider2.currentBranch;

      if (branchId2 != null) {
        await FirestoreService.processPayment(
          branchId: branchId2,
          orderId: widget.order.id,
          paymentMethod: paymentMethod,
          amount: totalAmount,
          tableNumber: orderType == 'dine_in' ? tableNumber : null,
        );
      }

      _showSuccessSnackbar(
        'Payment processed successfully with ${paymentMethod.toUpperCase()}!',
      );
      Navigator.pop(context);
    } on FirebaseException catch (e) {
      _showErrorSnackbar('Payment failed: ${e.message}');
    } catch (e) {
      _showErrorSnackbar('Payment failed: ${e.toString()}');
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  // Helper methods
  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _returnOrder() async {
    // Show confirmation dialog first
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Cancel Order'),
          content: Text(
            'Are you sure you want to cancel this order? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isUpdating = true);

    try {
      await FirebaseFirestore.instance
          .collection('Orders')
          .doc(widget.order.id)
          .update({'status': 'cancelled'});

      // Clear table if it's a dine-in order
      final orderData =
          (widget.order.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
      final orderType = orderData['Order_type']?.toString() ?? 'dine_in';

      if (orderType == 'dine_in') {
        final tableNumber = orderData['tableNumber']?.toString();
        if (tableNumber != null) {
          final tableUpdate = <String, dynamic>{};
          tableUpdate['Tables.$tableNumber.status'] = 'available';
          tableUpdate['Tables.$tableNumber.currentOrderId'] =
              FieldValue.delete();

          final userProvider = Provider.of<UserProvider>(
            context,
            listen: false,
          );
          final branchId = userProvider.currentBranch;

          if (branchId != null) {
            await FirebaseFirestore.instance
                .collection('Branch')
                .doc(branchId)
                .update(tableUpdate);
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order cancelled successfully!'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling order: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _returnToPending() async {
    setState(() => _isUpdating = true);

    try {
      await FirebaseFirestore.instance
          .collection('Orders')
          .doc(widget.order.id)
          .update({'status': 'pending'});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order returned to pending!'),
          backgroundColor: Colors.amber[700],
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating order: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _returnToPreparing() async {
    setState(() => _isUpdating = true);

    try {
      await FirebaseFirestore.instance
          .collection('Orders')
          .doc(widget.order.id)
          .update({'status': 'preparing'});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order returned to preparing!'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating order: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _returnToPrepared() async {
    setState(() => _isUpdating = true);

    try {
      await FirebaseFirestore.instance
          .collection('Orders')
          .doc(widget.order.id)
          .update({'status': 'prepared'});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order returned to prepared!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating order: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  void _showPaymentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Payment Method',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _processPayment('cash'),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.money, size: 40, color: Colors.green),
                            SizedBox(height: 8),
                            Text(
                              'Cash',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _processPayment('card'),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.credit_card,
                              size: 40,
                              color: Colors.blue,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Card',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }
}
