import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/data/auth_repository.dart';
import 'package:celtas_mobile/shared/widgets/celtas_button.dart';
import 'package:celtas_mobile/shared/widgets/celtas_flame.dart';
import 'package:celtas_mobile/shared/widgets/celtas_text_field.dart';
import 'package:celtas_mobile/shared/widgets/google_logo.dart';
import 'package:celtas_mobile/shared/widgets/slow_backend_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Login (pantalla 02 del mockup): email + password, o continuar con Google.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  bool _googleSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      // El router redirige a /home al pasar a authenticated.
    } catch (e) {
      setState(() {
        _errorMessage = _messageFor(e);
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _messageFor(Object e) {
    if (e is ApiException) return e.message;
    return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
  }

  /// Login con Google: la SDK abre el picker, obtiene el `idToken` y el
  /// backend lo verifica (`POST /auth/google`). Si el usuario cierra el picker
  /// no es un error: no se muestra ningún mensaje.
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _googleSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).loginWithGoogle();
      // El router redirige a /home al pasar a authenticated.
    } on GoogleSignInCanceledException {
      // El usuario cerró el picker de Google: no es un error.
    } catch (e) {
      setState(() {
        _errorMessage = _messageFor(e);
      });
    } finally {
      if (mounted) setState(() => _googleSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: llama + CELTAS.
                Row(
                  children: [
                    const CeltasFlame(),
                    const SizedBox(width: 9),
                    Text(
                      'CELTAS',
                      style: textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Text(
                  'Bienvenido de nuevo',
                  style: textTheme.headlineMedium?.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 6),
                Text(
                  'Iniciá sesión para pedir tu próxima comida',
                  style: textTheme.bodyMedium?.copyWith(
                    color: CeltasColors.textMuted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                CeltasTextField(
                  label: 'EMAIL',
                  controller: _emailController,
                  hintText: 'tu@email.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Ingresá tu email';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
                      return 'Email inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                CeltasTextField(
                  label: 'CONTRASEÑA',
                  controller: _passwordController,
                  hintText: '••••••••',
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if ((value ?? '').isEmpty) return 'Ingresá tu contraseña';
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Recuperación de contraseña próximamente'),
                        ),
                      );
                    },
                    child: Text(
                      '¿Olvidaste tu contraseña?',
                      style: textTheme.bodyMedium?.copyWith(
                        color: CeltasColors.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: textTheme.bodySmall?.copyWith(
                      color: CeltasColors.redLight,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_submitting) const SlowBackendNotice(),
                if (_submitting) const SizedBox(height: 12),
                CeltasButton(
                  label: 'INICIAR SESIÓN',
                  onPressed: _submitting ? null : _submit,
                  loading: _submitting,
                ),
                const SizedBox(height: 22),
                // Divider "o continuá con".
                Row(
                  children: [
                    const Expanded(child: Divider(color: CeltasColors.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'o continuá con',
                        style: textTheme.bodySmall?.copyWith(
                          color: CeltasColors.placeholder,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: CeltasColors.border)),
                  ],
                ),
                const SizedBox(height: 22),
                // Botón de Google: login con la SDK real (idToken →
                // POST /auth/google). El picker de Google es nativo; el
                // `POST /auth/google` puede tardar por el cold start de Render.
                SizedBox(
                  width: double.infinity,
                  child: Material(
                    color: CeltasColors.surface,
                    borderRadius: BorderRadius.circular(CeltasRadii.input),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(CeltasRadii.input),
                      onTap: _googleSubmitting ? null : _handleGoogleSignIn,
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const GoogleLogo(),
                            const SizedBox(width: 10),
                            Text(
                              _googleSubmitting
                                  ? 'Conectando con Google…'
                                  : 'Continuar con Google',
                              style: textTheme.bodyLarge?.copyWith(
                                color: CeltasColors.textSubtle,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_googleSubmitting) ...[
                  const SizedBox(height: 12),
                  const SlowBackendNotice(),
                ],
                const SizedBox(height: 16),
                // Footer: ir a Registro.
                Center(
                  child: Text.rich(
                    TextSpan(
                      text: '¿No tenés cuenta? ',
                      style: textTheme.bodyMedium?.copyWith(
                        color: CeltasColors.textMuted,
                        fontSize: 13,
                      ),
                      children: [
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: GestureDetector(
                            onTap: () => context.go('/register'),
                            child: Text(
                              'Registrate',
                              style: textTheme.bodyMedium?.copyWith(
                                color: CeltasColors.gold,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}