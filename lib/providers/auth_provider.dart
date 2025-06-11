import 'package:flutter/widgets.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../helper/db_helper.dart';
import '../models/user_model.dart';

class AppAuth extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? errorMessage;
  String? successMessage;
  int? _currentUserId;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final DbHelper _dbHelper = DbHelper();
  AppAuth();

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  int? get currentUserId => _currentUserId;

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  void login() {
    _isAuthenticated = true;
    notifyListeners();
  }

  void logout() {
    _isAuthenticated = false;
    _currentUserId = null;
    errorMessage = null;
    successMessage = null;
    emailController.clear();
    passwordController.clear();
    notifyListeners();
  }

  Future<void> registerWithEmail() async {
    final emailUser = emailController.text.trim();
    final passwordUser = passwordController.text.trim();

    _isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      if (emailUser.isEmpty || passwordUser.isEmpty) {
        errorMessage = 'Email dan Password tidak boleh kosong!';
        return;
      }

      if (!_isValidEmail(emailUser)) {
        errorMessage = 'Format email tidak valid!';
        return;
      }

      if (passwordUser.length < 6) {
        errorMessage = 'Password harus minimal 6 karakter!';
        return;
      }
      final existingUser = await _dbHelper.getUserByEmail(emailUser);
      if (existingUser != null) {
        errorMessage = 'Email sudah terdaftar!';
        return;
      }

      final hashedPassword = _hashPassword(passwordUser);
      final user = UserModel(
        email: emailUser,
        password: hashedPassword,
        createdAt: DateTime.now().toIso8601String(),
      );
      await _dbHelper.insertUser(user);

      successMessage = 'Registrasi berhasil! Silakan login.';
      emailController.clear();
      passwordController.clear();
    } catch (e) {
      errorMessage = 'Terjadi kesalahan: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loginWithEmail() async {
    final emailUser = emailController.text.trim();
    final passwordUser = passwordController.text.trim();

    _isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      if (emailUser.isEmpty || passwordUser.isEmpty) {
        errorMessage = 'Email dan Password tidak boleh kosong!';
        return;
      }
      final user = await _dbHelper.getUserByEmail(emailUser);
      if (user == null) {
        errorMessage = 'User tidak ditemukan!';
        return;
      }

      final hashedPassword = _hashPassword(passwordUser);
      if (user['password'] != hashedPassword) {
        errorMessage = 'Password salah!';
        return;
      }

      _isAuthenticated = true;
      _currentUserId = user['id'];
      successMessage = 'Login berhasil!';
      emailController.clear();
      passwordController.clear();
    } catch (e) {
      errorMessage = 'Terjadi kesalahan: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    if (_currentUserId == null) return null;
    return await _dbHelper.getUserById(_currentUserId!);
  }

  Future<Map<String, dynamic>> getUserStats() async {
    if (_currentUserId == null) return {};
    return await _dbHelper.getUserStats(_currentUserId!);
  }
}
