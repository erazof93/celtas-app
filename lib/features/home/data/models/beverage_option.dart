import 'package:freezed_annotation/freezed_annotation.dart';

part 'beverage_option.freezed.dart';
part 'beverage_option.g.dart';

/// Bebida que un producto ofrece para elegir (ej. Coca-Cola 500ml, Inca
/// Kola 500ml), tal como la devuelve `GET /menu` dentro de cada ítem.
///
/// Contrato verificado contra `backend-celtas/src/modules/menu/menu.service.ts`
/// (`findPublicMenu`): a diferencia de [SauceOption], el endpoint público SÍ
/// expone `price` — cada bebida elegida suma su precio una vez por unidad
/// del ítem (ver `OrdersService.buildItems` en el backend), así que la app
/// necesita el precio para el preview de total del detalle/carrito.
///
/// Se reusa el mismo shape para `CartItem.selectedBeverages` (lo que el
/// cliente eligió en el detalle de producto): ahí no viene de un
/// `fromJson`, se arma a mano a partir de las opciones ya cargadas en
/// `PublicMenuItem.beverages`.
@freezed
abstract class BeverageOption with _$BeverageOption {
  const factory BeverageOption({
    required String id,
    required String name,
    required double price,
  }) = _BeverageOption;

  factory BeverageOption.fromJson(Map<String, dynamic> json) =>
      _$BeverageOptionFromJson(json);
}
