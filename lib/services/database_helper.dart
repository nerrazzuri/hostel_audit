import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('hostel_audit.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const boolType = 'INTEGER NOT NULL';
    const intType = 'INTEGER NOT NULL';

    const intNullable = 'INTEGER';

    // Local Audits Table
    await db.execute('''
CREATE TABLE local_audits ( 
  id $idType, 
  user_id $textType,
  hostel_id $textNullable,
  unit_id $textNullable,
  hostel_name $textType,
  unit_name $textType,
  employer_name $textType,
  headcount $intType,
  date $textType,
  pdf_url $textNullable,
  sync_status $intType DEFAULT 0
  )
''');

    // Local Sections Table
    await db.execute('''
CREATE TABLE local_sections ( 
  id INTEGER PRIMARY KEY AUTOINCREMENT, 
  audit_id $textType,
  server_id $intNullable, -- Store Supabase ID (nullable for new local items)
  name_en $textType,
  name_ms $textType,
  position $intType,
  FOREIGN KEY (audit_id) REFERENCES local_audits (id) ON DELETE CASCADE
  )
''');

    // Local Items Table
    await db.execute('''
CREATE TABLE local_items ( 
  id INTEGER PRIMARY KEY AUTOINCREMENT, 
  section_id $intType,
  server_id $intNullable, -- Store Supabase ID (nullable for new local items)
  name_en $textType,
  name_ms $textType,
  status $textType,
  corrective_action $textNullable,
  audit_comment $textNullable,
  image_paths $textNullable,
  position $intType,
  FOREIGN KEY (section_id) REFERENCES local_sections (id) ON DELETE CASCADE
  )
''');

    // Local Defects Table (Optional, for tracking defects created offline)
    // We might just derive defects from items with 'fail' status during sync, 
    // but having a table helps if we want to store specific defect metadata locally.
    // For now, we'll rely on the audit items to generate defects during sync.
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
