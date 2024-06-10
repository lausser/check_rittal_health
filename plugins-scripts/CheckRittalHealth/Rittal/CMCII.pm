package CheckRittalHealth::Rittal::CMCII;
use strict;
our @ISA = qw(CheckRittalHealth::Rittal);


sub init {
  my $self = shift;
  $self->get_snmp_objects('RITTAL-CMC-TC-MIB',
      qw(cmcTcMibCondition cmcTcStatusDeviceCMC cmcTcUnitsConnected));
  if (! $self->{cmcTcMibCondition}) {
    $self->add_critical('snmpwalk returns no health data (rittal-cmc-mib)');
  }
  if ($self->mode =~ /device::(units|sensors)/) {
    if ($self->{cmcTcMibCondition} ne "ok") {
      $self->add_warning(sprintf "mib condition is %s fault", $self->{cmcTcMibCondition});
    }
    $self->analyze_and_check_unit_subsystem('CheckRittalHealth::Rittal::CMCII::Component::UnitSubsystem');
  } else {
    $self->no_such_mode();
  }
}



