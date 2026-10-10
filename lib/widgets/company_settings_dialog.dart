import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../models/hr_models.dart';
import 'glass_dialog.dart';

Future<void> showCompanySettingsDialog(BuildContext context) async {
  final provider = Provider.of<AttendanceProvider>(context, listen: false);
  await showGlassDialog(
    context: context,
    title: provider.translate('company_settings'),
    subtitle: provider.translate('manage_company_branding'),
    icon: Icons.business,
    content: const CompanySettingsForm(),
  );
}

class CompanySettingsForm extends StatefulWidget {
  const CompanySettingsForm({super.key});

  @override
  State<CompanySettingsForm> createState() => _CompanySettingsFormState();
}

class _CompanySettingsFormState extends State<CompanySettingsForm> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _logoBase64;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    if (provider.companyProfile != null) {
      _nameController.text = provider.companyProfile!.name;
      _addressController.text = provider.companyProfile!.address;
      _emailController.text = provider.companyProfile!.email ?? '';
      _phoneController.text = provider.companyProfile!.phone ?? '';
      _logoBase64 = provider.companyProfile!.logoBase64;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _isLoading = true);
      try {
        final bytes = await pickedFile.readAsBytes();
        final image = img.decodeImage(bytes);
        if (image != null) {
          // Resize to max 300 width to save space in Firestore
          final resized = img.copyResize(image, width: 300);
          final compressedBytes = img.encodeJpg(resized, quality: 75);
          setState(() {
            _logoBase64 = base64Encode(compressedBytes);
          });
        }
      } catch (e) {
        debugPrint('Error compressing image: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load image: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _save() async {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.translate('name_is_required'))));
      return;
    }

    setState(() => _isLoading = true);
    
    final newProfile = CompanyProfile(
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
      logoBase64: _logoBase64,
    );

    await provider.firebaseService.saveCompanyProfile(newProfile);
    
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.translate('company_settings_saved'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<AttendanceProvider>(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Logo Picker
        Center(
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1),
                ),
                image: _logoBase64 != null
                    ? DecorationImage(
                        image: MemoryImage(base64Decode(_logoBase64!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _logoBase64 == null
                  ? Icon(Icons.add_a_photo, color: isDark ? Colors.white54 : Colors.black54)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            provider.translate('tap_to_upload_logo'),
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Fields
        _buildTextField(provider.translate('company_name'), _nameController, Icons.business),
        const SizedBox(height: 16),
        _buildTextField(provider.translate('email'), _emailController, Icons.email),
        const SizedBox(height: 16),
        _buildTextField(provider.translate('phone'), _phoneController, Icons.phone),
        const SizedBox(height: 16),
        _buildTextField(provider.translate('address'), _addressController, Icons.location_on),
        const SizedBox(height: 32),

        // Save Button
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E65FF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(provider.translate('save_changes'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
        prefixIcon: Icon(icon, color: isDark ? Colors.white54 : Colors.black54),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
