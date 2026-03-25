#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  Instalador SIPAM  — idempotente
#  Cada paso verifica si ya está hecho antes de ejecutarse.
#  Compatible con Apple Silicon e Intel.
# ─────────────────────────────────────────────────────────────

SIPAM_APP="$HOME/Applications/SIPAM.app"
SIPAM_JSON="$HOME/Library/Application Support/iTerm2/DynamicProfiles/SIPAM.json"

# ── 1. Homebrew ───────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  echo "⬇️  Instalando Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  [ -f /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
  [ -f /usr/local/bin/brew ]    && eval "$(/usr/local/bin/brew shellenv)"
else
  echo "✅ Homebrew ya instalado — omitiendo"
  eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null \
    || eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null
fi

# ── 2. Telnet ─────────────────────────────────────────────────
if ! command -v telnet &>/dev/null; then
  echo "⬇️  Instalando telnet..."
  brew install telnet
else
  echo "✅ Telnet ya instalado — omitiendo"
fi

# ── 3. Perfil iTerm2 ──────────────────────────────────────────
# Siempre se sobreescribe para mantener el perfil actualizado;
# es una operación inocua si ya existía.
echo "⚙️  Configurando perfil SIPAM en iTerm2..."
mkdir -p "$HOME/Library/Application Support/iTerm2/DynamicProfiles"

TELNET_PATH=$(command -v telnet 2>/dev/null)
[ -z "$TELNET_PATH" ] && [ -f /opt/homebrew/bin/telnet ] && TELNET_PATH="/opt/homebrew/bin/telnet"
[ -z "$TELNET_PATH" ] && [ -f /usr/local/bin/telnet ]    && TELNET_PATH="/usr/local/bin/telnet"
echo "   Usando telnet en: $TELNET_PATH"

python3 - "$TELNET_PATH" "$SIPAM_JSON" <<'PYEOF'
import json, os, sys

esc         = "\u001b"
telnet_path = sys.argv[1] if len(sys.argv) > 1 else "telnet"
out_path    = sys.argv[2] if len(sys.argv) > 2 else \
    os.path.expanduser("~/Library/Application Support/iTerm2/DynamicProfiles/SIPAM.json")

profile = {
  "Profiles": [{
    "Name": "SIPAM",
    "Guid": "sipam-001",
    "Custom Command": "Yes",
    "Command": telnet_path + " 192.168.205.5",
    "Terminal Type": "vt220",
    "Use Custom Window Title": True,
    "Window Title": "SIPAM",
    "Keyboard Map": {
      "0xf704-0x0": {"Action": 12, "Text": esc + "p"},
      "0xf705-0x0": {"Action": 12, "Text": esc + "q"},
      "0xf706-0x0": {"Action": 12, "Text": esc + "r"},
      "0xf707-0x0": {"Action": 12, "Text": esc + "s"},
      "0xf708-0x0": {"Action": 12, "Text": esc + "t"},
      "0xf709-0x0": {"Action": 12, "Text": esc + "u"},
      "0xf70a-0x0": {"Action": 12, "Text": esc + "v"},
      "0xf70b-0x0": {"Action": 12, "Text": esc + "w"},
      "0xf70c-0x0": {"Action": 12, "Text": esc + "[20~"},
      "0xf70d-0x0": {"Action": 12, "Text": esc + "[21~"}
    }
  }]
}

with open(out_path, "w") as f:
    json.dump(profile, f, indent=2, ensure_ascii=False)

print("✅ Perfil SIPAM creado/actualizado en iTerm2")
PYEOF

# ── 4. SIPAM.app ──────────────────────────────────────────────
if [ -d "$SIPAM_APP" ]; then
  echo "✅ SIPAM.app ya existe — omitiendo"
else
  echo "⚙️  Creando SIPAM.app..."
  mkdir -p "$HOME/Applications"
  osacompile -o "$SIPAM_APP" - <<'APPLESCRIPT'
tell application "iTerm2"
    activate
    create window with profile "SIPAM"
end tell
APPLESCRIPT
  echo "✅ SIPAM.app creado en ~/Applications"
fi

# ── 5. Dock — añadir sólo si no está ya ──────────────────────
# Lee las entradas actuales y busca la ruta de SIPAM.app.
# Si ya aparece, no hace nada: sin duplicados.
DOCK_HAS_SIPAM=$(defaults read com.apple.dock persistent-apps 2>/dev/null \
  | grep -c "SIPAM\.app")

if [ "$DOCK_HAS_SIPAM" -gt 0 ]; then
  echo "✅ SIPAM ya está en el Dock — omitiendo"
else
  echo "⚙️  Añadiendo SIPAM al Dock..."
  defaults write com.apple.dock persistent-apps -array-add \
    "<dict><key>tile-data</key><dict><key>file-data</key><dict>\
<key>_CFURLString</key><string>$SIPAM_APP</string>\
<key>_CFURLStringType</key><integer>0</integer>\
</dict></dict></dict>"
  killall Dock
  echo "✅ SIPAM añadido al Dock"
fi

echo ""
echo "🏁 Instalación completa."
echo "   Reinicia iTerm2 una vez para cargar el perfil SIPAM,"
echo "   luego úsalo desde el Dock."
