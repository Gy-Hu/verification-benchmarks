#!/usr/bin/env bash

set -u
set -o pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
YOSYS_BIN="${YOSYS_BIN:-yosys}"
PONO_BIN="${PONO_BIN:-pono}"
TIMEOUT_BIN="${TIMEOUT_BIN:-timeout}"
PONO_TIMEOUT="${PONO_TIMEOUT:-120}"
REPORT_FILE="${REPORT_FILE:-$ROOT_DIR/pono_ic3sa_summary.tsv}"
RUN_PONO=1
SKIP_EXISTING=0

# id|bench|top|harness|sources_csv
TARGETS=$(cat <<'TARGET_LIST'
h18_rtc_clock_formal|hackatdac18|rtc_clock_formal|formal/hackatdac18/rtc_clock_formal.sv|hackatdac18-2018-soc/rtl/pulpissimo/rtc_clock.sv
h18_apb_gpio_formal|hackatdac18|apb_gpio_formal|formal/hackatdac18/apb_gpio_formal.sv|hackatdac18-2018-soc/ips/tech_cells_generic/pulp_clock_gating.sv,hackatdac18-2018-soc/ips/apb/apb_gpio/apb_gpio.sv
h18_mux_func_formal|hackatdac18|mux_func_formal|formal/hackatdac18/mux_func_formal.sv|hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/SubBytes.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/SubBytes_sbox.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/aes_1cc.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/keccak.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/md5.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/tempsen.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/KeyExpansion.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/AddRoundKey.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/ShiftRows.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/MixColumns.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/padder.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/f_permutation.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/padder1.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/rconst2in1.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/round2in1.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/mux_func.sv
TARGET_LIST
)

print_usage() {
  cat <<'USAGE'
Usage:
  scripts/run_pono_ic3sa_with_properties.sh [options]

Options:
  --generate-only      Only generate property-carrying BTOR2 files, do not run Pono.
  --skip-existing      Skip BTOR2 generation when output exists and is non-empty.
  --report <path>      Write TSV report to this file.
  --timeout <seconds>  Timeout for each Pono run (default: 120).
  --list-targets       Print target list and exit.
  -h, --help           Show help.

Environment:
  YOSYS_BIN            Yosys executable (default: yosys)
  PONO_BIN             Pono executable (default: pono)
  TIMEOUT_BIN          timeout executable (default: timeout)
USAGE
}

list_targets() {
  printf "%-28s %-12s %-24s\n" "TARGET_ID" "BENCHMARK" "TOP"
  printf "%-28s %-12s %-24s\n" "--------" "---------" "---"
  while IFS='|' read -r id bench top _ _; do
    [[ -z "$id" ]] && continue
    printf "%-28s %-12s %-24s\n" "$id" "$bench" "$top"
  done <<< "$TARGETS"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --generate-only)
      RUN_PONO=0
      shift
      ;;
    --skip-existing)
      SKIP_EXISTING=1
      shift
      ;;
    --report)
      REPORT_FILE="$2"
      shift 2
      ;;
    --timeout)
      PONO_TIMEOUT="$2"
      shift 2
      ;;
    --list-targets)
      list_targets
      exit 0
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      print_usage
      exit 1
      ;;
  esac
done

if ! command -v "$YOSYS_BIN" >/dev/null 2>&1; then
  echo "ERROR: Yosys not found: $YOSYS_BIN" >&2
  exit 1
fi

if [[ "$RUN_PONO" -eq 1 ]] && ! command -v "$PONO_BIN" >/dev/null 2>&1; then
  echo "ERROR: Pono not found: $PONO_BIN" >&2
  exit 1
fi

HAS_TIMEOUT=1
if ! command -v "$TIMEOUT_BIN" >/dev/null 2>&1; then
  HAS_TIMEOUT=0
fi

mkdir -p "$(dirname "$REPORT_FILE")"
printf "target_id\tbenchmark\ttop\tbtor2\tbad_count\tyosys_status\tpono_status\tnote\tyosys_log\tpono_log\n" > "$REPORT_FILE"

append_report() {
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$@" >> "$REPORT_FILE"
}

build_ys_script() {
  local ys_path="$1"
  local top="$2"
  local btor_rel="$3"
  local harness_abs="$4"
  local source_csv="$5"

  {
    local src
    IFS=',' read -r -a srcs <<< "$source_csv"
    for src in "${srcs[@]}"; do
      [[ -z "$src" ]] && continue
      echo "read_verilog -formal -sv $src"
    done
    echo "read_verilog -formal -sv $harness_abs"
    echo "prep -top $top"
    echo "flatten"
    echo "memory -nordff"
    echo "hierarchy -check"
    echo "setundef -undriven -init -expose"
    echo "async2sync"
    echo "dffunmap"
    echo "write_btor -s $btor_rel"
  } > "$ys_path"
}

