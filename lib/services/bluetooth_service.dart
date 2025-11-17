// lib/services/bluetooth_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

/// 연결 결과: 제어용 characteristic까지 준비되었는지 여부
class BleConnectResult {
  final bool ready;
  const BleConnectResult({required this.ready});
}

class MyBluetoothService {
  // --- UUID (Arduino 스케치와 반드시 동일해야 함) ---
  static const String _serviceUUID = "19B10000-E8F2-537E-4F6C-D104768A1214";
  static const String _ctrlUUID    = "19B10001-E8F2-537E-4F6C-D104768A1214";
  // -------------------------------------------------

  fbp.BluetoothDevice? connectedDevice;
  fbp.BluetoothCharacteristic? _ctrl;

  // 4개의 기능 → bit0~bit3
  // bit0: sound1
  // bit1: light1
  // bit2: sound2 (확장용)
  // bit3: light2 (확장용)
  int _state = 0;

  // 여러 번 연속 write할 때 충돌 방지용 플래그
  bool _isWriting = false;

  // ================== 스캔 ==================

  /// 주변 BLE 기기를 스캔하고 결과 스트림을 반환
  Stream<List<fbp.ScanResult>> startScan() {
    // 혹시 기존 스캔이 돌고 있으면 중단
    fbp.FlutterBluePlus.stopScan();
    fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    return fbp.FlutterBluePlus.scanResults;
  }

  Future<void> stopScan() async {
    try {
      await fbp.FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  // ================== 연결 ==================

  Future<BleConnectResult> connect(fbp.BluetoothDevice device) async {
    try {
      await stopScan();

      await device.connect(autoConnect: false);
      connectedDevice = device;

      await _discover();

      // 장치 쪽에서 현재 상태를 읽어올 수 있으면 한번 동기화
      if (_ctrl != null && _ctrl!.properties.read) {
        final v = await _ctrl!.read();
        if (v.isNotEmpty) _state = v.first;
      }

      return BleConnectResult(ready: _ctrl != null);
    } catch (e) {
      debugPrint("연결 실패: $e");
      connectedDevice = null;
      _ctrl = null;
      _state = 0;
      return const BleConnectResult(ready: false);
    }
  }

  Future<void> _discover() async {
    if (connectedDevice == null) return;

    _ctrl = null;
    final svcs = await connectedDevice!.discoverServices();

    for (final s in svcs) {
      if (s.uuid.toString().toUpperCase() == _serviceUUID) {
        for (final c in s.characteristics) {
          if (c.uuid.toString().toUpperCase() == _ctrlUUID) {
            _ctrl = c;
            debugPrint("제어 characteristic 발견");
          }
        }
      }
    }
  }

  bool get ready => _ctrl != null;

  // ================== 상태 조회 (비트 플래그) ==================

  bool get flag0 => (_state & 0x01) != 0;
  bool get flag1 => (_state & 0x02) != 0;
  bool get flag2 => (_state & 0x04) != 0;
  bool get flag3 => (_state & 0x08) != 0;

  // ================== 내부 write 함수 ==================

  Future<bool> _writeState() async {
    if (_ctrl == null) return false;

    // 동시에 두 번 write되지 않도록 간단한 락
    if (_isWriting) {
      debugPrint("쓰기 경합 발생 → 50ms 대기");
      await Future.delayed(const Duration(milliseconds: 50));

      if (_isWriting) {
        debugPrint("여전히 쓰기 중이어서 이번 write는 취소");
        return false;
      }
    }

    _isWriting = true;
    debugPrint("BLE Write 시작 (state=0b${_state.toRadixString(2)})");

    final useNR =
        _ctrl!.properties.writeWithoutResponse && !_ctrl!.properties.write;

    try {
      await _ctrl!.write([_state & 0xFF], withoutResponse: useNR);
      debugPrint("BLE Write 성공");
      return true;
    } catch (e) {
      debugPrint("BLE Write 실패: $e");
      return false;
    } finally {
      _isWriting = false;
    }
  }

  // ================== 비트 단위 토글 ==================

  Future<bool> toggleFlag0(bool on) async {
    _state = on ? (_state | 0x01) : (_state & ~0x01);
    return _writeState();
  }

  Future<bool> toggleFlag1(bool on) async {
    _state = on ? (_state | 0x02) : (_state & ~0x02);
    return _writeState();
  }

  Future<bool> toggleFlag2(bool on) async {
    _state = on ? (_state | 0x04) : (_state & ~0x04);
    return _writeState();
  }

  Future<bool> toggleFlag3(bool on) async {
    _state = on ? (_state | 0x08) : (_state & ~0x08);
    return _writeState();
  }

  // ================== 앱에서 쓰기 좋은 래퍼 ==================
  // Detail 화면 등에서 사용하는 메서드 이름을 여기에 맞춰 둔다.

  /// 불빛 제어 (현재 flag1 사용)
  Future<bool> toggleLight(bool on) => toggleFlag1(on);

  /// 소리 제어 (현재 flag0 사용)
  Future<bool> toggleSound(bool on) => toggleFlag0(on);

  /// 모두 끄기 (allOff / turnAllOff 둘 다 지원)
  Future<bool> allOff() => turnAllOff();

  Future<bool> turnAllOff() async {
    _state = 0;
    return _writeState();
  }

  // ================== 연결 해제 ==================

  Future<void> disconnect() async {
    try {
      await stopScan();
      await connectedDevice?.disconnect();
    } catch (_) {}
    connectedDevice = null;
    _ctrl = null;
    _state = 0;
  }
}

/// 앱 전체에서 공유해서 쓰는 전역 인스턴스
final myBleService = MyBluetoothService();
