/// Platform Printer Abstraction Interface and Test Mock.
/// Complies with Rule 92-96 (ESC/POS Thermal Printing & Standard Reports).
library printer_adapter;

enum PrinterConnectionType { usb, network, bluetooth }
enum PaperSize { mm58, mm80 }
enum PrinterStatus { ready, paperOut, offline, busy, error }

class PrinterDeviceInfo {
  final String id;
  final String name;
  final PrinterConnectionType connectionType;
  final PaperSize paperSize;
  final String? address; // IP address, USB serial, or MAC

  const PrinterDeviceInfo({
    required this.id,
    required this.name,
    required this.connectionType,
    this.paperSize = PaperSize.mm80,
    this.address,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'connectionType': connectionType.name,
        'paperSize': paperSize.name,
        if (address != null) 'address': address,
      };
}

abstract class PrinterAdapter {
  /// Discovers available printers via USB, LAN, or Bluetooth.
  Future<List<PrinterDeviceInfo>> getAvailablePrinters();

  /// Checks the hardware status of a specific printer.
  Future<PrinterStatus> getStatus(String printerId);

  /// Sends raw ESC/POS command bytes directly to the printer.
  Future<bool> printRawBytes(String printerId, List<int> bytes);

  /// Prints a rendered PDF document bytes.
  Future<bool> printPdf(String printerId, List<int> pdfBytes);

  /// Cuts the receipt paper (ESC/POS GS V 66 0).
  Future<bool> cutPaper(String printerId);

  /// Sends a cash drawer kick pulse (ESC/POS ESC p 0 25 250).
  Future<bool> openCashDrawer(String printerId);
}

/// Headless Mock Printer Adapter for Testing.
class MockPrinterAdapter implements PrinterAdapter {
  final List<PrinterDeviceInfo> _printers = [
    const PrinterDeviceInfo(
      id: 'mock_escpos_80',
      name: 'Counter ESC/POS 80mm Thermal',
      connectionType: PrinterConnectionType.usb,
      paperSize: PaperSize.mm80,
    ),
  ];

  final List<List<int>> printedPayloads = [];
  bool cashDrawerOpened = false;
  bool paperCutExecuted = false;

  @override
  Future<List<PrinterDeviceInfo>> getAvailablePrinters() async =>
      List.unmodifiable(_printers);

  @override
  Future<PrinterStatus> getStatus(String printerId) async =>
      PrinterStatus.ready;

  @override
  Future<bool> printRawBytes(String printerId, List<int> bytes) async {
    printedPayloads.add(List.from(bytes));
    return true;
  }

  @override
  Future<bool> printPdf(String printerId, List<int> pdfBytes) async {
    printedPayloads.add(List.from(pdfBytes));
    return true;
  }

  @override
  Future<bool> cutPaper(String printerId) async {
    paperCutExecuted = true;
    return true;
  }

  @override
  Future<bool> openCashDrawer(String printerId) async {
    cashDrawerOpened = true;
    return true;
  }
}
