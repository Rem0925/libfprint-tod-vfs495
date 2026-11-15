#!/bin/bash
# ==============================================================================
# Universal Installer for Validity Sensors VFS495 (138a:003f) Linux Driver
# Compatible with: Fedora, Ubuntu, Debian, Arch Linux, openSUSE
# Hardware: HP ProBook 430/440/450/640 G2, EliteBook 820/840/850 G1/G2, ZBook G2/G3
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Validity VFS495 (138a:003f) Native Linux Driver Installer     ${NC}"
echo -e "${BLUE}================================================================${NC}"

# 1. Check Root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Este script debe ejecutarse con privilegios de root (sudo).${NC}"
    echo "Ejecuta: sudo $0"
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$REAL_USER")

# 2. Check Device Presence
echo -e "\n${YELLOW}[1/5] Verificando presencia de hardware USB...${NC}"
if ! lsusb -d 138a:003f > /dev/null 2>&1; then
    echo -e "${RED}[ADVERTENCIA] No se detectó ningún lector USB 138a:003f en el sistema.${NC}"
    read -p "¿Deseas continuar con la instalación de todos modos? (s/N): " -r cont
    if [[ ! "$cont" =~ ^[sS]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✓ Lector Validity VFS495 (138a:003f) detectado correctamente.${NC}"
fi

# 3. Detect Distribution
echo -e "\n${YELLOW}[2/5] Detectando distribución de Linux...${NC}"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_LIKE="${ID_LIKE:-$DISTRO_ID}"
else
    DISTRO_ID="unknown"
    DISTRO_LIKE="unknown"
fi

echo -e "Distribución detectada: ${GREEN}$DISTRO_ID${NC} ($PRETTY_NAME)"

# 4. Install Dependencies & libfprint-tod
echo -e "\n${YELLOW}[3/5] Instalando dependencias y soporte libfprint-tod...${NC}"

case "$DISTRO_ID" in
    fedora)
        echo "Configurando repositorios y paquetes para Fedora..."
        # Enable Copr with libfprint-tod if not already installed
        if ! rpm -qa | grep -q "libfprint-tod"; then
            echo "Habilitando repositorio Copr para libfprint-tod..."
            dnf copr enable -y ferdiu/libfprint-tod || dnf copr enable -y grahamwhiteuk/libfprint-tod
            echo "Intercambiando libfprint estándar por libfprint-tod..."
            dnf swap -y libfprint libfprint-tod
        fi
        dnf install -y libfprint-tod-devel libgusb-devel openssl-devel glib2-devel meson ninja-build gcc curl python3 fprintd fprintd-pam
        ;;
    ubuntu|debian|linuxmint|pop)
        echo "Instalando paquetes para Debian/Ubuntu..."
        apt-get update
        apt-get install -y git build-essential meson ninja-build pkg-config curl python3 \
            libfprint-2-tod-dev libgusb-dev libssl-dev libglib2.0-dev fprintd libpam-fprintd
        ;;
    arch|manjaro|endeavouros)
        echo "Detectado Arch Linux. Asegúrate de tener libfprint-tod instalado desde AUR (yay/paru)."
        pacman -S --needed --noconfirm base-devel meson ninja pkgconf curl python openssl glib2 gusb fprintd
        ;;
    opensuse*|suse)
        echo "Instalando paquetes para openSUSE..."
        zypper in -y meson ninja gcc pkg-config curl python3 libopenssl-devel glib2-devel libgusb-devel fprintd
        ;;
    *)
        echo -e "${YELLOW}Distribución no reconocida específicamente. Asegúrate de tener instalados los headers de libfprint-tod, meson, ninja, gcc, openssl y libgusb.${NC}"
        ;;
esac

