import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/database_service.dart';

class IncidentCreateScreen extends StatefulWidget {
  final EquipmentModel equipment;
  final String? initialTitle;
  final String? initialDescription;
  final int? initialPage;
  final String? initialChunkId;

  const IncidentCreateScreen({
    super.key,
    required this.equipment,
    this.initialTitle,
    this.initialDescription,
    this.initialPage,
    this.initialChunkId,
  });

  @override
  State<IncidentCreateScreen> createState() => _IncidentCreateScreenState();
}

class _IncidentCreateScreenState extends State<IncidentCreateScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  IncidentSeverity _severity = IncidentSeverity.medium;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTitle != null) _titleController.text = widget.initialTitle!;
    if (widget.initialDescription != null) _descController.text = widget.initialDescription!;
  }

  Future<void> _saveIncident() async {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();

    if (title.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an incident title and description.')),
      );
      return;
    }

    setState(() => _saving = true);

    final incident = IncidentModel(
      id: const Uuid().v4(), // Permanent V4 UUID
      equipmentId: widget.equipment.id,
      title: title,
      description: desc,
      severity: _severity,
      recordedOfflineAt: DateTime.now().toUtc(),
      linkedManualPage: widget.initialPage,
      citationChunkId: widget.initialChunkId,
      syncStatus: SyncStatus.pending,
    );

    await DatabaseService().saveIncident(incident);

    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incident saved to offline outbox. Will sync on next HQ connection.')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Record Field Incident', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.equipment.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('Equipment ID: ${widget.equipment.id.substring(0, 8)}...',
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Incident Title *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155))),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'e.g. High Vibration Warning on Axis 3',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Severity Level *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155))),
            const SizedBox(height: 8),
            DropdownButtonFormField<IncidentSeverity>(
              initialValue: _severity,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: IncidentSeverity.values.map((s) {
                return DropdownMenuItem(
                  value: s,
                  child: Text(s.name.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _severity = val);
              },
            ),
            const SizedBox(height: 18),
            const Text('Detailed Technician Observations *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155))),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Describe physical symptoms, fault codes, ambient temperature, and preliminary checks performed...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            if (widget.initialPage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bookmark, size: 18, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text('Linked Manual Page: ${widget.initialPage}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveIncident,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save to Offline Outbox', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
