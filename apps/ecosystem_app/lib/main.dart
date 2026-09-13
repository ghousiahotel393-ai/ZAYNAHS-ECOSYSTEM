import 'dart:io';
import 'package:backup/backup.dart';
import 'package:cctv/cctv.dart';
import 'package:database/database.dart';
import 'package:flutter/material.dart';
import 'package:pos/pos.dart';
import 'package:storage/storage.dart';
import 'package:ui/ui.dart';

import 'src/screens/backup_screen.dart';
import 'src/screens/cctv_screen.dart';
import 'src/screens/inventory_screen.dart';
import 'src/screens/pos_screen.dart';
import 'src/screens/reports_screen.dart';
import 'src/screens/wallets_screen.dart';
import 'src/seed_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dataDir = Directory('data');
  if (!dataDir.existsSync()) dataDir.createSync(recursive: true);

  final storageDir = Directory('data/storage');
  if (!storageDir.existsSync()) storageDir.createSync(recursive: true);

  final db = AppDatabase.openFile('data/ecosystem.db');
  db.initialize();

  final storage = FileStorageService(storageDir.path);
  final invRepo = InventoryRepository(db);
  final walletRepo = WalletRepository(db);
  final salesRepo = SalesRepository(db: db, inventoryRepo: invRepo, walletRepo: walletRepo);
  final posEngine = UniversalPosEngine(
    salesRepo: salesRepo,
    inventoryRepo: invRepo,
    walletRepo: walletRepo,
  );
  final reportingEngine = ReportingEngine(
    db: db,
    inventoryRepo: invRepo,
    walletRepo: walletRepo,
    salesRepo: salesRepo,
  );
  final backupWriter = BackupWriter(db: db, storageService: storage);
  final cctvDiscovery = CameraDiscoveryService(db: db);

  seedBaselineData(db, invRepo, walletRepo, cctvDiscovery);

  runApp(ZaynahsEcosystemApp(
    db: db,
    invRepo: invRepo,
    walletRepo: walletRepo,
    posEngine: posEngine,
    reportingEngine: reportingEngine,
    backupWriter: backupWriter,
    cctvDiscovery: cctvDiscovery,
  ));
}

class ZaynahsEcosystemApp extends StatelessWidget {
  final AppDatabase db;
  final InventoryRepository invRepo;
  final WalletRepository walletRepo;
  final UniversalPosEngine posEngine;
  final ReportingEngine reportingEngine;
  final BackupWriter backupWriter;
  final CameraDiscoveryService cctvDiscovery;

  const ZaynahsEcosystemApp({
    super.key,
    required this.db,
    required this.invRepo,
    required this.walletRepo,
    required this.posEngine,
    required this.reportingEngine,
    required this.backupWriter,
    required this.cctvDiscovery,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zaynahs Ecosystem',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(AppColors.darkBackground),
        cardColor: const Color(AppColors.darkSurface),
        colorScheme: const ColorScheme.dark(
          primary: Color(AppColors.primaryValue),
          secondary: Color(AppColors.secondaryValue),
          surface: Color(AppColors.darkSurface),
        ),
      ),
      home: EcosystemHomeShell(
        db: db,
        invRepo: invRepo,
        walletRepo: walletRepo,
        posEngine: posEngine,
        reportingEngine: reportingEngine,
        backupWriter: backupWriter,
        cctvDiscovery: cctvDiscovery,
      ),
    );
  }
}

class EcosystemHomeShell extends StatefulWidget {
  final AppDatabase db;
  final InventoryRepository invRepo;
  final WalletRepository walletRepo;
  final UniversalPosEngine posEngine;
  final ReportingEngine reportingEngine;
  final BackupWriter backupWriter;
  final CameraDiscoveryService cctvDiscovery;

  const EcosystemHomeShell({
    super.key,
    required this.db,
    required this.invRepo,
    required this.walletRepo,
    required this.posEngine,
    required this.reportingEngine,
    required this.backupWriter,
    required this.cctvDiscovery,
  });

  @override
  State<EcosystemHomeShell> createState() => _EcosystemHomeShellState();
}

class _EcosystemHomeShellState extends State<EcosystemHomeShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final screenType = ResponsiveLayoutHelper.getScreenType(width);

    final screens = [
      PosScreen(
        db: widget.db,
        invRepo: widget.invRepo,
        walletRepo: widget.walletRepo,
        posEngine: widget.posEngine,
      ),
      InventoryScreen(invRepo: widget.invRepo),
      WalletsScreen(walletRepo: widget.walletRepo),
      ReportsScreen(reportingEngine: widget.reportingEngine),
      CctvScreen(cctvDiscovery: widget.cctvDiscovery),
      BackupScreen(backupWriter: widget.backupWriter),
    ];

    if (screenType == ScreenType.mobile) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Zaynahs Ecosystem', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(AppColors.darkSurface),
        ),
        body: screens[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(AppColors.darkSurface),
          selectedItemColor: const Color(AppColors.primaryLightValue),
          unselectedItemColor: const Color(AppColors.darkTextMuted),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: 'POS'),
            BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Stock'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Wallets'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'P&L'),
            BottomNavigationBarItem(icon: Icon(Icons.videocam), label: 'CCTV'),
            BottomNavigationBarItem(icon: Icon(Icons.backup), label: 'Backup'),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            backgroundColor: const Color(AppColors.darkSurface),
            selectedIconTheme: const IconThemeData(color: Color(AppColors.primaryLightValue)),
            unselectedIconTheme: const IconThemeData(color: Color(AppColors.darkTextMuted)),
            labelType: screenType == ScreenType.desktop ? NavigationRailLabelType.all : NavigationRailLabelType.none,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: CircleAvatar(
                backgroundColor: Color(AppColors.primaryValue),
                child: Text('Z', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.point_of_sale), label: Text('POS')),
              NavigationRailDestination(icon: Icon(Icons.inventory_2), label: Text('Inventory')),
              NavigationRailDestination(icon: Icon(Icons.account_balance_wallet), label: Text('Wallets')),
              NavigationRailDestination(icon: Icon(Icons.bar_chart), label: Text('P&L')),
              NavigationRailDestination(icon: Icon(Icons.videocam), label: Text('CCTV')),
              NavigationRailDestination(icon: Icon(Icons.backup), label: Text('Backup')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Color(AppColors.darkBorder)),
          Expanded(child: screens[_selectedIndex]),
        ],
      ),
    );
  }
}
