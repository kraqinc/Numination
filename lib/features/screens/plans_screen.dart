import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  // CONFIGURA ESTE DATO ANTES DEL LANZAMIENTO.
  // Escribe el número público de Nequi que recibirá los pagos.
  static const String _nequiRecipient = 'PON_AQUI_EL_NUMERO_NEQUI';

  static final Uri _nequiUri = Uri.parse('https://www.nequi.com.co/');

  bool _loadingPlans = true;
  bool _paypalEnabled = false;
  bool _nequiEnabled = true;

  String? _loadError;
  String? _workingPlanId;

  String? _pendingPaypalPaymentId;
  String? _pendingPaypalPlanTitle;
  bool _checkingPaypal = false;

  List<_BillingPlan> _plans = [];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    if (!mounted) return;

    setState(() {
      _loadingPlans = true;
      _loadError = null;
    });

    try {
      final response = await ApiClient.get('/payments/plans');
      final decoded = ApiClient.decode(response);

      if (decoded is! Map) {
        throw const FormatException('Respuesta de planes inválida.');
      }

      final data = Map<String, dynamic>.from(decoded);
      final rawPlans = data['plans'];

      if (rawPlans is! List) {
        throw const FormatException('No se recibieron los planes.');
      }

      final methods = data['methods'];
      final methodData = methods is Map
          ? Map<String, dynamic>.from(methods)
          : <String, dynamic>{};

      final plans = rawPlans
          .whereType<Map>()
          .map((item) => _BillingPlan.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      if (!mounted) return;

      setState(() {
        _plans = plans;
        _paypalEnabled = methodData['paypal'] == true;
        _nequiEnabled = methodData['nequi'] == true;
        _loadingPlans = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadingPlans = false;
        _loadError = error is ApiException
            ? error.message
            : 'No pudimos cargar los planes. Comprueba tu conexión.';
      });
    }
  }

  String _formatCop(int amount) {
    final digits = amount.toString();
    final formatted = digits.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
    return 'COP \$$formatted';
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _startPaypalCheckout(_BillingPlan plan) async {
    if (!_paypalEnabled) {
      _showMessage('PayPal no está disponible en este momento.');
      return;
    }

    if (_workingPlanId != null || _checkingPaypal) return;

    setState(() => _workingPlanId = plan.id);

    try {
      final response = await ApiClient.post('/payments/paypal/create-order', {
        'packageId': plan.id,
      });

      final decoded = ApiClient.decode(response);
      if (decoded is! Map) {
        throw const FormatException('PayPal devolvió una respuesta inválida.');
      }

      final data = Map<String, dynamic>.from(decoded);
      final paymentId = data['paymentId']?.toString() ?? '';
      final approvalUrl = data['approvalUrl']?.toString() ?? '';

      if (paymentId.isEmpty) {
        throw const FormatException('No se recibió el identificador del pago.');
      }

      final uri = Uri.tryParse(approvalUrl);
      final validPaypalHost =
          uri != null &&
          uri.scheme == 'https' &&
          (uri.host == 'paypal.com' || uri.host.endsWith('.paypal.com'));

      if (!validPaypalHost) {
        throw const FormatException(
          'El enlace de pago de PayPal no es válido.',
        );
      }

      if (!mounted) return;

      setState(() {
        _pendingPaypalPaymentId = paymentId;
        _pendingPaypalPlanTitle = plan.title;
      });

      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened) {
        _showMessage(
          'No pudimos abrir PayPal. Puedes intentarlo de nuevo '
          'o verificar el pago si ya lo completaste.',
        );
      }
    } catch (error) {
      _showMessage(
        error is ApiException
            ? error.message
            : error is FormatException
            ? error.message
            : 'No pudimos iniciar PayPal. Inténtalo de nuevo.',
      );
    } finally {
      if (mounted) {
        setState(() => _workingPlanId = null);
      }
    }
  }

  Future<void> _verifyPaypalPayment() async {
    final paymentId = _pendingPaypalPaymentId;
    if (paymentId == null || paymentId.isEmpty || _checkingPaypal) {
      return;
    }

    setState(() => _checkingPaypal = true);

    try {
      // Esta ruta captura y verifica la orden con PayPal.
      // No basta con consultar el estado ni volver a la aplicación.
      final response = await ApiClient.post('/payments/paypal/capture-order', {
        'paymentId': paymentId,
      });

      final decoded = ApiClient.decode(response);
      if (decoded is! Map) {
        throw const FormatException(
          'No pudimos interpretar la respuesta del pago.',
        );
      }

      final data = Map<String, dynamic>.from(decoded);
      final status = data['status']?.toString().toUpperCase() ?? '';

      if (!mounted) return;

      if (status == 'COMPLETED') {
        setState(() {
          _pendingPaypalPaymentId = null;
          _pendingPaypalPlanTitle = null;
        });

        _showMessage(
          '¡Pago confirmado! El backend reportó la compra como completada.',
        );
      } else if (status == 'PENDING') {
        _showMessage(
          'PayPal todavía no confirma el pago. '
          'Inténtalo de nuevo más tarde.',
        );
      } else if (status == 'FAILED' || status == 'CANCELLED') {
        setState(() {
          _pendingPaypalPaymentId = null;
          _pendingPaypalPlanTitle = null;
        });

        _showMessage('El pago no se completó. Puedes iniciar otra compra.');
      } else {
        _showMessage(
          'El pago todavía no está confirmado. Estado: '
          '${status.isEmpty ? 'desconocido' : status}.',
        );
      }
    } catch (error) {
      _showMessage(
        error is ApiException
            ? error.message
            : 'No pudimos verificar el pago. Vuelve a intentarlo.',
      );
    } finally {
      if (mounted) {
        setState(() => _checkingPaypal = false);
      }
    }
  }

  Future<void> _startNequiPayment(_BillingPlan plan) async {
    if (!_nequiEnabled) {
      _showMessage('Nequi no está disponible en este momento.');
      return;
    }

    // Evita crear solicitudes para un destinatario sin configurar.
    if (_nequiRecipient.trim().isEmpty ||
        _nequiRecipient == 'PON_AQUI_EL_NUMERO_NEQUI') {
      _showMessage(
        'Configura el número receptor de Nequi en plans_screen.dart.',
      );
      return;
    }

    if (_workingPlanId != null || _checkingPaypal) return;

    setState(() => _workingPlanId = plan.id);

    try {
      // Crea una solicitud pendiente que debe aprobarse manualmente.
      final response = await ApiClient.post('/credits/recharge', {
        'packageId': plan.id,
      });

      final decoded = ApiClient.decode(response);
      if (decoded is! Map) {
        throw const FormatException('No pudimos crear la solicitud de Nequi.');
      }

      final data = Map<String, dynamic>.from(decoded);
      final referenceCode = data['referenceCode']?.toString() ?? '';

      if (referenceCode.isEmpty) {
        throw const FormatException(
          'No recibimos el código de referencia del pago.',
        );
      }

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final colors = Theme.of(dialogContext).colorScheme;

          return AlertDialog(
            title: const Text('Pago por Nequi'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Solicitud creada. Tu plan no se activa hasta '
                    'que el pago sea revisado y aprobado.',
                    style: Theme.of(dialogContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Plan',
                    style: Theme.of(dialogContext).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.title,
                    style: Theme.of(dialogContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Valor mensual',
                    style: Theme.of(dialogContext).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCop(plan.priceCop),
                    style: Theme.of(dialogContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Enviar pago a',
                    style: Theme.of(dialogContext).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _nequiRecipient,
                    style: Theme.of(dialogContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: _nequiRecipient),
                        );
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text('Número de Nequi copiado.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copiar destinatario'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Referencia de pago',
                    style: Theme.of(dialogContext).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    referenceCode,
                    style: Theme.of(dialogContext).textTheme.titleMedium
                        ?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: referenceCode),
                        );
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text('Referencia copiada.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copiar referencia'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Conserva esta referencia para identificar tu pago. '
                    'La aprobación manual es necesaria para activar el plan.',
                    style: Theme.of(dialogContext).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cerrar'),
              ),
              FilledButton(
                onPressed: () async {
                  final opened = await launchUrl(
                    _nequiUri,
                    mode: LaunchMode.externalApplication,
                  );

                  if (!opened && dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('No pudimos abrir el sitio de Nequi.'),
                      ),
                    );
                  }
                },
                child: const Text('Abrir Nequi'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      _showMessage(
        error is ApiException
            ? error.message
            : error is FormatException
            ? error.message
            : 'No pudimos crear la solicitud de Nequi.',
      );
    } finally {
      if (mounted) {
        setState(() => _workingPlanId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suscripciones'),
        actions: [
          IconButton(
            tooltip: 'Actualizar planes',
            onPressed: _loadingPlans ? null : _loadPlans,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loadingPlans
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _buildLoadError()
          : RefreshIndicator(
              onRefresh: _loadPlans,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Elige tu plan',
                    style: text.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Más créditos para tus conversaciones, '
                    'proyectos y herramientas de IA.',
                    style: text.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildFreePlan(),
                  const SizedBox(height: 20),
                  if (_pendingPaypalPaymentId != null) _buildPaypalPending(),
                  if (_pendingPaypalPaymentId != null)
                    const SizedBox(height: 18),
                  if (_plans.isEmpty)
                    _buildEmptyPlans()
                  else
                    for (final plan in _plans) ...[
                      _buildPlanCard(plan),
                      const SizedBox(height: 14),
                    ],
                  const SizedBox(height: 8),
                  _buildPaymentInformation(),
                ],
              ),
            ),
    );
  }

  Widget _buildLoadError() {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No pudimos cargar los planes',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _loadError ?? 'Inténtalo de nuevo.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadPlans,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFreePlan() {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Free',
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Empieza a trabajar con Numination.',
            style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          _benefit('500 créditos diarios'),
          _benefit('Acceso al chat de IA'),
          _benefit('Coder con límites diarios'),
          const SizedBox(height: 8),
          Text(
            'Plan gratuito',
            style: text.labelLarge?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(_BillingPlan plan) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final featured = plan.bestValue;
    final busy = _workingPlanId == plan.id;
    final canPayNequi = _nequiEnabled;
    final canPayPaypal = _paypalEnabled;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: featured
            ? colors.primaryContainer.withValues(alpha: 0.28)
            : colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: featured ? colors.primary : colors.outlineVariant,
          width: featured ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.title.replaceFirst('Numination ', ''),
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (featured)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'MÁS CAPACIDAD',
                    style: text.labelSmall?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatCop(plan.priceCop),
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            'por mes',
            style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          _benefit('${_formatCredits(plan.credits)} créditos por semana'),
          _benefit('Acceso a las funciones incluidas en tu plan'),
          _benefit(
            featured
                ? 'Más capacidad para proyectos de mayor uso'
                : 'Más capacidad para trabajar cada semana',
          ),
          const SizedBox(height: 14),
          if (busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canPayNequi ? () => _startNequiPayment(plan) : null,
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Pagar con Nequi'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: canPayPaypal
                    ? () => _startPaypalCheckout(plan)
                    : null,
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(
                  canPayPaypal
                      ? 'Continuar con PayPal'
                      : 'PayPal no disponible',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaypalPending() {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Compra pendiente',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            _pendingPaypalPlanTitle == null
                ? 'Finaliza el pago en PayPal y después verifícalo.'
                : 'Plan: $_pendingPaypalPlanTitle. '
                      'Finaliza el pago en PayPal y después verifícalo.',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _checkingPaypal ? null : _verifyPaypalPayment,
              icon: _checkingPaypal
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_outlined),
              label: Text(
                _checkingPaypal ? 'Verificando pago...' : 'Verificar pago',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlans() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 30),
      child: Center(child: Text('No hay planes disponibles en este momento.')),
    );
  }

  Widget _buildPaymentInformation() {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          const Icon(Icons.lock_outline_rounded, size: 22),
          const SizedBox(height: 8),
          Text(
            'PayPal procesa el equivalente en USD mostrado por el backend. '
            'El precio en COP es una referencia aproximada.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            'Los pagos por Nequi requieren verificación manual. '
            'Crear una solicitud o abrir la app bancaria no activa '
            'automáticamente la suscripción.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _benefit(String label) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 19,
            color: colors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }

  String _formatCredits(int credits) {
    return credits.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }
}

class _BillingPlan {
  const _BillingPlan({
    required this.id,
    required this.title,
    required this.credits,
    required this.priceCop,
    required this.priceLabel,
    required this.bestValue,
  });

  final String id;
  final String title;
  final int credits;
  final int priceCop;
  final String priceLabel;
  final bool bestValue;

  factory _BillingPlan.fromJson(Map<String, dynamic> json) {
    final rawCop = json['priceCop'];
    final rawCredits = json['credits'];

    final priceCop = rawCop is num
        ? rawCop.toInt()
        : int.tryParse('$rawCop') ?? 0;

    final credits = rawCredits is num
        ? rawCredits.toInt()
        : int.tryParse('$rawCredits') ?? 0;

    final id = json['id']?.toString() ?? '';
    final title = json['title']?.toString() ?? id;

    if (id.isEmpty || priceCop <= 0 || credits <= 0) {
      throw const FormatException('El plan recibido no es válido.');
    }

    return _BillingPlan(
      id: id,
      title: title,
      credits: credits,
      priceCop: priceCop,
      priceLabel: json['priceLabel']?.toString() ?? '',
      bestValue: json['bestValue'] == true,
    );
  }
}
