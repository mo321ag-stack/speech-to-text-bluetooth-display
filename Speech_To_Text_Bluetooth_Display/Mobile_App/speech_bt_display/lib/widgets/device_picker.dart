import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../i18n.dart';
import '../services/bt_spp.dart';

/// Paired devices + scan for new ones + pairing.
class DevicePicker extends StatefulWidget {
  final BtSpp bt;
  final S s;
  const DevicePicker({super.key, required this.bt, required this.s});
  @override
  State<DevicePicker> createState() => _DevicePickerState();
}

class _DevicePickerState extends State<DevicePicker> {
  List<BtDevice> paired = [];
  final nearby = <String, BtDevice>{};
  bool scanning = false;
  final subs = <StreamSubscription>[];

  @override
  void initState() {
    super.initState();
    _loadPaired();
    subs.add(widget.bt.found.listen((d) => setState(() => nearby[d.address] = d)));
    subs.add(widget.bt.discoveryFinished.listen((_) {
      setState(() => scanning = false);
      _loadPaired();
    }));
  }

  @override
  void dispose() {
    for (final x in subs) {
      x.cancel();
    }
    if (scanning) widget.bt.cancelDiscovery();
    super.dispose();
  }

  Future<void> _loadPaired() async {
    final list = await widget.bt.bonded();
    list.sort((a, b) => (b.name.toUpperCase().contains('HC-0') ? 1 : 0) - (a.name.toUpperCase().contains('HC-0') ? 1 : 0));
    if (mounted) setState(() => paired = list);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final unpaired = nearby.values.where((d) => !paired.any((p) => p.address == d.address)).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(s.pairHelp),
            const SizedBox(height: 12),
            Text(s.pairedDevices, style: Theme.of(context).textTheme.titleSmall),
            for (final d in paired)
              ListTile(
                leading: Icon(Icons.bluetooth, color: d.name.toUpperCase().contains('HC-0') ? Colors.lightBlueAccent : null),
                title: Text(d.label),
                subtitle: Text(d.address),
                onTap: () => Navigator.pop(context, d),
              ),
            const Divider(),
            Row(
              children: [
                Expanded(child: Text(s.nearbyDevices, style: Theme.of(context).textTheme.titleSmall)),
                TextButton.icon(
                  onPressed: scanning
                      ? null
                      : () async {
                          setState(() {
                            scanning = true;
                            nearby.clear();
                          });
                          await widget.bt.startDiscovery();
                        },
                  icon: scanning
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search),
                  label: Text(scanning ? s.scanning : s.scan),
                ),
              ],
            ),
            for (final d in unpaired)
              ListTile(
                leading: const Icon(Icons.bluetooth_searching),
                title: Text(d.label),
                subtitle: Text(d.address),
                trailing: OutlinedButton(onPressed: () => widget.bt.bond(d.address), child: Text(s.pair)),
              ),
            const SizedBox(height: 8),
            TextButton.icon(onPressed: widget.bt.openSettings, icon: const Icon(Icons.settings_bluetooth), label: Text(s.btSettings)),
          ],
        ),
      ),
    );
  }
}
