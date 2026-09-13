import 'package:cctv/cctv.dart';
import 'package:core/core.dart';
import 'package:database/database.dart';

/// Seeds baseline demo enterprise data for local testing.
void seedBaselineData(
  AppDatabase db,
  InventoryRepository invRepo,
  WalletRepository walletRepo,
  CameraDiscoveryService cctvDiscovery,
) {
  final now = DateTime.now().toUtc();
  const curr = Currency.pkr;

  // 1. Ecosystem
  db.connection.execute(
    '''
    INSERT OR IGNORE INTO ecosystems (id, name, created_at, updated_at, settings_json)
    VALUES ('eco_default', 'Zaynahs Master Enterprise', ?, ?, '{}');
    ''',
    [now.toIso8601String(), now.toIso8601String()],
  );

  // 2. Trusted Device
  db.connection.execute(
    '''
    INSERT OR IGNORE INTO devices (id, name, trust_status, public_key, paired_at, last_seen_at, device_type)
    VALUES ('dev_local_pos', 'Primary POS Station', 'TRUSTED', 'pub_key_master_station', ?, ?, 'terminal');
    ''',
    [now.toIso8601String(), now.toIso8601String()],
  );

  // 3. Users: Admin & Cashier
  db.connection.execute(
    '''
    INSERT OR IGNORE INTO users (id, name, email, role, password_hash, pin_hash, is_active, created_at, updated_at)
    VALUES 
      ('usr_admin_01', 'System Owner', 'owner@zaynahs.com', 'Owner', 'hash_admin', 'hash_pin', 1, ?, ?),
      ('usr_cashier_01', 'Counter Cashier', 'cashier@zaynahs.com', 'Cashier', 'hash_cashier', 'hash_pin', 1, ?, ?);
    ''',
    [now.toIso8601String(), now.toIso8601String(), now.toIso8601String(), now.toIso8601String()],
  );

  // 4. Wallets: Cash, Bank, Online
  final existingWallets = walletRepo.listActiveWallets();
  if (existingWallets.isEmpty) {
    const cashInit = Money.fromMinorUnits(5000000, curr);
    walletRepo.createWallet(WalletEntity(
      id: 'wal_cash',
      name: 'Main Cash Drawer',
      type: 'CASH',
      currency: curr,
      balance: cashInit,
      createdAt: now,
      updatedAt: now,
    ));
    walletRepo.recordTransaction(
      walletId: 'wal_cash',
      type: 'DEPOSIT',
      amount: cashInit,
      referenceId: 'OPENING-CASH',
      actorId: 'usr_admin_01',
      deviceId: 'dev_local_pos',
      notes: 'Initial cash drawer float',
    );

    const bankInit = Money.fromMinorUnits(20000000, curr);
    walletRepo.createWallet(WalletEntity(
      id: 'wal_bank',
      name: 'HBL Business Account',
      type: 'BANK',
      currency: curr,
      balance: bankInit,
      createdAt: now,
      updatedAt: now,
    ));
    walletRepo.recordTransaction(
      walletId: 'wal_bank',
      type: 'DEPOSIT',
      amount: bankInit,
      referenceId: 'OPENING-BANK',
      actorId: 'usr_admin_01',
      deviceId: 'dev_local_pos',
      notes: 'Opening bank account balance',
    );

    const onlineInit = Money.fromMinorUnits(3500000, curr);
    walletRepo.createWallet(WalletEntity(
      id: 'wal_online',
      name: 'Easypaisa / Raast Online',
      type: 'ONLINE',
      currency: curr,
      balance: onlineInit,
      createdAt: now,
      updatedAt: now,
    ));
    walletRepo.recordTransaction(
      walletId: 'wal_online',
      type: 'DEPOSIT',
      amount: onlineInit,
      referenceId: 'OPENING-ONLINE',
      actorId: 'usr_admin_01',
      deviceId: 'dev_local_pos',
      notes: 'Opening online account balance',
    );
  }

  // 5. Items & Movements
  final existingItems = invRepo.listActiveItems();
  if (existingItems.isEmpty) {
    final catalog = [
      {'id': 'itm_01', 'sku': 'SHIRT-POLO-01', 'name': 'Classic Pique Polo Shirt', 'cost': 120000, 'price': 250000, 'stock': 50},
      {'id': 'itm_02', 'sku': 'JEANS-DENIM-02', 'name': 'Slim Fit Stretch Jeans', 'cost': 220000, 'price': 450000, 'stock': 35},
      {'id': 'itm_03', 'sku': 'HOODIE-FLEECE-03', 'name': 'Premium Fleece Hoodie', 'cost': 280000, 'price': 550000, 'stock': 20},
      {'id': 'itm_04', 'sku': 'ACC-LEATHER-04', 'name': 'Genuine Leather Bifold Wallet', 'cost': 90000, 'price': 180000, 'stock': 40},
      {'id': 'itm_05', 'sku': 'CAP-SNAPBACK-05', 'name': 'Embroidered Snapback Cap', 'cost': 60000, 'price': 120000, 'stock': 60},
    ];

    for (final item in catalog) {
      final iId = item['id'] as String;
      invRepo.createItem(InventoryItemEntity(
        id: iId,
        sku: item['sku'] as String,
        name: item['name'] as String,
        costPrice: Money.fromMinorUnits(item['cost'] as int, curr),
        sellingPrice: Money.fromMinorUnits(item['price'] as int, curr),
        createdAt: now,
        updatedAt: now,
      ));

      invRepo.recordMovement(
        itemId: iId,
        type: 'PURCHASE',
        quantity: item['stock'] as int,
        costPrice: Money.fromMinorUnits(item['cost'] as int, curr),
        referenceId: 'PO-INITIAL-${item['sku']}',
        actorId: 'usr_admin_01',
        deviceId: 'dev_local_pos',
      );
    }
  }

  // 6. Cameras
  final existingCams = cctvDiscovery.listCameras();
  if (existingCams.isEmpty) {
    cctvDiscovery.registerCamera(
      name: 'Counter & Register 01 (HD)',
      type: CameraSourceType.rtsp,
      sourceUrl: 'rtsp://192.168.1.120:554/live/ch0',
      deviceId: 'dev_local_pos',
    );
    cctvDiscovery.registerCamera(
      name: 'Entrance & Customer Area (HD)',
      type: CameraSourceType.rtsp,
      sourceUrl: 'rtsp://192.168.1.121:554/live/ch0',
      deviceId: 'dev_local_pos',
    );
  }
}
