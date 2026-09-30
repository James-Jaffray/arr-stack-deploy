#!/bin/sh
# Validate .env, check the host, create folders and fix ownership.
#
#   ./setup.sh           validate, then create folders and fix ownership
#   ./setup.sh --check   validate only, change nothing
#   ./setup.sh --up      do everything, then run `docker compose up -d`
#
# POSIX sh on purpose: DSM ships BusyBox, not bash. If the executable bit is lost
# (e.g. after copying from Windows) run it as `sh setup.sh`.
set -eu

# Git Bash on Windows rewrites arguments like /dev/net/tun into C:\... paths.
MSYS_NO_PATHCONV=1
export MSYS_NO_PATHCONV

cd "$(dirname "$0")"
ENV_FILE=.env
CR=$(printf '\r')

usage() {
  cat <<'EOF'
Usage: sh setup.sh [--check | --up]
  (none)   validate, then create folders and fix ownership
  --check  validate only, change nothing
  --up     do everything, then run `docker compose up -d`
Set SKIP_TUN_CHECK=1 to skip the tun device test.
EOF
}

MODE=setup
for arg in "$@"; do
  case $arg in
    --check) MODE=check ;;
    --up) MODE=up ;;
    -h | --help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

# ---------- output ----------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RED=$(printf '\033[31m'); C_GREEN=$(printf '\033[32m')
  C_YELLOW=$(printf '\033[33m'); C_BOLD=$(printf '\033[1m'); C_OFF=$(printf '\033[0m')
else
  C_RED=; C_GREEN=; C_YELLOW=; C_BOLD=; C_OFF=
fi
ERRORS=0
WARNINGS=0
ok()    { printf '%s[ ok ]%s %s\n' "$C_GREEN" "$C_OFF" "$*"; }
info()  { printf '       %s\n' "$*"; }
warn()  { WARNINGS=$((WARNINGS + 1)); printf '%s[warn]%s %s\n' "$C_YELLOW" "$C_OFF" "$*"; }
fail()  { ERRORS=$((ERRORS + 1)); printf '%s[FAIL]%s %s\n' "$C_RED" "$C_OFF" "$*"; }
head1() { printf '\n%s%s%s\n' "$C_BOLD" "$*" "$C_OFF"; }
# Hard failure for --up, warning otherwise.
soft() { if [ "$MODE" = up ]; then fail "$@"; else warn "$@"; fi; }

# ---------- .env parsing (never sourced) ----------
# Values are stored in variables named ENV_<KEY>; read them with val_of KEY.
val_of() { eval "printf '%s' \"\${ENV_$1:-}\""; }
val_or() { v=$(val_of "$1"); printf '%s' "${v:-$2}"; }

parse_env() {
  CRLF_FOUND=0
  while IFS= read -r line || [ -n "$line" ]; do
    case $line in
      *"$CR") CRLF_FOUND=1; line=${line%"$CR"} ;;
    esac
    line=${line#"${line%%[![:space:]]*}"}
    case $line in '' | '#'*) continue ;; esac
    case $line in
      'export '*) line=${line#export}; line=${line#"${line%%[![:space:]]*}"} ;;
    esac
    case $line in *=*) ;; *) continue ;; esac
    key=${line%%=*}
    key=${key%"${key##*[![:space:]]}"}
    case $key in '' | [0-9]* | *[!A-Za-z0-9_]*) continue ;; esac
    val=${line#*=}
    val=${val#"${val%%[![:space:]]*}"}
    case $val in
      '"'*) val=${val#\"}; val=${val%%\"*} ;;
      "'"*) val=${val#\'}; val=${val%%\'*} ;;
      '#'*) val= ;;
      *) val=${val%%[[:space:]]#*}; val=${val%"${val##*[![:space:]]}"} ;;
    esac
    eval "ENV_$key=\$val"
  done < "$ENV_FILE"
}

is_int() { case $1 in '' | *[!0-9]*) return 1 ;; esac; return 0; }

