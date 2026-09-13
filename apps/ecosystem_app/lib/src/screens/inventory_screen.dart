import 'package:core/core.dart';
import 'package:database/database.dart';
import 'package:flutter/material.dart';
import 'package:ui/ui.dart';

class InventoryScreen extends StatefulWidget {
  final InventoryRepository invRepo;

  const InventoryScreen({super.key, required this.invRepo});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<InventoryItemEntity> _items = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _items = widget.invRepo.listActiveItems();
    });
  }

  void _restock(String itemId, int qty) {
    widget.invRepo.recordMovement(
      itemId: itemId,
      type: 'PURCHASE',
      quantity: qty,
      costPrice: const Money.fromMinorUnits(50000, Currency.pkr),
      referenceId: 'PO-RESTOCK-${DateTime.now().millisecondsSinceEpoch}',
      actorId: 'usr_admin_01',
      deviceId: 'dev_local_pos',
    );
    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(AppColors.success),
        content: Text('Restocked +$qty units successfully!'),
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
              const Text('Immutable Inventory Stock Ledger', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (ctx, i) => const Divider(color: Color(AppColors.darkBorder)),
              itemBuilder: (ctx, i) {
                final it = _items[i];
                final stock = widget.invRepo.getStockBalance(it.id);
                return ListTile(
                  tileColor: const Color(AppColors.darkSurface),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  leading: CircleAvatar(
                    backgroundColor: const Color(AppColors.primaryValue),
                    child: Text(it.name[0], style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('SKU: ${it.sku} | Cost: Rs ${(it.costPrice.minorUnits / 100).toStringAsFixed(2)} | Retail: Rs ${(it.sellingPrice.minorUnits / 100).toStringAsFixed(2)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$stock units',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: stock < 10 ? const Color(AppColors.danger) : const Color(AppColors.success),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      OutlinedButton(
                        onPressed: () => _restock(it.id, 20),
                        child: const Text('+ Restock 20'),
                      ),
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
