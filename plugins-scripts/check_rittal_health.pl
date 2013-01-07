#! /usr/bin/perl

use strict;


use vars qw ($PROGNAME $REVISION $CONTACT $TIMEOUT $STATEFILESDIR $needs_restart %commandline $CELSIUS $PERFDATA);

$PROGNAME = "check_rittal_health";
$REVISION = '$Revision: #PACKAGE_VERSION# $';
$CONTACT = 'gerhard.lausser@consol.de';
$TIMEOUT = 60;
$STATEFILESDIR = '/var/tmp/check_rittal_health';
$CELSIUS = 1;
$PERFDATA = 1;

use constant OK         => 0;
use constant WARNING    => 1;
use constant CRITICAL   => 2;
use constant UNKNOWN    => 3;
use constant DEPENDENT  => 4;


my @modes = (
  ['device::uptime',
      'uptime', undef,
      'Check the uptime of the device' ],
  ['device::sensors::health',
      'overall-health', undef,
      'Check the state of the sensors' ],
  ['device::sensors::list',
      'list-sensors', undef,
      'Show the sensors of the device and update the name cache' ],
  ['device::walk',
      'walk', undef,
      'Show snmpwalk command with the oids necessary for a simulation' ],
);
my $modestring = "";
my $longest = length ((reverse sort {length $a <=> length $b} map { $_->[1] } @modes)[0]);
my $format = "       %-".
  (length ((reverse sort {length $a <=> length $b} map { $_->[1] } @modes)[0])).  "s\t(%s)\n";
foreach (@modes) {
  $modestring .= sprintf $format, $_->[1], $_->[3];
}
$modestring .= sprintf "\n";

my $plugin = Nagios::MiniPlugin->new(
    shortname => '',
    usage => 'Usage: %s [ -v|--verbose ] [ -t <timeout> ] '.
        '--hostname <ctc> --community <snmp-community>'.
        '  ...]',
    version => $REVISION,
    blurb => 'This plugin checks the status of rittal cmc-tc units',
    url => 'http://labs.consol.de/nagios/check_rittal_health',
    timeout => 60,
    shortname => '',
);
$plugin->add_arg(
    spec => 'mode=s',
    help => '--mode
   Tell the plugin what it should do',
    required => 0,
    default => 'overall-health',
);
$plugin->add_arg(
    spec => 'blacklist|b=s',
    help => '--blacklist
   Blacklist some (missing/failed) components',
    required => 0,
    default => '',
);
$plugin->add_arg(
    spec => 'customthresholds|c=s',
    help => '--customthresholds
   Use custom thresholds for certain temperatures',
    required => 0,
);
$plugin->add_arg(
    spec => 'perfdata=s',
    help => '--perfdata=[short]
   Output performance data. If your performance data string becomes
   too long and is truncated by Nagios, then you can use --perfdata=short
   instead. This will output temperature tags without location information',
    required => 0,
);
$plugin->add_arg(
    spec => 'hostname|H=s',
    help => '--hostname
   Hostname or IP-address of the server (SNMP mode only)',
    required => 0,
);
$plugin->add_arg(
    spec => 'port=i',
    help => '--port
   The SNMP port to use (default: 161)',
    required => 0,
    default => 161,
);
$plugin->add_arg(
    spec => 'protocol|P=s',
    help => '--protocol
   The SNMP protocol to use (default: 2c, other possibilities: 1,3)',
    required => 0,
    default => '2c',
);
$plugin->add_arg(
    spec => 'community|C=s',
    help => '--community
   SNMP community of the server (SNMP v1/2 only)',
    required => 0,
    default => 'public',
);
$plugin->add_arg(
    spec => 'username=s',
    help => '--username
   The securityName for the USM security model (SNMPv3 only)',
    required => 0,
);
$plugin->add_arg(
    spec => 'authpassword=s',
    help => '--authpassword
   The authentication password for SNMPv3',
    required => 0,
);
$plugin->add_arg(
    spec => 'authprotocol=s',
    help => '--authprotocol
   The authentication protocol for SNMPv3 (md5|sha)',
    required => 0,
);
$plugin->add_arg(
    spec => 'privpassword=s',
    help => '--privpassword
   The password for authPriv security level',
    required => 0,
);
$plugin->add_arg(
    spec => 'privprotocol=s',
    help => '--privprotocol
   The private protocol for SNMPv3 (des|aes|aes128|3des|3desde)',
    required => 0,
);
$plugin->add_arg(
    spec => 'servertype=s',
    help => '--servertype
   The type of the network device: rittal (default). Use it if auto-detection
   is not possible',
    required => 0,
);
$plugin->add_arg(
    spec => 'statefilesdir=s',
    help => '--statefilesdir
   An alternate directory where the plugin can save files',
    required => 0,
);
$plugin->add_arg(
    spec => 'snmpwalk=s',
    help => '--snmpwalk
   A file with the output of snmpwalk 1.3.6.1.4.1.3309',
    required => 0,
);
$plugin->add_arg(
    spec => 'snmphelp',
    help => '--snmphelp
   Output the list of OIDs you need to walk for a simulation file',
    required => 0,
);
$plugin->add_arg(
    spec => 'multiline',
    help => '--multiline
   Multiline output',
    required => 0,
);


