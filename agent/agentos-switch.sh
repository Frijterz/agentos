# agentos-switch <build-hash>|rollback: apply a system build. Runs as root, ONLY as the
# agentos-switch@<arg> service (modules/nixos/agent.nix), which polkit lets you start
# after typing your password. It takes no path from outside: the 32-character store
# hash must name an existing nixos-system-$AGENTOS_HOST build; "rollback" picks the
# previous generation itself.

arg="${1:?usage: agentos-switch <build-hash>|rollback}"
host="${AGENTOS_HOST:?AGENTOS_HOST not set}"
profile=/nix/var/nix/profiles/system

fail() {
  echo "agentos-switch: $*" >&2
  exit 1
}

if [ "$arg" = rollback ]; then
  current="$(readlink "$profile")" # system-N-link
  n="${current#system-}"
  n="${n%-link}"
  prev="$(find /nix/var/nix/profiles -maxdepth 1 -name 'system-*-link' -printf '%f\n' |
    sed -n 's/^system-\([0-9]*\)-link$/\1/p' | sort -n | awk -v n="$n" '$1 < n' | tail -n 1)"
  [ -n "$prev" ] || fail "no older generation to roll back to"
  target="$(readlink -f "$profile-$prev-link")"
else
  [[ "$arg" =~ ^[0-9a-z]{32}$ ]] || fail "not a store hash: $arg"
  shopt -s nullglob
  matches=(/nix/store/"$arg"-nixos-system-"$host"-*)
  [ "${#matches[@]}" -eq 1 ] || fail "no nixos-system-$host build with hash $arg"
  target="${matches[0]}"
fi

# A real, registered system build, not just a directory that looks like one.
nix-store --query --hash "$target" >/dev/null || fail "not a valid store path: $target"
[ -x "$target/bin/switch-to-configuration" ] || fail "not a NixOS system: $target"

# /home snapshot first, through snapper (modules/nixos/snapshots.nix) so it shows in
# `snapper -c home list`; its "number" cleanup keeps the newest few.
snapper -c home create --cleanup-algorithm number --description "agentos: before applying $arg"
# Snapshots from before we used snapper sat in snapper's folder; remove them once.
find /home/.snapshots -maxdepth 1 -name 'agentos-*' -printf '%p\n' |
  while read -r old; do btrfs subvolume delete "$old" >/dev/null; done

echo "agentos-switch: applying $target"
if [ "$arg" = rollback ]; then
  nix-env --profile "$profile" --rollback
else
  nix-env --profile "$profile" --set "$target"
fi
exec "$target/bin/switch-to-configuration" switch
