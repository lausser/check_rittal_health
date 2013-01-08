package NWC::Rittal::CMCII;
our @ISA = qw(NWC::Rittal);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    unit1 => undef,
    unit2 => undef,
    unit3 => undef,
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
  $self->{cmcTcMibCondition} =
      $self->get_snmp_object('RITTAL-CMC-TC-MIB', 'cmcTcMibCondition');
  if (! $self->{cmcTcMibCondition}) {
    $self->add_message(CRITICAL,
        'snmpwalk returns no health data (rittal-cmc-mib)');
  }
  $self->{cmcTcStatusDeviceCMC} = $self->get_snmp_object('RITTAL-CMC-TC-MIB', 'cmcTcStatusDeviceCMC');
  $self->{cmcTcUnitsConnected} = $self->get_snmp_object('RITTAL-CMC-TC-MIB', 'cmcTcUnitsConnected');
  $params{unitnr} = 1;
  $self->{unit1} = NWC::Rittal::CMCII::Unit->new(%params);
  $params{unitnr} = 2;
  $self->{unit2} = NWC::Rittal::CMCII::Unit->new(%params);
  $params{unitnr} = 3;
  $self->{unit3} = NWC::Rittal::CMCII::Unit->new(%params);
  $params{unitnr} = 4;
  $self->{unit4} = NWC::Rittal::CMCII::Unit->new(%params);
  $self->check();
}

sub check {
  my $self = shift;
  if ($self->mode =~ /device::units::list/) {
    for my $unit (1..4) {
      printf "unit%d\n", $unit if $self->{"unit$unit"}->{cmcTcUnitStatus} ne "notAvail";
    }
  } elsif ($self->mode =~ /device::sensors::list/) {
    for my $unit (1..4) {
      $self->{"unit$unit"}->list() if $self->{"unit$unit"}->{cmcTcUnitStatus} ne "notAvail";;
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


