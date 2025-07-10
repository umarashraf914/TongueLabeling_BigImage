import 'package:flutter/foundation.dart';

/// Holds the current evaluator name and how many iterations to show.
class DoctorProvider extends ChangeNotifier {
  String _name = '';
  int _iterations = 1;

  String get name => _name;
  set name(String n) {
    _name = n;
    notifyListeners();
  }

  int get iterations => _iterations;
  set iterations(int i) {
    _iterations = i;
    notifyListeners();
  }
}
