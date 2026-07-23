class Invoice {
  final String id;
  final String month;
  final double amount;
  final String dueDate;
  final bool isPaid;
  final String pdfUrl;

  Invoice({
    required this.id,
    required this.month,
    required this.amount,
    required this.dueDate,
    required this.isPaid,
    required this.pdfUrl,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] ?? '',
      month: json['month'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      dueDate: json['due_date'] ?? '',
      isPaid: json['is_paid'] ?? false,
      pdfUrl: json['pdf_url'] ?? '',
    );
  }
}

class Ticket {
  final String id;
  final String category;
  final String description;
  final String status; // 'Abierto', 'En Proceso', 'Resuelto'
  final String createdAt;
  final String? diagnosticResult;

  Ticket({
    required this.id,
    required this.category,
    required this.description,
    required this.status,
    required this.createdAt,
    this.diagnosticResult,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] ?? '',
      category: json['category'] ?? 'General',
      description: json['description'] ?? '',
      status: json['status'] ?? 'Abierto',
      createdAt: json['created_at'] ?? '',
      diagnosticResult: json['diagnostic_result'],
    );
  }
}
