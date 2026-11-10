%global debug_package %{nil}
%global modname macbook-t1-touchbar
%global AkmodsBuildRequires gcc make
Name: %{modname}-kmod
Version: 0.1.20261110
Release: 1%{?dist}
Summary: Experimental T1 MacBook Touch Bar driver with ACPI freeze guard
License: GPL-2.0-only
URL: https://github.com/AJ-dev-i60/t1-touchbar
Source0: %{modname}-%{version}.tar.gz
ExclusiveArch: x86_64
BuildRequires: kmodtool, gcc, make, kernel-devel, redhat-rpm-config
%{expand:%(kmodtool --target %{_target_cpu} --repo fedora --kmodname %{name} %{!?kernels:--akmod} %{?kernels:--for-kernels "%{kernels}"} 2>/dev/null)}

%description
Pinned T1 driver source at 20d65c7 with local command-result and resume fixes,
reset-resume cache invalidation, T1 idle blanking via MODE_OFF, and the
opt-in macbook_t1_socw T1 sleep/wake module.
Experimental hardware enablement; native applespi is not replaced.

%package common
Summary: T1 Touch Bar boot configuration and source provenance
Provides: %{modname}-kmod-common = %{version}-%{release}

%description common
Keeps skip_acpi_power=1 and includes drivers for early boot without resetting USB.

%prep
%{?kmodtool_check}
%setup -q -n %{modname}-%{version}
for kv in %{?kernel_versions}; do
    cp -a . "../_kmod_build_${kv%%___*}"
done

%build
for kv in %{?kernel_versions}; do
    make %{?_smp_mflags} -C "../_kmod_build_${kv%%___*}" KERNELRELEASE="${kv%%___*}" KDIR="${kv##*___}"
done

%install
for kv in %{?kernel_versions}; do
    for module in apple-ibridge apple-touchbar macbook_t1_socw; do
        install -Dpm 0644 "../_kmod_build_${kv%%___*}/${module}.ko" "%{buildroot}%{kmodinstdir_prefix}/${kv%%___*}%{kmodinstdir_postfix}/${module}.ko"
    done
done
install -d %{buildroot}%{_modprobedir} %{buildroot}%{_modulesloaddir} %{buildroot}%{_prefix}/lib/dracut/dracut.conf.d
printf 'options apple_ibridge skip_acpi_power=1\nsoftdep apple_ibridge pre: apple_touchbar\n' > %{buildroot}%{_modprobedir}/macbook-t1-touchbar.conf
printf 'apple_touchbar\napple_ibridge\n' > %{buildroot}%{_modulesloaddir}/macbook-t1-touchbar.conf
printf 'force_drivers+=" apple_touchbar apple_ibridge "\n' > %{buildroot}%{_prefix}/lib/dracut/dracut.conf.d/91-macbook-t1-touchbar.conf
%{?akmod_install}

%files common
%license LICENSE
%doc PROVENANCE.md
%{_modprobedir}/macbook-t1-touchbar.conf
%{_modulesloaddir}/macbook-t1-touchbar.conf
%{_prefix}/lib/dracut/dracut.conf.d/91-macbook-t1-touchbar.conf

%changelog
* Tue Nov 10 2026 Local hardware audit <nobody@localhost> - 0.1.20261110-1
- Blank the T1 strip on idle timeout via MODE_OFF; restore on normal input.
- Keep existing ACPI guard, suspend handling, and 300-second idle default.

* Sun Nov 01 2026 Local hardware audit <nobody@localhost> - 0.1.20261101-1
- Invalidate cached Touch Bar mode on reset-resume; add macbook_t1_socw (SOCW on demand only).

* Sat Oct 31 2026 Local hardware audit <nobody@localhost> - 0.1.20261031-1
- Pin source; keep ACPI guard; fix positive USB success and T1 resume predicate.
