import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'OrderDetailScreen.dart';
import 'package:provider/provider.dart';
import '../Providers/UserProvider.dart';

class ActiveOrdersScreen extends StatefulWidget {
  @override
  _ActiveOrdersScreenState createState() => _ActiveOrdersScreenState();
}

class _ActiveOrdersScreenState extends State<ActiveOrdersScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryColor = Color(0xFF1976D2);

  late TabController _tabController;
  List<String> _shownPreparedOrders = [];

  // Track expanded state for each section
  Map<String, bool> _expandedSections = {
    'ready': true,
    'preparing': true,
    'pending': true,
    'paid': true,
    'served': true,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double systemBottom = MediaQuery.of(context).padding.bottom;
    final double innerTabHeight = 54.0;
    final double preferredHeight = innerTabHeight + systemBottom;

    return Scaffold(
      backgroundColor: Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Active Orders",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(preferredHeight),
          child: Container(
            color: Colors.white,
            height: preferredHeight,
            padding: EdgeInsets.only(bottom: systemBottom),
            child: Center(
              child: SizedBox(
                height: innerTabHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.hardEdge,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: false,
                      indicatorSize: TabBarIndicatorSize.label,
                      indicatorColor: primaryColor,
                      indicatorWeight: 3,
                      labelColor: primaryColor,
                      unselectedLabelColor: Colors.grey[600],
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                      labelPadding: EdgeInsets.zero,
                      tabs: [
                        Tab(text: 'All'),
                        Tab(text: 'Dine In'),
                        Tab(text: 'Takeaway'),
                        Tab(text: 'Completed'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOrdersList('all'),
                _buildOrdersList('dine_in'),
                _buildOrdersList('takeaway'),
                _buildCompletedOrdersList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(String orderType) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getOrdersStream(orderType),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData) {
          return _buildLoadingState();
        }

        final orders = snapshot.data!.docs;

        if (orders.isEmpty) {
          return _buildEmptyState(orderType);
        }

        final pendingOrders = orders
            .where(
              (order) =>
                  (order.data() as Map<String, dynamic>)['status'] == 'pending',
            )
            .toList();
        final preparingOrders = orders
            .where(
              (order) =>
                  (order.data() as Map<String, dynamic>)['status'] ==
                  'preparing',
            )
            .toList();
        final preparedOrders = orders
            .where(
              (order) =>
                  (order.data() as Map<String, dynamic>)['status'] ==
                  'prepared',
            )
            .toList();

        return RefreshIndicator(
          onRefresh: () async {
            // Removed setState - RefreshIndicator handles the visual state
            await Future.delayed(Duration(milliseconds: 500));
          },
          child: ListView(
            padding: EdgeInsets.all(16),
            children: [
              _buildSummaryCards(
                pendingOrders.length,
                preparingOrders.length,
                preparedOrders.length,
              ),
              SizedBox(height: 20),
              if (preparedOrders.isNotEmpty)
                _buildExpandableSection(
                  'Ready to Serve',
                  preparedOrders.length,
                  Colors.green,
                  'ready',
                  preparedOrders,
                ),
              if (preparingOrders.isNotEmpty)
                _buildExpandableSection(
                  'Preparing',
                  preparingOrders.length,
                  Colors.orange,
                  'preparing',
                  preparingOrders,
                ),
              if (pendingOrders.isNotEmpty)
                _buildExpandableSection(
                  'New Orders',
                  pendingOrders.length,
                  Colors.red,
                  'pending',
                  pendingOrders,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpandableSection(
    String title,
    int count,
    Color color,
    String sectionKey,
    List<QueryDocumentSnapshot> orders,
  ) {
    bool isExpanded = _expandedSections[sectionKey] ?? true;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Header - clickable to expand/collapse
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              onTap: () {
                setState(() {
                  _expandedSections[sectionKey] = !isExpanded;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  border: Border.all(color: color.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: color,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content - animated expand/collapse
          AnimatedCrossFade(
            duration: Duration(milliseconds: 300),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                SizedBox(height: 8),
                ...orders.map(
                  (order) => Padding(
                    key: ValueKey(order.id), // Key for efficient list diffing
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: _buildOrderCard(order, sectionKey == 'ready'),
                  ),
                ),
                SizedBox(height: 8),
              ],
            ),
            secondChild: Container(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableCompletedSection(
    String title,
    int count,
    Color color,
    String sectionKey,
    List<QueryDocumentSnapshot> orders,
  ) {
    bool isExpanded = _expandedSections[sectionKey] ?? true;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Header - clickable to expand/collapse
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              onTap: () {
                setState(() {
                  _expandedSections[sectionKey] = !isExpanded;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  border: Border.all(color: color.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: color,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content - animated expand/collapse
          AnimatedCrossFade(
            duration: Duration(milliseconds: 300),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                SizedBox(height: 8),
                ...orders.map(
                  (order) => Padding(
                    key: ValueKey(order.id), // Key for efficient list diffing
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: _buildCompletedOrderCard(order),
                  ),
                ),
                SizedBox(height: 8),
              ],
            ),
            secondChild: Container(),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(QueryDocumentSnapshot order, bool isPriority) {
    final orderData = order.data() as Map<String, dynamic>;
    final orderType = orderData['Order_type']?.toString() ?? 'dine_in';
    final tableNumber = orderData['tableNumber']?.toString();
    final customerName = orderData['customerName']?.toString();
    final carPlateNumber = orderData['carPlateNumber']?.toString();
    final status = orderData['status']?.toString() ?? 'unknown';
    final dailyOrderNumber = orderData['dailyOrderNumber']?.toString() ?? '';
    final totalAmount = (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final timestamp = orderData['timestamp'] as Timestamp?;
    final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);
    final statusColor = _getFirestoreStatusColor(status);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        border: isPriority ? Border.all(color: Colors.green, width: 2) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailScreen(order: order),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Order # and Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #$dailyOrderNumber',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Order Info: Type and Location
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: orderType == 'takeaway'
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            orderType == 'takeaway'
                                ? Icons.shopping_bag_outlined
                                : Icons.table_restaurant_outlined,
                            size: 14,
                            color: orderType == 'takeaway'
                                ? Colors.orange[700]
                                : Colors.blue[700],
                          ),
                          SizedBox(width: 6),
                          Text(
                            orderType == 'takeaway'
                                ? (carPlateNumber != null
                                      ? 'Car: $carPlateNumber'
                                      : (customerName != null
                                            ? 'Customer: $customerName'
                                            : 'Takeaway'))
                                : 'Table $tableNumber',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: orderType == 'takeaway'
                                  ? Colors.orange[700]
                                  : Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Spacer(),
                    Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                    SizedBox(width: 4),
                    Text(
                      timestamp != null
                          ? _formatTime(timestamp.toDate())
                          : 'Unknown',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Divider(height: 1, color: Colors.grey[200]),
                SizedBox(height: 16),

                // Items Summary
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${items.length} Items',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            items
                                    .take(2)
                                    .map(
                                      (item) =>
                                          '${item['quantity']}x ${item['name']}',
                                    )
                                    .join(', ') +
                                (items.length > 2 ? '...' : ''),
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'TOTAL',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '\$${totalAmount.toStringAsFixed(2)}',
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
                if (isPriority) ...[
                  SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: Colors.green[700],
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Ready to Serve',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedOrderCard(QueryDocumentSnapshot order) {
    final orderData = order.data() as Map<String, dynamic>;
    final dailyOrderNumber = orderData['dailyOrderNumber']?.toString() ?? '';
    final orderType = orderData['Order_type']?.toString() ?? 'dine_in';
    final totalAmount = (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final paymentMethod = orderData['paymentMethod']?.toString() ?? 'N/A';
    final timestamp = orderData['timestamp'] as Timestamp?;
    final paymentTime = orderData['paymentTime'] as Timestamp?;
    final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);
    final tableNumber = orderData['tableNumber']?.toString();
    final customerName = orderData['customerName']?.toString();
    final carPlateNumber = orderData['carPlateNumber']?.toString();
    final status = orderData['status']?.toString() ?? '';
    final paymentStatus = orderData['paymentStatus']?.toString() ?? 'unpaid';

    // Determine if order is paid or unpaid
    final bool isPaid = status == 'paid' || paymentStatus == 'paid';
    final Color statusColor = isPaid ? Colors.green : Colors.blue;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailScreen(order: order),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #$dailyOrderNumber',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        isPaid ? 'PAID' : 'UNPAID',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Order Details Row
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: orderType == 'takeaway'
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            orderType == 'takeaway'
                                ? Icons.shopping_bag_outlined
                                : Icons.table_restaurant_outlined,
                            size: 14,
                            color: orderType == 'takeaway'
                                ? Colors.orange[700]
                                : Colors.blue[700],
                          ),
                          SizedBox(width: 6),
                          Text(
                            orderType == 'takeaway'
                                ? (carPlateNumber != null
                                      ? 'Car: $carPlateNumber'
                                      : (customerName != null
                                            ? 'Customer: $customerName'
                                            : 'Takeaway'))
                                : 'Table $tableNumber',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: orderType == 'takeaway'
                                  ? Colors.orange[700]
                                  : Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Spacer(),
                    Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                    SizedBox(width: 4),
                    Text(
                      isPaid
                          ? (paymentTime != null
                                ? _formatTime(paymentTime.toDate())
                                : _formatTime(
                                    timestamp?.toDate() ?? DateTime.now(),
                                  ))
                          : (timestamp != null
                                ? _formatTime(timestamp.toDate())
                                : 'Unknown'),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Divider(height: 1, color: Colors.grey[200]),
                SizedBox(height: 16),

                // Items Summary
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${items.length} Items',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            items
                                    .take(2)
                                    .map(
                                      (item) =>
                                          '${item['quantity']}x ${item['name']}',
                                    )
                                    .join(', ') +
                                (items.length > 2 ? '...' : ''),
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Divider(height: 1, color: Colors.grey[200]),
                SizedBox(height: 16),

                // Footer Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PAYMENT METHOD',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          paymentMethod.toUpperCase(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'TOTAL',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '\$${totalAmount.toStringAsFixed(2)}',
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedOrdersList() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final branchId = userProvider.currentBranch;

    if (branchId == null)
      return Container(); // Should handle better but for now

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('Orders')
          .where('branchIds', arrayContains: branchId)
          .where('status', whereIn: ['paid', 'served'])
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }
        if (!snapshot.hasData) {
          return _buildEmptyState('completed');
        }

        final orders = snapshot.data!.docs;
        if (orders.isEmpty) {
          return _buildEmptyState('completed');
        }

        final paidOrders = orders.where((order) {
          final orderData = order.data() as Map<String, dynamic>;
          return orderData['status'] == 'paid' ||
              orderData['paymentStatus'] == 'paid';
        }).toList();

        final unpaidOrders = orders.where((order) {
          final orderData = order.data() as Map<String, dynamic>;
          return orderData['status'] == 'served' &&
              (orderData['paymentStatus'] != 'paid');
        }).toList();

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
            await Future.delayed(Duration(milliseconds: 500));
          },
          child: ListView(
            padding: EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Unpaid',
                      unpaidOrders.length,
                      Colors.blue,
                      Icons.money_off,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      'Paid',
                      paidOrders.length,
                      Colors.green,
                      Icons.payment,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),

              // Put Unpaid Orders first
              if (unpaidOrders.isNotEmpty)
                _buildExpandableCompletedSection(
                  'Unpaid Orders',
                  unpaidOrders.length,
                  Colors.blue,
                  'unpaid',
                  unpaidOrders,
                ),

              // Then Paid Orders
              if (paidOrders.isNotEmpty)
                _buildExpandableCompletedSection(
                  'Paid Orders',
                  paidOrders.length,
                  Colors.green,
                  'paid',
                  paidOrders,
                ),
            ],
          ),
        );
      },
    );
  }

  Stream<QuerySnapshot> _getOrdersStream(String orderType) {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final branchId = userProvider.currentBranch;

      if (branchId == null) return Stream.empty();

      Query query = _firestore
          .collection('Orders')
          .where('branchIds', arrayContains: branchId)
          .where('status', whereIn: ['pending', 'preparing', 'prepared']);
      if (orderType != 'all') {
        query = query.where('Order_type', isEqualTo: orderType);
      }
      return query.orderBy('timestamp', descending: true).snapshots();
    } catch (e) {
      return Stream.empty();
    }
  }

  Widget _buildSummaryCards(int pending, int preparing, int prepared) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard('New', pending, Colors.red, Icons.fiber_new),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Preparing',
            preparing,
            Colors.orange,
            Icons.restaurant,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Ready',
            prepared,
            Colors.green,
            Icons.check_circle,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    int count,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1.0,
            ),
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String orderType) {
    String message;
    IconData icon;

    switch (orderType) {
      case 'dine_in':
        message = 'No active dine-in orders';
        icon = Icons.table_restaurant;
        break;
      case 'takeaway':
        message = 'No active takeaway orders';
        icon = Icons.shopping_bag;
        break;
      case 'completed':
        message = 'No completed orders for today';
        icon = Icons.check_circle_outline;
        break;
      default:
        message = 'No active orders';
        icon = Icons.restaurant;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 18, color: Colors.grey)),
          if (orderType != 'completed') ...[
            SizedBox(height: 8),
            Text(
              'Orders will appear here when they are placed',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text(
            'Error loading orders',
            style: TextStyle(fontSize: 18, color: Colors.red),
          ),
          SizedBox(height: 8),
          Text(
            'Please check your connection',
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() {}),
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryColor),
          SizedBox(height: 16),
          Text('Loading orders...', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Color _getFirestoreStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'prepared':
        return Colors.green;
      case 'preparing':
        return Colors.orange;
      case 'pending':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}';
    }
  }
}
