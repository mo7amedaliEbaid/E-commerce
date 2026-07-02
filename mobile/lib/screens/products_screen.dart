import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models.dart';
import 'cart_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late Future<List<Product>> _future;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = ApiClient.fetchProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _future = ApiClient.fetchProducts());
  }

  void _search(String query) {
    setState(() {
      _future = query.trim().isEmpty
          ? ApiClient.fetchProducts()
          : ApiClient.searchProducts(query.trim());
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addToCart(Product product) async {
    try {
      await ApiClient.addToCart(product.id);
      _showMessage('Added "${product.name}" to cart');
    } on ApiException catch (e) {
      _showMessage(e.message);
    }
  }

  Future<void> _buyNow(Product product) async {
    try {
      await ApiClient.instantBuy(product.id);
      _showMessage('Bought "${product.name}"');
    } on ApiException catch (e) {
      _showMessage(e.message);
    }
  }

  Future<void> _openAddProductDialog() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final ratingController = TextEditingController();
    final imageController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add product'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      int.tryParse(v ?? '') == null ? 'Enter a number' : null,
                ),
                TextFormField(
                  controller: ratingController,
                  decoration:
                      const InputDecoration(labelText: 'Rating (0-5)'),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      int.tryParse(v ?? '') == null ? 'Enter a number' : null,
                ),
                TextFormField(
                  controller: imageController,
                  decoration: const InputDecoration(labelText: 'Image URL'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await ApiClient.addProductAdmin(
                  name: nameController.text,
                  price: int.parse(priceController.text),
                  rating: int.parse(ratingController.text),
                  image: imageController.text,
                );
                if (context.mounted) Navigator.of(context).pop(true);
              } on ApiException catch (e) {
                _showMessage(e.message);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (added == true) {
      _showMessage('Product added');
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CartScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddProductDialog,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search products',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _search('');
                  },
                ),
              ),
              onSubmitted: _search,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _reload(),
              child: FutureBuilder<List<Product>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(child: Text('Error: ${snapshot.error}')),
                      ],
                    );
                  }
                  final products = snapshot.data ?? [];
                  if (products.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(child: Text('No products yet - tap + to add one')),
                      ],
                    );
                  }
                  return ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return Card(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: SizedBox(
                            width: 56,
                            height: 56,
                            child: (product.image == null || product.image!.isEmpty)
                                ? const Icon(Icons.image_not_supported)
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      ApiClient.productImageUrl(product.id),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.broken_image),
                                    ),
                                  ),
                          ),
                          title: Text(product.name),
                          subtitle: Text('\$${product.price} · ${product.rating}★'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Add to cart',
                                icon: const Icon(Icons.add_shopping_cart),
                                onPressed: () => _addToCart(product),
                              ),
                              IconButton(
                                tooltip: 'Buy now',
                                icon: const Icon(Icons.flash_on),
                                onPressed: () => _buyNow(product),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
