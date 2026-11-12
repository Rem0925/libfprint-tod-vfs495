Name:           vfs495-driver
Version:        0.6.0
Release:        1%{?dist}
Summary:        Native Linux driver for Validity VFS495 fingerprint reader (138a:003f)
License:        LGPL-2.1-or-later
URL:            https://github.com/Rem0925/libfprint-tod-vfs495
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  gcc
BuildRequires:  meson >= 0.58
BuildRequires:  ninja-build
BuildRequires:  pkgconfig(glib-2.0)
BuildRequires:  pkgconfig(gio-2.0)
BuildRequires:  pkgconfig(gmodule-2.0)
BuildRequires:  pkgconfig(gusb)
BuildRequires:  pkgconfig(libcrypto)
BuildRequires:  pkgconfig(libfprint-2-tod-1)
BuildRequires:  pkgconfig(libfprint-2)
BuildRequires:  python3
BuildRequires:  curl

Requires:       fprintd
Requires:       fprintd-pam
Requires:       libfprint-tod

%description
A native Linux driver for the Validity VFS495 swipe fingerprint reader (USB 138a:003f),
found in 2013–2015 HP EliteBook, ProBook (e.g. 430 G2, 440 G2, 450 G2, 640 G2)
and ZBook laptops. Plugs into libfprint as a TOD module to provide system authentication
for GNOME lock screen, login manager (GDM) and sudo.

%prep
%autosetup

%build
# Download HP SoftPaq and extract microcode
mkdir -p build-cache
if [ ! -f build-cache/sp84530.tar ]; then
    curl -sSL "https://ftp.hp.com/pub/softpaq/sp84501-85000/sp84530.tar" -o build-cache/sp84530.tar
fi
python3 recipe/build-commands.py build-cache/sp84530.tar commands.bin

%meson
%meson_build

%install
%meson_install
install -D -m 0644 commands.bin %{buildroot}%{_prefix}/lib/vfs495-driver/commands.bin
install -D -m 0644 packaging/70-vfs495.rules %{buildroot}%{_udevrulesdir}/70-vfs495.rules
install -D -m 0644 packaging/vfs495.conf %{buildroot}%{_unitdir}/fprintd.service.d/vfs495.conf

%post
/bin/udevadm control --reload-rules >/dev/null 2>&1 || :
/bin/udevadm trigger --subsystem-match=usb --attr-match=idVendor=138a --attr-match=idProduct=003f >/dev/null 2>&1 || :
systemctl daemon-reload >/dev/null 2>&1 || :
systemctl restart fprintd >/dev/null 2>&1 || :

%files
%license LICENSE
%doc README.md
%{_libdir}/libfprint-2/tod-1/*fprint-tod-vfs495.so
%{_prefix}/lib/vfs495-driver/commands.bin
%{_udevrulesdir}/70-vfs495.rules
%{_unitdir}/fprintd.service.d/vfs495.conf
%{_udevrulesdir}/70-vfs495.rules

%changelog
* Wed Nov 11 2026 Developer <dev@example.com> - 0.6.0-1
- Initial RPM release for Validity VFS495 on Fedora Linux.
