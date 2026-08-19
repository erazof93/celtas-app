import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/addresses/application/address_providers.dart';
import 'package:celtas_mobile/features/addresses/data/models/address.dart';
import 'package:celtas_mobile/features/addresses/presentation/widgets/address_form_card.dart';
import 'package:celtas_mobile/features/cart/application/cart_provider.dart';
import 'package:celtas_mobile/features/checkout/application/checkout_providers.dart';
import 'package:celtas_mobile/features/orders/application/order_history_providers.dart';
import 'package:celtas_mobile/features/settings/application/settings_providers.dart';
import 'package:celtas_mobile/shared/widgets/business_closed_notice.dart';
import 'package:celtas_mobile/shared/widgets/celtas_button.dart';
import 'package:celtas_mobile/shared/widgets/slow_backend_notice.dart';
import 'package:celtas_mobile/shared/widgets/svg_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Checkout (mockup 07 · CHECKOUT).
///
/// Selector de dirección (`GET`/`POST /users/me/addresses`, mínimo para no
/// bloquear el checkout si el usuario no tiene ninguna guardada — el CRUD
/// completo es del módulo 6), resumen del pedido con el descuento del cupón
/// ya validado en el carrito (módulo 4), y confirmación por WhatsApp
/// (`POST /orders` → abre `whatsappUrl` con `url_launcher`). Nunca hay pago
/// dentro de la app.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String? _selectedAddressId;
  bool _selectionInitialized = false;
  bool _showAddForm = false;

  final _addressFormKey = GlobalKey<FormState>();
  final _aliasController = TextEditingController();
  final _fullAddressController = TextEditingController();
  final _referenceController = TextEditingController();
  final _districtController = TextEditingController();
  bool _addingAddress = false;
  String? _addAddressError;

  bool _confirming = false;
  String? _orderError;
  String? _pendingWhatsappUrl;

  @override
  void dispose() {
    _aliasController.dispose();
    _fullAddressController.dispose();
    _referenceController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  Future<void> _submitNewAddress() async {
    if (!_addressFormKey.currentState!.validate()) return;
    setState(() {
      _addingAddress = true;
      _addAddressError = null;
    });
    try {
      final created = await ref.read(addressListProvider.notifier).addAddress(
            alias: _aliasController.text.trim(),
            fullAddress: _fullAddressController.text.trim(),
            reference: _referenceController.text.trim().isEmpty
                ? null
                : _referenceController.text.trim(),
            district: _districtController.text.trim(),
          );
      if (!mounted) return;
      _aliasController.clear();
      _fullAddressController.clear();
      _referenceController.clear();
      _districtController.clear();
      setState(() {
        _addingAddress = false;
        _showAddForm = false;
        _selectedAddressId = created.id;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _addingAddress = false;
          _addAddressError = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _addingAddress = false;
          _addAddressError =
              'No se pudo guardar la dirección. Inténtalo de nuevo.';
        });
      }
    }
  }

  Future<void> _confirmOrder(CartState cart) async {
    final addressId = _selectedAddressId!;
    setState(() {
      _confirming = true;
      _orderError = null;
    });
    try {
      final result = await ref.read(orderRepositoryProvider).createOrder(
            items: cart.items,
            addressId: addressId,
            couponCode: cart.coupon?.code,
          );
      // El pedido ya quedó registrado en el backend en "pendiente" en este
      // punto (aunque WhatsApp no llegue a abrirse) — el carrito local ya
      // cumplió su función y se limpia para no reenviarlo por error.
      ref.read(cartProvider.notifier).clear();
      // Invalida el historial para que el pedido recién creado aparezca al
      // volver a la pestaña Pedidos, según la regla de "invalidar y
      // re-fetchear" — no se intenta insertarlo a mano en la lista local.
      ref.invalidate(orderListProvider);
      final opened = await _openWhatsapp(result.whatsappUrl);
      if (!mounted) return;
      if (opened) {
        context.go('/home');
        return;
      }
      setState(() {
        _confirming = false;
        _pendingWhatsappUrl = result.whatsappUrl;
        _orderError =
            'Tu pedido #${result.id} se registró, pero no pudimos abrir '
            'WhatsApp automáticamente. Verificá que esté instalado y tocá '
            '"Abrir WhatsApp" para enviarlo.';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      // 409: el local está cerrado (horario programado o cierre manual
      // desde el panel), verificado ANTES de tocar la base — no se creó
      // nada a medias. Es un bloqueo claro ("no puedes pedir ahora"), no un
      // error corregible como un cupón inválido, así que no se mezcla con
      // el resto de errores mostrados inline (`_orderError`): un diálogo
      // bloqueante fuerza que el cliente lo lea, con el carrito intacto
      // para reintentar más tarde.
      if (e.statusCode == 409) {
        setState(() => _confirming = false);
        await _showClosedDialog(e.message);
        return;
      }
      setState(() {
        _confirming = false;
        _orderError = e.message;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _confirming = false;
          _orderError = 'Ocurrió un error inesperado. Inténtalo de nuevo.';
        });
      }
    }
  }

  Future<void> _showClosedDialog(String message) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('checkout-closed-dialog'),
        backgroundColor: CeltasColors.card,
        title: Text(
          'Local cerrado',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: CeltasColors.cream,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: CeltasColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: CeltasColors.orange),
            child: const Text('ENTENDIDO'),
          ),
        ],
      ),
    );
  }

  Future<void> _retryOpenWhatsapp() async {
    final url = _pendingWhatsappUrl;
    if (url == null) return;
    final opened = await _openWhatsapp(url);
    if (!mounted) return;
    if (opened) {
      context.go('/home');
    } else {
      setState(() {
        _orderError =
            'Seguimos sin poder abrir WhatsApp. Verificá que la app esté '
            'instalada en este dispositivo.';
      });
    }
  }

  /// NO usa `canLaunchUrl` como gate: verificado en dispositivo real que
  /// devuelve `false` para `wa.me` aunque WhatsApp esté instalado — Android
  /// resuelve el intent `https://` con `resolveActivity(MATCH_DEFAULT_ONLY)`,
  /// que da `null` en cuanto hay más de una app candidata (WhatsApp Y el
  /// navegador) sin un default fijado, igual que documenta el propio paquete
  /// ("A false return value can indicate either that there is no handler
  /// available, or that the application does not have permission to check").
  /// `launchUrl` en cambio dispara el `Intent.ACTION_VIEW` real: si hay
  /// ambigüedad, Android muestra el selector de apps; si no hay ninguna,
  /// devuelve `false` o lanza `PlatformException` — ahí sí es una señal
  /// confiable de "no se pudo abrir".
  Future<bool> _openWhatsapp(String url) async {
    try {
      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } on PlatformException {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final addressesAsync = ref.watch(addressListProvider);
    final businessHoursAsync = ref.watch(businessHoursProvider);
    final textTheme = Theme.of(context).textTheme;

    addressesAsync.whenData((addresses) {
      if (_selectionInitialized) return;
      _selectionInitialized = true;
      if (addresses.isEmpty) {
        _showAddForm = true;
      } else {
        _selectedAddressId = addresses.first.id;
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
              child: Text(
                'Checkout',
                style: textTheme.headlineSmall?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: CeltasColors.cream,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
                children: [
                  // Aviso preventivo, NO el bloqueo real: solo evita que el
                  // cliente llene dirección/cupón para nada si ya se sabe de
                  // antemano que el local está cerrado. El local puede cerrar
                  // recién mientras el checkout está abierto, así que el 409
                  // real de `POST /orders` al confirmar sigue siendo la
                  // única fuente de verdad (`_showClosedDialog`) — este
                  // aviso no deshabilita el botón de confirmar.
                  if (businessHoursAsync.valueOrNull?.open == false) ...[
                    BusinessClosedNotice(
                      key: const ValueKey('checkout-closed-notice'),
                      message: businessHoursAsync.valueOrNull!.message ??
                          'El local está cerrado en este momento',
                    ),
                    const SizedBox(height: 18),
                  ],
                  Text('DIRECCIÓN DE ENTREGA', style: textTheme.labelSmall),
                  const SizedBox(height: 10),
                  _AddressSection(
                    addressesAsync: addressesAsync,
                    selectedAddressId: _selectedAddressId,
                    showAddForm: _showAddForm,
                    onSelect: (id) => setState(() {
                      _selectedAddressId = id;
                      _showAddForm = false;
                    }),
                    onToggleAddForm: () =>
                        setState(() => _showAddForm = !_showAddForm),
                    addForm: AddressFormCard(
                      title: 'Nueva dirección',
                      formKey: _addressFormKey,
                      aliasController: _aliasController,
                      fullAddressController: _fullAddressController,
                      referenceController: _referenceController,
                      districtController: _districtController,
                      submitting: _addingAddress,
                      error: _addAddressError,
                      onSubmit: _submitNewAddress,
                      onCancel: addressesAsync.valueOrNull?.isNotEmpty == true
                          ? () => setState(() => _showAddForm = false)
                          : null,
                      submitLabel: 'GUARDAR DIRECCIÓN',
                      aliasFieldKey: const ValueKey('checkout-address-alias'),
                      fullAddressFieldKey:
                          const ValueKey('checkout-address-full'),
                      districtFieldKey:
                          const ValueKey('checkout-address-district'),
                      referenceFieldKey:
                          const ValueKey('checkout-address-reference'),
                      submitButtonKey:
                          const ValueKey('checkout-address-save'),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('RESUMEN DEL PEDIDO', style: textTheme.labelSmall),
                  const SizedBox(height: 10),
                  for (final item in cart.items) ...[
                    _SummaryRow(
                      label: '${item.quantity}x ${item.name}',
                      value: 'S/ ${item.lineTotal.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 6),
                  Container(height: 1, color: CeltasColors.divider),
                  const SizedBox(height: 14),
                  _SummaryRow(
                    label: 'Subtotal',
                    value: 'S/ ${cart.subtotal.toStringAsFixed(2)}',
                    color: CeltasColors.textMuted,
                  ),
                  if (cart.coupon != null) ...[
                    const SizedBox(height: 6),
                    _SummaryRow(
                      label: 'Cupón ${cart.coupon!.code}',
                      value: '-S/ ${cart.discount.toStringAsFixed(2)}',
                      color: CeltasColors.gold,
                    ),
                  ],
                  const SizedBox(height: 6),
                  _SummaryRow(
                    label: 'Total',
                    value: 'S/ ${cart.total.toStringAsFixed(2)}',
                    weight: FontWeight.w800,
                    fontSize: 18,
                  ),
                  if (_orderError != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _orderError!,
                      style: textTheme.bodySmall?.copyWith(
                        color: CeltasColors.redLight,
                        fontSize: 13,
                      ),
                    ),
                    if (_pendingWhatsappUrl != null) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _retryOpenWhatsapp,
                        style: TextButton.styleFrom(
                          foregroundColor: CeltasColors.orange,
                        ),
                        child: const Text('ABRIR WHATSAPP'),
                      ),
                    ],
                  ],
                  if (_confirming) ...[
                    const SizedBox(height: 16),
                    const SlowBackendNotice(),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              decoration: const BoxDecoration(
                color: CeltasColors.black,
                border: Border(top: BorderSide(color: CeltasColors.divider)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_selectedAddressId == null) ...[
                    const _MissingAddressNotice(),
                    const SizedBox(height: 12),
                  ],
                  CeltasButton(
                    key: const ValueKey('checkout-confirm'),
                    angled: true,
                    label: 'CONFIRMAR PEDIDO POR WHATSAPP',
                    loading: _confirming,
                    icon: const _WhatsappIcon(),
                    onPressed:
                        cart.items.isEmpty ||
                            _confirming ||
                            _selectedAddressId == null
                        ? null
                        : () => _confirmOrder(cart),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Dirección ──────────────────────────────────────────────────────────────

class _AddressSection extends StatelessWidget {
  const _AddressSection({
    required this.addressesAsync,
    required this.selectedAddressId,
    required this.showAddForm,
    required this.onSelect,
    required this.onToggleAddForm,
    required this.addForm,
  });

  final AsyncValue<List<Address>> addressesAsync;
  final String? selectedAddressId;
  final bool showAddForm;
  final ValueChanged<String> onSelect;
  final VoidCallback onToggleAddForm;
  final Widget addForm;

  @override
  Widget build(BuildContext context) {
    return addressesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SlowBackendNotice(),
      ),
      error: (error, _) => _AddressError(
        message: error is ApiException
            ? error.message
            : 'No se pudieron cargar tus direcciones.',
      ),
      data: (addresses) {
        if (addresses.isEmpty) return addForm;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final address in addresses) ...[
              _AddressCard(
                address: address,
                selected: address.id == selectedAddressId,
                onTap: () => onSelect(address.id),
              ),
              const SizedBox(height: 10),
            ],
            if (showAddForm) ...[
              addForm,
              const SizedBox(height: 4),
            ] else
              GestureDetector(
                key: const ValueKey('checkout-add-address-toggle'),
                onTap: onToggleAddForm,
                child: Text(
                  '+ Agregar nueva dirección',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: CeltasColors.gold,
                      ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AddressError extends ConsumerWidget {
  const _AddressError({required this.message});

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
            onPressed: () => ref.invalidate(addressListProvider),
            style: TextButton.styleFrom(foregroundColor: CeltasColors.orange),
            child: const Text('REINTENTAR'),
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  final Address address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      key: ValueKey('checkout-address-${address.id}'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? CeltasColors.surfaceSelected : null,
          border: Border.all(
            color: selected ? CeltasColors.orange : CeltasColors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(CeltasRadii.card),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.home_rounded,
                        size: 15,
                        color: CeltasColors.orange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        address.alias,
                        style: textTheme.bodyLarge?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: CeltasColors.cream,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      address.fullAddress,
                      address.district,
                    ].join(', '),
                    style: textTheme.bodySmall?.copyWith(
                      fontSize: 12.5,
                      color: CeltasColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? CeltasColors.orange : null,
                border: selected
                    ? null
                    : Border.all(color: CeltasColors.borderStrong, width: 1.5),
              ),
              alignment: Alignment.center,
              child: selected
                  ? const Icon(
                      Icons.check,
                      size: 13,
                      color: CeltasColors.black,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Aviso de dirección faltante ───────────────────────────────────────────

/// Mismo patrón de "notice" que [SlowBackendNotice] (card + ícono + texto),
/// en tono gold de advertencia en vez de neutro, pegado al botón de
/// confirmar para que la relación "por qué está bloqueado" sea obvia.
class _MissingAddressNotice extends StatelessWidget {
  const _MissingAddressNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('checkout-missing-address-notice'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: CeltasColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(CeltasRadii.input),
        border: Border.all(color: CeltasColors.gold, width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: CeltasColors.gold,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Elegí o agregá una dirección de entrega para continuar',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: CeltasColors.gold,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Resumen ────────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.color = CeltasColors.cream,
    this.weight = FontWeight.w400,
    this.fontSize = 14,
  });

  final String label;
  final String value;
  final Color color;
  final FontWeight weight;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: fontSize,
          fontWeight: weight,
          color: color,
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}

// ─── Ícono de WhatsApp (fill, no stroke) ───────────────────────────────────

class _WhatsappIcon extends StatelessWidget {
  const _WhatsappIcon();

  static const _path =
      'M12 2a10 10 0 0 0-8.6 15L2 22l5.2-1.4A10 10 0 1 0 12 2zm5.8 14.2c-.2.7-1.4 1.3-2 1.4-.5.1-1.2.1-1.9-.1-.4-.1-1-.3-1.7-.6-3-1.3-4.9-4.3-5.1-4.5-.1-.2-1.2-1.6-1.2-3.1s.8-2.2 1-2.5c.2-.3.5-.4.7-.4h.5c.2 0 .4 0 .6.5.2.5.7 1.8.8 1.9.1.2.1.3 0 .5-.1.2-.1.3-.3.5-.1.2-.3.4-.4.5-.2.2-.3.4-.1.7.2.3.9 1.5 2 2.4 1.4 1.2 2.5 1.6 2.9 1.7.3.1.5.1.6-.1.2-.2.7-.8.9-1.1.2-.3.4-.2.6-.1.2.1 1.5.7 1.8.8.3.1.5.2.5.3.1.2.1.7-.1 1.3z';

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size.square(19),
      painter: _FillPathPainter(_path, CeltasColors.black),
    );
  }
}

class _FillPathPainter extends CustomPainter {
  const _FillPathPainter(this.path, this.color);

  final String path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    final scaled = parseSvgPath(path)
        .transform(Matrix4.diagonal3Values(scale, scale, 1).storage);
    canvas.drawPath(scaled, paint);
  }

  @override
  bool shouldRepaint(_FillPathPainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.color != color;
}
