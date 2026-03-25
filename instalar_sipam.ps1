# ─────────────────────────────────────────────────────────────
#  Instalador SIPAM para Windows — sin privilegios de admin
#  Descarga PuTTY portable y crea acceso directo preconfigurado
#  Idempotente: puede ejecutarse varias veces sin duplicados
# ─────────────────────────────────────────────────────────────
#  Para ejecutar: clic derecho → "Ejecutar con PowerShell"
# ─────────────────────────────────────────────────────────────

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Configuración ────────────────────────────────────────────
$SIPAM_IP      = "192.168.205.5"
$SIPAM_PORT    = 23
$PUTTY_URL     = "https://the.earth.li/~sgtatham/putty/latest/w64/putty.exe"
$INSTALL_DIR   = "$env:USERPROFILE\SIPAM"
$PUTTY_EXE     = "$INSTALL_DIR\putty.exe"
$SHORTCUT_PATH = "$env:USERPROFILE\Desktop\SIPAM.lnk"
$SESSION_NAME  = "SIPAM"

# ── Helpers ──────────────────────────────────────────────────
function Write-Step  { param($msg) Write-Host "⚙️  $msg" -ForegroundColor Cyan }
function Write-Ok    { param($msg) Write-Host "✅ $msg"  -ForegroundColor Green }
function Write-Skip  { param($msg) Write-Host "↩️  $msg — omitiendo" -ForegroundColor DarkGray }
function Write-Fail  { param($msg) Write-Host "❌ $msg"  -ForegroundColor Red }

# ─────────────────────────────────────────────────────────────
# 1. Carpeta de instalación
# ─────────────────────────────────────────────────────────────
if (-not (Test-Path $INSTALL_DIR)) {
    Write-Step "Creando carpeta $INSTALL_DIR..."
    New-Item -ItemType Directory -Path $INSTALL_DIR | Out-Null
    Write-Ok "Carpeta creada"
} else {
    Write-Skip "Carpeta $INSTALL_DIR ya existe"
}

# ─────────────────────────────────────────────────────────────
# 2. Descargar PuTTY portable (sin instalador, sin admin)
# ─────────────────────────────────────────────────────────────
if (Test-Path $PUTTY_EXE) {
    Write-Skip "PuTTY ya descargado"
} else {
    Write-Step "Descargando PuTTY..."
    try {
        # Forzar TLS 1.2 (requerido en Windows más antiguos)
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $PUTTY_URL -OutFile $PUTTY_EXE -UseBasicParsing
        Write-Ok "PuTTY descargado en $PUTTY_EXE"
    } catch {
        Write-Fail "No se pudo descargar PuTTY: $_"
        Write-Host "   Descárgalo manualmente desde https://www.putty.org y colócalo en $INSTALL_DIR\putty.exe" -ForegroundColor Yellow
        Read-Host "Presiona Enter para salir"
        exit 1
    }
}

# ─────────────────────────────────────────────────────────────
# 3. Guardar sesión SIPAM en el registro del usuario
#    HKCU no requiere admin — es exclusivo del usuario actual
# ─────────────────────────────────────────────────────────────
$REG_BASE = "HKCU:\Software\SimonTatham\PuTTY\Sessions\$SESSION_NAME"

$sessionExists = Test-Path $REG_BASE

if ($sessionExists) {
    Write-Skip "Sesión PuTTY '$SESSION_NAME' ya registrada"
} else {
    Write-Step "Configurando sesión SIPAM en PuTTY..."
}

# Siempre actualizamos los valores clave (idempotente y correcto
# aunque la sesión ya exista — garantiza que la IP y emulación
# no queden desactualizadas si el script se vuelve a correr)
New-Item -Path $REG_BASE -Force | Out-Null

$settings = @{
    # Conexión
    "HostName"            = $SIPAM_IP
    "PortNumber"          = [int]$SIPAM_PORT
    "Protocol"            = "telnet"
    # Emulación de terminal HP 700/92
    "TerminalType"        = "vt220"
    "TerminalSpeed"       = "38400,38400"
    # Teclado — teclas de función estilo VT
    "FunctionKeysType"    = [int]1       # VT100+
    "ApplicationKeypad"   = [int]0
    # Pantalla
    "WinTitle"            = "SIPAM"
    "Columns"             = [int]80
    "Rows"                = [int]24
    "ScrollbackLines"     = [int]500
    # Codificación (para acentos)
    "LineCodePage"        = "UTF-8"
    # Colores: fondo negro, texto verde — estilo terminal clásico
    "Colour0"             = "0,255,0"    # texto normal
    "Colour2"             = "0,255,0"    # texto bold
    "Colour4"             = "0,0,0"      # BG normal
    "Colour6"             = "0,0,0"      # BG bold
    # Cerrar ventana al desconectar
    "CloseOnExit"         = [int]1
}

foreach ($key in $settings.Keys) {
    $val = $settings[$key]
    if ($val -is [int]) {
        Set-ItemProperty -Path $REG_BASE -Name $key -Value $val -Type DWord
    } else {
        Set-ItemProperty -Path $REG_BASE -Name $key -Value $val -Type String
    }
}

if (-not $sessionExists) {
    Write-Ok "Sesión '$SESSION_NAME' configurada"
} else {
    Write-Ok "Sesión '$SESSION_NAME' actualizada"
}

# ─────────────────────────────────────────────────────────────
# 4. Acceso directo en el Escritorio
#    Abre PuTTY directo a la sesión SIPAM con un doble clic
# ─────────────────────────────────────────────────────────────
if (Test-Path $SHORTCUT_PATH) {
    Write-Skip "Acceso directo SIPAM ya existe en el Escritorio"
} else {
    Write-Step "Creando acceso directo en el Escritorio..."
    $WshShell   = New-Object -ComObject WScript.Shell
    $shortcut   = $WshShell.CreateShortcut($SHORTCUT_PATH)
    $shortcut.TargetPath       = $PUTTY_EXE
    # -load abre la sesión guardada directamente, sin mostrar la ventana de PuTTY
    $shortcut.Arguments        = "-load `"$SESSION_NAME`""
    $shortcut.WorkingDirectory = $INSTALL_DIR
    $shortcut.Description      = "Conectar al SIPAM (INNSZ)"
    $shortcut.Save()
    Write-Ok "Acceso directo creado en el Escritorio"
}

# ─────────────────────────────────────────────────────────────
# Resumen final
# ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "🏁 Instalación completa." -ForegroundColor Green
Write-Host ""
Write-Host "   Para conectarte al SIPAM:" -ForegroundColor White
Write-Host "   → Haz doble clic en el ícono 'SIPAM' de tu Escritorio." -ForegroundColor White
Write-Host ""
Write-Host "   Credenciales de acceso:" -ForegroundColor White
Write-Host "   · Primer 'Password:'  → presiona Enter sin escribir nada" -ForegroundColor Gray
Write-Host "   · 'fenix login:'      → escribe tu usuario (ej: con209)" -ForegroundColor Gray
Write-Host "   · Segundo 'Password:' → escribe tu contraseña SIPAM" -ForegroundColor Gray
Write-Host ""
Write-Host "   Teclas de función: usa las teclas F1–F12 directamente." -ForegroundColor Gray
Write-Host "   (En Windows no necesitas la tecla Fn)" -ForegroundColor DarkGray
Write-Host ""

Read-Host "Presiona Enter para cerrar"
