import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_client.dart';
import '../services/app_logger.dart';
import '../services/session_storage.dart';
import '../constants/server_urls.dart';
import '../theme/app_theme.dart';

String? _formatTimeOfDay(dynamic raw) {
  final s = raw?.toString().trim();
  if (s == null || s.isEmpty) return null;
  final dt = DateTime.tryParse(s);
  if (dt == null) return s;
  final local = dt.toLocal();
  final hour24 = local.hour;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour12:$minute $period';
}

bool _isPositive(String? v) {
  if (v == null) return false;
  final n = num.tryParse(v);
  return n != null && n > 0;
}

Future<void> _dial(BuildContext context, String phone) async {
  final uri = Uri(scheme: 'tel', path: phone);
  try {
    final launched = await launchUrl(uri);
    if (!launched) throw Exception('launchUrl returned false');
  } catch (e, st) {
    AppLogger.e('BookingsView', 'dial($phone) failed', e, st);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open dialer for $phone'), behavior: SnackBarBehavior.floating),
      );
    }
  }
}

Future<void> _email(BuildContext context, String address) async {
  final uri = Uri(scheme: 'mailto', path: address);
  try {
    final launched = await launchUrl(uri);
    if (!launched) throw Exception('launchUrl returned false');
  } catch (e, st) {
    AppLogger.e('BookingsView', 'email($address) failed', e, st);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open mail app for $address'), behavior: SnackBarBehavior.floating),
      );
    }
  }
}

class _Booking {
  final String id;
  final String service;
  final String status;
  final DateTime? date;
  final String? time;
  final String brokerName;
  final String brokerCode;
  final String? brokerPhone;
  final String? brokerEmail;
  final String customerName;
  final String customerEmail;
  final String customerMobile;
  final String? amount;
  final String? amountAfterDiscount;
  final String? numberOfGuests;
  final String? specialRequest;

  const _Booking({
    required this.id,
    required this.service,
    required this.status,
    required this.date,
    required this.time,
    required this.brokerName,
    required this.brokerCode,
    this.brokerPhone,
    this.brokerEmail,
    required this.customerName,
    required this.customerEmail,
    required this.customerMobile,
    this.amount,
    this.amountAfterDiscount,
    this.numberOfGuests,
    this.specialRequest,
  });

  factory _Booking.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    String? nonEmpty(dynamic v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return _Booking(
      id: json['id']?.toString() ?? '',
      service: nonEmpty(data['Service']) ?? 'Booking',
      status: json['Current_Job_Status']?.toString() ?? 'Unknown',
      date: DateTime.tryParse(data['Date']?.toString() ?? ''),
      time: _formatTimeOfDay(data['Time']),
      brokerName: nonEmpty(data['Broker Name']) ?? '—',
      brokerCode: nonEmpty(data['Broker Code']) ?? '—',
      brokerPhone: nonEmpty(data['Phone Number']),
      brokerEmail: nonEmpty(data['Email Id']),
      customerName: nonEmpty(data['Name']) ?? '—',
      customerEmail: nonEmpty(data['Email']) ?? '—',
      customerMobile: nonEmpty(data['Mobile No']) ?? '—',
      amount: nonEmpty(data['Amount']),
      amountAfterDiscount: nonEmpty(data['Amount After Discount']),
      numberOfGuests: nonEmpty(data['Number of Guests']),
      specialRequest: nonEmpty(data['Special Request']),
    );
  }
}

class BookingsView extends StatefulWidget {
  const BookingsView({super.key});

