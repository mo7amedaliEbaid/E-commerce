import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Future<CartSummary> _future;
  bool _checkingOut = false;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.listCart();
  }

  void _reload() {
    setState(() => _future = ApiClient.listCart());
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _removeItem(CartItem item) async {
    try {
      await ApiClient.removeFromCart(item.productId);
      _showMessage('Removed "${item.name}"');
      _reload();
    } on ApiException catch (e) {
      _showMessage(e.message);
    }
  }

  Future<void> _checkout() async {
    setState(() => _checkingOut = true);
    try {
      await ApiClient.checkout();
      _showMessage('Order placed!');
      _reload();
    } on ApiException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<CartSummary>(
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
            final cart = snapshot.data ?? CartSummary(total: 0, items: []);
            if (cart.items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(child: Text('Your cart is empty')),
                ],
              );
            }
            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return ListTile(
                        title: Text(item.name),
                        subtitle: Text('\$${item.price}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _removeItem(item),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Total: \$${cart.total}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      FilledButton(
                        onPressed: _checkingOut ? null : _checkout,
                        child: _checkingOut
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Checkout'),
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
  }
}
