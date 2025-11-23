import 'package:flutter/material.dart';

// Reference Colors from main.dart
const Color trustBlue = Color(0xFF004AAD);
const Color actionGreen = Color(0xFF4CAF50);
const Color lightBackground = Color(0xFFF9F9F9);

enum AuditStatus { unchecked, pass, fail }

class RoomAuditScreen extends StatefulWidget {
  const RoomAuditScreen({super.key});

  @override
  State<RoomAuditScreen> createState() => _RoomAuditScreenState();
}

class _RoomAuditScreenState extends State<RoomAuditScreen> {
  final Map<int, AuditStatus> itemStatuses = {
    1: AuditStatus.pass,
    2: AuditStatus.fail,
    3: AuditStatus.unchecked,
  };

  final Map<int, TextEditingController> _defectControllers = {};

  @override
  void dispose() {
    for (final c in _defectControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = <Map<String, dynamic>>[
      {
        'id': 1,
        'q': 'Mattress condition (No tears, stains, or excessive wear)',
      },
      {
        'id': 2,
        'q': 'Bed Frame Integrity (No loose screws, wobbling, or sharp edges)',
      },
      {
        'id': 3,
        'q': 'Bedside Lamp Functionality (Working bulb and intact cable)',
      },
    ];

    final total = items.length;
    final completed = itemStatuses.values.where((s) => s != AuditStatus.unchecked).length;

    return Scaffold(
      backgroundColor: lightBackground,
      appBar: AppBar(
        backgroundColor: trustBlue,
        foregroundColor: Colors.white,
        title: const Text('Room B405 Audit'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: 0.45, // wireframe simulation
            color: actionGreen,
            backgroundColor: Colors.black.withOpacity(0.1),
            minHeight: 4,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          const Text(
            'Bed Structure & Mattress (Item 2 of 6)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          for (final item in items) ...[
            _buildAuditItem(
              item['id'] as int,
              item['q'] as String,
              itemStatuses[item['id']] ?? AuditStatus.unchecked,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: actionGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {},
              child: Text('SAVE SECTION PROGRESS ($completed/$total)'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuditItem(int itemId, String question, AuditStatus currentStatus) {
    final isPass = currentStatus == AuditStatus.pass;
    final isFail = currentStatus == AuditStatus.fail;
    final inactiveBg = Colors.grey[200];
    final inactiveFg = Colors.grey[800];

    _defectControllers.putIfAbsent(itemId, () => TextEditingController());

    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPass ? actionGreen : inactiveBg,
                      foregroundColor: isPass ? Colors.white : inactiveFg,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: isPass ? 3 : 0,
                    ),
                    onPressed: () {
                      setState(() {
                        itemStatuses[itemId] = AuditStatus.pass;
                        _defectControllers[itemId]?.text = '';
                      });
                    },
                    child: const Text('PASS', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFail ? Colors.red : inactiveBg,
                      foregroundColor: isFail ? Colors.white : inactiveFg,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: isFail ? 3 : 0,
                    ),
                    onPressed: () {
                      setState(() {
                        itemStatuses[itemId] = AuditStatus.fail;
                      });
                    },
                    child: const Text('FAIL', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            if (isFail) ...[
              const SizedBox(height: 12),
              const Text(
                'Defect Details (Mandatory)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _defectControllers[itemId],
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Describe the defect (e.g., loose bolts on top bunk rail)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  label: const Text(
                    'Upload Photo',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {},
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


