import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/cart/application/cart_provider.dart';
import 'package:celtas_mobile/features/home/application/home_providers.dart';
import 'package:celtas_mobile/features/home/data/models/banner.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_category.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_item.dart';
import 'package:celtas_mobile/features/notifications/application/notification_providers.dart';
import 'package:celtas_mobile/features/settings/application/settings_providers.dart';
import 'package:celtas_mobile/features/settings/data/models/business_hours.dart';
import 'package:celtas_mobile/shared/widgets/business_closed_notice.dart';
import 'package:celtas_mobile/shared/widgets/celtas_button.dart';
import 'package:celtas_mobile/shared/widgets/celtas_snackbar.dart';
import 'package:celtas_mobile/shared/widgets/slow_backend_notice.dart';
import 'package:celtas_mobile/shared/widgets/svg_stroke_icon.dart';
import 'package:flutter/material.dart' hide Banner;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pantalla Home: carrusel de banners + menú por categorías.
///
/// Módulo 3: consume `GET /banners/active` (carrusel con indicador de puntos)
/// y `GET /menu` (categorías con tarjetas de producto). El botón "+" de cada
/// tarjeta agrega directo al carrito local (`cartProvider`, módulo 4) SIN
/// pasar por el selector de salsas del detalle SOLO si el producto no ofrece
/// salsas (`item.sauces.isEmpty`) — es el atajo de "agregar rápido" ya
/// existente y probado, y agregar sin salsas es un estado válido para el
/// backend (`selectedSauces: null`, ver `orders.service.ts`). Si el producto
/// SÍ ofrece salsas, el "+" navega al detalle (`/product/:id`) en vez de
/// agregar directo — hallazgo real probando en dispositivo (dueño del
/// negocio): el atajo se sentía roto en un producto con salsas porque nunca
/// dejaba elegirlas. Tocar la tarjeta ya abría el detalle antes de este
/// cambio, y lo sigue haciendo para cualquier producto. El ícono de carrito
/// del header muestra el total de unidades en un badge.
///
/// Mejora post-cierre: tap sobre cada banner según su `actionType`
/// (`Banner.actionType`/`actionValue`, contrato real verificado contra
/// `BannerForm.tsx` del panel admin — `actionValue` es el `id` real de la
/// categoría/producto, NO un slug pese a como lo describe el Swagger del
/// backend):
///   - `none`: sin acción.
///   - `category`: selecciona el chip de esa categoría (`selectedCategoryIdProvider`,
///     compartido con `_MenuList`). Si la categoría ya no tiene productos
///     disponibles (o ya no existe), se reutiliza el estado vacío del menú.
///   - `menuItem`: navega a `/product/:id` con el mismo flujo que una tarjeta
///     de producto. Si el producto ya no está disponible, la propia pantalla
///     de detalle ya resuelve ese caso con su estado "Producto no encontrado"
///     (el backend excluye productos no disponibles de `GET /menu`, así que
///     no aparece en la búsqueda local) — no hace falta manejo especial acá.
///   - `external_url`: abre `actionValue` con `url_launcher`, mismo criterio
///     aprendido con WhatsApp (módulo 5): no usa `canLaunchUrl` como gate.
///
/// Estados:
///   - Carga: spinner + `SlowBackendNotice` (el backend de Render puede tardar
///     30-50s en despertar).
///   - Error: mensaje + botón de reintento.
///   - Vacío: sin banners activos → se oculta el carrusel (no es error); sin
///     categorías → mensaje de menú vacío.
///
/// Mejora post-cierre: cartel de "local cerrado" (`businessHoursProvider`,
/// `lib/features/settings/` — mismo provider global, sin `.autoDispose`, que
/// ya usa el checkout para su propio aviso; reutilizado tal cual, sin
/// duplicar la consulta a `GET /settings/business-hours`). Puramente
/// informativo: el cliente sigue pudiendo navegar el menú y armar su
/// carrito con el cartel visible — el único bloqueo real sigue siendo el
/// 409 del checkout.
///
/// Se refresca de forma **event-driven, no por polling** (decisión de
/// arquitectura explícita — reducir carga sobre un backend en Render free
/// con muchos usuarios concurrentes): el backend devuelve `nextChangeAt`
/// (ver [BusinessHours]), el instante exacto en que `open` va a cambiar, y
/// esta pantalla programa un ÚNICO `Timer` (no periódico) para ese momento.
/// Al dispararse, vuelve a consultar el endpoint — lo que a su vez entrega
/// un `nextChangeAt` nuevo y se reprograma solo, autoperpetuándose sin
/// nunca "adivinar" un intervalo. Sin `nextChangeAt` (cierre manual, o el
/// horario configurado nunca abre) no se programa ningún timer — ver
/// `_HomeScreenState._onBusinessHoursChanged`. También se refresca de
/// inmediato al volver de segundo plano (`didChangeAppLifecycleState`), por
/// si el estado cambió mientras la app no estaba en foreground.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  /// Margen defensivo sobre `nextChangeAt` para no dispararse un instante
  /// antes por un pequeño desfase entre el reloj del backend y el del
  /// dispositivo — el timer dispara un puñado de segundos DESPUÉS del
  /// instante exacto, nunca antes.
  static const _clockDriftMargin = Duration(seconds: 5);

  Timer? _nextChangeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // `fireImmediately: true`: si el provider ya tiene un valor cacheado al
    // montar esta pantalla (ej. el cliente ya pasó por el checkout antes),
    // programa el timer de una vez con ese valor — no hace falta esperar a
    // un cambio futuro para la primera programación.
    ref.listenManual<AsyncValue<BusinessHours>>(
      businessHoursProvider,
      (previous, next) => _onBusinessHoursChanged(next),
      fireImmediately: true,
    );
  }

  /// Única fuente de la lógica de re-programación: cada vez que llega un
  /// valor REALMENTE nuevo del provider (fetch inicial resuelto, el propio
  /// timer disparándose, o el refresco forzado al volver de segundo plano),
  /// reprograma el timer contra el `nextChangeAt` recibido. Nunca deja dos
  /// timers corriendo a la vez — cancela cualquier timer previo antes de
  /// programar el nuevo.
  ///
  /// Exige `next is AsyncData<BusinessHours> && !next.isLoading` a
  /// propósito, NUNCA `next.valueOrNull` a secas ni solo el tipo: mientras
  /// un `invalidate()` está en vuelo, Riverpod 2.x modela el estado como
  /// `AsyncData(isLoading: true, value: <valor ANTERIOR>)` — sigue siendo
  /// `AsyncData` (no un `AsyncLoading` aparte), pero con el dato VIEJO, para
  /// no parpadear la UI. Reaccionar a eso reprograma un timer contra un
  /// `nextChangeAt` ya vencido, que dispara casi de inmediato y genera un
  /// `invalidate()` fantasma mientras el fetch real todavía está en vuelo
  /// (bug real encontrado con un test que simula la carrera entre el timer
  /// viejo y un refetch lento — sin el `!next.isLoading`, el test lo
  /// reproducía de forma consistente).
  void _onBusinessHoursChanged(AsyncValue<BusinessHours> next) {
    // `next is AsyncData` NO alcanza por sí solo: mientras un `invalidate()`
    // está en vuelo, Riverpod 2.x lo modela como `AsyncData(isLoading: true,
    // value: <valor ANTERIOR>)` (no un `AsyncLoading` aparte) — sigue siendo
    // `AsyncData`, pero con el dato viejo, para no parpadear la UI. Hace
    // falta el `!next.isLoading` explícito para exigir un valor realmente
    // asentado.
    if (next is! AsyncData<BusinessHours> || next.isLoading) return;
    _scheduleNextChangeTimer(next.value.nextChangeAt);
  }

  void _scheduleNextChangeTimer(DateTime? nextChangeAt) {
    _nextChangeTimer?.cancel();
    _nextChangeTimer = null;
    // `null`: cierre manual (impredecible, puede levantarse en cualquier
    // momento) o el horario configurado nunca abre — decisión de producto
    // ya tomada: no programar nada, el cartel se actualiza solo con el
    // próximo refresco natural (volver de segundo plano, o reabrir la app).
    if (nextChangeAt == null) return;
    final rawDelay = nextChangeAt.difference(DateTime.now());
    final delay = rawDelay.isNegative
        ? Duration.zero
        : rawDelay + _clockDriftMargin;
    _nextChangeTimer = Timer(delay, () {
      // El nuevo valor llega vía `ref.listenManual` de arriba, que ya se
      // encarga de reprogramar con el `nextChangeAt` siguiente — acá solo
      // hace falta disparar el refetch.
      ref.invalidate(businessHoursProvider);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // La app pudo pasar minutos/horas en segundo plano — no confiar en que
    // el timer programado (si lo había) siga siendo válido: cancelarlo y
    // reconsultar desde cero cubre también el caso del cierre manual (que
    // nunca tiene timer propio, ver `_scheduleNextChangeTimer`).
    if (state == AppLifecycleState.resumed) {
      _nextChangeTimer?.cancel();
      _nextChangeTimer = null;
      ref.invalidate(businessHoursProvider);
    }
  }

  @override
  void dispose() {
    _nextChangeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(activeBannersProvider);
    final menuAsync = ref.watch(publicMenuProvider);
    final businessHours = ref.watch(businessHoursProvider).valueOrNull;
    final (cartCount, cartTotal) = ref.watch(
      cartProvider.select((state) => (state.totalCount, state.total)),
    );
    final hasCartItems = cartCount > 0;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const _HomeHeader(),
                // Cartel FIJO (no scrollea con el menú), debajo del header y
                // antes del contenido — a diferencia del aviso del checkout
                // (que sí vive dentro de la lista scrolleable), acá se pidió
                // explícitamente que se mantenga siempre visible mientras el
                // local esté cerrado. Desaparece solo en el próximo refresco
                // en que `open` vuelva a `true` (ver doc de la clase).
                if (businessHours?.open == false)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      CeltasSpacing.page,
                      0,
                      CeltasSpacing.page,
                      12,
                    ),
                    child: BusinessClosedNotice(
                      key: const ValueKey('home-closed-notice'),
                      message: businessHours!.message ??
                          'El local está cerrado en este momento',
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    color: CeltasColors.orange,
                    backgroundColor: CeltasColors.surface,
                    onRefresh: () async {
                      ref.invalidate(activeBannersProvider);
                      ref.invalidate(publicMenuProvider);
                      try {
                        await Future.wait([
                          ref.read(activeBannersProvider.future),
                          ref.read(publicMenuProvider.future),
                        ]);
                      } catch (_) {
                        // Los estados de error de cada provider ya se
                        // muestran en la UI (banners/menú) — el refresh no
                        // debe lanzar una excepción async sin manejar.
                      }
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        CeltasSpacing.page,
                        0,
                        CeltasSpacing.page,
                        // Espacio extra para que la barra flotante del
                        // carrito no tape el último ítem del menú.
                        hasCartItems ? 88 : 24,
                      ),
                      children: [
                        // Carrusel de banners: se oculta si no hay banners
                        // activos.
                        bannersAsync.when(
                          loading: () => const _BannersLoading(),
                          error: (error, _) => _BannersError(
                            onRetry: () {
                              ref.invalidate(activeBannersProvider);
                            },
                          ),
                          data: (banners) => banners.isEmpty
                              ? const SizedBox.shrink()
                              : _BannerCarousel(banners: banners),
                        ),
                        const SizedBox(height: 18),
                        // Menú por categorías.
                        menuAsync.when(
                          loading: () => const _MenuLoading(),
                          error: (error, _) => _MenuError(
                            message: error.toString(),
                            onRetry: () {
                              ref.invalidate(publicMenuProvider);
                            },
                          ),
                          data: (categories) => categories.isEmpty
                              ? const _EmptyMenu()
                              : _MenuList(categories: categories),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Barra flotante de "continuar": solo con ítems en el carrito,
            // encima del bottom nav del shell (vive dentro del área del
            // propio tab, así que nunca lo reemplaza). Sin precedente en
            // design-reference/ (los 12 mockups no la contemplan) — diseño
            // nuevo consistente con el resto de la app: mismas tarjetas
            // (`CeltasColors.card`/`CeltasRadii.card`) y CTA en píldora
            // naranja que ya usa el resto de la app para acciones primarias.
            if (hasCartItems)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: _CartSummaryBar(count: cartCount, total: cartTotal),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Barra flotante "N items · S/ total" + "VER CARRITO", visible solo con el
/// carrito no vacío.
class _CartSummaryBar extends StatelessWidget {
  const _CartSummaryBar({required this.count, required this.total});

  final int count;
  final double total;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: GestureDetector(
        key: const ValueKey('home-cart-summary-bar'),
        onTap: () {
          // Mismo criterio que el resto del Home: ocultar el SnackBar
          // "Agregado" antes de navegar, para que no persista tapando los
          // CTAs del carrito.
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          context.push('/cart');
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
          decoration: BoxDecoration(
            color: CeltasColors.card,
            border: Border.all(color: CeltasColors.borderStrong),
            borderRadius: BorderRadius.circular(CeltasRadii.card),
            boxShadow: [
              BoxShadow(
                color: CeltasColors.black.withValues(alpha: 0.55),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$count ${count == 1 ? 'item' : 'items'} · '
                  'S/ ${total.toStringAsFixed(2)}',
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: CeltasColors.cream,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: CeltasColors.orange,
                  borderRadius: BorderRadius.circular(CeltasRadii.pill),
                ),
                child: Text(
                  'VER CARRITO',
                  style: textTheme.labelSmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: CeltasColors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header (pin de ubicación + carrito con badge + campana) ────────────────

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(
      cartProvider.select((state) => state.totalCount),
    );
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CeltasSpacing.page,
        14,
        CeltasSpacing.page,
        8,
      ),
      child: Row(
        children: [
          const SvgStrokeIcon(
            // El punto interior del pin es un `<circle cx="12" cy="10" r="2.5">`
            // en el SVG original del mockup. Convertido a mano a comandos de
            // arco, arrancaba en (12,10) — el CENTRO del círculo, no un punto
            // de su circunferencia — lo que desplazaba el círculo resultante
            // ~2.5px hacia arriba (centro real en (12,7.5), invadiendo la
            // punta del pin) y se veía como un alargamiento del ícono. Arranca
            // en (9.5,10), el punto izquierdo de la circunferencia real.
            path:
                'M12 22s7-6.5 7-12a7 7 0 1 0-14 0c0 5.5 7 12 7 12z'
                'M9.5 10a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0-5 0z',
            size: 18,
            color: CeltasColors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entregar en',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: CeltasColors.textMuted,
                  ),
                ),
                Text(
                  'Casa · Av. Corrientes 1234',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: CeltasColors.cream,
                  ),
                ),
              ],
            ),
          ),
          // Carrito con badge de unidades. El mockup no contempla un ícono de
          // carrito en el shell (bottom nav de 4 tabs), así que vive acá, en
          // el header del Home, junto a la campana.
          _CartIconButton(count: cartCount),
          const SizedBox(width: 16),
          // Campana: navega al historial local de notificaciones (módulo 9 +
          // mejora post-cierre, `NotificationsScreen`). Badge con el conteo
          // de no leídas, mismo patrón que el badge de unidades del carrito.
          GestureDetector(
            key: const ValueKey('home-notifications-bell'),
            onTap: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              context.push('/notifications');
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const SvgStrokeIcon(
                  path:
                      'M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9'
                      'M13.7 21a2 2 0 0 1-3.4 0',
                  size: 20,
                  color: CeltasColors.cream,
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      key: const ValueKey('home-notifications-badge'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: const BoxDecoration(
                        color: CeltasColors.orange,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$unreadCount',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: CeltasColors.black,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ícono de carrito del header con badge naranja con la cantidad de unidades.
class _CartIconButton extends StatelessWidget {
  const _CartIconButton({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('home-cart-icon'),
      onTap: () {
        // Ocultar el SnackBar "Agregado" antes de navegar: persiste en el
        // ScaffoldMessenger raíz y tapa los CTAs del carrito.
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        context.push('/cart');
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const SvgStrokeIcon(
            // Mismo path de carrito que el tab "Pedidos" del mockup.
            path:
                'M3 3h2l2.6 13h11.8L21 8H6'
                'M9 18.6a1.4 1.4 0 1 0 0 2.8a1.4 1.4 0 1 0 0-2.8'
                'M18 18.6a1.4 1.4 0 1 0 0 2.8a1.4 1.4 0 1 0 0-2.8',
            size: 20,
            color: CeltasColors.cream,
          ),
          if (count > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                key: const ValueKey('home-cart-badge'),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: const BoxDecoration(
                  color: CeltasColors.orange,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                alignment: Alignment.center,
                child: Text(
                  '$count',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: CeltasColors.black,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Carrusel de banners ────────────────────────────────────────────────────

class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.banners});

  final List<Banner> banners;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final PageController _controller = PageController();
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (index) => setState(() => _current = index),
            itemBuilder: (context, index) =>
                _BannerCard(banner: widget.banners[index]),
          ),
        ),
        const SizedBox(height: 10),
        // Indicador de puntos: activo 16x3 naranja, inactivo 6x3 gris.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.banners.length, (index) {
            final active = index == _current;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 16 : 6,
              height: 3,
              decoration: BoxDecoration(
                color: active ? CeltasColors.orange : CeltasColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _BannerCard extends ConsumerWidget {
  const _BannerCard({required this.banner});

  final Banner banner;

  void _handleTap(BuildContext context, WidgetRef ref) {
    final actionValue = banner.actionValue;
    if (actionValue == null || actionValue.isEmpty) return;
    switch (banner.actionType) {
      case BannerActionType.none:
        return;
      case BannerActionType.category:
        ref.read(selectedCategoryIdProvider.notifier).state = actionValue;
      case BannerActionType.menuItem:
        // Mismo criterio que el resto del Home: ocultar el SnackBar "Agregado"
        // antes de navegar, para que no persista tapando el detalle.
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        context.push('/product/$actionValue');
      case BannerActionType.externalUrl:
        _openExternalUrl(context, actionValue);
    }
  }

  /// NO usa `canLaunchUrl` como gate (mismo criterio ya aprendido con el
  /// `whatsappUrl` del checkout, módulo 5): `launchUrl` directo es la señal
  /// confiable de éxito/fallo real.
  Future<void> _openExternalUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    var opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } on PlatformException {
        opened = false;
      }
    }
    if (opened || !context.mounted) return;
    showCeltasSnackBar(context, 'No se pudo abrir el enlace del banner.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tappable =
        banner.actionType != BannerActionType.none &&
        banner.actionValue != null &&
        banner.actionValue!.isNotEmpty;

    return GestureDetector(
      key: ValueKey('banner-${banner.id}'),
      onTap: tappable ? () => _handleTap(context, ref) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CeltasRadii.banner),
          color: CeltasColors.surface,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (banner.imageUrl != null && banner.imageUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: banner.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: CeltasColors.surface,
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: CeltasColors.orange,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: CeltasColors.surface,
                  alignment: Alignment.center,
                  child: Text(
                    banner.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              )
            else
              Container(
                color: CeltasColors.surface,
                alignment: Alignment.center,
                child: Text(
                  banner.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            // Gradiente oscuro de izquierda a derecha (del CSS real del mockup:
            // `linear-gradient(90deg, rgba(13,13,13,.85) 20%, transparent 70%)`).
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    CeltasColors.black.withValues(alpha: 0.85),
                    Colors.transparent,
                  ],
                  stops: const [0.2, 0.7],
                ),
              ),
            ),
            // Título del banner (Cinzel, abajo a la izquierda). `right` deja
            // espacio para el chevron de afordancia cuando el banner es
            // tocable — sin esto, un título largo se solapa con el ícono
            // (hallazgo real de `@tester`, verificado con `tester.getRect`).
            Positioned(
              left: 16,
              right: tappable ? 40 : 16,
              bottom: 14,
              child: Text(
                banner.title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: CeltasColors.cream,
                ),
              ),
            ),
            // Afordancia sutil de "tocable": no hay precedente en el mockup
            // (banner sin comportamiento de tap), así que se mantiene mínima —
            // mismo ícono/tamaño que ya usa `coupon_picker_sheet.dart` para
            // indicar una fila tocable.
            if (tappable)
              const Positioned(
                right: 12,
                bottom: 10,
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: CeltasColors.cream,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Menú por categorías ────────────────────────────────────────────────────

/// Lista del menú, con el chip seleccionado en `selectedCategoryIdProvider`
/// (compartido con el carrusel de banners: un banner con `actionType:
/// category` selecciona la categoría desde ahí, no desde acá).
class _MenuList extends ConsumerWidget {
  const _MenuList({required this.categories});

  final List<PublicMenuCategory> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategoryId = ref.watch(selectedCategoryIdProvider);
    final visible = selectedCategoryId == null
        ? categories
        : categories
              .where((category) => category.id == selectedCategoryId)
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chips de categorías (mockup: "Burgers", "Chicken", "Bebidas").
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _CategoryChip(
                label: 'Todas',
                selected: selectedCategoryId == null,
                onTap: () =>
                    ref.read(selectedCategoryIdProvider.notifier).state = null,
              ),
              for (final category in categories) ...[
                const SizedBox(width: 10),
                _CategoryChip(
                  label: category.name,
                  selected: selectedCategoryId == category.id,
                  onTap: () =>
                      ref.read(selectedCategoryIdProvider.notifier).state =
                          category.id,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Categoría seleccionada (por chip o por banner) que ya no tiene
        // productos disponibles, o que ya no existe: `GET /menu` excluye del
        // todo las categorías sin productos disponibles, así que este caso
        // se ve igual que "sin categorías" — mismo estado vacío, en vez de
        // dejar la sección en blanco.
        if (selectedCategoryId != null && visible.isEmpty)
          const _EmptyMenu()
        else
          for (final category in visible) ...[
            Text(
              category.name.toUpperCase(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: CeltasColors.cream,
              ),
            ),
            const SizedBox(height: 12),
            for (final item in category.items) ...[
              _ProductCard(item: item),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? CeltasColors.orange : CeltasColors.surface,
          borderRadius: BorderRadius.circular(CeltasRadii.pill),
          border: selected ? null : Border.all(color: CeltasColors.border),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? CeltasColors.black : CeltasColors.textLabel,
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de producto del mockup: fila con imagen 76x76, nombre, descripción,
/// precio dorado y botón "+" circular naranja. Esquina superior derecha cortada
/// (`clip-path: polygon(12px 0, ...)` del CSS real).
///
/// Tocar la tarjeta abre el detalle (`/product/:id`); el botón "+" agrega
/// directo al carrito local sin entrar al detalle SOLO si el producto no
/// ofrece salsas — si las ofrece, navega al detalle igual que la tarjeta
/// (ver doc de `HomeScreen`).
class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.item});

  final PublicMenuItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClipPath(
      clipper: const _CardCornerClipper(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: CeltasColors.card,
          border: Border.all(color: CeltasColors.cardBorder),
        ),
        child: Row(
          children: [
            _ProductImage(item: item),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                key: ValueKey('product-${item.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  // El SnackBar "Agregado" persiste en el ScaffoldMessenger raíz
                  // al navegar y tapa el CTA inferior del detalle: ocultarlo.
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  context.push('/product/${item.id}');
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: CeltasColors.cream,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (item.description != null &&
                        item.description!.isNotEmpty) ...[
                      Text(
                        item.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: CeltasColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      'S/ ${item.price.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: CeltasColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Botón "+" rápido: agrega al carrito local sin entrar al detalle
            // SOLO si el producto no ofrece salsas. Si las ofrece, navega al
            // detalle en vez de agregar directo (mismo `push` que el tap
            // sobre la tarjeta) para que el cliente pueda elegirlas — antes
            // agregaba siempre directo, sin importar si el producto tenía
            // salsas, y eso se sentía roto en dispositivo real.
            _AddButton(
              key: ValueKey('add-${item.id}'),
              onTap: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                if (item.sauces.isNotEmpty) {
                  context.push('/product/${item.id}');
                  return;
                }
                ref.read(cartProvider.notifier).addItem(item);
                showCeltasSnackBar(
                  context,
                  'Agregado: ${item.name}',
                  // Este agregado deja el carrito no vacío, así que
                  // `_CartSummaryBar` va a estar visible en este mismo
                  // Home — sin este margen el SnackBar queda tapado por
                  // esa barra. Mismo valor de 88 ya usado más arriba
                  // (padding del `ListView`) para la misma barra.
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.item});

  final PublicMenuItem item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.image;
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: CeltasColors.surface,
          borderRadius: BorderRadius.circular(CeltasRadii.control),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.restaurant,
          size: 24,
          color: CeltasColors.textSubtle,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(CeltasRadii.control),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 76,
        height: 76,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 76,
          height: 76,
          color: CeltasColors.surface,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: CeltasColors.orange,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: 76,
          height: 76,
          color: CeltasColors.surface,
          alignment: Alignment.center,
          child: const Icon(
            Icons.restaurant,
            size: 24,
            color: CeltasColors.textSubtle,
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: CeltasColors.orange,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const SvgStrokeIcon(
          path: 'M12 5v14M5 12h14',
          size: 16,
          color: CeltasColors.black,
          strokeWidth: 3,
        ),
      ),
    );
  }
}

/// Recorta la esquina superior derecha en diagonal (12px), replicando el
/// `clip-path: polygon(12px 0,100% 0,100% calc(100% - 12px),calc(100% - 12px)
/// 100%,0 100%,0 12px)` del CSS real de las cards del Home.
class _CardCornerClipper extends CustomClipper<Path> {
  const _CardCornerClipper(this.cut);

  final double cut;

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, cut)
      ..close();
  }

  @override
  bool shouldReclip(_CardCornerClipper oldClipper) => oldClipper.cut != cut;
}

// ─── Estados de carga / error / vacío ───────────────────────────────────────

class _BannersLoading extends StatelessWidget {
  const _BannersLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: CeltasColors.surface,
        borderRadius: BorderRadius.circular(CeltasRadii.banner),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: CeltasColors.orange,
        ),
      ),
    );
  }
}

/// Error del carrusel de banners: caja compacta con mensaje y reintento.
/// Antes este error se tragaba en silencio (`SizedBox.shrink`); ahora el
/// usuario puede reintentar sin perder el menú que ya cargó.
class _BannersError extends StatelessWidget {
  const _BannersError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: CeltasColors.surface,
        borderRadius: BorderRadius.circular(CeltasRadii.banner),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 22,
            color: CeltasColors.textSubtle,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No se pudieron cargar los banners',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: CeltasColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: CeltasColors.orange),
            child: const Text('REINTENTAR'),
          ),
        ],
      ),
    );
  }
}

class _MenuLoading extends StatelessWidget {
  const _MenuLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(height: 40),
        Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: CeltasColors.orange,
            ),
          ),
        ),
        SizedBox(height: 12),
        SlowBackendNotice(),
      ],
    );
  }
}

class _MenuError extends StatelessWidget {
  const _MenuError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 36,
            color: CeltasColors.textSubtle,
          ),
          const SizedBox(height: 12),
          Text(
            'No se pudo cargar el menú',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: CeltasColors.textMuted),
          ),
          const SizedBox(height: 16),
          CeltasButton(label: 'REINTENTAR', onPressed: onRetry),
        ],
      ),
    );
  }
}

class _EmptyMenu extends StatelessWidget {
  const _EmptyMenu();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          const Icon(
            Icons.restaurant_menu_rounded,
            size: 36,
            color: CeltasColors.textSubtle,
          ),
          const SizedBox(height: 12),
          Text(
            'El menú está vacío por ahora',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Volvé pronto, estamos preparando algo rico.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: CeltasColors.textMuted),
          ),
        ],
      ),
    );
  }
}
