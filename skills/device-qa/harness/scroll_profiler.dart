import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../presentation/map/map_screen.dart';
import '../../presentation/trending/trending_sheet.dart';

/// [측정 전용] 스크롤 프레임 성능 자동 측정 하네스.
///
/// `--dart-define=PERFTEST=true` + 비릴리즈(profile) 에서만 동작.
/// 프로덕션 빌드엔 영향 없음(트리거가 main 에서 게이트됨).
///
/// 동작: 홈 → 트렌딩 시트 → 지도 시트 순회하며, 각 화면의 **모든** 스크롤
/// (가로/세로 구분)을 결정적 animateTo 왕복으로 흔들어 FrameTiming 수집.
/// build(UI 스레드)·raster(GPU 스레드) ms 와 jank(예산 초과 프레임) 산출.
/// 결과 JSON 을 sink(localhost:9009) 로 POST.
class ScrollProfiler {
  ScrollProfiler._();

  /// PERFTEST 플래그(컴파일 타임).
  static const bool enabled =
      bool.fromEnvironment('PERFTEST', defaultValue: false) && !kReleaseMode;

  static const double _budget120 = 1000.0 / 120.0; // 8.33ms (120Hz)
  static const double _budget60 = 1000.0 / 60.0; // 16.67ms (60Hz)
  static const double _budgetSevere = 1000.0 / 30.0; // 33.33ms

  /// 결과 출력: 브라우저 콘솔 print + 로컬 sink POST(profile web 은 print 미포워딩).
  static void _emit(String s) {
    // ignore: avoid_print
    print(s);
    try {
      html.window.navigator.sendBeacon('http://localhost:9009/', '$s\n');
    } catch (_) {}
  }