is_cidr() {
  case $1 in */*) ;; *) return 1 ;; esac
  ip=${1%/*}
  mask=${1#*/}
  case $ip in '' | *[!0-9.]*) return 1 ;; esac
  is_int "$mask" || return 1
  [ "$mask" -le 32 ] || return 1
  old_ifs=$IFS
  IFS=.
  set -f
  # shellcheck disable=SC2086 # intentional split on dots; $ip is digits and dots only
  set -- $ip
  set +f
  IFS=$old_ifs
  [ $# -eq 4 ] || return 1
  for octet in "$@"; do
    is_int "$octet" || return 1
    [ "$octet" -le 255 ] || return 1
  done
  return 0
}

# Flag a required variable that is empty or still a placeholder. Names only, never values.
need() {
  v=$(val_of "$1")
  case $v in
    '') fail "$1 is empty" ;;
    *CHANGE_ME*) fail "$1 is still CHANGE_ME" ;;
  esac
}

# ---------- filesystem helpers ----------
devid()    { stat -c %d "$1" 2>/dev/null || stat -f %d "$1" 2>/dev/null || true; }
owner_of() { stat -c '%u:%g' "$1" 2>/dev/null || stat -f '%u:%g' "$1" 2>/dev/null || true; }
perm_of()  { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1" 2>/dev/null || true; }
abspath()  { (cd "$1" 2>/dev/null && pwd) || printf '%s' "$1"; }

# Windows drives (Git Bash, or WSL under /mnt/x) cannot hold Linux ownership or reliable hardlinks.
on_windows_fs() {
  case $(uname -s 2>/dev/null) in MINGW* | MSYS* | CYGWIN*) return 0 ;; esac
  case $(abspath "$1") in /mnt/[a-zA-Z]/*) return 0 ;; esac
  return 1
}

# ======================================================================
head1 "Reading $ENV_FILE"
if [ ! -f "$ENV_FILE" ]; then
  fail "$ENV_FILE not found. Create it with:  cp .env.example .env   then fill it in."
  exit 1
fi
parse_env

if [ "$CRLF_FOUND" = 1 ]; then
  warn "$ENV_FILE has Windows (CRLF) line endings. Values were read correctly here, but Docker Compose can choke on them."
  fixed=0
  if [ "$MODE" != check ] && [ -t 0 ]; then
    printf '       Convert %s to LF now? [y/N] ' "$ENV_FILE"
    read -r answer || answer=n
    case $answer in
      y | Y | yes)
        tr -d '\r' < "$ENV_FILE" > "$ENV_FILE.tmp" && cat "$ENV_FILE.tmp" > "$ENV_FILE" && rm -f "$ENV_FILE.tmp"
        ok "Converted $ENV_FILE to LF"
        fixed=1 ;;
    esac
  fi
  if [ "$fixed" = 0 ]; then
    info "Fix it with:  tr -d '\\r' < .env > .env.tmp && cat .env.tmp > .env && rm .env.tmp"
  fi
else
  ok "$ENV_FILE parsed (LF line endings)"
fi

head1 "Validating variables"
for name in PUID PGID TZ DATA_DIR LAN_SUBNET VPN_PROVIDER VPN_TYPE; do
  need "$name"
done
case $(val_of VPN_TYPE) in
  wireguard) need WIREGUARD_PRIVATE_KEY; need WIREGUARD_ADDRESSES ;;
  openvpn) need OPENVPN_USER; need OPENVPN_PASSWORD ;;
  '' | *CHANGE_ME*) ;;
  *) fail "VPN_TYPE must be wireguard or openvpn" ;;
esac
v=$(val_of PUID)
if [ -n "$v" ] && ! is_int "$v"; then fail "PUID must be a whole number"; fi
v=$(val_of PGID)
if [ -n "$v" ] && ! is_int "$v"; then fail "PGID must be a whole number"; fi
v=$(val_of LAN_SUBNET)
case $v in
  '' | *CHANGE_ME*) ;;
  *) is_cidr "$v" || fail "LAN_SUBNET must look like 192.168.1.0/24" ;;
esac
for name in QBIT_PORT PROWLARR_PORT SONARR_PORT RADARR_PORT; do
  v=$(val_of "$name")
  if [ -n "$v" ]; then
    if ! is_int "$v" || [ "$v" -lt 1 ] || [ "$v" -gt 65535 ]; then fail "$name must be a port number (1-65535)"; fi
  fi
done
if [ "$ERRORS" -eq 0 ]; then ok "All required variables are set"; fi

PUID=$(val_of PUID); PGID=$(val_of PGID)
CONFIG_DIR=$(val_or CONFIG_DIR ./config)
DATA_DIR=$(val_of DATA_DIR)
QBIT_PORT=$(val_or QBIT_PORT 8080)
PROWLARR_PORT=$(val_or PROWLARR_PORT 9696)
SONARR_PORT=$(val_or SONARR_PORT 8989)
RADARR_PORT=$(val_or RADARR_PORT 7878)

head1 "Checking the host"
DOCKER_OK=0
if ! command -v docker >/dev/null 2>&1; then
  soft "docker not found. Install Docker Desktop (Windows) or Container Manager (Synology)."
elif ! dv=$(docker --version 2>&1); then
  soft "docker did not run: $dv"
else
  ok "$dv"
  if cv=$(docker compose version 2>&1); then
    ok "$cv"
    if dinfo=$(docker info 2>&1 >/dev/null); then
      DOCKER_OK=1
    else
      case $dinfo in
        *ermission*) soft "Cannot talk to the Docker daemon (permission denied). On Synology re-run with sudo." ;;
        *) soft "Cannot talk to the Docker daemon. Is Docker running?" ;;
      esac
    fi
  else
    soft "docker compose not available: $cv"
  fi
fi

# Test the tun device the way Docker sees it: on Docker Desktop it lives in Docker's VM,
# on Synology on the host.
if [ "${SKIP_TUN_CHECK:-}" = 1 ] || [ "$(val_of SKIP_TUN_CHECK)" = 1 ]; then
  info "tun check skipped (SKIP_TUN_CHECK=1)"
elif [ "$DOCKER_OK" = 1 ] && docker run --rm --device /dev/net/tun alpine true >/dev/null 2>&1; then
  ok "Docker can use /dev/net/tun"
else
  if [ "$DOCKER_OK" = 0 ]; then
    soft "Could not test the tun device because Docker is not usable."
  elif [ -c /dev/net/tun ]; then
    soft "/dev/net/tun exists here, but a test container could not use it (or the test image could not be pulled)."
  else
    soft "No usable /dev/net/tun; Gluetun cannot start without it."
  fi
  info "Synology: Control Panel > Task Scheduler > Triggered Task > Boot-up (root), script = scripts/synology-tun-boot.sh"
  info "Linux:    sudo modprobe tun"
  info "Docker Desktop: restart Docker Desktop and confirm the WSL2 backend is enabled"
fi

# Port check. Existing containers of this stack will show as "in use" on a re-run.
port_in_use() {
  if command -v ss >/dev/null 2>&1; then
    ss -ltn 2>/dev/null | grep -E "[:.]$1[[:space:]]" >/dev/null
  elif command -v netstat >/dev/null 2>&1; then
    netstat -an 2>/dev/null | grep -i LISTEN | grep -E "[:.]$1[[:space:]]" >/dev/null
  else
    return 2
  fi
}
IN_WSL=0
if grep -qi microsoft /proc/version 2>/dev/null; then IN_WSL=1; fi
port_note=
if [ "$IN_WSL" = 1 ]; then
  port_note=" (WSL's view only; Docker Desktop will report a real conflict when the container starts)"
fi
if ! command -v ss >/dev/null 2>&1 && ! command -v netstat >/dev/null 2>&1; then
  warn "Neither ss nor netstat found; skipping the port check."
else
  busy=0
  for p in "$QBIT_PORT" "$PROWLARR_PORT" "$SONARR_PORT" "$RADARR_PORT"; do
    if port_in_use "$p"; then
      warn "Port $p is already in use$port_note. Expected if this stack is already running."
      busy=1
    fi
  done
  if [ "$busy" = 0 ]; then ok "Ports $QBIT_PORT, $PROWLARR_PORT, $SONARR_PORT, $RADARR_PORT are free$port_note"; fi
fi

# File permissions on .env are meaningless on a Windows drive.
if on_windows_fs "$ENV_FILE"; then
  info ".env permission check skipped (Windows drive)"
else
  perm=$(perm_of "$ENV_FILE")
  if [ -n "$perm" ] && [ "$perm" != 600 ] && [ "$perm" != 400 ]; then
    if [ "$MODE" = check ]; then
      warn ".env permissions are $perm (holds secrets). Run:  chmod 600 .env"
    else
      chmod 600 "$ENV_FILE" && ok ".env permissions tightened from $perm to 600"
    fi
  else
    ok ".env permissions are fine"
  fi
fi

# ---------- stop here if validation failed ----------
if [ "$ERRORS" -gt 0 ]; then
  printf '\n%s%s problem(s) found. Fix them in %s and re-run.%s\n' "$C_RED" "$ERRORS" "$ENV_FILE" "$C_OFF"
  exit 1
fi

# ---------- folders ----------
CONFIG_DIRS="$CONFIG_DIR/gluetun $CONFIG_DIR/qbittorrent $CONFIG_DIR/prowlarr $CONFIG_DIR/sonarr $CONFIG_DIR/radarr"
DATA_DIRS="$DATA_DIR/torrents/movies $DATA_DIR/torrents/tv $DATA_DIR/media/movies $DATA_DIR/media/tv"

head1 "Folders"
if [ "$MODE" = check ]; then
  for d in $CONFIG_DIRS $DATA_DIRS; do
    if [ -d "$d" ]; then info "exists   $d"; else info "would create $d"; fi
  done
else
  created=0
  for d in $CONFIG_DIRS $DATA_DIRS; do
    if [ ! -d "$d" ]; then
      mkdir -p "$d"
      created=$((created + 1))
    fi
  done
  ok "Folders ready ($created created)"

  if on_windows_fs "$DATA_DIR" || on_windows_fs "$CONFIG_DIR"; then
    info "Ownership step skipped: folders are on a Windows drive, where chown does nothing."
  else
    # Only recurse when a top-level folder has the wrong owner; keeps re-runs quick and
    # avoids re-walking a large existing library.
    want="$PUID:$PGID"
    for top in "$CONFIG_DIR" "$DATA_DIR/torrents" "$DATA_DIR/media"; do
      have=$(owner_of "$top")
      if [ "$have" = "$want" ]; then
        continue
      fi
      if [ "$(id -u)" = 0 ]; then
        chown -R "$want" "$top" && ok "Ownership of $top set to $want"
      else
        warn "$top is owned by ${have:-unknown}, apps run as $want. Run:  sudo chown -R $want \"$top\""
      fi
    done
  fi

  head1 "Hardlink check"
  dev_t=$(devid "$DATA_DIR/torrents")
  dev_m=$(devid "$DATA_DIR/media")
  if [ -n "$dev_t" ] && [ "$dev_t" != "$dev_m" ]; then
    warn "torrents/ and media/ are on DIFFERENT filesystems. Hardlinks will silently become copies (double disk use). Use one shared folder on one volume."
  elif [ -n "$dev_t" ]; then
    ok "torrents/ and media/ share a filesystem"
  else
    warn "Could not compare filesystems (stat unavailable)."
  fi
  if on_windows_fs "$DATA_DIR"; then
    warn "DATA_DIR is on a Windows drive: hardlinks may not work here. Not representative of the NAS."
  fi
fi

# ---------- summary ----------
head1 "Next steps"
if [ "$WARNINGS" -gt 0 ]; then info "$WARNINGS warning(s) above; read them before starting."; fi
info "Start:    docker compose up -d        (add --profile tunnel for Cloudflare)"
info "Verify:   sh scripts/verify.sh"
info "qBittorrent  http://localhost:$QBIT_PORT"
info "Prowlarr     http://localhost:$PROWLARR_PORT"
info "Sonarr       http://localhost:$SONARR_PORT"
info "Radarr       http://localhost:$RADARR_PORT"
info "Then follow the 'First-run wiring' section of README.md."

if [ "$MODE" = up ]; then
  head1 "Starting the stack"
  docker compose up -d
fi
