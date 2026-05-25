#!/usr/bin/env bash
set -euo pipefail

# Sort media files by date into folders named YYYY-MM-DD.
TARGET_DIR="."
DRY_RUN="${DRY_RUN:-0}"
TARGET_DIR_SET=0

show_help() {
  cat <<'EOF'
Verwendung: sort-media.sh [OPTIONEN] [VERZEICHNIS]

Sortiert unterstützte Mediendateien im angegebenen Verzeichnis in Ordner nach Datum.
Standard ist das aktuelle Verzeichnis.

Optionen:
  -h, --help      Diese Hilfe anzeigen.
  -n, --dry-run    Nur anzeigen, welche Dateien verschoben würden.

Beispiel:
  ./sort-media.sh ./Fotos
  DRY_RUN=1 ./sort-media.sh --dry-run ./Fotos
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -n|--dry-run)
      DRY_RUN=1
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Unbekannte Option: $1" >&2
      show_help
      exit 1
      ;;
    *)
      if (( TARGET_DIR_SET )); then
        echo "Zu viele Argumente: $1" >&2
        show_help >&2
        exit 1
      fi
      TARGET_DIR="$1"
      TARGET_DIR_SET=1
      shift
      ;;
  esac
done

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Fehler: '$TARGET_DIR' ist kein Verzeichnis." >&2
  exit 1
fi

declare -A SUPPORTED_EXTENSIONS=()

SUPPORTED_TYPES=(
  # RAW: Canon
  cr2 cr3 crw crm
  # RAW: Nikon
  nef nrw
  # RAW: Sony
  arw sr2 srf arq
  # RAW: Olympus
  orf ori
  # RAW: Panasonic
  rw2 rwz
  # RAW: Pentax
  pef dng
  # RAW: Fujifilm
  raf
  # RAW: Sigma / Others
  x3f iiq mef mfw mrw mos
  # RAW: Leica
  rwl rwk
  # RAW: RED
  r3d
  # Adobe / Affinity
  psd psb ai eps indd aep xd afdesign afphoto afpub
  # Raster / Photos
  jpg jpeg jpe jfif jif png gif bmp tif tiff webp heic heif jp2 avif
  # Motion / Clips
  mov mp4 m4v avi mkv webm mpg mpeg 3gp mts m2ts m2t
)

for ext in "${SUPPORTED_TYPES[@]}"; do
  SUPPORTED_EXTENSIONS[${ext,,}]=1
done

get_file_date() {
  local file="$1"
  local d=""

  if command -v exiftool >/dev/null 2>&1; then
    d=$(exiftool -s3 -d "%Y-%m-%d" \
      -DateTimeOriginal -CreateDate -ModifyDate -MediaCreateDate "$file" 2>/dev/null \
      | awk 'NF && $1 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ { print $1; exit }')
  fi

  if [[ ! "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    d=$(date -r "$file" +%Y-%m-%d)
  fi

  echo "$d"
}

mv_with_target() {
  local file="$1"
  local day
  local target

  day=$(get_file_date "$file")
  target="$TARGET_DIR/$day"
  mkdir -p "$target"

  if (( DRY_RUN )); then
    printf "Würde verschieben: %s -> %s/\n" "$(basename "$file")" "$day"
    return
  fi

  # keep existing target names unique when duplicates exist
  if [[ -e "$target/$(basename "$file")" ]]; then
    local stem ext
    stem=${file##*/}
    ext=${stem##*.}
    stem=${stem%.*}
    mv -- "$file" "$target/${stem}-$(date +%s%N).${ext,,}"
  else
    mv -- "$file" "$target/"
  fi
}

while IFS= read -r -d '' file; do
  name="${file##*/}"
  base="${name%.*}"
  ext="${name##*.}"

  if [[ "$base" == "$name" ]]; then
    continue
  fi

  ext="${ext,,}"
  if [[ -n "${SUPPORTED_EXTENSIONS[$ext]+x}" ]]; then
    mv_with_target "$file"
  fi
done < <(find "$TARGET_DIR" -maxdepth 1 -type f -print0)

echo "Fertig: Medien wurden nach Tagesordnern sortiert."
