package Classes::Rittal::CMCII::Component::SensorSubsystem;
use strict;
our @ISA = qw(GLPlugin::SNMP::Item);

sub init {
  my $self = shift;
  $self->get_snmp_table_objects('RITTAL-CMC-TC-MIB', [
      ['sensors', 'SensorTable', 'Classes::Rittal::CMCII::Component::SensorSubsystem::Sensor', sub { my $o = shift; $o->{unitSensorStatus} ne "notAvail" }],
  ]);
}


package Classes::Rittal::CMCII::Component::SensorSubsystem::Sensor;
use strict;
our @ISA = qw(GLPlugin::SNMP::TableItem);

sub finish {
  my $self = shift;
  foreach (keys %{$self}) {
    next if ! /unit\dSensor/;
    if (/unit\d+(.*)/) {
      $self->{'unit'.$1} = $self->{$_};
      delete $self->{$_};
    }
  }
}
