import 'package:flutter/material.dart';
import '../core/theme/da_vinci_theme.dart';

class GoldGlowContainer extends StatelessWidget {
  final Widget child;
  final bool isSelected;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const GoldGlowContainer({
    super.key,
    required this.child,
    this.isSelected = false,
    this.borderRadius = 8.0,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    if (!isSelected) {
      return Padding(
        padding: margin,
        child: Padding(
          padding: padding,
          child: child,
        ),
      );
    }

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppColors.accent,
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.4),
            blurRadius: 6.0,
            spreadRadius: 1.0,
          ),
        ],
      ),
      child: child,
    );
  }
}
