import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ActiveOrderScreen.dart';
import '../Firebase/FirestoreService.dart';
import 'OrderDetailScreen.dart';
import '../main.dart';
import 'package:provider/provider.dart';
import '../Providers/UserProvider.dart';
import 'ProfileScreen.dart';

class TablesScreen extends StatefulWidget {
  @override
  _TablesScreenState createState() => _TablesScreenState();
}

class TableStatusInfo {
  final Color color;
  final IconData icon;
  final String statusText;

  TableStatusInfo({
    required this.color,
    required this.icon,
    required this.statusText,
  });
}

class _TablesScreenState extends State<TablesScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryColor = Color(0xFF1976D2);
  final Color secondaryColor = Color(0xFFE3F2FD);

  late AnimationController _refreshController;
  late AnimationController _statsController;
  String _selectedFilter = 'all';
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _statsController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _statsController.forward();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _statsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final branchId = userProvider.currentBranch;

    if (userProvider.isLoading) {
      return _buildLoadingState();
    }

    if (branchId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Text("No Branch Assigned"),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                // Retry by re-fetching profile? Or just logout
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileScreen()),
                );
              },
              child: Text("Go to Profile"),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Container(
        color: Color(0xFFF5F6F8),
        child: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('Branch').doc(branchId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorState();
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              // Only return loading if we are truly waiting,
              // if it doesn't exist it might be a configured branch issue
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingState();
              }
              return Center(child: Text("Branch '$branchId' not found."));
            }

            final branchData = snapshot.data!.data() as Map<String, dynamic>;
            final tables = branchData['Tables'] as Map<String, dynamic>? ?? {};
            final filteredTables = _getFilteredTablesList(tables);

            return RefreshIndicator(
              onRefresh: _handleRefresh,
              color: primaryColor,
              child: CustomScrollView(
                physics: BouncingScrollPhysics(),
                slivers: [
                  _buildAppBar(),
                  _buildQuickStats(tables),
                  _buildFilterChips(tables),
                  _buildViewToggle(),
                  _isGridView
                      ? _buildTablesGrid(filteredTables)
                      : _buildTablesList(filteredTables),
                  SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red[50],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          ),
          SizedBox(height: 24),
          Text(
            'Oops! Something went wrong',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Unable to load restaurant tables',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _handleRefresh(),
            icon: Icon(Icons.refresh),
            label: Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
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
          Container(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              color: primaryColor,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Loading Tables...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please wait while we fetch the latest data',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      floating: false,
      expandedHeight: 100.0,
      backgroundColor: Colors.white,
      automaticallyImplyLeading: false,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(left: 20, bottom: 20),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Restaurant Tables',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.black87,
                height: 1.0,
              ),
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.store_rounded, color: primaryColor, size: 14),
                SizedBox(width: 4),
                Text(
                  'Branch: ${Provider.of<UserProvider>(context).currentBranch ?? "Unknown"}',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        background: Stack(
          children: [
            Container(color: Colors.white),
            Positioned(
              right: -30,
              top: -20,
              child: Transform.rotate(
                angle: -0.2,
                child: Icon(
                  Icons.table_restaurant_rounded,
                  size: 180,
                  color: primaryColor.withOpacity(0.05),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        AnimatedBuilder(
          animation: _refreshController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _refreshController.value * 2 * 3.14159,
              child: IconButton(
                icon: Icon(
                  Icons.refresh_rounded,
                  color: primaryColor,
                  size: 26,
                ),
                onPressed: _handleRefresh,
              ),
            );
          },
        ),
        IconButton(
          icon: Container(
            padding: EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: primaryColor, width: 2),
            ),
            child: Icon(Icons.person, color: primaryColor, size: 20),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileScreen()),
            );
          },
        ),
        SizedBox(width: 8),
      ],
    );
  }

  Widget _buildQuickStats(Map<String, dynamic> tables) {
    return SliverToBoxAdapter(
      // Using SlideTransition + FadeTransition with child caching for better performance
      child: SlideTransition(
        position: Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: _statsController, curve: Curves.easeOut),
            ),
        child: FadeTransition(
          opacity: _statsController,
          child: Container(
            margin: EdgeInsets.all(20),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickStat(
                  'Total',
                  tables.length,
                  Colors.grey[800]!,
                  Icons.grid_view_rounded,
                ),
                _buildVerticalDivider(),
                _buildQuickStat(
                  'Available',
                  _getStatusCount(tables, 'available'),
                  Colors.green,
                  Icons.check_circle_outline,
                ),
                _buildVerticalDivider(),
                _buildQuickStat(
                  'Ordered',
                  _getStatusCount(tables, 'ordered'),
                  Colors.blue,
                  Icons.restaurant_menu,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 40, width: 1, color: Colors.grey[300]);
  }

  Widget _buildQuickStat(String label, int count, Color color, IconData icon) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
            height: 1.0,
          ),
        ),
        SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips(Map<String, dynamic> tables) {
    final filterData = [
      {'label': 'All', 'value': 'all', 'count': tables.length},
      {
        'label': 'Available',
        'value': 'available',
        'count': _getStatusCount(tables, 'available'),
      },
      {
        'label': 'Ordered',
        'value': 'ordered',
        'count': _getStatusCount(tables, 'ordered'),
      },
    ];

    return SliverToBoxAdapter(
      child: Container(
        height: 60,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 20),
          itemCount: filterData.length,
          itemBuilder: (context, index) {
            final filter = filterData[index];
            final isSelected = _selectedFilter == filter['value'];

            return Padding(
              padding: EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFilter = filter['value'] as String;
                  });
                  HapticFeedback.selectionClick();
                },
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        )
                      else
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        filter['label'] as String,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(width: 6),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withOpacity(0.2)
                              : primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          (filter['count'] as int).toString(),
                          style: TextStyle(
                            color: isSelected ? Colors.white : primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tables',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildViewButton(Icons.grid_view, true),
                  _buildViewButton(Icons.list, false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewButton(IconData icon, bool isGrid) {
    final isSelected = _isGridView == isGrid;
    return GestureDetector(
      onTap: () {
        setState(() {
          _isGridView = isGrid;
        });
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.grey[600],
          size: 20,
        ),
      ),
    );
  }

  Widget _buildTablesGrid(List<MapEntry<String, dynamic>> filteredTables) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        // Calculate optimal column count based on available width
        final double availableWidth = constraints.crossAxisExtent;
        int crossAxisCount;
        double childAspectRatio;

        if (availableWidth > 1200) {
          crossAxisCount = 6;
          childAspectRatio = 0.85;
        } else if (availableWidth > 900) {
          crossAxisCount = 5;
          childAspectRatio = 0.8;
        } else if (availableWidth > 600) {
          crossAxisCount = 4;
          childAspectRatio = 0.75;
        } else {
          crossAxisCount = 3;
          childAspectRatio = 0.7;
        }

        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: childAspectRatio,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final entry = filteredTables[index];
              return _buildTableCard(
                context,
                entry.key,
                entry.value as Map<String, dynamic>,
              );
            }, childCount: filteredTables.length),
          ),
        );
      },
    );
  }

  Widget _buildTablesList(List<MapEntry<String, dynamic>> filteredTables) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final entry = filteredTables[index];
          return Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _buildTableListItem(
              context,
              entry.key,
              entry.value as Map<String, dynamic>,
            ),
          );
        }, childCount: filteredTables.length),
      ),
    );
  }

  Widget _buildTableCard(
    BuildContext context,
    String tableNumber,
    Map<String, dynamic> tableData,
  ) {
    final status = tableData['status']?.toString() ?? 'available';
    final seats = tableData['seats']?.toString() ?? '0';
    final currentOrderId = tableData['currentOrderId']?.toString();
    final tableInfo = _getTableStatusInfo(status);

    return GestureDetector(
      onTap: () => _navigateToOrderScreen(
        context,
        tableNumber,
        tableData,
        currentOrderId,
        status,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
            // Status Dot
            Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: tableInfo.color.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: tableInfo.color,
                  shape: BoxShape.circle,
                ),
              ),
            ),

            Text(
              'Table $tableNumber',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '$seats Seats',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: tableInfo.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tableInfo.statusText.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: tableInfo.color,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableListItem(
    BuildContext context,
    String tableNumber,
    Map<String, dynamic> tableData,
  ) {
    final status = tableData['status']?.toString() ?? 'available';
    final seats = tableData['seats']?.toString() ?? '0';
    final currentOrderId = tableData['currentOrderId']?.toString();
    final tableInfo = _getTableStatusInfo(status);

    return GestureDetector(
      onTap: () => _navigateToOrderScreen(
        context,
        tableNumber,
        tableData,
        currentOrderId,
        status,
      ),
      child: Container(
        padding: EdgeInsets.all(20),
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
        child: Row(
          children: [
            // Status Dot
            Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: tableInfo.color.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: tableInfo.color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Table $tableNumber',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.chair_alt_outlined,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      SizedBox(width: 4),
                      Text(
                        '$seats Seats',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: tableInfo.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tableInfo.statusText.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: tableInfo.color,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToOrderScreen(
    BuildContext context,
    String tableNumber,
    Map<String, dynamic> tableData,
    String? currentOrderId,
    String status,
  ) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderScreen(
          tableNumber: tableNumber,
          tableData: Map<String, dynamic>.from(tableData),
          existingOrderId: currentOrderId,
          isAddingToExisting: status == 'ordered',
        ),
      ),
    );
  }

  List<MapEntry<String, dynamic>> _getFilteredTablesList(
    Map<String, dynamic> tables,
  ) {
    if (_selectedFilter == 'all') {
      return tables.entries.toList();
    }

    return tables.entries.where((entry) {
      final tableData = entry.value as Map<String, dynamic>;
      final status = tableData['status']?.toString() ?? 'available';
      return status == _selectedFilter;
    }).toList();
  }

  TableStatusInfo _getTableStatusInfo(String status) {
    switch (status) {
      case 'occupied':
        return TableStatusInfo(
          color: Colors.orange[600]!,
          icon: Icons.group_rounded,
          statusText: 'Occupied',
        );
      case 'needs_attention':
        return TableStatusInfo(
          color: Colors.red[600]!,
          icon: Icons.notification_important_rounded,
          statusText: 'Need Help',
        );
      case 'ordered':
        return TableStatusInfo(
          color: Colors.red,
          icon: Icons.restaurant_menu_rounded,
          statusText: 'Ordered',
        );
      default:
        return TableStatusInfo(
          color: Colors.green[600]!,
          icon: Icons.check_circle_rounded,
          statusText: 'Available',
        );
    }
  }

  int _getStatusCount(Map<String, dynamic> tables, String targetStatus) {
    return tables.values.where((value) {
      final tableData = value as Map<String, dynamic>;
      final status = tableData['status']?.toString() ?? 'available';
      return status == targetStatus;
    }).length;
  }

  Future<void> _handleRefresh() async {
    _refreshController.forward();
    await Future.delayed(Duration(milliseconds: 1000));
    _refreshController.reset();
    HapticFeedback.mediumImpact();
  }
}

class OrderScreen extends StatefulWidget {
  final String tableNumber;
  final Map<String, dynamic> tableData;
  final String? existingOrderId;
  final bool isAddingToExisting;

  OrderScreen({
    required this.tableNumber,
    required this.tableData,
    this.existingOrderId,
    this.isAddingToExisting = false,
  });

  @override
  _OrderScreenState createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryColor = Color(0xFF1976D2);
  final Color secondaryColor = Color(0xFFF5F5F5);
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _cartItems = [];
  double _totalAmount = 0.0;
  List<Map<String, dynamic>> _existingOrderItems = [];
  bool _isCheckingOut = false;
  String _tableStatus = 'available';
  String _searchQuery = '';
  StreamSubscription? _tableStatusSubscription;
  StreamSubscription? _existingOrderSubscription;
  bool _isToggling = false;

  Timer? _timer;
  Duration _elapsed = Duration.zero;
  DateTime? _occupiedTime;

  // New category-related variables
  List<Map<String, dynamic>> _categories = [];
  Set<String> _expandedCategories = <String>{};
  bool _isLoadingCategories = false;
  bool _isLoadingCart = false;

  // Add this variable to track current order ID
  String? _currentOrderId;
  bool _isAddingToExistingOrder = false;

  // Add these variables to track order status and payment status
  String _currentOrderStatus = '';
  String _currentPaymentStatus = 'unpaid';

  // Debounce timer for search input
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _tableStatus = widget.tableData['status']?.toString() ?? 'available';
    _currentOrderId =
        widget.existingOrderId ?? widget.tableData['currentOrderId'];
    _isAddingToExistingOrder =
        widget.isAddingToExisting || (_currentOrderId != null);

    _initializeData();
    _startOrResetTimer();

    // Debounced search listener to prevent rapid rebuilds
    _searchController.addListener(() {
      _searchDebounceTimer?.cancel();
      _searchDebounceTimer = Timer(Duration(milliseconds: 300), () {
        if (mounted && _searchController.text.toLowerCase() != _searchQuery) {
          setState(() {
            _searchQuery = _searchController.text.toLowerCase();
          });
        }
      });
    });
  }

  Future<void> _initializeData() async {
    try {
      await _loadCartItems();
      await _loadCategories();
      _setupListeners();
    } catch (e) {
      _showErrorSnackbar('Failed to initialize: ${e.toString()}');
    }
  }

  void _setupListeners() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final branchId = userProvider.currentBranch;

    if (branchId != null) {
      _tableStatusSubscription = FirestoreService.getBranchStream(branchId)
          .listen((snapshot) {
            if (snapshot.exists && mounted) {
              _handleBranchUpdate(snapshot);
            }
          });
    }

    if (_currentOrderId != null) {
      _listenToExistingOrder();
    }
  }

  void _handleBranchUpdate(DocumentSnapshot snapshot) {
    final branchData = snapshot.data() as Map<String, dynamic>;
    final tables = branchData['Tables'] as Map<String, dynamic>?;

    if (tables != null && tables.containsKey(widget.tableNumber)) {
      final tableData = tables[widget.tableNumber] as Map<String, dynamic>;
      final newStatus = tableData['status']?.toString() ?? 'available';

      setState(() {
        _tableStatus = newStatus;
        _startOrResetTimer();

        final tableOrderId = tableData['currentOrderId']?.toString();
        if (tableOrderId != null && _currentOrderId != tableOrderId) {
          _currentOrderId = tableOrderId;
          _isAddingToExistingOrder = true;
          _listenToExistingOrder();
        }

        if (_tableStatus == 'occupied' || _tableStatus == 'ordered') {
          final Timestamp? ts = tableData['statusTimestamp'];
          if (ts != null) {
            _occupiedTime = ts.toDate();
          } else if (_occupiedTime == null) {
            _occupiedTime = DateTime.now();
          }
        } else {
          _occupiedTime = null;
        }
      });
    }
  }

  // Updated cart loading with error handling
  Future<void> _loadCartItems() async {
    setState(() => _isLoadingCart = true);
    try {
      final items = await FirestoreService.loadCartItems(widget.tableNumber);
      setState(() {
        _cartItems = items;
        _calculateTotal();
      });
    } catch (e) {
      _showErrorSnackbar('Failed to load cart: ${e.toString()}');
    } finally {
      setState(() => _isLoadingCart = false);
    }
  }

  // Updated order submission with transaction
  Future<void> _submitOrder() async {
    if (_cartItems.isEmpty) {
      _showErrorSnackbar('Cart is empty');
      return;
    }

    try {
      if (_isAddingToExistingOrder && _currentOrderId != null) {
        await FirestoreService.addToExistingOrder(
          orderId: _currentOrderId!,
          newItems: _cartItems,
          additionalAmount: _totalAmount,
        );
        _showSuccessSnackbar('Items added to order successfully!');
      } else {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final branchId = userProvider.currentBranch;

        if (branchId == null) {
          _showErrorSnackbar('Branch ID not found');
          return;
        }

        final newOrderId = await FirestoreService.createDineInOrder(
          branchId: branchId,
          tableNumber: widget.tableNumber,
          items: _cartItems,
          totalAmount: _totalAmount,
        );

        setState(() {
          _currentOrderId = newOrderId;
          _isAddingToExistingOrder = true;
        });

        _listenToExistingOrder();
        _showSuccessSnackbar('Order submitted successfully!');
      }

      // Clear local cart state
      setState(() {
        _cartItems.clear();
        _totalAmount = 0.0;
      });

      // Clear persisted cart
      await FirestoreService.clearCart(widget.tableNumber);
    } on FirebaseException catch (e) {
      _showErrorSnackbar('Order failed: ${e.message}');
    } catch (e) {
      _showErrorSnackbar('Order failed: ${e.toString()}');
    }
  }

  // Updated payment processing
  Future<void> _processPayment(String paymentMethod) async {
    Navigator.pop(context);
    setState(() => _isCheckingOut = true);

    try {
      final orderDoc = await FirebaseFirestore.instance
          .collection('Orders')
          .doc(_currentOrderId ?? widget.tableData['currentOrderId'])
          .get();

      if (orderDoc.exists) {
        final orderData = orderDoc.data() as Map<String, dynamic>;
        final totalAmount =
            (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final orderType = orderData['Order_type']?.toString() ?? 'dine_in';

        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final branchId = userProvider.currentBranch;

        if (branchId != null) {
          await FirestoreService.processPayment(
            branchId: branchId,
            orderId: _currentOrderId ?? widget.tableData['currentOrderId']!,
            paymentMethod: paymentMethod,
            amount: totalAmount,
            tableNumber: orderType == 'dine_in' ? widget.tableNumber : null,
          );
        }

        // Reset local state
        setState(() {
          _currentOrderId = null;
          _isAddingToExistingOrder = false;
          _existingOrderItems.clear();
          _currentOrderStatus = '';
          _currentPaymentStatus = 'unpaid';
        });

        _showSuccessSnackbar(
          'Payment processed successfully with ${paymentMethod.toUpperCase()}!',
        );
        Navigator.pop(context);
      }
    } on FirebaseException catch (e) {
      _showErrorSnackbar('Payment failed: ${e.message}');
    } catch (e) {
      _showErrorSnackbar('Payment failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isCheckingOut = false);
      }
    }
  }

  // Updated table availability toggle
  Future<void> _toggleTableAvailability() async {
    if (_isToggling) return;
    setState(() => _isToggling = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final branchId = userProvider.currentBranch;

      if (branchId == null) return;

      if (_tableStatus == 'available') {
        await FirestoreService.updateTableStatus(
          branchId,
          widget.tableNumber,
          'occupied',
        );
        _showSuccessSnackbar('Table ${widget.tableNumber} marked as occupied!');
      } else {
        if (_tableStatus == 'occupied' || _tableStatus == 'ordered') {
          _showMarkAvailableDialog();
        }
      }
    } on FirebaseException catch (e) {
      _showErrorSnackbar('Update failed: ${e.message}');
    } catch (e) {
      _showErrorSnackbar('Update failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isToggling = false);
      }
    }
  }

  Future<void> _markTableAvailable() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final branchId = userProvider.currentBranch;

      if (branchId != null) {
        await FirestoreService.updateTableStatus(
          branchId,
          widget.tableNumber,
          'available',
        );
      }
      await FirestoreService.clearCart(widget.tableNumber);

      // Reset local state
      setState(() {
        _currentOrderId = null;
        _isAddingToExistingOrder = false;
        _existingOrderItems.clear();
        _currentOrderStatus = '';
        _currentPaymentStatus = 'unpaid';
      });

      _showSuccessSnackbar('Table ${widget.tableNumber} marked as available!');
    } on FirebaseException catch (e) {
      _showErrorSnackbar('Update failed: ${e.message}');
    } catch (e) {
      _showErrorSnackbar('Update failed: ${e.toString()}');
    }
  }

  // Helper methods for consistent messaging
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

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _tableStatusSubscription?.cancel();
    _existingOrderSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  // Updated to track order status and payment status
  void _listenToExistingOrder() {
    if (_currentOrderId == null) return;

    _existingOrderSubscription?.cancel();
    _existingOrderSubscription = _firestore
        .collection('Orders')
        .doc(_currentOrderId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && mounted) {
            final orderData = snapshot.data() as Map<String, dynamic>;
            final items = List<Map<String, dynamic>>.from(
              orderData['items'] ?? [],
            );
            final status = orderData['status']?.toString() ?? '';
            final paymentStatus =
                orderData['paymentStatus']?.toString() ?? 'unpaid';

            setState(() {
              _existingOrderItems = items;
              _currentOrderStatus = status;
              _currentPaymentStatus = paymentStatus;
            });
          }
        });
  }

  Future<void> _saveCartItems() async {
    try {
      await _firestore
          .collection('carts')
          .doc('table_${widget.tableNumber}')
          .set({
            'items': _cartItems,
            'lastUpdated': Timestamp.now(),
            'tableNumber': widget.tableNumber,
          });
    } catch (e) {
      print('Error saving cart items: $e');
    }
  }

  // Load categories from Firestore
  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final branchId = userProvider.currentBranch;

      if (branchId == null) {
        setState(() => _isLoadingCategories = false);
        return;
      }

      // Load categories
      final categoriesSnapshot = await _firestore
          .collection('menu_categories')
          .where('branchIds', arrayContains: branchId)
          .where('isActive', isEqualTo: true)
          .orderBy('sortOrder')
          .get();

      if (!mounted) return;

      setState(() {
        _categories = categoriesSnapshot.docs
            .map(
              (doc) => {
                'id': doc.id,
                'name': doc.data()['name'] ?? 'Unknown',
                'imageUrl': doc.data()['imageUrl'] ?? '',
                'sortOrder': doc.data()['sortOrder'] ?? 0,
              },
            )
            .toList();
        _isLoadingCategories = false;

        // Auto-expand first category if any exist
        if (_categories.isNotEmpty) {
          _expandedCategories.add(_categories[0]['name']);
        }
      });
    } catch (e) {
      print('Error loading categories: $e');
      if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
    }
  }

  void _startOrResetTimer() {
    _timer?.cancel();

    if (_tableStatus == 'occupied' || _tableStatus == 'ordered') {
      _occupiedTime ??= DateTime.now();

      _timer = Timer.periodic(Duration(seconds: 1), (_) {
        if (!mounted) return;
        final now = DateTime.now();
        setState(() {
          _elapsed = now.difference(_occupiedTime!);
        });
      });
    } else {
      _occupiedTime = null;
      _elapsed = Duration.zero;
      setState(() {});
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return "${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}";
    }
    return "${twoDigits(minutes)}:${twoDigits(seconds)}";
  }

  String _getStatusDisplayText(String status) {
    switch (status) {
      case 'available':
        return 'Available';
      case 'occupied':
        return 'Occupied';
      case 'ordered':
        return 'Order Pending';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.greenAccent;
      case 'occupied':
        return Colors.orangeAccent;
      case 'ordered':
        return Colors.redAccent;
      default:
        return Colors.white;
    }
  }

  void _showMarkAvailableDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Mark Table Available'),
            ],
          ),
          content: Text(
            'Are you sure you want to mark Table ${widget.tableNumber} as available?\n\n'
            'This will clear any pending orders and reset the table status.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _isToggling = false);
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _markTableAvailable();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('Mark Available'),
            ),
          ],
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() => _isToggling = false);
      }
    });
  }

  // Add navigation to OrderDetailScreen
  void _navigateToOrderDetail() {
    if (_currentOrderId == null) return;

    _firestore
        .collection('Orders')
        .where(FieldPath.documentId, isEqualTo: _currentOrderId)
        .limit(1)
        .get()
        .then((querySnapshot) {
          if (querySnapshot.docs.isNotEmpty) {
            final orderDoc =
                querySnapshot.docs.first; // This is QueryDocumentSnapshot
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailScreen(order: orderDoc),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Order not found'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        })
        .catchError((e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading order details: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return _buildTabletScaffold(context);
        }
        return _buildMobileScaffold(context);
      },
    );
  }

  Widget _buildTabletScaffold(BuildContext context) {
    bool hasActiveOrder =
        _tableStatus == 'occupied' || _tableStatus == 'ordered';

    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          'Table ${widget.tableNumber}',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          Row(
            children: [
              if (_isToggling)
                Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else
                IconButton(
                  icon: Icon(
                    _tableStatus == 'available'
                        ? Icons.check_circle
                        : Icons.pending,
                    color: _tableStatus == 'available'
                        ? Colors.green[300]
                        : Colors.orange[300],
                  ),
                  onPressed: _toggleTableAvailability,
                  tooltip: _tableStatus == 'available'
                      ? 'Mark Occupied'
                      : 'Mark Available',
                ),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.info_outline),
                onPressed: _showTableInfo,
              ),
              SizedBox(width: 16),
            ],
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Panel: Status, Cart, Orders (40%)
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  // Status Bar
                  if (hasActiveOrder || _isAddingToExistingOrder)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      color: primaryColor.withOpacity(0.1),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getStatusColor(_tableStatus),
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            _getStatusDisplayText(_tableStatus),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                              fontSize: 13,
                            ),
                          ),
                          if (_elapsed.inMinutes > 0) ...[
                            SizedBox(width: 12),
                            Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 4),
                            Text(
                              _formatDuration(_elapsed),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                          Spacer(),
                          if (_isAddingToExistingOrder &&
                              _currentOrderId != null)
                            TextButton.icon(
                              onPressed: _navigateToOrderDetail,
                              icon: Icon(Icons.receipt_long, size: 16),
                              label: Text('View Order'),
                              style: TextButton.styleFrom(
                                foregroundColor: primaryColor,
                              ),
                            ),
                        ],
                      ),
                    ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          if (_cartItems.isEmpty && _existingOrderItems.isEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: 40),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.shopping_cart_outlined,
                                    size: 48,
                                    color: Colors.grey[300],
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Cart is empty',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_existingOrderItems.isNotEmpty)
                            _buildExistingOrderSection(),
                          if (_cartItems.isNotEmpty) _buildCartSection(),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action Area
                  if (_cartItems.isNotEmpty ||
                      (_currentOrderStatus == 'served' &&
                          _currentPaymentStatus == 'unpaid'))
                    Container(
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
                        children: [
                          if (_cartItems.isNotEmpty)
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Total Amount',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        'QAR ${_totalAmount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 16),
                                ElevatedButton.icon(
                                  onPressed: _submitOrder,
                                  icon: Icon(Icons.check_circle_outline),
                                  label: Text(
                                    _isAddingToExistingOrder
                                        ? 'Add Items'
                                        : 'Submit Order',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (_currentOrderStatus == 'served' &&
                              _currentPaymentStatus == 'unpaid' &&
                              (_tableStatus == 'occupied' ||
                                  _tableStatus == 'ordered'))
                            Padding(
                              padding: EdgeInsets.only(
                                top: _cartItems.isNotEmpty ? 12 : 0,
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isCheckingOut
                                      ? null
                                      : _showPaymentOptions,
                                  icon: _isCheckingOut
                                      ? Container(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Icon(Icons.payment),
                                  label: Text('Pay Now - Order Served'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          VerticalDivider(width: 1, color: Colors.grey[300]),
          // Right Panel: Menu (60%)
          Expanded(
            flex: 6,
            child: Column(
              children: [
                _buildSearchBar(),
                Expanded(child: _buildMenuList(crossAxisCount: 3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileScaffold(BuildContext context) {
    bool hasActiveOrder =
        _tableStatus == 'occupied' || _tableStatus == 'ordered';

    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          'Table ${widget.tableNumber}',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          if (_isToggling)
            Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(
                _tableStatus == 'available'
                    ? Icons.check_circle
                    : Icons.pending,
                color: _tableStatus == 'available'
                    ? Colors.green[300]
                    : Colors.orange[300],
              ),
              onPressed: _toggleTableAvailability,
              tooltip: _tableStatus == 'available'
                  ? 'Mark Occupied'
                  : 'Mark Available',
            ),
          IconButton(icon: Icon(Icons.info_outline), onPressed: _showTableInfo),
        ],
      ),
      body: Column(
        children: [
          // Minimal Status Bar
          if (hasActiveOrder || _isAddingToExistingOrder)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: primaryColor.withOpacity(0.1),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getStatusColor(_tableStatus),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    _getStatusDisplayText(_tableStatus),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                      fontSize: 13,
                    ),
                  ),
                  if (_elapsed.inMinutes > 0) ...[
                    SizedBox(width: 12),
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 4),
                    Text(
                      _formatDuration(_elapsed),
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                  Spacer(),
                  if (_isAddingToExistingOrder && _currentOrderId != null)
                    GestureDetector(
                      onTap: _navigateToOrderDetail,
                      child: Row(
                        children: [
                          Text(
                            'View Order',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: primaryColor,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          // Compact Cart Section
          if (_cartItems.isNotEmpty) _buildCartSection(),

          // Existing Order Summary (compact)
          if (_isAddingToExistingOrder && _existingOrderItems.isNotEmpty)
            _buildExistingOrderSection(),

          // Search Bar
          _buildSearchBar(),

          // Menu List
          Expanded(child: _buildMenuList()),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  void _showTableInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.table_restaurant, color: primaryColor),
              SizedBox(width: 8),
              Text('Table ${widget.tableNumber} Info'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(
                'Status',
                _getStatusDisplayText(_tableStatus),
                _getStatusColor(_tableStatus),
              ),
              SizedBox(height: 8),
              _buildInfoRow(
                'Current Order',
                _existingOrderItems.isNotEmpty ? 'Yes' : 'No',
                null,
              ),
              SizedBox(height: 8),
              _buildInfoRow('Items in Cart', '${_cartItems.length}', null),
              if (_totalAmount > 0) ...[
                SizedBox(height: 8),
                _buildInfoRow(
                  'Cart Total',
                  'QAR ${_totalAmount.toStringAsFixed(2)}',
                  null,
                ),
              ],
              if (_tableStatus == 'occupied' || _tableStatus == 'ordered') ...[
                SizedBox(height: 8),
                _buildInfoRow('Occupied Time', _formatDuration(_elapsed), null),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, Color? valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('$label:', style: TextStyle(fontWeight: FontWeight.w500)),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.grey[700],
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search dishes...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search, color: primaryColor),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: TextStyle(fontSize: 16),
      ),
    );
  }

  // Updated with navigation functionality
  Widget _buildExistingOrderSection() {
    return InkWell(
      onTap: _navigateToOrderDetail,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue[50],
          border: Border(
            bottom: BorderSide(color: primaryColor.withOpacity(0.2)),
          ),
        ),
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, size: 16, color: primaryColor),
                SizedBox(width: 8),
                Text(
                  'Existing Order Items',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                Spacer(),
                Row(
                  children: [
                    if (_currentOrderStatus == 'served' &&
                        _currentPaymentStatus == 'unpaid')
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'UNPAID',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _existingOrderItems.map((item) {
                return Chip(
                  label: Text(
                    '${item['name']} (x${item['quantity']})',
                    style: TextStyle(fontSize: 11),
                  ),
                  backgroundColor: primaryColor.withOpacity(0.1),
                  labelStyle: TextStyle(color: primaryColor),
                  side: BorderSide(color: primaryColor.withOpacity(0.3)),
                );
              }).toList(),
            ),
            SizedBox(height: 4),
            Text(
              'Tap to view order details',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSection() {
    return Container(
      margin: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 18,
                  color: primaryColor,
                ),
                SizedBox(width: 8),
                Text(
                  'Cart (${_cartItems.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    fontSize: 14,
                  ),
                ),
                Spacer(),
                Text(
                  'QAR ${_totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Cart Items - Compact List
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _cartItems.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Colors.grey[200]),
            itemBuilder: (context, index) {
              final item = _cartItems[index];
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // Item name and price
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'],
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item['specialInstructions'] != null &&
                              item['specialInstructions'].toString().isNotEmpty)
                            Text(
                              item['specialInstructions'],
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange[700],
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    // Quantity controls
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => _updateQuantity(index, -1),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.remove,
                              size: 16,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                        Container(
                          width: 32,
                          alignment: Alignment.center,
                          child: Text(
                            '${item['quantity']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _updateQuantity(index, 1),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.add,
                              size: 16,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 12),
                    // Price
                    SizedBox(
                      width: 60,
                      child: Text(
                        'QAR ${(item['price'] * item['quantity']).toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Updated _buildMenuList with category-based collapsible UI
  Widget _buildMenuList({int crossAxisCount = 2}) {
    if (_isLoadingCategories) {
      return Center(child: CircularProgressIndicator());
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final branchId = userProvider.currentBranch;

    if (branchId == null) {
      return Center(child: Text('Please select a branch'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('menu_items')
          .where('isAvailable', isEqualTo: true)
          .where('branchIds', arrayContains: branchId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final menuItems = snapshot.data!.docs;

        // Filter items based on search query
        final filteredItems = menuItems.where((item) {
          if (_searchQuery.isEmpty) return true;
          final itemData = item.data() as Map<String, dynamic>;
          final name = itemData['name']?.toString().toLowerCase() ?? '';
          final description =
              itemData['description']?.toString().toLowerCase() ?? '';
          final category = itemData['category']?.toString().toLowerCase() ?? '';

          return name.contains(_searchQuery) ||
              description.contains(_searchQuery) ||
              category.contains(_searchQuery);
        }).toList();

        if (filteredItems.isEmpty && _searchQuery.isNotEmpty) {
          return _buildNoResultsWidget();
        }

        // Group items by category ID instead of name for better matching
        Map<String, List<QueryDocumentSnapshot>> categorizedItems = {};

        // First, create empty lists for all categories
        for (var category in _categories) {
          categorizedItems[category['id']] = [];
        }

        // Add "Other" category for items that don't match
        categorizedItems['other'] = [];

        // Then add items to their respective categories
        for (var item in filteredItems) {
          final itemData = item.data() as Map<String, dynamic>;
          final itemCategoryId = itemData['categoryId']
              ?.toString(); // Try categoryId first
          final itemCategoryName = itemData['category']
              ?.toString(); // Then try category name

          bool itemCategorized = false;

          // Try to match by category ID
          if (itemCategoryId != null &&
              categorizedItems.containsKey(itemCategoryId)) {
            categorizedItems[itemCategoryId]!.add(item);
            itemCategorized = true;
          }
          // Try to match by category name
          else if (itemCategoryName != null) {
            for (var category in _categories) {
              if (category['name'] == itemCategoryName) {
                categorizedItems[category['id']]!.add(item);
                itemCategorized = true;
                break;
              }
            }
          }

          // If still not categorized, put in "Other"
          if (!itemCategorized) {
            categorizedItems['other']!.add(item);
          }
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount:
              _categories.length +
              (categorizedItems['other']!.isNotEmpty ? 1 : 0) +
              1, // Add 1 for the header
          itemBuilder: (context, index) {
            // Header with Expand/Collapse All
            if (index == 0) {
              final isAllExpanded = _categories.every(
                (c) => _expandedCategories.contains(c['name']),
              );

              return Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Menu Categories',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (isAllExpanded) {
                            _expandedCategories.clear();
                          } else {
                            _expandedCategories.addAll(
                              _categories.map((c) => c['name'] as String),
                            );
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isAllExpanded ? 'Collapse All' : 'Expand All',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              isAllExpanded
                                  ? Icons.unfold_less
                                  : Icons.unfold_more,
                              size: 16,
                              color: primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            // Adjust index for categories
            final categoryIndex = index - 1;

            if (categoryIndex < _categories.length) {
              final category = _categories[categoryIndex];
              final categoryItems = categorizedItems[category['id']] ?? [];
              return _buildCategorySection(
                category,
                categoryItems,
                crossAxisCount: crossAxisCount,
              );
            } else {
              // "Other" category section
              final otherItems = categorizedItems['other']!;
              return _buildCategorySection(
                {
                  'id': 'other',
                  'name': 'Other Items',
                  'imageUrl': '',
                  'sortOrder': 999,
                },
                otherItems,
                crossAxisCount: crossAxisCount,
              );
            }
          },
        );
      },
    );
  }

  Widget _buildNoResultsWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
          SizedBox(height: 16),
          Text(
            'No dishes found',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'Try searching with different keywords',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    Map<String, dynamic> category,
    List<QueryDocumentSnapshot> items, {
    int crossAxisCount = 2,
  }) {
    final categoryName = category['name'];
    final isExpanded = _expandedCategories.contains(categoryName);
    final hasItems = items.isNotEmpty;

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // Compact Category Header
          InkWell(
            onTap: hasItems
                ? () {
                    setState(() {
                      if (isExpanded) {
                        _expandedCategories.remove(categoryName);
                      } else {
                        _expandedCategories.add(categoryName);
                      }
                    });
                  }
                : null,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Category icon
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.restaurant_menu,
                      color: primaryColor,
                      size: 18,
                    ),
                  ),
                  SizedBox(width: 12),
                  // Category Name
                  Expanded(
                    child: Text(
                      categoryName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  // Item count
                  if (hasItems)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${items.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  SizedBox(width: 8),
                  // Expand/Collapse Arrow
                  if (hasItems)
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey[600],
                      size: 24,
                    ),
                ],
              ),
            ),
          ),

          // Expandable Items Section - Simple List
          if (isExpanded && hasItems)
            _buildCategoryItems(items, crossAxisCount: crossAxisCount),
        ],
      ),
    );
  }

  Widget _buildCategoryItems(
    List<QueryDocumentSnapshot> items, {
    int crossAxisCount = 2,
  }) {
    return Padding(
      padding: EdgeInsets.all(12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 1.15, // Taller boxes to prevent overflow
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildMenuItemCard(items[index]),
      ),
    );
  }

  Widget _buildMenuItemCard(QueryDocumentSnapshot item) {
    final itemData = item.data() as Map<String, dynamic>;
    final name = itemData['name']?.toString() ?? 'Unknown Item';
    final price = (itemData['price'] as num?)?.toDouble() ?? 0.0;
    final isPopular = itemData['isPopular'] ?? false;
    final hasVariants =
        itemData['variants'] != null &&
        itemData['variants'] is Map &&
        (itemData['variants'] as Map).isNotEmpty;

    return InkWell(
      onTap: () => hasVariants
          ? _showCustomizationOptions(item)
          : _addToCart(item, null),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.all(10), // Reduced padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Name and Popular Badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isPopular)
                  Container(
                    margin: EdgeInsets.only(bottom: 6),
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'POPULAR',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),

            // Price and Add Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'QAR ${price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    hasVariants ? Icons.arrow_forward : Icons.add,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomizationOptions(QueryDocumentSnapshot item) {
    final itemData = item.data() as Map<String, dynamic>;
    final name = itemData['name']?.toString() ?? 'Unknown Item';
    final basePrice = (itemData['price'] as num?)?.toDouble() ?? 0.0;

    // FIX: Handle both Map and List formats for variants
    List<Map<String, dynamic>> variants = [];

    final variantsData = itemData['variants'];
    if (variantsData != null) {
      if (variantsData is List) {
        // If variants is already a List
        variants = List<Map<String, dynamic>>.from(variantsData);
      } else if (variantsData is Map) {
        // If variants is a Map, convert it to a List
        variants = (variantsData as Map<String, dynamic>).entries.map((entry) {
          final Map<String, dynamic> variantMap = {'name': entry.key};

          // Add the variant properties if entry.value is a Map
          if (entry.value is Map) {
            final valueMap = Map<String, dynamic>.from(entry.value as Map);
            variantMap.addAll(valueMap);
          } else {
            // If it's not a Map, just store the value directly
            variantMap['value'] = entry.value;
          }

          return variantMap;
        }).toList();
      }
    }

    String? selectedVariant;
    String specialInstructions = '';
    int quantity = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // Calculate total price including selected variant
            double variantPrice = 0.0;
            if (selectedVariant != null) {
              final variant = variants.firstWhere(
                (v) => v['name'] == selectedVariant,
                orElse: () => <String, dynamic>{},
              );
              variantPrice =
                  (variant['variantprice'] as num?)?.toDouble() ?? 0.0;
            }
            final totalPrice = basePrice + variantPrice;

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'QAR ${totalPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Variants Section
                  Text(
                    'Variants',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 8),

                  if (variants.isEmpty)
                    Text(
                      'No variants available',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    Column(
                      children: variants.map((variant) {
                        final variantName =
                            variant['name']?.toString() ?? 'Unknown Variant';
                        final variantPrice =
                            (variant['variantprice'] as num?)?.toDouble() ??
                            0.0;
                        final isAvailable =
                            variant['isAvailable'] ??
                            true; // Default to true if not specified
                        final isSelected = selectedVariant == variantName;

                        return Container(
                          margin: EdgeInsets.only(bottom: 8),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected
                                  ? primaryColor
                                  : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: isSelected
                                ? primaryColor.withOpacity(0.1)
                                : Colors.transparent,
                          ),
                          child: Row(
                            children: [
                              Radio<String>(
                                value: variantName,
                                groupValue: selectedVariant,
                                onChanged: isAvailable
                                    ? (value) {
                                        setModalState(() {
                                          selectedVariant = value;
                                        });
                                      }
                                    : null,
                                activeColor: primaryColor,
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      variantName,
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: isAvailable
                                            ? Colors.grey[800]
                                            : Colors.grey[400],
                                      ),
                                    ),
                                    if (variantPrice > 0)
                                      Text(
                                        '+QAR ${variantPrice.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: primaryColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (!isAvailable)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Out of Stock',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                  SizedBox(height: 16),

                  // Quantity Selector
                  Text(
                    'Quantity',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: () {
                          if (quantity > 1) {
                            setModalState(() {
                              quantity--;
                            });
                          }
                        },
                      ),
                      Container(
                        width: 50,
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          quantity.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () {
                          setModalState(() {
                            quantity++;
                          });
                        },
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // Special Instructions
                  Text(
                    'Special Instructions (Optional)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'E.g. No onions, extra spicy, etc.',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      specialInstructions = value;
                    },
                  ),

                  SizedBox(height: 20),

                  // Add to Cart Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _addToCart(
                          item,
                          specialInstructions,
                          selectedVariant: selectedVariant,
                          quantity: quantity,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Add to Cart - QAR ${(totalPrice * quantity).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget? _buildBottomNavigationBar() {
    // Enhanced condition: order served + unpaid + seat occupied + order exists
    bool showPaymentButton =
        _currentOrderStatus == 'served' &&
        _currentPaymentStatus == 'unpaid' &&
        (_tableStatus == 'occupied' || _tableStatus == 'ordered') &&
        _currentOrderId != null;

    if (_cartItems.isEmpty && _tableStatus != 'ordered' && !showPaymentButton)
      return null;

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
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_cartItems.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isAddingToExistingOrder
                            ? 'Additional Total'
                            : 'Total Amount',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      Text(
                        'QAR ${_totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      Text(
                        '${_cartItems.length} item${_cartItems.length != 1 ? 's' : ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _submitOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, size: 20),
                      SizedBox(width: 8),
                      Text(
                        _isAddingToExistingOrder ? 'Add Items' : 'Submit Order',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

          // UPDATED: Payment button with all required conditions
          if (showPaymentButton)
            Padding(
              padding: EdgeInsets.only(top: _cartItems.isNotEmpty ? 12 : 0),
              child: ElevatedButton(
                onPressed: _isCheckingOut ? null : _showPaymentOptions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: Size(double.infinity, 48),
                ),
                child: _isCheckingOut
                    ? CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payment, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Pay Now - Order Served',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

          // Original checkout button for other statuses
          if ((_tableStatus == 'ordered' || _tableStatus == 'occupied') &&
              !showPaymentButton)
            Padding(
              padding: EdgeInsets.only(top: _cartItems.isNotEmpty ? 12 : 0),
              child: ElevatedButton(
                onPressed: _isCheckingOut ? null : _showPaymentOptions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: Size(double.infinity, 48),
                ),
                child: _isCheckingOut
                    ? CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payment, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Checkout & Pay',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }

  void _addToCart(
    QueryDocumentSnapshot item,
    String? specialInstructions, {
    int quantity = 1,
    String? selectedVariant,
  }) {
    setState(() {
      final itemData = item.data() as Map<String, dynamic>;
      final basePrice = (itemData['price'] as num?)?.toDouble() ?? 0.0;

      // Calculate variant price if selected
      double variantPrice = 0.0;
      if (selectedVariant != null) {
        final variants = itemData['variants'];
        if (variants != null) {
          if (variants is List) {
            final variantList = List<Map<String, dynamic>>.from(variants);
            final variant = variantList.firstWhere(
              (v) => v['name'] == selectedVariant,
              orElse: () => <String, dynamic>{},
            );
            variantPrice = (variant['variantprice'] as num?)?.toDouble() ?? 0.0;
          } else if (variants is Map) {
            final variantsMap = variants as Map<String, dynamic>;
            if (variantsMap.containsKey(selectedVariant)) {
              final variantData = variantsMap[selectedVariant];
              if (variantData is Map) {
                variantPrice =
                    (variantData['variantprice'] as num?)?.toDouble() ?? 0.0;
              }
            }
          }
        }
      }

      final totalPrice = basePrice + variantPrice;

      // Improved comparison logic for existing items
      final existingIndex = _cartItems.indexWhere((cartItem) {
        // Compare item ID
        if (cartItem['id'] != item.id) return false;

        // Compare selected variant
        final cartVariant = cartItem['selectedVariant'];
        if (cartVariant != selectedVariant) return false;

        // Compare special instructions (handle null cases)
        final cartInstructions = cartItem['specialInstructions'];
        if (cartInstructions == null && specialInstructions == null)
          return true;
        if (cartInstructions == null || specialInstructions == null)
          return false;
        return cartInstructions == specialInstructions;
      });

      if (existingIndex >= 0) {
        // Update existing item quantity
        int currentQuantity = (_cartItems[existingIndex]['quantity'] as num)
            .toInt();
        _cartItems[existingIndex]['quantity'] = currentQuantity + quantity;
      } else {
        // Add new item to cart
        _cartItems.add({
          'id': item.id,
          'name': itemData['name']?.toString() ?? 'Unknown Item',
          'basePrice': basePrice,
          'variantPrice': variantPrice,
          'price': totalPrice,
          'quantity': quantity,
          'selectedVariant': selectedVariant,
          'specialInstructions': specialInstructions,
          'variantName': selectedVariant,
        });
      }
      _calculateTotal();
      _saveCartItems();
    });
  }

  void _updateQuantity(int index, int change) {
    setState(() {
      _cartItems[index]['quantity'] += change;
      if (_cartItems[index]['quantity'] <= 0) {
        _cartItems.removeAt(index);
      }
      _calculateTotal();
      _saveCartItems(); // Save to Firestore
    });
  }

  void _calculateTotal() {
    _totalAmount = _cartItems.fold(0.0, (sum, item) {
      final double price = (item['price'] as num).toDouble();
      final int quantity = (item['quantity'] as num).toInt();
      return sum + (price * quantity.toDouble());
    });
  }

  // In _OrderScreenState class - Update the _showPaymentOptions method
  void _showPaymentOptions() {
    // Check if order hasn't gone through proper workflow
    final bool hasSkippedSteps =
        _currentOrderStatus.isEmpty ||
        (_currentOrderStatus != 'served' && _currentOrderStatus != 'paid');

    if (hasSkippedSteps) {
      _showPaymentWarningDialog();
    } else {
      _showPaymentMethodSelection();
    }
  }

  void _showPaymentWarningDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 12),
            Text(
              'Order Not Ready',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This order hasn\'t been prepared or served yet.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Current Status: ${_currentOrderStatus.isNotEmpty ? _currentOrderStatus.toUpperCase() : 'NOT PROCESSED'}',
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Are you sure you want to proceed with payment?',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showPaymentMethodSelection();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text('Proceed Anyway'),
          ),
        ],
      ),
    );
  }

  void _showPaymentMethodSelection() {
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
