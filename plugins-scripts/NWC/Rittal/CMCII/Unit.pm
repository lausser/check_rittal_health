package NWC::Rittal::CMCII::Unit;
our @ISA = qw(NWC::Rittal::CMCII);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    sensors => [],
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
  my $unit = $params{unitnr};
  $self->{cmcTcUnitNumber} = $unit;
  $self->{cmcTcUnitTypeOfDevice} =
      $self->get_snmp_object('RITTAL-CMC-TC-MIB', 'cmcTcUnit'.$unit.'TypeOfDevice');
  $self->{cmcTcUnitText} =
      $self->get_snmp_object('RITTAL-CMC-TC-MIB', 'cmcTcUnit'.$unit.'Text');
  $self->{cmcTcUnitStatus} =
      $self->get_snmp_object('RITTAL-CMC-TC-MIB', 'cmcTcUnit'.$unit.'Status');
  $self->{cmcTcUnitNumberOfSensors} =
      $self->get_snmp_object('RITTAL-CMC-TC-MIB', 'cmcTcUnit'.$unit.'NumberOfSensors');
#printf "%s\n", Data::Dumper::Dumper($self);
  # although unit4 is defined in the mib, it doesn't exist in reality

  $self->add_info(sprintf 'unit %d has status %s',
      $unit, $self->{cmcTcUnitStatus});
  if ($self->{cmcTcUnitStatus} ne "not Avail") {
    foreach ($self->get_snmp_table_objects(
       'RITTAL-CMC-TC-MIB', 'cmcTcUnit'.$unit.'SensorTable')) {
      foreach my $k (keys %{$_}) {
        if ($k =~ /unit$unit/) {
          (my $nokey = $k) =~ s/unit$unit/unit/g;
          $_->{$nokey} = $_->{$k};
          #delete $_->{$k};
        }
      }
      $_->{unitSensorUnit} = $unit;
#printf "%s\n", Data::Dumper::Dumper($_);
      push(@{$self->{sensors}},
          NWC::Rittal::CMCII::Sensor->new(%{$_}));
    }
  }
}

sub check {
  my $self = shift;
  my %params = @_;
  printf "am arch\n";
}

sub dump {
  my $self = shift;
  printf "[CMC-TC-UNIT-%d]\n", $self->{cmcTcUnitNumber};
  foreach (qw(cmcTcUnitTypeOfDevice cmcTcUnitText cmcTcUnitStatus cmcTcUnitNumberOfSensors)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
  foreach (@{$self->{sensors}}) {
    $_->dump();
  }
}

sub list {
  my $self = shift;
  foreach (sort {$a->{unitSensorIndex} <=> $b->{unitSensorIndex}} @{$self->{sensors}}) {
    $_->list();
  }
}

1;
