package Classes::Rittal::CMCIII;
use strict;
our @ISA = qw(Classes::Rittal);

sub init {
  my $self = shift;
  $self->get_snmp_objects('RITTAL-CMC-III-MIB',
      qw(cmcIIIUnitStatus cmcIIIUnitType cmcIIIUnitSerial 
      cmcIIIUnitProd cmcIIISetTempUnit cmcIIIOverallDevStatus
      cmcIIINumberOfDevs cmcIIINumberOfVars cmcIIIOverallMsgStatus));
  if (! $self->{cmcIIIUnitStatus}) {
    $self->add_critical('snmpwalk returns no health data (rittal-cmc-mib)');
  }
  $self->get_snmp_tables('RITTAL-CMC-III-MIB', [
      ['devices', 'cmcIIIDevTable', 'GLPlugin::SNMP::TableItem'],
      ['variables', 'cmcIIIVarTable', 'GLPlugin::SNMP::TableItem'],
  ]);
    #if ($self->filter_name($dev->{cmcIIIDevIndex})) {

  $self->assign();
  $self->check();
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
  } else {
    my $info = sprintf 'cmc-tc has %d devices connected, has status %s',
        $self->{cmcIIINumberOfDevs}, $self->{cmcIIIOverallDevStatus};
    $self->add_info($info);
    if ($self->{cmcIIIOverallMsgStatus} ne 'ok') {
      $self->add_critical(sprintf 'general status is %s',
          $self->{cmcIIIOverallMsgStatus});
    } else {
      $self->add_ok();
    }
    $self->check_devices();
    $self->dump() if $self->opts->verbose >= 2;;
  }
}

sub check_devices {
  my $self = shift;
  foreach (@{$self->{devices}}) {
    $_->check();
  }
}

sub dump {
  my $self = shift;
  printf "[CMC-TC]\n";
  foreach (qw(cmcIIIUnitType cmcIIIUnitSerial cmcIIIUnitProd cmcIIISetTempUnit
      cmcIIIOverallDevStatus cmcIIINumberOfDevs cmcIIINumberOfVars)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
  foreach (@{$self->{devices}}) {
    $_->dump();
  }
}

package Classes::Rittal::CMCIII::Device;
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
  foreach (@{$self->{variables}}) {
    $_->check();
  }
}


package Classes::Rittal::CMCIII::Variable;
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

