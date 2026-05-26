/// POI detail page — full scenic spot info with best poses.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/photo_spot.dart';
import '../../../shared/widgets/section_label.dart';
import '../../../features/pose_square/presentation/pose_detail_page.dart';

class PoiDetailPage extends ConsumerWidget {
  final PhotoSpot poi;

  const PoiDetailPage({super.key, required this.poi});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: Text(poi.nameZh),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            _HeaderCard(poi: poi),
            const SizedBox(height: 20),

            // Description
            if (poi.description.isNotEmpty) ...[
              SectionLabel(label: '景点介绍'),
              const SizedBox(height: 8),
              Text(
                poi.description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Photo tip
            if (poi.photoTip.isNotEmpty) ...[
              SectionLabel(label: '拍照技巧'),
              const SizedBox(height: 8),
              _InfoCard(
                icon: Icons.lightbulb_outline,
                color: Colors.amber,
                text: poi.photoTip,
              ),
              const SizedBox(height: 20),
            ],

            // Best time
            if (poi.bestTime.isNotEmpty) ...[
              SectionLabel(label: '最佳拍摄时间'),
              const SizedBox(height: 8),
              _InfoCard(
                icon: Icons.wb_sunny_outlined,
                color: Colors.orange,
                text: poi.bestTime,
              ),
              const SizedBox(height: 20),
            ],

            // Best angles
            if (poi.bestAngles.isNotEmpty) ...[
              SectionLabel(label: '最佳拍摄角度'),
              const SizedBox(height: 8),
              ...poi.bestAngles.map(
                (angle) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _InfoCard(
                    icon: Icons.camera_alt_outlined,
                    color: Colors.blueGrey,
                    text: angle,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Best poses
            if (poi.bestPoseIds.isNotEmpty) ...[
              SectionLabel(label: '推荐姿势'),
              const SizedBox(height: 8),
              ...poi.bestPoseIds.map((poseId) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _PoseLinkCard(
                      poseId: poseId,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PoseDetailPage(poseId: poseId),
                          ),
                        );
                      },
                    ),
                  )),
              const SizedBox(height: 20),
            ],

            // Tags
            if (poi.tags.isNotEmpty) ...[
              SectionLabel(label: '标签'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: poi.tags
                    .map((t) => _TagChip(label: t))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final PhotoSpot poi;

  const _HeaderCard({required this.poi});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          // Placeholder icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.place, color: Colors.amber, size: 36),
          ),
          const SizedBox(height: 14),
          Text(
            poi.nameZh,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _HeaderChip(
                icon: Icons.location_on_outlined,
                label: '${poi.city} · ${poi.region}',
              ),
              const SizedBox(width: 12),
              _HeaderChip(
                icon: Icons.star,
                label: poi.popularity.toStringAsFixed(1),
                color: Colors.amber,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _HeaderChip({
    required this.icon,
    required this.label,
    this.color = Colors.white70,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 13),
        ),
      ],
    );
  }
}


class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _InfoCard({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PoseLinkCard extends StatelessWidget {
  final String poseId;
  final VoidCallback onTap;

  const _PoseLinkCard({required this.poseId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.accessibility_new,
                  color: Colors.amber, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  poseId,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.3), size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.amber, fontSize: 12),
      ),
    );
  }
}
