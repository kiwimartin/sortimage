# sort-media

Ein kleines Bash-Skript zum automatischen Sortieren von Bild-, RAW-, Adobe-/Affinity- und Videodateien
in Tagesordnern anhand des Erstellungsdatums.

## Verwendung

```bash
./sort-media.sh [OPTIONEN] [VERZEICHNIS]
```

- `VERZEICHNIS` ist optional. Wenn kein Pfad angegeben wird, wird das aktuelle Verzeichnis verwendet.
- Optionen:
  - `-h`, `--help`: Zeigt die Hilfe an.
  - `-n`, `--dry-run`: Nur anzeigen, welche Dateien verschoben werden würden.
  - `--self-check`: Prüft Laufzeitabhängigkeiten und zeigt den Status an, ohne Dateien zu verschieben.
- Hinweis: Läuft Bash unter Version 4.0 unterhalb, gibt das Script beim Start eine Kompatibilitätswarnung aus und nutzt Fallbacks für Kleinbuchstaben-Konvertierung.
- Kompatibilität: Das Skript läuft mit `bash` in Version 3+ sowie in `zsh` (auch bei Aufruf aus `zsh`-Shell).
- Dateien im Zielverzeichnis werden in Unterordner nach `YYYY-MM-DD` verschoben.
- Das Datum wird bevorzugt aus EXIF/Metadaten (`exiftool`) gelesen und bei Fehlschlag auf das
  Dateisystem-Datum (`mtime`) zurückgegriffen.

## Abhängigkeiten

- Pflicht: `bash`/`zsh`, `find`, `awk`, `tr`, `date`, `mv`, `mkdir`
- Optional: `exiftool` (verbessert die Datumsbestimmung)

```bash
./sort-media.sh --self-check
```

## Unterstützte Dateitypen

- RAW (Camera): `CR2`, `CR3`, `CRW`, `CRM`, `NRW`, `NEF`, `ARW`, `SR2`, `SRF`, `ARQ`,
  `ORF`, `ORI`, `RW2`, `RWZ`, `RWL`/`RWK` (Leica), `PEF`, `DNG`, `RAF`, `X3F`, `IIQ`, `MEF`,
  `MFW`, `MRW`, `MOS`, `R3D` (RED)
- Adobe/Affinity: `PSD`, `PSB`, `AI`, `EPS`, `INDD`, `AEP`, `XD`, `AFDESIGN`, `AFPHOTO`, `AFPUB`
- Raster/Bilder: `JPG`, `JPEG`, `PNG`, `GIF`, `BMP`, `TIFF`, `WEBP`, `HEIC`, `HEIF`, `JP2`, `AVIF`
- Video/Clips: `MOV`, `MP4`, `M4V`, `AVI`, `MKV`, `WEBM`, `MPG`, `MPEG`, `3GP`, `MTS`, `M2TS`, `M2T`

## Hinweis

- Probelauf (`-n` oder `--dry-run`):

```bash
./sort-media.sh --dry-run ./Fotos
```

Self-Check (`--self-check`):

```bash
./sort-media.sh --self-check ./Fotos
```

Dabei werden die geplanten Zielpfade ausgegeben, ohne Dateien zu verschieben.

## Installationshinweis

```bash
chmod +x sort-media.sh
./sort-media.sh
```
