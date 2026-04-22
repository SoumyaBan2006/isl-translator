import 'dart:async';

class SignBuffer {
  final List<String> _signs = [];
  Timer? _pauseTimer;
  String _lastSign = '';
  final Function(List<String>) onSentenceReady;

  SignBuffer({required this.onSentenceReady});

  void addSign(String sign) {
    if (sign.isEmpty || sign == _lastSign) return;
    _lastSign = sign;
    _signs.add(sign);

    _pauseTimer?.cancel();
    _pauseTimer = Timer(const Duration(seconds: 2), () {
      if (_signs.isNotEmpty) {
        onSentenceReady(List.from(_signs));
        _signs.clear();
        _lastSign = '';
      }
    });
  }

  List<String> get currentSigns => List.from(_signs);

  void clear() {
    _signs.clear();
    _lastSign = '';
    _pauseTimer?.cancel();
  }

  void dispose() {
    _pauseTimer?.cancel();
  }
}