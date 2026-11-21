import 'package:flutter/material.dart';

/// Bottom sheet en móvil y modal centrada en ventanas anchas.
Future<T?> showAdaptiveBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  Color? barrierColor,
  ShapeBorder? shape,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool showDragHandle = false,
}) {
  final viewport = MediaQuery.sizeOf(context);

  if (viewport.width < 760) {
    return showModalBottomSheet<T>(
      context: context,
      builder: builder,
      backgroundColor: backgroundColor,
      barrierColor: barrierColor,
      shape: shape,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      showDragHandle: showDragHandle,
    );
  }

  return showDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: isDismissible,
    barrierColor: barrierColor,
    builder: (dialogContext) {
      final size = MediaQuery.sizeOf(dialogContext);
      final colors = Theme.of(dialogContext).colorScheme;
      final surface = backgroundColor ?? colors.surface;

      final width = (size.width - 48).clamp(420.0, 760.0).toDouble();

      final height = (size.height - 48).clamp(280.0, 840.0).toDouble();

      return Dialog(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 22,
        shadowColor: Colors.black.withValues(alpha: .28),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: colors.outlineVariant.withValues(alpha: .7)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: width,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: height),
            child: Material(
              color: surface,
              child: SafeArea(child: builder(dialogContext)),
            ),
          ),
        ),
      );
    },
  );
}
