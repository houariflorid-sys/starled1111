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

class AmwKeyMap {
  final String label;
  final int address;
  final Map<String, int> keys;

  const AmwKeyMap({
    required this.label,
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
  bool _isScanning = false;
  Timer? _scanTimer;

  // أكواد AMW TV (RID: 5904) مع ترتيب الأزرار الدقيق لكل لوحة
  final List<AmwKeyMap> _amwMaps = const [
    // 1. لوحة AMW / Ali / Sunplus (0x866B) - الأكثر تطابقاً مع RID 5904
    AmwKeyMap(
      label: "M1: AMW-Ali (0x866B)",
      address: 0x866B,
      keys: {
        'POWER': 0x00,
        'MUTE': 0x01,
        'SOURCE': 0x03,
        'VOL_UP': 0x0C,
        'VOL_DOWN': 0x0D,
        'CH_UP': 0x0E,
        'CH_DOWN': 0x0F,
        'MENU': 0x10,
        'EXIT': 0x11,
        'OK': 0x16,
        'UP': 0x12,
        'DOWN': 0x13,
        'LEFT': 0x14,
        'RIGHT': 0x15,
        '0': 0x02,
        '1': 0x04,
        '2': 0x05,
        '3': 0x06,
        '4': 0x07,
        '5': 0x08,
        '6': 0x09,
        '7': 0x0A,
        '8': 0x0B,
        '9': 0x17,
      },
    ),
    // 2. لوحة AMW / MStar Extended (0x02FD)
    AmwKeyMap(
      label: "M2: AMW-MStar (0x02FD)",
      address: 0x02FD,
      keys: {
        'POWER': 0x01,
        'MUTE': 0x00,
        'SOURCE': 0x03,
        'VOL_UP': 0x0F,
        'VOL_DOWN': 0x13,
        'CH_UP': 0x0E,
        'CH_DOWN': 0x12,
        'MENU': 0x0D,
        'EXIT': 0x18,
        'OK': 0x15,
        'UP': 0x11,
        'DOWN': 0x19,
        'LEFT': 0x14,
        'RIGHT': 0x16,
        '0': 0x10,
        '1': 0x04,
        '2': 0x05,
        '3': 0x06,
        '4': 0x07,
        '5': 0x08,
        '6': 0x09,
        '7': 0x0A,
        '8': 0x0B,
        '9': 0x0C,
      },
    ),
    // 3. لوحة AMW / OEM-4040 (Extended NEC)
    AmwKeyMap(
      label: "M3: AMW-OEM (0x4040)",
      address: 0x4040,
      keys: {
        'POWER': 0x0A,
        'MUTE': 0x0C,
        'SOURCE': 0x0B,
        'VOL_UP': 0x1A,
        'VOL_DOWN': 0x1E,
        'CH_UP': 0x1B,
        'CH_DOWN': 0x1F,
        'MENU': 0x14,
        'EXIT': 0x1C,
        'OK': 0x0D,
        'UP': 0x0B,
        'DOWN': 0x0E,
        'LEFT': 0x0A,
        'RIGHT': 0x0C,
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
    // 4. لوحة AMW / China-01FE
    AmwKeyMap(
      label: "M4: AMW-China (0x01FE)",
      address: 0x01FE,
      keys: {
        'POWER': 0x48,
        'MUTE': 0x10,
        'SOURCE': 0x18,
        'VOL_UP': 0x1A,
        'VOL_DOWN': 0x1E,
        'CH_UP': 0x1B,
        'CH_DOWN': 0x1F,
        'MENU': 0x14,
        'EXIT': 0x1C,
        'OK': 0x0D,
        'UP': 0x0B,
        'DOWN': 0x0E,
        'LEFT': 0x0A,
        'RIGHT': 0x0C,
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
    // 5. لوحة AMW / 55AA (Extended NEC)
    AmwKeyMap(
      label: "M5: AMW-55AA (0x55AA)",
      address: 0x55AA,
      keys: {
        'POWER': 0x01,
        'MUTE': 0x02,
        'SOURCE': 0x03,
        'VOL_UP': 0x12,
        'VOL_DOWN': 0x13,
        'CH_UP': 0x10,
        'CH_DOWN': 0x11,
        'MENU': 0x14,
        'EXIT': 0x15,
        'OK': 0x1A,
        'UP': 0x16,
        'DOWN': 0x17,
        'LEFT': 0x18,
        'RIGHT': 0x19,
        '0': 0x00,
        '1': 0x04,
        '2': 0x05,
        '3': 0x06,
        '4': 0x07,
        '5': 0x08,
        '6': 0x09,
        '7': 0x0A,
        '8': 0x0B,
        '9': 0x0C,
      },
    ),
    // 6. لوحة AMW / 807F مع أوامر CVTE
    AmwKeyMap(
      label: "M6: AMW-CVTE (0x807F)",
      address: 0x807F,
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
    // إرسال الإطار + نبضة التكرار القياسية لـ NEC (9000, 2250, 560)
    return [...frame, 40000, 9000, 2250, 560];
  }

  Future<void> _sendKey(String keyName, String arabicName) async {
    HapticFeedback.mediumImpact();
    if (!_hasIrEmitter) return;

    final map = _amwMaps[_selectedMap];
    final int? cmd = map.keys[keyName];
    if (cmd == null) return;

    final List<int> pattern = _buildNecFrame(map.address, cmd);

    try {
      await _irChannel.invokeMethod('transmit', {
        'pattern': pattern,
        'frequency': 38000,
      });
      setState(() => _status = "${map.label} -> $arabicName");
    } catch (e) {
      setState(() => _status = "فشل الإرسال");
    }
  }

  void _toggleScan() {
    if (_isScanning) {
      _scanTimer?.cancel();
      setState(() {
        _isScanning = false;
        _status = "مثبت على: ${_amwMaps[_selectedMap].label}";
      });
    } else {
      setState(() => _isScanning = true);
      _sendKey('VOL_UP', 'رفع الصوت');
      _scanTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
        setState(() {
          _selectedMap = (_selectedMap + 1) % _amwMaps.length;
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
              label: Text(_isScanning ? "إيقاف" : "فحص (M1-M6)"),
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
