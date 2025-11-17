// lib/screens/detail.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:smart_extinguisher_app/models/fire_extinguisher.dart';
import 'package:smart_extinguisher_app/utils/http_helper.dart';

class DetailScreen extends StatefulWidget {
  final FireExtinguisher extinguisher;

  const DetailScreen({super.key, required this.extinguisher});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late bool _isSoundOn;
  late bool _isLightOn;

  BluetoothDevice? _device;
  bool _connecting = false;
  bool _connected = false;
  StreamSubscription<List<ScanResult>>? _scanSub;
  List<ScanResult> _scanResults = [];

  @override
  void initState() {
    super.initState();
    _isSoundOn = widget.extinguisher.isSoundOn;
    _isLightOn = widget.extinguisher.isLightOn;
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _disconnectHardware();
    super.dispose();
  }

  // ---------------- 서버에 상태 PATCH ----------------
  Future<void> _updateExtinguisher(Map<String, dynamic> patch) async {
    try {
      final res = await httpPut(
        '/api/v1/extinguishers/${widget.extinguisher.id}',
        patch,
        context: context,
        auth: true, // 반드시 true
      );
      final data = jsonDecode(res.body);

      if (!(res.statusCode == 200 && data['ok'] == true)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '상태 변경 실패: ${data['error'] ?? data['detail'] ?? '알 수 없는 오류'}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e')),
      );
    }
  }

  // ---------------- 하드웨어로 명령 전송 ----------------
  Future<void> _sendCommand(String cmd) async {
    if (_device == null || !_connected) return;

    try {
      final services = await _device!.discoverServices();
      for (final s in services) {
        for (final c in s.characteristics) {
          if (c.properties.write || c.properties.writeWithoutResponse) {
            await c.write(
              utf8.encode(cmd),
              withoutResponse: c.properties.writeWithoutResponse,
            );
            return;
          }
        }
      }
    } catch (_) {
      // 조용히 무시
    }
  }

  // ---------------- 블루투스 스캔 + 디바이스 선택 ----------------
  Future<void> _selectAndConnectDevice() async {
    if (_connecting) return;

    setState(() {
      _connecting = true;
      _scanResults = [];
    });

    try {
      await FlutterBluePlus.stopScan();
      await _scanSub?.cancel();

      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        if (!mounted) return;
        setState(() {
          _scanResults = results;
        });
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
      await Future.delayed(const Duration(seconds: 5));
      await FlutterBluePlus.stopScan();
      await _scanSub?.cancel();

      if (!mounted) return;
      setState(() => _connecting = false);

      if (_scanResults.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('주변에서 기기를 찾지 못했습니다.')),
        );
        return;
      }

      // 기기 선택 바텀시트
      final selected = await showModalBottomSheet<ScanResult>(
        context: context,
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text('연결할 블루투스 기기를 선택하세요'),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: _scanResults.length,
                    itemBuilder: (context, index) {
                      final r = _scanResults[index];
                      final name =
                          r.device.platformName.isNotEmpty ? r.device.platformName : '알 수 없는 기기';
                      final id = r.device.remoteId.str;
                      return ListTile(
                        title: Text(name),
                        subtitle: Text(id),
                        onTap: () => Navigator.pop(ctx, r),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
        isScrollControlled: true,
      );

      if (selected == null) return;

      // 선택된 기기에 연결
      try {
        await selected.device.connect(timeout: const Duration(seconds: 5));
        if (!mounted) return;
        setState(() {
          _device = selected.device;
          _connected = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('하드웨어 연결됨: ${selected.device.platformName}')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('연결 실패: $e')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _connecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('블루투스 검색 실패: $e')),
      );
    }
  }

  Future<void> _disconnectHardware() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    try {
      await _scanSub?.cancel();
    } catch (_) {}

    if (_device != null) {
      try {
        await _device!.disconnect();
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _connected = false;
      _device = null;
    });
  }

  // ---------------- 토글 핸들러 ----------------
  Future<void> _toggleSound(bool value) async {
    setState(() => _isSoundOn = value);
    await _updateExtinguisher({'isSoundOn': value});
    await _sendCommand(value ? 'SOUND_ON' : 'SOUND_OFF');
  }

  Future<void> _toggleLight(bool value) async {
    setState(() => _isLightOn = value);
    await _updateExtinguisher({'isLightOn': value});
    await _sendCommand(value ? 'LIGHT_ON' : 'LIGHT_OFF');
  }

  String? _buildImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return '$imageRootUrl$path';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = _buildImageUrl(widget.extinguisher.imagePath);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.extinguisher.location.isEmpty
              ? '소화기 상세'
              : widget.extinguisher.location,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 이미지
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    alignment: Alignment.center,
                    color: theme.colorScheme.surfaceVariant,
                    child: const Text('이미지를 불러올 수 없습니다.'),
                  ),
                ),
              )
            else
              Container(
                height: 200,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('등록된 이미지가 없습니다.'),
              ),
            const SizedBox(height: 16),

            Text(
              '위치: ${widget.extinguisher.location.isEmpty ? '정보 없음' : widget.extinguisher.location}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              widget.extinguisher.expireDate.isEmpty
                  ? '사용 가능 기간: 정보 없음'
                  : '사용 가능 기간: ${widget.extinguisher.expireDate}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            // 블루투스 카드
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      _connected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color: _connected ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _connected
                            ? '블루투스 연결됨 (${_device?.platformName ?? '알 수 없음'})'
                            : _connecting
                                ? '주변 기기 검색 중...'
                                : '블루투스 기기를 검색하여 연결할 수 있습니다.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _connected
                        ? TextButton(
                            onPressed: _disconnectHardware,
                            child: const Text('연결 해제'),
                          )
                        : TextButton(
                            onPressed:
                                _connecting ? null : _selectAndConnectDevice,
                            child: const Text('기기 검색'),
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            SwitchListTile(
              title: const Text('불빛 ON / OFF'),
              value: _isLightOn,
              onChanged: _toggleLight,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('소리 ON / OFF'),
              value: _isSoundOn,
              onChanged: _toggleSound,
            ),
          ],
        ),
      ),
    );
  }
}
