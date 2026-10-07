import 'package:flutter/material.dart';
import '../state/device_store.dart';
import '../theme/theme_store.dart';
import '../theme/app_colors.dart';
import '../models/boiler_device.dart';
import '../models/boiler_parameter.dart';

class AddBoilerScreen extends StatefulWidget {
  final DeviceStore store;
  final ThemeStore themeStore;

  const AddBoilerScreen({super.key, required this.store, required this.themeStore});

  @override
  State<AddBoilerScreen> createState() => _AddBoilerScreenState();
}

class _AddBoilerScreenState extends State<AddBoilerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _idController = TextEditingController();
  final _claimController = TextEditingController();
  bool _busy = false;

  final Set<BoilerParameter> _selected = {
    BoilerParameter.voltage,
    BoilerParameter.mainCurrent,
    BoilerParameter.temperature,
    BoilerParameter.pressure,
  };

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _idController.dispose();
    _claimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.themeStore,
      builder: (context, _) {
        final colors = widget.themeStore.colors;
        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: colors.background,
            elevation: 0,
            title: Text('Add boiler', style: TextStyle(color: colors.textPrimary)),
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _label('Name', colors),
                _textField(_nameController, hint: 'Boiler unit 05', validatorMsg: 'Enter a name', colors: colors),
                const SizedBox(height: 16),
                _label('Location', colors),
                _textField(_locationController,
                    hint: 'Plant floor - Bay 4', validatorMsg: 'Enter a location', colors: colors),
                const SizedBox(height: 16),
                _label('Device ID', colors),
                Text(
                  'The device ID differs for each system — please find your '
                  'boiler ID on the System Info page on the HMI.',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 6),
                _textField(
                  _idController,
                  hint: 'b028a7a76062ec',
                  validatorMsg: 'Enter the device ID',
                  colors: colors,
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return 'Enter the device ID';
                    // The ID becomes a database path, so only letters and
                    // digits are allowed (no slashes, dots or symbols).
                    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(v)) return 'Letters and numbers only';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _label('Claim code', colors),
                Text(
                  'The claim code proves this boiler is yours. It is on the label '
                  'supplied with your unit, or ask your installer.',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 6),
                _textField(
                  _claimController,
                  hint: 'ABCD-EFGH-JKLM',
                  validatorMsg: 'Enter the claim code',
                  colors: colors,
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                _label('Parameters this boiler reports', colors),
                const SizedBox(height: 4),
                Text(
                  'Only selected parameters show on this boiler\'s dashboard.',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                ...BoilerParameter.values.map((p) => _parameterTile(p, colors)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.onAccent,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _busy
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: colors.onAccent),
                        )
                      : const Text('Add boiler'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _label(String text, AppColors colors) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w500)),
      );

  /// Shared text field. Set [required] to false for optional fields
  /// (username/password) — validation is skipped entirely rather than
  /// just relaxed, so an empty optional field never blocks submit.
  /// Pass a custom [validator] (e.g. for the numeric port field) to
  /// override the default required-non-empty check.
  Widget _textField(
    TextEditingController controller, {
    required String hint,
    required String validatorMsg,
    required AppColors colors,
    bool required = true,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      textCapitalization: textCapitalization,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: TextStyle(color: colors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        suffixIcon: suffixIcon,
      ),
      validator: !required
          ? null
          : validator ?? (value) => (value == null || value.trim().isEmpty) ? validatorMsg : null,
    );
  }

  Widget _parameterTile(BoilerParameter param, AppColors colors) {
    final info = boilerParameterInfo[param]!;
    final checked = _selected.contains(param);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(12)),
      child: CheckboxListTile(
        value: checked,
        onChanged: (value) {
          setState(() {
            if (value == true) {
              _selected.add(param);
            } else {
              _selected.remove(param);
            }
          });
        },
        activeColor: info.color,
        checkColor: colors.background,
        title: Text(info.label, style: TextStyle(color: colors.textPrimary)),
        secondary: Icon(info.icon, color: info.color),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one parameter')),
      );
      return;
    }
    final id = _idController.text.trim().toLowerCase(); // firmware IDs are lowercase hex
    if (widget.store.devices.any((d) => d.id == id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This boiler is already added')),
      );
      return;
    }

    final device = BoilerDevice(
      id: id,
      name: _nameController.text.trim(),
      location: _locationController.text.trim(),
      enabledParameters: _selected,
    );
    final claimCode = _claimController.text.trim().toUpperCase();

    setState(() => _busy = true);
    final error = await widget.store.addDevice(device, claimCode);
    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context).pop();
  }
}
