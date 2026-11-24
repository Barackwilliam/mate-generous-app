import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/live.dart';

/// "Jiunge" from the template. Plans and prices come from the admin.
/// Payment itself is the next step, so the button explains it is coming.
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  int? _selected;
  String _network = 'mpesa';

  static String price(num value) =>
      'Tsh ${value.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';

  void _join() {
    final s = context.read<AppState>().s;
    showModalBottomSheet(
      context: context,
      backgroundColor: Palette.night,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset(Img.premium, height: 70),
          const SizedBox(height: 12),
          Text(s.paymentsSoon, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 8),
          Text(s.paymentsSoonNote, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFD5DAF5), height: 1.5)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final api = context.read<AppState>().api;
    return Theme(
      data: AppTheme.of(Palette.dark, Brightness.dark),
      child: Builder(builder: (context) {
        final p = context.pal;
        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF3A1A86), Color(0xFF22106A), Color(0xFF120B45)],
              ),
            ),
            child: SafeArea(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 28), children: [
                Row(children: [
                  RoundButton(icon: const Icon(Icons.close_rounded), label: s.close, bare: true, onTap: () => Navigator.pop(context)),
                  const Spacer(),
                  const LangToggle(),
                ]),
                Center(child: Image.asset(Img.premium, height: 104)),
                const SizedBox(height: 10),
                Text(s.joinTitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, height: 1.15)),
                const SizedBox(height: 4),
                Text(s.joinSub, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: p.muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Center(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final perk in [s.perkSermons, s.perkCourses, s.perkPremium])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(gradient: Palette.goldGradient, shape: BoxShape.circle),
                            child: Icon(Icons.check_rounded, size: 16, color: p.onAccent),
                          ),
                          const SizedBox(width: 10),
                          Flexible(child: Text(perk, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                        ]),
                      ),
                  ]),
                ),
                const SizedBox(height: 18),
                LiveData<List<Plan>>(
                  load: () => api.plans(),
                  builder: (context, plans, _) {
                    final best = plans.where((x) => x.days >= 365 && x.tier == 'standard').map((x) => x.id).firstOrNull ??
                        (plans.isEmpty ? null : plans.last.id);
                    _selected ??= best;
                    return SizedBox(
                      height: 128,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        children: [
                          _PlanCard(title: s.freePreview, price: 'Tsh 0', note: s.preview, selected: false, onTap: null),
                          for (final plan in plans) ...[
                            const SizedBox(width: 10),
                            _PlanCard(
                              title: plan.name,
                              price: plan.price > 0 ? price(plan.price) : s.priceSoon,
                              note: plan.tier == 'premium' ? s.premiumPlus : (plan.id == best ? (s.en ? 'Popular' : 'Maarufu') : s.days(plan.days)),
                              selected: _selected == plan.id,
                              ribbon: plan.id == best ? s.bestValue : null,
                              onTap: () => setState(() => _selected = plan.id),
                            ),
                          ],
                          if (plans.isEmpty) ...[
                            const SizedBox(width: 10),
                            SizedBox(width: 220, child: Center(child: Text(s.noPlans, style: TextStyle(color: p.muted)))),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 22),
                PrimaryButton(label: s.joinNowArrow, trailing: const Icon(Icons.arrow_forward_rounded), onPressed: _join),
                const SizedBox(height: 16),
                Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
                  for (final (key, label, color) in [
                    ('mpesa', 'M-Pesa', const Color(0xFF16A34A)),
                    ('airtel', 'Airtel Money', const Color(0xFFDC2626)),
                    ('mixx', 'Mixx by Yas', const Color(0xFF2563EB)),
                  ])
                    Semantics(
                        button: true,
                        selected: _network == key,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _network = key),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _network == key ? p.accent : Colors.transparent),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.phone_android_rounded, size: 18, color: color),
                              const SizedBox(width: 4),
                              Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                    ),
                ]),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.title, required this.price, required this.note, required this.selected, required this.onTap, this.ribbon});
  final String title;
  final String price;
  final String note;
  final bool selected;
  final String? ribbon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final gold = selected || ribbon != null;
    final fg = gold ? p.onAccent : const Color(0xFF1A1033);
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 118,
            padding: const EdgeInsets.fromLTRB(10, 16, 10, 12),
            decoration: BoxDecoration(
              gradient: gold ? Palette.goldGradient : null,
              color: gold ? null : const Color(0xFFF4EFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 2),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: fg)),
              const SizedBox(height: 4),
              FittedBox(child: Text(price, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: fg))),
              const SizedBox(height: 2),
              Text(note, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg.withValues(alpha: 0.8))),
            ]),
          ),
          if (ribbon != null)
            Positioned(
              top: -9,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white, width: 1)),
                child: const Text('BEST VALUE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF1A1033))),
              ),
            ),
        ]),
      ),
    );
  }
}
