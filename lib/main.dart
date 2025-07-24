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
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(initSettings);
  }

  static Future<void> showNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Alerta da Cinta',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      0,
      message.notification?.title ?? 'Alerta',
      message.notification?.body ?? '',
      notificationDetails,
    );
  }
}

// === MQTT Service ===
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
      print('Erro ao conectar MQTT: $e');
      client.disconnect();
      return;
    }

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      print('✅ Conectado ao broker MQTT');
      final topic = '$username/feeds/alerta';
      client.subscribe(topic, MqttQos.atMostOnce);

      client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> event) {
        final recMess = event[0].payload as MqttPublishMessage;
        final msg =
            MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        print('📥 Mensagem recebida MQTT: $msg');
        onMessage(msg);
      });
    } else {
      print('❌ Falha ao conectar MQTT: ${client.connectionStatus?.state}');
      client.disconnect();
    }
  }

  void onDisconnected() {
    print('🔌 Desconectado do broker MQTT');
  }
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// === Handler para mensagens em background do Firebase Messaging ===
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService.showNotification(message);
}

// === Main ===
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "chave.env");

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  final settings = InitializationSettings(android: android);

  await flutterLocalNotificationsPlugin.initialize(
    settings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // Navegar para alerta, por exemplo
      runApp(MyApp(navigateTo: '/alerta'));
    },
  );

  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(MyApp());
}

// === MyApp e Rotas ===
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

// === SplashScreen ===
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

// === LoginScreen ===
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

// === RegisterScreen ===
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
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: SizedBox(
                    width: 70.0,
                    height: 50.0,
                    child: Image.asset(
                      "assets/logo.png",
                      fit: BoxFit.fill,
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

// === AlertaScreen ===
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

// === SettingsScreen ===
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

// === PairingScreen ===
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

// === WifiCredentialsScreen ===
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
                  color: enviando ? Colors.grey : Color(0xFF7E22CE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    enviando ? "Enviando..." : "Enviar",
                    style: TextStyle(color: Colors.white, fontSize: 18),
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

// === HomeScreen com FCM e MQTT ===
class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _fcmToken;
  final MqttService mqttService = MqttService();
  List<String> mensagens = [];

  @override
  void initState() {
    super.initState();
    _initFCM();
    _connectMQTT();
  }

  Future<void> _initFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print("Permissão concedida para notificações");

      String? token = await messaging.getToken();
      print("🔑 Token FCM: $token");

      setState(() {
        _fcmToken = token;
      });

      if (token != null) {
        await _sendTokenToBackend(token);
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null) {
          flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                'alert_channel',
                'Alertas',
                channelDescription: 'Canal para notificações de alertas',
                importance: Importance.max,
                priority: Priority.high,
              ),
            ),
          );
        }
      });
    } else {
      print("Permissão negada para notificações");
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    final url = Uri.parse("http://192.168.18.183:4000/register-device-token");
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      );
      if (response.statusCode == 200) {
        print("✅ Token enviado para backend com sucesso");
      } else {
        print("❌ Erro ao enviar token: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Erro ao enviar token: $e");
    }
  }

  void _connectMQTT() {
    mqttService.connectAndListen((msg) {
      setState(() {
        mensagens.add(msg);
      });
      // Exibir notificação local
      flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'Alerta recebido',
        msg,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'alert_channel',
            'Alertas',
            channelDescription: 'Canal para notificações de alertas',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    });
  }

  // Exemplo para puxar mensagens anteriores via REST do Adafruit
  Future<List<String>> fetchMessages() async {
    final username = "yiaan";
    final aioKey = dotenv.env['AIO_KEY'] ?? '';
    final url = Uri.parse("https://io.adafruit.com/api/v2/$username/feeds/alerta/data?X-AIO-Key=$aioKey");

    final response = await http.get(url);
    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      return data.map((e) => e['value'].toString()).toList();
    } else {
      throw Exception('Falha ao carregar mensagens');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Home - ESP32 App"),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          )
        ],
      ),
      body: FutureBuilder<List<String>>(
        future: fetchMessages(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro ao carregar mensagens"));
          }
          final allMessages = snapshot.data ?? [];
          final combined = [...allMessages, ...mensagens];
          return ListView.builder(
            itemCount: combined.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: Icon(Icons.notification_important, color: Colors.red),
                title: Text(combined[index]),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/pair'),
        child: Icon(Icons.bluetooth),
        tooltip: "Emparelhar dispositivo",
      ),
    );
  }
}
