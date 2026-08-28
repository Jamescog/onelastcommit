import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import '../util/timezone_service.dart';

/// Searchable list of every IANA zone, with the detected one pinned on top.
///
/// Shared by onboarding and settings. Onboarding previously carried its own
/// hardcoded list of fifteen cities — no African zones among them — which is
/// how a user in Addis Ababa ended up with no way to say so.
class TimezonePicker extends StatefulWidget {
  const TimezonePicker({this.detected, super.key});

  final String? detected;

  static Future<String?> show(BuildContext context, {String? detected}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TimezonePicker(detected: detected),
    );
  }

  @override
  State<TimezonePicker> createState() => _TimezonePickerState();
}

class _TimezonePickerState extends State<TimezonePicker> {
  String _query = '';
  late final List<String> _all = TimezoneService.all();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final q = _query.trim().toLowerCase();

    // Match on the city as well as the whole path, so "addis" finds
    // Africa/Addis_Ababa and "nairobi" finds Africa/Nairobi.
    final matches = q.isEmpty
        ? _all
        : _all
              .where(
                (z) =>
                    z.toLowerCase().contains(q) ||
                    z
                        .split('/')
                        .last
                        .replaceAll('_', ' ')
                        .toLowerCase()
                        .contains(q),
              )
              .toList();

    final detected = widget.detected;
    final nearby = detected == null || q.isNotEmpty
        ? const <String>[]
        : TimezoneService.sharingOffsetWith(
            detected,
          ).where((z) => z != detected).take(6).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search 400+ zones — try a city name',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              children: [
                if (detected != null && q.isEmpty) ...[
                  _Heading(label: 'Detected on this device'),
                  _ZoneTile(zone: detected, highlight: true),
                  if (nearby.isNotEmpty) ...[
                    _Heading(
                      label:
                          'Same offset (${TimezoneService.offsetLabel(detected)})',
                    ),
                    for (final z in nearby) _ZoneTile(zone: z),
                  ],
                  _Heading(label: 'All zones'),
                ],
                if (matches.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Text(
                      'No zone matches "$_query".',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                    ),
                  ),
                for (final z in matches) _ZoneTile(zone: z),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: context.tokens.textSecondary),
      ),
    );
  }
}

class _ZoneTile extends StatelessWidget {
  const _ZoneTile({required this.zone, this.highlight = false});

  final String zone;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final parts = zone.split('/');
    final city = parts.last.replaceAll('_', ' ');
    final region = parts.length > 1 ? parts.first.replaceAll('_', ' ') : '';

    return ListTile(
      dense: true,
      leading: highlight
          ? Icon(Icons.my_location, size: 18, color: t.accent)
          : null,
      title: Text(city),
      subtitle: region.isEmpty ? null : Text(region),
      trailing: Text(
        TimezoneService.offsetLabel(zone),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
      ),
      onTap: () => Navigator.of(context).pop(zone),
    );
  }
}
