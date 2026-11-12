# Validity VFS495 (138a:003f) Linux Fingerprint Driver

[![License: LGPL v2.1](https://img.shields.io/badge/License-LGPL_v2.1-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux%20(x86__64)-green.svg)]()
[![Hardware](https://img.shields.io/badge/Hardware-HP%20ProBook%20%7C%20EliteBook%20%7C%20ZBook-orange.svg)]()

Controlador nativo de código abierto para el lector de huellas dactilares **Validity Sensors VFS495** (USB ID **`138a:003f`**), integrado como módulo **TOD** en `libfprint`.

Permite la autenticación biométrica completa en el sistema:
* Inicio de sesión en **GDM / LightDM / SDDM**
* Desbloqueo de pantalla en **GNOME / KDE Plasma**
* Autorización de comandos con **`sudo`** y **`polkit`**

---

## 💻 Portátiles Compatibles Verificados

* **HP ProBook:** 430 G2, 440 G2, 450 G2, 470 G2, 640 G1/G2, 650 G1/G2.
* **HP EliteBook:** 820 G1/G2, 840 G1/G2, 850 G1/G2.
* **HP ZBook:** 14 G2, 15 G2/G3, 17 G2/G3.
* *Cualquier laptop con el dispositivo USB `138a:003f` (comprueba con `lsusb`).*

---

## ⚡ Instalación Rápida (1 Línea)

El instalador detecta automáticamente tu distribución (**Fedora, Ubuntu, Debian, Arch Linux, Linux Mint, openSUSE**), descarga las herramientas necesarias, extrae el microcódigo oficial de calibración y activa el lector en el sistema:

```bash
git clone https://github.com/Rem0925/libfprint-tod-vfs495.git
cd libfprint-tod-vfs495
sudo ./install.sh
```

Una vez finalizado, registra tu dedo ejecutando:
```bash
fprintd-enroll
```
*(o desde Configuración de GNOME -> Usuarios -> Inicio de sesión con huella)*.

---

## ⚙️ ¿Cómo funciona por debajo?

1. **Protocolo Criptográfico:** A diferencia de lectores simples, el VFS495 exige un handshake SSLv3 personalizado con cifrado `AES-256-CBC` y firma `SHA-1 HMAC`. Sin esta sesión, el microcontrolador del sensor rechaza cualquier lectura.
2. **Extracción Limpia (Clean-Room):** El instalador descarga el paquete oficial de HP SoftPaq (`sp84530.tar`, 2.9 MB) y extrae las tablas de microcódigo y calibración sin ejecutar binarios propietarios de Windows/Linux.
3. **Módulo TOD para libfprint:** Se compila como librería compartida `fprint-tod-vfs495.so` y se instala en `/usr/lib64/libfprint-2/tod-1/`. `fprintd` lo carga automáticamente al iniciar.
4. **Ensamblado de Huella:** Como es un sensor de barrido (*swipe sensor*), el driver calcula el desplazamiento temporal (*lag*) entre la línea de escaneo principal y la auxiliar para reconstruir la imagen bidimensional de la huella sin distorsiones.

---

## 📦 Empaquetado por Distribución

* **Fedora / RHEL / openSUSE:** Se incluye la especificación RPM en `packaging/vfs495-driver.spec`.
* **Arch Linux / Manjaro:** Se incluye la receta `PKGBUILD` en `packaging/PKGBUILD` para compilar con `makepkg -si`.
* **Ubuntu / Debian:** Scripts de generación `.deb` incluidos en `driver/packaging/build-deb.sh`.

---

## 🤝 Créditos y Agradecimientos

Basado en la investigación e ingeniería inversa comunitaria de **saifulmd0** (`saifulmd0/vfs495-linux`) y **Ahmad-b1995** (`Ahmad-b1995/vfs495-driver`).
Licenciado bajo LGPL-2.1.