for t in $TARGETS; do
  IFS='|' read -r id bench top harness_rel source_csv <<< "$t"
  bench_dir="$ROOT_DIR/$bench"

  out_dir="$bench_dir/yosys_out"
  mkdir -p "$out_dir"

  btor_rel="yosys_out/${top}.btor2"
  ys_rel="yosys_out/${id}.ys"
  yosys_log_rel="yosys_out/${id}_yosys.log"
  pono_log_rel="yosys_out/${id}_pono.log"

  btor_abs="$bench_dir/$btor_rel"
  ys_abs="$bench_dir/$ys_rel"
  yosys_log_abs="$bench_dir/$yosys_log_rel"
  pono_log_abs="$bench_dir/$pono_log_rel"

  harness_abs="$ROOT_DIR/$harness_rel"
  if [[ ! -f "$harness_abs" ]]; then
    append_report "$id" "$bench" "$top" "$bench/$btor_rel" "0" "FAIL" "SKIPPED" "missing harness: $harness_rel" "$bench/$yosys_log_rel" "$bench/$pono_log_rel"
    continue
  fi

  missing_source=""
  IFS=',' read -r -a srcs_check <<< "$source_csv"
  for s in "${srcs_check[@]}"; do
    [[ -z "$s" ]] && continue
    if [[ ! -f "$bench_dir/$s" ]]; then
      missing_source="$missing_source missing:$s;"
    fi
  done
  if [[ -n "$missing_source" ]]; then
    append_report "$id" "$bench" "$top" "$bench/$btor_rel" "0" "FAIL" "SKIPPED" "$missing_source" "$bench/$yosys_log_rel" "$bench/$pono_log_rel"
    continue
  fi

  yosys_status="PASS"
  if [[ "$SKIP_EXISTING" -eq 1 && -s "$btor_abs" ]]; then
    :
  else
    build_ys_script "$ys_abs" "$top" "$btor_rel" "$harness_abs" "$source_csv"
    (
      cd "$bench_dir" || exit 1
      "$YOSYS_BIN" -q -s "$ys_rel" > "$yosys_log_rel" 2>&1
    )
    rc=$?
    if [[ "$rc" -ne 0 || ! -s "$btor_abs" ]]; then
      yosys_status="FAIL"
    fi
  fi

  if [[ "$yosys_status" != "PASS" ]]; then
    append_report "$id" "$bench" "$top" "$bench/$btor_rel" "0" "$yosys_status" "SKIPPED" "failed to produce btor2" "$bench/$yosys_log_rel" "$bench/$pono_log_rel"
    continue
  fi

  bad_count=$(rg -n '^\d+ bad ' "$btor_abs" | wc -l | tr -d ' ')

  if [[ "$RUN_PONO" -eq 0 ]]; then
    append_report "$id" "$bench" "$top" "$bench/$btor_rel" "$bad_count" "$yosys_status" "SKIPPED" "generate-only mode" "$bench/$yosys_log_rel" "$bench/$pono_log_rel"
    continue
  fi

  if [[ "$bad_count" -eq 0 ]]; then
    append_report "$id" "$bench" "$top" "$bench/$btor_rel" "$bad_count" "$yosys_status" "NO_PROPERTY" "no bad state in btor2" "$bench/$yosys_log_rel" "$bench/$pono_log_rel"
    continue
  fi

  pono_status="ERROR"
  pono_note=""
  if [[ "$HAS_TIMEOUT" -eq 1 ]]; then
    (
      cd "$bench_dir" || exit 1
      "$TIMEOUT_BIN" "${PONO_TIMEOUT}s" "$PONO_BIN" --engine ic3sa --verbosity 1 "$btor_rel" > "$pono_log_rel" 2>&1
    )
    prc=$?
  else
    (
      cd "$bench_dir" || exit 1
      "$PONO_BIN" --engine ic3sa --verbosity 1 "$btor_rel" > "$pono_log_rel" 2>&1
    )
    prc=$?
  fi

  if [[ "$prc" -eq 124 ]]; then
    pono_status="TIMEOUT"
    pono_note=">${PONO_TIMEOUT}s"
  elif rg -q '^unsat$' "$pono_log_abs"; then
    pono_status="UNSAT"
    pono_note="property proved"
  elif rg -q '^sat$' "$pono_log_abs"; then
    pono_status="SAT"
    pono_note="counterexample found"
  elif rg -q 'number of properties.*\(0\)' "$pono_log_abs"; then
    pono_status="NO_PROPERTY"
    pono_note="no property in model"
  elif [[ "$prc" -eq 0 ]]; then
    pono_status="DONE"
    pono_note="completed without sat/unsat marker"
  else
    pono_status="ERROR"
    pono_note="pono exit code $prc"
  fi

  append_report "$id" "$bench" "$top" "$bench/$btor_rel" "$bad_count" "$yosys_status" "$pono_status" "$pono_note" "$bench/$yosys_log_rel" "$bench/$pono_log_rel"
done

echo "Summary written to: $REPORT_FILE"
