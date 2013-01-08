package NWC::Rittal::CMCII::TemperatureSensor;

our @ISA = qw(NWC::Rittal::CMCII::Sensor);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub check {
  my $self = shift;
  $self->add_info(sprintf 'sensor %d (%s) has status %s, %dC',
      $self->{unitSensorIndex}, $self->{unitSensorType},
      $self->{unitSensorStatus}, $self->{unitSensorValue});
  $self->{runtime}->{plugin}->add_perfdata(
    label => sprintf('temp_%d_%d', $self->{unitSensorUnit},
        $self->{unitSensorIndex}),
    value => $self->{unitSensorValue},
    warning => $self->{unitSensorSetWarn},
    critical => $self->{unitSensorSetHigh},
  );
}

1;
