import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/settings/data/settings_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

/// `GET /settings/business-hours` (contrato verificado contra
/// `celtas-backend/src/modules/settings/settings.controller.ts`): público,
/// sin auth, `{ open, message, schedule, manualClosed }` — el checkout solo
/// usa `open`/`message` para el aviso preventivo (ver doc de [BusinessHours]).
void main() {
  late MockDio dio;
  late SettingsRepository repository;

  setUpAll(() {
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com',
    );
  });

  setUp(() {
    dio = MockDio();
    repository = SettingsRepository(dio);
  });

  group('getBusinessHours', () {
    test('local abierto: open=true, message=null', () async {
      when(() => dio.get<Map<String, dynamic>>('/settings/business-hours'))
          .thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/settings/business-hours'),
          data: const {
            'open': true,
            'message': null,
            'schedule': <String, dynamic>{},
            'manualClosed': false,
          },
        ),
      );

      final result = await repository.getBusinessHours();

      expect(result.open, isTrue);
      expect(result.message, isNull);
      verify(
        () => dio.get<Map<String, dynamic>>('/settings/business-hours'),
      ).called(1);
    });

    test(
      'local cerrado por horario: open=false con el mensaje real del backend',
      () async {
        when(() => dio.get<Map<String, dynamic>>('/settings/business-hours'))
            .thenAnswer(
          (_) async => Response<Map<String, dynamic>>(
            requestOptions: RequestOptions(path: '/settings/business-hours'),
            data: const {
              'open': false,
              'message':
                  'El local está cerrado en este momento. Hoy atendemos de '
                  '11:00 a 23:00',
              'schedule': <String, dynamic>{},
              'manualClosed': false,
            },
          ),
        );

        final result = await repository.getBusinessHours();

        expect(result.open, isFalse);
        expect(
          result.message,
          'El local está cerrado en este momento. Hoy atendemos de 11:00 a '
          '23:00',
        );
      },
    );

    test(
      'cierre manual con motivo: open=false, message incluye el motivo',
      () async {
        when(() => dio.get<Map<String, dynamic>>('/settings/business-hours'))
            .thenAnswer(
          (_) async => Response<Map<String, dynamic>>(
            requestOptions: RequestOptions(path: '/settings/business-hours'),
            data: const {
              'open': false,
              'message':
                  'El local está cerrado temporalmente: Cerrado por '
                  'mantenimiento',
              'schedule': <String, dynamic>{},
              'manualClosed': true,
            },
          ),
        );

        final result = await repository.getBusinessHours();

        expect(result.open, isFalse);
        expect(
          result.message,
          'El local está cerrado temporalmente: Cerrado por mantenimiento',
        );
      },
    );

    test('error de red → ApiException de conexión', () async {
      when(() => dio.get<Map<String, dynamic>>('/settings/business-hours'))
          .thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/settings/business-hours'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        repository.getBusinessHours(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('No se pudo conectar con el servidor'),
          ),
        ),
      );
    });
  });
}
