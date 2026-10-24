import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/network_service.dart';
import 'home_dashboard_screen.dart';
import 'hq_data_screen.dart';
import 'storage_management_screen.dart';

class EquipmentSelectionScreen extends StatefulWidget {
  const EquipmentSelectionScreen({super.key});

  @override
  State<EquipmentSelectionScreen> createState() =>
      _EquipmentSelectionScreenState();
}

class _EquipmentSelectionScreenState extends State<EquipmentSelectionScreen> {
  List<EquipmentModel> _equipmentList = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEquipment();
  }

  Future<void> _loadEquipment() async {
    setState(() {
      _loading = true;
    });

    try {
      final hqUrl = NetworkService().hqBaseUrl;
      final res = await http
          .get(Uri.parse('$hqUrl/equipment'))
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List)
            .map((item) => EquipmentModel.fromJson(item))
            .toList();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_equipment', res.body);
        if (mounted) setState(() => _equipmentList = list);
      } else {
        setState(() => _equipmentList = []);
      }
    } catch (_) {
      // Offline fallback: check SharedPreferences cached equipment or empty
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_equipment');
      if (cachedJson != null) {
        final list = (jsonDecode(cachedJson) as List)
            .map((item) => EquipmentModel.fromJson(item))
            .toList();
        setState(() => _equipmentList = list);
      }
    } finally {
      if (_equipmentList.isEmpty) {
        _equipmentList = [
          EquipmentModel(
            id: 'pump-01',
            name: 'WARMAN AH Centrifugal Slurry Pump',
            modelNumber: 'WARMAN-6x4D-AH',
            manufacturer: 'Weir Minerals / Warman',
            serialNumber: 'WM-2024-8841',
            description: 'Slurry Processing Bay 2',
          ),
        ];
      }
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectEquipment(EquipmentModel eq) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_equipment_id', eq.id);
    await prefs.setString('active_equipment_name', eq.name);
    await prefs.setString('active_equipment_model', eq.modelNumber);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeDashboardScreen(equipment: eq)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      appBar: AppBar(
        title: const Text('Select Equipment Asset',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Manage equipment and manuals',
            icon: const Icon(Icons.more_vert),
            onSelected: (category) async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) =>
                category == 'local'
                  ? const StorageManagementScreen()
                  : HqDataScreen(initialCategory: category)));
              if (mounted) await _loadEquipment();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'equipment', child: Text('Delete HQ equipment')),
              PopupMenuItem(value: 'manuals', child: Text('Delete HQ manuals')),
              PopupMenuItem(value: 'local', child: Text('Manage offline downloads')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assigned Equipment',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose the industrial machine you are servicing to activate its local RAG knowledge.',
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              if (_loading)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator()))
              else if (_equipmentList.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.precision_manufacturing_outlined,
                            size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text(
                          'No Equipment Packages Cached',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Connect to the Headquarters Hotspot to fetch equipment registrations.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _loadEquipment,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry Fetch'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _equipmentList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final eq = _equipmentList[index];
                      return InkWell(
                        onTap: () => _selectEquipment(eq),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F0FE),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(Icons.memory,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(eq.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${eq.manufacturer} • ${eq.modelNumber}',
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: Colors.grey),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
