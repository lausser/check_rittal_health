package Classes::Rittal::CMCII::Component::SensorSubsystem;
use strict;
our @ISA = qw(GLPlugin::SNMP::Item);

sub init {
  my $self = shift;
  $self->get_snmp_table_objects('RITTAL-CMC-TC-MIB', [
      ['sensors', 'SensorTable', 'Classes::Rittal::CMCII::Component::SensorSubsystem::Sensor', sub { my $o = shift; $o->{unitSensorStatus} ne "notAvail" }],
  ]);
}

sub check {
  my $self = shift;
  if (! $self->check_messages) {
    $self->clear_all();
    $self->add_ok("all sensors are within their range");
  }
}


package Classes::Rittal::CMCII::Component::SensorSubsystem::Sensor;
use strict;
our @ISA = qw(GLPlugin::SNMP::TableItem);

sub finish {
  my $self = shift;
  foreach (keys %{$self}) {
    next if ! /unit\dSensor/;
    if (/unit(\d+)(.*)/) {
      $self->{'unit'.$2} = $self->{$_};
      $self->{unit} = $1;
      delete $self->{$_};
    }
  }
  if ($self->{unitSensorType} =~ /^(temp1LCP|rpm\d+LCP|contrTemp\d+|valveActual|fanSpeed|waterFlow|waterOutTemp|waterInTemp|temp\d+LCP|airTemp\d+LCP|temp\d+LCP)/) {
    bless $self, "Classes::Rittal::CMCII::Component::SensorSubsystem::Sensor::Perf";
  }
}

sub check {
  my $self = shift;
  $self->add_info(sprintf "sensor %d.%d (%s) has status %s",
      $self->{unit}, $self->{unitSensorIndex}, $self->{unitSensorText}, $self->{unitSensorStatus});
  if ($self->{unitSensorStatus} eq "ok") {
    $self->add_ok();
  } elsif ($self->{unitSensorStatus} ne "ok") {
    $self->add_critical();
  }
}

package Classes::Rittal::CMCII::Component::SensorSubsystem::Sensor::Perf;
use strict;
our @ISA = qw(Classes::Rittal::CMCII::Component::SensorSubsystem::Sensor);

sub check {
  my $self = shift;
  $self->SUPER::check();
  my %perfdata = ();
  $perfdata{metric} = sprintf "%d.%d.%s", $self->{unit}, $self->{unitSensorIndex}, $self->{unitSensorText};
  $perfdata{label} = sprintf "%d.%d.%s", $self->{unit}, $self->{unitSensorIndex}, $self->{unitSensorText};
  if ($self->{unitSensorSetWarn}) {
    if ($self->{unitSensorSetLow}) {
      $perfdata{warning} = $self->{unitSensorSetLow}.":".$self->{unitSensorSetWarn};
    } else {
      $perfdata{warning} = $self->{unitSensorSetWarn};
    }
  }
  if ($self->{unitSensorSetHigh}) {
    $perfdata{critical} = $self->{unitSensorSetHigh};
  }
  $perfdata{value} = $self->{unitSensorValue};
  $self->add_perfdata(%perfdata);
}

