import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ir_sensor_plugin/ir_sensor_plugin.dart';

void main() {
  runApp(const StarLedRemoteApp());
}

class StarLedRemoteApp extends StatelessWidget {
  const StarLedRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const StarLedRemoteScreen(),
    );
  }
}

class StarLedRemoteScreen extends StatefulWidget {
  const StarLedRemoteScreen({super.key});

  @override
  State<StarLedRemoteScreen> createState() => _StarLedRemoteScreenState();
}

class _StarLedRemoteScreenState extends State<StarLedRemoteScreen> {
  bool _hasIrEmitter = false;
  String _status = "جاري فحص مستشعر IR...";

  // كود الشاسيه القياسي لتلفاز StarLED HK320DF (Profile 6)
  static const int _addressCode = 0x807F;

  // أكواد الأوامر القياسية لبروتوكول NEC (0x807F)
  final Map<String, int> _commands = {
    'POWER': 0x12,
    'MUTE': 0x10,
    '1': 0x01,
    '2': 0x02,
    '3': 0x03,
    '4': 0x04,
    '5': 0x05,
    '6': 0x06,
    '7': 0x07,
    '8': 0x08,
    '9': 0x09,
    '0': 0x00,
    'VOL_UP': 0x1A,
    'VOL_DOWN': 0x1E,
    'CH_UP': 0x1B,
    'CH_DOWN': 0x1F,
    'MENU': 0x14,
    'SOURCE': 0x18,
    'OK': 0x0D,
    'UP': 0x0B,
    'DOWN': 0x0E,
    'LEFT': 0x0A,
    'RIGHT': 0x0C,
    'EXIT': 0x1C,
  };

  @override
  void initState() {
    super.initState();
    _checkIrSensor();
  }

  Future<void> _checkIrSensor() async {
    try {
      final bool hasIr = await IrSensorPlugin.hasIrEmitter;
      setState(() {
        _hasIrEmitter = hasIr;
        _status = hasIr
            ? "مستشعر IR جاهز (StarLED 0x807F)"
            : "الهاتف لا يدعم IR أو الإذن مرفوض";
      });
    } on PlatformException {
      setState(() {
        _status = "خطأ في الوصول إلى مستشعر IR";
      });
    }
  }

  /// تحويل كود NEC 16-bit Address + 8-bit Command إلى مصفوفة نبضات بالميكروثانية
  List<int> _buildNecPattern(int address, int command) {
    List<int> pattern = [];

    // نبضة البداية القياسية لبروتوكول NEC (9ms نبضة + 4.5ms فراغ)
    pattern.add(9000);
    pattern.add(4500);

    // 1. إرسال العنوان (16 بت - LSB First)
    for (int i = 0; i < 16; i++) {
      pattern.add(560); // Mark
      bool bit = ((address >> i) & 1) == 1;
      pattern.add(bit ? 1690 : 560); // Space (1 = 1690us, 0 = 560us)
    }

    // 2. إرسال الأمر (8 بت) ثم معكوس الأمر (8 بت للتحقق)
    int invertedCommand = (~command) & 0xFF;
    int fullCommand = (invertedCommand << 8) | (command & 0xFF);

    for (int i = 0; i < 16; i++) {
      pattern.add(560);
      bool bit = ((fullCommand >> i) & 1) == 1;
      pattern.add(bit ? 1690 : 560);
    }

    // نبضة الإغلاق النهائية
    pattern.add(560);
    return pattern;
  }

  Future<void> _sendKey(String keyName) async {
    HapticFeedback.lightImpact();
    if (!_hasIrEmitter) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("مستشعر IR غير متاح على هذا الجهاز")),
      );
      return;
    }

    final int? cmd = _commands[keyName];
    if (cmd == null) return;

    final List<int> pattern = _buildNecPattern(_addressCode, cmd);
    try {
      await IrSensorPlugin.transmitListInt(list: pattern);
      setState(() => _status = "تم إرسال: $keyName (0x${cmd.toRadixString(16).toUpperCase()})");
    } catch (e) {
      setState(() => _status = "فشل الإرسال: $e");
    }
  }

  Widget _buildButton(String label, String keyName, {Color? color, IconData? icon}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => _sendKey(keyName),
      child: icon != null
          ? Icon(icon, size: 24)
          : Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("StarLED HK320DF Remote"),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _hasIrEmitter ? Colors.teal.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.settings_remote, color: _hasIrEmitter ? Colors.tealAccent : Colors.redAccent),
                  const SizedBox(width: 8),
                  Text(_status, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // أزرار الطاقة وكتم الصوت
            Row(
              children: [
                Expanded(child: _buildButton("POWER", "POWER", color: Colors.red.shade700, icon: Icons.power_settings_new)),
                const SizedBox(width: 16),
                Expanded(child: _buildButton("MUTE", "MUTE", color: Colors.teal.shade700, icon: Icons.volume_off)),
              ],
            ),
            const SizedBox(height: 20),
            // لوحة الأرقام
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.6,
                children: [
                  for (var num in ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'SOURCE', '0', 'MENU'])
                    _buildButton(num, num),
                ],
              ),
            ),
            // التحكم بالصوت والقنوات
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    _buildButton("VOL +", "VOL_UP"),
                    const SizedBox(height: 8),
                    _buildButton("VOL -", "VOL_DOWN"),
                  ],
                ),
                _buildButton("OK", "OK", color: Colors.blueGrey.shade700),
                Column(
                  children: [
                    _buildButton("CH +", "CH_UP"),
                    const SizedBox(height: 8),
                    _buildButton("CH -", "CH_DOWN"),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
