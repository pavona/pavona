#!/bin/bash

# ============================================
# DEFAULTS
# ============================================

DASHBOARD_BASE="./scratch/dashboard"
RUN_FLAG=""
ITEM_FLAG="all"
TOOL_FLAG="vcs"
PUBLISH_FLAG="false"

# ============================================
# ARGUMENT PARSING
# ============================================

usage() {
  echo "Usage: $0 [options] [output_dir]"
  echo ""
  echo "Options:"
  echo "  -r <N>           Set number of runs (e.g. -r 5)"
  echo "  -i <all|smoke>   Set test item flag (default: all)"
  echo "  -t <tool>        Set simulator tool (e.g. -t vcs)"
  echo "  -p <true|false>  Publish these results in the current server (port 8000) (default:false)"
  echo "  -h               Show this help"
  echo ""
  echo "Arguments:"
  echo "  output_dir     Output directory (default: ./scratch/dashboard)"
  exit 0
}

while getopts "r:i:t:p:h" opt; do
  case $opt in
  r) RUN_FLAG="-r $OPTARG" ;;
  i) ITEM_FLAG="$OPTARG" ;;
  t) TOOL_FLAG="$OPTARG" ;;
  p) PUBLISH_FLAG="$OPTARG" ;;
  h) usage ;;
  *)
    echo "Unknown option: $opt"
    usage
    ;;
  esac
done

# If the string for the output_dir argument is not empty
# use that for the output dir variable
shift $((OPTIND - 1))
if [ -n "$1" ]; then
  DASHBOARD_BASE="$1"
fi

# ============================================
# GIT BRANCH & SCRATCH BASE
# ============================================

GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -z "$GIT_BRANCH" ]; then
  echo "Error: could not determine git branch. Are you in a git repo?"
  exit 1
fi
SCRATCH_BASE="scratch/${GIT_BRANCH}"

# ============================================
# PURGE AND SETUP OUTPUT DIR
# ============================================

echo "Purging $DASHBOARD_BASE..."
rm -rf "$DASHBOARD_BASE"
mkdir "$DASHBOARD_BASE"

echo "Purging $SCRATCH_BASE..."
rm -rf "$SCRATCH_BASE"

LOG_FILE="${DASHBOARD_BASE}/dashboard.txt"
touch "$LOG_FILE"

log() {
  echo "$@" | tee -a "$LOG_FILE"
}

echo "============================================" | tee -a "$LOG_FILE"
echo "Configuration:" | tee -a "$LOG_FILE"
echo "  Output dir  : $DASHBOARD_BASE" | tee -a "$LOG_FILE"
echo "  Git branch  : $GIT_BRANCH" | tee -a "$LOG_FILE"
echo "  Scratch base: $SCRATCH_BASE" | tee -a "$LOG_FILE"
echo "  Runs        : ${RUN_FLAG:-(not set)}" | tee -a "$LOG_FILE"
echo "  Item        : $ITEM_FLAG" | tee -a "$LOG_FILE"
echo "  Tool        : ${TOOL_FLAG:-(not set)}" | tee -a "$LOG_FILE"
echo "  Publish     : ${PUBLISH_FLAG:-(not set)}" | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"
echo ""

WARNINGS=()

find_cov_report() {
  local sim_name=$1
  local top=$2
  if [ -d "${SCRATCH_BASE}/${sim_name}-sim-vcs/cov_report" ]; then
    echo "${SCRATCH_BASE}/${sim_name}-sim-vcs/cov_report"
  elif [ -d "${SCRATCH_BASE}/${sim_name}_${top}-sim-vcs/cov_report" ]; then
    echo "${SCRATCH_BASE}/${sim_name}_${top}-sim-vcs/cov_report"
  else
    echo ""
  fi
}

find_run_report() {
  local sim_name=$1
  local top=$2
  if [ -f "${SCRATCH_BASE}/${sim_name}-sim-vcs/reports/latest/report.html" ]; then
    echo "${SCRATCH_BASE}/${sim_name}-sim-vcs/reports/latest/report.html"
  elif [ -f "${SCRATCH_BASE}/${sim_name}_${top}-sim-vcs/reports/latest/report.html" ]; then
    echo "${SCRATCH_BASE}/${sim_name}_${top}-sim-vcs/reports/latest/report.html"
  else
    echo ""
  fi
}

# ============================================
# PHASE 1: COLLECT ALL CFG FILES
# ============================================

log "Collecting all sim cfg files..."

JOBS=()

