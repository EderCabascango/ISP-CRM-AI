import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../data/services/speedtest_service.dart';

class SpeedtestScreen extends StatefulWidget {
  const SpeedtestScreen({super.key});

  @override
  State<SpeedtestScreen> createState() => _SpeedtestScreenState();
}

class _SpeedtestScreenState extends State<SpeedtestScreen> {
  late final SpeedtestService _speedtestService;

  bool _isRunning = false;
  bool _isOptimizing = false;
  double _progress = 0.0;
  String _currentPhase = 'Presiona "Iniciar Prueba" para comenzar';
  double _liveGaugeValue = 0.0;

  int? _latency;
  int? _jitter;
  double? _finalDownload;
  double? _finalUpload;

  @override
  void initState() {
    super.initState();
    _speedtestService = SpeedtestService(
      dio: Dio(BaseOptions(baseUrl: 'https://api.isp-backend.com/v1')),
    );
  }

  Future<void> _startTest() async {
    setState(() {
      _isRunning = true;
      _progress = 0.0;
      _currentPhase = 'Iniciando test...';
      _liveGaugeValue = 0.0;
      _latency = null;
      _jitter = null;
      _finalDownload = null;
      _finalUpload = null;
    });

    final result = await _speedtestService.runSpeedTest(
      onProgress: (progress, phase, liveMbps) {
        if (mounted) {
          setState(() {
            _progress = progress;
            _currentPhase = phase;
            _liveGaugeValue = liveMbps;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isRunning = false;
        _latency = result.latencyMs;
        _jitter = result.jitterMs;
        _finalDownload = result.downloadMbps;
        _finalUpload = result.uploadMbps;
        _liveGaugeValue = result.downloadMbps;
        _currentPhase = '¡Prueba de Velocidad Completada!';
      });
    }
  }

  Future<void> _optimizeChannel() async {
    setState(() => _isOptimizing = true);

    final msg = await _speedtestService.optimizeChannel();

    if (mounted) {
      setState(() => _isOptimizing = false);
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.auto_awesome, color: Colors.amber, size: 48),
          title: const Text('¡Canal Wi-Fi Optimizado!'),
          content: Text(msg, textAlign: TextAlign.center),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Excelente', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_isRunning,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Prueba de Velocidad & Optimización'),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // VELOCÍMETRO CIRCULAR (GAUGE)
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.shade50,
                  border: Border.all(color: theme.primaryColor.withOpacity(0.3), width: 8),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: CircularProgressIndicator(
                        value: _isRunning ? _progress : 1.0,
                        strokeWidth: 10,
                        backgroundColor: Colors.grey.shade200,
                        color: _isRunning ? theme.primaryColor : Colors.green,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _liveGaugeValue.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                        const Text(
                          'Mbps',
                          style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentPhase,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // RESULTADOS DE MÉTRICAS (Ping, Download, Upload)
              Row(
                children: [
                  _buildResultCard(
                    title: 'Ping / Jitter',
                    value: _latency != null ? '${_latency}ms / ${_jitter}ms' : '--',
                    icon: Icons.speed,
                    color: Colors.purple,
                  ),
                  const SizedBox(width: 12),
                  _buildResultCard(
                    title: 'Descarga',
                    value: _finalDownload != null ? '$_finalDownload Mbps' : '--',
                    icon: Icons.arrow_downward,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 12),
                  _buildResultCard(
                    title: 'Carga',
                    value: _finalUpload != null ? '$_finalUpload Mbps' : '--',
                    icon: Icons.arrow_upward,
                    color: Colors.blue,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // BOTÓN INICIAR PRUEBA
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isRunning ? null : _startTest,
                  icon: _isRunning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(
                    _isRunning ? 'Midiendo Velocidad...' : 'Iniciar Prueba',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 20),

              // SECCIÓN OPTIMIZAR CANAL WI-FI
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.auto_awesome, color: Colors.amber.shade900, size: 28),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAlignment.start,
                              children: [
                                Text(
                                  'Optimizar Mi Wi-Fi',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Escanea el espectro y cambia tu router al canal menos congestionado.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: Colors.amber.shade800),
                            foregroundColor: Colors.amber.shade900,
                          ),
                          onPressed: (_isRunning || _isOptimizing) ? null : _optimizeChannel,
                          icon: _isOptimizing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.tune),
                          label: Text(
                            _isOptimizing ? 'Analizando espectro...' : 'Optimizar Canal Ahora',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
