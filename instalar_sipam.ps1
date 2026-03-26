# =============================================================
#  Instalador SIPAM para Windows -- sin privilegios de admin
#  Compatible: Windows 10/11, PowerShell 5.1+
#  Idempotente: puede ejecutarse varias veces sin duplicados
# =============================================================

$ErrorActionPreference = "Stop"

# -- Configuracion --------------------------------------------
$SIPAM_IP      = "192.168.205.5"
$SIPAM_PORT    = 23
$PUTTY_URL     = "https://the.earth.li/~sgtatham/putty/latest/w64/putty.exe"
$INSTALL_DIR   = Join-Path $env:USERPROFILE "SIPAM"
$PUTTY_EXE     = Join-Path $INSTALL_DIR "putty.exe"
$SHORTCUT_PATH = Join-Path ([Environment]::GetFolderPath("Desktop")) "SIPAM.lnk"
$SESSION_NAME  = "SIPAM"

# -- Helpers --------------------------------------------------
function Write-Step { param($msg) Write-Host "[...] $msg" -ForegroundColor Cyan }
function Write-Ok   { param($msg) Write-Host " [OK] $msg" -ForegroundColor Green }
function Write-Skip { param($msg) Write-Host "[OMI] $msg" -ForegroundColor DarkGray }
function Write-Fail { param($msg) Write-Host "[ERR] $msg" -ForegroundColor Red }

# =============================================================
# 1. Carpeta de instalacion
# =============================================================
if (-not (Test-Path $INSTALL_DIR)) {
    Write-Step "Creando carpeta $INSTALL_DIR..."
    New-Item -ItemType Directory -Path $INSTALL_DIR | Out-Null
    Write-Ok "Carpeta creada"
} else {
    Write-Skip "Carpeta ya existe: $INSTALL_DIR"
}

# =============================================================
# 2. Descargar PuTTY portable
# =============================================================
if (Test-Path $PUTTY_EXE) {
    Write-Skip "PuTTY ya descargado en $PUTTY_EXE"
} else {
    Write-Step "Descargando PuTTY..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $PUTTY_URL -OutFile $PUTTY_EXE -UseBasicParsing
        Write-Ok "PuTTY descargado en $PUTTY_EXE"
    } catch {
        Write-Fail "No se pudo descargar PuTTY: $_"
        Write-Host "Descargalo manualmente desde https://www.putty.org" -ForegroundColor Yellow
        Write-Host "y coloca putty.exe en: $INSTALL_DIR" -ForegroundColor Yellow
        Read-Host "Presiona Enter para salir"
        exit 1
    }
}

# =============================================================
# 3. Sesion PuTTY en el registro (HKCU -- sin admin)
#
# Indices de color en PuTTY:
#   Colour0 = texto por defecto (foreground)
#   Colour1 = texto bold
#   Colour2 = cursor
#   Colour3 = texto del cursor
#   Colour4 = fondo (background)
#   Colour5 = fondo bold
# =============================================================
$REG_BASE = "HKCU:\Software\SimonTatham\PuTTY\Sessions\$SESSION_NAME"
$sessionExists = Test-Path $REG_BASE

if ($sessionExists) {
    Write-Skip "Sesion '$SESSION_NAME' ya existe -- actualizando valores"
} else {
    Write-Step "Configurando sesion SIPAM en PuTTY..."
}

New-Item -Path $REG_BASE -Force | Out-Null

$settings = @{
    # Conexion
    "HostName"          = $SIPAM_IP
    "PortNumber"        = [int]$SIPAM_PORT
    "Protocol"          = "telnet"
    # Terminal
    "TerminalType"      = "vt220"
    "TerminalSpeed"     = "38400,38400"
    "FunctionKeysType"  = [int]1
    "ApplicationKeypad" = [int]0
    "WinTitle"          = "SIPAM"
    "Columns"           = [int]80
    "Rows"              = [int]24
    "ScrollbackLines"   = [int]500
    "LineCodePage"      = "UTF-8"
    # Colores: texto blanco sobre fondo negro (legible, sin confusion)
    "Colour0"           = "187,187,187"   # foreground: gris claro
    "Colour1"           = "255,255,255"   # bold foreground: blanco
    "Colour2"           = "0,255,0"       # cursor: verde
    "Colour3"           = "0,0,0"         # cursor text: negro
    "Colour4"           = "0,0,0"         # background: negro
    "Colour5"           = "0,0,0"         # bold background: negro
    # Cierre
    "CloseOnExit"       = [int]1
}

foreach ($key in $settings.Keys) {
    $val = $settings[$key]
    if ($val -is [int]) {
        Set-ItemProperty -Path $REG_BASE -Name $key -Value $val -Type DWord
    } else {
        Set-ItemProperty -Path $REG_BASE -Name $key -Value $val -Type String
    }
}
Write-Ok "Sesion '$SESSION_NAME' lista"

# =============================================================
# 4. Acceso directo en el Escritorio
# =============================================================
if (Test-Path $SHORTCUT_PATH) {
    Write-Skip "Acceso directo ya existe en el Escritorio"
} else {
    Write-Step "Creando acceso directo en el Escritorio..."
    $WshShell              = New-Object -ComObject WScript.Shell
    $shortcut              = $WshShell.CreateShortcut($SHORTCUT_PATH)
    $shortcut.TargetPath   = $PUTTY_EXE
    $shortcut.Arguments    = "-load `"$SESSION_NAME`""
    $shortcut.WorkingDirectory = $INSTALL_DIR
    $shortcut.Description  = "Conectar al SIPAM (INNSZ)"
    $shortcut.Save()
    Write-Ok "Acceso directo creado en el Escritorio"
}

# =============================================================
# Listo
# =============================================================
Write-Host ""
Write-Host "===================================================" -ForegroundColor Green
Write-Host " INSTALACION COMPLETA" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Para conectarte al SIPAM:" -ForegroundColor White
Write-Host "  Haz doble clic en el icono SIPAM de tu Escritorio." -ForegroundColor White
Write-Host ""
Write-Host "Credenciales:" -ForegroundColor White
Write-Host "  1. Primer Password:  --> presiona Enter sin escribir nada" -ForegroundColor Gray
Write-Host "  2. fenix login:      --> tu usuario (ej: con209)" -ForegroundColor Gray
Write-Host "  3. Segundo Password: --> tu contrasena SIPAM" -ForegroundColor Gray
Write-Host ""

Read-Host "Presiona Enter para cerrar"
