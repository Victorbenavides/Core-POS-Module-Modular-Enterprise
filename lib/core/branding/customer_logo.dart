import 'dart:io';
import 'package:flutter/material.dart';

import 'customer_branding_service.dart';

class CustomerLogo extends StatelessWidget {
  final double height;
  final double? width;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const CustomerLogo({
    super.key,
    this.height = 44,
    this.width,
    this.fit = BoxFit.contain,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<File?>(
      valueListenable: CustomerBrandingService.instance.logoFile,
      builder: (_, file, __) {
        if (file == null) {
          // Fallback cuando no hay logo
          return SizedBox(
            height: height,
            width: width,
            child: const Icon(Icons.business, size: 28),
          );
        }

        return ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.circular(10),
          child: SizedBox(
            height: height,
            width: width,
            child: Image.file(
              file,
              fit: fit,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
            ),
          ),
        );
      },
    );
  }
}
