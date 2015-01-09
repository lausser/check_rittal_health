package Classes::Rittal::CMCIII::Component::DeviceSubsystem;
our @ISA = qw(GLPlugin::SNMP::Item);
use strict;

sub init {
  my $self = shift;
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
our @ISA = qw(GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my $self = shift;
  $self->{cmcIIIDevIndex} = $self->{indices}->[0];
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
}


package Classes::Rittal::CMCIII::Component::DeviceSubsystem::Variable;
our @ISA = qw(GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my $self = shift;
  $self->{cmcIIIVarDeviceIndex} = $self->{indices}->[0];
  $self->{cmcIIIVarIndex} = $self->{indices}->[1];
}

sub check {
  my $self = shift;
  $self->add_info(sprintf 'var %d/%d (%s) has status %s',
      $self->{cmcIIIVarDeviceIndex}, $self->{cmcIIIVarIndex},
      $self->{cmcIIIVarName}, $self->{cmcIIIVarValueStr});
}

