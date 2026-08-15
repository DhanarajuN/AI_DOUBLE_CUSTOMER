import 'package:flutter/material.dart';
import '../services/app_logger.dart';
import '../services/business_service.dart';
import '../theme/app_theme.dart';

/// "Choose a business" bottom sheet, shown after the customer picks a
/// category-level agent (e.g. "Healthcare") and before a new chat opens —
/// lets them pick which of the (possibly many) individual businesses in
/// that category the conversation is about. Server-side tagging of the
/// conversation with this businessId is what makes live human handoff
/// possible later.
///
/// Returns the picked business's raw JSON (`{"id": ..., "data": {...}}`),
/// an empty map if the customer explicitly skipped, or null if the sheet
/// was dismissed (caller should treat that as "cancel opening the chat").
Future<Map<String, dynamic>?> showBusinessPickerSheet(
  BuildContext context, {
  required String category,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    backgroundColor: AppColors.appSurfaceColor,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: AppColors.appBorderColorStrong,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Choose a business',
                    style: AppFonts.display(size: 20)),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Which $category business are you chatting with?',
                  style: AppFonts.body(
                      size: 13, color: AppColors.appTextSecondaryColor),
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.5),
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: BusinessService.fetchBusinesses(category),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppColors.appPrimaryColor),
                          ),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      AppLogger.e(
                          'BusinessPickerSheet',
                          'fetchBusinesses failed',
                          snapshot.error,
                          snapshot.stackTrace);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Could not load businesses. Try again later.',
                          style: AppFonts.body(
                              size: 13, color: AppColors.appTextSecondaryColor),
                        ),
                      );
                    }
                    final businesses = snapshot.data ?? const [];
                    if (businesses.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No $category businesses available yet.',
                          style: AppFonts.body(
                              size: 13, color: AppColors.appTextSecondaryColor),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: businesses.length,
                      itemBuilder: (context, index) {
                        final business = businesses[index];
                        final data =
                            business['data'] as Map<String, dynamic>? ??
                                const {};
                        final name = (data['Business Name'] as String?) ??
                            'Untitled business';
                        final contact = (data['First Name'] as String?) ?? '';
                        return InkWell(
                          onTap: () => Navigator.pop(ctx, business),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 9),
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: AppColors.appSurfaceColor,
                              border:
                                  Border.all(color: AppColors.appBorderColor),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.appPrimaryGradient,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.storefront_outlined,
                                      color: Colors.white, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          style: AppFonts.body(
                                              size: 14,
                                              weight: FontWeight.w600)),
                                      if (contact.isNotEmpty) ...[
                                        const SizedBox(height: 1),
                                        Text(contact,
                                            style: AppFonts.body(
                                                size: 12,
                                                color: AppColors
                                                    .appTextSecondaryColor)),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(ctx, <String, dynamic>{}),
                child: Text(
                  "Skip — I'll pick later",
                  style: AppFonts.body(
                      size: 12.5, color: AppColors.appTextSecondaryColor),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
