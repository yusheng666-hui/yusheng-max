/// Pose Clone page — pick a photo, extract skeleton, save for AR replication.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../domain/providers.dart';
import '../domain/clone_store.dart';
import 'clone_result_page.dart';

class ClonePage extends ConsumerStatefulWidget {
  const ClonePage({super.key});

  @override
  ConsumerState<ClonePage> createState() => _ClonePageState();
}

class _ClonePageState extends ConsumerState<ClonePage> {
  final _picker = ImagePicker();
  bool _loadingStore = true;

  @override
  void initState() {
    super.initState();
    _initStore();
  }

  Future<void> _initStore() async {
    await ref.read(cloneStoreProvider).load();
    if (mounted) setState(() => _loadingStore = false);
  }

  Future<void> _pickAndDetect() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (xfile == null) return;

    ref.read(isDetectingProvider.notifier).state = true;

    final service = ref.read(poseCloneServiceProvider);
    final result = await service.detectFromFile(xfile.path);

    ref.read(isDetectingProvider.notifier).state = false;

    if (result == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未检测到人体，请选择包含全身或半身人物的照片')),
        );
      }
      return;
    }

    if (result.confidence < 0.3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('检测置信度较低 (${(result.confidence * 100).toInt()}%)，建议换一张更清晰的照片'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    ref.read(cloneResultProvider.notifier).state = result;

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const CloneResultPage(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDetecting = ref.watch(isDetectingProvider);
    final entries = ref.watch(clonedPosesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text('姿势克隆'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loadingStore
          ? const Center(
              child: CircularProgressIndicator(
                  color: Colors.amber, strokeWidth: 2))
          : Column(
              children: [
                // Pick button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: isDetecting ? null : _pickAndDetect,
                      icon: isDetecting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2),
                            )
                          : const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(isDetecting ? '检测中...' : '从相册选择照片'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.amber.withOpacity(0.15),
                        foregroundColor: Colors.amber,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                // History
                Expanded(
                  child: entries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.content_copy,
                                  color: Colors.white.withOpacity(0.2),
                                  size: 48),
                              const SizedBox(height: 12),
                              Text(
                                '还没有克隆姿势\n选择一张全身或半身照片开始克隆',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.35),
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            return _CloneEntryCard(
                              entry: entry,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CloneResultPage(
                                      existingEntry: entry,
                                    ),
                                  ),
                                );
                              },
                              onDelete: () {
                                ref
                                    .read(cloneStoreProvider)
                                    .deleteEntry(entry.id);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _CloneEntryCard extends StatelessWidget {
  final ClonedPoseEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CloneEntryCard({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final thumb = entry.thumbBytes;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 56,
                    height: 56,
                    color: Colors.white.withOpacity(0.05),
                    child: thumb != null && thumb.isNotEmpty
                        ? Image.memory(thumb, fit: BoxFit.cover)
                        : const Icon(Icons.person,
                            color: Colors.white24, size: 28),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${entry.skeleton.keypoints.length} 个关键点 · '
                        '置信度 ${(entry.confidence * 100).toInt()}%',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: Colors.white24,
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
