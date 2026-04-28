import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  bool isStreaming = false;

  void setStreaming(bool value) {
    isStreaming = value;
    notifyListeners();
  }
}
