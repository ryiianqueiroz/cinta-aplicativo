import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
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
import 'package:firebase_messaging/firebase_messaging.dart';

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

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("📨 Mensagem em segundo plano: ${message.messageId}");
}

void setupFirebaseMessaging() async {
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Solicitar permissão (iOS)
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();

  // Obter token do dispositivo
  final token = await messaging.getToken();
  print("🔑 Token FCM: $token");

  // Quando o app está em primeiro plano
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      flutterLocalNotificationsPlugin.show(
        0,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails('channel_id', 'Alerta'),
        ),
      );
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "chave.env");
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
  
  await Firebase.initializeApp();
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
      body: Center(
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Bem-vindo ao ESP32 App'),
          SizedBox(height: 20),
          Image.asset('assets/logo.png'),
        ],
      ),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  final TextEditingController email = TextEditingController();
  final TextEditingController senha = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
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
                  fillColor: Colors.grey[100],
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
                  fillColor: Colors.grey[100],
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
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(5), // Adjust the margin value as needed
                child: SizedBox(
                  width: 70.0, // Adjust the width as needed
                  height: 50.0, // Adjust the height as needed
                  child: Image.asset(
                    "assets/logo.png",
                    fit: BoxFit.fill, // Or other BoxFit options like BoxFit.cover, BoxFit.fitWidth, etc.
                  ),
                ),
              ),
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
        fillColor: Colors.grey[100],
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
  final flutterReactiveBle = FlutterReactiveBle();
  late Stream<DiscoveredDevice> scanStream;
  List<DiscoveredDevice> dispositivos = [];

  @override
  void initState() {
    super.initState();
    iniciarScan();
  }

  void iniciarScan() {
    scanStream = flutterReactiveBle.scanForDevices(withServices: []);
    scanStream.listen((device) {
      if (!dispositivos.any((d) => d.id == device.id)) {
        setState(() {
          dispositivos.add(device);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F2FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text("Emparelhar Cinta"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.bluetooth_searching, size: 80, color: Color(0xFF7E22CE)),
            const SizedBox(height: 16),
            const Text(
              "Procurando dispositivos...",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4B0082),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: dispositivos.length,
                itemBuilder: (context, index) {
                  final device = dispositivos[index];
                  return Card(
                    child: ListTile(
                      title: Text(device.name.isNotEmpty ? device.name : "Dispositivo sem nome"),
                      subtitle: Text(device.id),
                      onTap: () {
                        // 👉 Navegar para a WifiCredentialsScreen passando o deviceId
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WifiCredentialsScreen(deviceId: device.id),
                          ),
                        );
                      },
                    ),
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

class WifiCredentialsScreen extends StatefulWidget {
  final String deviceId;

  WifiCredentialsScreen({required this.deviceId});

  @override
  _WifiCredentialsScreenState createState() => _WifiCredentialsScreenState();
}

class _WifiCredentialsScreenState extends State<WifiCredentialsScreen> {
  final TextEditingController ssidController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();
  final flutterReactiveBle = FlutterReactiveBle();

  bool enviando = false;

  Future<void> conectarEEnviar(String ssid, String senha) async {
    final serviceUuid = Uuid.parse("12345678-1234-1234-1234-1234567890ab");
    final ssidCharUuid = Uuid.parse("abcd1234-1111-1111-1111-abcdef123456");
    final passCharUuid = Uuid.parse("abcd1234-2222-2222-2222-abcdef123456");

    setState(() => enviando = true);

    try {
      final connection = flutterReactiveBle.connectToDevice(id: widget.deviceId);
      await connection.first;

      final ssidChar = QualifiedCharacteristic(
        deviceId: widget.deviceId,
        serviceId: serviceUuid,
        characteristicId: ssidCharUuid,
      );
      final passChar = QualifiedCharacteristic(
        deviceId: widget.deviceId,
        serviceId: serviceUuid,
        characteristicId: passCharUuid,
      );

      await flutterReactiveBle.writeCharacteristicWithResponse(
        ssidChar,
        value: utf8.encode(ssid),
      );
      await flutterReactiveBle.writeCharacteristicWithResponse(
        passChar,
        value: utf8.encode(senha),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Dados enviados com sucesso!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Erro ao enviar dados: $e")),
      );
    } finally {
      setState(() => enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F2FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text("Pareando Cinta"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.wifi, size: 80, color: Color(0xFF7E22CE)),
            const SizedBox(height: 16),
            const Text(
              "Conectar ao Wi-Fi",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4B0082),
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: ssidController,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                labelText: "SSID",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: senhaController,
              obscureText: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                labelText: "Senha",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: enviando
                  ? null
                  : () async {
                      await conectarEEnviar(
                        ssidController.text.trim(),
                        senhaController.text.trim(),
                      );
                    },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF7E22CE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: enviando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Finalizar",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
