import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../clock/domain/entities/clock_config_entity.dart';
import '../../../clock/presentation/bloc/clock_bloc.dart';
import 'clock_style_card.dart';

/// 2-column grid of clock style cards (Styles tab).
class ClockStylesPanel extends StatelessWidget {
  const ClockStylesPanel({super.key});

  static const _labels = {
    ClockStyle.modern: 'Modern',
    ClockStyle.minimal: 'Minimal',
    ClockStyle.elegant: 'Elegant',
    ClockStyle.digital: 'Digital',
  };

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClockBloc, ClockState>(
      builder: (context, state) {
        final selected =
            state is ClockReady ? state.config.style : ClockStyle.modern;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            for (final style in ClockStyle.values)
              ClockStyleCard(
                style: style,
                label: _labels[style]!,
                selected: selected == style,
                onTap: () =>
                    context.read<ClockBloc>().add(ClockStyleChanged(style)),
              ),
          ],
        );
      },
    );
  }
}
