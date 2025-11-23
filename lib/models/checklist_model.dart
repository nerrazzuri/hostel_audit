enum ItemStatus { good, damaged, missing, na }

class AuditItem {
  final String nameEn;
  final String nameMs;
  ItemStatus status;
  String correctiveAction;
  String auditComment;
  List<String> imagePaths;

  AuditItem({
    required this.nameEn,
    required this.nameMs,
    this.status = ItemStatus.missing,
    this.correctiveAction = '',
    this.auditComment = '',
    List<String>? imagePaths,
  }) : imagePaths = imagePaths ?? [];

  Map<String, dynamic> toJson() {
    return {
      'nameEn': nameEn,
      'nameMs': nameMs,
      'status': status.index,
      'correctiveAction': correctiveAction,
      'auditComment': auditComment,
      'imagePaths': imagePaths,
    };
  }

  factory AuditItem.fromJson(Map<String, dynamic> json) {
    return AuditItem(
      // Backward compatibility: fall back to legacy 'name' if present
      nameEn: json['nameEn'] ?? json['name'] ?? '',
      nameMs: json['nameMs'] ?? '',
      status: ItemStatus.values[json['status']],
      correctiveAction: json['correctiveAction'] ?? '',
      auditComment: json['auditComment'] ?? (json['remarks'] ?? ''),
      imagePaths: (json['imagePaths'] as List?)?.map((e) => e as String).toList() ?? 
                  (json['imagePath'] != null ? [json['imagePath'] as String] : []),
    );
  }
}

class AuditSection {
  final String nameEn;
  final String nameMs;
  final List<AuditItem> items;

  AuditSection({required this.nameEn, required this.nameMs, required this.items});

  Map<String, dynamic> toJson() {
    return {
      'nameEn': nameEn,
      'nameMs': nameMs,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }

  factory AuditSection.fromJson(Map<String, dynamic> json) {
    return AuditSection(
      nameEn: json['nameEn'] ?? json['name'] ?? '',
      nameMs: json['nameMs'] ?? '',
      items: (json['items'] as List)
          .map((i) => AuditItem.fromJson(i))
          .toList(),
    );
  }
}

class Audit {
  final String id;
  final DateTime date;
  final String auditorName;
  final String hostelName;
  final String employerName;
  final int headcount;
  final List<AuditSection> sections;

  final String? pdfUrl;

  Audit({
    required this.id,
    required this.date,
    required this.auditorName,
    required this.hostelName,
    this.employerName = '',
    this.headcount = 0,
    required this.sections,
    this.pdfUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'auditorName': auditorName,
      'hostelName': hostelName,
      'employerName': employerName,
      'headcount': headcount,
      'sections': sections.map((s) => s.toJson()).toList(),
      'pdfUrl': pdfUrl,
    };
  }

  factory Audit.fromJson(Map<String, dynamic> json) {
    return Audit(
      id: json['id'],
      date: DateTime.parse(json['date']),
      auditorName: json['auditorName'],
      hostelName: json['hostelName'],
      employerName: json['employerName'] ?? '',
      headcount: json['headcount'] ?? 0,
      sections: (json['sections'] as List)
          .map((s) => AuditSection.fromJson(s))
          .toList(),
      pdfUrl: json['pdfUrl'],
    );
  }
  
  // Factory to create a fresh audit with default checklist
  factory Audit.createDefault({List<AuditSection>? sections}) {
    return Audit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now().toUtc(),
      auditorName: '',
      hostelName: '',
      employerName: '',
      headcount: 0,
      sections: sections ?? _defaultSections(),
    );
  }

