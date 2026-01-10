import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../Providers/UserProvider.dart';

class TakeawayOrderScreen extends StatefulWidget {
  @override
  _TakeawayOrderScreenState createState() => _TakeawayOrderScreenState();
}

class _TakeawayOrderScreenState extends State<TakeawayOrderScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryColor = Color(0xFF1976D2);
  final Color secondaryColor = Color(0xFFE3F2FD);
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _carPlateNumberController =
      TextEditingController();
  final TextEditingController _specialInstructionsController =
      TextEditingController();

  List<Map<String, dynamic>> _cartItems = [];
  double _totalAmount = 0.0;
  bool _isSubmitting = false;
  String _searchQuery = '';

  // Category-related variables
  List<Map<String, dynamic>> _categories = [];
  Set<String> _expandedCategories = <String>{};
  bool _isLoadingCategories = false;
  bool _isLoadingCart = false;

  // Add this to prevent duplicate submissions
  bool _isOrderInProgress = false;

  // Debounce timer for search input
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _loadCategories();

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

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _carPlateNumberController.dispose();
    _specialInstructionsController.dispose();
    super.dispose();
  }

  // Load categories from Firestore
  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final branchId = userProvider.currentBranch;
      if (branchId == null) return;

      final categoriesSnapshot = await _firestore
          .collection('menu_categories')
          .where('branchIds', arrayContains: branchId)
          .where('isActive', isEqualTo: true)
          .orderBy('sortOrder')
          .get();

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
      setState(() => _isLoadingCategories = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          'Takeaway Order',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: _showTakeawayInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // Minimal Status Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: primaryColor.withOpacity(0.1),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text(
                  'Ready in 15-20 mins',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                    fontSize: 13,
                  ),
                ),
                SizedBox(width: 16),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 16),
                Icon(Icons.store_outlined, size: 16, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  Provider.of<UserProvider>(context).currentBranch ?? 'Unknown',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Compact Cart Section
          if (_cartItems.isNotEmpty) _buildCartSection(),

          // Search Bar
          _buildSearchBar(),

          // Menu List
          Expanded(child: _buildMenuList()),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  void _showTakeawayInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.takeout_dining, color: primaryColor),
              SizedBox(width: 8),
              Text('Takeaway Information'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Order Type', 'Takeaway', null),
              SizedBox(height: 8),
              _buildInfoRow('Preparation Time', '15-20 minutes', null),
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
                    // Item name
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

  Widget _buildMenuList() {
    if (_isLoadingCategories) {
      return Center(child: CircularProgressIndicator());
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final branchId = userProvider.currentBranch;

    if (branchId == null) return Center(child: Text("No Branch Selected"));

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

        // Group items by category ID
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
          final itemCategoryId = itemData['categoryId']?.toString();
          final itemCategoryName = itemData['category']?.toString();

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
              return _buildCategorySection(category, categoryItems);
            } else {
              // "Other" category section
              final otherItems = categorizedItems['other']!;
              return _buildCategorySection({
                'id': 'other',
                'name': 'Other Items',
                'imageUrl': '',
                'sortOrder': 999,
              }, otherItems);
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
    List<QueryDocumentSnapshot> items,
  ) {
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
          if (isExpanded && hasItems) _buildCategoryItems(items),
        ],
      ),
    );
  }

  Widget _buildCategoryItems(List<QueryDocumentSnapshot> items) {
    return Padding(
      padding: EdgeInsets.all(12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
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
    final imageUrl = itemData['imageUrl']?.toString();
    final description = itemData['description']?.toString();

    // Handle variants data properly
    List<Map<String, dynamic>> variants = [];
    final variantsData = itemData['variants'];
    if (variantsData != null) {
      if (variantsData is List) {
        variants = List<Map<String, dynamic>>.from(variantsData);
      } else if (variantsData is Map) {
        variants = (variantsData as Map<String, dynamic>).entries.map((entry) {
          final Map<String, dynamic> variantMap = {'name': entry.key};

          if (entry.value is Map) {
            final valueMap = Map<String, dynamic>.from(entry.value as Map);
            variantMap.addAll(valueMap);
          } else {
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
      isScrollControlled: true, // Keep this true for keyboard handling
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(
              context,
            ).viewInsets.bottom, // This handles keyboard overlap
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.of(context).size.height *
                  0.85, // Increased to 85% for better visibility
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 20,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: StatefulBuilder(
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
                final finalTotal = totalPrice * quantity;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with Drag Handle
                    Container(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Drag Handle
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          SizedBox(height: 12),
                          // Item Header
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Item Image
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: primaryColor.withOpacity(0.1),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: imageUrl != null && imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Icon(
                                                    Icons.restaurant_menu,
                                                    color: primaryColor,
                                                    size: 24,
                                                  ),
                                        )
                                      : Icon(
                                          Icons.restaurant_menu,
                                          color: primaryColor,
                                          size: 24,
                                        ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[800],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (description != null &&
                                        description.isNotEmpty)
                                      Padding(
                                        padding: EdgeInsets.only(top: 4),
                                        child: Text(
                                          description,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Divider(height: 1, color: Colors.grey[200]),

                    // Content Area with Limited Height
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Variants Section
                            if (variants.isNotEmpty) ...[
                              Row(
                                children: [
                                  Icon(
                                    Icons.tune_rounded,
                                    size: 20,
                                    color: primaryColor,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Customize Your Order',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),

                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Column(
                                  children: variants.map((variant) {
                                    final variantName =
                                        variant['name']?.toString() ??
                                        'Unknown Variant';
                                    final variantPrice =
                                        (variant['variantprice'] as num?)
                                            ?.toDouble() ??
                                        0.0;
                                    final isAvailable =
                                        variant['isAvailable'] ?? true;
                                    final isSelected =
                                        selectedVariant == variantName;

                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: isAvailable
                                            ? () {
                                                setModalState(() {
                                                  selectedVariant = isSelected
                                                      ? null
                                                      : variantName;
                                                });
                                              }
                                            : null,
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: variants.last != variant
                                                  ? BorderSide(
                                                      color: Colors.grey[200]!,
                                                    )
                                                  : BorderSide.none,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              // Custom Radio Button
                                              Container(
                                                width: 20,
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? primaryColor
                                                        : Colors.grey[400]!,
                                                    width: 2,
                                                  ),
                                                  color: isSelected
                                                      ? primaryColor
                                                      : Colors.transparent,
                                                ),
                                                child: isSelected
                                                    ? Icon(
                                                        Icons.check,
                                                        size: 12,
                                                        color: Colors.white,
                                                      )
                                                    : null,
                                              ),
                                              SizedBox(width: 12),

                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            variantName,
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: isAvailable
                                                                  ? (isSelected
                                                                        ? primaryColor
                                                                        : Colors
                                                                              .grey[800])
                                                                  : Colors
                                                                        .grey[400],
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ),
                                                        if (variantPrice > 0)
                                                          Text(
                                                            '+QAR ${variantPrice.toStringAsFixed(2)}',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color:
                                                                  primaryColor,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    if (!isAvailable)
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              top: 4,
                                                            ),
                                                        child: Text(
                                                          'Temporarily unavailable',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors
                                                                .orange[700],
                                                            fontStyle: FontStyle
                                                                .italic,
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
                                    );
                                  }).toList(),
                                ),
                              ),
                              SizedBox(height: 24),
                            ],

                            // Quantity Selector
                            Row(
                              children: [
                                Icon(
                                  Icons.format_list_numbered_rounded,
                                  size: 20,
                                  color: primaryColor,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Quantity',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                Spacer(),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.remove, size: 18),
                                        onPressed: () {
                                          if (quantity > 1) {
                                            setModalState(() {
                                              quantity--;
                                            });
                                          }
                                        },
                                        style: IconButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.all(8),
                                        ),
                                      ),
                                      Container(
                                        width: 40,
                                        alignment: Alignment.center,
                                        child: Text(
                                          quantity.toString(),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.add, size: 18),
                                        onPressed: () {
                                          setModalState(() {
                                            quantity++;
                                          });
                                        },
                                        style: IconButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.all(8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 24),

                            // Special Instructions
                            Row(
                              children: [
                                Icon(
                                  Icons.edit_note_rounded,
                                  size: 20,
                                  color: primaryColor,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Special Instructions',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Add any special requests or dietary requirements',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: TextField(
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText:
                                      'E.g. No onions, extra spicy, less salt, allergies...',
                                  hintStyle: TextStyle(color: Colors.grey[500]),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(16),
                                ),
                                onChanged: (value) {
                                  specialInstructions = value;
                                },
                              ),
                            ),

                            // Add some bottom padding for better scrolling
                            SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),

                    // Footer with Total and Add Button
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Colors.grey[200]!),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Total Price
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Amount',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                'QAR ${finalTotal.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),

                          // Add to Cart Button
                          SizedBox(
                            width: double.infinity,
                            height: 54,
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
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.shopping_cart_checkout_rounded,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Add to Cart',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Spacer(),
                                  Text(
                                    'QAR ${finalTotal.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget? _buildBottomNavigationBar() {
    if (_cartItems.isEmpty) return null;

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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Amount',
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
              // REMOVE StatefulBuilder and use the main widget's state directly
              ElevatedButton(
                onPressed: (_isSubmitting || _isOrderInProgress)
                    ? null
                    : _showCustomerDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: (_isSubmitting || _isOrderInProgress)
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Place Order',
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
      final nameAr =
          itemData['name_ar']?.toString() ?? itemData['name']?.toString() ?? '';

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
          'name_ar': nameAr,
          'selectedVariant': selectedVariant,
          'specialInstructions': specialInstructions,
          'variantName': selectedVariant,
        });
      }
      _calculateTotal();
    });
  }

  void _updateQuantity(int index, int change) {
    setState(() {
      _cartItems[index]['quantity'] += change;
      if (_cartItems[index]['quantity'] <= 0) {
        _cartItems.removeAt(index);
      }
      _calculateTotal();
    });
  }

  void _calculateTotal() {
    _totalAmount = _cartItems.fold(0.0, (sum, item) {
      final double price = (item['price'] as num).toDouble();
      final int quantity = (item['quantity'] as num).toInt();
      return sum + (price * quantity.toDouble());
    });
  }

  void _showCustomerDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Customer Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                SizedBox(height: 20),
                TextField(
                  controller: _carPlateNumberController,
                  decoration: InputDecoration(
                    labelText: 'Car Plate Number *',
                    hintText: 'e.g. XYZ 789',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.directions_car),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _specialInstructionsController,
                  decoration: InputDecoration(
                    labelText: 'Special Instructions (Optional)',
                    hintText: 'e.g. Honk twice when outside',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 3,
                ),
                SizedBox(height: 20),

                // PASTE THE SIZEDBOX CODE RIGHT HERE - REPLACING THE EXISTING BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_isSubmitting || _isOrderInProgress)
                        ? null
                        : _validateAndSubmitOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: (_isSubmitting || _isOrderInProgress)
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Place Takeaway Order - QAR ${_totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _validateAndSubmitOrder() async {
    if (_carPlateNumberController.text.trim().isEmpty) {
      _showErrorMessage('Please enter car plate number');
      return;
    }

    if (_cartItems.isEmpty) {
      _showErrorMessage('Cart is empty');
      return;
    }

    // Prevent duplicate submissions
    if (_isOrderInProgress) {
      _showErrorMessage('Order is already being processed');
      return;
    }

    await _submitOrder();
  }

  Future<void> _submitOrder() async {
    // Set both flags to prevent duplicate submissions and trigger UI update
    setState(() {
      _isSubmitting = true;
      _isOrderInProgress = true;
    });

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // Get daily order number first
      final ordersToday = await _firestore
          .collection('Orders')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(startOfDay))
          .get();

      final dailyOrderNumber = ordersToday.size + 1;

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final branchId = userProvider.currentBranch;

      if (branchId == null) {
        throw Exception(
          'No branch selected. Please restart the app or contact support.',
        );
      }

      // Use transaction for order creation
      await _firestore.runTransaction((transaction) async {
        final orderRef = _firestore.collection('Orders').doc();

        final orderData = {
          'Order_type': 'takeaway',
          'carPlateNumber': _carPlateNumberController.text.trim(),
          'specialInstructions': _specialInstructionsController.text.trim(),
          'items': _cartItems,
          'subtotal': _totalAmount,
          'totalAmount': _totalAmount,
          'status': 'pending',
          'paymentStatus': 'unpaid',
          'timestamp': FieldValue.serverTimestamp(),
          'dailyOrderNumber': dailyOrderNumber,
          'branchIds': [branchId],
          'estimatedReadyTime': _calculateEstimatedTime(),
        };

        // Properly check for empty strings using .toString() and .isEmpty
        final carPlateNumber = orderData['carPlateNumber'].toString();

        if (carPlateNumber.isEmpty) {
          throw Exception('Car plate number is required');
        }

        if (_cartItems.isEmpty) {
          throw Exception('Cart cannot be empty');
        }

        transaction.set(orderRef, orderData);
      });

      // Show success dialog and clear form
      _showSuccessDialog();
      _clearFormData();
    } on FirebaseException catch (e) {
      _showErrorMessage('Order failed: ${e.message}');
    } catch (e) {
      _showErrorMessage('Failed to place order: ${e.toString()}');
    } finally {
      // Always reset loading states and trigger UI update
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isOrderInProgress = false;
        });
      }
    }
  }

  String _calculateEstimatedTime() {
    final now = DateTime.now();
    final estimatedTime = now.add(Duration(minutes: 15));
    return _formatTime(estimatedTime);
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, color: Colors.green, size: 48),
            ),
            SizedBox(height: 16),
            Text(
              'Order Placed Successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Your takeaway order has been confirmed and will be ready for pickup in approximately 15-20 minutes.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close customer details sheet
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _clearFormData() {
    setState(() {
      _cartItems.clear();
      _totalAmount = 0.0;
      _carPlateNumberController.clear();
      _specialInstructionsController.clear();
    });
  }
}
