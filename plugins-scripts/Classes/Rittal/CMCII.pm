package Classes::Rittal::CMCII;
use strict;
our @ISA = qw(Classes::Rittal);


sub init {
  my $self = shift;
  $self->get_snmp_objects('RITTAL-CMC-TC-MIB',
      qw(cmcTcMibCondition cmcTcStatusDeviceCMC cmcTcUnitsConnected));
  if (! $self->{cmcTcMibCondition}) {
    $self->add_critical('snmpwalk returns no health data (rittal-cmc-mib)');
  }
  if ($self->mode =~ /device::hardware::health/) {
    $self->analyze_and_check_unit_subsystem('Classes::Rittal::CMCII::Components::UnitSubsystem');
  }
}



