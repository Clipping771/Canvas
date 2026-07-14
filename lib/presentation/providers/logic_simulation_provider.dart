import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinci_board/engines/logic/tesla_engine.dart';

final teslaEngineProvider = Provider<TeslaEngine>((ref) {
  return TeslaEngine();
});
