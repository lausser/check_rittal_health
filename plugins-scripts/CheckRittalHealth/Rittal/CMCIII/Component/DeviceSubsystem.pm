package CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my $self = shift;
  $self->mult_snmp_max_msg_size(10);
  $self->get_snmp_objects('RITTAL-CMC-III-MIB',
      qw(cmcIIIUnitStatus cmcIIIUnitType cmcIIIUnitSerial
      cmcIIIUnitProd cmcIIISetTempUnit cmcIIIOverallDevStatus
      cmcIIINumberOfDevs cmcIIINumberOfVars));
  $self->get_snmp_tables('RITTAL-CMC-III-MIB', [
      ['devices', 'cmcIIIDevTable', 'CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::Device'],
      ['variables', 'cmcIIIVarTable', 'CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::Variable'],
  ]);
  #if ($self->filter_name($dev->{cmcIIIDevIndex})) {
  $self->assign();
}

sub assign {
  my $self = shift;
  foreach my $dev (@{$self->{devices}}) {
    $dev->{variables} = [];
    foreach my $var (@{$self->{variables}}) {
      if ($dev->{cmcIIIDevIndex} eq $var->{cmcIIIVarDeviceIndex}) {
        push(@{$dev->{variables}}, $var);
      }
    }
    @{$dev->{variables}} = sort {
        $a->{cmcIIIVarIndex} <=> $b->{cmcIIIVarIndex} 
    } @{$dev->{variables}};
  }
  @{$self->{devices}} = sort {
      $a->{cmcIIIDevIndex} <=> $b->{cmcIIIDevIndex}
  } @{$self->{devices}};
  foreach (@{$self->{devices}}) {
    $_->group_variables();
  }
}

sub check {
  my $self = shift;
  if ($self->mode =~ /device::devices::list/) {
    foreach (@{$self->{devices}}) {
      #printf "dev%d\n", $unit if $self->{"unit$unit"}->{cmcTcUnitStatus} ne "notAvail";
      printf "%s\n", Data::Dumper::Dumper($_);
    }
    $self->add_ok("have fun");
  } elsif ($self->mode =~ /device::variables::list/) {
    foreach (@{$self->{variables}}) {
      printf "%s\n", Data::Dumper::Dumper($_);
    }
    $self->add_ok("have fun");
  } elsif ($self->mode =~ /device::(units|sensors)/) {
    my $info = sprintf 'cmc-tc has %d devices connected, device status is %s',
        $self->{cmcIIINumberOfDevs}, $self->{cmcIIIOverallDevStatus};
    $self->add_info($info);
    if ($self->{cmcIIIOverallDevStatus} ne 'ok') {
      $self->add_critical(sprintf 'overall device status is %s',
          $self->{cmcIIIOverallDevStatus});
    } else {
      $self->add_ok();
    }
    foreach (@{$self->{devices}}) {
      $_->check();
    }
    delete $self->{variables};
  } else {
    $self->no_such_mode();
  }
}


package CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::Device;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my $self = shift;
  $self->{cmcIIIDevIndex} = $self->{indices}->[0];
  $self->{perf_variables} = [];
}

sub check {
  my $self = shift;
  $self->add_info(sprintf 'device %d (%s) has status %s',
      $self->{cmcIIIDevIndex}, $self->{cmcIIIDevName},
      $self->{cmcIIIDevStatus});
  if ($self->{cmcIIIDevStatus} ne 'ok') {
    if ($self->{cmcIIIDevStatusText}) {
      $self->add_critical($self->{cmcIIIDevStatusText});
    } else {
      $self->add_critical();
    }
  }
  foreach (@{$self->{variables}}) {
    $_->check();
  }
  foreach (@{$self->{perf_variables}}) {
    $_->check();
  }
}

