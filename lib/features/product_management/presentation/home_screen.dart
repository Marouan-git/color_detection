import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _productIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _productIdController.dispose();
    super.dispose();
  }

  void _generateQr() {
    if (_formKey.currentState!.validate()) {
      context.push('/qr', extra: _productIdController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Traffic Sensor Detection')),
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
                    hintText: 'Enter Product ID or Name',
                    prefixIcon: Icon(Icons.qr_code),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a Product ID';
                    }
                    return null;
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
                  onPressed: () => context.push('/capture'),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Go to Data Capture'),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
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
