import 'package:celtas_mobile/core/startup/celtas_startup_app.dart';
import 'package:celtas_mobile/core/startup/dev_preparation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const dev = bool.fromEnvironment('CELTAS_DEV');
  if (dev || appFlavor != null) {
    runApp(
      CeltasStartupApp(
        controller: devPreparation(
          flavor: appFlavor,
          enabled: dev,
          configuration: const String.fromEnvironment('CELTAS_DEV_ENV'),
        ),
        disposeController: true,
      ),
    );
  } else {
    runApp(const CeltasStartupApp());
  }
}
