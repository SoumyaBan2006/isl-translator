import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:math' as math;

class SignClassifier {
  bool _isLoaded = false;

  Future<void> load() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _isLoaded = true;
  }

  static String formatSign(String raw) {
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty
            ? ''
            : w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  String predictFromPose(List<PoseLandmark> landmarks) {
    if (!_isLoaded || landmarks.isEmpty) return '';

    final Map<int, PoseLandmark> lm = {};
    for (final l in landmarks) {
      lm[l.type.index] = l;
    }

    final lw = lm[15];
    final rw = lm[16];
    final ls = lm[11];
    final rs = lm[12];
    final le = lm[13];
    final re = lm[14];
    final nose = lm[0];
    final lh = lm[23];
    final rh = lm[24];

    if (lw == null || rw == null || ls == null || rs == null) return '';

    final shY = (ls.y + rs.y) / 2;
    final shW = (rs.x - ls.x).abs();
    final shMidX = (ls.x + rs.x) / 2;

    final lwRel = lw.y - shY;
    final rwRel = rw.y - shY;
    final lwFromCenter = lw.x - shMidX;
    final rwFromCenter = rw.x - shMidX;

    final wristDist = math.sqrt(
      math.pow(lw.x - rw.x, 2) + math.pow(lw.y - rw.y, 2),
    );

    double elbowAngle(
        PoseLandmark shoulder, PoseLandmark elbow, PoseLandmark wrist) {
      final a =
          math.atan2(shoulder.y - elbow.y, shoulder.x - elbow.x);
      final b =
          math.atan2(wrist.y - elbow.y, wrist.x - elbow.x);
      return (a - b).abs() * 180 / math.pi;
    }

    final rightElbowAngle =
        re != null ? elbowAngle(rs, re, rw) : 180.0;
    final leftElbowAngle =
        le != null ? elbowAngle(ls, le, lw) : 180.0;

    final rwNoseX =
        nose != null ? (rw.x - nose.x).abs() : 999.0;
    final rwNoseY = nose != null ? (rw.y - nose.y) : 999.0;

    // ── DEAD ZONE — both arms hanging naturally ───────────────────────────────
    if (lwRel > 200 && rwRel > 200) return '';

    // ── HELLO ─────────────────────────────────────────────────────────────────
    if (rwRel < -100 && lwRel > 150 && rightElbowAngle > 100) {
      return 'HELLO';
    }

    // ── GOOD MORNING ──────────────────────────────────────────────────────────
    if (rwRel < -60 && lwRel < -60 &&
        rwFromCenter < -shW * 0.15 &&
        lwFromCenter > shW * 0.15) {
      return 'GOOD_MORNING';
    }

    // ── HOW ARE YOU ───────────────────────────────────────────────────────────
    if (rwRel > -40 && rwRel < 70 &&
        lwRel > -40 && lwRel < 70 &&
        rwFromCenter < -shW * 0.2 &&
        lwFromCenter > shW * 0.2 &&
        wristDist > shW * 1.4) {
      return 'HOW_ARE_YOU';
    }

    // ── WE ────────────────────────────────────────────────────────────────────
    if (lwRel > 5 && lwRel < 80 &&
        rwRel > 5 && rwRel < 80 &&
        wristDist < shW * 0.35) {
      return 'WE';
    }

    // ── TODAY ────────────────────────────────────────────────────────────────
    if (lwRel > 5 && lwRel < 80 &&
        rwRel > 5 && rwRel < 80 &&
        wristDist >= shW * 0.35 &&
        wristDist < shW * 0.8) {
      return 'TODAY';
    }

    // ── THANK YOU ─────────────────────────────────────────────────────────────
    if (lwRel > 80 && lwRel < 180 &&
        rwRel > 80 && rwRel < 180 &&
        wristDist > shW * 0.3 &&
        wristDist < shW * 1.2) {
      return 'THANK_YOU';
    }

    // ── I ─────────────────────────────────────────────────────────────────────
    if (rwRel > 40 && rwRel < 140 &&
        rwFromCenter.abs() < shW * 0.3 &&
        lwRel > 140 &&
        rightElbowAngle < 130) {
      return 'I';
    }

    // ── YOU ───────────────────────────────────────────────────────────────────
    if (rwRel < -20 && rwRel > -100 &&
        rwFromCenter < -shW * 0.05 &&
        lwRel > 100 &&
        rightElbowAngle > 120) {
      return 'YOU';
    }

    // ── HELP ──────────────────────────────────────────────────────────────────
    if (rwRel < lwRel - 50 &&
        rwRel > -60 && rwRel < 80 &&
        lwRel > 40 && lwRel < 180 &&
        rwNoseX < shW * 0.5) {
      return 'HELP';
    }

    // ── MOTHER ────────────────────────────────────────────────────────────────
    if (rwNoseX < shW * 0.35 &&
        rwNoseY > -20 && rwNoseY < 60 &&
        lwRel > 150) {
      return 'MOTHER';
    }

    // ── FATHER ────────────────────────────────────────────────────────────────
    if (rwNoseX < shW * 0.4 &&
        rwNoseY < -20 && rwNoseY > -100 &&
        rwRel < 0 &&
        lwRel > 120) {
      return 'FATHER';
    }

    // ── DOG ───────────────────────────────────────────────────────────────────
    // Very strict — wrist must be right at hip level
    if (rh != null &&
        (rw.y - rh.y).abs() < shW * 0.25 &&
        lwRel > 200 &&
        rwRel > 220 &&
        (rw.x - rh.x).abs() < shW * 0.3) {
      return 'DOG';
    }

    // ── BIRD ──────────────────────────────────────────────────────────────────
    if (rwRel > 60 && rwRel < 160 &&
        lwRel > 60 && lwRel < 160 &&
        (lwRel - rwRel).abs() > 40 &&
        wristDist < shW * 0.7) {
      return 'BIRD';
    }

    // ── MONDAY ────────────────────────────────────────────────────────────────
    if (rwRel > 60 && rwRel < 160 &&
        rwFromCenter < -shW * 0.15 &&
        lwRel > 160) {
      return 'MONDAY';
    }

    return '';
  }

  List<double> extractFeatures(
    List<double> hand1x,
    List<double> hand1y,
    List<double> hand2x,
    List<double> hand2y,
  ) {
    List<double> pad(List<double> lst) {
      if (lst.length >= 21) return lst.sublist(0, 21);
      return [...lst, ...List.filled(21 - lst.length, 0.0)];
    }
    return [
      ...pad(hand1x),
      ...pad(hand1y),
      ...pad(hand2x),
      ...pad(hand2y)
    ];
  }

  bool get isLoaded => _isLoaded;
}