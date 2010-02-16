package Rittal::CMCTC::Unit::Sensor;

our @ISA = qw(Rittal::CMCTC::Unit);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class  = shift;
  my %params = @_;
  my $self   = {
    runtime      => $params{runtime},
    rawdata      => $params{rawdata},
    unitSensorUnit => $params{unitSensorUnit},

    blacklisted  => 0,
    info         => undef,
    extendedinfo => undef,
  };
  foreach (grep /^unit\d+/, keys %params) {
    my $tmpkey = $_;
    $tmpkey =~ s/unit\d+/unit/;
    $self->{$tmpkey} = $params{$_};
  }
  $self->{unitSensorValue} = $self->{unitSensorVal};
  delete $self->{unitSensorVal}; # das kommt von der Sonderrolle von ...Value
  bless $self, $class;
  if ($self->{unitSensorType} eq 'temperature') {
    bless $self, 'Rittal::CMCTC::Unit::TemperatureSensor';
  }
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
