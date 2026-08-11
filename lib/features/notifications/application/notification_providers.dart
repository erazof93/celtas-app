import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/notifications/data/notification_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repositorio de notificaciones push contra el backend real.
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ApiClient.instance.dio),
);
