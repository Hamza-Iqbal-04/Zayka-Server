import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProvider with ChangeNotifier {
  Map<String, dynamic>? _userProfile;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Getter for branchId with safe fallback or null
  // Returns the first branch ID if available, otherwise null
  String? get currentBranch {
    if (_userProfile != null &&
        _userProfile!.containsKey('branchIds') &&
        _userProfile!['branchIds'] is List &&
        (_userProfile!['branchIds'] as List).isNotEmpty) {
      return (_userProfile!['branchIds'] as List).first.toString();
    }
    return null;
  }

  String? get userName => _userProfile?['name'];
  String? get userEmail => _userProfile?['email'];
  String? get userRole => _userProfile?['role'];

  Future<void> fetchUserProfile(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Directly query by email.
      QuerySnapshot query = await FirebaseFirestore.instance
          .collection('staff')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        _userProfile = query.docs.first.data() as Map<String, dynamic>;

        // Optional: Log if multiple branches found just for debugging? No, keep it simple.
      } else {
        _error = 'User profile not found. Please contact admin.';
        _userProfile = null;
      }
    } catch (e) {
      _error = 'Failed to fetch profile: $e';
      _userProfile = null;
      print('UserProvider Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearProfile() {
    _userProfile = null;
    _error = null;
    notifyListeners();
  }
}
