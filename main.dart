import 'dart:async';
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

enum SignalType { necLsb, necMsb, sony12, jvc, panasonic }

class AmwProfile {
  final String name;
  final SignalType type;
  final int frequency;
  final int address;
  final Map<String, int> keys;

  const AmwProfile({
    required this.name,
    required this.type,
    this.frequency = 38000,
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
  int _selected = 0;
  bool _isScanning = false;
  Timer? _timer;

  // خرائط AMW TV (RID: 5904) بجميع احتمالات التشفير (MSB / LSB / Sony / JVC / Panasonic)
  final List<AmwProfile> _profiles = const [
    // 1. NEC MSB-First (الترتيب المعكوس - شائع جداً في قواعد بيانات RID)
    AmwProfile(
      name: "A1: AMW-MSB (0x04FB)",
      type: SignalType.necMsb,
      address: 0x04FB,
      keys: {
        'POWER': 0x08, 'MUTE': 0x09, 'SOURCE': 0x0B,
        'VOL_UP': 0x02, 'VOL_DOWN': 0x03, 'CH_UP': 0x00, 'CH_DOWN': 0x01,
        'MENU': 0x43, 'EXIT': 0x5B, 'OK': 0x44,
        'UP': 0x40, 'DOWN': 0x41, 'LEFT': 0x07, 'RIGHT': 0x06,
        '0': 0x10, '1': 0x11, '2': 0x12, '3': 0x13, '4': 0x14,
        '5': 0x15, '6': 0x16, '7': 0x17, '8': 0x18, '9': 0x19,
      },
    ),
    // 2. NEC MSB-First (0x00FF)
    AmwProfile(
      name: "A2: AMW-MSB (0x00FF)",
      type: SignalType.necMsb,
      address: 0x00FF,
      keys: {
        'POWER': 0x0D, 'MUTE': 0x0E, 'SOURCE': 0x0C,
        'VOL_UP': 0x15, 'VOL_DOWN': 0x16, 'CH_UP': 0x13, 'CH_DOWN': 0x14,
        'MENU': 0x1A, 'EXIT': 0x19, 'OK': 0x1F,
        'UP': 0x1B, 'DOWN': 0x1C, 'LEFT': 0x1D, 'RIGHT': 0x1E,
        '0': 0x00, '1': 0x01, '2': 0x02, '3': 0x03, '4': 0x04,
        '5': 0x05, '6': 0x06, '7': 0x07, '8': 0x08, '9': 0x09,
      },
    ),
    // 3. Sony SIRC 12-bit (تردد 40kHz - تستخدمه بعض شاشات AMW)
    AmwProfile(
      name: "A3: AMW-Sony (40kHz)",
      type: SignalType.sony12,
      frequency: 40000,
      address: 0x01,
      keys: {
        'POWER': 0x15, 'MUTE': 0x14, 'SOURCE': 0x25,
        'VOL_UP': 0x12, 'VOL_DOWN': 0x13, 'CH_UP': 0x10, 'CH_DOWN': 0x11,
        'MENU': 0x60, 'EXIT': 0x63, 'OK': 0x65,
        'UP': 0x74, 'DOWN': 0x75, 'LEFT': 0x34, 'RIGHT': 0x33,
        '0': 0x09, '1': 0x00, '2': 0x01, '3': 0x02, '4': 0x03,
        '5': 0x04, '6': 0x05, '7': 0x06, '8': 0x07, '9': 0x08,
      },
    ),
    // 4. JVC Protocol (0xC0)
    AmwProfile(
      name: "A4: AMW-JVC (0xC0)",
      type: SignalType.jvc,
      address: 0xC0,
      keys: {
        'POWER': 0x17, 'MUTE': 0x1C, 'SOURCE': 0x13,
        'VOL_UP': 0x1E, 'VOL_DOWN': 0x1F, 'CH_UP': 0x19, 'CH_DOWN': 0x18,
        'MENU': 0x2E, 'EXIT': 0x2D, 'OK': 0x2F,
        'UP': 0x2A, 'DOWN': 0x2B, 'LEFT': 0x2C, 'RIGHT': 0x29,
        '0': 0x20, '1': 0x21, '2': 0x22, '3': 0x23, '4': 0x24,
        '5': 0x25, '6': 0x26, '7': 0x27, '8': 0x28, '9': 0x29,
      },
    ),
    // 5. Panasonic / Matsushita (48-bit Kaseikyo)
    AmwProfile(
      name: "A5: AMW-Panasonic",
      type: SignalType.panasonic,
      frequency: 37000,
      address: 0x0080,
      keys: {
        'POWER': 0x3D, 'MUTE': 0x32, 'SOURCE': 0x05,
        'VOL_UP': 0x20, 'VOL_DOWN': 0x21, 'CH_UP': 0x34, 'CH_DOWN': 0x35,
        'MENU': 0x52, 'EXIT': 0xD3, 'OK': 0x49,
        'UP': 0x4A, 'DOWN': 0x4B, 'LEFT': 0x4E, 'RIGHT': 0x4F,
        '0': 0x19, '1': 0x10, '2': 0x11, '3': 0x12, '4': 0x13,
        '5': 0x14, '6': 0x15, '7': 0x16, '8': 0x17, '9': 0x18,
      },
    ),
    // 6. NEC LSB القياسي مع عنوان 0x00FD (شائع في لوحات Vestel/AMW)
    AmwProfile(
      name: "A6: AMW-Vestel (0x00FD)",
      type: SignalType.necLsb,
      address: 0x00FD,
      keys: {
        'POWER': 0x0C, 'MUTE': 0x0D, 'SOURCE': 0x38,
        'VOL_UP': 0x10, 'VOL_DOWN': 0x11, 'CH_UP': 0x20, 'CH_DOWN': 0x21,
        'MENU': 0x30, 'EXIT': 0x37, 'OK': 0x35,
        'UP': 0x14, 'DOWN': 0x13, 'LEFT': 0x15, 'RIGHT': 0x16,
        '0': 0x00, '1': 0x01, '2': 0x02, '3': 0x03, '4': 0x04,
        '5': 0x05, '6': 0x06, '7': 0x07, '8': 0x08, '9': 0x09,
      },
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkIrSensor();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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

  List<int> _buildSignal(AmwProfile p, int cmd) {
    switch (p.type) {
      case SignalType.necLsb:
        List<int> f = [9000, 4500];
        for (int i = 0; i < 16; i++) {
          f.add(560);
          f.add(((p.address >> i) & 1) == 1 ? 1690 : 560);
        }
        int full = (((~cmd) & 0xFF) << 8) | (cmd & 0xFF);
        for (int i = 0; i < 16; i++) {
          f.add(560);
          f.add(((full >> i) & 1) == 1 ? 1690 : 560);
        }
        f.add(560);
        return [...f, 40000, ...f];

      case SignalType.necMsb:
        List<int> f = [9000, 4500];
        for (int i = 15; i >= 0; i--) {
          f.add(560);
          f.add(((p.address >> i) & 1) == 1 ? 1690 : 560);
        }
        int inv = (~cmd) & 0xFF;
        for (int i = 7; i >= 0; i--) {
          f.add(560);
          f.add(((cmd >> i) & 1) == 1 ? 1690 : 560);
        }
        for (int i = 7; i >= 0; i--) {
          f.add(560);
          f.add(((inv >> i) & 1) == 1 ? 1690 : 560);
        }
        f.add(560);
        return [...f, 40000, ...f];

      case SignalType.sony12:
        List<int> f = [2400, 600];
        for (int i = 0; i < 7; i++) {
          f.add(((cmd >> i) & 1) == 1 ? 1200 : 600);
          f.add(600);
        }
        for (int i = 0; i < 5; i++) {
          f.add(((p.address >> i) & 1) == 1 ? 1200 : 600);
          f.add(600);
        }
        return [...f, 25000, ...f, 25000, ...f];

      case SignalType.jvc:
        List<int> header = [8400, 4200];
        List<int> body = [];
        for (int i = 0; i < 8; i++) {
          body.add(526);
          body.add(((p.address >> i) & 1) == 1 ? 1574 : 526);
        }
        for (int i = 0; i < 8; i++) {
          body.add(526);
          body.add(((cmd >> i) & 1) == 1 ? 1574 : 526);
        }
        body.add(526);
        return [...header, ...body, 20000, ...body];

      case SignalType.panasonic:
        List<int> bytes = [0x02, 0x20, 0x80, 0x00, cmd, 0x80 ^ 0x00 ^ cmd];
        List<int> f = [3456, 1728];
        for (int b in bytes) {
          for (int i = 0; i < 8; i++) {
            f.add(432);
            f.add(((b >> i) & 1) == 1 ? 1296 : 432);
          }
        }
        f.add(432);
        return [...f, 74000, ...f];
    }
  }

  Future<void> _sendKey(String keyName, String arabicName) async {
    HapticFeedback.mediumImpact();
    if (!_hasIrEmitter) return;

    final p = _profiles[_selected];
    final int? cmd = p.keys[keyName];
    if (cmd == null) return;

    final List<int> pattern = _buildSignal(p, cmd);

    try {
      await _irChannel.invokeMethod('transmit', {
        'pattern': pattern,
        'frequency': p.frequency,
      });
      setState(() => _status = "${p.name} -> $arabicName");
    } catch (e) {
      setState(() => _status = "فشل الإرسال");
    }
  }

  void _toggleScan() {
    if (_isScanning) {
      _timer?.cancel();
      setState(() {
        _isScanning = false;
        _status = "مثبت على: ${_profiles[_selected].name}";
      });
    } else {
      setState(() => _isScanning = true);
      _sendKey('VOL_UP', 'رفع الصوت');
      _timer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
        setState(() {
          _selected = (_selected + 1) % _profiles.length;
        });
        _sendKey('VOL_UP', 'رفع الصوت');
      });
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
        title: const Text("AMW TV (5904)", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isScanning ? Colors.red.shade700 : Colors.amber.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: _toggleScan,
              icon: Icon(_isScanning ? Icons.stop : Icons.radar, size: 18),
              label: Text(_isScanning ? "إيقاف" : "فحص (A1-A6)"),
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
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.tealAccent.withOpacity(0.5)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selected,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E293B),
                    items: List.generate(_profiles.length, (i) {
                      return DropdownMenuItem(
                        value: i,
                        child: Text(
                          _profiles[i].name,
                          style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) setState(() => _selected = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(_status, style: const TextStyle(fontSize: 13, color: Colors.amberAccent)),
              const SizedBox(height: 14),
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
