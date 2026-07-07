import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pro.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/booking_sheet.dart';
import 'chat_thread_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Set<int> _openFaqs = {};

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final Pro? pro = state.currentProId != null ? state.pros[state.currentProId] : null;
    if (pro == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) Navigator.pop(context);
      });
      return const Scaffold(backgroundColor: AppColors.app);
    }

    return Scaffold(
      backgroundColor: AppColors.app,
      body: SafeArea(
        child: Column(
          children: [
            // ---- bar ----
            Container(
              padding: const EdgeInsets.fromLTRB(6, 14, 14, 12),
              decoration: const BoxDecoration(
                color: AppColors.panel,
                border: Border(bottom: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(child: Text('Profile', style: AppFonts.display(size: 19))),
                  IconButton(
                    icon: Icon(
                      state.isCurrentProSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: state.isCurrentProSaved ? AppColors.gold : AppColors.dim,
                    ),
                    onPressed: () {
                      final wasSaved = state.isCurrentProSaved;
                      state.toggleSave();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(wasSaved ? 'Removed from saved' : 'Saved ${pro.name}'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ---- body ----
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildHeader(pro),
                  _buildStats(pro),
                  _buildSection('About', child: Text(pro.about, style: AppFonts.body(size: 13.5, color: AppColors.text))),
                  _buildSection(
                    'Services',
                    child: Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: pro.services
                          .map((s) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.panel,
                                  border: Border.all(color: AppColors.line),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(s, style: AppFonts.body(size: 12, color: AppColors.dim)),
                              ))
                          .toList(),
                    ),
                  ),
                  _buildSection(
                    'Common questions',
                    child: Column(
                      children: List.generate(pro.faqs.length, (i) {
                        final faq = pro.faqs[i];
                        final open = _openFaqs.contains(i);
                        return InkWell(
                          onTap: () => setState(() => open ? _openFaqs.remove(i) : _openFaqs.add(i)),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: i == 0
                                  ? null
                                  : const Border(top: BorderSide(color: AppColors.line)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(faq[0], style: AppFonts.body(size: 13.5, weight: FontWeight.w600)),
                                    ),
                                    AnimatedRotation(
                                      turns: open ? 0.25 : 0,
                                      duration: const Duration(milliseconds: 200),
                                      child: const Icon(Icons.chevron_right, size: 16, color: AppColors.faint),
                                    ),
                                  ],
                                ),
                                AnimatedCrossFade(
                                  firstChild: const SizedBox(width: double.infinity),
                                  secondChild: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      faq[1],
                                      style: AppFonts.body(size: 13, color: AppColors.dim),
                                    ),
                                  ),
                                  crossFadeState: open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                                  duration: const Duration(milliseconds: 200),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  _buildSection(
                    'Reviews',
                    child: Column(
                      children: List.generate(pro.revs.length, (i) {
                        final r = pro.revs[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: i == 0 ? null : const Border(top: BorderSide(color: AppColors.line)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(gradient: AppColors.tealGradient, shape: BoxShape.circle),
                                child: Text(
                                  r.initials,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(r.name, style: AppFonts.body(size: 13, weight: FontWeight.w600)),
                                        Text('★ ${r.rating}', style: AppFonts.body(size: 11, color: AppColors.gold)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(r.text, style: AppFonts.body(size: 12.5, color: AppColors.dim)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // ---- CTA ----
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: AppColors.app,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      side: const BorderSide(color: AppColors.line2),
                      backgroundColor: AppColors.panel,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      state.chatWithPro(pro.id);
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatThreadScreen()));
                    },
                    child: const Icon(Icons.chat_bubble_outline, color: AppColors.text, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        foregroundColor: const Color(0xFF04120D),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        showBookingSheet(
                          context: context,
                          state: state,
                          pro: pro,
                          onOpenChat: () {
                            state.chatWithPro(pro.id);
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatThreadScreen()));
                          },
                        );
                      },
                      child: Text('Book · ${pro.price}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Pro pro) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.panel, AppColors.panel.withOpacity(0)],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: pro.gradient),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(pro.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(pro.name, style: AppFonts.display(size: 21))),
                    const SizedBox(width: 6),
                    const Text('✓', style: TextStyle(color: AppColors.teal, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(pro.role, style: AppFonts.body(size: 13, color: AppColors.dim)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('★ ${pro.rating}', style: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: AppColors.gold)),
                    const SizedBox(width: 10),
                    Text('${pro.reviews} reviews', style: AppFonts.body(size: 12.5, color: AppColors.dim)),
                    if (pro.tier != null) ...[
                      const SizedBox(width: 10),
                      Text('·', style: AppFonts.body(size: 12.5, color: AppColors.faint)),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.goldDim,
                          border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text('${pro.tier} TIER', style: AppFonts.mono(size: 9, color: AppColors.gold, letterSpacing: 0.7)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(Pro pro) {
    Widget stat(String n, String l) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.panel,
            child: Column(
              children: [
                Text(n, style: AppFonts.display(size: 18)),
                const SizedBox(height: 2),
                Text(l, style: AppFonts.body(size: 10, color: AppColors.dim)),
              ],
            ),
          ),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 4, 18, 0),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          stat(pro.rating, 'Rating'),
          Container(width: 1, color: AppColors.line),
          stat(pro.responds, 'Responds'),
          Container(width: 1, color: AppColors.line),
          stat(pro.verifiedSince, 'Verified'),
        ],
      ),
    );
  }

  Widget _buildSection(String title, {required Widget child}) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: AppFonts.mono(size: 10, letterSpacing: 1.4, color: AppColors.faint)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
