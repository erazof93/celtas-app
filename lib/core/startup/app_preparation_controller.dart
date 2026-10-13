import 'dart:async';

import 'package:celtas_mobile/core/config/app_environment.dart';
import 'package:celtas_mobile/core/router/app_router.dart';
import 'package:celtas_mobile/core/startup/initialization_operation.dart';
import 'package:celtas_mobile/features/addresses/data/address_selection_storage.dart';
import 'package:celtas_mobile/features/cart/data/cart_storage.dart';
import 'package:celtas_mobile/features/notifications/application/notification_service.dart';
import 'package:celtas_mobile/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppPreparationStatus { loading, error, ready }

class AppPreparationController extends ChangeNotifier {
  AppPreparationController({
    Future<void> Function()? loadConfiguration,
    Future<SharedPreferences> Function()? loadPreferences,
    Future<void> Function()? initializeFirebase,
    ProviderContainer Function(SharedPreferences)? createContainer,
    this.notifications,
  }) : _configuration = InitializationOperation(
         loadConfiguration ?? dotenv.load,
       ),
       _preferences = InitializationOperation(
         loadPreferences ?? SharedPreferences.getInstance,
       ),
       _firebase = InitializationOperation(
         initializeFirebase ??
             () async {
               await Firebase.initializeApp(
                 options: DefaultFirebaseOptions.currentPlatform,
               );
             },
       ),
       _createContainer = createContainer ?? _containerWithStorage;

  final InitializationOperation<void> _configuration;
  final InitializationOperation<SharedPreferences> _preferences;
  final InitializationOperation<void> _firebase;
  final ProviderContainer Function(SharedPreferences) _createContainer;
  final NotificationService? notifications;

  AppPreparationStatus status = AppPreparationStatus.loading;
  String? errorMessage;
  ProviderContainer? container;
  Completer<void>? _attempt;
  Timer? _deadline;
  bool _disposed = false;

  static ProviderContainer _containerWithStorage(SharedPreferences prefs) =>
      ProviderContainer(
        overrides: [
          cartStorageProvider.overrideWithValue(CartStorage(prefs)),
          addressSelectionStorageProvider.overrideWithValue(
            AddressSelectionStorage(prefs),
          ),
        ],
      );

  Future<void> prepare() {
    if (_disposed || status == AppPreparationStatus.ready) {
      return Future.value();
    }
    if (_attempt != null) return _attempt!.future;
    final attempt = Completer<void>();
    _attempt = attempt;
    status = AppPreparationStatus.loading;
    errorMessage = null;
    notifyListeners();
    notifications?.captureEvents();
    _deadline = Timer(const Duration(seconds: 20), () {
      if (!_current(attempt)) return;
      status = AppPreparationStatus.error;
      errorMessage =
          'La preparación está tardando demasiado. Puedes reintentar.';
      _finish(attempt);
      notifyListeners();
    });
    unawaited(_prepare(attempt));
    return attempt.future;
  }

  bool _current(Completer<void> attempt) =>
      !_disposed && identical(_attempt, attempt);

  Future<void> _prepare(Completer<void> attempt) async {
    try {
      await _configuration.run();
      if (!_current(attempt)) return;
      final prefs = await _preferences.run();
      if (!_current(attempt)) return;
      await _firebase.run();
      if (!_current(attempt)) return;
      // No provisional container/storage: providers can only start with real
      // configuration, hydrated preferences and a ready Firebase SDK.
      container ??= _createContainer(prefs);
      final service = notifications;
      if (service != null) {
        unawaited(
          service.init(container!).catchError((Object error, StackTrace stack) {
            debugPrint('Notification attachment failed: ${error.runtimeType}');
          }),
        );
      }
      status = AppPreparationStatus.ready;
    } catch (error) {
      if (!_current(attempt)) return;
      status = AppPreparationStatus.error;
      errorMessage = error is ConfigurationException
          ? error.message
          : 'No pudimos preparar Celtas. Inténtalo nuevamente.';
    } finally {
      if (_current(attempt)) {
        _finish(attempt);
        notifyListeners();
      }
    }
  }

  void _finish(Completer<void> attempt) {
    _deadline?.cancel();
    _attempt = null;
    if (!attempt.isCompleted) attempt.complete();
  }

  @override
  void dispose() {
    _disposed = true;
    final attempt = _attempt;
    if (attempt != null) _finish(attempt);
    notifications?.dispose();
    final prepared = container;
    if (prepared != null) {
      if (prepared.exists(routerProvider)) {
        prepared.read(routerProvider).dispose();
      }
      prepared.dispose();
    }
    super.dispose();
  }
}
