import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../camera/domain/providers.dart';
import '../../../camera/domain/services/camera_params_service.dart';

/// Floating camera parameter card displayed on the camera view.
///
/// Shows the recommended camera settings based on the current scene and active pose.
/// Toggles between beginner (mode suggestions) and advanced (specific values) views.
class CameraParamsCard extends ConsumerStatefulWidget {
  const CameraParamsCard({super.key});

  @override
  ConsumerState<CameraParamsCard> createState() => _CameraParamsCardState();
}

class _CameraParamsCardState extends ConsumerState<CameraParamsCard> {
  bool _showAdvanced = false;

  void _toggleMode() {
    setState(() {
      _showAdvanced = !_showAdvanced;
    });
  }

  @override
  Widget build(BuildContext context) {
    final params = ref.watch(cameraParamsRecommendationProvider);

    if (params == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _toggleMode,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: _showAdvanced ? 170 : 120,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _modeColor(params.recommendedMode).withOpacity(0.5),
          ),
        ),
        child: _showAdvanced
            ? _buildAdvancedView(params)
            : _buildBeginnerView(params),
      ),
    );
  }

  Widget _buildBeginnerView(CameraParamsRecommendation params) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('CAMERA', Icons.camera_alt_outlined),
        const SizedBox(height: 6),
        _beginnerRow('模式', _modeLabel(params.recommendedMode)),
        _beginnerRow('HDR', params.hdrAdvice.toUpperCase()),
        _beginnerRow('闪光灯', _flashLabel(params.flashAdvice)),
        const SizedBox(height: 6),
        Text(
          '点击查看专业参数 →',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 9,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedView(CameraParamsRecommendation params) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('PRO', Icons.tune),
        const SizedBox(height: 6),
        _advancedRow('ISO', '${params.iso}'),
        _advancedRow('快门', params.shutterSpeed),
        _advancedRow('光圈', 'f/${params.aperture.toStringAsFixed(1)}'),
        _advancedRow('EV', '${params.evCompensation >= 0 ? "+" : ""}${params.evCompensation.toStringAsFixed(1)}'),
        _advancedRow('WB', '${params.whiteBalance}K'),
        _advancedRow('测光', _meteringLabel(params.meteringMode)),
        _advancedRow('对焦', _focusLabel(params.focusMode, params.focusPoint)),
        if (params.rawRecommended)
          const _AdvancedRow(label: 'RAW', value: 'ON', accent: true),
        const SizedBox(height: 4),
        Text(
          '点击返回简化模式 →',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 9,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.amber.withOpacity(0.9)),
        const SizedBox(width: 4),
        Text(
          title,
          style: TextStyle(
            color: Colors.amber.withOpacity(0.9),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _beginnerRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _advancedRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 9),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Color _modeColor(String mode) {
    switch (mode) {
      case 'portrait':
        return Colors.purpleAccent;
      case 'night':
        return Colors.blueAccent;
      case 'hdr':
        return Colors.amber;
      default:
        return Colors.white38;
    }
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case 'portrait':
        return '人像';
      case 'night':
        return '夜景';
      case 'hdr':
        return 'HDR';
      case 'photo':
        return '标准';
      default:
        return mode;
    }
  }

  String _flashLabel(String flash) {
    switch (flash) {
      case 'on':
        return '开启';
      case 'off':
        return '关闭';
      case 'fill':
        return '补光';
      default:
        return flash;
    }
  }

  String _meteringLabel(String metering) {
    switch (metering) {
      case 'spot':
        return '点测光';
      case 'center':
        return '中央重点';
      case 'matrix':
        return '矩阵';
      default:
        return metering;
    }
  }

  String _focusLabel(String mode, String point) {
    final modeStr = mode == 'af-c' ? '连续' : '单次';
    final pointStr = point == 'eye' ? '眼部' : (point == 'face' ? '面部' : point);
    return '$modeStr/$pointStr';
  }
}

class _AdvancedRow extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;

  const _AdvancedRow({
    required this.label,
    required this.value,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 9),
          ),
          Text(
            value,
            style: TextStyle(
              color: accent ? Colors.amber : Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
