#!/usr/bin/env bash

set -u
set -o pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
YOSYS_BIN="${YOSYS_BIN:-yosys}"
TIMEOUT_BIN="${TIMEOUT_BIN:-timeout}"
DEFAULT_TIMEOUT="${DEFAULT_TIMEOUT:-300}"
REPORT_FILE="$ROOT_DIR/yosys_conversion_summary.tsv"
TARGET_MODE="stable"
SKIP_EXISTING=0
TIMEOUT_OVERRIDE=""

# Target format:
# id|benchmark_dir|top_module|btor_memory_mode|aiger_memory_mode|timeout_sec|source_csv|include_csv|tier
TARGETS=$(cat <<'TARGET_LIST'
h18_rtc_clock|hackatdac18|rtc_clock|nomap|nordff|120|hackatdac18-2018-soc/rtl/pulpissimo/rtc_clock.sv||stable
h18_apb_gpio|hackatdac18|apb_gpio|nomap|nordff|180|hackatdac18-2018-soc/ips/tech_cells_generic/pulp_clock_gating.sv,hackatdac18-2018-soc/ips/apb/apb_gpio/apb_gpio.sv||stable
h18_axi_address_decoder_ar|hackatdac18|axi_address_decoder_AR|nomap|nordff|180|hackatdac18-2018-soc/ips/axi/axi_node/axi_address_decoder_AR.sv||stable
h18_jtag_tap_top|hackatdac18|jtag_tap_top|nomap|nordff|240|hackatdac18-2018-soc/ips/jtag_pulp/src/bscell.sv,hackatdac18-2018-soc/ips/jtag_pulp/src/jtag_sync.sv,hackatdac18-2018-soc/ips/jtag_pulp/src/jtagreg.sv,hackatdac18-2018-soc/ips/jtag_pulp/src/tap_top.v,hackatdac18-2018-soc/rtl/pulpissimo/jtag_tap_top.sv||stable
h18_mux_func|hackatdac18|mux_func|nomap|nordff|300|hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/SubBytes.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/SubBytes_sbox.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/aes_1cc.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/keccak.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/md5.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/tempsen.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/KeyExpansion.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/AddRoundKey.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/ShiftRows.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/MixColumns.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/padder.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/f_permutation.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/padder1.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/rconst2in1.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/round2in1.v,hackatdac18-2018-soc/ips/hwpe-mac-engine/rtl/mux_func.sv||stable
h19_axi_address_decoder_ar|hackatdac19|axi_address_decoder_AR|nomap|nordff|180|design/src/axi_node/src/axi_address_decoder_AR.sv||stable
h19_axi_address_decoder_aw|hackatdac19|axi_address_decoder_AW|nomap|nordff|180|design/src/axi_node/src/axi_address_decoder_AW.sv||stable
h19_axi_address_decoder_br|hackatdac19|axi_address_decoder_BR|nomap|nordff|180|design/src/axi_node/src/axi_address_decoder_BR.sv||stable
h19_axi_address_decoder_bw|hackatdac19|axi_address_decoder_BW|nomap|nordff|180|design/src/axi_node/src/axi_address_decoder_BW.sv||stable
h21_sha256|hackatdac21|sha256|nordff|nordff|240|design/hackatdac21/piton/design/chip/tile/ariane/src/sha256/sha256.v,design/hackatdac21/piton/design/chip/tile/ariane/src/sha256/sha256_k_constants.v,design/hackatdac21/piton/design/chip/tile/ariane/src/sha256/sha256_w_mem.v||stable
h21_aes_192|hackatdac21|aes_192|nordff|nordff|360|design/hackatdac21/piton/design/chip/tile/ariane/src/aes0/aes_192.v,design/hackatdac21/piton/design/chip/tile/ariane/src/aes0/table.v,design/hackatdac21/piton/design/chip/tile/ariane/src/aes0/round.v||stable
h21_aes1_core|hackatdac21|aes1_core|nomap|nordff|360|design/hackatdac21/piton/design/chip/tile/ariane/src/aes1/aes1_core.v,design/hackatdac21/piton/design/chip/tile/ariane/src/aes1/aes1_encipher_block.v,design/hackatdac21/piton/design/chip/tile/ariane/src/aes1/aes1_decipher_block.v,design/hackatdac21/piton/design/chip/tile/ariane/src/aes1/aes1_key_mem.v,design/hackatdac21/piton/design/chip/tile/ariane/src/aes1/aes1_sbox.v,design/hackatdac21/piton/design/chip/tile/ariane/src/aes1/aes1_inv_sbox.v||stable
h21_rng_32|hackatdac21|rng_32|nomap|nordff|180|design/hackatdac21/piton/design/chip/tile/ariane/src/rand_num/rng_cs.v,design/hackatdac21/piton/design/chip/tile/ariane/src/rand_num/rng_16.v,design/hackatdac21/piton/design/chip/tile/ariane/src/rand_num/rng_32.v,design/hackatdac21/piton/design/chip/tile/ariane/src/rand_num/rng_64.v,design/hackatdac21/piton/design/chip/tile/ariane/src/rand_num/rng_128.v||stable
h18_adbg_tap_top|hackatdac18|adbg_tap_top|nomap|nordff|180|hackatdac18-2018-soc/ips/tech_cells_generic/cluster_clock_inverter.sv,hackatdac18-2018-soc/ips/tech_cells_generic/cluster_clock_mux2.sv,hackatdac18-2018-soc/ips/adv_dbg_if/rtl/adbg_tap_top.v|hackatdac18-2018-soc/ips/adv_dbg_if/rtl|extended
h19_axi_address_decoder_dw|hackatdac19|axi_address_decoder_DW|nomap|nordff|180|design/src/common_cells/src/fifo_v2.sv,design/src/axi_node/src/axi_address_decoder_DW.sv||extended
h21_rsa_top|hackatdac21|rsa_top|nordff|nordff|180|design/hackatdac21/piton/design/chip/tile/ariane/src/rsa/rsa_top.v,design/hackatdac21/piton/design/chip/tile/ariane/src/rsa/mod_exp.v,design/hackatdac21/piton/design/chip/tile/ariane/src/rsa/mod.v,design/hackatdac21/piton/design/chip/tile/ariane/src/rsa/inverter.v||extended
TARGET_LIST
)

