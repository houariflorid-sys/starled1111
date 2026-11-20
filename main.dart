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

  // العنوان الصحيح المستنتج من استجابة شاشتك (0x00FF)
  // مع خيار التبديل إلى (0x00FD) في حال احتجت ذلك
  int _address = 0x00FF;

  // الخريطة الدقيقة المستنتجة رياضياً من أزرار شاشتك (كل زر في وظيفته الصحيحة)
  final Map<String, int> _exactKeys = const {
    'POWER': 0x0D,    // التشغيل والإيقاف
    'MUTE': 0x0E,     // كتم الصوت
    'SOURCE': 0xA8,   // مصادر الإدخال (HDMI / PC / AV) - تم التحقق منه من شاشتك!
    '1': 0xC8,        // رقم 1 - تم التحقق منه من شاشتك!
    '2': 0xB0,        // رقم 2 - تم التحقق منه من شاشتك!
    '3': 0x70,        // رقم 3
    '4': 0xD0,        // رقم 4
    '5': 0x90,        // رقم 5
    '6': 0x50,        // رقم 6
    '7': 0xE0,        // رقم 7
    '8': 0xA0,        // رقم 8
    '9': 0x60,        // رقم 9
    '0': 0x88,        // رقم 0
    'VOL_UP': 0x15,   // رفع الصوت (+)
    'VOL_DOWN': 0x16, // خفض الصوت (-)
    'CH_UP': 0x13,    // القناة التالية (+)
    'CH_DOWN': 0x14,  // القناة السابقة (-)
    'MENU': 0x1A,     // القائمة (MENU)
    'EXIT': 0x19,     // خروج / رجوع (EXIT)
    'OK': 0x1F,       // تأكيد (OK)
    'UP': 0x1B,       // سهم للأعلى
    'DOWN': 0x1C,     // سهم للأسفل
    'LEFT': 0x1D,     // سهم لليسار
    'RIGHT': 0x1E,    // سهم لليمين
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
        _status = hasIr
            ? "جاهز - AMW TV (0x${_address.toRadixString(16).toUpperCase().padLeft(4, '0')})"
            : "مستشعر IR غير متاح";
      });
    } catch (e) {
      setState(() => _status = "خطأ في المستشعر");
    }
  }

  /// بناء إشارة NEC القياسية بترتيب LSB الصحيح المطابق للوحة شاشتك
  List<int> _buildExactSignal(int address, int command) {
    List<int> frame = [9000, 4500];
    for (int i = 0; i < 16; i++) {
      frame.add(560);
      bool bit = ((address >> i) & 1) == 1;
      frame.add(bit ? 1690 : 560);
    }
    int invertedCommand = (~command) & 0xFF;
    int fullCommand = (invertedCommand << 8) | (command & 0xFF);
    for (int i = 0; i < 16; i++) {
      frame.add(560);
      bool bit = ((fullCommand >> i) & 1) == 1;
      frame.add(bit ? 1690 : 560);
    }
    frame.add(560);
    // إرسال الإطار مع نبضة تكرار واحدة لمنع تكرار الرقم مرتين (مثل 11 أو 22)
    return [...frame, 40000, 9000, 2250, 560];
  }

  Future<void> _sendKey(String keyName, String arabicLabel) async {
    HapticFeedback.mediumImpact();
    if (!_hasIrEmitter) return;

    final int? cmd = _exactKeys[keyName];
    if (cmd == null) return;

    final List<int> pattern = _buildExactSignal(_address, cmd);

    try {
      await _irChannel.invokeMethod('transmit', {
        'pattern': pattern,
        'frequency': 38000,
      });
      setState(() => _status = "تم تنفيذ: $arabicLabel");
    } catch (e) {
      setState(() => _status = "فشل الإرسال");
    }
  }

  Widget _btn(String label, String keyName, String arabicLabel, {Color? color, IconData? icon, double height = 48}) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => _sendKey(keyName, arabicLabel),
        child: icon != null
            ? Icon(icon, size: 24)
            : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _address = (_address == 0x00FF) ? 0x00FD : 0x00FF;
                _status = "العنوان: 0x${_address.toRadixString(16).toUpperCase().padLeft(4, '0')}";
              });
            },
            child: Text(
              "0x${_address.toRadixString(16).toUpperCase().padLeft(4, '0')}",
              style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold),
            ),
          )
        ],
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
                  style: const TextStyle(fontSize: 14, color: Colors.tealAccent, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 14),

              // الصف العلوي: التشغيل - المصادر - كتم الصوت
              Row(
                children: [
                  Expanded(child: _btn("POWER", "POWER", "تشغيل / إيقاف", color: Colors.red.shade700, icon: Icons.power_settings_new)),
                  const SizedBox(width: 10),
                  Expanded(child: _btn("SOURCE", "SOURCE", "مصادر الإدخال", color: Colors.indigo.shade700)),
                  const SizedBox(width: 10),
                  Expanded(child: _btn("MUTE", "MUTE", "كتم الصوت", color: Colors.teal.shade700, icon: Icons.volume_off)),
                ],
              ),
              const SizedBox(height: 14),

              // لوحة الأرقام
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.1,
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
              const SizedBox(height: 16),

              // الصوت + الأسهم + القنوات
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _btn("VOL +", "VOL_UP", "رفع الصوت", height: 54),
                        const SizedBox(height: 10),
                        _btn("VOL -", "VOL_DOWN", "خفض الصوت", height: 54),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        SizedBox(width: 72, child: _btn("UP", "UP", "سهم للأعلى", icon: Icons.keyboard_arrow_up)),
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
                        SizedBox(width: 72, child: _btn("DOWN", "DOWN", "سهم للأسفل", icon: Icons.keyboard_arrow_down)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _btn("CH +", "CH_UP", "القناة التالية", height: 54),
                        const SizedBox(height: 10),
                        _btn("CH -", "CH_DOWN", "القناة السابقة", height: 54),
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
