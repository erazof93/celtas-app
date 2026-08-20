import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Mapa siempre visible con "pin arrastrable" para confirmar/corregir la
/// ubicación de una dirección — el paso final de precisión del flujo
/// acordado (autocompletado y GPS son solo atajos para llegar a un punto de
/// partida; el pin es lo que garantiza precisión real, ver skill
/// `geoapify-direcciones`).
///
/// Implementación: el pin queda FIJO en el centro visual del mapa y es el
/// MAPA el que se arrastra debajo — patrón estándar para selectores de
/// ubicación (evita reimplementar gestos de arrastre de un marcador
/// individual, que `flutter_map` no expone de forma nativa). Desde la
/// perspectiva del usuario el efecto es idéntico a arrastrar un pin: paneás
/// el mapa hasta que el pin quede sobre el punto exacto y soltás.
///
/// Tiles: Geoapify Map Tiles (misma API key que Autocomplete/Geocoding, un
/// solo proveedor para las 4 piezas — ver skill).
class AddressMapPicker extends StatefulWidget {
  const AddressMapPicker({
    super.key,
    required this.center,
    required this.onCenterChanged,
    required this.apiKey,
    this.height = 200,
  });

  /// Centro actual del mapa (y por lo tanto la posición del pin).
  final LatLng center;

  /// Se llama cuando el usuario termina de mover el mapa (`onPositionChanged`
  /// con `hasGesture: true`, para no disparar reverse geocoding por cambios
  /// programáticos del propio widget, ej. al recibir una nueva posición GPS
  /// desde el padre).
  final ValueChanged<LatLng> onCenterChanged;

  final String? apiKey;
  final double height;

  @override
  State<AddressMapPicker> createState() => _AddressMapPickerState();
}

class _AddressMapPickerState extends State<AddressMapPicker> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(covariant AddressMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recentrar programáticamente (ej. tras GPS o seleccionar una
    // sugerencia) sin esperar a que el usuario arrastre el mapa él mismo.
    if (widget.center != oldWidget.center) {
      _mapController.move(widget.center, _mapController.camera.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = widget.apiKey != null && widget.apiKey!.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(CeltasRadii.card),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (hasKey)
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: widget.center,
                  initialZoom: 16,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onPositionChanged: (position, hasGesture) {
                    if (!hasGesture) return;
                    final newCenter = position.center;
                    widget.onCenterChanged(newCenter);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://maps.geoapify.com/v1/tile/osm-bright/'
                        '{z}/{x}/{y}.png?apiKey=${widget.apiKey}',
                    userAgentPackageName: 'com.celtas.celtas_mobile',
                    maxNativeZoom: 20,
                  ),
                ],
              )
            else
              Container(
                color: CeltasColors.surface,
                alignment: Alignment.center,
                child: Text(
                  'Mapa no disponible',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            // Pin fijo al centro — nunca se mueve con el mapa, es la
            // referencia visual de "acá va la dirección".
            IgnorePointer(
              child: Padding(
                // El ícono de pin apunta hacia abajo con la punta al centro
                // visual real: se desplaza medio alto hacia arriba para que
                // la PUNTA (no el centro del ícono) quede sobre el centro
                // del mapa.
                padding: const EdgeInsets.only(bottom: 24),
                child: Icon(
                  Icons.location_on,
                  size: 40,
                  color: CeltasColors.orange,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 4,
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
