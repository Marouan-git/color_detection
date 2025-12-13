import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../domain/product.dart';

class ProductRepository {
  static const String _fileName = 'products.json';

  Future<File> get _file async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<List<Product>> getProducts() async {
    try {
      final file = await _file;
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((e) => Product.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveProduct(Product product) async {
    final products = await getProducts();
    final index = products.indexWhere((p) => p.id == product.id);

    if (index >= 0) {
      products[index] = product;
    } else {
      products.add(product);
    }

    await _saveList(products);
  }

  Future<void> _saveList(List<Product> products) async {
    final file = await _file;
    final jsonList = products.map((e) => e.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  Future<Product?> getProduct(String id) async {
    final products = await getProducts();
    try {
      return products.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }
}
