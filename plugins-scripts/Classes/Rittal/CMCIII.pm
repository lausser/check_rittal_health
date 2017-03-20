package Classes::Rittal::CMCIII;
our @ISA = qw(Classes::Rittal);
use strict;


sub init {
  my $self = shift;
  if ($self->mode =~ /device::(units|sensors)/) {
    $self->get_snmp_objects('RITTAL-CMC-III-MIB',
        qw(cmcIIIUnitStatus));
    if (! $self->{cmcIIIUnitStatus}) {
      $self->add_critical('snmpwalk returns no health data (rittal-cmc-mib)');
    } else {
      $self->analyze_and_check_device_subsystem('Classes::Rittal::CMCIII::Component::DeviceSubsystem');
      $self->analyze_and_check_message_subsystem('Classes::Rittal::CMCIII::Component::MessageSubsystem');
    }
  } else {
    $self->no_such_mode();
  }
}

sub check {
  my $self = shift;

}

