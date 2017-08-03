Summary: perl-Net-Netconf
Name: perl-Net-Netconf
Version: 1.4.2
Release: 1%{?dist}
License: Apache
Group: GRNOC
URL: https://github.com/GlobalNOC/netconf-perl
Source: %{name}-%{version}.tar.gz

BuildRoot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
BuildRequires: perl
Requires: perl-Net-SSH2
Requires: perl-File-Which
Requires: perl-XML-LibXML

%description
Netconf library for JUNOS devices

%prep
%setup -q -n perl-Net-Netconf-%{version}

%build
%{__perl} Makefile.PL PREFIX="%{buildroot}%{_prefix}" INSTALLDIRS="vendor"
make

%install
rm -rf $RPM_BUILD_ROOT

%{__install} -d -p %{buildroot}%{perl_vendorlib}/Net
cp -ar lib/Net/* %{buildroot}%{perl_vendorlib}/Net

%clean
rm -rf $RPM_BUILD_ROOT


%files
%{perl_vendorlib}/Net

%doc


%changelog
* Thu Jun 29 2017 Jonathan Stout <jonstout@nddi-dev.bldc.net.internet2.edu> - Net-Netconf
- Initial build.

