import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sub_page.dart';
import 'booking_models.dart';
import 'booking_repository.dart';
import 'regions.dart';

/// Add or edit one address. Route: /addresses/form   (extra: SavedAddress? to edit)
/// Pops with the saved SavedAddress.
class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key, this.existing});
  final SavedAddress? existing;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  late final TextEditingController _label;
  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _city;
  late final TextEditingController _postal;
  late final TextEditingController _instructions;
  late String _country;
  String? _region;
  bool _default = false;
  bool _saving = false;
  final _errors = <String, String>{};
  String? _formError;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _label = TextEditingController(text: a?.label ?? '');
    _line1 = TextEditingController(text: a?.addressLine1 ?? '');
    _line2 = TextEditingController(text: a?.addressLine2 ?? '');
    _city = TextEditingController(text: a?.city ?? '');
    _postal = TextEditingController(text: a?.postalCode ?? '');
    _instructions = TextEditingController(text: a?.instructions ?? '');
    _country = a?.country ?? 'CA';
    _region = a?.region;
    _default = a?.isDefault ?? false;
  }

  @override
  void dispose() {
    for (final c in [_label, _line1, _line2, _city, _postal, _instructions]) {
      c.dispose();
    }
    super.dispose();
  }

  InputDecoration _deco(String label, {String? error, String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
        filled: true,
        fillColor: AppColors.authBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.fieldBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.fieldBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.blueDark, width: 1.6)),
      );

  bool _validate() {
    _errors.clear();
    if (_line1.text.trim().length < 3) _errors['line1'] = 'Enter the street address.';
    if (_city.text.trim().length < 2) _errors['city'] = 'Enter the city.';
    if (_region == null) _errors['region'] = 'Choose one.';
    if (!postalValid(_country, _postal.text)) _errors['postal'] = 'Enter a valid ${postalLabel[_country]!.toLowerCase()}.';
    setState(() {});
    return _errors.isEmpty;
  }

  Future<void> _save() async {
    if (_saving || !_validate()) return;
    setState(() {
      _saving = true;
      _formError = null;
    });
    String? nullable(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    try {
      final saved = await ref.read(bookingRepositoryProvider).saveAddress({
        'label': nullable(_label),
        'country': _country,
        'address_line1': _line1.text.trim(),
        'address_line2': nullable(_line2),
        'city': _city.text.trim(),
        'region': _region,
        'postal_code': _postal.text.trim().toUpperCase(),
        'instructions': nullable(_instructions),
        'is_default': _default,
      }, id: widget.existing?.id);
      if (mounted) context.pop(saved);
    } on ApiError catch (e) {
      if (mounted) setState(() => _formError = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final regions = regionsByCountry[_country]!;
    return SubPageScaffold(
      title: widget.existing == null ? 'Add address' : 'Edit address',
      children: [
        TextField(controller: _label, maxLength: 40, decoration: _deco('Label (optional)', hint: 'Home, Office...').copyWith(counterText: '')),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: _country,
          decoration: _deco('Country'),
          items: [for (final e in countryNames.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() {
            _country = v ?? _country;
            _region = null;
          }),
        ),
        const SizedBox(height: 14),
        TextField(controller: _line1, textCapitalization: TextCapitalization.words, decoration: _deco('Street address', error: _errors['line1'])),
        const SizedBox(height: 14),
        TextField(controller: _line2, textCapitalization: TextCapitalization.words, decoration: _deco('Apartment, suite, unit (optional)')),
        const SizedBox(height: 14),
        TextField(controller: _city, textCapitalization: TextCapitalization.words, decoration: _deco('City', error: _errors['city'])),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          key: ValueKey(_country),
          // ignore: deprecated_member_use
          value: _region,
          isExpanded: true,
          decoration: _deco(regionLabel[_country]!, error: _errors['region']),
          items: [for (final r in regions) DropdownMenuItem(value: r, child: Text(r))],
          onChanged: (v) => setState(() => _region = v),
        ),
        const SizedBox(height: 14),
        TextField(controller: _postal, textCapitalization: TextCapitalization.characters, decoration: _deco(postalLabel[_country]!, error: _errors['postal'])),
        const SizedBox(height: 14),
        TextField(
          controller: _instructions,
          maxLength: 300,
          maxLines: 2,
          decoration: _deco('Access notes (optional)', hint: 'Gate code, which door, parking...'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _default,
          onChanged: (v) => setState(() => _default = v),
          title: const Text('Use as my default address', style: TextStyle(fontSize: 14, color: AppColors.navy)),
        ),
        if (_formError != null)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_formError!, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.blueDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Text('Save address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