print_usage() {
  cat <<'USAGE'
Usage:
  scripts/convert_cases_to_btor2_aiger.sh [options]

Options:
  --stable             Run only stable targets (default).
  --extended           Run stable + extended targets.
  --report <path>      Write TSV summary to this file.
  --timeout <seconds>  Override per-target timeout.
  --skip-existing      Skip a format run when output file already exists and is non-empty.
  --list-targets       Print target catalog and exit.
  -h, --help           Show this help.

Environment:
  YOSYS_BIN            Yosys executable (default: yosys)
  TIMEOUT_BIN          Timeout executable (default: timeout)
USAGE
}

list_targets() {
  printf "%-32s %-12s %-22s %-10s\n" "TARGET_ID" "BENCHMARK" "TOP" "TIER"
  printf "%-32s %-12s %-22s %-10s\n" "--------" "---------" "---" "----"
  while IFS='|' read -r id bench top _ _ _ _ _ tier; do
    [[ -z "$id" ]] && continue
    printf "%-32s %-12s %-22s %-10s\n" "$id" "$bench" "$top" "$tier"
  done <<< "$TARGETS"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stable)
      TARGET_MODE="stable"
      shift
      ;;
    --extended)
      TARGET_MODE="extended"
      shift
      ;;
    --report)
      REPORT_FILE="$2"
      shift 2
      ;;
    --timeout)
      TIMEOUT_OVERRIDE="$2"
      shift 2
      ;;
    --skip-existing)
      SKIP_EXISTING=1
      shift
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

HAS_TIMEOUT=1
if ! command -v "$TIMEOUT_BIN" >/dev/null 2>&1; then
  HAS_TIMEOUT=0
fi

