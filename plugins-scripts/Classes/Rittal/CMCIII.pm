package Classes::Rittal::CMCIII;
use strict;
our @ISA = qw(Classes::Rittal);

sub init {
  my $self = shift;
  my %params = @_;
  $self->{cmcIIIUnitStatus} =
      $self->get_snmp_object('RITTAL-CMC-III-MIB', 'cmcIIIUnitStatus');
  if (! $self->{cmcIIIUnitStatus}) {
    $self->add_critical('snmpwalk returns no health data (rittal-cmc-mib)');
  }
  foreach (qw(cmcIIIUnitType cmcIIIUnitSerial cmcIIIUnitProd cmcIIISetTempUnit
      cmcIIIOverallDevStatus cmcIIINumberOfDevs cmcIIINumberOfVars cmcIIIOverallMsgStatus)) {
    $self->{$_} =
        $self->get_snmp_object('RITTAL-CMC-III-MIB', $_);
  }
  foreach ($self->get_snmp_table_objects(
     'RITTAL-CMC-III-MIB', 'cmcIIIDevTable')) {
    my $dev = Classes::Rittal::CMCIII::Device->new(%{$_});
    if ($self->filter_name($dev->{cmcIIIDevIndex})) {
      push(@{$self->{devices}}, $dev);
    }
  }
  foreach ($self->get_snmp_table_objects(
     'RITTAL-CMC-III-MIB', 'cmcIIIVarTable')) {
    my $var = Classes::Rittal::CMCIII::Variable->new(%{$_});
    if ($self->filter_name($var->{cmcIIIVarDeviceIndex})) {
      push(@{$self->{variables}}, $var);
    }
  }
  $self->assign();
  $self->check();
}

sub assign {
  my $self = shift;
  foreach my $dev (@{$self->{devices}}) {
    $dev->{variables} = [];
    foreach my $var (
        sort {$a->{cmcIIIVarDeviceIndex} <=> $b->{cmcIIIVarDeviceIndex}}
        @{$self->{variables}}) {
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
our @ISA = qw(Classes::Rittal::CMCIII);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  foreach my $param (keys %params) {
    if (exists $params{$param}) {
      $self->{$param} = $params{$param};
    }
  }
  $self->{cmcIIIDevIndex} = $self->{indices}->[0];
  delete $self->{indices};
  bless $self, $class;
  #if ($self->{unitSensorType} eq 'temperature') {
  #  bless $self, 'Classes::Rittal::CMCII::TemperatureSensor';
  #}
  #$self->init(%params);
  return $self;
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

sub dump {
  my $self = shift;
  printf "[DEVICE_%d]\n",
      $self->{cmcIIIDevIndex};
  foreach (grep /^cmcIII/, keys %{$self}) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  foreach (@{$self->{variables}}) {
    $_->dump();
  }
  printf "\n";
}


package Classes::Rittal::CMCIII::Variable;
our @ISA = qw(Classes::Rittal::CMCIII);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  foreach my $param (keys %params) {
    if (exists $params{$param}) {
      $self->{$param} = $params{$param};
    }
  }
  $self->{cmcIIIVarDeviceIndex} = $self->{indices}->[0];
  $self->{cmcIIIVarIndex} = $self->{indices}->[1];
  delete $self->{indices};
  bless $self, $class;
  #if ($self->{unitSensorType} eq 'temperature') {
  #  bless $self, 'Classes::Rittal::CMCII::TemperatureSensor';
  #}
  #$self->init(%params);
  return $self;
}


sub check {
  my $self = shift;
  $self->add_info(sprintf 'var %d/%d (%s) has status %s',
      $self->{cmcIIIVarDeviceIndex}, $self->{cmcIIIVarIndex},
      $self->{cmcIIIVarName}, $self->{cmcIIIVarValueStr});
}

sub dump {
  my $self = shift;
  printf "[VARIABLE_%d_%d]\n",
      $self->{cmcIIIVarDeviceIndex}, $self->{cmcIIIVarIndex};
  foreach (grep /^cmcIIIVar/, keys %{$self}) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";

}
