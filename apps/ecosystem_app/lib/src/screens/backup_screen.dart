import 'package:backup/backup.dart';
import 'package:flutter/material.dart';
import 'package:ui/ui.dart';

class BackupScreen extends StatefulWidget {
  final BackupWriter backupWriter;

  const BackupScreen({super.key, required this.backupWriter});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  String? _lastBackupInfo;
  bool _isCreating = false;

  void _createBackup() async {
    setState(() => _isCreating = true);
    try {
      final res = await widget.backupWriter.createBackup(
        type: BackupType.manual,
        actorId: 'usr_admin_01',
        deviceId: 'dev_local_pos',
      );
      setState(() {
        _lastBackupInfo = 'Archive: ${res.id}.zynb (${res.fileSizeBytes} bytes)\nSHA-256: ${res.sha256Checksum}';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(AppColors.success),
            content: Text('Disaster recovery archive generated successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(AppColors.danger), content: Text('Backup Error: $e')),
        );
      }
    } finally {
      setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Disaster Recovery & Encrypted Archive (.zynb)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Rule 86-91: Verifiable snapshot archive containing SQLite database, media files, and SHA-256 cryptographic seal.',
            style: TextStyle(color: Color(AppColors.darkTextSecondary), fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppColors.primaryValue),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
            onPressed: _isCreating ? null : _createBackup,
            icon: _isCreating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.archive),
            label: Text(_isCreating ? 'Creating Archive...' : 'Generate Full Backup (.zynb)'),
          ),
          if (_lastBackupInfo != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: const Color(AppColors.darkSurface),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: const Color(AppColors.darkBorder)),
              ),
              child: SelectableText(
                _lastBackupInfo!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(AppColors.info)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
