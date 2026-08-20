import 'dart:async';

import 'package:celtas_mobile/core/config/env.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/addresses/application/current_location_controller.dart';
import 'package:celtas_mobile/features/addresses/application/geoapify_providers.dart';
import 'package:celtas_mobile/features/addresses/application/location_resolution_failure.dart';
import 'package:celtas_mobile/features/addresses/data/models/geoapify_suggestion.dart';
import 'package:celtas_mobile/features/addresses/presentation/widgets/address_map_picker.dart';
import 'package:celtas_mobile/shared/widgets/celtas_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Centro por defecto del mapa antes de cualquier interacción (autocompletado
/// / GPS / drag): San Juan de Miraflores, Lima — aproximado, solo un punto de
/// partida razonable para el distrito donde opera Celtas, NUNCA se guarda
/// como coordenada real de la dirección si el usuario no interactúa con el
/// mapa (ver `bool _hasInteracted` abajo).
const _defaultCenter = LatLng(-12.1633, -76.9718);

/// Combina las tres formas acordadas de llegar a una ubicación (autocompletado
/// de texto, botón GPS, mapa con pin arrastrable) sobre el campo "DIRECCIÓN
/// COMPLETA" ya existente del formulario — ver skill `geoapify-direcciones`.
///
/// Nunca lanza ni bloquea el guardado: si Geoapify no tiene API key
/// configurada, o cualquier request falla, el usuario igual puede escribir la
/// dirección a mano y guardarla sin coordenadas (`latitude`/`longitude`
/// quedan `null`, un valor válido — ver skill, "direcciones sin lat/lng
/// siguen siendo válidas").
class AddressLocationPicker extends ConsumerStatefulWidget {
  const AddressLocationPicker({
    super.key,
    required this.fullAddressController,
    required this.districtController,
    required this.latitude,
    required this.longitude,
    required this.onLocationChanged,
  });

  final TextEditingController fullAddressController;
  final TextEditingController districtController;

  /// Coordenadas ya resueltas (ej. al editar una dirección existente que ya
  /// las tiene). `null` si todavía no hay ninguna.
  final double? latitude;
  final double? longitude;

  /// Se llama cada vez que el usuario confirma una ubicación nueva
  /// (sugerencia elegida, GPS resuelto, o pin soltado tras arrastrar el
  /// mapa) — el padre es quien posee el estado real de `latitude`/
  /// `longitude` para el submit, igual que ya posee los controllers de texto.
  final ValueChanged<LatLng> onLocationChanged;

  @override
  ConsumerState<AddressLocationPicker> createState() =>
      _AddressLocationPickerState();
}

