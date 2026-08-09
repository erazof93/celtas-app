import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/shared/widgets/celtas_button.dart';
import 'package:celtas_mobile/shared/widgets/celtas_text_field.dart';
import 'package:celtas_mobile/shared/widgets/slow_backend_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Registro (pantalla 03 del mockup): nombre completo, email, teléfono
/// (opcional) y contraseña.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
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
      await ref.read(authControllerProvider.notifier).register(
            fullName: _fullNameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            password: _passwordController.text,
          );
      // El router redirige a /home al pasar a authenticated.
    } catch (e) {
      setState(() {
        _errorMessage = e is ApiException
            ? e.message
            : 'Ocurrió un error inesperado. Inténtalo de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Flecha de volver.
                GestureDetector(
                  onTap: () => context.go('/login'),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: CeltasColors.cream,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Crear cuenta',
                  style: textTheme.headlineMedium?.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 6),
                Text(
                  'Unite a la horda. Pedí en minutos.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: CeltasColors.textMuted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 26),
                CeltasTextField(
                  label: 'NOMBRE COMPLETO',
                  controller: _fullNameController,
                  hintText: 'Ragnar Andersen',
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Ingresá tu nombre completo';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
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
                const SizedBox(height: 14),
                CeltasTextField(
                  label: 'TELÉFONO',
                  controller: _phoneController,
                  hintText: '+51 999 999 999',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                CeltasTextField(
                  label: 'CONTRASEÑA',
                  controller: _passwordController,
                  hintText: '••••••••',
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    final v = value ?? '';
                    if (v.isEmpty) return 'Ingresá una contraseña';
                    if (v.length < 8) {
                      return 'Mínimo 8 caracteres';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
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
                  label: 'CREAR CUENTA',
                  onPressed: _submitting ? null : _submit,
                  loading: _submitting,
                ),
                const SizedBox(height: 16),
                // Footer: ir a Login.
                Center(
                  child: Text.rich(
                    TextSpan(
                      text: '¿Ya tenés cuenta? ',
                      style: textTheme.bodyMedium?.copyWith(
                        color: CeltasColors.textMuted,
                        fontSize: 13,
                      ),
                      children: [
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: GestureDetector(
                            onTap: () => context.go('/login'),
                            child: Text(
                              'Iniciá sesión',
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