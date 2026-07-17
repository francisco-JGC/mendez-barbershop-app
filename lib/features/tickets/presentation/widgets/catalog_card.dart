import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Item card used in the "Nueva venta" grid — high-contrast, tappable, with
/// a stock badge for products. Kept visually loud so sellers can hit them
/// fast on a phone in a busy shop.
class CatalogCard extends StatelessWidget {
  const CatalogCard({
    super.key,
    required this.title,
    required this.priceLabel,
    required this.icon,
    required this.onTap,
    this.badge,
    this.badgeColor,
    this.badgeTextColor,
  });

  final String title;
  final String priceLabel;
  final IconData icon;
  final VoidCallback? onTap;
  final String? badge;
  final Color? badgeColor;
  final Color? badgeTextColor;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(14),
      color: disabled ? Colors.grey.shade100 : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        splashColor: AppColors.primary.withValues(alpha: 0.2),
        highlightColor: AppColors.primary.withValues(alpha: 0.08),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: disabled ? Colors.grey.shade300 : AppColors.primary,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: disabled ? Colors.grey : AppColors.primary,
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor ?? Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge!,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: badgeTextColor ?? Colors.grey.shade800,
                        ),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: disabled ? Colors.grey : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    priceLabel,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: disabled ? Colors.grey : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
