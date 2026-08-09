import 'package:celtas_mobile/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  // `CeltasApp` es un `ConsumerWidget` (usa `ref.watch(routerProvider)`):
  // necesita un `ProviderScope` en la raíz o crashea con
  // "Bad state: No ProviderScope found".
  runApp(const ProviderScope(child: CeltasApp()));
}