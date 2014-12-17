package Classes::Rittal::CMCII::UnitSubsystem;
use strict;
our @ISA = qw(GLPlugin::SNMP::Item);

sub init {
  my $self = shift;
  $self->{unit1} = Classes::Rittal::CMCII::UnitSubsystem::Unit->new(1);
  $self->{unit2} = Classes::Rittal::CMCII::UnitSubsystem::Unit->new(2);
  $self->{unit3} = Classes::Rittal::CMCII::UnitSubsystem::Unit->new(3);
  $self->{unit4} = Classes::Rittal::CMCII::UnitSubsystem::Unit->new(4);
}

package Classes::Rittal::CMCII::UnitSubsystem::Unit;
use strict;
our @ISA = qw(GLPlugin::SNMP::Item);

sub init {
  my $self = shift;
  my $unit = shift;
  $self->get_snmp_objects('RITTAL-CMC-TC-MIB', (
      'cmcTcUnit'.$unit.'TypeOfDevice',
      'cmcTcUnit'.$unit.'Text',
      'cmcTcUnit'.$unit.'Status',
      'cmcTcUnit'.$unit.'NumberOfSensors'
  );
  $self->add_info(sprintf 'unit %d has status %s',
      $unit, $self->{'cmcTcUnit'.$unit.'Status'});
  if ($self->{'cmcTcUnit'.$unit.'Status'} ne "not Avail") {
    $self->get_snmp_table_objects('RITTAL-CMC-TC-MIB', [
        ['sensors', 'SensorTable', 'Classes::Rittal::CMCII::SensorSubsystem::Sensor'],
    ]);
  }
}


