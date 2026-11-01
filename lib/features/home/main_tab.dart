import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 0 Home, 1 Booking, 2 Chat, 3 Profile
final mainTabProvider = NotifierProvider<MainTab, int>(MainTab.new);

class MainTab extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}