# 5. Extract Official Microcode Patches (Clean-room SoftPaq extraction)
echo -e "\n${YELLOW}[4/5] Extrayendo comandos y microcódigo del paquete oficial de HP...${NC}"
BUILD_DIR="/tmp/vfs495-build-$$"
mkdir -p "$BUILD_DIR"
trap 'rm -rf "$BUILD_DIR"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p /usr/lib/vfs495-driver

echo "Descargando HP SoftPaq sp84530.tar (2.9 MB)..."
curl -sSL "https://ftp.hp.com/pub/softpaq/sp84501-85000/sp84530.tar" -o "$BUILD_DIR/sp84530.tar"

echo "Extrayendo parches de calibración..."
python3 "$SCRIPT_DIR/recipe/build-commands.py" "$BUILD_DIR/sp84530.tar" /usr/lib/vfs495-driver/commands.bin
chmod 0644 /usr/lib/vfs495-driver/commands.bin
echo -e "${GREEN}✓ Microcódigo instalado en /usr/lib/vfs495-driver/commands.bin${NC}"

# 6. Compile and Install TOD Driver Module
echo -e "\n${YELLOW}[5/5] Compilando e instalando el módulo de libfprint...${NC}"
cd "$SCRIPT_DIR/driver"
meson setup "$BUILD_DIR/meson-build" --prefix=/usr --buildtype=release
ninja -C "$BUILD_DIR/meson-build"
ninja -C "$BUILD_DIR/meson-build" install

# Detect TOD drivers directory
TOD_DIR=""
for d in /usr/lib64/libfprint-2/tod-1 /usr/lib/x86_64-linux-gnu/libfprint-2/tod-1 /usr/lib/libfprint-2/tod-1; do
    if [ -d "$d" ]; then
        TOD_DIR="$d"
        break
    fi
done

if [ -n "$TOD_DIR" ]; then
    echo -e "${GREEN}✓ Módulo instalado en: $TOD_DIR/libfprint-tod-vfs495.so${NC}"
fi

# 7. Enable PAM & System Integration
echo -e "\n${YELLOW}Configurando autenticación biométrica en el sistema...${NC}"
case "$DISTRO_ID" in
    fedora)
        authselect enable-feature with-fingerprint || true
        authselect apply-changes || true
        ;;
    ubuntu|debian|linuxmint)
        pam-auth-update --enable fprintd || true
        ;;
esac

# 8. Set up udev rule
echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="138a", ATTRS{idProduct}=="003f", ATTR{power/control}="auto", ATTR{power/autosuspend_delay_ms}="2000", TAG+="uaccess"' > /etc/udev/rules.d/70-vfs495.rules
udevadm control --reload-rules
udevadm trigger

# 9. Install resume service (prevents reader freeze after laptop sleep)
if [ -f "$SCRIPT_DIR/driver/packaging/resume.service" ]; then
    cp "$SCRIPT_DIR/driver/packaging/resume.service" /etc/systemd/system/vfs495-resume.service
    systemctl daemon-reload
    systemctl enable vfs495-resume.service
fi

# 10. Set up fprintd service configuration (calibrated 500 DPI physical sensor distance)
mkdir -p /etc/systemd/system/fprintd.service.d
cat << 'EOF' > /etc/systemd/system/fprintd.service.d/vfs495.conf
[Service]
Environment="G_MESSAGES_DEBUG=libfprint-print fprintd libfprint-vfs495"
EOF
systemctl daemon-reload

# 11. Restart fprintd
systemctl restart fprintd || true

echo -e "\n${GREEN}================================================================${NC}"
echo -e "${GREEN}  ¡Instalación completada con éxito!                            ${NC}"
echo -e "${GREEN}================================================================${NC}"
echo -e "Para registrar tu huella dactilar ahora mismo, ejecuta:"
echo -e "   ${BLUE}fprintd-enroll${NC}"
echo ""
echo -e "O ve a la configuración de tu escritorio:"
echo -e "   ${BLUE}Configuración de GNOME -> Usuarios -> Inicio de sesión con huella${NC}"
echo ""