# Pattern 1: hw/ip/{ip_name}/dv/{sim_cfg}
for cfg_file in hw/ip/*/dv/*_sim_cfg.hjson; do
  [ -f "$cfg_file" ] || continue
  sim_name=$(basename "$cfg_file" "_sim_cfg.hjson")
  [[ "$sim_name" == *base* ]] && continue
  ip_name=$(echo "$cfg_file" | cut -d'/' -f3)
  JOBS+=("${cfg_file}|${ip_name}|${sim_name}|ip|")
done

# Pattern 2: hw/ip/{ip_name}/dv/uvm/{sim_cfg}
for cfg_file in hw/ip/*/dv/uvm/*_sim_cfg.hjson; do
  [ -f "$cfg_file" ] || continue
  sim_name=$(basename "$cfg_file" "_sim_cfg.hjson")
  [[ "$sim_name" == *base* ]] && continue
  ip_name=$(echo "$cfg_file" | cut -d'/' -f3)
  JOBS+=("${cfg_file}|${ip_name}|${sim_name}|ip|")
done

# Pattern 3: hw/ip/prim/dv/{prim_variant}/{sim_cfg}
for cfg_file in hw/ip/prim/dv/*/*_sim_cfg.hjson; do
  [ -f "$cfg_file" ] || continue
  sim_name=$(basename "$cfg_file" "_sim_cfg.hjson")
  JOBS+=("${cfg_file}|prim|${sim_name}|ip|")
done

# Pattern 4: basically just tl_agent
for cfg_file in hw/dv/sv/*/*/*_sim_cfg.hjson; do
  [ -f "$cfg_file" ] || continue
  sim_name="tl_host_if"
  JOBS+=("${cfg_file}|tl_agent|${sim_name}|ip|")
done

