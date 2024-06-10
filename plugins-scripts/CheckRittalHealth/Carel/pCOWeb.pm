package CheckRittalHealth::Carel::pCOWeb;
use strict;
our @ISA = qw(CheckRittalHealth::Carel);


sub init {
  my $self = shift;
  if ($self->mode =~ /device::(sensors)/) {
die;
    $self->analyze_and_check_sensor_subsystem('CheckRittalHealth::Carel::pCOWeb::Component::SensorSubsystem');
  } else {
    $self->no_such_mode();
  }
}



