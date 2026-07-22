#!/usr/bin/env bash
# score-regression.sh — scoring backend for autoresearch:regression
#
#   rubric  [file]          → grep-rubric quality score of regression.md   → "SCORE: N"
#   verdict <results.tsv>   → tiered stability verdict from a results TSV
#
# verdict logic:
#   - any HARD row that is a green→red regression (classification=eligible, regressed=true) → UNSTABLE
#   - else weighted SCORE: per-dim worst subscore, weights renormalized over dims that ran,
#     STABLE iff stability_score >= threshold (default 95)
#   - classification in {pre-existing,new-coverage,baseline-unavailable,flaky} never gates
#   - exit 0 STABLE / 1 UNSTABLE / 2 ERROR   (CI-usable)   · score math → stderr
#
# Overridable env: REG_THRESHOLD, REG_W_FLAKINESS, REG_W_PERFORMANCE, REG_W_RESOURCE, REG_W_VISUAL
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SPEC_DEFAULT="$REPO_ROOT/claude-plugin/commands/autoresearch/regression.md"

REG_THRESHOLD="${REG_THRESHOLD:-95}"
REG_W_FLAKINESS="${REG_W_FLAKINESS:-0.30}"
REG_W_PERFORMANCE="${REG_W_PERFORMANCE:-0.30}"
REG_W_RESOURCE="${REG_W_RESOURCE:-0.20}"
REG_W_VISUAL="${REG_W_VISUAL:-0.20}"

# ---------------------------------------------------------------------------
# rubric: grep the protocol spec for required invariants/sections/flags.
# Each pattern matched = +1. Prints "SCORE: N" only.
# ---------------------------------------------------------------------------
rubric() {
  local file="${1:-$SPEC_DEFAULT}"
  if [[ ! -f "$file" ]]; then echo "SCORE: 0"; return 0; fi

  local checks=(
    "classification"
    "green.{0,3}red"
    "regression.eligible|[^a-z]eligible"
    "pre-existing"
    "new-coverage"
    "baseline.unavailable|BASELINE_UNAVAILABLE"
    "functional"
    "api-contract"
    "data-migration"
    "integration-e2e"
    "flakiness"
    "performance"
    "resource"
    "visual"
    "HARD"
    "SCORE"
    "worktree"
    "--detach|detach"
    "submodule"
    "baseline.cache|--baseline-cache"
    "--select"
    "findRelatedTests|nx affected|affected"
    "Mann.?Whitney"
    "independent.process"
    "effect.size|median delta"
    "SSIM|maxDiffPixelRatio|pixel.ratio"
    "samples"
    "noise-band"
    "forward-only"
    "allowlist"
    "fix-cycle|--fix-cycles"
    "probe"
    "auto-skip"
    "--max-runs"
    "handoff"
    "verdict"
    "STABLE"
    "UNSTABLE"
  )

  local score=0 pat
  for pat in "${checks[@]}"; do
    if grep -qiE -- "$pat" "$file"; then score=$((score + 1)); fi
  done
  echo "SCORE: $score"
}

# ---------------------------------------------------------------------------
# verdict: reduce a results TSV to STABLE|UNSTABLE + stability score.
# ---------------------------------------------------------------------------
verdict() {
  local tsv="${1:?usage: verdict <results.tsv>}"
  if [[ ! -f "$tsv" ]]; then
    echo "VERDICT: ERROR"; echo "score=0.0"; echo "blocking=missing-tsv"
    return 2
  fi

  awk -v FS='\t' \
      -v wF="$REG_W_FLAKINESS" -v wP="$REG_W_PERFORMANCE" \
      -v wR="$REG_W_RESOURCE"  -v wV="$REG_W_VISUAL" \
      -v thr="$REG_THRESHOLD" '
    /^#/      { next }              # comment (e.g. metric_direction)
    $1=="iteration" { next }        # header
    NF < 11   { next }              # malformed / short row
    {
      nrows++;
      dim=$3; tier=$5; cls=$6; regressed=$10; subv=$11+0;
      present[dim]=1;
      if (tier=="HARD" && regressed=="true" && cls=="eligible") hardset[dim]=1;
      if (tier=="SCORE" && cls!="baseline-unavailable") {
        if (!(dim in dmin) || subv < dmin[dim]) dmin[dim]=subv;   # per-dim worst case
      }
    }
    END {
      # No measurable data rows ran at all → nothing to gate on. Must NOT read as a
      # green ship signal: an empty/header-only TSV or all-dims-unavailable run is
      # advisory, not STABLE. Emit BASELINE_UNAVAILABLE + non-zero exit.
      if (nrows==0) {
        printf "VERDICT: BASELINE_UNAVAILABLE\n";
        printf "score=0.00\n";
        printf "blocking=no-dims-ran\n";
        printf "dims_ran=none\n";
        printf "dims_unavailable=functional,api-contract,data-migration,integration-e2e,flakiness,performance,resource,visual-ui\n";
        exit 2;
      }

      hb="";
      for (d in hardset) hb = hb (hb==""?"":",") d;

      wt["flakiness"]=wF; wt["performance"]=wP; wt["resource"]=wR; wt["visual-ui"]=wV;
      num=0; den=0;
      for (d in dmin) { w=(d in wt)?wt[d]:0; if (w>0){ num+=w*dmin[d]; den+=w; } }
      score = (den>0) ? num/den : 100;

      split("functional,api-contract,data-migration,integration-e2e,flakiness,performance,resource,visual-ui", reg, ",");
      ran=""; unavail="";
      for (i=1;i<=8;i++){
        if (reg[i] in present) ran = ran (ran==""?"":",") reg[i];
        else                   unavail = unavail (unavail==""?"":",") reg[i];
      }

      unstable = (hb!="") || (score < thr);
      verdict  = unstable ? "UNSTABLE" : "STABLE";
      if      (hb!="" && score<thr) blocking = hb ",score";
      else if (hb!="")              blocking = hb;
      else if (score<thr)           blocking = "score";
      else                          blocking = "none";

      # Display floors to 2 decimals (never rounds up): a true 94.9999 must print as
      # 94.99 — not 95.00 — so the shown number cannot read >= threshold while UNSTABLE.
      # The gate itself (above) compares full precision.
      disp = int(score*100)/100;

      printf "VERDICT: %s\n", verdict;
      printf "score=%.2f\n", disp;
      printf "blocking=%s\n", blocking;
      printf "dims_ran=%s\n", (ran==""?"none":ran);
      printf "dims_unavailable=%s\n", (unavail==""?"none":unavail);

      for (d in dmin) printf "  %-12s subscore=%.2f weight=%s\n", d, int(dmin[d]*100)/100, ((d in wt)?wt[d]:"0") > "/dev/stderr";
      printf "  stability_score=%.2f threshold=%s\n", disp, thr > "/dev/stderr";

      exit (unstable ? 1 : 0);
    }
  ' "$tsv"
}

case "${1:-}" in
  rubric)  shift; rubric  "$@" ;;
  verdict) shift; verdict "$@" ;;
  *) echo "usage: $0 {rubric [file] | verdict <results.tsv>}" >&2; exit 64 ;;
esac
