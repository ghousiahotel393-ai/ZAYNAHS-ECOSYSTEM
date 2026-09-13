import 'package:core/core.dart';
import 'package:database/database.dart';
import 'package:flutter/material.dart';
import 'package:ui/ui.dart';

class WalletsScreen extends StatefulWidget {
  final WalletRepository walletRepo;

  const WalletsScreen({super.key, required this.walletRepo});

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  List<WalletEntity> _wallets = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _wallets = widget.walletRepo.listActiveWallets();
    });
  }

  void _transfer(String from, String to, int minor) {
    widget.walletRepo.transferBetweenWallets(
      fromWalletId: from,
      toWalletId: to,
      amount: Money.fromMinorUnits(minor, Currency.pkr),
      actorId: 'usr_admin_01',
      deviceId: 'dev_local_pos',
      notes: 'Counter float rebalance',
    );
    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(AppColors.success),
        content: Text('Inter-wallet transfer complete!'),
      ),
    );
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
              const Text('Authoritative Wallet Balances', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: 1.6,
              ),
              itemCount: _wallets.length,
              itemBuilder: (ctx, i) {
                final w = _wallets[i];
                final bal = widget.walletRepo.getWalletBalance(w.id);
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: const Color(AppColors.darkSurface),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: const Color(AppColors.darkBorder)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(w.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Chip(
                            label: Text(w.type, style: const TextStyle(fontSize: 10, color: Color(AppColors.info))),
                            backgroundColor: const Color(AppColors.darkSurfaceRaised),
                          ),
                        ],
                      ),
                      Text(
                        'Rs ${(bal.minorUnits / 100).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(AppColors.success)),
                      ),
                      Text('Account: ${w.id}', style: const TextStyle(fontSize: 11, color: Color(AppColors.darkTextMuted))),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
