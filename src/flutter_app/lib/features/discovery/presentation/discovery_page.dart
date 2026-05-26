/// Discovery page — browse scenic photo spots by region or nearby GPS.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/photo_spot.dart';
import '../domain/providers.dart';
import 'poi_detail_page.dart';

class DiscoveryPage extends ConsumerWidget {
  const DiscoveryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loader = ref.watch(poiLoaderProvider);
    final nearbyMode = ref.watch(nearbyModeProvider);
    final filtered = ref.watch(filteredPoisProvider);
    final regions = ref.watch(poiRegionsProvider);
    final activeRegion = ref.watch(poiRegionFilterProvider);

    // Nearby state
    final userPos = ref.watch(userPositionProvider);
    final nearbyPois = ref.watch(userNearbyPoisProvider);
    final isLocating = ref.watch(isLocatingProvider);
    final locationError = ref.watch(locationErrorProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text('景点机位'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Mode toggle
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('浏览')),
                ButtonSegment(value: true, label: Text('附近')),
              ],
              selected: {nearbyMode},
              onSelectionChanged: (sel) {
                ref.read(nearbyModeProvider.notifier).state = sel.first;
                if (sel.first && userPos == null) {
                  fetchUserLocation(ref);
                }
              },
              style: ButtonStyle(
                textStyle: MaterialStateProperty.all(
                    const TextStyle(fontSize: 12)),
                backgroundColor:
                    MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
                    return Colors.amber.withOpacity(0.15);
                  }
                  return Colors.transparent;
                }),
                foregroundColor:
                    MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
                    return Colors.amber;
                  }
                  return Colors.white38;
                }),
              ),
            ),
          ),
        ],
      ),
      body: loader.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Colors.amber, strokeWidth: 2))
          : nearbyMode
              ? _buildNearbyView(
                  context, ref, isLocating, locationError,
                  userPos, nearbyPois)
              : _buildBrowseView(
                  context, ref, filtered, regions, activeRegion),
    );
  }

  Widget _buildNearbyView(
    BuildContext context,
    WidgetRef ref,
    bool isLocating,
    String? error,
    dynamic userPos,
    List<PhotoSpot> nearbyPois,
  ) {
    if (isLocating) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.amber, strokeWidth: 2),
            SizedBox(height: 12),
            Text('正在获取位置...',
                style: TextStyle(color: Colors.white54, fontSize: 14)),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            Text(error, style: const TextStyle(color: Colors.white38)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => fetchUserLocation(ref),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('重试'),
              style: TextButton.styleFrom(foregroundColor: Colors.amber),
            ),
          ],
        ),
      );
    }

    if (userPos == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_outlined,
                color: Colors.white.withOpacity(0.2), size: 56),
            const SizedBox(height: 12),
            Text(
              '查看附近的拍照机位',
              style: TextStyle(color: Colors.white.withOpacity(0.35)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => fetchUserLocation(ref),
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('获取当前位置'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.withOpacity(0.15),
                foregroundColor: Colors.amber,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    if (nearbyPois.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.place_outlined,
                color: Colors.white.withOpacity(0.2), size: 48),
            const SizedBox(height: 12),
            Text(
              '100km 范围内暂无收录的拍照机位',
              style: TextStyle(color: Colors.white.withOpacity(0.4)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.my_location, color: Colors.amber, size: 16),
              const SizedBox(width: 6),
              Text(
                '附近 ${nearbyPois.length} 个拍照机位',
                style: const TextStyle(color: Colors.amber, fontSize: 13),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => fetchUserLocation(ref),
                child: const Icon(Icons.refresh, color: Colors.white38, size: 18),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: nearbyPois.length,
            itemBuilder: (context, index) {
              final poi = nearbyPois[index];
              final dist = poi.distanceKm(userPos.lat, userPos.lon);
              final bearing = bearingTo(
                  userPos.lat, userPos.lon, poi.latitude, poi.longitude);
              return _NearbyPoiCard(
                poi: poi,
                distanceKm: dist,
                arrow: bearingToArrow(bearing),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PoiDetailPage(poi: poi),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBrowseView(
    BuildContext context,
    WidgetRef ref,
    List<PhotoSpot> filtered,
    List<String> regions,
    String? activeRegion,
  ) {
    return Column(
      children: [
        // Region filter chips
        _RegionBar(
          regions: regions,
          activeRegion: activeRegion,
          onSelect: (r) {
            ref.read(poiRegionFilterProvider.notifier).state = r;
          },
        ),
        // POI list
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    '暂无景点数据',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 14,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final poi = filtered[index];
                    return _PoiCard(
                      poi: poi,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PoiDetailPage(poi: poi),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Horizontal scrollable region filter bar.
class _RegionBar extends StatelessWidget {
  final List<String> regions;
  final String? activeRegion;
  final ValueChanged<String?> onSelect;

  const _RegionBar({
    required this.regions,
    required this.activeRegion,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: regions.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final region = isAll ? null : regions[index - 1];
          final label = isAll ? '全部' : region!;
          final isActive =
              isAll ? activeRegion == null : activeRegion == region;
          return _FilterChip(
            label: label,
            isActive: isActive,
            onTap: () => onSelect(region),
          );
        },
      ),
    );
  }
}

/// Card with distance + direction arrow for nearby mode.
class _NearbyPoiCard extends StatelessWidget {
  final PhotoSpot poi;
  final double distanceKm;
  final String arrow;
  final VoidCallback onTap;

  const _NearbyPoiCard({
    required this.poi,
    required this.distanceKm,
    required this.arrow,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final distStr = distanceKm < 1
        ? '${(distanceKm * 1000).toInt()}m'
        : '${distanceKm.toStringAsFixed(1)}km';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Direction + distance
                Column(
                  children: [
                    Text(arrow,
                        style: const TextStyle(
                            color: Colors.amber, fontSize: 22)),
                    const SizedBox(height: 2),
                    Text(distStr,
                        style: TextStyle(
                            color: Colors.amber.withOpacity(0.7),
                            fontSize: 11)),
                  ],
                ),
                const SizedBox(width: 14),
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.place,
                      color: Colors.amber, size: 24),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              poi.nameZh,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 12),
                                const SizedBox(width: 2),
                                Text(
                                  poi.popularity.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${poi.city} · ${poi.region}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: Colors.white.withOpacity(0.3), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Single POI card in the browse list.
class _PoiCard extends StatelessWidget {
  final PhotoSpot poi;
  final VoidCallback onTap;

  const _PoiCard({required this.poi, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.place,
                      color: Colors.amber, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              poi.nameZh,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 12),
                                const SizedBox(width: 2),
                                Text(
                                  poi.popularity.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${poi.city} · ${poi.region}  |  ${poi.bestTime}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      if (poi.tags.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: poi.tags
                              .take(3)
                              .map((t) => _MiniTag(label: t))
                              .toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right,
                    color: Colors.white.withOpacity(0.3), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  const _MiniTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 10),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.amber.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? Colors.amber : Colors.white10,
            width: isActive ? 1.5 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.amber : Colors.white70,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
