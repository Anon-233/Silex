#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: version-compare.sh <left> <right>" >&2
  exit 64
fi

validate_version() {
  case "$1" in
    ""|*[!0-9.]*|.*|*..*|*.)
      echo "versions must contain only dotted numeric components" >&2
      exit 64
      ;;
  esac
}

validate_version "$1"
validate_version "$2"

/usr/bin/awk -v left_version="$1" -v right_version="$2" '
BEGIN {
  left_count = split(left_version, left, ".")
  right_count = split(right_version, right, ".")
  count = left_count > right_count ? left_count : right_count

  for (component = 1; component <= count; component++) {
    left_value = left[component] + 0
    right_value = right[component] + 0
    if (left_value < right_value) {
      print -1
      exit
    }
    if (left_value > right_value) {
      print 1
      exit
    }
  }

  print 0
}
'
