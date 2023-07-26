import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:collection/collection.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 Voltage Reader',
      home: FindDevicesScreen(),
    );
  }
}

class FindDevicesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Find Devices'),
    ),
    body: RefreshIndicator(
      onRefresh: () => FlutterBlue.instance.startScan(timeout: Duration(seconds: 4)),
      child: SingleChildScrollView(
        child: StreamBuilder<List<ScanResult>>(
          stream: FlutterBlue.instance.scanResults,
          initialData: [],
          builder: (c, snapshot) => Column(
            children: snapshot.data!
                .map(
                  (r) => ScanResultTile(
                    result: r,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) {
                      r.device.connect();
                      return Scaffold(
                        appBar: AppBar(
                          title: Text('ESP32 Voltage Reader'),
                        ),
                        body: VoltageReaderScreen(device: r.device),
                      );
                    })),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    ),
    floatingActionButton: StreamBuilder<bool>(
      stream: FlutterBlue.instance.isScanning,
      initialData: false,
      builder: (c, snapshot) => FloatingActionButton(
        child: Icon(snapshot.data! ? Icons.stop : Icons.search),
        onPressed: snapshot.data! ? FlutterBlue.instance.stopScan : () => FlutterBlue.instance.startScan(timeout: Duration(seconds: 4)),
      ),
    ),
  );
}

class ScanResultTile extends StatelessWidget {
  const ScanResultTile({Key? key, required this.result, this.onTap}) : super(key: key);
  final ScanResult result;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Text(result.rssi.toString()),
      title: Text(result.device.name.length > 0 ? result.device.name : result.device.id.toString()),
      subtitle: Text(result.advertisementData.connectable ? 'Connectable' : 'Not connectable'),
    );
  }
}

class VoltageReaderScreen extends StatefulWidget {
  const VoltageReaderScreen({Key? key, required this.device}) : super(key: key);
  final BluetoothDevice device;

  @override
  _VoltageReaderScreenState createState() => _VoltageReaderScreenState();
}

class _VoltageReaderScreenState extends State<VoltageReaderScreen> {
  late List<int> voltages = List.filled(10, 0);

  @override
  void initState() {
    super.initState();
    widget.device.discoverServices().then((services) {
      var service = services.firstWhereOrNull(
          (s) => s.uuid.toString() == '4fafc201-1fb5-459e-8fcc-c5c9c331914b');
      if (service != null) {
        var characteristic = service.characteristics.firstWhereOrNull(
            (c) => c.uuid.toString() == 'beb5483e-36e1-4688-b7f5-ea07361b26a8');
        if (characteristic != null) {
          characteristic.setNotifyValue(true);
          characteristic.value.listen((data) {
            List<String> voltStrings = String.fromCharCodes(data).split(',');
            setState(() {
              voltages = voltStrings.map((voltString) => int.tryParse(voltString) ?? 0).toList();
            });
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: voltages.length,
      itemBuilder: (context, index) => ListTile(
        title: Text('Voltage ${index+1}: ${voltages[index]}'),
      ),
    );
  }
}
