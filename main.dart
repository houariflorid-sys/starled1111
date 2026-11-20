import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        scaffoldBackgroundColor: const Color(0xFF0B1120),
      ),
      home: const StarLedRemoteScreen(),
    );
  }
}

class ChassisProfile {
  final String name;
  final int address;
  final int powerCmd;
  final int volUpCmd;
  final int volDownCmd;
  final int chUpCmd;
  final int chDownCmd;
  final int muteCmd;
  final int menuCmd;
  final int sourceCmd;
  final int okCmd;
  final int upCmd;
  final int downCmd;
  final int leftCmd;
  final int rightCmd;
  final int exitCmd;
  final List<int> digits; // 0..9

  const ChassisProfile({
    required this.name,
    required this.address,
    required this.powerCmd,
    required this.volUpCmd,
    required this.volDownCmd,
    required this.chUpCmd,
    required this.chDownCmd,
    required this.muteCmd,
    required this.menuCmd,
    required this.sourceCmd,
    required this.okCmd,
    required this.upCmd,
    required this.downCmd,
    required this.leftCmd,
    required this.rightCmd,
    required this.exitCmd,
    required this.digits,
  });
}

class StarLedRemoteScreen extends StatefulWidget {
  const StarLedRemoteScreen({super.key});

  @override
  State<StarLedRemoteScreen> createState() => _StarLedRemoteScreenState();
}

class _StarLedRemoteScreenState extends State<StarLedRemoteScreen> {
  static const MethodChannel _irChannel = MethodChannel('starled_ir_channel');
  bool _hasIrEmitter = false;
  String _status = "جاري فحص مستشعر IR...";
  int _profileIndex = 0;
  bool _isScanning = false;
  Timer? _scanTimer;

