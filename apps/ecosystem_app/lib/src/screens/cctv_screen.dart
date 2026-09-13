import 'package:cctv/cctv.dart';
import 'package:flutter/material.dart';
import 'package:ui/ui.dart';

class CctvScreen extends StatefulWidget {
  final CameraDiscoveryService cctvDiscovery;

  const CctvScreen({super.key, required this.cctvDiscovery});

  @override
  State<CctvScreen> createState() => _CctvScreenState();
}

class _CctvScreenState extends State<CctvScreen> {
  List<CameraSource> _cameras = [];

  @override
  void initState() {
    super.initState();
    _loadCameras();
  }

  void _loadCameras() {
    setState(() {
      _cameras = widget.cctvDiscovery.listCameras();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('CCTV Surveillance Pipeline', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadCameras),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: 1.4,
              ),
              itemCount: _cameras.length,
              itemBuilder: (ctx, i) {
                final c = _cameras[i];
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: const Color(AppColors.darkBorder)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          const Row(
                            children: [
                              CircleAvatar(radius: 4, backgroundColor: Color(AppColors.success)),
                              SizedBox(width: 4),
                              Text('LIVE', style: TextStyle(fontSize: 10, color: Color(AppColors.success), fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                      const Center(
                        child: Icon(Icons.videocam, size: 48, color: Color(AppColors.darkTextMuted)),
                      ),
                      Text(c.sourceUrl, style: const TextStyle(fontSize: 10, color: Color(AppColors.darkTextMuted))),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
