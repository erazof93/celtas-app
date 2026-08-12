import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/home/data/home_repository.dart';
import 'package:celtas_mobile/features/home/data/models/banner.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_category.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repositorio del Home contra el backend real.
final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => HomeRepository(ApiClient.instance.dio),
);

/// Banners vigentes para el carrusel (`GET /banners/active`).
///
/// Puede devolver una lista vacía (sin banners activos): la UI oculta el
/// carrusel en ese caso, no muestra error.
final activeBannersProvider = FutureProvider<List<Banner>>(
  (ref) => ref.watch(homeRepositoryProvider).getActiveBanners(),
);

/// Menú público (`GET /menu`): categorías activas con productos disponibles.
final publicMenuProvider = FutureProvider<List<PublicMenuCategory>>(
  (ref) => ref.watch(homeRepositoryProvider).getMenu(),
);

/// Categoría seleccionada en los chips del menú (`null` = "Todas").
///
/// Vive acá (no como estado local de `_MenuList`) porque un banner con
/// `actionType: category` necesita poder seleccionarla desde el carrusel,
/// que es un widget hermano en el árbol, no un ancestro/descendiente.
final selectedCategoryIdProvider = StateProvider<String?>((ref) => null);
