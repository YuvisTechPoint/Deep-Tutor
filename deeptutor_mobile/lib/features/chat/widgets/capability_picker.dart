import 'package:flutter/material.dart';

import '../data/capability_catalog.dart';

/// Bottom sheet that lists all 10 capabilities and returns the chosen id.
Future<String?> showCapabilityPickerSheet(
  BuildContext context, {
  required String current,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: CapabilityCatalog.capabilities.length,
          itemBuilder: (_, i) {
            final cap = CapabilityCatalog.capabilities[i];
            final selected = cap.id == current;
            return ListTile(
              leading: Icon(cap.icon),
              title: Text(cap.label),
              subtitle: Text(
                cap.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: selected
                  ? const Icon(Icons.check_rounded, color: Colors.green)
                  : null,
              onTap: () => Navigator.of(ctx).pop(cap.id),
            );
          },
        ),
      );
    },
  );
}
