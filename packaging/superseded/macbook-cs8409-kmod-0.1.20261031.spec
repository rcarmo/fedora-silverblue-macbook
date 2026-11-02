%global debug_package %{nil}
%global modname macbook-cs8409
%global AkmodsBuildRequires gcc make
Name: %{modname}-kmod
Version: 0.1.20261031
Release: 2%{?dist}
Summary: Experimental Apple CS8409 audio driver for MacBookPro13,2
License: GPL-2.0-only AND GPL-2.0-or-later
URL: https://github.com/davidjo/snd_hda_macbookpro
Source0: %{modname}-%{version}.tar.gz
ExclusiveArch: x86_64
BuildRequires: kmodtool, gcc, make, kernel-devel, redhat-rpm-config
%{expand:%(kmodtool --target %{_target_cpu} --repo fedora --kmodname %{name} %{!?kernels:--akmod} %{?kernels:--for-kernels "%{kernels}"} 2>/dev/null)}

%description
Apple-specific amplifier initialization from pinned community driver 89b22ff.
Bundled Linux 7.2.13 HDA source and explicit header adaptation; no build-time
network downloads. Audio headphones and suspend behavior remain experimental.

%package common
Summary: Apple CS8409 module precedence and provenance
Provides: %{modname}-kmod-common = %{version}-%{release}

%description common
Selects the packaged Apple codec module without overwriting Fedora's stock codec.

%prep
%{?kmodtool_check}
%setup -q -n %{modname}-%{version}
for kv in %{?kernel_versions}; do
    # Refuse unreviewed major/minor API changes; update source before upgrading.
    case "${kv%%-*}" in 7.2.*) ;; *) echo "Apple CS8409 source requires review for kernel ${kv%%___*}" >&2; exit 1;; esac
    cp -a . "../_kmod_build_${kv%%___*}"
done

%build
for kv in %{?kernel_versions}; do
    make %{?_smp_mflags} -C "${kv##*___}" M="$(realpath ../_kmod_build_${kv%%___*}/hda)" CFLAGS_MODULE='-DAPPLE_PINSENSE_FIXUP -DAPPLE_CODECS -DCONFIG_SND_HDA_RECONFIG=1 -Wno-unused-variable -Wno-unused-function' modules
done

%install
for kv in %{?kernel_versions}; do
    install -Dpm 0644 "../_kmod_build_${kv%%___*}/hda/codecs/cirrus/snd-hda-codec-cs8409.ko" "%{buildroot}%{kmodinstdir_prefix}/${kv%%___*}%{kmodinstdir_postfix}/snd-hda-codec-cs8409.ko"
done
install -d %{buildroot}%{_prefix}/lib/depmod.d %{buildroot}%{_prefix}/lib/dracut/dracut.conf.d
printf 'override snd-hda-codec-cs8409 * extra/macbook-cs8409\n' > %{buildroot}%{_prefix}/lib/depmod.d/macbook-cs8409.conf
printf 'add_drivers+=" snd_hda_codec_cs8409 "\n' > %{buildroot}%{_prefix}/lib/dracut/dracut.conf.d/92-macbook-cs8409.conf
%{?akmod_install}

%files common
%license LICENSE
%doc PROVENANCE.md
%{_prefix}/lib/depmod.d/macbook-cs8409.conf
%{_prefix}/lib/dracut/dracut.conf.d/92-macbook-cs8409.conf

%changelog
* Sat Oct 31 2026 Local hardware audit <nobody@localhost> - 0.1.20261031-2
- Use literal module filename in depmod override; verify selection against stock.
* Sat Oct 31 2026 Local hardware audit <nobody@localhost> - 0.1.20261031-1
- Bundle pinned Apple driver plus Linux 7.2.13 HDA source and adapted header.
