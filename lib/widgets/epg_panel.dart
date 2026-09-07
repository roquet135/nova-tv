import 'package:flutter/material.dart';
import '../services/epg_service.dart';
import '../theme/nova_theme.dart';

/// Guide des programmes affiche a cote de la mini TV.
class EpgPanel extends StatelessWidget {
  final List<EpgProgram> programs;
  final bool loading;
  final String channelName;

  const EpgPanel({
    super.key,
    required this.programs,
    required this.channelName,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: NovaColors.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded,
                  size: 14, color: NovaColors.cyan),
              const SizedBox(width: 7),
              const Text('GUIDE TV',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: NovaColors.cyan,
                  )),
              const Spacer(),
              Flexible(
                child: Text(
                  channelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10.5, color: NovaColors.textDim),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (loading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: NovaColors.cyan),
        ),
      );
    }
    if (programs.isEmpty) {
      return const Center(
        child: Text(
          'Aucun programme fourni\npar ce portail',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: NovaColors.textDim),
        ),
      );
    }

    return ListView.separated(
      itemCount: programs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 7),
      itemBuilder: (context, i) {
        final p = programs[i];
        final now = p.isNow;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: now
                ? NovaColors.violet.withOpacity(0.18)
                : Colors.white.withOpacity(0.035),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: now ? NovaColors.cyan : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    p.range,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: now ? NovaColors.cyan : NovaColors.textDim,
                    ),
                  ),
                  if (now) ...[
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        gradient: NovaColors.brand,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('EN COURS',
                          style: TextStyle(
                              fontSize: 7.5, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                p.title.isEmpty ? 'Programme' : p.title,
                maxLines: now ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.3,
                  fontWeight: now ? FontWeight.w700 : FontWeight.w500,
                  color: now ? NovaColors.text : NovaColors.textDim,
                ),
              ),
              if (now) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: p.progress,
                    minHeight: 3,
                    backgroundColor: Colors.white.withOpacity(0.12),
                    valueColor: const AlwaysStoppedAnimation(NovaColors.cyan),
                  ),
                ),
                if (p.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    p.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.45,
                        color: NovaColors.textDim),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}
