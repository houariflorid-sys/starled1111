import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const AmwRemoteApp());
}

class AmwRemoteApp extends StatelessWidget {
  const AmwRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B1120),
      ),
      home: const AmwRemoteScreen(),
    );
  }
}

class AmwRemoteScreen extends StatefulWidget {
  const AmwRemoteScreen({super.key});

  @override
  State<AmwRemoteScreen> createState() => _AmwRemoteScreenState();
}

class _AmwRemoteScreenState extends State<AmwRemoteScreen> {
  static const MethodChannel _irChannel = MethodChannel('starled_ir_channel');
  bool _hasIrEmitter = false;
  String _status = "جاري فحص مستشعر IR...";

  final int _address = 0x04FB;

  // الخريطة الزوجية الكاملة للوحة AMW / MStar (0x04FB MSB)
  final Map<String, int> _keys = const {
    'POWER': 0x12,    // التشغيل والإيقاف (مؤكد 100%)
    'SOURCE': 0x02,   // مصادر الإدخال (مؤكد 100%)
    'GUIDE': 0x0A,    // دليل البرامج (مؤكد 100%)
    'MUTE': 0x10,     // كتم الصوت
    '1': 0x00,        // رقم 1 (مؤكد 100%)
    '2': 0x08,        // رقم 2 (مؤكد 100%)
    '3': 0x04,        // رقم 3
    '4': 0x0C,        // رقم 4
    '5': 0x14,        // رقم 5
    '6': 0x18,        // رقم 6
    '7': 0x1C,        // رقم 7
    '8': 0x40,        // رقم 8
    '9': 0x48,        // رقم 9
    '0': 0x0E,        // رقم 0
    'VOL_UP': 0x16,   // رفع الصوت (+)
    'VOL_DOWN': 0x1A, // خفض الصوت (-)
    'CH_UP': 0x06,    // القناة التالية (+)
    'CH_DOWN': 0x1E,  // القناة السابقة (-)
    'MENU': 0x44,     // القائمة (MENU)
    'EXIT': 0x4C,     // خروج / رجوع (EXIT)
    'OK': 0x54,       // تأكيد (OK)
    'UP': 0x50,       // سهم للأعلى
    'DOWN': 0x58,     // سهم للأسفل
    'LEFT': 0x5C,     // سهم لليسار
    'RIGHT': 0x52,    // سهم لليمين
  };

  @override
  void initState() {
    super.initState();
    _checkIrSensor();
  }

  Future<void> _checkIrSensor() async {
    try {
      final bool hasIr = await _irChannel.invokeMethod('hasIrEmitter');
      setState(() {
        _hasIrEmitter = hasIr;
        _status = hasIr ? "جاهز - AMW TV (0x04FB)" : "مستشعر IR غير متاح";
      });
    } catch (e) {
      setState(() => _status = "خطأ في المستشعر");
    }
  }

  List<int> _buildMsbSignal(int address, int command) {
    List<int> f = [9000, 4500];
    for (int i = 15; i >= 0; i--) {
      f.add(560);
      f.add(((address >> i) & 1) == 1 ? 1690 : 560);
    }
    int inv = (~command) & 0xFF;
    for (int i = 7; i >= 0; i--) {
      f.add(560);
      f.add(((command >> i) & 1) == 1 ? 1690 : 560);
    }
    for (int i = 7; i >= 0; i--) {
      f.add(560);
      f.add(((inv >> i) & 1) == 1 ? 1690 : 560);
    }
    f.add(560);
    return [...f, 40000, 9000, 2250, 560];
  }

  Future<void> _sendKey(String keyName, String arabicLabel) async {
    HapticFeedback.mediumImpact();
    if (!_hasIrEmitter) return;

    final int? cmd = _keys[keyName];
    if (cmd == null) return;

    final List<int> pattern = _buildMsbSignal(_address, cmd);

    try {
      await _irChannel.invokeMethod('transmit', {
        'pattern': pattern,
        'frequency': 38000,
      });
      setState(() => _status = "$arabicLabel (0x${cmd.toRadixString(16).toUpperCase().padLeft(2, '0')})");
    } catch (e) {
      setState(() => _status = "فشل الإرسال");
    }
  }

  Widget _btn(String label, String keyName, String arabicLabel, {Color? color, IconData? icon, double height = 46}) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => _sendKey(keyName, arabicLabel),
        child: icon != null
            ? Icon(icon, size: 23)
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, maxLines: 1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AMW Remote", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.tealAccent.withOpacity(0.4)),
                ),
                child: Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.tealAccent, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _btn("POWER", "POWER", "تشغيل / إيقاف", color: Colors.red.shade700, icon: Icons.power_settings_new)),
                  const SizedBox(width: 8),
                  Expanded(child: _btn("SOURCE", "SOURCE", "مصادر الإدخال", color: Colors.indigo.shade700)),
                  const SizedBox(width: 8),
                  Expanded(child: _btn("GUIDE", "GUIDE", "دليل البرامج", color: Colors.blueGrey.shade700)),
                  const SizedBox(width: 8),
                  Expanded(child: _btn("MUTE", "MUTE", "كتم الصوت", color: Colors.teal.shade700, icon: Icons.volume_off)),
                ],
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
                children: [
                  _btn("1", "1", "رقم 1"),
                  _btn("2", "2", "رقم 2"),
                  _btn("3", "3", "رقم 3"),
                  _btn("4", "4", "رقم 4"),
                  _btn("5", "5", "رقم 5"),
                  _btn("6", "6", "رقم 6"),
                  _btn("7", "7", "رقم 7"),
                  _btn("8", "8", "رقم 8"),
                  _btn("9", "9", "رقم 9"),
                  _btn("MENU", "MENU", "القائمة", color: const Color(0xFF334155)),
                  _btn("0", "0", "رقم 0"),
                  _btn("EXIT", "EXIT", "خروج / رجوع", color: const Color(0xFF334155)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _btn("VOL +", "VOL_UP", "رفع الصوت", height: 52),
                        const SizedBox(height: 10),
                        _btn("VOL -", "VOL_DOWN", "خفض الصوت", height: 52),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        SizedBox(width: 70, child: _btn("UP", "UP", "سهم للأعلى", icon: Icons.keyboard_arrow_up)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(child: _btn("LEFT", "LEFT", "سهم لليسار", icon: Icons.keyboard_arrow_left)),
                            const SizedBox(width: 6),
                            Expanded(child: _btn("OK", "OK", "تأكيد (OK)", color: Colors.blue.shade700)),
                            const SizedBox(width: 6),
                            Expanded(child: _btn("RIGHT", "RIGHT", "سهم لليمين", icon: Icons.keyboard_arrow_right)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SizedBox(width: 70, child: _btn("DOWN", "DOWN", "سهم للأسفل", icon: Icons.keyboard_arrow_down)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _btn("CH +", "CH_UP", "القناة التالية", height: 52),
                        const SizedBox(height: 10),
                        _btn("CH -", "CH_DOWN", "القناة السابقة", height: 52),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
