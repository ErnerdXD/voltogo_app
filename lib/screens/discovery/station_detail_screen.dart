import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voltogo_app/services/open_charge_map_service.dart';
import 'package:voltogo_app/providers/station_provider.dart';
import 'package:voltogo_app/providers/vehicle_provider.dart';
import 'package:voltogo_app/models/station_model.dart';
import 'package:voltogo_app/models/slot_model.dart';
import 'package:voltogo_app/screens/reservation/reservation_screen.dart'
    show pendingBookingStationProvider;

class StationDetailSheet extends ConsumerStatefulWidget {
  final ChargingStation station;

  const StationDetailSheet({super.key, required this.station});

  @override
  ConsumerState<StationDetailSheet> createState() => _StationDetailSheetState();
}

class _StationDetailSheetState extends ConsumerState<StationDetailSheet> {
  SlotModel? selectedSlot;

  @override
  Widget build(BuildContext context) {
    final ocmStation = widget.station;
    final supabaseStationsAsync = ref.watch(stationsProvider);
    final vehiclesAsync = ref.watch(vehicleProvider);
    final mediaQuery = MediaQuery.of(context);
    String? incompatibleVehicleMsg;
    vehiclesAsync.whenData((vehicles) {
      if (vehicles.isNotEmpty) {
        final connectors = ocmStation.connectors?.map((c) => c.type.toLowerCase()).toList() ?? [];
        final incompatible = vehicles.where((v) {
          final plugType = v.plugType?.toLowerCase();
          return plugType != null && !connectors.contains(plugType);
        }).toList();
        if (incompatible.isNotEmpty) {
          incompatibleVehicleMsg =
            'One or more of your vehicles is not suitable for this station (plug type not compatible). You can still proceed to book.';
        }
      }
    });

    return supabaseStationsAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => SizedBox(
        height: 200,
        child: Center(child: Text('Error loading stations: $err')),
      ),
      data: (supabaseStations) {
        // Match OCM station to Supabase station by external_id (OCM-{id})
        StationModel? supabaseStation;
        try {
          supabaseStation = supabaseStations.firstWhere(
                (s) =>
            s.externalId == 'OCM-${ocmStation.id}' ||
                s.externalId == ocmStation.id.toString() ||
                (s.name != null &&
                    s.name!.trim().toLowerCase() ==
                        ocmStation.name.trim().toLowerCase()),
          );
        } catch (_) {
          supabaseStation = null;
        }

        final slots = supabaseStation?.slots ?? [];
        final availableCount = slots.where((s) => s.status == 'available').length;
        final isBookable = supabaseStation != null && slots.isNotEmpty;

        return LayoutBuilder(builder: (context, constraints) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight -
                      mediaQuery.padding.top -
                      mediaQuery.padding.bottom,
                ),
                child: SingleChildScrollView(
                  padding:
                  EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),

                      // Station name
                      Text(
                        ocmStation.name,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      // Address
                      if (ocmStation.address != null &&
                          ocmStation.address!.isNotEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on,
                                color: Colors.grey, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(ocmStation.address!,
                                  style:
                                  TextStyle(color: Colors.grey[700])),
                            ),
                          ],
                        ),

                      // Phone
                      if (ocmStation.phoneNumber != null &&
                          ocmStation.phoneNumber!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.phone,
                                color: Colors.grey, size: 20),
                            const SizedBox(width: 8),
                            Text(ocmStation.phoneNumber!,
                                style: TextStyle(color: Colors.grey[700])),
                          ],
                        ),
                      ],

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Availability summary
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Available Slots',
                                  style: TextStyle(color: Colors.grey)),
                              Text(
                                isBookable
                                    ? '$availableCount / ${slots.length}'
                                    : '—',
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isBookable && availableCount > 0
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isBookable && availableCount > 0
                                  ? 'Available'
                                  : isBookable
                                  ? 'Full'
                                  : 'Info Only',
                              style: TextStyle(
                                color: isBookable && availableCount > 0
                                    ? Colors.green
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Bookable: show Supabase slots ──────────────────
                      if (isBookable) ...[
                        const Text('Select a Slot',
                            style:
                            TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text(
                          'Date & time can be set on the next screen.',
                          style:
                          TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        Column(
                          children: slots.map((slot) {
                            final isSelected = selectedSlot?.id == slot.id;
                            final isAvailable = slot.status == 'available';
                            return GestureDetector(
                              onTap: isAvailable
                                  ? () =>
                                  setState(() => selectedSlot = slot)
                                  : null,
                              child: AnimatedContainer(
                                duration:
                                const Duration(milliseconds: 180),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.blue
                                      .withValues(alpha: 0.08)
                                      : Colors.grey
                                      .withValues(alpha: 0.04),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.blue
                                        : isAvailable
                                        ? Colors.grey.shade300
                                        : Colors.red.shade200,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: Icon(
                                    isAvailable
                                        ? Icons.ev_station
                                        : Icons.block,
                                    color: isAvailable
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  title: Text(
                                    slot.connectorType ??
                                        'Unknown Connector',
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Wrap(
                                    spacing: 6,
                                    children: [
                                      if (slot.slotCode != null)
                                        Text(slot.slotCode!,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey)),
                                      if (slot.pricePerKwh != null)
                                        Text(
                                            'RM${slot.pricePerKwh!.toStringAsFixed(2)}/kWh',
                                            style: const TextStyle(
                                                fontSize: 12)),
                                      Text(
                                        slot.status ?? 'unknown',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isAvailable
                                              ? Colors.green
                                              : Colors.red,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle,
                                      color: Colors.blue)
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        if (selectedSlot == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'Tap an available slot to select it.',
                              style: TextStyle(
                                  color: Colors.orange, fontSize: 12),
                            ),
                          ),
                      ] else ...[
                        // ── Not in Supabase: show OCM connector info only ──
                        if (ocmStation.connectors != null &&
                            ocmStation.connectors!.isNotEmpty) ...[
                          const Text('Connectors',
                              style:
                              TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ocmStation.connectors!
                                .map((c) => Chip(
                              label: Text(c.type,
                                  style: const TextStyle(
                                      fontSize: 12)),
                              backgroundColor: Colors.blue
                                  .withValues(alpha: 0.1),
                              side: BorderSide.none,
                            ))
                                .toList(),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                Colors.orange.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.orange, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This station is not yet available for booking through the app.',
                                  style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Warning for incompatible vehicle
                      if (incompatibleVehicleMsg != null) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Text(incompatibleVehicleMsg!, style: const TextStyle(color: Colors.orange, fontSize: 13))),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          // Navigate to map screen and highlight this station
                          context.go('/map?highlightStationId=${ocmStation.id}');
                        },
                        icon: const Icon(Icons.map, color: Colors.blue),
                        label: const Text('Show on Map'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.blue),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  Navigator.pop(context, true),
                              icon: const Icon(Icons.my_location),
                              label: const Text('Locate'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: (!isBookable ||
                                  selectedSlot == null)
                                  ? null
                                  : () {
                                Navigator.pop(context);
                                ref
                                    .read(
                                    pendingBookingStationProvider
                                        .notifier)
                                    .state = {
                                  'slotId': selectedSlot!.id,
                                  'stationName':
                                  supabaseStation!.name ?? ocmStation.name,
                                  'stationAddress':
                                  supabaseStation.address ??
                                      ocmStation.address ??
                                      '',
                                  'connectorType':
                                  selectedSlot!.connectorType ??
                                      '',
                                  'connectorPrice': selectedSlot!
                                      .pricePerKwh
                                      ?.toStringAsFixed(2) ??
                                      '',
                                  'connectorStatus':
                                  selectedSlot!.status ?? '',
                                  'slotCode':
                                  selectedSlot!.slotCode ?? '',
                                };
                                context.go('/reservation');
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
                                backgroundColor:
                                isBookable ? Colors.blue : Colors.grey,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(isBookable
                                  ? 'Book Now'
                                  : 'Not Available'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
  }
}

