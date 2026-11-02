import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const AstraAssistantApp());
}

class AstraAssistantApp extends StatelessWidget {
  const AstraAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Astra AI Assistant',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const VoiceScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  String _textWords = "Tap mic or speak continuously...";
  String _lastCommand = "";
  bool _isContinuousMode = true; // Continuous listening flag

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _requestPermissions();
  }

  void _requestPermissions() async {
    await [Permission.microphone, Permission.phone].request();
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  // Continuous listening start karne ka function
  void _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (val) {
        debugPrint('onStatus: $val');
        if (val == 'notListening' && _isContinuousMode && !_isListening) {
          // Agar speech ruk jaye to automatically wapas start kar do (Continuous loop)
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _isContinuousMode) _startListening();
          });
        }
      },
      onError: (val) {
        debugPrint('onError: $val');
        if (_isContinuousMode) {
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted && _isContinuousMode) _startListening();
          });
        }
      },
    );

    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) {
          setState(() {
            _textWords = val.recognizedWords;
          });
          if (val.finalResult && val.recognizedWords.isNotEmpty) {
            _processCommand(val.recognizedWords);
          }
        },
        localeId: "en_IN", // Indian English accent ke liye
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  void _stopListening() {
    setState(() {
      _isListening = false;
      _isContinuousMode = false;
    });
    _speech.stop();
  }

  // Command process karne ke baad wapas listening mode me bhejne ka system
  void _processCommand(String command) async {
    String cmd = command.toLowerCase();
    setState(() {
      _lastCommand = cmd;
    });

    if (cmd.contains("youtube")) {
      await _speak("Opening YouTube");
      _launchURL("https://www.youtube.com");
    } else if (cmd.contains("google") || cmd.contains("search")) {
      await _speak("Searching Google");
      _launchURL("https://www.google.com");
    } else if (cmd.contains("whatsapp")) {
      await _speak("Opening WhatsApp");
      _launchURL("whatsapp://");
    } else if (cmd.contains("call")) {
      await _speak("Opening phone dialer");
      _launchURL("tel:");
    } else {
      await _speak("Command executed.");
    }

    // Action perform hone ke turant baad wapas listening resume kar do taaki user agli command de sake
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _isContinuousMode && !_isListening) {
        _startListening();
      }
    });
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Astra AI Assistant'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.deepPurpleAccent, width: 1.5),
              ),
              child: Column(
                children: [
                  const Text(
                    "Recognized Command:",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _textWords,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(
              _isListening ? "Listening continuously..." : "Assistant Paused",
              style: TextStyle(
                color: _isListening ? Colors.greenAccent : Colors.redAccent,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isContinuousMode = !_isContinuousMode;
                });
                if (_isContinuousMode) {
                  _startListening();
                } else {
                  _stopListening();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 90,
                width: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? Colors.green : Colors.deepPurple,
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? Colors.green : Colors.deepPurple).withOpacity(0.6),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_off,
                  color: Colors.white,
                  size: 45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
