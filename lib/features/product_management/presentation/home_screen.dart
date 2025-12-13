import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _productIdController = TextEditingController();
  final _supplierController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _repository = ProductRepository();
  StockStatus _selectedStockStatus = StockStatus.inStock;

  @override
  void dispose() {
    _productIdController.dispose();
    _supplierController.dispose();
    super.dispose();
  }

  Future<void> _generateQr() async {
    if (_formKey.currentState!.validate()) {
      final productId = _productIdController.text.trim();
      final supplier = _supplierController.text.trim();

      final existingProduct = await _repository.getProduct(productId);

      if (existingProduct != null) {
        if (!mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Product Exists'),
            content: Text(
              'Product ID "$productId" is already registered. Do you want to replace it?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Replace'),
              ),
            ],
          ),
        );

        if (confirm != true) return;
      }

      final product = Product(
        id: productId,
        supplier: supplier,
        stockStatus: _selectedStockStatus,
      );

      await _repository.saveProduct(product);

      if (mounted) {
        context.push('/qr', extra: productId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Status Detection')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Product Management',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _productIdController,
                  decoration: const InputDecoration(
                    labelText: 'Product ID',
                    hintText: 'Enter Product ID',
                    prefixIcon: Icon(Icons.qr_code),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a Product ID';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _supplierController,
                  decoration: const InputDecoration(
                    labelText: 'Supplier',
                    hintText: 'Enter Supplier Name',
                    prefixIcon: Icon(Icons.business),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a Supplier';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<StockStatus>(
                  value: _selectedStockStatus,
                  decoration: const InputDecoration(
                    labelText: 'Stock Status',
                    prefixIcon: Icon(Icons.inventory),
                  ),
                  items: StockStatus.values.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(status.label),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedStockStatus = value);
                    }
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _generateQr,
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Generate QR Code'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => context.push('/dashboard'),
                  icon: const Icon(Icons.dashboard),
                  label: const Text('View Product Dashboard'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => context.push('/capture'),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Go to Data Capture'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => context.push('/export'),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Manage Captured Data'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
