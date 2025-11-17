// lib/services/bluetooth_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

class BleConnectResult {
  final bool ready;
  const BleConnectResult({required this.ready});
}

class MyBluetoothService {
  // --- 아두이노(하드웨어)에서 설정한 UUID와 일치해야 합니다 ---
  static const String _serviceUUID = "19B10000-E8F2-537E-4F6C-D104768A1214";
  static const String _ctrlUUID = "19B10001-E8F2-537E-4F6C-D104768A1214";
  // --- ---

  fbp.BluetoothDevice? connectedDevice;
  fbp.BluetoothCharacteristic? _ctrl;
  int _state = 0; // bit0: sound, bit1: light (하드웨어와 약속된 값)

  Stream<List<fbp.ScanResult>> startScan() {
    fbp.FlutterBluePlus.stopScan();
    fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    return fbp.FlutterBluePlus.scanResults;
  }

  Future<void> stopScan() async {
    try {
      await fbp.FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  Future<BleConnectResult> connect(fbp.BluetoothDevice device) async {
    try {
      await stopScan(); 
      await device.connect(autoConnect: false);
      connectedDevice = device;
      
      await _discover();
      
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
    _ctrl = null;
    if (connectedDevice == null) return;
    
    final svcs = await connectedDevice!.discoverServices();
    
    for (final s in svcs) {
      if (s.uuid.toString().toUpperCase() == _serviceUUID) {
        for (final c in s.characteristics) {
          final id = c.uuid.toString().toUpperCase();
          if (id == _ctrlUUID) {
            _ctrl = c;
            debugPrint("제어 특성(_ctrl) 찾음!");
          }
        }
        break;
      }
    }
  }

  bool get ready => _ctrl != null;
  bool get soundOn => (_state & 0x01) != 0;
  bool get lightOn => (_state & 0x02) != 0;

  Future<bool> _writeState() async {
    if (_ctrl == null) return false;
    final useNR =
        _ctrl!.properties.writeWithoutResponse && !_ctrl!.properties.write;
    try {
      await _ctrl!.write([_state & 0xFF], withoutResponse: useNR);
      return true;
    } catch (e) {
      debugPrint("write 실패: $e");
      return false;
    }
  }

  Future<bool> toggleSound(bool on) async {
    _state = on ? (_state | 0x01) : (_state & ~0x01);
    return _writeState();
  }

  Future<bool> toggleLight(bool on) async {
    _state = on ? (_state | 0x02) : (_state & ~0x02);
    return _writeState();
  }

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