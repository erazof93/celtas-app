import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/addresses/application/address_providers.dart';
import 'package:celtas_mobile/features/addresses/data/models/address.dart';
import 'package:celtas_mobile/features/addresses/presentation/widgets/address_form_card.dart';
import 'package:celtas_mobile/shared/widgets/slow_backend_notice.dart';
import 'package:celtas_mobile/shared/widgets/svg_stroke_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

/// Direcciones guardadas (mockup 09 · DIRECCIONES GUARDADAS).
///
/// CRUD completo (`GET`/`POST`/`PATCH`/`DELETE /users/me/addresses`): listar,
/// crear (formulario inline, igual que el mínimo del checkout pero con el
/// toggle de "principal"), editar (mismo formulario, precargado, en el lugar
/// de la tarjeta) y eliminar (con confirmación).
class AddressesScreen extends ConsumerStatefulWidget {
  const AddressesScreen({super.key});

  @override
  ConsumerState<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends ConsumerState<AddressesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _aliasController = TextEditingController();
  final _fullAddressController = TextEditingController();
  final _referenceController = TextEditingController();
  final _districtController = TextEditingController();
  bool _formIsDefault = false;
  double? _formLatitude;
  double? _formLongitude;

  /// `'new'` para el alta, el `id` de la dirección para edición, `null` sin
  /// formulario abierto. Alta y edición son mutuamente excluyentes: un solo
  /// set de controllers, reseteado al abrir cada modo.
  String? _activeFormId;
  bool _submitting = false;
  String? _formError;
  String? _actionError;
  String? _deletingId;