  // أشهر 14 لوحة شاسيه لتلفزيونات StarLED واللوحات الصينية المتوافقة
  final List<ChassisProfile> _profiles = const [
    // 1. لوحات CVTE / T.VST القياسية (الأكثر شيوعاً في StarLED 32")
    ChassisProfile(
      name: "P1: StarLED CVTE (0x00FF)",
      address: 0x00FF,
      powerCmd: 0x0D,
      volUpCmd: 0x15,
      volDownCmd: 0x16,
      chUpCmd: 0x13,
      chDownCmd: 0x14,
      muteCmd: 0x0E,
      menuCmd: 0x1A,
      sourceCmd: 0x0C,
      okCmd: 0x1F,
      upCmd: 0x1B,
      downCmd: 0x1C,
      leftCmd: 0x1D,
      rightCmd: 0x1E,
      exitCmd: 0x19,
      digits: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09],
    ),
    // 2. لوحات StarLED Universal A
    ChassisProfile(
      name: "P2: StarLED Univ-A (0x04FB)",
      address: 0x04FB,
      powerCmd: 0x08,
      volUpCmd: 0x02,
      volDownCmd: 0x03,
      chUpCmd: 0x00,
      chDownCmd: 0x01,
      muteCmd: 0x09,
      menuCmd: 0x43,
      sourceCmd: 0x0B,
      okCmd: 0x44,
      upCmd: 0x40,
      downCmd: 0x41,
      leftCmd: 0x07,
      rightCmd: 0x06,
      exitCmd: 0x5B,
      digits: [0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19],
    ),
    // 3. لوحات StarLED / MStar (0x08F7)
    ChassisProfile(
      name: "P3: MStar Board (0x08F7)",
      address: 0x08F7,
      powerCmd: 0x0B,
      volUpCmd: 0x12,
      volDownCmd: 0x13,
      chUpCmd: 0x10,
      chDownCmd: 0x11,
      muteCmd: 0x0E,
      menuCmd: 0x19,
      sourceCmd: 0x0F,
      okCmd: 0x1E,
      upCmd: 0x1A,
      downCmd: 0x1B,
      leftCmd: 0x1C,
      rightCmd: 0x1D,
      exitCmd: 0x18,
      digits: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09],
    ),
    // 4. لوحات Realtek / HK320 (0x20DF)
    ChassisProfile(
      name: "P4: HK-Board (0x20DF)",
      address: 0x20DF,
      powerCmd: 0x10,
      volUpCmd: 0x40,
      volDownCmd: 0xC0,
      chUpCmd: 0x00,
      chDownCmd: 0x80,
      muteCmd: 0x90,
      menuCmd: 0xC2,
      sourceCmd: 0xD0,
      okCmd: 0x22,
      upCmd: 0x02,
      downCmd: 0x82,
      leftCmd: 0xE0,
      rightCmd: 0x60,
      exitCmd: 0xDA,
      digits: [0x08, 0x88, 0x48, 0xC8, 0x28, 0xA8, 0x68, 0xE8, 0x18, 0x98],
    ),
    // 5. لوحات Hisense / StarLED (0x00BF)
    ChassisProfile(
      name: "P5: Hisense/Star (0x00BF)",
      address: 0x00BF,
      powerCmd: 0x0D,
      volUpCmd: 0x44,
      volDownCmd: 0x43,
      chUpCmd: 0x48,
      chDownCmd: 0x49,
      muteCmd: 0x0E,
      menuCmd: 0x14,
      sourceCmd: 0x12,
      okCmd: 0x15,
      upCmd: 0x16,
      downCmd: 0x17,
      leftCmd: 0x19,
      rightCmd: 0x18,
      exitCmd: 0x48,
      digits: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09],
    ),
    // 6. لوحات Skyworth / StarLED (0x0E0E)
    ChassisProfile(
      name: "P6: Skyworth/Star (0x0E0E)",
      address: 0x0E0E,
      powerCmd: 0x0C,
      volUpCmd: 0x10,
      volDownCmd: 0x11,
      chUpCmd: 0x20,
      chDownCmd: 0x21,
      muteCmd: 0x0D,
      menuCmd: 0x54,
      sourceCmd: 0x38,
      okCmd: 0x5C,
      upCmd: 0x58,
      downCmd: 0x59,
      leftCmd: 0x5A,
      rightCmd: 0x5B,
      exitCmd: 0x0A,
      digits: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09],
    ),
    // 7. لوحات Changhong / StarLED (0x40BF)
    ChassisProfile(
      name: "P7: Changhong (0x40BF)",
      address: 0x40BF,
      powerCmd: 0x12,
      volUpCmd: 0x1A,
      volDownCmd: 0x1E,
      chUpCmd: 0x1B,
      chDownCmd: 0x1F,
      muteCmd: 0x10,
      menuCmd: 0x14,
      sourceCmd: 0x18,
      okCmd: 0x0D,
      upCmd: 0x0B,
      downCmd: 0x0E,
      leftCmd: 0x0A,
      rightCmd: 0x0C,
      exitCmd: 0x1C,
      digits: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09],
    ),
    // 8. لوحات Konka / StarLED (0x0202)
    ChassisProfile(
      name: "P8: Konka/Star (0x0202)",
      address: 0x0202,
      powerCmd: 0x0B,
      volUpCmd: 0x13,
      volDownCmd: 0x12,
      chUpCmd: 0x11,
      chDownCmd: 0x10,
      muteCmd: 0x14,
      menuCmd: 0x15,
      sourceCmd: 0x1C,
      okCmd: 0x2F,
      upCmd: 0x2B,
      downCmd: 0x2C,
      leftCmd: 0x2D,
      rightCmd: 0x2E,
      exitCmd: 0x30,
      digits: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09],
    ),
    // 9. لوحات Haier / StarLED (0x1818)
    ChassisProfile(
      name: "P9: Haier/Star (0x1818)",
      address: 0x1818,
      powerCmd: 0x0C,
      volUpCmd: 0x10,
      volDownCmd: 0x11,
      chUpCmd: 0x20,
      chDownCmd: 0x21,
      muteCmd: 0x0D,
      menuCmd: 0x30,
      sourceCmd: 0x38,
      okCmd: 0x35,
      upCmd: 0x31,
      downCmd: 0x32,
      leftCmd: 0x33,
      rightCmd: 0x34,
      exitCmd: 0x36,
      digits: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09],
    ),
    // 10. لوحات TCL / Thomson (0xF00F)
    ChassisProfile(
      name: "P10: TCL/Star (0xF00F)",
      address: 0xF00F,
      powerCmd: 0x0D,
      volUpCmd: 0x10,
      volDownCmd: 0x11,
      chUpCmd: 0x20,
      chDownCmd: 0x21,
      muteCmd: 0x0E,
      menuCmd: 0x54,
      sourceCmd: 0x38,
      okCmd: 0x5C,
      upCmd: 0x58,
      downCmd: 0x59,
      leftCmd: 0x5A,
      rightCmd: 0x5B,
      exitCmd: 0x0A,
      digits: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09],
    ),
    // 11. لوحات Universal China 1 (0x01FE)
    ChassisProfile(
      name: "P11: China-TV1 (0x01FE)",
      address: 0x01FE,
      powerCmd: 0x48,
      volUpCmd: 0x1A,
      volDownCmd: 0x1E,
      chUpCmd: 0x1B,
      chDownCmd: 0x1F,
      muteCmd: 0x10,
      menuCmd: 0x14,
      sourceCmd: 0x18,
      okCmd: 0x0D,
      upCmd: 0x0B,
      downCmd: 0x0E,
      leftCmd: 0x0A,
      rightCmd: 0x0C,
      exitCmd: 0x1C,
      digits: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09],
    ),
    // 12. لوحات Universal China 2 (0x807F مع أوامر CVTE)
    ChassisProfile(
      name: "P12: StarLED-Alt (0x807F)",
      address: 0x807F,
      powerCmd: 0x0D,
      volUpCmd: 0x15,
      volDownCmd: 0x16,
      chUpCmd: 0x13,
      chDownCmd: 0x14,
      muteCmd: 0x0E,
      menuCmd: 0x1A,
      sourceCmd: 0x0C,
      okCmd: 0x1F,
      upCmd: 0x1B,
      downCmd: 0x1C,
      leftCmd: 0x1D,
      rightCmd: 0x1E,
      exitCmd: 0x19,
      digits: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09],
    ),
    // 13. لوحات Universal China 3 (0xFE01 مع أوامر CVTE)
    ChassisProfile(
      name: "P13: StarLED-Inv (0xFE01)",
      address: 0xFE01,
      powerCmd: 0x0D,
      volUpCmd: 0x15,
      volDownCmd: 0x16,
      chUpCmd: 0x13,
      chDownCmd: 0x14,
      muteCmd: 0x0E,
      menuCmd: 0x1A,
      sourceCmd: 0x0C,
      okCmd: 0x1F,
      upCmd: 0x1B,
      downCmd: 0x1C,
      leftCmd: 0x1D,
      rightCmd: 0x1E,
      exitCmd: 0x19,
      digits: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09],
    ),
    // 14. لوحات Vestel / Finlux (0x0000)
    ChassisProfile(
      name: "P14: Vestel/Star (0x0000)",
      address: 0x0000,
      powerCmd: 0x0C,
      volUpCmd: 0x10,
      volDownCmd: 0x11,
      chUpCmd: 0x20,
      chDownCmd: 0x21,
      muteCmd: 0x0D,
      menuCmd: 0x30,
      sourceCmd: 0x38,
      okCmd: 0x35,
      upCmd: 0x14,
      downCmd: 0x13,
      leftCmd: 0x15,
      rightCmd: 0x16,
      exitCmd: 0x37,
      digits: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkIrSensor();
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkIrSensor() async {
    try {
      final bool hasIr = await _irChannel.invokeMethod('hasIrEmitter');
      setState(() {
        _hasIrEmitter = hasIr;
        _status = hasIr ? "جاهز - وجّه الكاميرا الخلفية للتلفاز" : "مستشعر IR غير متاح";
      });
    } catch (e) {
      setState(() => _status = "خطأ في المستشعر");
    }
  }

  List<int> _buildNecPattern(int address, int command) {
    List<int> pattern = [9000, 4500];
    for (int i = 0; i < 16; i++) {
      pattern.add(560);
      bool bit = ((address >> i) & 1) == 1;
      pattern.add(bit ? 1690 : 560);
    }
    int invertedCommand = (~command) & 0xFF;
    int fullCommand = (invertedCommand << 8) | (command & 0xFF);
    for (int i = 0; i < 16; i++) {
      pattern.add(560);
      bool bit = ((fullCommand >> i) & 1) == 1;
      pattern.add(bit ? 1690 : 560);
    }
    pattern.add(560);
    return pattern;
  }

  int _getCommandForKey(ChassisProfile p, String key) {
    switch (key) {
      case 'POWER': return p.powerCmd;
      case 'MUTE': return p.muteCmd;
      case 'VOL_UP': return p.volUpCmd;
      case 'VOL_DOWN': return p.volDownCmd;
      case 'CH_UP': return p.chUpCmd;
      case 'CH_DOWN': return p.chDownCmd;
      case 'MENU': return p.menuCmd;
      case 'SOURCE': return p.sourceCmd;
      case 'OK': return p.okCmd;
      case 'UP': return p.upCmd;
      case 'DOWN': return p.downCmd;
      case 'LEFT': return p.leftCmd;
      case 'RIGHT': return p.rightCmd;
      case 'EXIT': return p.exitCmd;
      default:
        int? d = int.tryParse(key);
        if (d != null && d >= 0 && d <= 9) return p.digits[d];
        return p.volUpCmd;
    }
  }

  Future<void> _sendKey(String keyName) async {
    HapticFeedback.mediumImpact();
    if (!_hasIrEmitter) return;
    final p = _profiles[_profileIndex];
    final int cmd = _getCommandForKey(p, keyName);
    final List<int> pattern = _buildNecPattern(p.address, cmd);
    try {
      await _irChannel.invokeMethod('transmit', {'pattern': pattern});
      setState(() => _status = "${p.name} -> $keyName");
    } catch (e) {
      setState(() => _status = "فشل الإرسال: $e");
    }
  }

  void _toggleAutoScan() {
    if (_isScanning) {
      _scanTimer?.cancel();
      setState(() {
        _isScanning = false;
        _status = "تم التثبيت على: ${_profiles[_profileIndex].name}";
      });
    } else {
      setState(() => _isScanning = true);
      _sendKey('VOL_UP');
      _scanTimer = Timer.periodic(const Duration(milliseconds: 1400), (timer) {
        setState(() {
          _profileIndex = (_profileIndex + 1) % _profiles.length;
        });
        _sendKey('VOL_UP');
      });
    }
  }

  Widget _btn(String label, String keyName, {Color? color, IconData? icon, double height = 46}) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () => _sendKey(keyName),
        child: icon != null
            ? Icon(icon, size: 22)
            : Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("StarLED HK320DF", style: TextStyle(fontSize: 17)),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isScanning ? Colors.red.shade700 : Colors.amber.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: _toggleAutoScan,
              icon: Icon(_isScanning ? Icons.stop : Icons.radar, size: 18),
              label: Text(_isScanning ? "إيقاف المسح" : "Auto-Scan"),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // قائمة اختيار البروفايل يدوياً
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amberAccent.withOpacity(0.5)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _profileIndex,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E293B),
                    items: List.generate(_profiles.length, (index) {
                      return DropdownMenuItem(
                        value: index,
                        child: Text(_profiles[index].name, style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _profileIndex = val);
                        _sendKey('VOL_UP');
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(_status, style: const TextStyle(fontSize: 13, color: Colors.tealAccent)),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(child: _btn("POWER", "POWER", color: Colors.red.shade700, icon: Icons.power_settings_new)),
                  const SizedBox(width: 8),
                  Expanded(child: _btn("SOURCE", "SOURCE", color: Colors.indigo.shade700)),
                  const SizedBox(width: 8),
                  Expanded(child: _btn("MUTE", "MUTE", color: Colors.teal.shade700, icon: Icons.volume_off)),
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
                  for (var num in ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'MENU', '0', 'EXIT'])
                    _btn(num, num, color: (num == 'MENU' || num == 'EXIT') ? const Color(0xFF334155) : null),
                ],
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _btn("VOL +", "VOL_UP", height: 52),
                        const SizedBox(height: 8),
                        _btn("VOL -", "VOL_DOWN", height: 52),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        SizedBox(width: 68, child: _btn("UP", "UP", icon: Icons.keyboard_arrow_up)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(child: _btn("LEFT", "LEFT", icon: Icons.keyboard_arrow_left)),
                            const SizedBox(width: 6),
                            Expanded(child: _btn("OK", "OK", color: Colors.blue.shade700)),
                            const SizedBox(width: 6),
                            Expanded(child: _btn("RIGHT", "RIGHT", icon: Icons.keyboard_arrow_right)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SizedBox(width: 68, child: _btn("DOWN", "DOWN", icon: Icons.keyboard_arrow_down)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _btn("CH +", "CH_UP", height: 52),
                        const SizedBox(height: 8),
                        _btn("CH -", "CH_DOWN", height: 52),
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
