import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AstraApp());
}

class AstraApp extends StatelessWidget {
  const AstraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Astra Voice Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF080B18),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B7CFF),
          brightness: Brightness.dark,
        ),
      ),
      home: const AssistantHomePage(),
    );
  }
}

class AssistantHomePage extends StatefulWidget {
  const AssistantHomePage({super.key});

  @override
  State<AssistantHomePage> createState() => _AssistantHomePageState();
}

class _AssistantHomePageState extends State<AssistantHomePage> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _commandController = TextEditingController();

  bool _speechReady = false;
  bool _isListening = false;
  bool _isBusy = false;
  String _recognizedText = '';
  String _status = 'Tap the microphone and say a command';
  String _localeId = 'en_IN';

  @override
  void initState() {
    super.initState();
    _configureTts();
    _initializeSpeech();
  }

  Future<void> _configureTts() async {
    await _tts.setLanguage('en-IN');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
  }

  Future<void> _initializeSpeech() async {
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      if (mounted) {
        setState(() => _status = 'Microphone permission is required for voice commands.');
      }
      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        setState(() {
          _isListening = status == 'listening';
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _status = 'Speech recognition error: ${error.errorMsg}';
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _speechReady = available;
      _status = available
          ? 'Ready. Try “YouTube search cricket highlights”.'
          : 'Speech recognition is unavailable on this device.';
    });
  }

  Future<void> _startListening() async {
    if (_isBusy) return;

    if (!_speechReady) {
      await _initializeSpeech();
      if (!_speechReady) return;
    }

    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      await _speak('Please allow microphone permission in settings.');
      return;
    }

    await _tts.stop();
    setState(() {
      _recognizedText = '';
      _status = 'Listening…';
      _isListening = true;
    });

    await _speech.listen(
      localeId: _localeId,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      ),
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _recognizedText = result.recognizedWords;
          _commandController.text = result.recognizedWords;
          _commandController.selection = TextSelection.collapsed(
            offset: _commandController.text.length,
          );
        });

        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          _handleCommand(result.recognizedWords);
        }
      },
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
        _status = 'Listening stopped';
      });
    }
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // TTS is an enhancement; the on-screen status remains available.
    }
  }

  String _cleanCommand(String input) {
    var text = input.toLowerCase().trim();
    text = text.replaceFirst(
      RegExp(r'^(hey\s+astra|hi\s+astra|hello\s+astra|astra)\s*[, ]*'),
      '',
    );
    return text.trim();
  }

  Future<void> _handleCommand(String rawCommand) async {
    final command = _cleanCommand(rawCommand);
    if (command.isEmpty) return;

    setState(() {
      _isBusy = true;
      _recognizedText = rawCommand;
      _status = 'Processing: $rawCommand';
    });

    try {
      if (_matches(command, ['youtube', 'you tube', 'यूट्यूब'])) {
        await _handleYouTube(command);
      } else if (_matches(command, ['google', 'search', 'गूगल', 'सर्च', 'खोजो'])) {
        await _handleGoogle(command);
      } else if (_matches(command, ['whatsapp', 'व्हाट्सएप', 'व्हाट्स ऐप'])) {
        await _handleWhatsApp(command);
      } else if (_matches(command, ['call', 'phone', 'dial', 'कॉल', 'फोन', 'मिलाओ'])) {
        await _handleCall(command);
      } else if (_matches(command, ['stop', 'रुको', 'बंद करो'])) {
        await _speech.stop();
        await _tts.stop();
        _setStatus('Stopped.');
      } else if (_matches(command, ['hello', 'hi', 'नमस्ते', 'हेलो'])) {
        await _respond('Hello! I am Astra. What would you like me to do?');
      } else if (_matches(command, ['help', 'commands', 'मदद'])) {
        await _respond(
          'You can say: YouTube search cricket, Google search weather, '
          'open WhatsApp, WhatsApp number followed by a phone number, '
          'or call followed by a phone number.',
        );
      } else {
        await _respond('Sorry, I did not understand. Say help to hear example commands.');
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  bool _matches(String text, List<String> terms) => terms.any(text.contains);

  Future<void> _handleYouTube(String command) async {
    var query = command
        .replaceFirst(RegExp(r'^(open\s+)?(youtube|you tube|यूट्यूब)\s*'), '')
        .replaceFirst(RegExp(r'^(search|find|play|watch|पर खोजो|खोजो)\s*'), '')
        .trim();

    if (query.isEmpty || query == 'open') {
      await _openUri(Uri.parse('https://www.youtube.com/'));
      await _respond('Opening YouTube.');
      return;
    }

    final uri = Uri.https('www.youtube.com', '/results', {'search_query': query});
    await _openUri(uri);
    await _respond('Searching YouTube for $query.');
  }

  Future<void> _handleGoogle(String command) async {
    var query = command
        .replaceFirst(RegExp(r'^(open\s+)?google\s*'), '')
        .replaceFirst(RegExp(r'^(search|search for|find|सर्च करो|खोजो)\s*'), '')
        .trim();

    if (query.isEmpty || query == 'open') {
      await _openUri(Uri.parse('https://www.google.com/'));
      await _respond('Opening Google.');
      return;
    }

    final uri = Uri.https('www.google.com', '/search', {'q': query});
    await _openUri(uri);
    await _respond('Searching Google for $query.');
  }

  Future<void> _handleWhatsApp(String command) async {
    final digits = _extractPhoneNumber(command);
    if (digits != null) {
      // Opens a WhatsApp chat only. It does not send a message.
      await _openUri(Uri.parse('https://wa.me/$digits'));
      await _respond('Opening WhatsApp chat. Review the recipient before sending anything.');
      return;
    }

    await _openUri(Uri.parse('https://wa.me/'));
    await _respond('Opening WhatsApp. Choose the chat you want.');
  }

  Future<void> _handleCall(String command) async {
    final digits = _extractPhoneNumber(command);
    if (digits == null) {
      await _respond(
        'Please say call followed by a phone number. '
        'I cannot identify a contact by name in this version.',
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: digits);
    final launched = await launchUrl(uri);
    if (launched) {
      await _respond('Opening the phone dialer. Review the number and tap call if it is correct.');
      _setStatus('Dialer opened for $digits. No call was placed automatically.');
    } else {
      await _respond('I could not open the phone dialer on this device.');
    }
  }

  String? _extractPhoneNumber(String command) {
    final match = RegExp(r'(\+?\d[\d\s().-]{5,}\d)').firstMatch(command);
    if (match == null) return null;
    final digits = match.group(0)!.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || digits.length > 15) return null;
    return digits;
  }

  Future<void> _openUri(Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw PlatformException(
        code: 'URL_LAUNCH_FAILED',
        message: 'Could not open ${uri.toString()}',
      );
    }
  }

  Future<void> _respond(String message) async {
    if (!mounted) return;
    setState(() => _status = message);
    await _speak(message);
  }

  void _setStatus(String message) {
    if (mounted) setState(() => _status = message);
  }

  Future<void> _submitTypedCommand() async {
    final command = _commandController.text.trim();
    if (command.isEmpty) return;
    await _speech.stop();
    await _handleCommand(command);
  }

  @override
  void dispose() {
    _speech.cancel();
    _tts.stop();
    _commandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF111936), Color(0xFF090D1B), Color(0xFF080B18)],
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B7CFF).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: const Color(0xFF8B7CFF)),
                      ),
                      child: const Icon(Icons.graphic_eq_rounded, color: Color(0xFFB7AEFF), size: 27),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ASTRA', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 3)),
                          Text('VOICE ASSISTANT', style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.white54)),
                        ],
                      ),
                    ),
                    Icon(_speechReady ? Icons.check_circle : Icons.info_outline,
                        color: _speechReady ? Colors.greenAccent : Colors.orangeAccent),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF8B7CFF).withOpacity(0.28),
                      const Color(0xFF8B7CFF).withOpacity(0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: _isListening ? 142 : 126,
                    height: _isListening ? 142 : 126,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF7566E8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B7CFF).withOpacity(_isListening ? 0.55 : 0.25),
                          blurRadius: _isListening ? 42 : 25,
                          spreadRadius: _isListening ? 8 : 3,
                        ),
                      ],
                    ),
                    child: Icon(_isListening ? Icons.graphic_eq : Icons.mic_none_rounded, size: 58, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(_isListening ? 'I’M LISTENING' : 'HOW CAN I HELP?',
                  style: const TextStyle(fontSize: 13, letterSpacing: 3, fontWeight: FontWeight.w700, color: Colors.white70)),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  _recognizedText.isEmpty ? 'Try “YouTube search latest songs”' : '“$_recognizedText”',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Text(_status, textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, height: 1.4)),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: DropdownButtonFormField<String>(
                  value: _localeId,
                  dropdownColor: const Color(0xFF202744),
                  decoration: InputDecoration(
                    labelText: 'Speech language',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'en_IN', child: Text('English (India)')),
                    DropdownMenuItem(value: 'hi_IN', child: Text('हिन्दी')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _localeId = value);
                  },
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commandController,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _submitTypedCommand(),
                        decoration: InputDecoration(
                          hintText: 'Type a command…',
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    IconButton.filled(
                      onPressed: _submitTypedCommand,
                      icon: const Icon(Icons.send_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF7566E8),
                        minimumSize: const Size(52, 52),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
                child: SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: FilledButton.icon(
                    onPressed: _isBusy ? null : (_isListening ? _stopListening : _startListening),
                    icon: Icon(_isListening ? Icons.stop_rounded : Icons.mic_rounded),
                    label: Text(_isListening ? 'STOP LISTENING' : 'TAP TO SPEAK'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7566E8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
