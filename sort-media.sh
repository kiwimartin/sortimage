#!/usr/bin/env bash
set -eu

# Sort media files by date into folders named YYYY-MM-DD.
TARGET_DIR="."
DRY_RUN="${DRY_RUN:-0}"
SELF_CHECK=0
TARGET_DIR_SET=0

warn_legacy_bash() {
  if [ -z "${BASH_VERSION-}" ]; then
    return
  fi

  if (( ${BASH_VERSINFO[0]} < 4 )); then
    echo "Warnung: Bash ${BASH_VERSION} (< 4.0) erkannt. Das Skript nutzt kompatible Fallbacks für Kleinbuchstaben-Konvertierung." >&2
  fi
}

to_lower() {
  local value="$1"
  echo "$value" | tr '[:upper:]' '[:lower:]'
}

show_help() {
  cat <<'EOF'
Verwendung: sort-media.sh [OPTIONEN] [VERZEICHNIS]

Sortiert unterstützte Mediendateien im angegebenen Verzeichnis in Ordner nach Datum.
Standard ist das aktuelle Verzeichnis.

Optionen:
  -h, --help      Diese Hilfe anzeigen.
  -n, --dry-run    Nur anzeigen, welche Dateien verschoben würden.
  --self-check     Prüft Abhängigkeiten und Umgebungsbedingungen ohne Dateien zu verschieben.

Beispiel:
  ./sort-media.sh ./Fotos
  DRY_RUN=1 ./sort-media.sh --dry-run ./Fotos
  ./sort-media.sh --self-check ./Fotos
EOF
}

check_dependency() {
  local name=$1
  if command -v "$name" >/dev/null 2>&1; then
    printf "  ok   %s\n" "$name"
    return 0
  fi

  printf "  fehlt %s\n" "$name"
  return 1
}

self_check() {
  local has_errors=0
  local shell_name="unbekannt"

  if [ -n "${BASH_VERSION-}" ]; then
    shell_name="bash ${BASH_VERSION}"
  elif [ -n "${ZSH_VERSION-}" ]; then
    shell_name="zsh ${ZSH_VERSION}"
  elif [ -n "${SHELL-}" ]; then
    shell_name="${SHELL##*/}"
  fi

  echo "Self-Check: sort-media.sh"
  echo "Shell        : $shell_name"
  echo "Zielpfad     : $TARGET_DIR"

  echo "Pflicht-Abhängigkeiten:"
  check_dependency find || has_errors=1
  check_dependency awk || has_errors=1
  check_dependency tr || has_errors=1
  check_dependency date || has_errors=1
  check_dependency mv || has_errors=1
  check_dependency mkdir || has_errors=1

  echo "Optionale Abhängigkeit:"
  if check_dependency exiftool; then
    echo "  Hinweis: exiftool gefunden, EXIF-Daten werden bevorzugt verwendet."
  else
    echo "  Hinweis: exiftool nicht gefunden, Fallback auf Dateisystem-Datum."
  fi

  if [ -d "$TARGET_DIR" ] && [ -w "$TARGET_DIR" ]; then
    echo "Zielverzeichnis erreichbar und beschreibbar."
  else
    echo "Fehler: Zielverzeichnis nicht schreibbar: $TARGET_DIR"
    has_errors=1
  fi

  if (( has_errors )); then
    echo "Self-Check: Fehler gefunden."
    exit 1
  fi

  echo "Self-Check: OK"
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
    --self-check)
      SELF_CHECK=1
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

warn_legacy_bash

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Fehler: '$TARGET_DIR' ist kein Verzeichnis." >&2
  exit 1
fi

if (( SELF_CHECK )); then
  self_check
  exit 0
fi

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

is_supported_ext() {
  local ext="$1"
  local candidate

  for candidate in "${SUPPORTED_TYPES[@]}"; do
    if [[ "$candidate" == "$ext" ]]; then
      return 0
    fi
  done
  return 1
}

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
    ext="$(to_lower "${stem##*.}")"
    stem=${stem%.*}
    mv -- "$file" "$target/${stem}-$(date +%s).$ext"
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

  ext="$(to_lower "$ext")"
  if is_supported_ext "$ext"; then
    mv_with_target "$file"
  fi
done < <(find "$TARGET_DIR" -maxdepth 1 -type f -print0)

echo "Fertig: Medien wurden nach Tagesordnern sortiert."
