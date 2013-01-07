package NWC::Rittal::CMCII::Sensor;

our @ISA = qw(NWC::Rittal::CMCII::Unit);

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
  foreach my $param (qw(unitSensorIndex unitSensorText unitSensorStatus
      unitSensorType unitSensorValue unitSensorSetLow
      unitSensorSetWarn unitSensorSetHigh)) {
    if (exists $params{$param}) {
      $self->{$param} = $params{$param};
    }
  }
  bless $self, $class;
  if ($self->{unitSensorType} eq 'temperature') {
    bless $self, 'Rittal::CMCII::TemperatureSensor';
  }
  #$self->init(%params);
  return $self;
}


sub check {
  my $self = shift;
  $self->add_info(sprintf 'sensor %d (%s) has status %s',
      $self->{unitSensorIndex}, $self->{unitSensorType},
      $self->{unitSensorStatus});
}

sub dump {
  my $self = shift;
  printf "[SENSOR_%d_%d]\n", 
      $self->{unitSensorUnit},
      $self->{unitSensorIndex};
  foreach (qw(unitSensorIndex unitSensorText unitSensorStatus
      unitSensorType unitSensorValue unitSensorSetLow
      unitSensorSetWarn unitSensorSetHigh)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";

}

1;
