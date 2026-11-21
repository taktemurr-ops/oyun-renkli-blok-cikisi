import 'package:flutter_test/flutter_test.dart';
import 'package:oyun_renkli_blok_cikisi/oyun_renkli_blok_cikisi.dart';
import 'package:studio_core/core/level_plan.dart';

void main() {
  final rules = ExitRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  test('bölümler çözülebilir; çözüm oynanınca kazanılır', () {
    for (final lv in [1, 12, 50, 99, 230, 777, 2500, 9999, 33333, 49999]) {
      final gl = rules.build(planner.spec(lv));
      expect(gl.validation.ok, isTrue, reason: 'bölüm $lv');
      expect(gl.attempts, lessThan(40), reason: 'bölüm $lv kolaylaştırıldı');
      final l = rules.finalize(gl);
      final g = ExitGame(l);
      final sol = g.board.solve(g.pos)!;
      expect(sol.length, l.optimal);
      for (final m in sol) {
        expect(g.move(m ~/ 4, m % 4), isNot(0));
      }
      expect(g.won, isTrue);
      expect(ExitRules.stars(g), 3);
    }
  });

  test('ipucu çözüme götürür; geri al ve kayıt çalışır', () {
    final l = rules.finalize(rules.build(planner.spec(123)));
    final g = ExitGame(l);
    final h = g.hint()!;
    expect(g.move(h.$1, h.$2), isNot(0));
    final r = ExitGame.restore(l, g.serialize());
    expect(r.pos, g.pos);
    g.undo();
    expect(g.pos, l.start);
  });
}