  /// 부팅 후 측정 스케줄. main 에서 enabled 일 때만 호출.
  static void scheduleAfterBoot() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(seconds: 4));
      try {
        await _runSuite();
      } catch (e, st) {
        _emit('__PERF_ERROR__ $e\n$st');
      }
      _emit('__PERF_DONE__');
    });
  }

  static Future<void> _runSuite() async {
    final results = <Map<String, dynamic>>[];

    // CDP 모바일 뷰포트 에뮬레이션 적용 대기(레이스 방지). 최대 ~10s.
    for (var i = 0; i < 40; i++) {
      if (html.window.innerWidth! < 600) break;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    _emit('__PERF_DIAG__ viewport=${html.window.innerWidth}'
        'x${html.window.innerHeight}');

    // 쿠폰 그림자 재래스터 단가 직접 측정(리프레시레이트 무관 = 60/120Hz 동일).
    _measureShadowCost();

    final ctx = _anyScrollableContext();

    // --- 홈 ---
    results.addAll(await _measureScreen('홈', exclude: const {}));
    // 홈 스크롤 position 들 — 시트 뒤에 남아있으므로 이후 측정서 제외
    final homePos =
        _scrollables(exclude: const {}).map((s) => s.position).toSet();

    // PERF_HOME_ONLY=true 면 홈만 측정(빠른 반복용).
    const homeOnly = bool.fromEnvironment('PERF_HOME_ONLY', defaultValue: false);
    if (homeOnly) {
      _emit('__PERF_RESULT__ ${jsonEncode(results)}');
      return;
    }

    // --- 트렌딩 시트 ---
    if (ctx != null && ctx.mounted) {
      // ignore: use_build_context_synchronously
      unawaited(showTrendingSheet(ctx));
      await _settle(exclude: homePos);
      results.addAll(await _measureScreen('트렌딩', exclude: homePos));
      // ignore: use_build_context_synchronously
      await _closeSheet(ctx);
    }

    // --- 지도 시트 ---
    if (ctx != null && ctx.mounted) {
      // ignore: use_build_context_synchronously
      unawaited(showPharmacyMapSheet(ctx));
      await _settle(exclude: homePos, extra: const Duration(seconds: 1));
      results.addAll(await _measureScreen('지도', exclude: homePos));
      // ignore: use_build_context_synchronously
      await _closeSheet(ctx);
    }

    _emit('__PERF_RESULT__ ${jsonEncode(results)}');
  }

  /// 쿠폰 그림자 재래스터 단가 직접 측정.
  ///
  /// 레이어 evict 후 재래스터될 때 그림자가 다시 그려지는 그 1회 비용을,
  /// 두 방식으로 raw canvas → toImageSync 래스터해 Stopwatch 로 잰다:
  /// - blur: BoxShadow 와 동일(RRect + MaskFilter.blur 가우시안 매번 재계산)
  /// - baked: 1회 구운 ui.Image 를 drawImageRect 로 blit
  /// raster ms 는 디스플레이 주사율과 무관 → 여기 값이 곧 120Hz 프레임 비용.
  /// 실제 카드 크기/DPR 을 트리에서 읽어 동일 조건으로 측정.
  static void _measureShadowCost() {
    final dpr = html.window.devicePixelRatio.toDouble();

    // 실제 렌더된 쿠폰 카드 크기 탐색(없으면 대표값).
    Size? cardSize;
    final root = WidgetsBinding.instance.rootElement;
    if (root != null) {
      void visit(Element el) {
        if (cardSize != null) return;
        if (el.widget.runtimeType.toString() == 'CouponCard') {
          final ro = el.findRenderObject();
          if (ro is RenderBox && ro.hasSize) cardSize = ro.size;
          return;
        }
        el.visitChildren(visit);
      }

      root.visitChildren(visit);
    }
    final w = cardSize?.width ?? 350.0;
    final cardH = cardSize?.height ?? 266.0;
    const barcodeH = 92.0;
    final dealH = (cardH - barcodeH).clamp(80.0, 400.0).toDouble();

    // coupon_card.dart 와 동일 파라미터.
    const color = Color(0x141E202A);
    const blur = 7.4;
    final sigma = blur * 0.57735 + 0.5;
    final margin = blur * 3;
    const dealBr = BorderRadius.only(
      topLeft: Radius.circular(8),
      topRight: Radius.circular(8),
      bottomLeft: Radius.circular(16),
      bottomRight: Radius.circular(16),
    );
    const barcodeBr = BorderRadius.only(
      topLeft: Radius.circular(16),
      topRight: Radius.circular(16),
      bottomLeft: Radius.circular(8),
      bottomRight: Radius.circular(8),
    );

    List<double> stat(List<double> xs) {
      xs.sort();
      double pct(double p) => xs[((xs.length - 1) * p).round()];
      return [
        double.parse(pct(0.50).toStringAsFixed(3)),
        double.parse(pct(0.99).toStringAsFixed(3)),
        double.parse(xs.last.toStringAsFixed(3)),
      ];
    }

    // blur(BoxShadow) 1회 재래스터 비용: 매번 RRect + 가우시안 fresh.
    List<double> benchBlur(double width, double height, BorderRadius br) {
      final wPx = ((width + margin * 2) * dpr).ceil();
      final hPx = ((height + margin * 2) * dpr).ceil();
      final samples = <double>[];
      for (var i = 0; i < 70; i++) {
        final sw = Stopwatch()..start();
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        c.scale(dpr);
        final rrect = br.toRRect(Rect.fromLTWH(margin, margin, width, height));
        c.drawRRect(
          rrect,
          Paint()
            ..color = color
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
        );
        c.drawRRect(rrect, Paint()..color = const Color(0xFFFFFFFF));
        final img = rec.endRecording().toImageSync(wPx, hPx);
        sw.stop();
        if (i >= 10) samples.add(sw.elapsedMicroseconds / 1000.0); // 워밍업 제외
        img.dispose();
      }
      return stat(samples);
    }

    // baked 1회 재래스터 비용: 1회만 굽고(루프 밖) 매번 blit.
    List<double> benchBaked(double width, double height, BorderRadius br) {
      final wPx = ((width + margin * 2) * dpr).ceil();
      final hPx = ((height + margin * 2) * dpr).ceil();
      // 1회 굽기(실제 _ShadowPainter._bake 와 동일).
      final brec = ui.PictureRecorder();
      final bc = Canvas(brec);
      bc.scale(dpr);
      final brrect = br.toRRect(Rect.fromLTWH(margin, margin, width, height));
      bc.drawRRect(
        brrect,
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
      );
      final baked = brec.endRecording().toImageSync(wPx, hPx);
      final srcR =
          Rect.fromLTWH(0, 0, baked.width.toDouble(), baked.height.toDouble());

      final samples = <double>[];
      for (var i = 0; i < 70; i++) {
        final sw = Stopwatch()..start();
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        c.scale(dpr);
        final rrect = br.toRRect(Rect.fromLTWH(margin, margin, width, height));
        final dst = Rect.fromLTWH(
            0, 0, width + margin * 2, height + margin * 2);
        c.drawImageRect(
            baked, srcR, dst, Paint()..filterQuality = FilterQuality.low);
        c.drawRRect(rrect, Paint()..color = const Color(0xFFFFFFFF));
        final img = rec.endRecording().toImageSync(wPx, hPx);
        sw.stop();
        if (i >= 10) samples.add(sw.elapsedMicroseconds / 1000.0);
        img.dispose();
      }
      baked.dispose();
      return stat(samples);
    }

    final blurDeal = benchBlur(w, dealH, dealBr);
    final blurBar = benchBlur(w, barcodeH, barcodeBr);
    final bakedDeal = benchBaked(w, dealH, dealBr);
    final bakedBar = benchBaked(w, barcodeH, barcodeBr);

    final result = {
      'card': {'w': w, 'h': cardH, 'dealH': dealH, 'barcodeH': barcodeH},
      'dpr': dpr,
      'found': cardSize != null,
      // [p50, p99, max] ms — 그림자 op 1회 재래스터.
      'blur_deal': blurDeal,
      'blur_barcode': blurBar,
      'baked_deal': bakedDeal,
      'baked_barcode': bakedBar,
      // 카드 1장 = 딜 + 바코드 두 그림자 op 합(p50 기준).
      'card_blur_p50':
          double.parse((blurDeal[0] + blurBar[0]).toStringAsFixed(3)),
      'card_baked_p50':
          double.parse((bakedDeal[0] + bakedBar[0]).toStringAsFixed(3)),
      'budget_120hz': _budget120,
    };
    _emit('__PERF_SHADOW__ ${jsonEncode(result)}');
  }

  /// 현재 화면의 모든 스크롤(가로/세로) 측정.
  static Future<List<Map<String, dynamic>>> _measureScreen(
    String screen, {
    required Set<ScrollPosition> exclude,
  }) async {
    final list = _scrollables(exclude: exclude);
    if (list.isEmpty) {
      _emit('__PERF_WARN__ $screen: 스크롤 가능한 영역 없음(콘텐츠가 화면에 다 들어옴)');
      return const [];
    }
    final out = <Map<String, dynamic>>[];
    final used = <String>{};
    for (final s in list) {
      var label = _label(screen, s.position.axis);
      if (!used.add(label)) label = '$label#${out.length + 1}';
      out.add(await _measure(label, screen, s.position));
    }
    return out;
  }

  static String _label(String screen, Axis axis) {
    final h = axis == Axis.horizontal;
    switch (screen) {
      case '홈':
        return '홈 · 메인 피드(세로)';
      case '트렌딩':
        return h ? '트렌딩 · 상단 칩(가로)' : '트렌딩 · 랭킹 리스트(세로)';
      case '지도':
        return h ? '지도 · 가로 스크롤' : '지도 · 약국 리스트(세로)';
      default:
        return '$screen · ${h ? "가로" : "세로"}';
    }
  }

  /// 한 ScrollPosition 결정적 왕복 스크롤하며 프레임 수집 → 통계.
  static Future<Map<String, dynamic>> _measure(
    String label,
    String screen,
    ScrollPosition pos,
  ) async {
    final frames = <FrameTiming>[];
    void cb(List<FrameTiming> ts) => frames.addAll(ts);
    SchedulerBinding.instance.addTimingsCallback(cb);

    const dur = Duration(milliseconds: 1200);
    const curve = Curves.easeInOut;
    final maxE = pos.maxScrollExtent;
    final sw = Stopwatch()..start();
    for (var i = 0; i < 2; i++) {
      if (!pos.hasContentDimensions) break;
      await pos.animateTo(pos.maxScrollExtent, duration: dur, curve: curve);
      await pos.animateTo(pos.minScrollExtent, duration: dur, curve: curve);
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    sw.stop();
    SchedulerBinding.instance.removeTimingsCallback(cb);

    return _stats(label, screen, pos.axis, frames, maxE, sw.elapsedMilliseconds);
  }

  static Map<String, dynamic> _stats(
    String label,
    String screen,
    Axis axis,
    List<FrameTiming> frames,
    double maxExtent,
    int elapsedMs,
  ) {
    double ms(Duration d) => d.inMicroseconds / 1000.0;
    final build = frames.map((f) => ms(f.buildDuration)).toList()..sort();
    final raster = frames.map((f) => ms(f.rasterDuration)).toList()..sort();
    final total = frames.map((f) => ms(f.totalSpan)).toList()..sort();
    // 프레임당 실작업 = build(UI) + raster(GPU). 주사율 무관.
    // 이 값이 예산 안이면 그 주사율 유지 가능. 웹 CanvasKit 은 메인스레드
    // 공유라 합산이 보수적(실제론 일부 파이프라인). 120fps 적합 판정 기준.
    final work = frames
        .map((f) => ms(f.buildDuration) + ms(f.rasterDuration))
        .toList()
      ..sort();

    double pct(List<double> xs, double p) {
      if (xs.isEmpty) return 0;
      return xs[((xs.length - 1) * p).round()];
    }

    final jank120 = total.where((t) => t > _budget120).length;
    final jank60 = total.where((t) => t > _budget60).length;
    final jankSevere = total.where((t) => t > _budgetSevere).length;
    // 프레임당 작업이 120Hz/60Hz 예산 초과한 수(주사율 무관 = 능력 판정).
    final workOver120 = work.where((t) => t > _budget120).length;
    final workOver60 = work.where((t) => t > _budget60).length;
    final fit120pct = frames.isEmpty
        ? 0.0
        : double.parse(
            (100.0 * (frames.length - workOver120) / frames.length)
                .toStringAsFixed(1));

    // 드랍 케이스 추적: 120Hz 예산(8.33ms) 초과 프레임 개별 기록.
    // 원인(build/raster 중 큰 쪽) + 스크롤 내 위치(frac) + ms 분해.
    final drops = <Map<String, dynamic>>[];
    for (var i = 0; i < frames.length; i++) {
      final f = frames[i];
      final b = ms(f.buildDuration);
      final r = ms(f.rasterDuration);
      final w = b + r;
      if (w > _budget120) {
        drops.add({
          'i': i,
          'frac': frames.length < 2
              ? 0.0
              : double.parse((i / (frames.length - 1)).toStringAsFixed(2)),
          'build': double.parse(b.toStringAsFixed(1)),
          'raster': double.parse(r.toStringAsFixed(1)),
          'work': double.parse(w.toStringAsFixed(1)),
          'cause': b >= r ? 'build' : 'raster',
        });
      }
    }
    // 페이로드 제한: work 큰 순 상위 50개.
    drops.sort((a, b) => (b['work'] as double).compareTo(a['work'] as double));
    final dropsTop = drops.take(50).toList();
    // 실측 fps: 수집 프레임수 / 경과시간(스크롤 모션 구간).
    final fps = elapsedMs <= 0 ? 0.0 : frames.length * 1000.0 / elapsedMs;

    Map<String, double> dist(List<double> xs) => {
          'p50': double.parse(pct(xs, 0.50).toStringAsFixed(2)),
          'p90': double.parse(pct(xs, 0.90).toStringAsFixed(2)),
          'p95': double.parse(pct(xs, 0.95).toStringAsFixed(2)),
          'p99': double.parse(pct(xs, 0.99).toStringAsFixed(2)),
          'max': double.parse((xs.isEmpty ? 0 : xs.last).toStringAsFixed(2)),
        };

    return {
      'label': label,
      'screen': screen,
      'axis': axis == Axis.horizontal ? 'h' : 'v',
      'frames': frames.length,
      'maxScrollExtent': double.parse(maxExtent.toStringAsFixed(1)),
      'fps': double.parse(fps.toStringAsFixed(1)),
      'jank_gt8ms': jank120,
      'jank_gt16ms': jank60,
      'jank_gt33ms': jankSevere,
      'jank_gt16ms_pct': frames.isEmpty
          ? 0.0
          : double.parse((100.0 * jank60 / frames.length).toStringAsFixed(1)),
      'build_ms': dist(build),
      'raster_ms': dist(raster),
      'total_ms': dist(total),
      // 프레임당 작업(build+raster) — 120fps 적합 판정용.
      'work_ms': dist(work),
      'work_over_8ms': workOver120,
      'work_over_16ms': workOver60,
      'fit120_pct': fit120pct,
      'drops_total': drops.length,
      'drops': dropsTop,
    };
  }

  /// 트리워크로 스크롤 가능한 ScrollableState 목록(maxExtent 내림차순).
  static List<ScrollableState> _scrollables({
    required Set<ScrollPosition> exclude,
    double minExtent = 20,
  }) {
    final found = <ScrollableState>[];
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return found;
    void visit(Element el) {
      if (el is StatefulElement && el.state is ScrollableState) {
        final p = (el.state as ScrollableState).position;
        if (p.hasContentDimensions &&
            p.maxScrollExtent > minExtent &&
            !exclude.contains(p)) {
          found.add(el.state as ScrollableState);
        }
      }
      el.visitChildren(visit);
    }

    root.visitChildren(visit);
    found.sort(
      (a, b) =>
          b.position.maxScrollExtent.compareTo(a.position.maxScrollExtent),
    );
    return found;
  }

  /// 첫 Scrollable element 의 context(extent 무관) — 시트 표시용(Navigator 하위).
  static BuildContext? _anyScrollableContext() {
    BuildContext? ctx;
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return null;
    void visit(Element el) {
      if (ctx != null) return;
      if (el is StatefulElement && el.state is ScrollableState) {
        ctx = el;
        return;
      }
      el.visitChildren(visit);
    }

    root.visitChildren(visit);
    return ctx;
  }

  /// 시트 콘텐츠(새 스크롤) 등장 + 데이터 로드 대기.
  static Future<void> _settle({
    required Set<ScrollPosition> exclude,
    Duration extra = Duration.zero,
  }) async {
    for (var i = 0; i < 40; i++) {
      if (_scrollables(exclude: exclude).isNotEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    // 데이터/이미지 추가 로드 안정화
    await Future<void>.delayed(const Duration(milliseconds: 600) + extra);
  }

  /// 최상단 시트(모달 라우트) 닫기.
  static Future<void> _closeSheet(BuildContext ctx) async {
    if (ctx.mounted) {
      Navigator.of(ctx, rootNavigator: true).maybePop();
    }
    await Future<void>.delayed(const Duration(milliseconds: 800));
  }
}
