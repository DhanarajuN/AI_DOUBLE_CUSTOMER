import 'package:flutter/material.dart';
import '../data/scripts_data.dart';
import '../models/pro.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Shows the booking flow as a modal bottom sheet: pick a slot, add an
/// optional note, confirm -> success screen -> "Open chat" hands off to
/// the pro's 1:1 thread (mirrors openBooking/confirmBooking/afterBooking).
Future<void> showBookingSheet({
  required BuildContext context,
  required AppState state,
  required Pro pro,
  required VoidCallback onOpenChat,
}) {
  state.selectedSlot = null;
  _justConfirmed = false;
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.panel,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          final confirmed = _justConfirmed;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: AppColors.line2, borderRadius: BorderRadius.circular(2)),
                  ),
                  if (!confirmed) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Book ${pro.name}', style: AppFonts.display(size: 20)),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('${pro.price} · ${pro.role}', style: AppFonts.body(size: 13, color: AppColors.dim)),
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('CHOOSE A TIME', style: AppFonts.mono(size: 11, letterSpacing: 1)),
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.7,
                      children: kSlots.map((s) {
                        final on = state.selectedSlot == s;
                        return InkWell(
                          onTap: () => setSheetState(() => state.pickSlot(s)),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: on ? AppColors.teal : Colors.transparent,
                              border: Border.all(color: on ? AppColors.teal : AppColors.line),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              s.replaceFirst(' ', '\n'),
                              textAlign: TextAlign.center,
                              style: AppFonts.body(
                                size: 13,
                                weight: on ? FontWeight.w600 : FontWeight.w500,
                                color: on ? const Color(0xFF04120D) : AppColors.text,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('ADD A NOTE (OPTIONAL)', style: AppFonts.mono(size: 11, letterSpacing: 1)),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      style: AppFonts.body(size: 14),
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Briefly describe what you need…',
                        hintStyle: AppFonts.body(size: 14, color: AppColors.faint),
                        filled: true,
                        fillColor: AppColors.panel2,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(11),
                          borderSide: const BorderSide(color: AppColors.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(11),
                          borderSide: const BorderSide(color: AppColors.line),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: const Color(0xFF04120D),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          if (state.selectedSlot == null) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Pick a time first'), behavior: SnackBarBehavior.floating),
                            );
                            return;
                          }
                          state.confirmBooking();
                          _justConfirmed = true;
                          setSheetState(() {});
                        },
                        child: const Text('Confirm booking', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: 64,
                      height: 64,
                      margin: const EdgeInsets.only(top: 20, bottom: 16),
                      decoration: BoxDecoration(color: AppColors.green.withOpacity(0.14), shape: BoxShape.circle),
                      child: const Icon(Icons.check, color: AppColors.green, size: 32),
                    ),
                    Text('Booking confirmed', style: AppFonts.display(size: 20), textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(
                      '${pro.name} · ${state.bookings.first.slot}',
                      style: AppFonts.body(size: 13, color: AppColors.dim),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'A chat has been opened with ${pro.name.split(' ').first} to coordinate.',
                        textAlign: TextAlign.center,
                        style: AppFonts.body(size: 13.5, color: AppColors.dim),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: const Color(0xFF04120D),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          _justConfirmed = false;
                          Navigator.pop(ctx);
                          onOpenChat();
                        },
                        child: const Text('Open chat', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(() => _justConfirmed = false);
}

// Sheet-local flag tracking whether confirmBooking() just succeeded, so the
// same sheet swaps from "pick a slot" to "confirmed" view without a second
// showModalBottomSheet call (mirrors swapping #sheet-content innerHTML).
bool _justConfirmed = false;