mkdir -p "$(dirname "$REPORT_FILE")"
printf "target_id\tbenchmark\ttop\tformat\tstatus\toutput\tlog\tmessage\n" > "$REPORT_FILE"

pass_count=0
fail_count=0
skip_count=0
timeout_count=0

append_report_line() {
  local id="$1"
  local bench="$2"
  local top="$3"
  local format="$4"
  local status="$5"
  local output="$6"
  local log="$7"
  local message="$8"
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$id" "$bench" "$top" "$format" "$status" "$output" "$log" "$message" >> "$REPORT_FILE"
}

join_with_space() {
  local input_csv="$1"
  local joined=""
  local item
  IFS=',' read -r -a items <<< "$input_csv"
  for item in "${items[@]}"; do
    [[ -z "$item" ]] && continue
    if [[ -z "$joined" ]]; then
      joined="-I $item"
    else
      joined="$joined -I $item"
    fi
  done
  echo "$joined"
}

build_ys_script() {
  local bench_dir="$1"
  local ys_path="$2"
  local top="$3"
  local mem_mode="$4"
  local output_model_rel="$5"
  local source_csv="$6"
  local include_csv="$7"
  local format="$8"

  local include_flags
  include_flags="$(join_with_space "$include_csv")"

  {
    local src
    IFS=',' read -r -a srcs <<< "$source_csv"
    for src in "${srcs[@]}"; do
      [[ -z "$src" ]] && continue
      if [[ -n "$include_flags" ]]; then
        echo "read_verilog -formal -sv $include_flags $src"
      else
        echo "read_verilog -formal -sv $src"
      fi
    done

    echo "prep -top $top"
    echo "flatten"
    echo "memory -$mem_mode"
    echo "hierarchy -check"
    echo "setundef -undriven -init -expose"
    echo "async2sync"
    echo "dffunmap"

    if [[ "$format" == "aig" ]]; then
      echo "techmap"
      echo "abc -fast -g AND"
      echo "write_aiger -zinit $output_model_rel"
    else
      echo "write_btor -s $output_model_rel"
    fi
  } > "$ys_path"
}

check_inputs() {
  local bench_dir="$1"
  local source_csv="$2"
  local include_csv="$3"
  local missing=""

  local src
  IFS=',' read -r -a srcs <<< "$source_csv"
  for src in "${srcs[@]}"; do
    [[ -z "$src" ]] && continue
    if [[ ! -f "$bench_dir/$src" ]]; then
      missing="$missing missing_source:$src;"
    fi
  done

  local inc
  IFS=',' read -r -a incs <<< "$include_csv"
  for inc in "${incs[@]}"; do
    [[ -z "$inc" ]] && continue
    if [[ ! -d "$bench_dir/$inc" ]]; then
      missing="$missing missing_incdir:$inc;"
    fi
  done

  echo "$missing"
}

