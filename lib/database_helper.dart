import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class History {
  final int? id;
  final String label;
  final double confidence;
  final String timestamp;

  History({this.id, required this.label, required this.confidence, required this.timestamp});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'confidence': confidence,
      'timestamp': timestamp,
    };
  }
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'aquascan_history.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            label TEXT,
            confidence REAL,
            timestamp TEXT
          )
        ''');
      },
    );
  }

  Future<int> insertHistory(History history) async {
    final db = await database;
    return await db.insert('history', history.toMap());
  }

  Future<List<History>> getHistory() async {
    final db = await database;
    final maps = await db.query('history', orderBy: 'id DESC');
    return maps.map((map) => History(
      id: map['id'] as int?,
      label: map['label'] as String,
      confidence: map['confidence'] as double,
      timestamp: map['timestamp'] as String,
    )).toList();
  }
}