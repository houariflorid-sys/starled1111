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

class AmwKeyMap {
  final String label;
  final int frequency;
  final bool isRc5;
  final int address;
  final Map<String, int> keys;

  const AmwKeyMap({
    required this.label,
    this.frequency = 38000,
    this.isRc5 = false,
    required this.address,
    required this.keys,
  });
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
  int _selectedMap = 0;
  bool _rc5Toggle = false;

  // الخرائط الثلاث الدقيقة والمطابقة لوظائف أزرار AMW TV (RID: 5904)
  final List<AmwKeyMap> _amwMaps = const [
    // الخريطة 1: خريطة AMW / LG-OEM القياسية (0x04FB) - كل زر في وظيفته الدقيقة
    AmwKeyMap(
      label: "AMW 5904 - خريطة 1 (الأساسية)",
      address: 0x04FB,
      keys: {
        'POWER': 0x08,
        'MUTE': 0x09,
        'SOURCE': 0x0B,
        'VOL_UP': 0x02,
        'VOL_DOWN': 0x03,
        'CH_UP': 0x00,
        'CH_DOWN': 0x01,
        'MENU': 0x43,
        'EXIT': 0x5B,
        'OK': 0x44,
        'UP': 0x40,
        'DOWN': 0x41,
        'LEFT': 0x07,
        'RIGHT': 0x06,
        '0': 0x10,
        '1': 0x11,
        '2': 0x12,
        '3': 0x13,
        '4': 0x14,
        '5': 0x15,
        '6': 0x16,
        '7': 0x17,
        '8': 0x18,
        '9': 0x19,
      },
    ),
    // الخريطة 2: خريطة AMW / CVTE الأوروبية (0x00FF)
    AmwKeyMap(
      label: "AMW 5904 - خريطة 2 (بديلة A)",
      address: 0x00FF,
      keys: {
        'POWER': 0x0D,
        'MUTE': 0x0E,
        'SOURCE': 0x0C,
        'VOL_UP': 0x15,
        'VOL_DOWN': 0x16,
        'CH_UP': 0x13,
        'CH_DOWN': 0x14,
        'MENU': 0x1A,
        'EXIT': 0x19,
        'OK': 0x1F,
        'UP': 0x1B,
        'DOWN': 0x1C,
        'LEFT': 0x1D,
        'RIGHT': 0x1E,
        '0': 0x00,
        '1': 0x01,
        '2': 0x02,
        '3': 0x03,
        '4': 0x04,
        '5': 0x05,
        '6': 0x06,
        '7': 0x07,
        '8': 0x08,
        '9': 0x09,
      },
    ),
    // الخريطة 3: خريطة AMW / Vestel RC5 (تردد 36kHz)
    AmwKeyMap(
      label: "AMW 5904 - خريطة 3 (RC5)",
      frequency: 36000,
      isRc5: true,
      address: 0x00,
      keys: {
        'POWER': 0x0C,
        'MUTE': 0x0D,
        'SOURCE': 0x38,
        'VOL_UP': 0x10,
        'VOL_DOWN': 0x11,
        'CH_UP': 0x20,
        'CH_DOWN': 0x21,
        'MENU': 0x30,
        'EXIT': 0x37,
        'OK': 0x35,
        'UP': 0x14,
        'DOWN': 0x13,
        'LEFT': 0x15,
        'RIGHT': 0x16,
        '0': 0x00,
        '1': 0x01,
        '2': 0x02,
        '3': 0x03,
        '4': 0x04,
        '5': 0x05,
        '6': 0x06,
        '7': 0x07,
        '8': 0x08,
        '9': 0x09,
      },
    ),
  ];

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
        _status = hasIr ? "جاهز - AMW TV (RID: 5904)" : "مستشعر IR غير متاح";
      });
    } catch (e) {
      setState(() => _status = "خطأ في المستشعر");
    }
  }

  List<int> _buildNecFrame(int address, int command) {
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
    return [...frame, 40000, ...frame];
  }

  List<int> _buildRc5Frame(int systemAddr, int command) {
    List<int> bits = [
      1,
      (command < 64) ? 1 : 0,
      _rc5Toggle ? 1 : 0,
    ];
    for (int i = 4; i >= 0; i--) {
      bits.add((systemAddr >> i) & 1);
    }
    for (int i = 5; i >= 0; i--) {
      bits.add((command >> i) & 1);
    }

    List<int> raw = [];
    for (int b in bits) {
      if (b == 1) {
        raw.add(-889);
        raw.add(889);
      } else {
        raw.add(889);
        raw.add(-889);
      }
    }

    List<int> pattern = [];
    for (int val in raw) {
      if (pattern.isEmpty) {
        if (val > 0) pattern.add(val);
        continue;
      }
      bool lastIsMark = pattern.length % 2 == 1;
      bool currIsMark = val > 0;
      if (lastIsMark == currIsMark) {
        pattern[pattern.length - 1] += val.abs();
      } else {
        pattern.add(val.abs());
      }
    }
    if (pattern.length % 2 == 0) {
      pattern.removeLast();
    }
    return [...pattern, 88000, ...pattern];
  }

  Future<void> _sendKey(String keyName, String arabicName) async {
    HapticFeedback.mediumImpact();
    if (!_hasIrEmitter) return;

    final map = _amwMaps[_selectedMap];
    final int? cmd = map.keys[keyName];
    if (cmd == null) return;

    final List<int> pattern = map.isRc5
        ? _buildRc5Frame(map.address, cmd)
        : _buildNecFrame(map.address, cmd);

    if (map.isRc5) {
      _rc5Toggle = !_rc5Toggle;
    }

    try {
      await _irChannel.invokeMethod('transmit', {
        'pattern': pattern,
        'frequency': map.frequency,
      });
      setState(() => _status = "تم تنفيذ: $arabicName");
    } catch (e) {
      setState(() => _status = "فشل الإرسال");
    }
  }

  Widget _btn(String label, String keyName, String arabicName, {Color? color, IconData? icon, double height = 48}) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => _sendKey(keyName, arabicName),
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
        title: const Text("AMW TV (5904)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            children: [
              // اختيار الخريطة الدقيقة لـ AMW 5904
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.tealAccent.withOpacity(0.5)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedMap,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E293B),
                    items: List.generate(_amwMaps.length, (i) {
                      return DropdownMenuItem(
                        value: i,
                        child: Text(
                          _amwMaps[i].label,
                          style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedMap = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(_status, style: const TextStyle(fontSize: 13, color: Colors.amberAccent)),
              const SizedBox(height: 14),

              // الصف العلوي: التشغيل - المصادر - كتم الصوت
              Row(
                children: [
                  Expanded(child: _btn("POWER", "POWER", "تشغيل / إيقاف", color: Colors.red.shade700, icon: Icons.power_settings_new)),
                  const SizedBox(width: 10),
                  Expanded(child: _btn("SOURCE", "SOURCE", "المصادر (HDMI/AV)", color: Colors.indigo.shade700)),
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
