import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_error.dart';
import '../../core/widgets/auth_widgets.dart';
import '../../core/widgets/sub_page.dart';
import 'profile_controller.dart';
import 'user_profile.dart';

enum ProfileField { name, phone, email, address }

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.field});
  final ProfileField field;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _a;
  late final TextEditingController _b;
  Map<String, String> _errors = {};
  String? _banner;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final p = ref.read(profileProvider).value ?? UserProfile.empty;
    final (a, b) = switch (widget.field) {
      ProfileField.name => (p.firstName, p.lastName),
      ProfileField.phone => (p.phone ?? '', ''),
      ProfileField.email => (p.email, ''),
      ProfileField.address => (p.address ?? '', ''),
    };
    _a = TextEditingController(text: a);
    _b = TextEditingController(text: b);
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final errors = <String, String>{};
    final body = <String, dynamic>{};
    final a = _a.text.trim();
    final b = _b.text.trim();

    switch (widget.field) {
      case ProfileField.name:
        if (a.isEmpty) errors['first_name'] = 'Enter your first name.';
        if (b.isEmpty) errors['last_name'] = 'Enter your last name.';
        body.addAll({'first_name': a, 'last_name': b});
      case ProfileField.phone:
        if (a.isNotEmpty && !RegExp(r'^\+?[0-9\s\-()]{7,20}$').hasMatch(a)) {
          errors['phone'] = 'Enter a valid phone number.';
        }
        body['phone'] = a.isEmpty ? null : a;
      case ProfileField.address:
        if (a.length > 500) errors['address'] = 'Keep the address under 500 characters.';
        body['address'] = a.isEmpty ? null : a;
      case ProfileField.email:
        return;
    }

    setState(() {
      _errors = errors;
      _banner = null;
    });
    if (errors.isNotEmpty) return;

    setState(() => _loading = true);
    try {
      await ref.read(profileProvider.notifier).save(body);
      if (!mounted) return;
      showToast(context, 'Saved.');
      context.pop();
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.fields.isNotEmpty) {
          _errors = e.fields;
        } else {
          _banner = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[ErrorSlot(_banner)];

    switch (widget.field) {
      case ProfileField.name:
        children.addAll([
          AppTextField(
            label: 'First Name',
            hint: 'Enter your first name',
            controller: _a,
            textInputAction: TextInputAction.next,
            errorText: _errors['first_name'],
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Last Name',
            hint: 'Enter your last name',
            controller: _b,
            textInputAction: TextInputAction.done,
            errorText: _errors['last_name'],
            onSubmitted: (_) => _save(),
          ),
        ]);
      case ProfileField.phone:
        children.add(AppTextField(
          label: 'Phone Number',
          hint: 'Enter your phone number',
          controller: _a,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          errorText: _errors['phone'],
          onSubmitted: (_) => _save(),
        ));
      case ProfileField.address:
        children.add(AppTextField(
          label: 'Address',
          hint: 'Enter your address',
          controller: _a,
          maxLines: 3,
          errorText: _errors['address'],
        ));
      case ProfileField.email:
        children.add(AppTextField(
          label: 'Email',
          hint: '',
          controller: _a,
          readOnly: true,
          helperText: 'Your email is used to sign in, so it can’t be changed here.',
        ));
    }

    if (widget.field != ProfileField.email) {
      children.addAll([
        const SizedBox(height: 32),
        PrimaryButton(label: 'Save', loading: _loading, onPressed: _save),
      ]);
    }

    return SubPageScaffold(title: 'Edit', children: children);
  }
}