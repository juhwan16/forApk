// lib/screens/detail.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:smart_extinguisher_app/models/fire_extinguisher.dart';
import 'package:smart_extinguisher_app/utils/http_helper.dart';
import 'package:smart_extinguisher_app/services/bluetooth_service.dart';

class DetailScreen extends StatefulWidget {
  final FireExtinguisher extinguisher;

  const DetailScreen({super.key, required this.extinguisher});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _connecting = false;
  StreamSubscription<List<ScanResult>>? _scanSub;

  @override
  void dispose() {
    _scanSub?.cancel();
    myBleService.disconnect();
    super.dispose();
  }

  Future<void> _updateExtinguisher(Map<String, dynamic> patch) async {
    try {
      final res = await httpPut(
        '/api/v1/extinguishers/${widget.extinguisher.id}',
        patch,
        context: context,
        auth: true,
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

  // ---------------- 블루투스 스캔/연결 ----------------

  Future<void> _showDevicePicker() async {
    setState(() => _connecting = true);

    final results = <ScanResult>[];

    _scanSub = myBleService.startScan().listen((list) {
      results
        ..clear()
        ..addAll(list);
      setState(() {});
    });

    await Future.delayed(const Duration(seconds: 4));
    await myBleService.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;

    if (!mounted) return;
    setState(() => _connecting = false);

    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('주변에서 블루투스 기기를 찾지 못했습니다.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<ScanResult>(
      context: context,
      builder: (context) {
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final r = results[index];
            return ListTile(
              title: Text(
                r.device.platformName.isEmpty
                    ? '(이름 없음)'
                    : r.device.platformName,
              ),
              subtitle: Text(r.device.remoteId.str),
              onTap: () => Navigator.pop(context, r),
            );
          },
        );
      },
    );

    if (selected == null) return;

    final result = await myBleService.connect(selected.device);

    if (!mounted) return;

    if (result.ready) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '하드웨어 연결됨: ${selected.device.platformName.isEmpty ? '(이름 없음)' : selected.device.platformName}',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기기 연결에 실패했습니다.')),
      );
    }
  }

  Future<void> _disconnectHardware() async {
    await myBleService.disconnect();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('블루투스 연결이 해제되었습니다.')),
    );
    setState(() {});
  }

  // ---------------- ON / OFF 명령 ----------------
  // 비트 매핑 (bluetooth_service.dart 기준)
  // bit0: sound1  → toggleFlag0
  // bit1: light1  → toggleFlag1

  Future<void> _setLight(bool on) async {
    await _updateExtinguisher({'isLightOn': on});
    if (myBleService.ready) {
      await myBleService.toggleFlag1(on);
    }
  }

  Future<void> _setSound(bool on) async {
    await _updateExtinguisher({'isSoundOn': on});
    if (myBleService.ready) {
      await myBleService.toggleFlag0(on);
    }
  }

  Future<void> _allOff() async {
    await _updateExtinguisher({'isLightOn': false, 'isSoundOn': false});
    if (myBleService.ready) {
      await myBleService.turnAllOff();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            // 항상 같은 고정 이미지
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/fire_detail.png',
                height: 200,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
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
                      myBleService.ready
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color: myBleService.ready ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        myBleService.ready
                            ? '블루투스 연결됨 (${myBleService.connectedDevice?.platformName ?? '알 수 없음'})'
                            : _connecting
                                ? '주변 기기 검색 중...'
                                : '블루투스 기기를 검색하여 연결할 수 있습니다.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    myBleService.ready
                        ? TextButton(
                            onPressed: _disconnectHardware,
                            child: const Text('연결 해제'),
                          )
                        : TextButton(
                            onPressed: _connecting ? null : _showDevicePicker,
                            child: const Text('기기 검색'),
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 불빛 ON / OFF (버튼 클릭 → 즉시 신호 전송, 상태 유지 X)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('불빛', style: theme.textTheme.titleMedium),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => _setLight(true),
                      child: const Text('ON'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _setLight(false),
                      child: const Text('OFF'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 소리 ON / OFF
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('소리', style: theme.textTheme.titleMedium),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => _setSound(true),
                      child: const Text('ON'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _setSound(false),
                      child: const Text('OFF'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),

            // 모두 끄기 버튼
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _allOff,
                icon: const Icon(Icons.power_settings_new),
                label: const Text('불빛·소리 모두 끄기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.errorContainer,
                  foregroundColor: theme.colorScheme.onErrorContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
