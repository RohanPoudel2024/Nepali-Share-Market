import 'package:flutter/material.dart';
import 'package:nepse_market_app/models/user.dart';
import 'package:nepse_market_app/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get errorMessage => _errorMessage;
  
  AuthProvider() {
    _checkLoginStatus();
  }
  
  Future<void> _checkLoginStatus() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // First check if there's a valid token
      final hasToken = await _authService.isLoggedIn();
      
      if (hasToken) {
        // Then verify the session is still valid on the server
        final sessionResult = await _authService.checkSession();
        
        if (sessionResult['success']) {
          _user = sessionResult['user'];
        } else {
          // Session invalid, clear token
          await _authService.logout();
        }
      }
    } catch (e) {
      print('Error checking login status: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    final result = await _authService.register(name, email, password);
    
    _isLoading = false;
    
    if (result['success']) {
      _user = result['user'];
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['message'];
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    final result = await _authService.login(email, password);
    
    _isLoading = false;
    
    if (result['success']) {
      _user = result['user'];
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['message'];
      notifyListeners();
      return false;
    }
  }
  
  Future<void> getCurrentUser() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    final result = await _authService.getCurrentUser();
    
    _isLoading = false;
    
    if (result['success']) {
      _user = result['user'];
    } else {
      _errorMessage = result['message'];
    }
    
    notifyListeners();
  }
  
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    
    await _authService.logout();
    
    _user = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateProfile(String name) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    final result = await _authService.updateProfile(name);
    
    _isLoading = false;
    
    if (result['success']) {
      _user = result['user'];
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['message'];
      notifyListeners();
      return false;
    }
  }
}