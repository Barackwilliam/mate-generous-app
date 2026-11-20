import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';

/// Plans from the subscription engine. Payment itself is not part of this
/// phase, so the button explains that payments are coming.
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  late Future<List<Plan>> _future = context.read<AppState>().api.plans();
  int? _selected;
  String _network = 'mpesa';

  String _price(Plan plan, String soon) {
    if (plan.price <= 0) return soon;
    final digits = plan.price.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return 'TSh $digits';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 10, 20, 28), children: [
          Row(children: [
            RoundButton(icon: const Icon(Icons.close_rounded), label: s.close, onTap: () => Navigator.pop(context)),
            const Spacer(),
            const LangToggle(),
          ]),
          const SizedBox(height: 18),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(18)),
              alignment: Alignment.center,
              child: const CrossIcon(size: 28, color: Palette.night),
            ),
          ),
          const SizedBox(height: 14),
          Text(s.plansTitle, style: const TextStyle(fontFamily: AppTheme.serif, fontSize: 28, fontWeight: FontWeight.w600, height: 1.15)),
          const SizedBox(height: 8),
          Text(s.plansIntro, style: TextStyle(fontSize: 14, height: 1.5, color: p.muted)),
          const SizedBox(height: 18),
          FutureBuilder<List<Plan>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Loading();
              if (snap.hasError) {
                return ErrorRetry(error: snap.error!, onRetry: () => setState(() => _future = context.read<AppState>().api.plans()));
              }
              final plans = snap.data!;
              if (plans.isEmpty) return EmptyState(message: s.noPlans);
              final popular = plans.where((x) => x.days == 365 && x.tier == 'standard').map((x) => x.id).firstOrNull;
              _selected ??= popular ?? plans.first.id;
              return Column(children: [
                for (final plan in plans)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PlanTile(
                      plan: plan,
                      price: _price(plan, s.priceSoon),
                      selected: _selected == plan.id,
                      popular: plan.id == popular,
                      onTap: () => setState(() => _selected = plan.id),
                    ),
                  ),
              ]);
            },
          ),
          const SizedBox(height: 10),
          Text(s.payWith, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: p.muted)),
          const SizedBox(height: 10),
          Row(children: [
            for (final (key, label) in [('mpesa', 'M-Pesa'), ('airtel', 'Airtel Money'), ('mixx', 'Mixx by Yas')]) ...[
              Expanded(
                child: Semantics(
                  button: true,
                  selected: _network == key,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _network = key),
                    child: Container(
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _network == key ? p.surfaceHi : p.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _network == key ? p.accent : p.border, width: _network == key ? 2 : 1),
                      ),
                      child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _network == key ? p.text : p.muted)),
                    ),
                  ),
                ),
              ),
              if (key != 'mixx') const SizedBox(width: 8),
            ],
          ]),
          const SizedBox(height: 22),
          PrimaryButton(label: s.paymentsSoon, onPressed: null),
          const SizedBox(height: 10),
          Text(s.paymentsSoonNote, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: p.muted, height: 1.5)),
        ]),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.plan, required this.price, required this.selected, required this.popular, required this.onTap});
  final Plan plan;
  final String price;
  final bool selected;
  final bool popular;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: selected ? p.surfaceHi : p.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selected ? p.accent : p.border, width: selected ? 2 : 1),
            ),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? p.accent : Colors.transparent,
                  border: Border.all(color: selected ? p.accent : p.border, width: 2),
                ),
                child: selected ? Icon(Icons.check_rounded, size: 14, color: p.onAccent) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text.rich(TextSpan(children: [
                    TextSpan(text: plan.name),
                    if (plan.tier == 'premium') TextSpan(text: '  ${s.premiumPlus}', style: TextStyle(fontSize: 11, color: p.accentText)),
                  ]), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(s.days(plan.days), style: TextStyle(fontSize: 12, color: p.muted)),
                ]),
              ),
              Text(price, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
          ),
          if (popular)
            Positioned(
              top: -10,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(6)),
                child: Text(s.en ? 'POPULAR' : 'MAARUFU',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: p.onAccent)),
              ),
            ),
        ]),
      ),
    );
  }
}
