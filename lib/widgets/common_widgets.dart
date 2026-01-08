import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CommonWidgets {
  // Logo widget with border
  static Widget logoWithBorder({double radius = 45, double imageHeight = 90}) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderBlue, width: 3),
      ),
      child: CircleAvatar(
        backgroundColor: Colors.white,
        radius: radius,
        child: Image.asset('assets/queue_logo.jpg', height: imageHeight),
      ),
    );
  }

  // Back button
  static Widget backButton({
    required VoidCallback onPressed,
    Color? iconColor,
    double? iconSize,
  }) {
    return IconButton(
      icon: Icon(
        Icons.arrow_back,
        color: iconColor ?? AppColors.primaryBlue,
        size: iconSize ?? 36,
      ),
      onPressed: onPressed,
    );
  }

  // Bottom bar
  static Widget bottomBar({double height = 42}) {
    return Container(
      color: AppColors.primaryBlue,
      height: height,
      width: double.infinity,
    );
  }

  // Custom text field
  static Widget customTextField({
    required String label,
    TextEditingController? controller,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey[300],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // Custom dropdown
  static Widget customDropdown({
    required String label,
    required List<DropdownMenuItem<String>> items,
    String? value,
    void Function(String?)? onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(labelText: label, border: InputBorder.none),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  // Primary button
  static Widget primaryButton({
    required String text,
    required VoidCallback onPressed,
    double? width,
    double? height,
    EdgeInsetsGeometry? padding,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding:
              padding ??
              const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, color: Colors.white),
        ),
      ),
    );
  }
}