sub group_variables {
  my $self = shift;
  my $perf_variables = {};
  my $group_names = {};
  foreach (@{$self->{variables}}) {
    if ($_->{cmcIIIVarName} =~ /^([\w\.]*(Temperature|Supply|Humidity))\.(.*)/) {
      # Air.Temperature.DescName
      # Air.Temperature.In-Mid
      # Air.Temperature.Out-Mid
      # Air.Temperature.Status
      # ...
      # System.Temperature.DescName
      # System.Temperature.Value
      # System.Temperature.Status
      # ...
      # Temperature.DescName
      # Temperature.Value
      # Temperature.Status
      # ...
      my $var_item = $1;
      my $var_var = $3;
      $perf_variables->{$var_item} = {} if ! exists $perf_variables->{$var_item};
      $perf_variables->{$var_item}->{$var_var} = $_->{cmcIIIVarValueStr};
      if ($var_var eq "Status" and exists $perf_variables->{$var_item} and exists $perf_variables->{$var_item}->{DescName} and  $perf_variables->{$var_item}->{DescName} =~ /Temperatures/) {
        # z.b. Air-Temperatures. So ein Dings hat keine Variable *.Value
        # wie es sie bei "normalen" XY*Temperature.Value gibt.
        # Denn Air-Temperatures hat haufenweise Oben/unten/linkshinten-Werte
        # die allesamt eine eigene Tempratur angeben.
        # Hier ist daher .Status verantwortlich, den perfvariablen die
        # die cmcIII-Zuordnung zu verpassen. Ob wie hier in einer Status-Var
        # sind, deren Schwester-Var Air.Temperature.DescName einen ValueStr
        # von ...Temperatures (Plural) hatte, entscheidet.
        $perf_variables->{$var_item}->{cmcIIIVarGroupName} = $var_item;
        $perf_variables->{$var_item}->{cmcIIIVarDeviceIndex} = $_->{cmcIIIVarDeviceIndex};
        $perf_variables->{$var_item}->{cmcIIIVarUnit} = $_->{cmcIIIVarUnit};
        $group_names->{$_->{cmcIIIVarName}} = 1;
      } elsif ($var_var ne "Value" and index($_->{cmcIIIVarUnit}, "degree") != -1) {
        # das sind jetzt die "Values" so eines Multi-Temperatur-Dingens
        # Im Gegensatz zu dem naechsten elsif, der einen Satz Variablen
        # gruppiert, welche nur eine .Value haben
        if ($_->{cmcIIIVarScale} > 0) {
          $perf_variables->{$var_item}->{$var_var} =
              $_->{cmcIIIVarValueInt} * $_->{cmcIIIVarScale};
        } elsif ($_->{cmcIIIVarScale} < 0) {
          $perf_variables->{$var_item}->{$var_var} =
              $_->{cmcIIIVarValueInt} / abs($_->{cmcIIIVarScale});
        } else {
          $perf_variables->{$var_item}->{$var_var} = $_->{cmcIIIVarValueInt};
        }
        # later in the check, we need to know which of the attributes of
        # a VariableGroup is a metric
        if (! exists $perf_variables->{$var_item}->{perf_vars}) {
          $perf_variables->{$var_item}->{perf_vars} = [];
        } else {
          push(@{$perf_variables->{$var_item}->{perf_vars}}, $var_var);
        }
      } elsif ($var_var eq "Value") {
        # variable is cmcIIIVarName: Temperature.Value
        # cmcIIIVarValueStr is pretty ok, like
        # cmcIIIVarValueStr: 26.80 degree C
        # but we can do better:
        if ($_->{cmcIIIVarScale} > 0) {
          $perf_variables->{$var_item}->{$var_var} =
              $_->{cmcIIIVarValueInt} * $_->{cmcIIIVarScale};
        } elsif ($_->{cmcIIIVarScale} < 0) {
          $perf_variables->{$var_item}->{$var_var} =
              $_->{cmcIIIVarValueInt} / abs($_->{cmcIIIVarScale});
        } else {
          $perf_variables->{$var_item}->{$var_var} = $_->{cmcIIIVarValueInt};
        }
        $perf_variables->{$var_item}->{cmcIIIVarGroupName} = $var_item;
        $perf_variables->{$var_item}->{cmcIIIVarDeviceIndex} = $_->{cmcIIIVarDeviceIndex};
        $perf_variables->{$var_item}->{cmcIIIVarUnit} = $_->{cmcIIIVarUnit};
        $group_names->{$_->{cmcIIIVarName}} = 1;
      }
    } elsif ($_->{cmcIIIVarName} =~ /^([\w\.]*(Leakage))\.(.*)/ or
        $_->{cmcIIIVarName} =~ /^([\w\.]*(Temperature|Supply|Humidity))\.(.*)/) {
      # there is no variable cmcIIIVarName: Leakage.Value
      # we need to work with cmcIIIVarName: Leakage.Status
      # which has cmcIIIVarType: status, cmcIIIVarValueStr: OK and
      # cmcIIIVarValueInt: 4, whatever this value means. 
      my $var_item = $1;
      my $var_var = $3;
      if ($var_var eq "Status") {
        $perf_variables->{$var_item} = {} if ! exists $perf_variables->{$var_item};
        $perf_variables->{$var_item}->{$var_var} = $_->{cmcIIIVarValueStr};
        $perf_variables->{$var_item}->{Value} = $_->{cmcIIIVarValueInt};
        $perf_variables->{$var_item}->{cmcIIIVarGroupName} = $var_item;
        $perf_variables->{$var_item}->{cmcIIIVarDeviceIndex} = $_->{cmcIIIVarDeviceIndex};
        $perf_variables->{$var_item}->{cmcIIIVarUnit} = $_->{cmcIIIVarUnit};
        $group_names->{$_->{cmcIIIVarName}} = 1;
      }
    }
  }
  foreach (sort keys %{$perf_variables}) {
    push(@{$self->{perf_variables}}, 
        CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::VariableGroup->new(%{$perf_variables->{$_}}));
  }
  #@{$self->{variables}} = grep { ! exists $group_names->{$_->{cmcIIIVarName}} } @{$self->{variables}};
}


package CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::Variable;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my $self = shift;
  $self->{cmcIIIVarDeviceIndex} = $self->{indices}->[0];
  $self->{cmcIIIVarIndex} = $self->{indices}->[1];
  if ($self->{cmcIIIVarValueStr} =~ /^(?:[0-9a-f]{2} )+[0-9a-f]{2}$/i) {
    $self->{cmcIIIVarValueStr} =~ s/\s//g;
    $self->{cmcIIIVarValueStr} =~ s/(([0-9a-f][0-9a-f])+)/pack('H*', $1)/ie;
  }
  if ($self->{cmcIIIVarUnit} =~ /^(?:[0-9a-f]{2} )+[0-9a-f]{2}$/i) {
    $self->{cmcIIIVarUnit} =~ s/\s//g;
    $self->{cmcIIIVarUnit} =~ s/(([0-9a-f][0-9a-f])+)/pack('H*', $1)/ie;
  }
}

sub check {
  my $self = shift;
  $self->add_info(sprintf 'var %d/%d (%s) has status %s',
      $self->{cmcIIIVarDeviceIndex}, $self->{cmcIIIVarIndex},
      $self->{cmcIIIVarName}, $self->{cmcIIIVarValueStr});
}

package CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::VariableGroup;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my $self = shift;
  $self->{DescName} ||= $self->{cmcIIIVarGroupName}; # undef ist mir schon untergekommen
