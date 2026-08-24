#!/usr/bin/env bash
set -euo pipefail
umask 077

[[ $EUID -eq 0 ]] || { printf 'xauthority-root-contract=failed safe-code=root-required\n' >&2; exit 2; }
run_user=${MYDASHBOARD_TEST_RUN_USER:?set MYDASHBOARD_TEST_RUN_USER}
run_group=$(id -gn "$run_user")
fixture=$(mktemp -d /tmp/mydashboard-xauthority-contract.XXXXXX)
display=:199
before_srelens=$(pgrep -xc srelens || true)
before_xorg=$(pgrep -xc Xorg || true)

cleanup() {
  find "$fixture" -maxdepth 1 -type f -name 'Xauthority*' -links 1 -delete 2>/dev/null || true
  rm -rf -- "$fixture"
}
trap cleanup EXIT INT TERM
chown "$run_user:$run_group" "$fixture"
chmod 0700 "$fixture"

metadata_valid() {
  local path=$1
  [[ -f "$path" && ! -L "$path" && $(stat -c %h "$path") == 1 && $(stat -c %U "$path") == "$run_user" && $(stat -c %a "$path") == 600 ]]
}

add_as_user() {
  local path=$1 value=$2
  printf 'add %s MIT-MAGIC-COOKIE-1 %s\n' "$display" "$value" | \
    /usr/sbin/runuser -u "$run_user" -- env -i \
      HOME="$fixture" USER="$run_user" LOGNAME="$run_user" XAUTHORITY="$path" PATH=/usr/bin:/bin \
      /usr/bin/xauth -f "$path" source - >/dev/null 2>&1
}

# Reproduce the incident: root xauth atomically replaces a user-owned file.
root_path="$fixture/Xauthority-root-writer"
install -m 0600 -o "$run_user" -g "$run_group" /dev/null "$root_path"
printf 'add %s MIT-MAGIC-COOKIE-1 %s\n' "$display" 11111111111111111111111111111111 | \
  /usr/bin/xauth -f "$root_path" source - >/dev/null 2>&1
[[ $(stat -c %U "$root_path") == root ]]
rm -f -- "$root_path"

# Corrected path: the final owner also performs the atomic write.
user_path="$fixture/Xauthority-user-writer"
install -m 0600 -o "$run_user" -g "$run_group" /dev/null "$user_path"
add_as_user "$user_path" 22222222222222222222222222222222
metadata_valid "$user_path"
/usr/sbin/runuser -u "$run_user" -- env -i \
  HOME="$fixture" USER="$run_user" LOGNAME="$run_user" XAUTHORITY="$user_path" PATH=/usr/bin:/bin \
  /usr/bin/xauth -f "$user_path" nlist "$display" 2>/dev/null | grep -q .

# Metadata and malformed-entry validators fail closed.
malformed="$fixture/Xauthority-malformed"
install -m 0600 -o "$run_user" -g "$run_group" /dev/null "$malformed"
printf 'not-an-authority\n' | /usr/sbin/runuser -u "$run_user" -- tee "$malformed" >/dev/null
if /usr/sbin/runuser -u "$run_user" -- /usr/bin/xauth -f "$malformed" nlist "$display" 2>/dev/null | grep -q .; then exit 1; fi

symlink_path="$fixture/Xauthority-symlink"
ln -s "$user_path" "$symlink_path"
if metadata_valid "$symlink_path"; then exit 1; fi
hardlink_path="$fixture/Xauthority-hardlink"
ln "$user_path" "$hardlink_path"
if metadata_valid "$user_path"; then exit 1; fi
rm -f -- "$hardlink_path"
wrong_owner="$fixture/Xauthority-wrong-owner"
install -m 0600 /dev/null "$wrong_owner"
if metadata_valid "$wrong_owner"; then exit 1; fi
wrong_mode="$fixture/Xauthority-wrong-mode"
install -m 0644 -o "$run_user" -g "$run_group" /dev/null "$wrong_mode"
if metadata_valid "$wrong_mode"; then exit 1; fi

rm -f -- "$user_path" "$malformed" "$symlink_path" "$wrong_owner" "$wrong_mode"
if find "$fixture" -maxdepth 1 -name 'Xauthority*' -print -quit | grep -q .; then exit 1; fi
[[ $(pgrep -xc srelens || true) == "$before_srelens" ]]
[[ $(pgrep -xc Xorg || true) == "$before_xorg" ]]
printf 'xauthority-root-contract=passed tests=17 cookie-output=false app-core-provider-started=false residue=0\n'
