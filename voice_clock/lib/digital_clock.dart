// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_clock_helper/model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum _Element {
  background,
  text,
  shadow,
}

final _lightTheme = {
  _Element.background: Color(0xFF81B3FE),
  _Element.text: Colors.white,
  _Element.shadow: Colors.black,
};

final _darkTheme = {
  _Element.background: Colors.black,
  _Element.text: Colors.white,
  _Element.shadow: Color(0xFF174EA6),
};

/// A basic digital clock.
///
/// You can do better than this!
class DigitalClock extends StatefulWidget {
  const DigitalClock(this.model);

  final ClockModel model;

  @override
  _DigitalClockState createState() => _DigitalClockState();
}

class _DigitalClockState extends State<DigitalClock> {
  DateTime _dateTime = DateTime.now();
  Timer _timer;
  Map<_Element, Color> _colors = _lightTheme;

  // STT
  final SpeechToText speech = SpeechToText();
  bool _hasSpeech = false;
  bool _stressTest = false;
  double level = 0.0;
  int _stressLoops = 0;
  String lastWords = "";
  String lastError = "";
  String lastStatus = "";
  String _currentLocaleId = "";
  List<LocaleName> _localeNames = [];

  // TTS
  FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();

    _setupHotwordMethodChannel();
    _setupConfigMethodChannel();

    widget.model.addListener(_updateModel);
    _updateTime();
    _updateModel();

    initSpeechState();
  }

  Future<void> initSpeechState() async {
    bool hasSpeech = await speech.initialize(
        onError: errorListener, onStatus: statusListener);
    if (hasSpeech) {
      _localeNames = await speech.locales();

      var systemLocale = await speech.systemLocale();
      _currentLocaleId = systemLocale.localeId;
    }

    if (!mounted) return;

    setState(() {
      _hasSpeech = hasSpeech;
    });
  }

  @override
  void didUpdateWidget(DigitalClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.model != oldWidget.model) {
      oldWidget.model.removeListener(_updateModel);
      widget.model.addListener(_updateModel);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.model.removeListener(_updateModel);
    widget.model.dispose();
    super.dispose();
  }

  void _updateModel() {
    setState(() {
      // Cause the clock to rebuild when the model changes.
    });
  }

  void _updateTime() {
    setState(() {
      _dateTime = DateTime.now();
      _timer = Timer(
        Duration(minutes: 1) - Duration(seconds: _dateTime.second) - Duration(milliseconds: _dateTime.millisecond),
        _updateTime,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateFormat(widget.model.is24HourFormat ? 'HH' : 'hh').format(_dateTime);
    final minute = DateFormat('mm').format(_dateTime);
    final fontSize = MediaQuery.of(context).size.width / 3.5;
    final offset = -fontSize / 7;
    final defaultStyle = TextStyle(
      color: _colors[_Element.text],
      fontFamily: 'PressStart2P',
      fontSize: fontSize,
      shadows: [
        Shadow(
          blurRadius: 0,
          color: _colors[_Element.shadow],
          offset: Offset(10, 0),
        ),
      ],
    );

    return Container(
      color: _colors[_Element.background],
      child: Center(
        child: DefaultTextStyle(
          style: defaultStyle,
          child: Stack(
            children: <Widget>[
              Positioned(left: offset, top: 0, child: Text(hour)),
              Positioned(right: offset, bottom: offset, child: Text(minute)),
              Positioned(
                left: 0,
                bottom: 0,
                child: IconButton(
                  icon: Icon(Icons.mic),
                  onPressed: () => speechToText(),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  speechToText() async {
    print("speechToText");
    if (speech.isListening) {
      stopListening();
    } else {
      startListening();
    }
  }

  void stressTest() {
    if (_stressTest) {
      return;
    }
    _stressLoops = 0;
    _stressTest = true;
    print("Starting stress test...");
    startListening();
  }

  void changeStatusForStress(String status) {
    if (!_stressTest) {
      return;
    }
    if (speech.isListening) {
      stopListening();
    } else {
      if (_stressLoops >= 100) {
        _stressTest = false;
        print("Stress test complete.");
        return;
      }
      print("Stress loop: $_stressLoops");
      ++_stressLoops;
      startListening();
    }
  }

  void startListening() {
    lastWords = "";
    lastError = "";
    speech.listen(
        onResult: resultListener,
        listenFor: Duration(seconds: 10),
        localeId: _currentLocaleId,
        onSoundLevelChange: soundLevelListener );
    setState(() {});
  }

  void stopListening() {
    speech.stop();
    setState(() {
      level = 0.0;
    });
  }

  void cancelListening() {
    speech.cancel();
    setState(() {
      level = 0.0;
    });
  }

  void resultListener(SpeechRecognitionResult result) async {
    if (result.finalResult) {
      String tts = "Setting to";
      String words = result.recognizedWords.toLowerCase();
      if (words.contains("light")) {
        tts += " light theme,";
        setState(() {
          _colors = _lightTheme;
        });
      }

      if (words.contains("dark")) {
        tts += " dark theme,";
        setState(() {
          _colors = _darkTheme;
        });
      }

      if (words.contains("12") || words.contains("twelve")) {
        tts += " twelve hour format,";
        setState(() {
          widget.model.is24HourFormat = false;
        });
      }

      if (words.contains("24") || words.contains("twenty-four")) {
        tts += " twenty four hour format";
        setState(() {
          widget.model.is24HourFormat = true;
        });
      }

      if (tts != "Setting to") {
        flutterTts.setSpeechRate(0.4);
        flutterTts.speak(tts);
      }

      await MethodChannel('dev.elainedb.voice_clock/stt').invokeMethod('final', '');
    }

    setState(() {
      lastWords = "${result.recognizedWords} - ${result.finalResult}";
    });
  }

  void soundLevelListener(double level) {
    setState(() {
      this.level = level;
    });
  }

  void errorListener(SpeechRecognitionError error) {
    setState(() {
      lastError = "${error.errorMsg} - ${error.permanent}";
    });
  }

  void statusListener(String status) {
    changeStatusForStress(status);
    setState(() {
      lastStatus = "$status";
    });
  }

  void _setupHotwordMethodChannel() {
    MethodChannel('dev.elainedb.voice_clock/hotword').setMethodCallHandler((MethodCall call) async {
      print(call.method + " " + call.arguments);
      if (call.method == "hotword") {
        speechToText();
      }
    });
  }

  void _setupConfigMethodChannel() {
    MethodChannel('dev.elainedb.voice_clock/config').setMethodCallHandler((MethodCall call) async {
      print(call.method + " " + call.arguments);
      if (call.method == "dark") {
        setState(() {
          _colors = _darkTheme;
        });
        flutterTts.setSpeechRate(0.4);
        flutterTts.speak('Setting to dark theme from app actions.');
      }
    });
  }
}
