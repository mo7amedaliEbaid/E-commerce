/// Matches models.Product from models/models.go. Product_ID has no json
/// tag on the Go side, so it serializes as "Product_ID", not "product_id".
class Product {
  final String id;
  final String name;
  final int price;
  final int rating;
  final String? image;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.rating,
    this.image,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: (json['Product_ID'] ?? json['_id'] ?? '').toString(),
      name: (json['product_name'] ?? '').toString(),
      price: ((json['price'] ?? 0) as num).toInt(),
      rating: ((json['rating'] ?? 0) as num).toInt(),
      image: json['image'] as String?,
    );
  }
}

/// Matches models.ProductUser, the shape items take once they're inside a
/// user's cart (returned by GET /listcart).
class CartItem {
  final String productId;
  final String name;
  final int price;
  final int? rating;
  final String? image;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    this.rating,
    this.image,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: (json['Product_ID'] ?? json['_id'] ?? '').toString(),
      name: (json['product_name'] ?? '').toString(),
      price: ((json['price'] ?? 0) as num).toInt(),
      rating: (json['rating'] as num?)?.toInt(),
      image: json['image'] as String?,
    );
  }
}

class CartSummary {
  final int total;
  final List<CartItem> items;

  CartSummary({required this.total, required this.items});
}
