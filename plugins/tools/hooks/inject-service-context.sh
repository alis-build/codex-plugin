#!/usr/bin/env bash
# SessionStart hook: when a session opens inside an Alis Build workspace
# (~/alis.build/<org>/{build,define}/...), inject a short pointer to the
# service's counterpart half — definitions (protobuf API contract) when on the
# build side, implementation when on the define side — plus the package id.
#
# Layout (verified): build  = <root>/alis.build/<org>/build/<path...>
#                     define = <root>/alis.build/<org>/define/<org>/<path...>
# Package id          = <org>.<path-with-/-as-.>   (e.g. alis.os.cli.v1)
#
# Whatever this script prints to stdout is added to the session context, exactly
# like load-primer.sh. Any non-match emits nothing and exits 0 so the session
# proceeds unmodified (graceful degradation, like the sibling hooks). Codex sets
# PLUGIN_ROOT for plugin-bundled hooks; the working directory is read from
# CODEX_PROJECT_DIR when set, falling back to the hook's $PWD.
set -euo pipefail

dir="${CODEX_PROJECT_DIR:-$PWD}"
case "$dir" in */alis.build/*) ;; *) exit 0 ;; esac

root="${dir%%/alis.build/*}/alis.build"
rest="${dir#*/alis.build/}"

IFS='/' read -ra parts <<< "$rest"
org="${parts[0]:-}"; side="${parts[1]:-}"
[ -n "$org" ] && [ -n "$side" ] || exit 0

# Path segments below the side (and below the nested <org> on the define side).
segs=()
case "$side" in
  build)  segs=("${parts[@]:2}") ;;
  define) [ "${parts[2]:-}" = "$org" ] || exit 0   # skip vendored google/lf symlinks
          segs=("${parts[@]:3}") ;;
  *)      exit 0 ;;
esac

# Resolve up to the service version (vN) root; drop empty segments.
# The ${arr[@]+"${arr[@]}"} form expands to nothing for an empty array, which
# bash 3.2 (macOS) otherwise rejects under `set -u`.
svc=(); found_version=0
for s in ${segs[@]+"${segs[@]}"}; do
  [ -n "$s" ] || continue
  svc+=("$s")
  if [[ "$s" =~ ^v[0-9]+$ ]]; then found_version=1; break; fi
done
[ "${#svc[@]}" -gt 0 ] || exit 0   # at org/side root → nothing specific to say

join() { local IFS="$1"; shift; printf '%s' "$*"; }
relpath="$(join / "${svc[@]}")"
definedir="$root/$org/define/$org/$relpath"
builddir="$root/$org/build/$relpath"
pkg=""; [ "$found_version" -eq 1 ] && pkg="$org.$(join . "${svc[@]}")"

emit_protos() {  # list top-level *.proto basenames in $1, if any
  local d="$1" f names=() out
  for f in "$d"/*.proto; do [ -e "$f" ] && names+=("$(basename "$f")"); done
  if [ "${#names[@]}" -gt 0 ]; then
    printf -v out '%s, ' "${names[@]}"
    printf '  Proto files: %s\n' "${out%, }"
  fi
  return 0
}

if [ "$side" = "build" ]; then
  printf 'This Codex session is inside an Alis Build service implementation (build) directory.\n'
  [ -n "$pkg" ] && printf '  Package id:  %s\n' "$pkg"
  if [ -d "$definedir" ]; then
    printf '  The protobuf definitions (the API contract — the DBD "Define" step) are available here:\n    %s\n' "$definedir"
    emit_protos "$definedir"
  else
    printf '  Expected definitions at %s (not found on disk).\n' "$definedir"
  fi
else  # define side
  printf 'This Codex session is inside an Alis Build definitions (define) directory — the protobuf API contract.\n'
  [ -n "$pkg" ] && printf '  Package id:  %s\n' "$pkg"
  emit_protos "$dir"
  if [ -d "$builddir" ]; then
    printf '  The implementation (the DBD "Build" step) is available here:\n    %s\n' "$builddir"
  else
    printf '  This contract has no corresponding build/ implementation directory yet.\n'
  fi
fi
exit 0
