import 'dart:async';

import 'package:celtas_mobile/app.dart';
import 'package:celtas_mobile/core/startup/app_preparation_controller.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/notifications/application/notification_service.dart';
import 'package:celtas_mobile/shared/widgets/celtas_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows preparation before any app providers can consume configuration/storage.
class CeltasStartupApp extends StatefulWidget {
  const CeltasStartupApp({
    super.key,
    this.controller,
    this.disposeController = false,
  });
  final AppPreparationController? controller;
  final bool disposeController;

  @override
  State<CeltasStartupApp> createState() => _CeltasStartupAppState();
}

class _CeltasStartupAppState extends State<CeltasStartupApp> {
  late final AppPreparationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        AppPreparationController(notifications: NotificationService.instance);
    _controller.addListener(_changed);
    unawaited(_controller.prepare());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    if (widget.controller == null || widget.disposeController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.status == AppPreparationStatus.ready) {
      return UncontrolledProviderScope(
        container: _controller.container!,
        child: CeltasApp(notifications: _controller.notifications),
      );
    }
    final loading = _controller.status == AppPreparationStatus.loading;
    return MaterialApp(
      title: 'Celtas',
      debugShowCheckedModeBanner: false,
      // Preparation must not start font downloads before configuration is ready.
      // The named families fall back locally if fonts have not loaded yet.
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: CeltasColors.black,
        colorScheme: const ColorScheme.dark(
          primary: CeltasColors.orange,
          surface: CeltasColors.surface,
        ),
        fontFamily: 'Manrope',
      ),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(CeltasSpacing.page),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('CELTAS'),
                  const SizedBox(height: 24),
                  if (loading) const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    loading ? 'Preparando Celtas…' : _controller.errorMessage!,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  CeltasButton(
                    label: 'Reintentar',
                    onPressed: loading
                        ? null
                        : () => unawaited(_controller.prepare()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
