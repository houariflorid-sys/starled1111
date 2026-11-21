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
  String _statusLabel = "جاري فحص مستشعر IR...";
  String _statusHex = "";

  // جميع الأكواد الـ 32 المؤكدة بنظام NEC LSB (العنوان 0x20DF)
  final Map<String, int> _keys = const {
    'POWER': 0x48,      // تشغيل / إيقاف
    'SOURCE': 0x40,     // مصادر الإدخال (HDMI / PC / AV)
    'GUIDE': 0x50,      // دليل البرامج
    'MENU': 0x4A,       // القائمة
    'MUTE': 0x0B,       // كتم الصوت
    'VOL_UP': 0x5C,     // زيادة الصوت
    'VOL_DOWN': 0x0C,   // تنقيص الصوت
    'CH_UP': 0x5D,      // القناة الأعلى
    'CH_DOWN': 0x5E,    // القناة السفلى
    'CH_LIST': 0x0E,    // قائمة القنوات / تأكيد (OK)
    'ASPECT': 0x53,     // حجم الشاشة (16:9)
    'SLEEP': 0x5A,      // وقت النوم
    'PIC_MODE': 0x4C,   // نوع الصورة
    'SND_MODE': 0x06,   // نوع الصوت
    'UP': 0x4D,         // أعلى في القائمة
    'DOWN': 0x47,       // أسفل في القائمة
    'LEFT': 0x49,       // قمر لليسار / يسار
    'RIGHT': 0x4B,      // قمر لليمين / يمين
    'EXIT': 0x01,       // خروج (EXIT)
    'BACK': 0x0A,       // رجوع / خروج
    'SORT': 0x56,       // ترتيب القنوات (A-Z)
    'SEARCH': 0x58,     // البحث بالاسم
    '0': 0x1B,
    '1': 0x00,
    '2': 0x10,
    '3': 0x11,
    '4': 0x13,
    '5': 0x14,
    '6': 0x15,
    '7': 0x17,
    '8': 0x18,
    '9': 0x19,
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
        _statusLabel = hasIr ? "جاهز - AMW TV (5904)" : "مستشعر IR غير متاح";
        _statusHex = "";
      });
    } catch (e) {
      setState(() {
        _statusLabel = "خطأ في المستشعر";
        _statusHex = "";
      });
    }
  }

  List<int> _buildLsbSignal(int cmdLsb) {
    List<int> f = [9000, 4500];
    const int addr1 = 0x20;
    const int addr2 = 0xDF;
    for (int i = 0; i < 8; i++) {
      f.add(560);
      f.add(((addr1 >> i) & 1) == 1 ? 1690 : 560);
    }
    for (int i = 0; i < 8; i++) {
      f.add(560);
      f.add(((addr2 >> i) & 1) == 1 ? 1690 : 560);
    }
    int inv = (~cmdLsb) & 0xFF;
    for (int i = 0; i < 8; i++) {
      f.add(560);
      f.add(((cmdLsb >> i) & 1) == 1 ? 1690 : 560);
    }
    for (int i = 0; i < 8; i++) {
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

    final String hex = "0x${cmd.toRadixString(16).toUpperCase().padLeft(2, '0')}";

    try {
      await _irChannel.invokeMethod('transmit', {
        'pattern': _buildLsbSignal(cmd),
        'frequency': 38000,
      });
      setState(() {
        _statusLabel = arabicLabel;
        _statusHex = hex;
      });
    } catch (e) {
      setState(() {
        _statusLabel = "فشل الإرسال";
        _statusHex = "";
      });
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
            ? Icon(icon, size: 22)
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
              // شريط الحالة
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.tealAccent.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_statusHex.isNotEmpty) ...[
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          _statusHex,
                          style: const TextStyle(fontSize: 14, color: Colors.amberAccent, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Text("  |  ", style: TextStyle(color: Colors.white54)),
                    ],
                    Text(
                      _statusLabel,
                      style: const TextStyle(fontSize: 14, color: Colors.tealAccent, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // الصف الأول: التشغيل - المصادر - الدليل - كتم الصوت
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
              const SizedBox(height: 8),

              // الصف الثاني: الصورة - الصوت - حجم الشاشة - وقت النوم
              Row(
                children: [
                  Expanded(child: _btn("PICTURE", "PIC_MODE", "نوع الصورة", color: const Color(0xFF273549))),
                  const SizedBox(width: 6),
                  Expanded(child: _btn("SOUND", "SND_MODE", "نوع الصوت", color: const Color(0xFF273549))),
                  const SizedBox(width: 6),
                  Expanded(child: _btn("16:9", "ASPECT", "حجم الشاشة", color: const Color(0xFF273549))),
                  const SizedBox(width: 6),
                  Expanded(child: _btn("SLEEP", "SLEEP", "وقت النوم", color: const Color(0xFF273549))),
                ],
              ),
              const SizedBox(height: 12),

              // لوحة الأرقام
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.25,
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
                  _btn("CH LIST", "CH_LIST", "قائمة القنوات", color: const Color(0xFF334155)),
                  _btn("0", "0", "رقم 0"),
                  _btn("MENU", "MENU", "القائمة", color: const Color(0xFF334155)),
                ],
              ),
              const SizedBox(height: 14),

              // الصوت + الأسهم والأقمار + القنوات
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _btn("VOL +", "VOL_UP", "زيادة الصوت", height: 52),
                        const SizedBox(height: 10),
                        _btn("VOL -", "VOL_DOWN", "تنقيص الصوت", height: 52),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        SizedBox(width: 70, child: _btn("UP", "UP", "أعلى في القائمة", icon: Icons.keyboard_arrow_up)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(child: _btn("LEFT", "LEFT", "قمر لليسار", icon: Icons.keyboard_arrow_left)),
                            const SizedBox(width: 6),
                            Expanded(child: _btn("OK", "CH_LIST", "تأكيد / القائمة", color: Colors.blue.shade700)),
                            const SizedBox(width: 6),
                            Expanded(child: _btn("RIGHT", "RIGHT", "قمر لليمين", icon: Icons.keyboard_arrow_right)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SizedBox(width: 70, child: _btn("DOWN", "DOWN", "أسفل في القائمة", icon: Icons.keyboard_arrow_down)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _btn("CH +", "CH_UP", "القناة الأعلى", height: 52),
                        const SizedBox(height: 10),
                        _btn("CH -", "CH_DOWN", "القناة السفلى", height: 52),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // شريط أدوات قائمة القنوات والخروج
              Row(
                children: [
                  Expanded(child: _btn("A-Z ترتيب", "SORT", "ترتيب القنوات", color: Colors.green.shade700)),
                  const SizedBox(width: 6),
                  Expanded(child: _btn("بحث بالاسم", "SEARCH", "البحث بالاسم", color: Colors.cyan.shade800)),
                  const SizedBox(width: 6),
                  Expanded(child: _btn("رجوع", "BACK", "رجوع", color: Colors.amber.shade900)),
                  const SizedBox(width: 6),
                  Expanded(child: _btn("EXIT", "EXIT", "خروج (EXIT)", color: Colors.deepOrange.shade800)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
