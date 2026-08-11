import 'package:celtas_mobile/app.dart';
import 'package:celtas_mobile/features/notifications/application/notification_service.dart';
import 'package:celtas_mobile/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Se crea el `ProviderContainer` a mano (en vez de dejar que `ProviderScope`
  // lo cree internamente) para que `NotificationService` pueda leer/invalidar
  // providers y navegar fuera del árbol de widgets — necesario porque
  // `getInitialMessage()` (notificación que abrió la app desde terminada) se
  // resuelve antes de que exista ningún `BuildContext`.
  final container = ProviderContainer();
  await NotificationService.instance.init(container);

  // `CeltasApp` es un `ConsumerWidget` (usa `ref.watch(routerProvider)`):
  // necesita un `ProviderScope` en la raíz o crashea con
  // "Bad state: No ProviderScope found".
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const CeltasApp(),
    ),
  );
}