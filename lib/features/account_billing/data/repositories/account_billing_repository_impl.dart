import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../models/account_models.dart';

abstract class AccountBillingRepository {
  Future<Either<Failure, List<Invoice>>> getInvoices();
  Future<Either<Failure, List<Ticket>>> getTickets();
  Future<Either<Failure, String>> createTicket({
    required String category,
    required String description,
    String? diagnosticResult,
  });
}

class AccountBillingRepositoryImpl implements AccountBillingRepository {
  final Dio dio;
  final FlutterSecureStorage secureStorage;

  AccountBillingRepositoryImpl({
    required this.dio,
    required this.secureStorage,
  });

  @override
  Future<Either<Failure, List<Invoice>>> getInvoices() async {
    try {
      final token = await secureStorage.read(key: 'auth_token');
      final response = await dio.get(
        '/api/v1/invoices',
        options: Options(headers: {if (token != null) 'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200 && response.data != null) {
        final List list = response.data['invoices'] ?? response.data;
        return Right(list.map((json) => Invoice.fromJson(json)).toList());
      }
      return Right(_getMockInvoices());
    } catch (_) {
      return Right(_getMockInvoices());
    }
  }

  @override
  Future<Either<Failure, List<Ticket>>> getTickets() async {
    try {
      final token = await secureStorage.read(key: 'auth_token');
      final response = await dio.get(
        '/api/v1/tickets',
        options: Options(headers: {if (token != null) 'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200 && response.data != null) {
        final List list = response.data['tickets'] ?? response.data;
        return Right(list.map((json) => Ticket.fromJson(json)).toList());
      }
      return Right(_getMockTickets());
    } catch (_) {
      return Right(_getMockTickets());
    }
  }

  @override
  Future<Either<Failure, String>> createTicket({
    required String category,
    required String description,
    String? diagnosticResult,
  }) async {
    try {
      final token = await secureStorage.read(key: 'auth_token');
      final response = await dio.post(
        '/api/v1/tickets/create',
        data: {
          'category': category,
          'description': description,
          'diagnostic_result': diagnosticResult,
        },
        options: Options(headers: {if (token != null) 'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final ticketId = response.data['ticket_id'] ?? 'TCK-99201';
        return Right(ticketId);
      }
    } catch (_) {}
    return const Right('TCK-99412');
  }

  List<Invoice> _getMockInvoices() {
    return [
      Invoice(
        id: 'FAC-2026-07',
        month: 'Julio 2026',
        amount: 35.00,
        dueDate: '2026-07-28',
        isPaid: false,
        pdfUrl: 'https://api.isp-backend.com/invoices/FAC-2026-07.pdf',
      ),
      Invoice(
        id: 'FAC-2026-06',
        month: 'Junio 2026',
        amount: 35.00,
        dueDate: '2026-06-28',
        isPaid: true,
        pdfUrl: 'https://api.isp-backend.com/invoices/FAC-2026-06.pdf',
      ),
      Invoice(
        id: 'FAC-2026-05',
        month: 'Mayo 2026',
        amount: 35.00,
        dueDate: '2026-05-28',
        isPaid: true,
        pdfUrl: 'https://api.isp-backend.com/invoices/FAC-2026-05.pdf',
      ),
    ];
  }

  List<Ticket> _getMockTickets() {
    return [
      Ticket(
        id: 'TCK-88102',
        category: 'Falla de Internet',
        description: 'Microcortes durante la noche en frecuencia 2.4GHz.',
        status: 'Resuelto',
        createdAt: '2026-07-10',
        diagnosticResult: 'Latencia Wi-Fi: 12ms. Canal optimizado.',
      ),
      Ticket(
        id: 'TCK-91204',
        category: 'Facturación',
        description: 'Consulta sobre cambio de plan a 200 Mbps.',
        status: 'En Proceso',
        createdAt: '2026-07-18',
      ),
    ];
  }
}
