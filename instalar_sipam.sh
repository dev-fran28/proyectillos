#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  Instalador SIPAM
#  Compatible con Apple Silicon e Intel.
# ─────────────────────────────────────────────────────────────

# 1. Homebrew
if ! command -v brew &>/dev/null; then
  echo "⬇️  Instalando Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  [ -f /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
  [ -f /usr/local/bin/brew ]    && eval "$(/usr/local/bin/brew shellenv)"
else
  echo "✅ Homebrew ya instalado — omitiendo"
  eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null
fi

# 2. Telnet
if ! command -v telnet &>/dev/null; then
  echo "⬇️  Instalando telnet..."
  brew install telnet
else
  echo "✅ Telnet ya instalado — omitiendo"
fi

# 3. Perfil iTerm2 — generado con Python para JSON válido
echo "⚙️  Configurando perfil SIPAM en iTerm2..."
PROFILE_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
mkdir -p "$PROFILE_DIR"

# Detect telnet absolute path
TELNET_PATH=$(command -v telnet 2>/dev/null)
if [ -z "$TELNET_PATH" ]; then
  # fallback for Apple Silicon / Intel
  [ -f /opt/homebrew/bin/telnet ] && TELNET_PATH="/opt/homebrew/bin/telnet"
  [ -f /usr/local/bin/telnet ]    && TELNET_PATH="/usr/local/bin/telnet"
fi
echo "   Usando telnet en: $TELNET_PATH"

python3 - "$TELNET_PATH" <<'PYEOF'
import json, os, sys

esc = "\u001b"
telnet_path = sys.argv[1] if len(sys.argv) > 1 else "telnet"

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

path = os.path.expanduser(
    "~/Library/Application Support/iTerm2/DynamicProfiles/SIPAM.json"
)
with open(path, "w") as f:
    json.dump(profile, f, indent=2, ensure_ascii=False)

print("✅ Perfil SIPAM creado en iTerm2")
PYEOF

# 4. Aplicación SIPAM.app
echo "⚙️  Creando SIPAM.app..."
osacompile -o ~/Applications/SIPAM.app - << 'APPLESCRIPT'
tell application "iTerm2"
    activate
    create window with profile "SIPAM"
end tell
APPLESCRIPT
echo "✅ SIPAM.app creado en ~/Applications"

# 5. Añadir al Dock
echo "⚙️  Añadiendo SIPAM al Dock..."
defaults write com.apple.dock persistent-apps -array-add \
  "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$HOME/Applications/SIPAM.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
killall Dock

echo ""
echo "🏁 Instalación completa."
echo "   Reinicia iTerm2 una vez para cargar el perfil SIPAM,"
echo "   luego úsalo desde el Dock."
