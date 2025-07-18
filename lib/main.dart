import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Serviço MQTT
class MqttService {
  final String username = "yiaan";
  final String aioKey = dotenv.env['AIO_KEY'] ?? '';

  late MqttServerClient client;

  MqttService() {
    final clientId = 'flutter_client_$username';
    client = MqttServerClient.withPort('io.adafruit.com', clientId, 8883);
    client.secure = true;
    client.securityContext = SecurityContext.defaultContext;
    client.setProtocolV311();
    client.keepAlivePeriod = 20;
    client.logging(on: true);
    client.onDisconnected = onDisconnected;
  }

  Future<void> connectAndListen(Function(String) onMessage) async {
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(client.clientIdentifier)
        .startClean()
        .authenticateAs(username, aioKey);

    try {
      await client.connect().timeout(const Duration(seconds: 10));
    } catch (e) {
      print('Erro ao conectar: $e');
      client.disconnect();
      return;
    }

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      print('✅ Conectado ao broker');
      final topic = '$username/feeds/alerta';
      client.subscribe(topic, MqttQos.atMostOnce);

      client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> event) {
        final recMess = event[0].payload as MqttPublishMessage;
        final msg =
            MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        print('📥 Mensagem recebida: $msg');
        onMessage(msg);
      });
    } else {
      print('❌ Falha ao conectar: ${client.connectionStatus?.state}');
      client.disconnect();
    }
  }

  void onDisconnected() {
    print('🔌 Desconectado do broker');
  }
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final flutterReactiveBle = FlutterReactiveBle();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(); 
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  final settings = InitializationSettings(android: android);

  await flutterLocalNotificationsPlugin.initialize(
    settings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      runApp(MyApp(navigateTo: '/alerta'));
    },
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final String? navigateTo;
  MyApp({this.navigateTo});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 App',
      debugShowCheckedModeBanner: false,
      initialRoute: navigateTo ?? '/',
      routes: {
        '/': (_) => SplashScreen(),
        '/login': (_) => LoginScreen(),
        '/register': (_) => RegisterScreen(),
        '/home': (_) => HomeScreen(),
        '/pair': (_) => PairingScreen(),
        '/settings': (_) => SettingsScreen(),
        '/alerta': (_) => AlertaScreen(),
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Future.delayed(Duration(seconds: 2), () {
      Navigator.pushReplacementNamed(context, '/login');
    });

    return Scaffold(
      body: Center(child: Text('Bem-vindo ao ESP32 App')),
    );
  }
}

