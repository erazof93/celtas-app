import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/data/models/user.dart';
import 'package:celtas_mobile/features/notifications/application/notification_providers.dart';
import 'package:celtas_mobile/features/profile/application/profile_providers.dart';
import 'package:celtas_mobile/shared/widgets/celtas_button.dart';
import 'package:celtas_mobile/shared/widgets/celtas_text_field.dart';
import 'package:celtas_mobile/shared/widgets/slow_backend_notice.dart';
import 'package:celtas_mobile/shared/widgets/svg_stroke_icon.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Perfil (mockup 08 · PERFIL).
///
/// Header con datos del usuario (`GET /users/me`, leído fresco de la BD) +
/// edición inline de `fullName`/`phone` (`PATCH /users/me` — `email` no es
/// editable, el backend lo rechaza) y menú de navegación (Direcciones
/// guardadas, Mis cupones, Historial de pedidos, Cerrar sesión).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _editing = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // El usuario pudo activar/desactivar el permiso desde Configuración del
  // sistema sin reiniciar la app (ej. volvió de `openSystemSettings()`) —
  // re-consulta el estado real cada vez que la app vuelve a foreground,
  // mismo patrón que `HomeScreen` con `businessHoursProvider`.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(notificationPermissionProvider.notifier).refresh();
    }
  }

  void _startEditing(User user) {
    _fullNameController.text = user.fullName;
    _phoneController.text = user.phone ?? '';
    setState(() {
      _editing = true;
      _error = null;
    });
  }

  void _cancelEditing() => setState(() {
        _editing = false;
        _error = null;
      });

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(profileProvider.notifier).updateProfile(
            fullName: _fullNameController.text.trim(),
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
          );
      if (mounted) {
        setState(() {
          _saving = false;
          _editing = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.message; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No se pudo actualizar el perfil. Inténtalo de nuevo.';
        });
      }
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CeltasColors.card,
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Vas a tener que volver a iniciar sesión para pedir.'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            style: TextButton.styleFrom(foregroundColor: CeltasColors.redLight),
            child: const Text('CERRAR SESIÓN'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).logout();
      // El router redirige a /login al pasar a unauthenticated.
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              child: Text(
                'Perfil',
                style: textTheme.headlineSmall?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: CeltasColors.cream,
                ),
              ),
            ),
            Expanded(
              child: profileAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: SlowBackendNotice(),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: _ProfileError(
                    message: error is ApiException
                        ? error.message
                        : 'No se pudo cargar tu perfil.',
                  ),
                ),
                data: (user) => ListView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  children: [
                    if (_editing)
                      _EditForm(
                        formKey: _formKey,
                        fullNameController: _fullNameController,
                        phoneController: _phoneController,
                        email: user.email,
                        saving: _saving,
                        error: _error,
                        onSave: _save,
                        onCancel: _cancelEditing,
                      )
                    else
                      _ProfileHeader(
                        user: user,
                        onEdit: () => _startEditing(user),
                      ),
                    const SizedBox(height: 28),
                    _MenuRow(
                      key: const ValueKey('profile-menu-addresses'),
                      icon: 'M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9',
                      label: 'Direcciones guardadas',
                      onTap: () => context.push('/addresses'),
                    ),
                    _MenuRow(
                      key: const ValueKey('profile-menu-coupons'),
                      icon: 'M20.6 12.5a1.9 1.9 0 0 1 0-2.9L21.8 8a2 2 0 0 0-2-3.4l-1.7.6'
                          'a1.9 1.9 0 0 1-2.5-1.5L15.3 2a2 2 0 0 0-3.9 0l-.3 1.7'
                          'a1.9 1.9 0 0 1-2.5 1.5L6.9 4.6A2 2 0 0 0 4.9 8l1.2 1.6'
                          'a1.9 1.9 0 0 1 0 2.9L4.9 14a2 2 0 0 0 2 3.4l1.7-.6'
                          'a1.9 1.9 0 0 1 2.5 1.5l.3 1.7a2 2 0 0 0 3.9 0l.3-1.7'
                          'a1.9 1.9 0 0 1 2.5-1.5l1.7.6a2 2 0 0 0 2-3.4z',
                      label: 'Mis cupones',
                      onTap: () => context.go('/coupons'),
                    ),
                    _MenuRow(
                      key: const ValueKey('profile-menu-orders'),
                      icon: 'M3 3h2l2.6 13h11.8L21 8H6'
                          'M9 18.6a1.4 1.4 0 1 0 0 2.8a1.4 1.4 0 1 0 0-2.8'
                          'M18 18.6a1.4 1.4 0 1 0 0 2.8a1.4 1.4 0 1 0 0-2.8',
                      label: 'Historial de pedidos',
                      onTap: () => context.go('/orders'),
                    ),
                    const _NotificationPermissionRow(
                      key: ValueKey('profile-menu-notifications'),
                    ),
                    _MenuRow(
                      key: const ValueKey('profile-menu-logout'),
                      icon: 'M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4'
                          'M16 17l5-5-5-5'
                          'M21 12H9',
                      label: 'Cerrar sesión',
                      color: CeltasColors.redLight,
                      iconColor: CeltasColors.redLight,
                      showChevron: false,
                      onTap: _confirmLogout,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header / avatar ────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user, required this.onEdit});

  final User user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: CeltasColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: CeltasColors.orange, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            _initials(user.fullName),
            style: textTheme.headlineSmall?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: CeltasColors.gold,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName,
                style: textTheme.bodyLarge?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: CeltasColors.cream,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.email,
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  color: CeltasColors.textMuted,
                ),
              ),
              if (user.phone != null && user.phone!.isNotEmpty)
                Text(
                  user.phone!,
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    color: CeltasColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
        GestureDetector(
          key: const ValueKey('profile-edit'),
          onTap: onEdit,
          child: const SvgStrokeIcon(
            path: 'M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4 12.5-12.5z'
                'M12 20h9',
            size: 18,
          ),
        ),
      ],
    );
  }

  /// Iniciales del avatar: primera letra de las dos primeras palabras del
  /// nombre (ej. "Ragnar Andersen" → "RA"), como en el mockup.
  String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '';
    final first = parts.first[0];
    final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }
}

