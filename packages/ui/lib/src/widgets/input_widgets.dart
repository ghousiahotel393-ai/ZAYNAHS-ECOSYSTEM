/// Input UI Components for Zaynahs Ecosystem.
/// Includes AppButton, AppTextInput, AppSearchBar, AppDropdown, AppCheckbox, and AppSwitch.
library input_widgets;

enum ButtonVariant { primary, secondary, danger, ghost }
enum ButtonSize { small, medium, large }

/// 6. AppButton Component model.
class AppButtonConfig {
  final String label;
  final ButtonVariant variant;
  final ButtonSize size;
  final bool isLoading;
  final bool isDisabled;
  final String? iconName;
  final void Function()? onPressed;

  const AppButtonConfig({
    required this.label,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.isLoading = false,
    this.isDisabled = false,
    this.iconName,
    this.onPressed,
  });
}

/// 7. AppTextInput Component model.
class AppTextInputConfig {
  final String label;
  final String? placeholder;
  final String initialValue;
  final String? errorText;
  final String? helperText;
  final bool isPassword;
  final bool isReadOnly;
  final bool isAutofocus;
  final String? prefixIcon;
  final String? suffixIcon;
  final void Function(String value)? onChanged;
  final void Function(String value)? onSubmitted;

  const AppTextInputConfig({
    required this.label,
    this.placeholder,
    this.initialValue = '',
    this.errorText,
    this.helperText,
    this.isPassword = false,
    this.isReadOnly = false,
    this.isAutofocus = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
  });
}

/// 8. AppSearchBar Component model.
class AppSearchBarConfig {
  final String placeholder;
  final String query;
  final int debounceMs;
  final void Function(String query)? onQueryChanged;
  final void Function()? onClear;

  const AppSearchBarConfig({
    this.placeholder = 'Search...',
    this.query = '',
    this.debounceMs = 300,
    this.onQueryChanged,
    this.onClear,
  });
}

/// 9. AppDropdown Component model.
class DropdownOption<T> {
  final T value;
  final String label;
  final String? iconName;

  const DropdownOption({
    required this.value,
    required this.label,
    this.iconName,
  });
}

class AppDropdownConfig<T> {
  final String label;
  final List<DropdownOption<T>> options;
  final T? selectedValue;
  final String? placeholder;
  final void Function(T? value)? onChanged;

  const AppDropdownConfig({
    required this.label,
    required this.options,
    this.selectedValue,
    this.placeholder,
    this.onChanged,
  });
}

/// 10. AppCheckbox Component model.
class AppCheckboxConfig {
  final String label;
  final bool isChecked;
  final bool isDisabled;
  final void Function(bool checked)? onChanged;

  const AppCheckboxConfig({
    required this.label,
    required this.isChecked,
    this.isDisabled = false,
    this.onChanged,
  });
}

/// 11. AppSwitch Component model.
class AppSwitchConfig {
  final String label;
  final bool isOn;
  final bool isDisabled;
  final void Function(bool value)? onChanged;

  const AppSwitchConfig({
    required this.label,
    required this.isOn,
    this.isDisabled = false,
    this.onChanged,
  });
}
