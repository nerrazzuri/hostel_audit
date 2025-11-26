import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/ui.dart';
import '../../utils/time.dart';

class TenantAddScreen extends StatefulWidget {
  const TenantAddScreen({super.key});

  @override
  State<TenantAddScreen> createState() => _TenantAddScreenState();
}

class _TenantAddScreenState extends State<TenantAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _passportCtrl = TextEditingController();
  final _permitCtrl = TextEditingController();
  DateTime? _permitExpiry;
  DateTime? _checkIn;
  DateTime? _checkOut;

  String? _selectedHostelId;
  String? _selectedUnitId;
  List<Map<String, dynamic>> _hostels = [];
  List<Map<String, dynamic>> _units = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadHostels();
  }

  Future<void> _loadHostels() async {
    try {
      final rows = await Supabase.instance.client
          .from('hostels')
          .select('id, name')
          .order('name');
      setState(() {
        _hostels = List<Map<String, dynamic>>.from(rows);
      });
    } catch (e) {
      if (mounted) showError(context, e, prefix: 'Failed to load hostels');
    }
  }

  Future<void> _loadUnits(String hostelId) async {
    try {
      final rows = await Supabase.instance.client
          .from('hostel_units')
          .select('id, name')
          .eq('hostel_id', hostelId)
          .order('name');
      setState(() {
        _units = List<Map<String, dynamic>>.from(rows);
      });
    } catch (e) {
      if (mounted) showError(context, e, prefix: 'Failed to load units');
    }
  }

  Future<void> _pickDate(BuildContext context, ValueChanged<DateTime> onPicked, {DateTime? initial}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) {
      onPicked(picked);
      setState(() {});
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedHostelId == null || _selectedUnitId == null) {
      showInfo(context, 'Please select hostel and unit');
      return;
    }
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.from('tenants').insert({
        'name': _nameCtrl.text.trim(),
        'passport_number': _passportCtrl.text.trim(),
        'permit_number': _permitCtrl.text.trim(),
        'permit_expiry_date': _permitExpiry?.toIso8601String(),
        'check_in_date': _checkIn?.toIso8601String(),
        'check_out_date': _checkOut?.toIso8601String(),
        'unit_id': _selectedUnitId,
      });
      if (mounted) {
        showInfo(context, 'Tenant created');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showError(context, e, prefix: 'Create failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Tenant')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Basic Information', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passportCtrl,
                decoration: const InputDecoration(labelText: 'Passport Number', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _permitCtrl,
                decoration: const InputDecoration(labelText: 'Permit Number', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              const Text('Accommodation', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedHostelId,
                items: _hostels.map((h) => DropdownMenuItem<String>(
                  value: h['id'] as String,
                  child: Text(h['name'] ?? '-'),
                )).toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedHostelId = v;
                    _selectedUnitId = null;
                    _units = [];
                  });
                  if (v != null) _loadUnits(v);
                },
                decoration: const InputDecoration(labelText: 'Hostel', border: OutlineInputBorder()),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedUnitId,
                items: _units.map((u) => DropdownMenuItem<String>(
                  value: u['id'] as String,
                  child: Text(u['name'] ?? '-'),
                )).toList(),
                onChanged: (v) => setState(() => _selectedUnitId = v),
                decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              const Text('Dates', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DatePickerField(
                      label: 'Permit Expiry',
                      value: _permitExpiry,
                      onTap: () => _pickDate(context, (d) => _permitExpiry = d, initial: _permitExpiry),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DatePickerField(
                      label: 'Check In',
                      value: _checkIn,
                      onTap: () => _pickDate(context, (d) => _checkIn = d, initial: _checkIn),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _DatePickerField(
                label: 'Check Out',
                value: _checkOut,
                onTap: () => _pickDate(context, (d) => _checkOut = d, initial: _checkOut),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _save,
                  icon: _loading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: const Text('Save Tenant'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  const _DatePickerField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = value == null ? 'Select date' : DateFormat('dd/MM/yyyy').format(value!);
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: Text(text),
      ),
    );
  }
}


