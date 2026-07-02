import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'models.dart';
import 'session.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// Thin wrapper around the endpoints documented in API.md.
class ApiClient {
  static Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${ApiConfig.baseUrl}$path')
        .replace(queryParameters: query);
  }

  static const _jsonHeaders = {'Content-Type': 'application/json'};

  static Map<String, String> get _authHeaders => {
        ..._jsonHeaders,
        if (Session.instance.token != null) 'token': Session.instance.token!,
      };

  // Error bodies from this API show up as {"error": ...}, {"Error": ...},
  // a bare JSON string, or plain text depending on the endpoint - this
  // normalizes all of them into one message.
  static String _extractMessage(http.Response res) {
    final body = res.body.trim();
    if (body.isEmpty) return 'Request failed (HTTP ${res.statusCode})';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return (decoded['error'] ?? decoded['Error'] ?? decoded).toString();
      }
      return decoded.toString();
    } catch (_) {
      return body;
    }
  }

  static Future<void> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String phone,
  }) async {
    final res = await http.post(
      _uri('/users/signup'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'password': password,
        'phone': phone,
      }),
    );
    if (res.statusCode != 201) throw ApiException(_extractMessage(res));
  }

  // Login "succeeds" with HTTP 302 (c.JSON(http.StatusFound, ...) in
  // controllers.go) rather than a real redirect - the body is the user's
  // JSON document either way, so no Location header is ever set.
  static Future<void> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      _uri('/users/login'),
      headers: _jsonHeaders,
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode != 302 && res.statusCode != 200) {
      throw ApiException(_extractMessage(res));
    }
    final user = jsonDecode(res.body) as Map<String, dynamic>;
    final token = user['token'] as String?;
    final userId = user['user_id'] as String?;
    if (token == null || userId == null) {
      throw ApiException('Login response was missing token/user_id');
    }
    Session.instance.token = token;
    Session.instance.userId = userId;
    Session.instance.firstName = user['first_name'] as String?;
  }

  static Future<List<Product>> fetchProducts() async {
    final res = await http.get(_uri('/users/productview'));
    if (res.statusCode != 200) throw ApiException(_extractMessage(res));
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Product>> searchProducts(String name) async {
    final res = await http.get(_uri('/users/search', {'name': name}));
    if (res.statusCode != 200) throw ApiException(_extractMessage(res));
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Public and unauthenticated despite the /admin path (see API.md "Known
  // issues") - used here to seed products since there's no other way to.
  static Future<void> addProductAdmin({
    required String name,
    required int price,
    required int rating,
    required String image,
  }) async {
    final res = await http.post(
      _uri('/admin/addproduct'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'product_name': name,
        'price': price,
        'rating': rating,
        'image': image,
      }),
    );
    if (res.statusCode != 200) throw ApiException(_extractMessage(res));
  }

  /// GET /products/:id/image 302-redirects to the real image URL - Flutter's
  /// network image loader follows that automatically, so this is safe to
  /// hand straight to Image.network.
  static String productImageUrl(String productId) =>
      '${ApiConfig.baseUrl}/products/$productId/image';

  static Future<void> addToCart(String productId) async {
    final res = await http.get(
      _uri('/addtocart', {
        'id': productId,
        'userID': Session.instance.userId ?? '',
      }),
      headers: _authHeaders,
    );
    if (res.statusCode != 200) throw ApiException(_extractMessage(res));
  }

  static Future<void> removeFromCart(String productId) async {
    final res = await http.get(
      _uri('/removeitem', {
        'id': productId,
        'userID': Session.instance.userId ?? '',
      }),
      headers: _authHeaders,
    );
    if (res.statusCode != 200) throw ApiException(_extractMessage(res));
  }

  // /listcart writes two separate JSON values back-to-back in one response
  // body (total, then the items array - see API.md "Known issues"), so it
  // can't be parsed with a single jsonDecode.
  static Future<CartSummary> listCart() async {
    final res = await http.get(
      _uri('/listcart', {'id': Session.instance.userId ?? ''}),
      headers: _authHeaders,
    );
    if (res.statusCode != 200) throw ApiException(_extractMessage(res));
    final body = res.body.trim();
    final splitIndex = body.indexOf('[');
    if (body.isEmpty || splitIndex == -1) {
      return CartSummary(total: 0, items: []);
    }
    final total = num.tryParse(body.substring(0, splitIndex).trim())?.toInt();
    final items = (jsonDecode(body.substring(splitIndex)) as List)
        .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return CartSummary(total: total ?? 0, items: items);
  }

  static Future<void> checkout() async {
    final res = await http.get(
      _uri('/cartcheckout', {'id': Session.instance.userId ?? ''}),
      headers: _authHeaders,
    );
    if (res.statusCode != 200) throw ApiException(_extractMessage(res));
  }

  static Future<void> instantBuy(String productId) async {
    final res = await http.get(
      _uri('/instantbuy', {
        'userid': Session.instance.userId ?? '',
        'pid': productId,
      }),
      headers: _authHeaders,
    );
    if (res.statusCode != 200) throw ApiException(_extractMessage(res));
  }
}
