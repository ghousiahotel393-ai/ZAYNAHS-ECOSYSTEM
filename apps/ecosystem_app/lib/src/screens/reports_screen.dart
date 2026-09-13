import 'package:flutter/material.dart';
import 'package:pos/pos.dart';
import 'package:ui/ui.dart';

class ReportsScreen extends StatefulWidget {
  final ReportingEngine reportingEngine;

  const ReportsScreen({super.key, required this.reportingEngine});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ProfitAndLossReport? _pnl;

  @override
  void initState() {
    super.initState();
    _loadPnL();
  }

  void _loadPnL() {
    final now = DateTime.now().toUtc();
    final start = now.subtract(const Duration(days: 30));
    setState(() {
      _pnl = widget.reportingEngine.generateProfitAndLoss(startDate: start, endDate: now);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ledger-Derived Profit & Loss (30 Days)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPnL),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_pnl != null)
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    title: 'Gross Sales Revenue',
                    value: 'Rs ${(_pnl!.grossRevenue.minorUnits / 100).toStringAsFixed(2)}',
                    color: const Color(AppColors.success),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _MetricCard(
                    title: 'Cost of Goods Sold (COGS)',
                    value: 'Rs ${(_pnl!.costOfGoodsSold.minorUnits / 100).toStringAsFixed(2)}',
                    color: const Color(AppColors.danger),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _MetricCard(
                    title: 'Net Operating Profit',
                    value: 'Rs ${(_pnl!.netProfit.minorUnits / 100).toStringAsFixed(2)}',
                    color: const Color(AppColors.info),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _MetricCard({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(AppColors.darkSurface),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: const Color(AppColors.darkBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, color: Color(AppColors.darkTextSecondary))),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