#
#
# JA TOLL, GENAU DANN, WENN ICH DEN SCHEISS AUSROLLEN WILL, KOMMT SOWAS DAHER:
#$VAR1 = bless( {
#  'DescName' => 'Air-Temperatures',
#  'Out-Top' => '27.2 degree C',
#  'Status' => 'OK',
#  'name' => 'dev__Air-Temperatures',
#  'Out-Mid' => '26.6 degree C',
#  'In-Mid' => '18.7 degree C',
#  'In-Top' => '18.0 degree C',
#  'Category' => '2 ',
#  'Out-Bot' => '28.0 degree C',
#  'In-Bot' => '19.5 degree C'
#}, 'CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::VariableGroup' );
#
#
  $self->{name} = "dev ".$self->{cmcIIIVarDeviceIndex}." ".$self->{DescName};
  $self->{name} =~ s/\s/_/g;
  foreach (qw(cmcIIIVarUnit)) {
    if (defined $self->{$_}) {
      $self->{$_} =~ s/[^%\w]//g;
    }
  }
  foreach (qw(SetPtHighAlarm SetPtHighWarning SetPtLowAlarm SetPtLowWarning Value cmcIIIVarUnit)) {
    if (defined $self->{$_}) {
      $self->{$_} =~ s/^(-*[\d\.]+).*/$1/g;
    }
  }
  if ($self->{cmcIIIVarGroupName} =~ /Temperature/ and $self->{DescName} =~ /Temperatures/) {
    bless $self, 'CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::MultiTemperatureGroup';
  } elsif ($self->{cmcIIIVarGroupName} =~ /Temperature/) {
    bless $self, 'CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::TemperatureGroup';
  } elsif ($self->{cmcIIIVarGroupName} =~ /Humidity/) {
    bless $self, 'CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::HumidityGroup';
  } elsif ($self->{cmcIIIVarGroupName} =~ /Supply/) {
    bless $self, 'CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::SupplyGroup';
  } elsif ($self->{cmcIIIVarGroupName} =~ /Leakage/) {
    bless $self, 'CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::LeakageGroup';
  }
}

sub check {
  my $self = shift;
  $self->set_thresholds(metric => $self->{name},
      warning => $self->{SetPtLowWarning}.":".$self->{SetPtHighWarning},
      critical => $self->{SetPtLowAlarm}.":".$self->{SetPtHighAlarm});
  $self->add_perfdata(label => $self->{name},
      uom => $self->{cmcIIIVarUnit} eq "%" ? 
          $self->{cmcIIIVarUnit} : undef,
      value => $self->{Value});
}

package CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::TemperatureGroup;
our @ISA = qw(CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::VariableGroup);
use strict;

package CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::MultiTemperatureGroup;
our @ISA = qw(CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::VariableGroup);
use strict;

sub check {
  my $self = shift;
  foreach (@{$self->{perf_vars}}) {
    $self->add_perfdata(label => $self->{name}.'_'.$_,
        value => $self->{$_});
  }
}

package CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::HumidityGroup;
our @ISA = qw(CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::VariableGroup);
use strict;

package CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::SupplyGroup;
our @ISA = qw(CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::VariableGroup);
use strict;

package CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::LeakageGroup;
our @ISA = qw(CheckRittalHealth::Rittal::CMCIII::Component::DeviceSubsystem::VariableGroup);
use strict;

sub check {
  my $self = shift;
  $self->add_info(sprintf '%s has status %s',
      $self->{name}, $self->{Status}
  );
  if ($self->{Status} ne "OK" and $self->{Status} ne "n.a.") {
    $self->add_critical();
  }
  # Zum Kotzen sowas. Weil einer unbedingt seine Lecksensoren im Grafana
  # anzeigen will. Wozu gibt's eigentlich Monitoring?
  # Wenn Nagios Alarm schlägt, dann hol Eimer und Lappen und wisch auf!
  # Aber die Herrschaften starren lieber auf Dashboards und kommen
  # sich cool vor. Wie mich das ankotzt :-(((
  $self->add_perfdata(label => $self->{name},
      value => $self->{Status} eq "OK" ? 0 : 1,
  ) if $self->{Status} ne "n.a.";
}


