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
# Secuencias de teclas verificadas contra el perfil Mac funcional
# (captura HP 700/92 iTerm2):
#   F1=ESC p  F2=ESC q  F3=ESC r  F4=ESC s
#   F5=ESC t  F6=ESC u  F7=ESC v  F8=ESC w
#   F9=ESC[20~  F10=ESC[21~  F11=ESC[23~  F12=ESC[31~
#
# PuTTY Keymappings: subclave separada bajo la sesion.
# Formato: nombre = "<VKcode_decimal>:<modifier>"
#   modifier: 0=ninguno, 1=shift, 2=ctrl, 4=alt
# VK codes: F1=112, F2=113 ... F12=123
# =============================================================
$REG_BASE  = "HKCU:\Software\SimonTatham\PuTTY\Sessions\$SESSION_NAME"
$KEYS_BASE = "$REG_BASE\Keymappings"

Write-Step "Configurando sesion SIPAM en PuTTY..."

# Borrar sesion anterior completamente para evitar valores huerfanos
if (Test-Path $REG_BASE) {
    Remove-Item -Path $REG_BASE -Recurse -Force
}
New-Item -Path $REG_BASE  -Force | Out-Null
New-Item -Path $KEYS_BASE -Force | Out-Null

# -- Configuracion general de la sesion -----------------------
$settings = @{
    # Conexion
    "HostName"           = $SIPAM_IP
    "PortNumber"         = [int]$SIPAM_PORT
    "Protocol"           = "telnet"
    # Terminal
    "TerminalType"       = "vt220"
    "TerminalSpeed"      = "38400,38400"
    "LocalEcho"          = [int]0
    "LocalEdit"          = [int]0
    # Teclado: sin remapeo global, usamos Keymappings manual
    "FunctionKeysType"   = [int]0
    "ApplicationKeypad"  = [int]0
    # Pantalla
    "WinTitle"           = "SIPAM"
    "Columns"            = [int]80
    "Rows"               = [int]24
    "ScrollbackLines"    = [int]500
    "LineCodePage"       = "UTF-8"
    # Colores: texto #4C566A (76,86,106) sobre fondo blanco
    # Colour0=FG  Colour1=FG bold  Colour2=BG  Colour3=BG bold
    # Colour4=cursor text  Colour5=cursor color
    "Colour0"            = "76,86,106"
    "Colour1"            = "46,52,64"
    "Colour2"            = "255,255,255"
    "Colour3"            = "255,255,255"
    "Colour4"            = "76,86,106"
    "Colour5"            = "255,255,255"
    # Cierre automatico al desconectar
    "CloseOnExit"        = [int]1
}

foreach ($key in $settings.Keys) {
    $val = $settings[$key]
    if ($val -is [int]) {
        Set-ItemProperty -Path $REG_BASE -Name $key -Value $val -Type DWord
    } else {
        Set-ItemProperty -Path $REG_BASE -Name $key -Value $val -Type String
    }
}

# -- Mapa de teclado HP 700/92 --------------------------------
# ESC = "`e" en PowerShell (caracter escape U+001B)
# F1-F8: ESC + letra (secuencias propietarias HP)
# F9-F12: ESC [ n ~ (secuencias VT220 extendidas)
Write-Step "Configurando mapa de teclas HP 700/92..."

Set-ItemProperty -Path $KEYS_BASE -Name "112:0" -Value "`ep"     -Type String  # F1  = ESC p
Set-ItemProperty -Path $KEYS_BASE -Name "113:0" -Value "`eq"     -Type String  # F2  = ESC q
Set-ItemProperty -Path $KEYS_BASE -Name "114:0" -Value "`er"     -Type String  # F3  = ESC r
Set-ItemProperty -Path $KEYS_BASE -Name "115:0" -Value "`es"     -Type String  # F4  = ESC s
Set-ItemProperty -Path $KEYS_BASE -Name "116:0" -Value "`et"     -Type String  # F5  = ESC t
Set-ItemProperty -Path $KEYS_BASE -Name "117:0" -Value "`eu"     -Type String  # F6  = ESC u
Set-ItemProperty -Path $KEYS_BASE -Name "118:0" -Value "`ev"     -Type String  # F7  = ESC v
Set-ItemProperty -Path $KEYS_BASE -Name "119:0" -Value "`ew"     -Type String  # F8  = ESC w
Set-ItemProperty -Path $KEYS_BASE -Name "120:0" -Value "`e[20~"  -Type String  # F9  = ESC[20~
Set-ItemProperty -Path $KEYS_BASE -Name "121:0" -Value "`e[21~"  -Type String  # F10 = ESC[21~
Set-ItemProperty -Path $KEYS_BASE -Name "122:0" -Value "`e[23~"  -Type String  # F11 = ESC[23~
Set-ItemProperty -Path $KEYS_BASE -Name "123:0" -Value "`e[31~"  -Type String  # F12 = ESC[31~

Write-Ok "Sesion '$SESSION_NAME' lista con mapa de teclas HP 700/92"

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
