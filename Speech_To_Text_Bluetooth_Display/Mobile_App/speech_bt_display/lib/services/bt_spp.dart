/// Bluetooth Classic SPP client (HC-05). The Android side is MainActivity.kt.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../protocol/frames.dart';

class BtDevice {
  final String name;
  final String address;
  final bool bonded;
  const BtDevice(this.name, this.address, this.bonded);
  String get label => name.isEmpty ? address : name;
}

class BtSpp {
  static const _m = MethodChannel('bt_spp/methods');
  static const _e = EventChannel('bt_spp/events');

  final _connected = StreamController<bool>.broadcast();
  final _found = StreamController<BtDevice>.broadcast();
  final _lines = StreamController<String>.broadcast();
  final _discoveryDone = StreamController<void>.broadcast();
  StreamSubscription? _sub;
  final _rx = StringBuffer();

  bool isConnected = false;
  BtDevice? device;

  Stream<bool> get connection => _connected.stream;
  Stream<BtDevice> get found => _found.stream;
  Stream<String> get replies => _lines.stream; // "ACK 01", "PONG 1.0", ...
  Stream<void> get discoveryFinished => _discoveryDone.stream;

  void start() {
    _sub ??= _e.receiveBroadcastStream().listen((dynamic ev) {
      final m = Map<String, dynamic>.from(ev as Map);
      switch (m['type']) {
        case 'state':
          isConnected = m['connected'] == true;
          _connected.add(isConnected);
          break;
        case 'data':
          _rx.write(latin1.decode(m['bytes'] as Uint8List));
          var s = _rx.toString();
          int i;
          while ((i = s.indexOf('\n')) >= 0) {
            final line = s.substring(0, i).trim();
            if (line.isNotEmpty) _lines.add(line);
            s = s.substring(i + 1);
          }
          _rx
            ..clear()
            ..write(s);
          break;
        case 'found':
          _found.add(BtDevice(m['name'] as String? ?? '', m['address'] as String, m['bonded'] == true));
          break;
        case 'discovery_finished':
          _discoveryDone.add(null);
          break;
      }
    });
  }

  /// Android 12+: BLUETOOTH_SCAN + BLUETOOTH_CONNECT. Android <= 11: location for scanning.
  Future<bool> ensurePermissions({bool scan = false}) async {
    if (!Platform.isAndroid) return false;
    final perms = <Permission>[Permission.bluetoothConnect];
    if (scan) perms.addAll([Permission.bluetoothScan, Permission.locationWhenInUse]);
    final res = await perms.request();
    // locationWhenInUse is only needed (and only granted) on old Android versions.
    return res[Permission.bluetoothConnect]!.isGranted &&
        (!scan || res[Permission.bluetoothScan]!.isGranted || res[Permission.locationWhenInUse]!.isGranted);
  }

  Future<bool> isEnabled() async => await _m.invokeMethod<bool>('isEnabled') ?? false;

  Future<List<BtDevice>> bonded() async {
    final list = await _m.invokeListMethod<Map>('bondedDevices') ?? [];
    return list.map((d) => BtDevice(d['name'] as String? ?? '', d['address'] as String, true)).toList();
  }

  Future<void> startDiscovery() => _m.invokeMethod('startDiscovery');
  Future<void> cancelDiscovery() => _m.invokeMethod('cancelDiscovery');
  Future<bool> bond(String address) async => await _m.invokeMethod<bool>('bond', {'address': address}) ?? false;
  Future<void> openSettings() => _m.invokeMethod('openSettings');

  Future<void> connect(BtDevice d) async {
    await _m.invokeMethod('connect', {'address': d.address});
    device = d;
  }

  Future<void> disconnect() async {
    await _m.invokeMethod('disconnect');
  }

  Future<void> write(Uint8List bytes) => _m.invokeMethod('write', {'bytes': bytes});

  /// Sends frames with a short pause between them. At 9600 baud a 100-byte frame takes
  /// ~105 ms on the wire; the pause keeps the ATmega's 128-byte receive buffer from
  /// overflowing while it is drawing on the LCD.
  Future<void> sendFrames(List<Uint8List> frames, {Duration gap = const Duration(milliseconds: 150)}) async {
    for (final f in frames) {
      await write(f);
      await Future.delayed(gap + Duration(milliseconds: f.length * 11 ~/ 10));
    }
  }

  Future<void> clearDisplay() => write(frame(Msg.clear));

  void dispose() {
    _sub?.cancel();
    _connected.close();
    _found.close();
    _lines.close();
    _discoveryDone.close();
  }
}
