package Classes::Rittal::CMCIII::Component::DeviceSubsystem;
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
      ['devices', 'cmcIIIDevTable', 'Classes::Rittal::CMCIII::Component::DeviceSubsystem::Device'],
      ['variables', 'cmcIIIVarTable', 'Classes::Rittal::CMCIII::Component::DeviceSubsystem::Variable'],
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


package Classes::Rittal::CMCIII::Component::DeviceSubsystem::Device;
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
      $perf_variables->{$1} = {} if ! exists $perf_variables->{$1};
      $perf_variables->{$1}->{$3} = $_->{cmcIIIVarValueStr};
      if ($3 eq "Value") {
        $perf_variables->{$1}->{cmcIIIVarGroupName} = $1;
        $perf_variables->{$1}->{cmcIIIVarDeviceIndex} = $_->{cmcIIIVarDeviceIndex};
        $perf_variables->{$1}->{cmcIIIVarUnit} = $_->{cmcIIIVarUnit};
        $group_names->{$_->{cmcIIIVarName}} = 1;
      }
    }
  }
  foreach (sort keys %{$perf_variables}) {
    push(@{$self->{perf_variables}}, 
        Classes::Rittal::CMCIII::Component::DeviceSubsystem::VariableGroup->new(%{$perf_variables->{$_}}));
  }
  #@{$self->{variables}} = grep { ! exists $group_names->{$_->{cmcIIIVarName}} } @{$self->{variables}};
}


package Classes::Rittal::CMCIII::Component::DeviceSubsystem::Variable;
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

package Classes::Rittal::CMCIII::Component::DeviceSubsystem::VariableGroup;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my $self = shift;
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
  if ($self->{cmcIIIVarGroupName} =~ /Temperature/) {
    bless $self, 'Classes::Rittal::CMCIII::Component::DeviceSubsystem::TemperatureGroup';
  } elsif ($self->{cmcIIIVarGroupName} =~ /Humidity/) {
    bless $self, 'Classes::Rittal::CMCIII::Component::DeviceSubsystem::HumidityGroup';
  } elsif ($self->{cmcIIIVarGroupName} =~ /Supply/) {
    bless $self, 'Classes::Rittal::CMCIII::Component::DeviceSubsystem::SupplyGroup';
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

package Classes::Rittal::CMCIII::Component::DeviceSubsystem::TemperatureGroup;
our @ISA = qw(Classes::Rittal::CMCIII::Component::DeviceSubsystem::VariableGroup);
use strict;

package Classes::Rittal::CMCIII::Component::DeviceSubsystem::HumidityGroup;
our @ISA = qw(Classes::Rittal::CMCIII::Component::DeviceSubsystem::VariableGroup);
use strict;

package Classes::Rittal::CMCIII::Component::DeviceSubsystem::SupplyGroup;
our @ISA = qw(Classes::Rittal::CMCIII::Component::DeviceSubsystem::VariableGroup);
use strict;

