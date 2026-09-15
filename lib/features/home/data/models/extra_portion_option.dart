import 'package:freezed_annotation/freezed_annotation.dart';

part 'extra_portion_option.freezed.dart';
part 'extra_portion_option.g.dart';

/// Porción extra que un producto ofrece para elegir (ej. papas extra,
/// queso extra), tal como la devuelve `GET /menu` dentro de cada ítem.
///
/// Contrato verificado contra `backend-celtas/src/modules/menu/menu.service.ts`
/// (`findPublicMenu`): mismo shape que [BeverageOption] — expone `price`
/// porque cada porción extra elegida suma su precio una vez por unidad del
/// ítem (ver `OrdersService.buildItems` en el backend).
///
/// Se reusa el mismo shape para `CartItem.selectedExtraPortions` (lo que el
/// cliente eligió en el detalle de producto): ahí no viene de un
/// `fromJson`, se arma a mano a partir de las opciones ya cargadas en
/// `PublicMenuItem.extraPortions`.
@freezed
abstract class ExtraPortionOption with _$ExtraPortionOption {
  const factory ExtraPortionOption({
    required String id,
    required String name,
    required double price,
  }) = _ExtraPortionOption;

  factory ExtraPortionOption.fromJson(Map<String, dynamic> json) =>
      _$ExtraPortionOptionFromJson(json);
}
