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
  int _rangeIndex = 0; // 0: 00-5F, 1: 60-AF, 2: B0-FF
  final Set<int> _testedNow = {};
  int? _lastCode;

  // جميع الأكواد الـ 24 المؤكدة بنظام LSB (العنوان 0x20DF)
  final Map<String, int> _keys = const {
    'POWER': 0x48,
    'SOURCE': 0x40,
    'GUIDE': 0x50,
    'MENU': 0x4A,
    'MUTE': 0x0B,
    'VOL_UP': 0x5C,
    'VOL_DOWN': 0x0C,
    'CH_UP': 0x5D,
    'CH_DOWN': 0x5E,
    'CH_LIST': 0x0E,
    'ASPECT': 0x53,
    'SLEEP': 0x5A,
    'PIC_MODE': 0x4C,
    'SND_MODE': 0x06,
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

  // تمييز جميع الأكواد المؤكدة باللون الأخضر في كاشف القوائم
  final Map<int, String> _confirmedLabels = const {
    0x00: '1',
    0x06: 'SND',
    0x0B: 'MUTE',
    0x0C: 'VOL-',
    0x0E: 'LIST',
    0x10: '2',
    0x11: '3',
    0x13: '4',
    0x14: '5',
    0x15: '6',
    0x17: '7',
    0x18: '8',
    0x19: '9',
    0x1B: '0',
    0x40: 'SRC',
    0x48: 'PWR',
    0x4A: 'MENU',
    0x4C: 'PIC',
    0x50: 'EPG',
    0x53: '16:9',
    0x5A: 'SLP',
    0x5C: 'VOL+',
    0x5D: 'CH+',
    0x5E: 'CH-',
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
        _status = hasIr ? "جاهز - AMW TV (5904)" : "مستشعر IR غير متاح";
      });
    } catch (e) {
      setState(() => _status = "خطأ في المستشعر");
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

  Future<void> _sendRawCode(int cmdLsb, String label, {bool trackTested = false}) async {
    HapticFeedback.mediumImpact();
    if (!_hasIrEmitter) return;

    final String hex = "0x${cmdLsb.toRadixString(16).toUpperCase().padLeft(2, '0')}";

    try {
      await _irChannel.invokeMethod('transmit', {
        'pattern': _buildLsbSignal(cmdLsb),
        'frequency': 38000,
      });
      setState(() {
        if (trackTested) {
          _testedNow.add(cmdLsb);
          _lastCode = cmdLsb;
        }
        _status = "$label  |  $hex";
      });
    } catch (e) {
      setState(() => _status = "فشل الإرسال");
    }
  }

  Future<void> _sendKey(String keyName, String arabicLabel) async {
    final int? cmd = _keys[keyName];
    if (cmd == null) return;
    await _sendRawCode(cmd, arabicLabel);
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

  Widget _buildRemoteTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        children: [
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
              _btn("CH LIST", "CH_LIST", "قائمة القنوات", color: const Color(0xFF334155)),
              _btn("0", "0", "رقم 0"),
              _btn("MENU", "MENU", "القائمة", color: const Color(0xFF334155)),
            ],
          ),
          const SizedBox(height: 14),
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
                    SizedBox(width: 70, child: _btn("UP", "CH_UP", "القناة الأعلى", icon: Icons.keyboard_arrow_up)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(child: _btn("LEFT", "VOL_DOWN", "تنقيص الصوت", icon: Icons.keyboard_arrow_left)),
                        const SizedBox(width: 6),
                        Expanded(child: _btn("OK", "CH_LIST", "قائمة القنوات", color: Colors.blue.shade700)),
                        const SizedBox(width: 6),
                        Expanded(child: _btn("RIGHT", "VOL_UP", "زيادة الصوت", icon: Icons.keyboard_arrow_right)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(width: 70, child: _btn("DOWN", "CH_DOWN", "القناة السفلى", icon: Icons.keyboard_arrow_down)),
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
                    _btn("CH -", "CH_DOWN", "القناة السابقة", height: 52),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuFinderTab() {
    final int start = _rangeIndex == 0 ? 0x00 : (_rangeIndex == 1 ? 0x60 : 0xB0);
    final int count = _rangeIndex == 0 ? 96 : 80;

    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        children: [
          // أزرار سريعة لفتح القائمة أو قائمة القنوات أثناء الفحص
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () => _sendRawCode(0x0E, "قائمة القنوات"),
                  icon: const Icon(Icons.list, size: 18),
                  label: const Text("قائمة القنوات", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () => _sendRawCode(0x4A, "القائمة"),
                  icon: const Icon(Icons.menu, size: 18),
                  label: const Text("القائمة", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: "تصفير الألوان",
                style: IconButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                onPressed: () => setState(() {
                  _testedNow.clear();
                  _lastCode = null;
                }),
                icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _rangeIndex == 0 ? Colors.teal.shade700 : const Color(0xFF1E293B),
                  ),
                  onPressed: () => setState(() => _rangeIndex = 0),
                  child: const Text("00 - 5F", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _rangeIndex == 1 ? Colors.teal.shade700 : const Color(0xFF1E293B),
                  ),
                  onPressed: () => setState(() => _rangeIndex = 1),
                  child: const Text("60 - AF", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _rangeIndex == 2 ? Colors.teal.shade700 : const Color(0xFF1E293B),
                  ),
                  onPressed: () => setState(() => _rangeIndex = 2),
                  child: const Text("B0 - FF", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "افتح قائمة القنوات أولاً ثم جرّب الأزرار الزرقاء (الأخضر = محفوظ، البنفسجي = جُرّب الآن)",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1.65,
              ),
              itemCount: count,
              itemBuilder: (context, index) {
                final int code = start + index;
                final String hex = code.toRadixString(16).toUpperCase().padLeft(2, '0');
                final String? confirmed = _confirmedLabels[code];
                final bool tested = _testedNow.contains(code);
                final bool isLast = _lastCode == code;

                Color bgColor = Colors.indigo.shade700;
                if (confirmed != null) {
                  bgColor = Colors.green.shade800;
                } else if (tested) {
                  bgColor = Colors.deepPurple.shade400;
                }

                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: bgColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    side: isLast ? const BorderSide(color: Colors.amberAccent, width: 2) : BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _sendRawCode(code, confirmed ?? "تجربة", trackTested: confirmed == null),
                  child: Text(
                    confirmed != null ? "$hex\n$confirmed" : hex,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("AMW Remote", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF1E293B),
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: Colors.tealAccent,
            labelColor: Colors.tealAccent,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: "الريموت"),
              Tab(text: "كاشف القوائم"),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.tealAccent.withOpacity(0.4)),
                ),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.tealAccent, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildRemoteTab(),
                    _buildMenuFinderTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