$plugin->getopts();
if ($plugin->opts->multiline) {
  $ENV{NRPE_MULTILINESUPPORT} = 1;
} else {
  $ENV{NRPE_MULTILINESUPPORT} = 0;
}
if (! $PERFDATA && $plugin->opts->get('perfdata')) {
  $PERFDATA = 1;
}
if ($PERFDATA && $plugin->opts->get('perfdata') &&
    ($plugin->opts->get('perfdata') eq 'short')) {
  $PERFDATA = 2;
}
if ($plugin->opts->snmphelp) {
  my @subtrees = ("1");
  foreach my $mib (keys %{$NWC::Device::mibs_and_oids}) {
    foreach my $table (grep {/Table$/} keys %{$NWC::Device::mibs_and_oids->{$mib
}}) {
      push(@subtrees, $NWC::Device::mibs_and_oids->{$mib}->{$table});
    }
  }
  printf "snmpwalk -On ... %s\n", join(" ", @subtrees);
  printf "snmpwalk -On ... %s\n", join(" ", @subtrees);
  exit 0;
}
if ($plugin->opts->community) {
  if ($plugin->opts->community =~ /^snmpv3(.)(.+)/) {
    my $separator = $1;
    my ($authprotocol, $authpassword, $privprotocol, $privpassword, $username) =
        split(/$separator/, $2);
    $plugin->override_opt('authprotocol', $authprotocol)
        if defined($authprotocol) && $authprotocol;
    $plugin->override_opt('authpassword', $authpassword)
        if defined($authpassword) && $authpassword;
    $plugin->override_opt('privprotocol', $privprotocol)
        if defined($privprotocol) && $privprotocol;
    $plugin->override_opt('privpassword', $privpassword)
        if defined($privpassword) && $privpassword;
    $plugin->override_opt('username', $username)
        if defined($username) && $username;
    $plugin->override_opt('protocol', '3') ;
  }
}
if ($plugin->opts->snmpwalk) {
  $plugin->override_opt('hostname', 'snmpwalk.file')
}
if (! $plugin->opts->statefilesdir) {
  if (exists $ENV{OMD_ROOT}) {
    $plugin->override_opt('statefilesdir', $ENV{OMD_ROOT}."/var/tmp/check_nwc_health");
  } else {
    $plugin->override_opt('statefilesdir', $STATEFILESDIR);
  }
}

$plugin->{messages}->{unknown} = []; # wg. add_message(UNKNOWN,...)

$plugin->{info} = []; # gefrickel

if ($plugin->opts->mode =~ /^my-([^\-.]+)/) {
  my $param = $plugin->opts->mode;
  $param =~ s/\-/::/g;
  push(@modes, [$param, $plugin->opts->mode, undef, 'my extension']);
} elsif ($plugin->opts->mode eq 'encode') {
  my $input = <>;
  chomp $input;
  $input =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
  printf "%s\n", $input;
  exit 0;
} elsif ((! grep { $plugin->opts->mode eq $_ } map { $_->[1] } @modes) &&
    (! grep { $plugin->opts->mode eq $_ } map { defined $_->[2] ? @{$_->[2]} : () } @modes)) {
  printf "UNKNOWN - mode %s\n", $plugin->opts->mode;
  $plugin->opts->print_help();
  exit 3;
}

$SIG{'ALRM'} = sub {
  printf "UNKNOWN - check_nwc_health timed out after %d seconds\n",
      $plugin->opts->timeout;
  exit $ERRORS{UNKNOWN};
};
alarm($plugin->opts->timeout);

$NWC::Device::plugin = $plugin;
$NWC::Device::mode = (
    map { $_->[0] }
    grep {
       ($plugin->opts->mode eq $_->[1]) ||
       ( defined $_->[2] && grep { $plugin->opts->mode eq $_ } @{$_->[2]})
    } @modes
)[0];
my $server = NWC::Device->new( runtime => {

    plugin => $plugin,
    options => {
        servertype => $plugin->opts->servertype,
        verbose => $plugin->opts->verbose,
        customthresholds => $plugin->opts->get('customthresholds'),
        blacklist => $plugin->opts->blacklist,
        celsius => $CELSIUS,
        perfdata => $PERFDATA,
    },
},);
#$server->dumper();
if (! $plugin->check_messages()) {
  $server->init();
  if (! $plugin->check_messages()) {
    $plugin->add_message(OK, $server->get_summary())
        if $server->get_summary();
    $plugin->add_message(OK, $server->get_extendedinfo())
        if $server->get_extendedinfo();
  }
} else {
  $plugin->add_message(CRITICAL, 'wrong device');
}
my ($code, $message) = $plugin->opts->multiline ?
    $plugin->check_messages(join => "\n", join_all => ', ') :
    $plugin->check_messages(join => ', ', join_all => ', ');
$message .= sprintf "\n%s\n", join("\n", @{$NWC::Device::info})
    if $plugin->opts->verbose >= 1;
$plugin->nagios_exit($code, $message);


