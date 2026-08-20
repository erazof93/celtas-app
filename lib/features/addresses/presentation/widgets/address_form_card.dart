import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/addresses/presentation/widgets/address_location_picker.dart';
import 'package:celtas_mobile/shared/widgets/celtas_button.dart';
import 'package:celtas_mobile/shared/widgets/celtas_text_field.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Formulario de dirección (alias, dirección completa, distrito, referencia
/// opcional, ubicación en mapa) compartido entre el checkout (módulo 5, alta
/// mínima inline) y la pantalla de direcciones guardadas (módulo 6, alta y
/// edición completas).
///
/// El toggle "Marcar como principal" es opcional: el checkout no lo pasa
/// (`onIsDefaultChanged == null` oculta el toggle), la pantalla de
/// direcciones sí.
///
/// El campo "DIRECCIÓN COMPLETA" original se extendió con
/// `AddressLocationPicker` (autocompletado + GPS + mapa con pin, ver skill
/// `geoapify-direcciones`) en vez de reemplazarse: sigue siendo el mismo
/// `fullAddressController` de siempre, la única diferencia es que ahora
/// también puede llenarse solo (sugerencia elegida, GPS, o reverse geocoding
/// al soltar el pin) y expone `latitude`/`longitude`.
class AddressFormCard extends StatelessWidget {
  const AddressFormCard({
    super.key,
    required this.title,
    required this.formKey,
    required this.aliasController,
    required this.fullAddressController,
    required this.referenceController,
    required this.districtController,
    required this.submitting,
    required this.error,
    required this.onSubmit,
    required this.onCancel,
    required this.submitLabel,
    this.aliasFieldKey,
    this.fullAddressFieldKey,
    this.districtFieldKey,
    this.referenceFieldKey,
    this.submitButtonKey,
    this.isDefault,
    this.onIsDefaultChanged,
    this.latitude,
    this.longitude,
    this.onLocationChanged,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final TextEditingController aliasController;
  final TextEditingController fullAddressController;
  final TextEditingController referenceController;
  final TextEditingController districtController;
  final bool submitting;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback? onCancel;
  final String submitLabel;

  final Key? aliasFieldKey;
  final Key? fullAddressFieldKey;
  final Key? districtFieldKey;
  final Key? referenceFieldKey;
  final Key? submitButtonKey;

  /// `null` oculta el toggle (caso del checkout). No-`null` lo muestra.
  final bool? isDefault;
  final ValueChanged<bool>? onIsDefaultChanged;

  /// Coordenadas ya resueltas (ej. al editar una dirección existente).
  /// `null` es un valor válido — el formulario se puede guardar sin pasar
  /// por el mapa/autocompletado/GPS (ver skill `geoapify-direcciones`).
  final double? latitude;
  final double? longitude;

  /// Se llama cuando el usuario confirma una ubicación nueva desde el mapa,
  /// el autocompletado, o el GPS. El caller (dueño del estado del
  /// formulario) es responsable de guardar `latitude`/`longitude` para el
  /// submit — mismo criterio que ya usa para los `TextEditingController`.
  final ValueChanged<LatLng>? onLocationChanged;

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
            Text(
              title,
              style: textTheme.bodyLarge?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: CeltasColors.cream,
              ),
            ),
            const SizedBox(height: 12),
            CeltasTextField(
              key: aliasFieldKey,
              label: 'ALIAS',
              controller: aliasController,
              hintText: 'Casa, Trabajo…',
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Ingresa un alias' : null,
            ),
            const SizedBox(height: 12),
            KeyedSubtree(
              key: fullAddressFieldKey,
              child: AddressLocationPicker(
                fullAddressController: fullAddressController,
                districtController: districtController,
                latitude: latitude,
                longitude: longitude,
                onLocationChanged:
                    onLocationChanged ?? (_) {},
              ),
            ),
            const SizedBox(height: 12),
            CeltasTextField(
              key: districtFieldKey,
              label: 'DISTRITO',
              controller: districtController,
              hintText: 'San Juan de Miraflores',
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Ingresa el distrito' : null,
            ),
            const SizedBox(height: 12),
            CeltasTextField(
              key: referenceFieldKey,
              label: 'REFERENCIA (OPCIONAL)',
              controller: referenceController,
              hintText: 'Portón verde, tercer piso',
              textInputAction:
                  onIsDefaultChanged == null
                      ? TextInputAction.done
                      : TextInputAction.next,
              onFieldSubmitted: onIsDefaultChanged == null
                  ? (_) => submitting ? null : onSubmit()
                  : null,
            ),
            if (onIsDefaultChanged != null) ...[
              const SizedBox(height: 12),
              _DefaultToggle(
                value: isDefault ?? false,
                onChanged: submitting ? null : onIsDefaultChanged,
              ),
            ],
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
                if (onCancel != null) ...[
                  Expanded(
                    child: TextButton(
                      onPressed: submitting ? null : onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: CeltasColors.textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: const Text(
                        'CANCELAR',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: onCancel != null ? 2 : 1,
                  child: CeltasButton(
                    key: submitButtonKey,
                    label: submitLabel,
                    loading: submitting,
                    onPressed: submitting ? null : onSubmit,
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

class _DefaultToggle extends StatelessWidget {
  const _DefaultToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('address-form-is-default'),
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: value ? CeltasColors.orange : null,
              border: value
                  ? null
                  : Border.all(color: CeltasColors.borderStrong, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: value
                ? const Icon(Icons.check, size: 12, color: CeltasColors.black)
                : null,
          ),
          const SizedBox(width: 10),
          Text(
            'Marcar como principal',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: CeltasColors.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}
