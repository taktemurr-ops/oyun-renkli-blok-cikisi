import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/missions.dart';
import 'package:studio_core/core/stats.dart';

import 'exit_engine.dart';

const renkliCikisId = 'oyun-renkli-blok-cikisi';

class ExitRules extends GameRules<ExitLevel> {
  /// Üretim + çözücü türü: 100.000 numaralı bölüm (1000 dünya).
  @override
  int get levelCount => 100000;

  @override
  String get gameId => renkliCikisId;

  @override
  List<String> get optionalMechanics => const [];

  @override
  List<GameModeId> get modes => const [GameModeId.campaign, GameModeId.daily, GameModeId.weekly, GameModeId.challenge];

  @override
  List<GameStat> get gameStats => const [
        GameStat('blocks_exited', 'Çıkan blok', 'Blocks out', scale: 60),
        GameStat('perfect', 'En kısa çözüm', 'Perfect solves', scale: 3),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('exited', 'blocks_exited', [20, 60, 150]),
        MissionTemplate('perfect', 'perfect', [1, 3, 8]),
      ];

  @override
  ExitLevel generate(LevelSpec spec) => generateExitLevel(spec);

  @override
  Validation validate(ExitLevel level, LevelSpec spec) {
    final movable = level.blocks.where((b) => !b.stone).length;
    if (movable < 3) return const Validation.fail('too few blocks');
    final colors = {for (final b in level.blocks) if (!b.stone) b.color};
    for (final c in colors) {
      if (!level.doors.any((d) => d.color == c)) return const Validation.fail('missing door');
    }
    final sol = ExitBoard(level).solve(level.start, cap: 20000);
    if (sol == null) return const Validation.fail('not solvable');
    return Validation.ok(sol.length);
  }

  ExitLevel finalize(GeneratedLevel<ExitLevel> g) => g.puzzle.withOptimal(g.validation.metric);

  static int stars(ExitGame g) {
    if (!g.won) return 0;
    final o = g.level.optimal;
    if (o <= 0 || g.moves <= o) return 3;
    if (g.moves <= o + 3) return 2;
    return 1;
  }
}
