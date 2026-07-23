import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/models/account_models.dart';
import '../data/repositories/account_billing_repository_impl.dart';

class AccountBillingScreen extends StatefulWidget {
  const AccountBillingScreen({super.key});

  @override
  State<AccountBillingScreen> createState() => _AccountBillingScreenState();
}

class _AccountBillingScreenState extends State<AccountBillingScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final AccountBillingRepositoryImpl _repository;

  bool _isLoadingInvoices = true;
  bool _isLoadingTickets = true;
  List<Invoice> _invoices = [];
  List<Ticket> _tickets = [];

  // Formulario Nuevo Ticket
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'Falla de Internet';
  bool _attachDiagnostic = true;
  bool _isCreatingTicket = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _repository = AccountBillingRepositoryImpl(
      dio: Dio(BaseOptions(baseUrl: 'https://api.isp-backend.com/v1')),
      secureStorage: const FlutterSecureStorage(),
    );
    _loadData();
  }

  Future<void> _loadData() async {
    final invResult = await _repository.getInvoices();
    invResult.fold((_) {}, (list) => setState(() => _invoices = list));
    setState(() => _isLoadingInvoices = false);

    final tckResult = await _repository.getTickets();
    tckResult.fold((_) {}, (list) => setState(() => _tickets = list));
    setState(() => _isLoadingTickets = false);
  }

  Future<void> _submitTicket() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isCreatingTicket = true);

      final diagSummary = _attachDiagnostic ? 'Latencia Wi-Fi: 14ms | Salida WAN: OK | Sector: Operativo' : null;
      final result = await _repository.createTicket(
        category: _selectedCategory,
        description: _descriptionController.text.trim(),
        diagnosticResult: diagSummary,
      );

      setState(() => _isCreatingTicket = false);

      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message), backgroundColor: Colors.red),
          );
        },
        (ticketId) {
          _descriptionController.clear();
          Navigator.of(context).pop(); // Cerrar modal bottom sheet
          _loadData(); // Recargar lista de tickets

          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              icon: const Icon(Icons.confirmation_number, color: Colors.green, size: 48),
              title: const Text('¡Ticket Generado!'),
              content: Text(
                'Tu caso ha sido registrado con éxito.\n\nNúmero de Radicado:\n$ticketId',
                textAlign: TextAlign.center,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Cuenta y Servicios'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long), text: 'Facturación & Pagos'),
            Tab(icon: Icon(Icons.support_agent), text: 'Tickets de Soporte'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBillingTab(),
          _buildTicketsTab(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 1: FACTURACIÓN Y PAGOS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBillingTab() {
    if (_isLoadingInvoices) {
      return const Center(child: CircularProgressIndicator());
    }

    final pendingInvoice = _invoices.firstWhere(
      (inv) => !inv.isPaid,
      orElse: () => _invoices.first,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAlignment.start,
        children: [
          // TARJETA DE RESUMEN DE CUENTA
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: pendingInvoice.isPaid ? Colors.green.shade700 : Colors.blue.shade800,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        pendingInvoice.isPaid ? 'Servicio Al Día' : 'Factura Pendiente',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          pendingInvoice.isPaid ? 'PAGADO' : 'POR PAGAR',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '\$${pendingInvoice.amount.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vence el: ${pendingInvoice.dueDate}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (!pendingInvoice.isPaid)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _openPaymentGateway(pendingInvoice),
                        icon: const Icon(Icons.payment),
                        label: const Text('Pagar Factura Ahora', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // HISTORIAL DE FACTURAS
          Text(
            'Historial de Facturas',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _invoices.length,
            itemBuilder: (context, index) {
              final inv = _invoices[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: inv.isPaid ? Colors.green.shade50 : Colors.orange.shade50,
                    child: Icon(
                      inv.isPaid ? Icons.check : Icons.priority_high,
                      color: inv.isPaid ? Colors.green : Colors.orange,
                    ),
                  ),
                  title: Text(inv.month, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Vence: ${inv.dueDate}  •  \$${inv.amount.toStringAsFixed(2)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                        tooltip: 'Ver PDF',
                        onPressed: () => _openPdf(inv.pdfUrl),
                      ),
                      if (!inv.isPaid)
                        TextButton(
                          onPressed: () => _openPaymentGateway(inv),
                          child: const Text('Pagar', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 2: TICKETS DE SOPORTE TÉCNICO
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTicketsTab() {
    if (_isLoadingTickets) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTicketBottomSheet,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Ticket'),
      ),
      body: _tickets.isEmpty
          ? const Center(child: Text('No tienes tickets de soporte registrados.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _tickets.length,
              itemBuilder: (context, index) {
                final tck = _tickets[index];
                Color statusColor = Colors.orange;
                if (tck.status == 'Resuelto') statusColor = Colors.green;
                if (tck.status == 'En Proceso') statusColor = Colors.blue;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(tck.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tck.status,
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Categoría: ${tck.category}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(tck.description, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                        if (tck.diagnosticResult != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.health_and_safety, size: 16, color: Colors.blue),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Diagnóstico adjunto: ${tck.diagnosticResult}',
                                    style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showCreateTicketBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAlignment.start,
              children: [
                Text(
                  'Crear Ticket de Soporte',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Selector de Categoría
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Categoría de la Incidencia',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Falla de Internet', child: Text('Falla de Internet / Lentitud')),
                    DropdownMenuItem(value: 'Cambio de Domicilio', child: Text('Cambio de Domicilio / Traslado')),
                    DropdownMenuItem(value: 'Problema de Facturación', child: Text('Problema de Facturación / Cobro')),
                  ],
                  onChanged: (val) => setModalState(() => _selectedCategory = val!),
                ),
                const SizedBox(height: 16),

                // Campo Descripción
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Descripción del Problema',
                    hintText: 'Describe lo que sucede con tu servicio...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 10) {
                      return 'Por favor describe el problema en al menos 10 caracteres.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Casilla adjuntar diagnóstico automático
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Adjuntar diagnóstico automático de red', style: TextStyle(fontSize: 13)),
                  subtitle: const Text('Incluye latencia Wi-Fi y estado WAN actual', style: TextStyle(fontSize: 11)),
                  value: _attachDiagnostic,
                  onChanged: (val) => setModalState(() => _attachDiagnostic = val ?? true),
                ),
                const SizedBox(height: 20),

                // Botón Envío
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isCreatingTicket ? null : _submitTicket,
                    child: _isCreatingTicket
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Generar Ticket de Soporte', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPaymentGateway(Invoice invoice) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Abriendo pasarela de pago para la factura ${invoice.id}...'),
        backgroundColor: Colors.blue.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openPdf(String pdfUrl) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Descargando factura electrónica PDF... ($pdfUrl)'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
