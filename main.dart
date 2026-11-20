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

class StarLedRemoteScreen extends StatefulWidget {
  const StarLedRemoteScreen({super.key});

  @override
  State<StarLedRemoteScreen> createState() => _StarLedRemoteScreenState();
}

class _StarLedRemoteScreenState extends State<StarLedRemoteScreen> {
  static const MethodChannel _irChannel = MethodChannel('starled_ir_channel');
  bool _hasIrEmitter = false;
  String _status = "جاري فحص مستشعر IR...";
  int _addressCode = 0x807F;

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
      final bool hasIr = await _irChannel.invokeMethod('hasIrEmitter');
      setState(() {
        _hasIrEmitter = hasIr;
        _status = hasIr
            ? "مستشعر IR جاهز (0x${_addressCode.toRadixString(16).toUpperCase()})"
            : "الهاتف لا يدعم IR أو الإذن مرفوض";
      });
    } catch (e) {
      setState(() {
        _status = "خطأ في فحص مستشعر IR";
      });
    }
  }

  void _toggleAddressCode() {
    setState(() {
      _addressCode = (_addressCode == 0x807F) ? 0xFE01 : 0x807F;
      _status = "تم التبديل إلى الكود: 0x${_addressCode.toRadixString(16).toUpperCase()}";
    });
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

  Future<void> _sendKey(String keyName) async {
    HapticFeedback.mediumImpact();
    if (!_hasIrEmitter) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("مستشعر IR غير متاح على هذا الهاتف")),
      );
      return;
    }

    final int? cmd = _commands[keyName];
    if (cmd == null) return;

    final List<int> pattern = _buildNecPattern(_addressCode, cmd);
    try {
      await _irChannel.invokeMethod('transmit', {'pattern': pattern});
      setState(() => _status = "أُرسل: $keyName (0x${cmd.toRadixString(16).toUpperCase()})");
    } catch (e) {
      setState(() => _status = "فشل الإرسال: $e");
    }
  }

  Widget _btn(String label, String keyName, {Color? color, IconData? icon, double height = 48}) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => _sendKey(keyName),
        child: icon != null
            ? Icon(icon, size: 22)
            : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("StarLED HK320DF", style: TextStyle(fontSize: 18)),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          TextButton.icon(
            onPressed: _toggleAddressCode,
            icon: const Icon(Icons.swap_horiz, color: Colors.amberAccent, size: 20),
            label: Text(
              "0x${_addressCode.toRadixString(16).toUpperCase()}",
              style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
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
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: _hasIrEmitter ? Colors.teal.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _hasIrEmitter ? Colors.tealAccent.withOpacity(0.4) : Colors.redAccent),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.settings_remote, size: 18, color: _hasIrEmitter ? Colors.tealAccent : Colors.redAccent),
                    const SizedBox(width: 8),
                    Text(_status, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _btn("POWER", "POWER", color: Colors.red.shade700, icon: Icons.power_settings_new)),
                  const SizedBox(width: 10),
                  Expanded(child: _btn("SOURCE", "SOURCE", color: Colors.indigo.shade700)),
                  const SizedBox(width: 10),
                  Expanded(child: _btn("MUTE", "MUTE", color: Colors.teal.shade700, icon: Icons.volume_off)),
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
                  for (var num in ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'MENU', '0', 'EXIT'])
                    _btn(
                      num,
                      num,
                      color: (num == 'MENU' || num == 'EXIT') ? const Color(0xFF334155) : null,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _btn("VOL +", "VOL_UP", height: 54),
                        const SizedBox(height: 10),
                        _btn("VOL -", "VOL_DOWN", height: 54),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        SizedBox(width: 70, child: _btn("UP", "UP", icon: Icons.keyboard_arrow_up)),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(child: _btn("LEFT", "LEFT", icon: Icons.keyboard_arrow_left)),
                            const SizedBox(width: 6),
                            Expanded(child: _btn("OK", "OK", color: Colors.blue.shade700)),
                            const SizedBox(width: 6),
                            Expanded(child: _btn("RIGHT", "RIGHT", icon: Icons.keyboard_arrow_right)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SizedBox(width: 70, child: _btn("DOWN", "DOWN", icon: Icons.keyboard_arrow_down)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _btn("CH +", "CH_UP", height: 54),
                        const SizedBox(height: 10),
                        _btn("CH -", "CH_DOWN", height: 54),
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
