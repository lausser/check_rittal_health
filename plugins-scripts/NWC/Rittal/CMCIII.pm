package NWC::Rittal::CMCIII;
our @ISA = qw(NWC::Rittal);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    devices => [],
    timers => [],
    variables => [],
    messages => [],
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  $self->init(%params);
  return $self;
}

sub init {
  my $self = shift;
  my %params = @_;
  $self->{cmcIIIUnitStatus} =
      $self->get_snmp_object('RITTAL-CMC-III-MIB', 'cmcIIIUnitStatus');
  if (! $self->{cmcTcMibCondition}) {
    $self->add_message(CRITICAL,
        'snmpwalk returns no health data (rittal-cmc-mib)');
  }
  foreach (qw(cmcIIIUnitSerial cmcIIIUnitProd cmcIIISetTempUnit
      cmcIIIOverallDevStatus cmcIIINumberOfDevs cmcIIINumberOfVars)) {
    $self->{$_} =
        $self->get_snmp_object('RITTAL-CMC-III-MIB', $_);
  }
  foreach ($self->get_snmp_table_objects(
     'RITTAL-CMC-III-MIB', 'cmcIIIDevTable')) {
    push(@{$self->{devices}}, $_);
  }
  foreach ($self->get_snmp_table_objects(
     'RITTAL-CMC-III-MIB', 'cmcIIIVarTable')) {
    push(@{$self->{variables}}, $_);
  }
  foreach ($self->get_snmp_table_objects(
     'RITTAL-CMC-III-MIB', 'cmcIIIMsgTable')) {
    push(@{$self->{messages}}, $_);
  }
  $self->check();
}

sub check {
  my $self = shift;
  if ($self->mode =~ /device::devices::list/) {
    foreach (@{$self->{devices}}) {
      #printf "dev%d\n", $unit if $self->{"unit$unit"}->{cmcTcUnitStatus} ne "notAvail";
      printf "%s\n", Data::Dumper::Dumper($_);
    }
    $self->add_message(OK, "have fun");
  } elsif ($self->mode =~ /device::variables::list/) {
    foreach (@{$self->{variables}}) {
      printf "%s\n", Data::Dumper::Dumper($_);
    }
    $self->add_message(OK, "have fun");
  } else {
    my $info = sprintf 'cmc-tc has %d units connected, has status %s',
        $self->{cmcTcUnitsConnected}, $self->{cmcTcStatusDeviceCMC};
    $self->add_info($info);
    if ($self->{cmcTcStatusDeviceCMC} eq 'failed') {
      $self->add_message(CRITICAL, sprintf 'general status of cmc-tc is %s',
          $self->{cmcTcStatusDeviceCMC});
    } else {
      $self->add_message(OK, $info);
    }
    $self->dump() if $self->opts->verbose >= 2;;
    $self->check_sensor_units();
  }
}

sub check_sensor_units {
  my $self = shift;
  $self->{unit1}->check();
  $self->{unit2}->check();
  $self->{unit3}->check();
  $self->{unit4}->check();
}

sub dump {
  my $self = shift;
  printf "[CMC-TC]\n";
  foreach (qw(cmcTcStatusDeviceCMC cmcTcUnitsConnected)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
  $self->{unit1}->dump();
  $self->{unit2}->dump();
  $self->{unit3}->dump();
  $self->{unit4}->dump();
}