  static List<AuditSection> _defaultSections() {
    return [
      AuditSection(
        nameEn: 'External/ Surrounding',
        nameMs: 'Luaran/ Persekitaran',
        items: [
          AuditItem(nameEn: 'Area hanging clothes', nameMs: 'Kawasan ampaian'),
          AuditItem(nameEn: 'Cleanliness', nameMs: 'Kebersihan'),
          AuditItem(nameEn: 'Safety (door lock, gate)', nameMs: 'Keselamatan (Mangga pintu, pintu pagar)'),
          AuditItem(nameEn: 'Shoe Rack', nameMs: 'Rak Kasut'),
        ],
      ),
      AuditSection(
        nameEn: 'Living room',
        nameMs: 'Ruang Tamu',
        items: [
          AuditItem(nameEn: 'Notice board & Housekeeping Schedule', nameMs: 'Papan notis & Jadual Pengemasan'),
          AuditItem(nameEn: 'Emergency Contact Information', nameMs: 'Maklumat Pangilan Kecemasan'),
          AuditItem(nameEn: 'Cleanliness', nameMs: 'Kebersihan'),
          AuditItem(nameEn: 'Lamp', nameMs: 'Lampu'),
          AuditItem(nameEn: 'Fan', nameMs: 'Kipas'),
          AuditItem(nameEn: 'Fire Evacution Plan', nameMs: 'Pelan Laluan Kebakaran'),
          AuditItem(nameEn: 'Facilities & Utility ( fans, lamp, sofa, TV, curtain)', nameMs: 'Kemudahan & Utiliti (kipas, lampu, sofa, TV, langsir)'),
          AuditItem(nameEn: 'Curtains', nameMs: 'Langsir'),
        ],
      ),
      AuditSection(
        nameEn: 'Dining Room',
        nameMs: 'Ruang makan',
        items: [
          AuditItem(nameEn: 'Facilities & Utility ( dining table, chair, lamp)', nameMs: 'Kemudahan & Utiliti ( meja makan, kerusi, lampu)'),
          AuditItem(nameEn: 'Cleanliness', nameMs: 'Kebersihan'),
          AuditItem(nameEn: 'Lamp', nameMs: 'Lampu'),
        ],
      ),
      AuditSection(
        nameEn: 'Kitchen Facilities',
        nameMs: 'Kemudahan Dapur',
        items: [
          AuditItem(nameEn: 'Cooking Facilities', nameMs: 'Kelengkapan Memasak'),
          AuditItem(nameEn: 'Sink & Tap', nameMs: 'Sinki & Paip'),
          AuditItem(nameEn: 'Lamp', nameMs: 'Lampu'),
          AuditItem(nameEn: 'Cleanliness', nameMs: 'Kebersihan'),
          AuditItem(nameEn: 'Emergency Response: Fire extinguisher', nameMs: 'Tindak Balas Kecemasan: Alat pemadam api'),
          AuditItem(nameEn: 'Smoke Detector', nameMs: 'Pengesan asap'),
          AuditItem(nameEn: 'Refrigerator', nameMs: 'Peti sejuk'),
          AuditItem(nameEn: 'Food cabinet/ Rack', nameMs: 'Kabinet makanan/ Rak'),
          AuditItem(nameEn: 'Dustbin', nameMs: 'Tong sampah'),
        ],
      ),
      AuditSection(
        nameEn: 'Bedroom',
        nameMs: 'Bilik tidur',
        items: [
          AuditItem(nameEn: 'Cleanliness & Tidiness (food not allow in room)', nameMs: 'Kebersihan & Kekemasan (makanan tidak dibenarkan di dalam bilik)'),
          AuditItem(nameEn: 'Lamp', nameMs: 'Lampu'),
          AuditItem(nameEn: 'Fan', nameMs: 'Kipas'),
          AuditItem(nameEn: 'Double-Decker', nameMs: 'Katil Bertingkat'),
          AuditItem(nameEn: 'Wardrobe Condition', nameMs: 'Keadaan Almari Pakaian'),
          AuditItem(nameEn: 'Minimum 1 adapter each room', nameMs: 'Minima 1 adapter (plug tiga soket) setiap bilik'),
          AuditItem(nameEn: '**Additional Item: curtain, carpet, pillow, blanket, bed', nameMs: '**Item tambahan: langsir, permaidani, bantal, selimut, katil'),
        ],
      ),
      AuditSection(
        nameEn: 'Washroom',
        nameMs: 'Bilik air',
        items: [
          AuditItem(nameEn: 'Cleanliness', nameMs: 'Kebersihan'),
          AuditItem(nameEn: 'Lamp', nameMs: 'Lampu'),
          AuditItem(nameEn: 'Facility & Utility ( shower, tap, basin, hole trap)', nameMs: 'Kemudahan & Utiliti (paip mandi, paip, singki, lubang tandas)'),
        ],
      ),
      AuditSection(
        nameEn: 'Others',
        nameMs: 'Lain-lain',
        items: [
          AuditItem(nameEn: 'First-aid Kits', nameMs: 'Peti pertolongan cemas'),
          AuditItem(nameEn: 'Fire Extinguisher', nameMs: 'Alat Pemadam Api'),
          AuditItem(nameEn: 'Emergency Light', nameMs: 'Lampu Kecemasan'),
          AuditItem(nameEn: 'Smoke Detactor', nameMs: 'Pengesan asap'),
          AuditItem(nameEn: 'Exit Signage', nameMs: 'Papan Tanda Keluar'),
        ],
      ),
    ];
  }
}
