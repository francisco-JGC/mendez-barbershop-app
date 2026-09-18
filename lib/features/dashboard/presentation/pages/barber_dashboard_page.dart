import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/barber_dashboard_providers.dart';
import '../../domain/entities/barber_dashboard_summary.dart';
import '../../domain/entities/dashboard_period.dart';

/// Read-only personal summary for a barber. This is the whole app for that
/// role — no POS, no catalog, no printer: barbers don't ring up sales, they
/// check what they earned.
class BarberDashboardPage extends ConsumerWidget {
  const BarberDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final period = ref.watch(dashboardPeriodProvider);
    final async = ref.watch(barberDashboardProvider(period));

    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${_firstName(user?.name ?? '')} 👋'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(barberDashboardProvider(period).future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _PeriodSelector(
              value: period,
              onChanged: (next) =>
                  ref.read(dashboardPeriodProvider.notifier).state = next,
            ),
            const Gap(16),
            async.when(
              data: (summary) => _Summary(summary: summary, period: period),
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => _Error(
                message: error is Failure
                    ? error.message
                    : 'No se pudo cargar tu resumen',
                onRetry: () => ref.invalidate(barberDashboardProvider(period)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _firstName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(' ').first;
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.value, required this.onChanged});

  final DashboardPeriod value;
  final ValueChanged<DashboardPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<DashboardPeriod>(
      showSelectedIcon: false,
      segments: [
        for (final period in DashboardPeriod.values)
          ButtonSegment(value: period, label: Text(period.label)),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary, required this.period});

  final BarberDashboardSummary summary;
  final DashboardPeriod period;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary.stationNumber != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              avatar: const Icon(Icons.event_seat, size: 18),
              label: Text('Silla ${summary.stationNumber}'),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const Gap(12),
        ],
        _EarningsCard(summary: summary, period: period),
        const Gap(12),
        _StatTile(
          icon: Icons.content_cut,
          label: period.servicesLabel,
          value: '${summary.cutsCount}',
        ),
        const Gap(8),
        _StatTile(
          icon: Icons.payments_outlined,
          label: 'Total generado',
          value: Formatters.money(summary.totalRevenue),
        ),
        const Gap(8),
        _StatTile(
          icon: Icons.trending_up,
          label: 'Promedio por servicio',
          value: Formatters.money(summary.averagePerCut),
          hint: summary.isEmpty
              ? 'Sin servicios registrados'
              : '${summary.cutsCount} servicio${summary.cutsCount == 1 ? '' : 's'} en total',
        ),
        const Gap(16),
        _BreakdownCard(entries: summary.serviceBreakdown),
      ],
    );
  }
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.summary, required this.period});

  final BarberDashboardSummary summary;
  final DashboardPeriod period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = summary.impliedCommissionRate;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryContainer],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TU GANANCIA ${period.phrase.toUpperCase()}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white70,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Gap(8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      Formatters.money(summary.commission),
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Gap(6),
                  Text(
                    rate == null
                        ? 'Aún no hay servicios en este periodo'
                        : 'Sobre ${Formatters.money(summary.totalRevenue)} en servicios (${_percent(rate)})',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Gap(12),
            const CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.accent,
              child: Icon(Icons.savings_outlined,
                  color: AppColors.primary, size: 26),
            ),
          ],
        ),
      ),
    );
  }

  /// 0.5 → "50%", 0.425 → "42.5%".
  static String _percent(double rate) {
    final pct = rate * 100;
    final text = pct
        .toStringAsFixed(1)
        .replaceFirst(RegExp(r'\.0$'), '');
    return '$text%';
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.08),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(label, style: theme.textTheme.bodyMedium),
        subtitle: hint == null ? null : Text(hint!),
        trailing: Text(
          value,
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.entries});

  final List<ServiceBreakdownEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.checklist, size: 18, color: AppColors.muted),
                const Gap(8),
                Text('Desglose por servicio',
                    style: theme.textTheme.titleMedium),
              ],
            ),
            const Gap(4),
            Text(
              'Cantidad de veces que realizaste cada tipo de servicio.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
            const Gap(12),
            if (entries.isEmpty)
              Text(
                'Aún no has realizado servicios en este periodo.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.muted),
              )
            else
              for (final entry in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.serviceName,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      const Gap(8),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          '${entry.count} ${entry.count == 1 ? 'vez' : 'veces'}',
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Column(
        children: [
          Icon(Icons.cloud_off, size: 56, color: Colors.grey.shade400),
          const Gap(12),
          Text(message, textAlign: TextAlign.center),
          const Gap(12),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
