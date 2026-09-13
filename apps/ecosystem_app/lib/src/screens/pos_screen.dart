import 'package:core/core.dart';
import 'package:database/database.dart';
import 'package:flutter/material.dart';
import 'package:pos/pos.dart';
import 'package:ui/ui.dart';

class PosScreen extends StatefulWidget {
  final AppDatabase db;
  final InventoryRepository invRepo;
  final WalletRepository walletRepo;
  final UniversalPosEngine posEngine;

  const PosScreen({
    super.key,
    required this.db,
    required this.invRepo,
    required this.walletRepo,
    required this.posEngine,
  });

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final Map<String, int> _cart = {};
  String _selectedWalletId = 'wal_cash';
  List<InventoryItemEntity> _items = [];

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  void _loadCatalog() {
    setState(() {
      _items = widget.invRepo.listActiveItems();
    });
  }

  void _addToCart(String itemId) {
    final available = widget.invRepo.getStockBalance(itemId);
    final currentInCart = _cart[itemId] ?? 0;
    if (currentInCart < available) {
      setState(() {
        _cart[itemId] = currentInCart + 1;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient stock available!')),
      );
    }
  }

  void _updateCartQty(String itemId, int delta) {
    setState(() {
      final current = _cart[itemId] ?? 0;
      final updated = current + delta;
      if (updated <= 0) {
        _cart.remove(itemId);
      } else {
        _cart[itemId] = updated;
      }
    });
  }

  void _checkout() {
    if (_cart.isEmpty) return;
    final curr = Currency.pkr;
    final lineItems = <CartLineItem>[];
    var totalMinor = 0;

    for (final entry in _cart.entries) {
      final it = _items.firstWhere((i) => i.id == entry.key);
      lineItems.add(CartLineItem(
        itemId: it.id,
        itemName: it.name,
        quantity: entry.value,
        unitPrice: it.sellingPrice,
        costPrice: it.costPrice,
        itemDiscount: Money.zero(curr),
      ));
      totalMinor += it.sellingPrice.minorUnits * entry.value;
    }

    final cart = PosCart(
      items: lineItems,
      cartDiscount: Money.zero(curr),
      tax: Money.zero(curr),
    );

    final invoice = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    try {
      final sale = widget.posEngine.checkout(
        cart: cart,
        invoiceNumber: invoice,
        paymentAllocations: [
          PaymentAllocation(
            walletId: _selectedWalletId,
            amount: Money.fromMinorUnits(totalMinor, curr),
          ),
        ],
        actorId: 'usr_cashier_01',
        deviceId: 'dev_local_pos',
      );

      setState(() {
        _cart.clear();
        _loadCatalog();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(AppColors.success),
          content: Text('Sale Complete! Invoice: ${sale.invoiceNumber} (Rs ${totalMinor / 100})'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(AppColors.danger),
          content: Text('Checkout Error: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cols = ResponsiveLayoutHelper.calculatePosGridColumns(width);

    return Row(
      children: [
        // Product Grid
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Product Catalog (${_items.length} items)',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final it = _items[i];
                      final stock = widget.invRepo.getStockBalance(it.id);
                      return InkWell(
                        onTap: () => _addToCart(it.id),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: const Color(AppColors.darkSurface),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(color: const Color(AppColors.darkBorder)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(it.sku, style: const TextStyle(fontSize: 11, color: Color(AppColors.info))),
                              const SizedBox(height: 4),
                              Text(it.name, maxLines: 2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const Spacer(),
                              Text(
                                'Rs ${(it.sellingPrice.minorUnits / 100).toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(AppColors.success)),
                              ),
                              Text('Stock: $stock units', style: const TextStyle(fontSize: 11, color: Color(AppColors.darkTextSecondary))),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // Cart Drawer
        Container(
          width: 360,
          color: const Color(AppColors.darkSurfaceRaised),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Active Cart', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Color(AppColors.danger)),
                    onPressed: () => setState(() => _cart.clear()),
                  ),
                ],
              ),
              const Divider(color: Color(AppColors.darkBorder)),
              Expanded(
                child: _cart.isEmpty
                    ? const Center(child: Text('Cart is empty', style: TextStyle(color: Color(AppColors.darkTextMuted))))
                    : ListView(
                        children: _cart.entries.map((entry) {
                          final it = _items.firstWhere((i) => i.id == entry.key);
                          final lineTotal = it.sellingPrice.minorUnits * entry.value;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(it.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            subtitle: Text('Rs ${(lineTotal / 100).toStringAsFixed(2)}', style: const TextStyle(color: Color(AppColors.success), fontSize: 12)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.remove, size: 16), onPressed: () => _updateCartQty(it.id, -1)),
                                Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(icon: const Icon(Icons.add, size: 16), onPressed: () => _updateCartQty(it.id, 1)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const Divider(color: Color(AppColors.darkBorder)),
              DropdownButton<String>(
                value: _selectedWalletId,
                isExpanded: true,
                dropdownColor: const Color(AppColors.darkSurface),
                items: const [
                  DropdownMenuItem(value: 'wal_cash', child: Text('Cash Drawer')),
                  DropdownMenuItem(value: 'wal_bank', child: Text('HBL Bank Account')),
                  DropdownMenuItem(value: 'wal_online', child: Text('Easypaisa Online')),
                ],
                onChanged: (val) => setState(() => _selectedWalletId = val!),
              ),
              const SizedBox(height: AppSpacing.sm),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppColors.success),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                onPressed: _cart.isEmpty ? null : _checkout,
                child: const Text('Complete Checkout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