  static Route<void> route() {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => const BookingsView(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<BookingsView> createState() => _BookingsViewState();
}

const _kFilters = ['All', 'Draft', 'Accepted', 'Completed', 'Rejected', 'Cancelled'];

class _BookingsViewState extends State<BookingsView> {
  List<_Booking> _bookings = [];
  bool _loading = true;
  String? _error;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await context.read<ApiClient>().get(ServerUrls.bookingsInstances) as Map<String, dynamic>;
      final jobs = (json['jobs'] as List?) ?? const [];
      final bookings = jobs.cast<Map<String, dynamic>>().map(_Booking.fromJson).toList()
        ..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _loading = false;
      });
    } catch (e, st) {
      AppLogger.e('BookingsView', 'fetchBookings failed', e, st);
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<_Booking> get _visible {
    if (_filter == 'All') return _bookings;
    return _bookings.where((b) => b.status.toLowerCase() == _filter.toLowerCase()).toList();
  }

  IconData _iconFor(String service) {
    final s = service.toLowerCase();
    if (s.contains('tutor') || s.contains('education') || s.contains('coaching')) return Icons.school_outlined;
    if (s.contains('pain') || s.contains('health') || s.contains('care') || s.contains('physio')) {
      return Icons.health_and_safety_outlined;
    }
    if (s.contains('plumb')) return Icons.plumbing_outlined;
    if (s.contains('home')) return Icons.home_repair_service_outlined;
    if (s.contains('insur') || s.contains('claim')) return Icons.shield_outlined;
    return Icons.event_available_outlined;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'accepted':
      case 'completed':
        return AppColors.appSuccessColor;
      case 'cancelled':
      case 'inactive':
      case 'draft':
        return AppColors.appTextMutedColor;
      case 'rejected':
        return const Color(0xFFD64545);
      default:
        return AppColors.appSecondaryColor;
    }
  }

  Future<Map<String, dynamic>?> _findNextStatus(
      String instanceId, String targetSecondaryStatus) async {
    try {
      final json = await context.read<ApiClient>().get(
        '${ServerUrls.jobInstances}$instanceId',
        query: {'limitSubJobs': 'true', 'includeJobWorkflowType': 'true'},
      ) as Map<String, dynamic>;
      final jobs = json['jobs'] as List?;
      if (jobs == null || jobs.isEmpty) return null;
      final nextStatuses = (jobs[0] as Map<String, dynamic>)['Next_Job_Statuses'] as List?;
      if (nextStatuses == null) return null;

      for (final entry in nextStatuses.cast<Map<String, dynamic>>()) {
        if ((entry['secondaryStatus'] as String? ?? '').toLowerCase() !=
            targetSecondaryStatus.toLowerCase()) {
          continue;
        }
        final roles = entry['roles'] as List?;
        final role = (roles != null && roles.isNotEmpty) ? roles[0] as Map<String, dynamic> : null;
        return {
          'sequenceNo': entry['sequenceNo'],
          'secondaryStatus': entry['secondaryStatus'],
          'roleId': role?['id'],
          'roleName': role?['name'],
        };
      }
      return null;
    } catch (e, st) {
      AppLogger.e('BookingsView', 'findNextStatus($instanceId) failed', e, st);
      return null;
    }
  }

  Future<void> _cancelBooking(_Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.appSurfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel booking?', style: AppFonts.display(size: 17)),
        content: Text(
          'This will cancel "${booking.service}". This can\'t be undone.',
          style: AppFonts.body(size: 13.5, color: AppColors.appTextSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Keep it', style: AppFonts.body(size: 14, color: AppColors.appTextSecondaryColor)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Cancel booking',
                style: AppFonts.body(size: 14, weight: FontWeight.w600, color: const Color(0xFFD64545))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final next = await _findNextStatus(booking.id, 'Cancelled');
    if (next == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No Cancelled status available for this booking'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }
    AppLogger.i('BookingsView',
        'cancel target for ${booking.id}: sequenceNo=${next['sequenceNo']} secondaryStatus=${next['secondaryStatus']} roleId=${next['roleId']} roleName=${next['roleName']}');

    final myRoleName = await SessionStorage().readRoleName();
    final requiredRoleName = next['roleName'] as String?;
    if (requiredRoleName != null &&
        (myRoleName == null || myRoleName.toLowerCase() != requiredRoleName.toLowerCase())) {
      AppLogger.w('BookingsView',
          'cancel blocked: myRole=$myRoleName requiredRole=$requiredRoleName');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("You don't have permission to cancel this booking"),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    if (!mounted) return;
    try {
      await context.read<ApiClient>().post(
        ServerUrls.updateWorkflowStatus,
        body: {
          'jobInstanceId': booking.id,
          'secondaryStatus': next['secondaryStatus'],
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking cancelled'), behavior: SnackBarBehavior.floating),
      );
      _load();
    } catch (e, st) {
      AppLogger.e('BookingsView', 'updateWorkflowStatus(${booking.id}) failed', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not cancel booking: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Date not set';
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }

  Widget _buildFilterBar() {
    return Container(
      color: AppColors.appSurfaceColor,
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: _kFilters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final label = _kFilters[i];
            final selected = _filter == label;
            return InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: () => setState(() => _filter = label),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? AppColors.appPrimaryColor : AppColors.appSurfaceVariantColor,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: selected ? AppColors.appPrimaryColor : AppColors.appBorderColor),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: AppFonts.body(
                    size: 12.5,
                    weight: FontWeight.w600,
                    color: selected ? AppColors.appOnPrimaryColor : AppColors.appTextSecondaryColor,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      backgroundColor: AppColors.appBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.appSurfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.appTextColor),
        title: Text('Bookings', style: AppFonts.display(size: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: _buildFilterBar(),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.appPrimaryColor,
          child: _loading
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.appPrimaryColor),
                  ),
                )
              : _error != null
                  ? ListView(
                      padding: const EdgeInsets.only(top: 120),
                      children: [
                        Center(
                          child: Text(
                            'Could not load bookings. Pull to refresh.',
                            style: AppFonts.body(size: 13.5, color: AppColors.appTextSecondaryColor),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    )
                  : visible.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.only(top: 120),
                          children: [
                            Center(
                              child: Text(
                                _bookings.isEmpty ? 'No bookings yet.' : 'No $_filter bookings.',
                                style: AppFonts.body(size: 13.5, color: AppColors.appTextSecondaryColor),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                          itemCount: visible.length,
                          itemBuilder: (context, i) => _BookingCard(
                            booking: visible[i],
                            icon: _iconFor(visible[i].service),
                            statusColor: _statusColor(visible[i].status),
                            formattedDate: _formatDate(visible[i].date),
                            onCancel: visible[i].status.toLowerCase() == 'draft'
                                ? () => _cancelBooking(visible[i])
                                : null,
                          ),
                        ),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final _Booking booking;
  final IconData icon;
  final Color statusColor;
  final String formattedDate;
  final VoidCallback? onCancel;

  const _BookingCard({
    required this.booking,
    required this.icon,
    required this.statusColor,
    required this.formattedDate,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final extras = <MapEntry<String, String>>[
      if (_isPositive(booking.amount)) MapEntry('Amount', '₹${booking.amount}'),
      if (_isPositive(booking.amountAfterDiscount)) MapEntry('After discount', '₹${booking.amountAfterDiscount}'),
      if (_isPositive(booking.numberOfGuests)) MapEntry('Guests', booking.numberOfGuests!),
      if (booking.time != null) MapEntry('Time', booking.time!),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.appSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.appBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(gradient: AppColors.appPrimaryGradient, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: Colors.white, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.service,
                        style: AppFonts.body(size: 15.5, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formattedDate,
                        style: AppFonts.mono(size: 10.5, color: AppColors.appTextSecondaryColor, letterSpacing: 0.3),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: statusColor.withOpacity(0.35)),
                  ),
                  child: Text(
                    booking.status,
                    style: AppFonts.body(size: 10.5, weight: FontWeight.w700, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(color: AppColors.appBorderColor, height: 1),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _InfoColumn(
                    label: 'Booked by',
                    lines: [booking.customerName, booking.customerMobile],
                  ),
                ),
                Expanded(
                  child: _InfoColumn(
                    label: 'Assigned to',
                    lines: [booking.brokerName, booking.brokerCode],
                    phone: booking.brokerPhone,
                    email: booking.brokerEmail,
                  ),
                ),
              ],
            ),
            if (extras.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: extras
                    .map((e) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.appSurfaceVariantColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${e.key}: ${e.value}',
                            style: AppFonts.body(size: 11.5, color: AppColors.appTextSecondaryColor),
                          ),
                        ))
                    .toList(),
              ),
            ],
            if (booking.specialRequest != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.appPrimaryColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(left: BorderSide(color: AppColors.appPrimaryColor, width: 3)),
                ),
                child: Text(
                  booking.specialRequest!,
                  style: AppFonts.body(size: 12, color: AppColors.appTextSecondaryColor).copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            ],
            if (onCancel != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD64545),
                    side: const BorderSide(color: Color(0xFFD64545)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Cancel booking', style: AppFonts.body(size: 13, weight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final String label;
  final List<String> lines;
  final String? phone;
  final String? email;
  const _InfoColumn({required this.label, required this.lines, this.phone, this.email});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppFonts.mono(size: 9.5, color: AppColors.appTextMutedColor, letterSpacing: 0.6),
        ),
        const SizedBox(height: 3),
        for (final line in lines)
          Text(
            line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.body(size: 13, weight: FontWeight.w600),
          ),
        if (phone != null) _ContactRow(icon: Icons.call, text: phone!, onTap: () => _dial(context, phone!)),
        if (email != null) _ContactRow(icon: Icons.email_outlined, text: email!, onTap: () => _email(context, email!)),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _ContactRow({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.appPrimaryColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: AppColors.appPrimaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