class _EditForm extends StatelessWidget {
  const _EditForm({
    required this.formKey,
    required this.fullNameController,
    required this.phoneController,
    required this.email,
    required this.saving,
    required this.error,
    required this.onSave,
    required this.onCancel,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final TextEditingController phoneController;
  final String email;
  final bool saving;
  final String? error;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CeltasColors.surface,
        border: Border.all(color: CeltasColors.border),
        borderRadius: BorderRadius.circular(CeltasRadii.card),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EMAIL', style: textTheme.labelSmall),
            const SizedBox(height: 8),
            Text(
              email,
              style: textTheme.bodyLarge?.copyWith(
                fontSize: 15,
                color: CeltasColors.textSubtle,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'El email no se puede editar',
              style: textTheme.bodySmall?.copyWith(
                fontSize: 11.5,
                color: CeltasColors.textSubtle,
              ),
            ),
            const SizedBox(height: 14),
            CeltasTextField(
              key: const ValueKey('profile-fullname'),
              label: 'NOMBRE COMPLETO',
              controller: fullNameController,
              textInputAction: TextInputAction.next,
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'Ingresa tu nombre completo'
                  : null,
            ),
            const SizedBox(height: 12),
            CeltasTextField(
              key: const ValueKey('profile-phone'),
              label: 'TELÉFONO',
              controller: phoneController,
              hintText: '+51 999 999 999',
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => saving ? null : onSave(),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                style: textTheme.bodySmall?.copyWith(
                  color: CeltasColors.redLight,
                  fontSize: 12.5,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: saving ? null : onCancel,
                    style: TextButton.styleFrom(
                      foregroundColor: CeltasColors.textMuted,
                    ),
                    child: const Text('CANCELAR'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: CeltasButton(
                    key: const ValueKey('profile-save'),
                    label: 'GUARDAR CAMBIOS',
                    loading: saving,
                    onPressed: saving ? null : onSave,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Menú ───────────────────────────────────────────────────────────────────

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = CeltasColors.cream,
    this.iconColor = CeltasColors.orange,
    this.showChevron = true,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color iconColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: CeltasColors.divider)),
        ),
        child: Row(
          children: [
            SvgStrokeIcon(path: icon, size: 19, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
              ),
            ),
            if (showChevron)
              const SvgStrokeIcon(path: 'M9 6l6 6-6 6', size: 16),
          ],
        ),
      ),
    );
  }
}

/// Renglón "Notificaciones: Activadas/Desactivadas" — estado real leído con
/// `FirebaseMessaging.instance.getNotificationSettings()`
/// (`notificationPermissionProvider`), re-chequeado al volver de segundo
/// plano (`_ProfileScreenState.didChangeAppLifecycleState`).
///
/// Al tocarlo: si nunca se le preguntó (`notDetermined`), dispara el pedido
/// nativo normal; si ya lo rechazó (`denied`), abre Configuración del
/// sistema — `requestPermission()` no puede volver a mostrar el diálogo una
/// vez rechazado (confirmado contra la doc oficial de FlutterFire), así que
/// reintentarlo ahí no haría nada. Ver `actionForAuthorizationStatus`.
class _NotificationPermissionRow extends ConsumerWidget {
  const _NotificationPermissionRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(notificationPermissionProvider);
    final notifier = ref.read(notificationPermissionProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    // Mismo criterio que `HomeScreen`/`businessHoursProvider`: nunca solo
    // `valueOrNull` a secas para decidir el texto — se distingue "cargando"
    // y "error" explícitamente antes de mirar el valor.
    final (String trailingText, Color trailingColor) = statusAsync.hasError
        ? ('No se pudo verificar', CeltasColors.redLight)
        : switch (statusAsync.valueOrNull) {
            AuthorizationStatus.authorized ||
            AuthorizationStatus.provisional => (
              'Activadas',
              CeltasColors.textMuted,
            ),
            AuthorizationStatus.denied ||
            AuthorizationStatus.deniedPermanently ||
            AuthorizationStatus.notDetermined => (
              'Desactivadas',
              CeltasColors.redLight,
            ),
            null => ('', CeltasColors.textMuted),
          };

    return InkWell(
      key: const ValueKey('profile-notifications-tap'),
      onTap: statusAsync.isLoading
          ? null
          : statusAsync.hasError
          ? notifier.refresh
          : notifier.handleTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: CeltasColors.divider)),
        ),
        child: Row(
          children: [
            const SvgStrokeIcon(
              path:
                  'M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9'
                  'M13.7 21a2 2 0 0 1-3.4 0',
              size: 19,
              color: CeltasColors.orange,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Notificaciones',
                style: textTheme.bodyLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: CeltasColors.cream,
                ),
              ),
            ),
            if (statusAsync.isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                trailingText,
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: trailingColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileError extends ConsumerWidget {
  const _ProfileError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CeltasColors.surface,
        border: Border.all(color: CeltasColors.border),
        borderRadius: BorderRadius.circular(CeltasRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: CeltasColors.redLight,
                ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => ref.invalidate(profileProvider),
            style: TextButton.styleFrom(foregroundColor: CeltasColors.orange),
            child: const Text('REINTENTAR'),
          ),
        ],
      ),
    );
  }
}
