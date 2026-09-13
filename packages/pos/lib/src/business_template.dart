/// Business domain configuration templates for the Universal POS Engine.
/// Enforces Rule 23, 36-40: ONE POS Engine across all verticals.
/// Business templates only configure visibility, labels, custom fields, and workflows,
/// never duplicating or altering core financial or ledger transaction logic.
library business_template;

enum BusinessVertical {
  clothing,
  electronics,
  pharmacy,
  restaurant,
  grocery,
  general,
}

class TemplateField {
  final String key;
  final String label;
  final bool isRequired;
  final String defaultValue;
  final List<String> allowedOptions;

  const TemplateField({
    required this.key,
    required this.label,
    this.isRequired = false,
    this.defaultValue = '',
    this.allowedOptions = const [],
  });
}

class BusinessTemplate {
  final BusinessVertical vertical;
  final String displayName;
  final List<TemplateField> supportedFields;
  final bool requiresTableAssignment;
  final bool requiresSerialTracking;
  final bool requiresExpiryTracking;

  const BusinessTemplate({
    required this.vertical,
    required this.displayName,
    this.supportedFields = const [],
    this.requiresTableAssignment = false,
    this.requiresSerialTracking = false,
    this.requiresExpiryTracking = false,
  });

  /// Validates item attributes against this domain template.
  Map<String, String> sanitizeAttributes(Map<String, dynamic> rawAttributes) {
    final sanitized = <String, String>{};
    for (final field in supportedFields) {
      final val = rawAttributes[field.key];
      if (val != null && val.toString().trim().isNotEmpty) {
        sanitized[field.key] = val.toString().trim();
      } else if (field.isRequired) {
        throw ArgumentError('Required attribute "${field.label}" (${field.key}) is missing.');
      }
    }
    return sanitized;
  }

  // Pre-configured standard industry templates
  static const clothing = BusinessTemplate(
    vertical: BusinessVertical.clothing,
    displayName: 'Apparel & Clothing',
    supportedFields: [
      TemplateField(key: 'size', label: 'Size', isRequired: true),
      TemplateField(key: 'color', label: 'Color', isRequired: true),
      TemplateField(key: 'gender', label: 'Gender'),
      TemplateField(key: 'material', label: 'Material'),
      TemplateField(key: 'season', label: 'Season'),
    ],
  );

  static const electronics = BusinessTemplate(
    vertical: BusinessVertical.electronics,
    displayName: 'Consumer Electronics & Hardware',
    requiresSerialTracking: true,
    supportedFields: [
      TemplateField(key: 'serial', label: 'Serial Number', isRequired: true),
      TemplateField(key: 'imei', label: 'IMEI'),
      TemplateField(key: 'model', label: 'Model'),
      TemplateField(key: 'warranty', label: 'Warranty Period (Months)'),
    ],
  );

  static const pharmacy = BusinessTemplate(
    vertical: BusinessVertical.pharmacy,
    displayName: 'Pharmacy & Healthcare',
    requiresExpiryTracking: true,
    supportedFields: [
      TemplateField(key: 'batch', label: 'Batch Number', isRequired: true),
      TemplateField(key: 'expiry', label: 'Expiry Date (YYYY-MM-DD)', isRequired: true),
      TemplateField(key: 'manufacturer', label: 'Manufacturer'),
    ],
  );

  static const restaurant = BusinessTemplate(
    vertical: BusinessVertical.restaurant,
    displayName: 'Dining & Restaurant',
    requiresTableAssignment: true,
    supportedFields: [
      TemplateField(key: 'table', label: 'Table Number'),
      TemplateField(key: 'order_type', label: 'Order Type (Dine-in/Takeaway/Delivery)'),
      TemplateField(key: 'modifiers', label: 'Modifiers/Notes'),
    ],
  );

  static const grocery = BusinessTemplate(
    vertical: BusinessVertical.grocery,
    displayName: 'Grocery & Supermarket',
    supportedFields: [
      TemplateField(key: 'weight_kg', label: 'Weight (kg)'),
      TemplateField(key: 'origin', label: 'Origin/Brand'),
    ],
  );

  static const general = BusinessTemplate(
    vertical: BusinessVertical.general,
    displayName: 'General Retail',
    supportedFields: [],
  );

  static BusinessTemplate forVertical(BusinessVertical vertical) {
    switch (vertical) {
      case BusinessVertical.clothing:
        return clothing;
      case BusinessVertical.electronics:
        return electronics;
      case BusinessVertical.pharmacy:
        return pharmacy;
      case BusinessVertical.restaurant:
        return restaurant;
      case BusinessVertical.grocery:
        return grocery;
      case BusinessVertical.general:
        return general;
    }
  }
}