  @override
  void dispose() {
    _aliasController.dispose();
    _fullAddressController.dispose();
    _referenceController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  void _openNewForm() {
    _aliasController.clear();
    _fullAddressController.clear();
    _referenceController.clear();
    _districtController.clear();
    setState(() {
      _activeFormId = 'new';
      _formIsDefault = false;
      _formLatitude = null;
      _formLongitude = null;
      _formError = null;
      _actionError = null;
    });
  }

  void _openEditForm(Address address) {
    _aliasController.text = address.alias;
    _fullAddressController.text = address.fullAddress;
    _referenceController.text = address.reference ?? '';
    _districtController.text = address.district;
    setState(() {
      _activeFormId = address.id;
      _formIsDefault = address.isDefault;
      _formLatitude = address.latitude;
      _formLongitude = address.longitude;
      _formError = null;
      _actionError = null;
    });
  }

  void _onFormLocationChanged(LatLng point) {
    setState(() {
      _formLatitude = point.latitude;
      _formLongitude = point.longitude;
    });
  }

  void _closeForm() => setState(() {
        _activeFormId = null;
        _formError = null;
      });

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    // `latitude`/`longitude` vienen del pin del mapa, no de un
    // `TextFormField` — `Form.validate()` no los cubre, así que el chequeo va
    // aparte.
    if (_formLatitude == null || _formLongitude == null) {
      setState(() {
        _formError = 'Toca el mapa para marcar la ubicación de tu dirección';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _formError = null;
    });
    final alias = _aliasController.text.trim();
    final fullAddress = _fullAddressController.text.trim();
    final district = _districtController.text.trim();
    final reference =
        _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim();
    try {
      final notifier = ref.read(addressListProvider.notifier);
      final editingId = _activeFormId;
      if (editingId != null && editingId != 'new') {
        await notifier.updateAddress(
          editingId,
          alias: alias,
          fullAddress: fullAddress,
          reference: reference,
          district: district,
          isDefault: _formIsDefault,
          latitude: _formLatitude,
          longitude: _formLongitude,
        );
      } else {
        await notifier.addAddress(
          alias: alias,
          fullAddress: fullAddress,
          reference: reference,
          district: district,
          latitude: _formLatitude,
          longitude: _formLongitude,
        );
      }
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _activeFormId = null;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _formError = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _formError = 'No se pudo guardar la dirección. Inténtalo de nuevo.';
        });
      }
    }
  }

  Future<void> _confirmDelete(Address address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CeltasColors.card,
        title: const Text('¿Eliminar dirección?'),
        content: Text(
          'Se eliminará "${address.alias}" (${address.fullAddress}). '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            style: TextButton.styleFrom(foregroundColor: CeltasColors.redLight),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _deletingId = address.id;
      _actionError = null;
    });
    try {
      await ref.read(addressListProvider.notifier).removeAddress(address.id);
      if (mounted) setState(() => _deletingId = null);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _deletingId = null;
          _actionError = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _deletingId = null;
          _actionError =
              'No se pudo eliminar la dirección. Inténtalo de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(addressListProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const SvgStrokeIcon(
                      path: 'M15 18l-6-6 6-6',
                      size: 18,
                      color: CeltasColors.cream,
                      strokeWidth: 2.2,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Direcciones',
                    style: textTheme.headlineSmall?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: CeltasColors.cream,
                    ),
                  ),
                ],
              ),
            ),
            if (_actionError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                child: Text(
                  _actionError!,
                  style: textTheme.bodySmall?.copyWith(
                    color: CeltasColors.redLight,
                  ),
                ),
              ),
            Expanded(
              child: addressesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: SlowBackendNotice(),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: _AddressesError(
                    message: error is ApiException
                        ? error.message
                        : 'No se pudieron cargar tus direcciones.',
                  ),
                ),
                data: (addresses) => ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  children: [
                    if (addresses.isEmpty && _activeFormId == null)
                      const _EmptyAddresses(),
                    for (final address in addresses) ...[
                      if (_activeFormId == address.id)
                        AddressFormCard(
                          key: const ValueKey('addresses-form'),
                          title: 'Editar dirección',
                          formKey: _formKey,
                          aliasController: _aliasController,
                          fullAddressController: _fullAddressController,
                          referenceController: _referenceController,
                          districtController: _districtController,
                          submitting: _submitting,
                          error: _formError,
                          onSubmit: _submitForm,
                          onCancel: _closeForm,
                          submitLabel: 'GUARDAR CAMBIOS',
                          aliasFieldKey: const ValueKey('addresses-form-alias'),
                          fullAddressFieldKey:
                              const ValueKey('addresses-form-full'),
                          districtFieldKey:
                              const ValueKey('addresses-form-district'),
                          referenceFieldKey:
                              const ValueKey('addresses-form-reference'),
                          submitButtonKey:
                              const ValueKey('addresses-form-save'),
                          isDefault: _formIsDefault,
                          onIsDefaultChanged: (v) =>
                              setState(() => _formIsDefault = v),
                          latitude: _formLatitude,
                          longitude: _formLongitude,
                          onLocationChanged: _onFormLocationChanged,
                        )
                      else
                        _AddressListCard(
                          address: address,
                          deleting: _deletingId == address.id,
                          onEdit: () => _openEditForm(address),
                          onDelete: () => _confirmDelete(address),
                        ),
                      const SizedBox(height: 12),
                    ],
                    if (_activeFormId == 'new')
                      AddressFormCard(
                        key: const ValueKey('addresses-form'),
                        title: 'Nueva dirección',
                        formKey: _formKey,
                        aliasController: _aliasController,
                        fullAddressController: _fullAddressController,
                        referenceController: _referenceController,
                        districtController: _districtController,
                        submitting: _submitting,
                        error: _formError,
                        onSubmit: _submitForm,
                        onCancel: _closeForm,
                        submitLabel: 'GUARDAR DIRECCIÓN',
                        aliasFieldKey: const ValueKey('addresses-form-alias'),
                        fullAddressFieldKey:
                            const ValueKey('addresses-form-full'),
                        districtFieldKey:
                            const ValueKey('addresses-form-district'),
                        referenceFieldKey:
                            const ValueKey('addresses-form-reference'),
                        submitButtonKey: const ValueKey('addresses-form-save'),
                        isDefault: _formIsDefault,
                        onIsDefaultChanged: (v) =>
                            setState(() => _formIsDefault = v),
                        latitude: _formLatitude,
                        longitude: _formLongitude,
                        onLocationChanged: _onFormLocationChanged,
                      ),
                  ],
                ),
              ),
            ),
            if (_activeFormId == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: GestureDetector(
                  key: const ValueKey('addresses-add-new'),
                  onTap: _openNewForm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    // El mockup usa borde punteado (`dashed`); Flutter no lo
                    // soporta nativamente sin un `CustomPainter` propio, así
                    // que se simplifica a sólido (misma intención visual).
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: CeltasColors.orange,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(CeltasRadii.input),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '+ AGREGAR NUEVA DIRECCIÓN',
                      style: textTheme.labelMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: CeltasColors.orange,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddressListCard extends StatelessWidget {
  const _AddressListCard({
    required this.address,
    required this.deleting,
    required this.onEdit,
    required this.onDelete,
  });

  final Address address;
  final bool deleting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: ValueKey('addresses-card-${address.id}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CeltasColors.card,
        border: Border.all(color: CeltasColors.border),
        borderRadius: BorderRadius.circular(CeltasRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SvgStrokeIcon(
                path: 'M3 10l9-7 9 7v10a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z',
                size: 16,
                color: CeltasColors.orange,
                strokeWidth: 2.2,
              ),
              const SizedBox(width: 8),
              Text(
                address.alias,
                style: textTheme.bodyLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: CeltasColors.cream,
                ),
              ),
              if (address.isDefault) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: CeltasColors.surfaceSelected,
                    border: Border.all(color: CeltasColors.gold),
                    borderRadius: BorderRadius.circular(CeltasRadii.badge),
                  ),
                  child: Text(
                    'PRINCIPAL',
                    style: textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: CeltasColors.gold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (deleting)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: CeltasColors.textMuted,
                  ),
                )
              else ...[
                GestureDetector(
                  key: ValueKey('addresses-edit-${address.id}'),
                  onTap: onEdit,
                  child: const SvgStrokeIcon(
                    path: 'M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4 12.5-12.5z'
                        'M12 20h9',
                    size: 16,
                  ),
                ),
                const SizedBox(width: 14),
                GestureDetector(
                  key: ValueKey('addresses-delete-${address.id}'),
                  onTap: onDelete,
                  child: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: CeltasColors.redLight,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            [address.fullAddress, address.district].join(', '),
            style: textTheme.bodySmall?.copyWith(
              fontSize: 13.5,
              color: CeltasColors.textMuted,
            ),
          ),
          if (address.reference != null && address.reference!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              address.reference!,
              style: textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: CeltasColors.textSubtle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddressesError extends ConsumerWidget {
  const _AddressesError({required this.message});

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

class _EmptyAddresses extends StatelessWidget {
  const _EmptyAddresses();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 36,
            color: CeltasColors.textSubtle,
          ),
          const SizedBox(height: 12),
          Text(
            'Todavía no tienes direcciones guardadas',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CeltasColors.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}
