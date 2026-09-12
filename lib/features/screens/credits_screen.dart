import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/theme.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  Map<String, dynamic>? overview;
  List<CreditLog> history = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final overviewResponse =
          ApiClient.decode(await ApiClient.get('/credits')) as Map;

      final historyResponse =
          ApiClient.decode(await ApiClient.get('/credits/history')) as Map;

      final logs = ((historyResponse['logs'] as List?) ?? const [])
          .map(
            (e) => CreditLog.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        overview = Map<String, dynamic>.from(overviewResponse);
        history = logs;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> recharge(BillingPlan plan) async {
    try {
      final response =
          ApiClient.decode(
            await ApiClient.post(
              '/credits/recharge',
              {
                'packageId': plan.id,
              },
            ),
          ) as Map;

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('Solicitud creada'),
            content: SelectableText(
              '${response['message']}\n\n'
              'Referencia: ${response['referenceCode']}\n'
              'Créditos: ${response['credits']}\n'
              '${response['paypalUrl'] ?? ''}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      );

      await load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = ((overview?['plans'] as List?) ?? const [])
        .map(
          (e) => BillingPlan.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();

    final balance = overview?['balance'] ?? 0;
    final tier = overview?['tier'] ?? 'FREE';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créditos'),
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            GlassCard(
              child: Row(
                children: [
                  const Icon(
                    Icons.bolt,
                    size: 40,
                    color: AppColors.yellow,
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Saldo',
                        style: TextStyle(
                          color: AppColors.muted,
                        ),
                      ),
                      Text(
                        '$balance',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '$tier',
                        style: const TextStyle(
                          color: AppColors.cyan,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Comprar créditos / plan',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (loading) const LinearProgressIndicator(),
            ...plans.map(
              (plan) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      plan.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      '${plan.credits} créditos · ${plan.priceLabel}',
                      style: const TextStyle(
                        color: AppColors.muted,
                      ),
                    ),
                    trailing: FilledButton(
                      onPressed: () => recharge(plan),
                      child: const Text('Solicitar'),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Historial',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ...history.map(
              (log) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  log.amount >= 0
                      ? Icons.add_circle_outline
                      : Icons.remove_circle_outline,
                  color: log.amount >= 0
                      ? AppColors.green
                      : AppColors.red,
                ),
                title: Text(log.reason),
                subtitle: Text(
                  log.timestamp,
                  style: const TextStyle(
                    color: AppColors.muted,
                  ),
                ),
                trailing: Text(
                  '${log.amount >= 0 ? '+' : ''}${log.amount}',
                  style: TextStyle(
                    color: log.amount >= 0
                        ? AppColors.green
                        : AppColors.red,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}