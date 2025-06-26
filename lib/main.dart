import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final flutterReactiveBle = FlutterReactiveBle();
  List<DiscoveredDevice> devices = [];
  late Stream<DiscoveredDevice> scanStream;
  bool scanning = false;

  @override
  void initState() {
    super.initState();
    checkPermissions();
  }

  Future<void> checkPermissions() async {
    if (await Permission.location.isDenied) {
      await Permission.location.request();
    }

    if (await Permission.bluetoothScan.isDenied) {
      await Permission.bluetoothScan.request();
    }

    if (await Permission.bluetoothConnect.isDenied) {
      await Permission.bluetoothConnect.request();
    }
  }

  void startScan() {
    setState(() {
      devices.clear();
      scanning = true;
    });

    scanStream = flutterReactiveBle.scanForDevices(
      withServices: [], // escaneia todos os dispositivos BLE
      scanMode: ScanMode.lowLatency,
    );

    scanStream.listen((device) {
      if (device.name.isNotEmpty && !devices.any((d) => d.id == device.id)) {
        setState(() {
          devices.add(device);
        });
      }
    }, onDone: () {
      setState(() {
        scanning = false;
      });
    }, onError: (error) {
      print("Erro ao escanear: $error");
      setState(() {
        scanning = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('BLE Scanner')),
        body: Column(
          children: [
            ElevatedButton(
              onPressed: scanning ? null : startScan,
              child: Text(scanning ? 'Escaneando...' : 'Buscar Dispositivos'),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];
                  return ListTile(
                    title: Text(device.name),
                    subtitle: Text(device.id),
                    onTap: () {
                      print("Selecionado: ${device.name} (${device.id})");
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
