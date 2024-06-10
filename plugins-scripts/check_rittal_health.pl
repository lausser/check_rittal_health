package CheckRittalHealth;
use strict;
no warnings qw(once);

sub run_plugin {
  my $plugin_class = (caller(0))[0]."::Device";
  if ( ! grep /BEGIN/, keys %Monitoring::GLPlugin::) {
    eval {
      require Monitoring::GLPlugin;
      require Monitoring::GLPlugin::SNMP;
    };
    if ($@) {
      printf "UNKNOWN - module Monitoring::GLPlugin was not found. Either build a standalone version of this plugin or set PERL5LIB\n";
      printf "%s\n", $@;
      exit 3;
    }
  }
  my $plugin = $plugin_class->new(
      shortname => '',
      usage => 'Usage: %s [ -v|--verbose ] [ -t <timeout> ] '.
          '--mode <what-to-do> '.
          '--hostname <network-component> --community <snmp-community>'.
          '  ...]',
      version => '$Revision: #PACKAGE_VERSION# $',
      blurb => 'This plugin checks various parameters of rittal cmc ',
      url => 'http://labs.consol.de/nagios/check_rittal_health',
      timeout => 60,
  );

  $plugin->add_mode(
      internal => 'device::sensors::health',
      spec => 'hardware-health',
      alias => ['overall-health'],
      help => 'Check the state of the sensors',
  );
  $plugin->add_mode(
      internal => 'device::units::list',
      spec => 'list-units',
      alias => undef,
      help => 'Show the units of the cmc ii and update the name cache',
  );
  $plugin->add_mode(
      internal => 'device::sensors::list',
      spec => 'list-sensors',
      alias => undef,
      help => 'Show the sensors of the cmc ii and update the name cache',
  );
  $plugin->add_mode(
      internal => 'device::devices::list',
      spec => 'list-devices',
      alias => undef,
      help => 'Show the devices of the cmc ii and update the name cache',
  );
  $plugin->add_snmp_modes();
  $plugin->add_snmp_args();
  $plugin->add_default_args();
  $plugin->mod_arg("name",
      help => "--name
     The name (number) of a unit",
  );
  $plugin->mod_arg("name2",
      help => "--name2
     The name (number) of a sensor",
  );
  
  $plugin->getopts();
  $plugin->classify();
  $plugin->validate_args();

  if (! $plugin->check_messages()) {
    $plugin->init();
    if (! $plugin->check_messages()) {
      $plugin->add_ok($plugin->get_summary())
          if $plugin->get_summary();
      $plugin->add_ok($plugin->get_extendedinfo(" "))
          if $plugin->get_extendedinfo();
    }
  }
  my ($code, $message) = $plugin->opts->multiline ?
      $plugin->check_messages(join => "\n", join_all => ', ') :
      $plugin->check_messages(join => ', ', join_all => ', ');
  $message .= sprintf "\n%s\n", $plugin->get_info("\n")
      if $plugin->opts->verbose >= 1;

  $plugin->nagios_exit($code, $message);
}

1;

join('', map { ucfirst } split(/_/, (split(/\//, (split ' ', "check_rittal_health" // '')[0]))[-1]))->run_plugin();