run_one_format() {
  local id="$1"
  local bench="$2"
  local top="$3"
  local source_csv="$4"
  local include_csv="$5"
  local timeout_sec="$6"
  local format="$7"
  local mem_mode="$8"

  local bench_dir="$ROOT_DIR/$bench"
  local out_dir="$bench_dir/yosys_out"
  mkdir -p "$out_dir"

  local extension
  if [[ "$format" == "aig" ]]; then
    extension="aig"
  else
    extension="btor2"
  fi

  local output_rel="yosys_out/${top}.${extension}"
  local log_rel="yosys_out/${id}_${format}.log"
  local ys_rel="yosys_out/${id}_${format}.ys"
  local output_abs="$bench_dir/$output_rel"
  local log_abs="$bench_dir/$log_rel"
  local ys_abs="$bench_dir/$ys_rel"

  if [[ "$SKIP_EXISTING" -eq 1 && -s "$output_abs" ]]; then
    append_report_line "$id" "$bench" "$top" "$format" "SKIPPED" "$bench/$output_rel" "$bench/$log_rel" "output exists"
    skip_count=$((skip_count + 1))
    return
  fi

  build_ys_script "$bench_dir" "$ys_abs" "$top" "$mem_mode" "$output_rel" "$source_csv" "$include_csv" "$format"

  local rc
  if [[ "$HAS_TIMEOUT" -eq 1 ]]; then
    (
      cd "$bench_dir" || exit 1
      "$TIMEOUT_BIN" "${timeout_sec}s" "$YOSYS_BIN" -q -s "$ys_rel" > "$log_rel" 2>&1
    )
    rc=$?
  else
    (
      cd "$bench_dir" || exit 1
      "$YOSYS_BIN" -q -s "$ys_rel" > "$log_rel" 2>&1
    )
    rc=$?
  fi

  if [[ "$rc" -eq 0 && -s "$output_abs" ]]; then
    append_report_line "$id" "$bench" "$top" "$format" "PASS" "$bench/$output_rel" "$bench/$log_rel" ""
    pass_count=$((pass_count + 1))
  elif [[ "$rc" -eq 124 ]]; then
    append_report_line "$id" "$bench" "$top" "$format" "TIMEOUT" "$bench/$output_rel" "$bench/$log_rel" "reached ${timeout_sec}s timeout"
    timeout_count=$((timeout_count + 1))
    fail_count=$((fail_count + 1))
  elif [[ "$rc" -eq 0 ]]; then
    append_report_line "$id" "$bench" "$top" "$format" "FAIL" "$bench/$output_rel" "$bench/$log_rel" "yosys returned 0 but output is empty"
    fail_count=$((fail_count + 1))
  else
    append_report_line "$id" "$bench" "$top" "$format" "FAIL" "$bench/$output_rel" "$bench/$log_rel" "yosys exit code $rc"
    fail_count=$((fail_count + 1))
  fi
}

echo "Using Yosys: $YOSYS_BIN"
echo "Target mode: $TARGET_MODE"
echo "Summary file: $REPORT_FILE"

while IFS='|' read -r id bench top btor_mem aig_mem target_timeout source_csv include_csv tier; do
  [[ -z "$id" ]] && continue

  if [[ "$TARGET_MODE" == "stable" && "$tier" != "stable" ]]; then
    continue
  fi

  local_timeout="$target_timeout"
  if [[ -n "$TIMEOUT_OVERRIDE" ]]; then
    local_timeout="$TIMEOUT_OVERRIDE"
  fi

  bench_dir="$ROOT_DIR/$bench"
  if [[ ! -d "$bench_dir" ]]; then
    append_report_line "$id" "$bench" "$top" "btor2" "FAIL" "$bench/yosys_out/${top}.btor2" "$bench/yosys_out/${id}_btor2.log" "benchmark directory missing"
    append_report_line "$id" "$bench" "$top" "aig" "FAIL" "$bench/yosys_out/${top}.aig" "$bench/yosys_out/${id}_aig.log" "benchmark directory missing"
    fail_count=$((fail_count + 2))
    continue
  fi

  missing_info="$(check_inputs "$bench_dir" "$source_csv" "$include_csv")"
  if [[ -n "$missing_info" ]]; then
    append_report_line "$id" "$bench" "$top" "btor2" "FAIL" "$bench/yosys_out/${top}.btor2" "$bench/yosys_out/${id}_btor2.log" "$missing_info"
    append_report_line "$id" "$bench" "$top" "aig" "FAIL" "$bench/yosys_out/${top}.aig" "$bench/yosys_out/${id}_aig.log" "$missing_info"
    fail_count=$((fail_count + 2))
    continue
  fi

  echo "Running target: $id (top=$top, benchmark=$bench)"
  run_one_format "$id" "$bench" "$top" "$source_csv" "$include_csv" "$local_timeout" "btor2" "$btor_mem"
  run_one_format "$id" "$bench" "$top" "$source_csv" "$include_csv" "$local_timeout" "aig" "$aig_mem"
done <<< "$TARGETS"

echo
printf "Completed. PASS=%d FAIL=%d TIMEOUT=%d SKIPPED=%d\n" "$pass_count" "$fail_count" "$timeout_count" "$skip_count"
echo "Summary written to: $REPORT_FILE"
