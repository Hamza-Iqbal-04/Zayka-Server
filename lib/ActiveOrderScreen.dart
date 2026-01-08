import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'FirestoreService.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:vibration/vibration.dart';

class ActiveOrdersScreen extends StatefulWidget {
  @override
  _ActiveOrdersScreenState createState() => _ActiveOrdersScreenState();
}

class _ActiveOrdersScreenState extends State<ActiveOrdersScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryColor = Color(0xFF1976D2);
  final Color secondaryColor = Color(0xFFE3F2FD);
  final AudioPlayer _audioPlayer = AudioPlayer();

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
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _audioPlayer.dispose(); // Add this line
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _shownPreparedOrders.clear();
    }
  }

  Future<void> _triggerVibration() async {
    try {
      // Check if device can vibrate
      if (await Vibration.hasVibrator() ?? false) {
        // Pattern: wait 0.5s, vibrate 1s, wait 0.2s, vibrate 1s
        Vibration.vibrate(pattern: [500, 1000, 200, 1000]);
      }
    } catch (e) {
      print('Vibration error: $e');
      // Fallback: simple vibration
      Vibration.vibrate(duration: 1000);
    }
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

        if (snapshot.hasData) {
          _checkForPreparedOrders(snapshot.data!);
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
            setState(() {});
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

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('Orders')
          .where('branchIds', arrayContains: 'Mansoura')
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

  void _checkForPreparedOrders(QuerySnapshot snapshot) {
    final orders = snapshot.docs;

    for (final order in orders) {
      final orderData = order.data() as Map<String, dynamic>;
      final status = orderData['status']?.toString() ?? '';
      final orderId = order.id;
      final dailyOrderNumber = orderData['dailyOrderNumber']?.toString() ?? '';
      final orderType = orderData['Order_type']?.toString() ?? 'dine_in';
      final tableNumber = orderData['tableNumber']?.toString();
      final customerName = orderData['customerName']?.toString();
      final carPlateNumber = orderData['carPlateNumber']?.toString();

      if (status == 'prepared' && !_shownPreparedOrders.contains(orderId)) {
        _shownPreparedOrders.add(orderId);

        // Store order details for the popup
        final orderDetails = {
          'orderId': orderId,
          'orderNumber': dailyOrderNumber,
          'orderType': orderType,
          'tableNumber': tableNumber,
          'customerName': customerName,
          'carPlateNumber': carPlateNumber,
          'timestamp': DateTime.now(),
        };

        _showPreparedOrderPopup(orderDetails);
      }
    }
  }

  Future<void> _triggerSoundEffect() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/alert.wav'));
    } catch (e) {
      print('Sound error: $e');
      // Fallback to online sound
      try {
        await _audioPlayer.play(
          UrlSource(
            'https://assets.mixkit.co/sfx/download/mixkit-correct-answer-tone-2870.mp3',
          ),
        );
      } catch (e2) {
        print('Fallback sound also failed: $e2');
      }
    }
  }

  // Fallback method for beep sound
  void _showPreparedOrderPopup(Map<String, dynamic> orderDetails) {
    _triggerVibration();
    _triggerSoundEffect(); // Add this line

    Future.delayed(Duration(milliseconds: 500), () {
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return _buildOrderReadyDialog(orderDetails);
        },
      );
    });
  }

  Widget _buildOrderReadyDialog(Map<String, dynamic> orderDetails) {
    final String orderId = orderDetails['orderId'];
    final String orderNumber = orderDetails['orderNumber'];
    final String orderType = orderDetails['orderType'];
    final String? tableNumber = orderDetails['tableNumber'];
    final String? customerName = orderDetails['customerName'];
    final String? carPlateNumber = orderDetails['carPlateNumber'];

    final bool isTakeaway = orderType == 'takeaway';
    final Color typeColor = isTakeaway ? Colors.orange : Colors.blue;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green, Colors.green[700]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.white, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ORDER READY!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isTakeaway ? 'TAKEAWAY' : 'DINE-IN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Information
          Text(
            'Order #$orderNumber',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),

          // Order Type & Details
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isTakeaway ? Icons.shopping_bag : Icons.table_restaurant,
                  color: typeColor,
                  size: 16,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTakeaway ? 'Takeaway Order' : 'Dine-in Order',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: typeColor,
                      ),
                    ),
                    if (isTakeaway && carPlateNumber != null)
                      Text(
                        'Car: $carPlateNumber',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      )
                    else if (isTakeaway && customerName != null)
                      Text(
                        'Customer: $customerName',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    if (!isTakeaway && tableNumber != null)
                      Text(
                        'Table: $tableNumber',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Action Required
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.amber[700], size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isTakeaway
                        ? 'Ready for customer pickup'
                        : 'Ready to serve at table',
                    style: TextStyle(
                      color: Colors.amber[800],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Dismiss Button
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
          child: Text('Dismiss'),
        ),

        // View Details Button
        OutlinedButton(
          onPressed: () {
            Navigator.of(context).pop();
            _navigateToOrderDetails(orderId);
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryColor,
            side: BorderSide(color: primaryColor),
          ),
          child: Text('View Details'),
        ),

        // Mark as Served/Picked Up Button
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            _markAsServed(orderId, orderType);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: Text(isTakeaway ? 'Mark Picked Up' : 'Mark Served'),
        ),
      ],
    );
  }

  void _navigateToOrderDetails(String orderId) {
    _firestore.collection('Orders').doc(orderId).get().then((doc) {
      if (doc.exists && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderDetailScreen(order: doc)),
        );
      }
    });
  }

  Future<void> _markAsServed(String orderId, String orderType) async {
    try {
      final orderDoc = await _firestore.collection('Orders').doc(orderId).get();
      final orderData = orderDoc.data() as Map<String, dynamic>?;
      final tableNumber = orderData?['tableNumber']?.toString();

      await _firestore.runTransaction((transaction) async {
        final orderRef = _firestore.collection('Orders').doc(orderId);
        transaction.update(orderRef, {
          'status': 'served',
          'paymentStatus': 'unpaid',
        });

        // Update table status only for dine-in orders
        if (orderType == 'dine_in' && tableNumber != null) {
          final branchRef = _firestore.collection('Branch').doc('Mansoura');
          transaction.update(branchRef, {
            'Tables.$tableNumber.status': 'occupied',
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              orderType == 'takeaway'
                  ? 'Order marked as picked up!'
                  : 'Order marked as served!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Stream<QuerySnapshot> _getOrdersStream(String orderType) {
    try {
      Query query = _firestore
          .collection('Orders')
          .where('branchIds', arrayContains: 'Mansoura')
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

          // Show status info for paid orders
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

          // Show status info for cancelled orders
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
      await FirestoreService.updateOrderStatusWithTable(
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
      await FirestoreService.updateOrderStatusWithTable(
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

      await FirestoreService.updateOrderStatusWithTable(
        widget.order.id,
        'served',
        tableNumber: orderType == 'dine_in' ? tableNumber : null,
      );

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

      await FirestoreService.processPayment(
        orderId: widget.order.id,
        paymentMethod: paymentMethod,
        amount: totalAmount,
        tableNumber: orderType == 'dine_in' ? tableNumber : null,
      );

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

          await FirebaseFirestore.instance
              .collection('Branch')
              .doc('Mansoura')
              .update(tableUpdate);
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
