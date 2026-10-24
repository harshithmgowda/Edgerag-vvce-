import 'package:flutter/material.dart';
import '../models/models.dart';
import '../screens/provider_settings_screen.dart';

/// A per-screen selection only. This widget never sends prompts or documents.
class AiRequestPicker extends StatelessWidget {
  final AiMode mode;
  final String provider;
  final bool enabled;
  final bool audio;
  final void Function(AiMode, String) onChanged;
  const AiRequestPicker(
      {super.key,
      required this.mode,
      required this.provider,
      required this.onChanged,
      this.enabled = true,
      this.audio = false});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DropdownButton<AiMode>(
            value: mode,
            isExpanded: true,
            items: const [
              DropdownMenuItem(
                  value: AiMode.offlineOnly,
                  child: Text('Local AI · Gemma 4 E2B IT')),
              DropdownMenuItem(
                  value: AiMode.onlineAi,
                  child: Text('External AI · choose provider')),
              DropdownMenuItem(
                  value: AiMode.smartAuto,
                  child: Text('Automatic · cloud with local fallback')),
            ],
            onChanged: enabled ? (value) => onChanged(value!, provider) : null),
        if (mode != AiMode.offlineOnly)
          DropdownButton<String>(
              value: provider,
              isExpanded: true,
              items: [
                const DropdownMenuItem(
                    value: 'auto', child: Text('Automatic provider')),
                const DropdownMenuItem(
                    value: 'gemini',
                    child: Text('Gemini · model from AI Providers')),
                if (!audio)
                  const DropdownMenuItem(
                      value: 'nvidia',
                      child: Text('NVIDIA · model from AI Providers')),
              ],
              onChanged: enabled
                  ? (value) => onChanged(AiMode.onlineAi, value!)
                  : null),
        if (mode != AiMode.offlineOnly)
          Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                  onPressed: enabled
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProviderSettingsScreen()))
                      : null,
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Choose cloud model / API key'))),
        if (audio && mode != AiMode.offlineOnly)
          const Text(
              'Cloud audio uses Gemini. The NVIDIA text endpoint does not accept audio.',
              style: TextStyle(fontSize: 11)),
      ]));
}
