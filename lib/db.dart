import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DB {
  static final DB _instance = DB._internal();
  static Database? _db;

  DB._internal();
  factory DB() => _instance;

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future close() async {
    final db = await getDB();
    await db.close();
  }

  Future<Database> getDB() async {
    if (_db != null) return _db!;
    _db = await _initDB('comandas.db');
    return _db!;
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL,
        first_name TEXT,
        last_name TEXT,
        pin TEXT NOT NULL CHECK(LENGTH(pin) BETWEEN 4 AND 6),
        created_at DEFAULT CURRENT_TIMESTAMP,
        is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1))
      )
    ''');
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT,
        phone TEXT,
        email TEXT,
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1))
      )
    ''');
    await db.execute('''
      CREATE TABLE table_areas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1))
      )
    ''');
    await db.execute('''
      CREATE TABLE tables (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          table_area_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          FOREIGN KEY(table_area_id) REFERENCES table_areas(id),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1))
      )
    ''');

    await db.execute('''
      CREATE TABLE product_categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1))
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_category_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          price REAL NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
          FOREIGN KEY(product_category_id) REFERENCES product_categories(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE orders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        is_cancelled INTEGER NOT NULL DEFAULT 0 CHECK (is_cancelled IN (0,1)),
        created_at DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(table_id) REFERENCES tables(id),
        FOREIGN KEY(user_id) REFERENCES users(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE order_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        price REAL NOT NULL,
        total REAL NOT NULL,
        FOREIGN KEY(order_id) REFERENCES orders(id),
        FOREIGN KEY(product_id) REFERENCES products(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE invoices(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        total REAL NOT NULL,
        is_cancelled INTEGER NOT NULL DEFAULT 0 CHECK (is_cancelled IN (0,1)),
        is_paid INTEGER NOT NULL DEFAULT 0 CHECK (is_paid IN (0,1)),
        created_at DEFAULT CURRENT_TIMESTAMP,
        paid_at TEXT,
        FOREIGN KEY(customer_id) REFERENCES customers(id),
        FOREIGN KEY(user_id) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE invoice_orders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        order_id INTEGER NOT NULL,
        FOREIGN KEY(invoice_id) REFERENCES invoices(id),
        FOREIGN KEY(order_id) REFERENCES orders(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE ingredients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        unit TEXT NOT NULL,
        stock REAL NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1)),
        created_at DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('''
      CREATE TABLE product_ingredients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        ingredient_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        FOREIGN KEY(product_id) REFERENCES products(id),
        FOREIGN KEY(ingredient_id) REFERENCES ingredients(id)
    )
    ''');
    await db.execute('''
      CREATE TABLE ingredient_consumptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_item_id INTEGER NOT NULL,
        ingredient_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        created_at DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(order_item_id) REFERENCES order_items(id),
        FOREIGN KEY(ingredient_id) REFERENCES ingredients(id)
    )
    ''');
  }

  // *** USUARIOS ***
  // Crear usuario
  Future<int> createUser(Map<String, dynamic> user) async {
    final db = await getDB();
    return await db.insert('users', user);
  }

  // Obtener usuario por PIN
  Future<Map<String, dynamic>?> getUserByPin(String pin) async {
    final db = await getDB();
    final res = await db.query(
      'users',
      where: 'pin = ? AND is_active = 1',
      whereArgs: [pin],
    );
    return res.isNotEmpty ? res.first : null;
  }

  // Listar usuarios activos
  Future<List<Map<String, dynamic>>> getUsers() async {
    final db = await getDB();
    return await db.query('users', where: 'is_active = 1');
  }

  Future<int> setUserActiveStatus(int userId, bool isActive) async {
    final db = await getDB();
    return await db.update(
      'users',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  // *** CLIENTES ***
  Future<int> createCustomer(Map<String, dynamic> customer) async {
    final db = await getDB();
    return await db.insert('customers', customer);
  }

  Future<List<Map<String, dynamic>>> getCustomers() async {
    final db = await getDB();
    return await db.query('customers', where: 'is_active = 1');
  }

  // *** MESAS ***
  Future<List<Map<String, dynamic>>> getTableAreas() async {
    final db = await getDB();
    return await db.query('table_areas', where: 'is_active = 1');
  }

  Future<int> createTable(Map<String, dynamic> table) async {
    final db = await getDB();
    return await db.insert('tables', table);
  }

  Future<List<Map<String, dynamic>>> getTables({int? areaId}) async {
    final db = await getDB();
    if (areaId != null) {
      return await db.query(
        'tables',
        where: 'table_area_id = ? AND is_active = 1',
        whereArgs: [areaId],
      );
    }
    return await db.query('tables', where: 'is_active = 1');
  }

  Future<int> setCustomerActiveStatus(int customerId, bool isActive) async {
    final db = await getDB();
    return await db.update(
      'customers',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }

  // *** PRODUCTOS ***

  Future<int> createProductCategory(Map<String, dynamic> category) async {
    final db = await getDB();
    return await db.insert('product_categories', category);
  }

  Future<int> createProduct(Map<String, dynamic> product) async {
    final db = await getDB();
    return await db.insert('products', product);
  }

  Future<List<Map<String, dynamic>>> getProducts({int? categoryId}) async {
    final db = await getDB();
    if (categoryId != null) {
      return await db.query(
        'products',
        where: 'product_category_id = ? AND is_active = 1',
        whereArgs: [categoryId],
      );
    }
    return await db.query('products', where: 'is_active = 1');
  }

  Future<int> updateProductPrice(int productId, double newPrice) async {
    final db = await getDB();
    return await db.update(
      'products',
      {'price': newPrice},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  Future<int> setProductActiveStatus(int productId, bool isActive) async {
    final db = await getDB();
    return await db.update(
      'products',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  // *** COMANDAS ***
  Future<int> createOrder(
    Map<String, dynamic> order,
    List<Map<String, dynamic>> items,
  ) async {
    final db = await getDB();
    int orderId = 0;

    // Ejecutar todo dentro de una transacción para que sea atómico
    await db.transaction((txn) async {
      orderId = await txn.insert('orders', order);

      for (var item in items) {
        item['order_id'] = orderId;
        int orderItemId = await txn.insert('order_items', item);

        final productIngredients = await txn.query(
          'product_ingredients',
          where: 'product_id = ?',
          whereArgs: [item['product_id']],
        );

        for (var pi in productIngredients) {
          double consumedQty =
              (pi['quantity'] as double) * (item['quantity'] as double);
          await txn.insert('ingredient_consumptions', {
            'order_item_id': orderItemId,
            'ingredient_id': pi['ingredient_id'],
            'quantity': consumedQty,
            'created_at': DateTime.now().toIso8601String(),
          });

          // Actualizar stock del ingrediente (opcional)
          await txn.rawUpdate(
            '''
          UPDATE ingredients
          SET stock = stock - ?
          WHERE id = ?
        ''',
            [consumedQty, pi['ingredient_id']],
          );
        }
      }
    });

    return orderId;
  }

  Future<List<Map<String, dynamic>>> getOrders({
    int? orderId,
    int? tableId,
    int? userId,
    bool? isCancelled,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await getDB();

    // Lista de condiciones y argumentos
    List<String> conditions = [];
    List<dynamic> args = [];

    if (orderId != null) {
      conditions.add('id = ?');
      args.add(orderId);
    }

    if (tableId != null) {
      conditions.add('table_id = ?');
      args.add(tableId);
    }

    if (userId != null) {
      conditions.add('user_id = ?');
      args.add(userId);
    }

    if (isCancelled != null) {
      conditions.add('is_cancelled = ?');
      args.add(isCancelled ? 1 : 0);
    }

    if (startDate != null) {
      conditions.add('created_at >= ?');
      args.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      conditions.add('created_at <= ?');
      args.add(endDate.toIso8601String());
    }

    // Construir la cláusula WHERE
    String whereClause = conditions.isNotEmpty ? conditions.join(' AND ') : '';

    return await db.query(
      'orders',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'created_at DESC',
    );
  }

  // Obtener items de una comanda
  Future<List<Map<String, dynamic>>> getOrderItems(int orderId) async {
    final db = await getDB();
    return await db.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
  }

  // *** FACTURAS ***

  Future<int> createInvoice(Map<String, dynamic> invoice) async {
    final db = await getDB();
    return await db.insert('invoices', invoice);
  }

  Future<int> linkOrderToInvoice(int invoiceId, int orderId) async {
    final db = await getDB();
    return await db.insert('invoice_orders', {
      'invoice_id': invoiceId,
      'order_id': orderId,
    });
  }

  // Obtener todas las comandas de una factura
  Future<List<Map<String, dynamic>>> getInvoiceOrders(int invoiceId) async {
    final db = await getDB();
    return await db.query(
      'invoice_orders',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );
  }

  // *** INGREDIENTES ***
  Future<int> createIngredient(Map<String, dynamic> ingredient) async {
    final db = await getDB();
    return await db.insert('ingredients', ingredient);
  }

  Future<int> linkProductIngredient(Map<String, dynamic> pi) async {
    final db = await getDB();
    return await db.insert('product_ingredients', pi);
  }

  Future<int> recordIngredientConsumption(
    Map<String, dynamic> consumption,
  ) async {
    final db = await getDB();
    return await db.insert('ingredient_consumptions', consumption);
  }

  // Reporte de consumo total de un ingrediente
  Future<List<Map<String, dynamic>>> getIngredientConsumption(
    int ingredientId,
  ) async {
    final db = await getDB();
    return await db.rawQuery(
      '''
    SELECT SUM(quantity) as total_consumed
    FROM ingredient_consumptions
    WHERE ingredient_id = ?
  ''',
      [ingredientId],
    );
  }
}