class LoginScreen extends StatelessWidget {
  final TextEditingController email = TextEditingController();
  final TextEditingController senha = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDD9A0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Your Logo", style: TextStyle(fontSize: 16)),
              const SizedBox(height: 30),
              const Text("Sign in to", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text("Lorem Ipsum is simply", style: TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text("If you don’t have an account register "),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/register');
                    },
                    child: const Text(
                      "Register here !",
                      style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Campo de email
              TextField(
                controller: email,
                decoration: InputDecoration(
                  hintText: "Enter email or user name",
                  fillColor: Colors.orange.shade100,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Campo de senha
              TextField(
                controller: senha,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: "Password",
                  suffixIcon: const Icon(Icons.visibility_off),
                  fillColor: Colors.orange.shade100,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text("Forgot password ?", style: TextStyle(fontSize: 12)),
                ),
              ),

              const SizedBox(height: 20),

              // Botão de login
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 6,
                  ),
                  child: const Text("Login", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),

              const SizedBox(height: 24),
              const Center(child: Text("or continue with")),
              const SizedBox(height: 20),

              // Redes sociais
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.facebook, size: 30, color: Colors.blue),
                  SizedBox(width: 20),
                  Icon(Icons.apple, size: 30),
                  SizedBox(width: 20),
                  Icon(Icons.g_mobiledata, size: 34, color: Colors.red),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatelessWidget {
  final TextEditingController email = TextEditingController();
  final TextEditingController username = TextEditingController();
  final TextEditingController contact = TextEditingController();
  final TextEditingController password = TextEditingController();
  final TextEditingController confirm = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDD9A0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Your Logo", style: TextStyle(fontSize: 16)),
              const SizedBox(height: 30),
              const Text("Sign in up", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text("Lorem Ipsum is simply", style: TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text("If you already have an account register "),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text("Login here !", style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              _buildInputField(email, "Enter Email"),
              const SizedBox(height: 12),
              _buildInputField(username, "Create User name"),
              const SizedBox(height: 12),
              _buildInputField(contact, "Contact number"),
              const SizedBox(height: 12),
              _buildInputField(password, "Password", isPassword: true),
              const SizedBox(height: 12),
              _buildInputField(confirm, "Confirm Password", isPassword: true),
              const SizedBox(height: 20),
              _buildButton("Register"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String hint, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        hintText: hint,
        fillColor: Colors.orange.shade100,
        filled: true,
        suffixIcon: isPassword ? const Icon(Icons.visibility_off) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildButton(String text) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 6,
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
    );
  }
}

class AlertaScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("⚠️ Alerta")),
      body: Center(
        child: Text(
          "Temperatura crítica detectada!",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Configurações")),
      body: ListView(
        children: [
          ListTile(title: Text("Alterar senha")),
          ListTile(title: Text("Tema escuro")),
          ListTile(
            title: Text("Sair"),
            onTap: () => Navigator.pushReplacementNamed(context, '/login'),
          ),
        ],
      ),
    );
  }
}

class PairingScreen extends StatefulWidget {
  @override
  _PairingScreenState createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  List<DiscoveredDevice> devices = [];
  late Stream<DiscoveredDevice> scanStream;
  bool scanning = false;

  @override
  void initState() {
    super.initState();
    checkPermissions();
  }

  Future<void> checkPermissions() async {
    await Permission.location.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
  }

  Future<void> conectarEEnviar(
    String deviceId,
    String ssid,
    String senha,
  ) async {
    final characteristic = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: Uuid.parse("12345678-1234-1234-1234-1234567890ab"), // UUID do serviço do ESP32
      characteristicId: Uuid.parse("abcd1234-1111-1111-1111-abcdef123456"), // UUID da característica WRITE
    );

    // Conectando ao dispositivo
    await flutterReactiveBle.connectToDevice(id: deviceId).first;

    // Escrevendo dados na característica
    await flutterReactiveBle.writeCharacteristicWithResponse(
      characteristic,
      value: utf8.encode("$ssid|$senha"),
    );
  }



  void startScan() {
    setState(() {
      devices.clear();
      scanning = true;
    });

    scanStream = flutterReactiveBle.scanForDevices(
      withServices: [],
      scanMode: ScanMode.lowLatency,
    );

    scanStream.listen((device) {
      print("📡 Dispositivo encontrado: ${device.name} - ${device.id}");
      if (!devices.any((d) => d.id == device.id)) {
        setState(() {
          devices.add(device);
        });
      }
    }, onDone: () {
      setState(() => scanning = false);
    }, onError: (e) {
      print("Erro ao escanear: $e");
      setState(() => scanning = false);
    });
  }

  void exibirDialogoWiFi(String deviceId) {
    final ssidController = TextEditingController();
    final senhaController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Enviar Wi-Fi para ESP32"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: ssidController, decoration: InputDecoration(labelText: "SSID")),
            TextField(controller: senhaController, decoration: InputDecoration(labelText: "Senha"), obscureText: true),
          ],
        ),
        actions: [
          TextButton(
            child: Text("Enviar"),
            onPressed: () async {
              Navigator.pop(context);
              await conectarEEnviar(deviceId, ssidController.text, senhaController.text);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Credenciais enviadas!")));
            },
          )
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Emparelhamento')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: scanning ? null : startScan,
            child: Text(scanning ? 'Escaneando...' : 'Buscar Dispositivos'),
          ),
          Expanded(
            child: devices.isEmpty
              ? Center(
                  child: Text(
                    scanning
                      ? '🔍 Procurando dispositivos BLE...'
                      : 'Nenhum dispositivo encontrado. Ligue sua ESP32 ou tente novamente.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return ListTile(
                      title: Text(device.name.isNotEmpty ? device.name : 'Dispositivo sem nome'),
                      subtitle: Text(device.id),
                      onTap: () {
                        // Mostra o diálogo para enviar SSID/Senha
                        final ssidController = TextEditingController();
                        final senhaController = TextEditingController();

                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text("Conectar ao Wi-Fi"),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                    controller: ssidController,
                                    decoration: InputDecoration(labelText: "SSID do Wi-Fi"),
                                  ),
                                  TextField(
                                    controller: senhaController,
                                    decoration: InputDecoration(labelText: "Senha do Wi-Fi"),
                                    obscureText: true,
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  child: Text("Enviar"),
                                  onPressed: () async {
                                    Navigator.of(context).pop();
                                    await conectarEEnviar(
                                      device.id,
                                      ssidController.text,
                                      senhaController.text,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Credenciais enviadas!")),
                                    );
                                  },
                                )
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              )
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String diaSelecionado = 'D';
  int alertasRecebidos = 0;
  final diasSemana = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
  int diaSelecionadoIndex = 0;
  final mqtt = MqttService();
  List<Map<String, String>> backlogAlertas = [];

  @override
  void initState() {
    super.initState();
    solicitarPermissaoNotificacao();
    buscarMensagensAnteriores();

    mqtt.connectAndListen((mensagem) {
      final agora = DateTime.now();
      final formatado = "${agora.day.toString().padLeft(2, '0')}/"
                        "${agora.month.toString().padLeft(2, '0')}/"
                        "${agora.year} - "
                        "${agora.hour.toString().padLeft(2, '0')}:"
                        "${agora.minute.toString().padLeft(2, '0')}";

      setState(() {
        alertasRecebidos++;
        backlogAlertas.insert(0, {
          "mensagem": mensagem,
          "data": formatado,
        });
      });

      flutterLocalNotificationsPlugin.show(
        0,
        '⚠️ Alerta da ESP32',
        mensagem,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'alert_channel',
            'Alertas da ESP32',
            channelDescription: 'Canal para notificações da ESP32',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    });
  }

  Future<void> buscarMensagensAnteriores() async {
    final url = Uri.parse('https://io.adafruit.com/api/v2/yiaan/feeds/alerta/data?limit=10');
    final response = await http.get(url, headers: {
      'X-AIO-Key': dotenv.env['AIO_KEY'] ?? '',
    });


    if (response.statusCode == 200) {
      final List<dynamic> dados = jsonDecode(response.body);

      setState(() {
        backlogAlertas = dados.map<Map<String, String>>((item) {
          final DateTime createdAt = DateTime.parse(item['created_at']);
          final dataFormatada = "${createdAt.day.toString().padLeft(2, '0')}/"
                                "${createdAt.month.toString().padLeft(2, '0')}/"
                                "${createdAt.year} - "
                                "${createdAt.hour.toString().padLeft(2, '0')}:"
                                "${createdAt.minute.toString().padLeft(2, '0')}";
          return {
            "mensagem": item['value'],
            "data": dataFormatada,
          };
        }).toList();
      });
    } else {
      print('Erro ao buscar histórico: ${response.statusCode}');
    }
  }

  Future<void> solicitarPermissaoNotificacao() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  Widget colunaIndicador(String label) {
    return Column(
      children: [
        CircleAvatar(radius: 18, backgroundColor: Colors.black),
        SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12))
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Tela Inicial"),
        actions: [
          IconButton(
            icon: Icon(Icons.bluetooth),
            onPressed: () => Navigator.pushNamed(context, '/pair'),
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Column(
          children: [
            SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Text(
                "Cinta está: Desconectada",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: diasSemana.asMap().entries.map((entry) {
                  final index = entry.key;
                  final dia = entry.value;
                  final selecionado = index == diaSelecionadoIndex;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        diaSelecionadoIndex = index;
                        alertasRecebidos = 0;
                        backlogAlertas.clear();
                      });
                    },
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: selecionado ? Colors.blue : Colors.grey.shade300,
                      child: Text(
                        dia,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: selecionado ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Column(
                children: [
                  Text(
                    "$alertasRecebidos",
                    style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Alertas recebidos",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      colunaIndicador("Temperatura"),
                      colunaIndicador("BPM"),
                      colunaIndicador("Passos"),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Text("📦 Histórico de Alertas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: backlogAlertas.length,
                itemBuilder: (context, index) {
                  final alerta = backlogAlertas[index];
                  return ListTile(
                    leading: Icon(Icons.warning_amber_rounded, color: Colors.red),
                    title: Text(alerta['mensagem'] ?? ''),
                    subtitle: Text(alerta['data'] ?? ''),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