class _AddressLocationPickerState
    extends ConsumerState<AddressLocationPicker> {
  static const _debounceDuration = Duration(milliseconds: 400);

  Timer? _debounce;
  Timer? _mapDebounce;
  List<GeoapifySuggestion> _suggestions = const [];
  bool _suggestionsLoading = false;
  bool _showSuggestions = false;
  final _fieldFocusNode = FocusNode();

  /// Centro actual del mapa. Arranca en las coordenadas ya conocidas (modo
  /// edición) o en el centro por defecto del distrito (modo alta) — en este
  /// último caso `_hasInteracted` sigue en `false` hasta que el usuario haga
  /// algo, así que ese centro nunca se confunde con una ubicación elegida.
  late LatLng _mapCenter;

  /// `true` en cuanto el usuario elige una sugerencia, usa el GPS, o
  /// arrastra el mapa — recién ahí el centro del mapa representa una
  /// ubicación real elegida por el usuario (antes es solo el punto de
  /// partida visual).
  bool _hasInteracted = false;

  @override
  void initState() {
    super.initState();
    _mapCenter = (widget.latitude != null && widget.longitude != null)
        ? LatLng(widget.latitude!, widget.longitude!)
        : _defaultCenter;
    _hasInteracted = widget.latitude != null && widget.longitude != null;
    _fieldFocusNode.addListener(() {
      if (!_fieldFocusNode.hasFocus) {
        // Pequeño delay para no cerrar el dropdown antes de procesar el tap
        // sobre una sugerencia (que también le quita el foco al campo).
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) setState(() => _showSuggestions = false);
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant AddressLocationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.latitude != oldWidget.latitude ||
        widget.longitude != oldWidget.longitude) {
      if (widget.latitude != null && widget.longitude != null) {
        setState(() {
          _mapCenter = LatLng(widget.latitude!, widget.longitude!);
          _hasInteracted = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapDebounce?.cancel();
    _fieldFocusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    _debounce?.cancel();
    if (text.trim().length < 4) {
      setState(() {
        _suggestions = const [];
        _suggestionsLoading = false;
      });
      return;
    }
    setState(() => _suggestionsLoading = true);
    _debounce = Timer(_debounceDuration, () async {
      final repo = ref.read(geoapifyRepositoryProvider);
      final results = await repo.autocomplete(text);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _suggestionsLoading = false;
        _showSuggestions = results.isNotEmpty;
      });
    });
  }

  void _selectSuggestion(GeoapifySuggestion suggestion) {
    widget.fullAddressController.text = suggestion.bestFullAddress;
    final district = suggestion.bestDistrict;
    if (district != null) {
      widget.districtController.text = district;
    }
    final point = LatLng(suggestion.latitude, suggestion.longitude);
    setState(() {
      _mapCenter = point;
      _hasInteracted = true;
      _suggestions = const [];
      _showSuggestions = false;
    });
    _fieldFocusNode.unfocus();
    widget.onLocationChanged(point);
  }

  /// `onPositionChanged` de `flutter_map` dispara en CADA frame intermedio
  /// del gesto de arrastre (no solo al soltar) — confirmado en dispositivo
  /// real: un solo drag de 2 segundos disparó más de una decena de llamadas
  /// a Reverse Geocoding seguidas. Sin debounce acá, un único drag de un
  /// usuario podía agotar por sí solo el rate limit compartido de Geoapify
  /// (5 req/seg para TODA la app) y devolver 429 al resto de usuarios — la
  /// misma regla de debounce que ya aplica el autocompletado de texto, ver
  /// skill `geoapify-direcciones`.
  void _onMapCenterChanged(LatLng point) {
    setState(() {
      _mapCenter = point;
      _hasInteracted = true;
    });
    widget.onLocationChanged(point);
    _mapDebounce?.cancel();
    _mapDebounce = Timer(
      _debounceDuration,
      () => _reverseGeocodeAndFill(point),
    );
  }

  Future<void> _useCurrentLocation() async {
    await ref
        .read(currentLocationControllerProvider.notifier)
        .requestCurrentPosition();
    final result = ref.read(currentLocationControllerProvider);
    final position = result.valueOrNull;
    if (position == null) {
      if (mounted) _showLocationError(result);
      return;
    }
    final point = LatLng(position.latitude, position.longitude);
    setState(() {
      _mapCenter = point;
      _hasInteracted = true;
    });
    widget.onLocationChanged(point);
    await _reverseGeocodeAndFill(point);
  }

  Future<void> _reverseGeocodeAndFill(LatLng point) async {
    final repo = ref.read(geoapifyRepositoryProvider);
    final result = await repo.reverseGeocode(
      latitude: point.latitude,
      longitude: point.longitude,
    );
    if (!mounted || result == null) return;
    widget.fullAddressController.text = result.bestFullAddress;
    final district = result.bestDistrict;
    if (district != null) {
      widget.districtController.text = district;
    }
  }

  void _showLocationError(AsyncValue<dynamic> result) {
    final error = result.error;
    String message =
        'No se pudo obtener tu ubicación. Puedes ubicarla en el mapa manualmente.';
    if (error is LocationResolutionFailure) {
      switch (error.reason) {
        case LocationResolutionReason.permissionDenied:
          message =
              'No diste permiso de ubicación. Puedes ubicarte en el mapa manualmente.';
        case LocationResolutionReason.permissionDeniedForever:
          message =
              'El permiso de ubicación está bloqueado. Actívalo desde Configuración '
              'del sistema, o ubícate en el mapa manualmente.';
        case LocationResolutionReason.serviceDisabled:
          message =
              'Activa el GPS de tu dispositivo para usar tu ubicación actual.';
        case LocationResolutionReason.unknown:
          message =
              'No se pudo obtener tu ubicación. Puedes ubicarla en el mapa manualmente.';
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final locatingAsync = ref.watch(currentLocationControllerProvider);
    final locating = locatingAsync.isLoading;
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CeltasTextField(
              label: 'DIRECCIÓN COMPLETA',
              controller: widget.fullAddressController,
              hintText: 'Av. Los Álamos 123',
              textInputAction: TextInputAction.next,
              focusNode: _fieldFocusNode,
              onChanged: _onTextChanged,
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'Ingresa la dirección completa'
                  : null,
              suffixIcon: _suggestionsLoading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: locating ? null : _useCurrentLocation,
                icon: locating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location, size: 16),
                label: const Text('USAR MI UBICACIÓN ACTUAL'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CeltasColors.orange,
                  side: const BorderSide(color: CeltasColors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: textTheme.labelMedium?.copyWith(fontSize: 12.5),
                ),
              ),
            ),
            const SizedBox(height: 10),
            AddressMapPicker(
              center: _mapCenter,
              onCenterChanged: _onMapCenterChanged,
              apiKey: AppConfig.geoapifyApiKey,
            ),
            const SizedBox(height: 4),
            Text(
              _hasInteracted
                  ? 'Arrastra el mapa para ajustar el pin sobre tu dirección exacta.'
                  : 'Busca tu dirección, usa el GPS, o arrastra el mapa para ubicarte '
                      '(opcional — puedes guardar la dirección sin hacerlo).',
              style: textTheme.bodySmall?.copyWith(
                fontSize: 11.5,
                color: CeltasColors.textSubtle,
              ),
            ),
          ],
        ),
        // Pintado al final del Stack a propósito: así queda por ENCIMA del
        // botón de GPS y del mapa que vienen después en el Column. Cuando
        // este overlay vivía en un Stack propio que solo envolvía el campo de
        // texto, `Clip.none` lo dejaba desbordar hacia abajo pero el orden de
        // pintado de los hermanos del Column (botón, mapa) lo tapaba —
        // confirmado en dispositivo real, el texto de la sugerencia quedaba
        // ilegible superpuesto con "USAR MI UBICACIÓN ACTUAL".
        if (_showSuggestions && _suggestions.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            top: 74,
            child: _SuggestionsList(
              suggestions: _suggestions,
              onSelected: _selectSuggestion,
            ),
          ),
      ],
    );
  }
}

class _SuggestionsList extends StatelessWidget {
  const _SuggestionsList({required this.suggestions, required this.onSelected});

  final List<GeoapifySuggestion> suggestions;
  final ValueChanged<GeoapifySuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      color: CeltasColors.card,
      borderRadius: BorderRadius.circular(CeltasRadii.input),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: suggestions.length,
          separatorBuilder: (_, _) =>
              const Divider(height: 1, color: CeltasColors.border),
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return ListTile(
              dense: true,
              leading: const Icon(
                Icons.location_on_outlined,
                size: 18,
                color: CeltasColors.orange,
              ),
              title: Text(
                suggestion.formatted,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                ),
              ),
              onTap: () => onSelected(suggestion),
            );
          },
        ),
      ),
    );
  }
}
