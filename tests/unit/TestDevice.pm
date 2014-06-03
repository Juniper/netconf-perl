package Net::Netconf::TestDevice;
use base qw(Test::Class);
use Test::More qw(no_plan);
require_ok('Device.pm');
require_ok('Manager.pm');

sub ssh_connect :Test(startup)
{
print "Enter hostname\n";
my $hostname = <>;
print "Enter username\n";
my $login= <>;
print "Enter password\n";
my $pass = <>;
chomp($hostname);
chomp($login);
chomp($pass);
$jnx = new Net::Netconf::Manager( 'access' => 'ssh',
        'login' => $login,
        'password' => $pass,
        'hostname' => $hostname);
isa_ok($jnx,'Net::Netconf::Device');
};

sub capability_server :Test(2)
{
@arr= $jnx->get_server_cap();
$val= join("," ,@arr);
cmp_ok(index ($val, "capability"), '>', -1);
cmp_ok(index($val, "netconf"), '>', -1);
};

sub checklock_config :Test(3)
{
my %queryargs = ( 'target' => 'candidate' );
$isloc = $jnx->lock_config(%queryargs);
print $isloc;
cmp_ok(index ($isloc, "rpc-reply"), '>', -1);
cmp_ok(index($isloc, "ok"), '>', -1);
is(index($isloc,"rpc-error"), -1, "No error found while locking Device...!!!");
};

sub edit_config : Test(3)
{
%queryargs = ('target' => 'candidate');
$config= "<configuration>
  <system>
	<services>
	      <ftp/>
	</services>
  </system>
</configuration>";
$queryargs{'config'} = $config;
my $isedit=$jnx->edit_config(%queryargs);
print $isedit;
cmp_ok(index ($isedit, "rpc-reply"), '>', -1);
cmp_ok(index($isedit, "ok"), '>', -1);
is(index($isedit,"rpc-error"), -1, "No error found while locking Device...!!!");
};

sub testcommit_config : Test(3)
{
my $iscommit= $jnx->commit();
print $iscommit;
cmp_ok(index ($iscommit, "rpc-reply"), '>', -1);
cmp_ok(index($iscommit, "ok"), '>', -1);
is(index($iscommit,"rpc-error"), -1, "No error found while commiting changes.....!!");
};

sub unlock_config : Test(3)
{
my $isunloc = $jnx->unlock_config();
print $isunloc;
cmp_ok(index ($isunloc, "rpc-reply"), '>', -1);
cmp_ok(index($isunloc, "ok"), '>', -1);
is(index($isunloc,"rpc-error"), -1, "No error found while unlocking Device.....!!");
};

sub verify_execute_rpc : Test(3)
{
my $val = $jnx->get_alarm_information();
print $val;
cmp_ok(index ($val, "rpc-reply"), '>', -1);
cmp_ok(index($val, "alarm"), '>', -1);
is(index($val,"rpc-error"), -1, "execute_rpc no error found!!");
};

sub ssh_close : Test(shutdown=>3)
{
my $isclose=$jnx->close_session();
print "disconnect value is $isclose";
cmp_ok(index ($isclose, "rpc-reply"), '>', -1);
cmp_ok(index($isclose, "ok"), '>', -1);
is(index($isclose,"rpc-error"), -1, "No error found while closing session.....!!");
};
