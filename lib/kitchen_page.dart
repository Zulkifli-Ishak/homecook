import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class KitchenPage extends StatefulWidget {
  final Map<String, dynamic> recipeData;

  const KitchenPage({super.key, required this.recipeData});

  @override
  State<KitchenPage> createState() => _KitchenPageState();
}

class _KitchenPageState extends State<KitchenPage> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  
  bool _isListening = false;
  bool _isProcessing = false;
  int _currentStep = 0;
  List<String> _instructions = [];

  @override
  void initState() {
    super.initState();
    _prepareInstructions(); 
    _initSpeech();
    // Small delay to ensure engine is ready before speaking
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _speak(_instructions[_currentStep]);
    });
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  void _prepareInstructions() {
    String title = widget.recipeData['title'] ?? "this recipe";
    List rawSteps = widget.recipeData['instructions'] ?? [];

    setState(() {
      _instructions = [
        "Welcome to Homecook. Are you ready to make $title? Say Next to begin.",
        ...rawSteps.map((s) => s.toString()), 
        "You are done! Enjoy your delicious meal. Say Exit to finish."
      ];
    });
  }

  // --- Voice Logic ---
  Future _speak(String text) async {
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.speak(text);
  }

  void _initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) => debugPrint('onStatus: $status'),
      onError: (errorNotification) => debugPrint('onError: $errorNotification'),
    );
    if (available) {
      _startListening();
    } else {
      debugPrint("Speech recognition not available");
    }
  }

  void _startListening() async {
    if (_isProcessing) return;
    
    // Continuous listening
    await _speech.listen(
      onResult: (result) {
        if (_isProcessing) return;
        String words = result.recognizedWords.toLowerCase();
        
        // Simple command detection
        if (words.contains("next") || words.contains("forward") || words.contains("go")) {
          _moveStep(1);
        } else if (words.contains("back") || words.contains("previous")) {
          _moveStep(-1);
        } else if (words.contains("exit") || words.contains("stop")) {
          Navigator.pop(context);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      partialResults: true,
      localeId: "en_US",
      cancelOnError: false,
      listenMode: stt.ListenMode.dictation,
    );
    
    if (mounted) setState(() => _isListening = true);
  }

  void _moveStep(int direction) {
    int targetStep = _currentStep + direction;
    if (targetStep >= 0 && targetStep < _instructions.length) {
      setState(() {
        _isProcessing = true; // Stop listening while speaking
        _currentStep = targetStep;
      });
      
      _speech.stop(); // Stop listening explicitly
      _speak(_instructions[_currentStep]); 

      // Resume listening after speaking (approximate duration logic or simple delay)
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted) {
          setState(() => _isProcessing = false);
          _startListening();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.recipeData['title'] ?? 'Smart Kitchen'), 
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Visual feedback
            Icon(
              _isProcessing ? Icons.volume_up : Icons.mic, 
              color: _isProcessing ? Colors.orange : Colors.green, 
              size: 80
            ),
            const SizedBox(height: 20),
            Text(
              "Step ${_currentStep} of ${_instructions.length - 1}",
              style: TextStyle(color: Colors.grey[600], fontSize: 18),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.green[200]!)
              ),
              child: Text(
                _instructions.isNotEmpty ? _instructions[_currentStep] : "Loading...",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 50),
            const Text("Voice Commands:", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Chip(label: Text("Next")),
                SizedBox(width: 10),
                Chip(label: Text("Back")),
                SizedBox(width: 10),
                Chip(label: Text("Exit")),
              ],
            ),
            const SizedBox(height: 40),
            
            // Manual Controls (Backup)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () => _moveStep(-1),
                  child: const Text("Previous"),
                ),
                 ElevatedButton(
                  onPressed: () => _moveStep(1),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: const Text("Next Step"),
                ),
              ],
            ),
             const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context), 
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text("Stop Cooking"),
            ),
          ],
        ),
      ),
    );
  }
}