for top in top_earlgrey top_darjeeling; do
  mkdir -p "${DASHBOARD_BASE}/${top}"

  # Pattern 5: hw/{top}/ip_autogen/{ip_name}/dv/{sim_cfg}
  for cfg_file in hw/${top}/ip_autogen/*/dv/*_sim_cfg.hjson; do
    [ -f "$cfg_file" ] || continue
    sim_name=$(basename "$cfg_file" "_sim_cfg.hjson")
    [[ "$sim_name" == *base* ]] && continue
    ip_name=$(echo "$cfg_file" | cut -d'/' -f4)
    JOBS+=("${cfg_file}|${ip_name}|${sim_name}|autogen|${top}")
  done

  # Pattern 6: hw/{top}/ip_autogen/{ip_name}/dv/*/{sim_cfg}
  for cfg_file in hw/${top}/ip_autogen/*/dv/*/*_sim_cfg.hjson; do
    [ -f "$cfg_file" ] || continue
    sim_name=$(basename "$cfg_file" "_sim_cfg.hjson")
    [[ "$sim_name" == *base* ]] && continue
    ip_name=$(echo "$cfg_file" | cut -d'/' -f4)
    JOBS+=("${cfg_file}|${ip_name}|${sim_name}|autogen|${top}")
  done

  # Pattern 7: hw/{top}/ip/{xbar_name}/dv/autogen/{sim_cfg}
  for cfg_file in hw/${top}/ip/*/dv/autogen/*_sim_cfg.hjson; do
    [ -f "$cfg_file" ] || continue
    sim_name=$(basename "$cfg_file" "_sim_cfg.hjson")
    ip_name=$(echo "$cfg_file" | cut -d'/' -f4)
    JOBS+=("${cfg_file}|${ip_name}|${sim_name}|autogen|${top}")
  done

  # Pattern 8: hw/{top}/dv/{sim_cfg} (chip-level)
  for cfg_file in hw/${top}/dv/*_sim_cfg.hjson; do
    [ -f "$cfg_file" ] || continue
    sim_name=$(basename "$cfg_file" "_sim_cfg.hjson")
    JOBS+=("${cfg_file}|${top}|${sim_name}|chip|${top}")
  done
done

log "Found ${#JOBS[@]} jobs:"
for job in "${JOBS[@]}"; do
  cfg_file=$(echo "$job" | cut -d'|' -f1)
  sim_name=$(echo "$job" | cut -d'|' -f3)
  type=$(echo "$job" | cut -d'|' -f4)
  top=$(echo "$job" | cut -d'|' -f5)
  log "  [${type}${top:+:$top}] $sim_name ($cfg_file)"
done

log ""
log "============================================"
log "Starting runs..."
log "============================================"

# ============================================
# PHASE 2: RUN ALL JOBS
# ============================================

DASHBOARD_IP="${DASHBOARD_BASE}/ip"
mkdir -p "$DASHBOARD_IP"

for job in "${JOBS[@]}"; do
  cfg_file=$(echo "$job" | cut -d'|' -f1)
  ip_name=$(echo "$job" | cut -d'|' -f2)
  sim_name=$(echo "$job" | cut -d'|' -f3)
  type=$(echo "$job" | cut -d'|' -f4)
  top=$(echo "$job" | cut -d'|' -f5)

  if [ "$type" = "ip" ]; then
    DASHBOARD_DEST="$DASHBOARD_IP"
  else
    DASHBOARD_DEST="${DASHBOARD_BASE}/${top}"
  fi

  if [ "$ITEM_FLAG" = "smoke" ]; then
    ITEM="-i smoke"
  else
    ITEM="-i all"
  fi

  if [ "$TOOL_FLAG" = "vcs" ]; then
    TOOL="-t vcs"
  elif [ "$TOOL_FLAG" = "xcelium" ]; then
    TOOL="-t xcelium"
  fi

  log ""
  log "============================================"
  log "Running [${type}${top:+:$top}] $sim_name"
  log "============================================"

  mkdir -p "$DASHBOARD_DEST"

  ./util/dvsim/dvsim.py "$cfg_file" \
    $RUN_FLAG \
    -v m \
    -ro +max_quit_count=40 \
    --build-opts '-kdb -debug_access+all+reverse' \
    --run-opts '+UVM_VERDI_TRACE=HIER +print_topology=1' \
    $ITEM \
    --cov \
    $TOOL 2>&1 | tee -a "$LOG_FILE"

  if [ "$type" = "chip" ]; then
    top_clean=${top#top_} # strip "top_" prefix
    COV_REPORT="${SCRATCH_BASE}/${sim_name}_${top_clean}_asic-sim-vcs/cov_report"
    RUN_REPORT="${SCRATCH_BASE}/${sim_name}_${top_clean}_asic-sim-vcs/reports/latest/report.html"
    DEST="${DASHBOARD_DEST}/${sim_name}_cov_report"
  else
    COV_REPORT=$(find_cov_report "$sim_name" "$top")
    RUN_REPORT=$(find_run_report "$sim_name" "$top")
    DEST="${DASHBOARD_DEST}/${ip_name}_cov_report/${sim_name}"
  fi

  mkdir -p "$DEST"

  if [ -n "$COV_REPORT" ] && [ -d "$COV_REPORT" ]; then
    log "Copying coverage report for $sim_name to $DEST"
    cp -r "$COV_REPORT/." "$DEST/"
  else
    WARNINGS+=("Warning: no cov_report found for $sim_name (scratch: $SCRATCH_BASE)")
    log "${WARNINGS[-1]}"
  fi

  if [ -n "$RUN_REPORT" ] && [ -f "$RUN_REPORT" ]; then
    log "Copying run report for $sim_name to $DEST/run_report.html"
    cp "$RUN_REPORT" "$DEST/run_report.html"
  else
    WARNINGS+=("Warning: no run report found for $sim_name (scratch: $SCRATCH_BASE)")
    log "${WARNINGS[-1]}"
  fi
done

# ============================================
# SUMMARY
# ============================================

log ""
log "All done."
log "  Log file               : $LOG_FILE"
log "  IP reports             : $DASHBOARD_IP"
log "  top_earlgrey reports   : ${DASHBOARD_BASE}/top_earlgrey"
log "  top_darjeeling reports : ${DASHBOARD_BASE}/top_darjeeling"

if [ ${#WARNINGS[@]} -gt 0 ]; then
  log ""
  log "============================================"
  log "WARNINGS SUMMARY (${#WARNINGS[@]} total):"
  log "============================================"
  for w in "${WARNINGS[@]}"; do
    log "  $w"
  done
fi

if [ "$PUBLISH_FLAG" = "true" ]; then
  log "Creating access to dashboard..."
  # Go to the dashboard directory
  cd "$DASHBOARD_BASE" || {
    echo "Cannot cd to $DASHBOARD_BASE"
    exit 1
  }
  # Start HTTP server
  echo "Serving $DASHBOARD_BASE on port 8000..."
  SERVER_NAME=$HOSTNAME

  # Find server name and output the address
  echo "Dashboard server: $SERVER_NAME"
  echo "Access from your browser at http://$SERVER_NAME:8000"

  # Continue like this
  nohup python3 -m http.server 8000 --bind 0.0.0.0 >/dev/null 2>&1 &
  echo "HTTP server running in background..."
fi
