package Classes::Rittal::CMCIII::Component::MessageSubsystem;
our @ISA = qw(GLPlugin::SNMP::Item);
use strict;

sub init {
  my $self = shift;
  $self->get_snmp_objects('RITTAL-CMC-III-MIB',
      qw(cmcIIIOverallMsgStatus cmcIIINumberOfMsgs));
  $self->get_snmp_tables('RITTAL-CMC-III-MIB', [
      ['messages', 'cmcIIIMsgTable', 'Classes::Rittal::CMCIII::Component::MessageSubsystem::Message'],
  ]);
}

sub check {
  my $self = shift;
  if ($self->mode =~ /device::devices::list/) {
    foreach (@{$self->{devices}}) {
      #printf "dev%d\n", $unit if $self->{"unit$unit"}->{cmcTcUnitStatus} ne "notAvail";
      printf "%s\n", Data::Dumper::Dumper($_);
    }
    $self->add_ok("have fun");
  } elsif ($self->mode =~ /device::variables::list/) {
    foreach (@{$self->{variables}}) {
      printf "%s\n", Data::Dumper::Dumper($_);
    }
    $self->add_ok("have fun");
  } elsif ($self->mode =~ /device::(units|sensors)/) {
    my $info = sprintf 'message status is %s',
        $self->{cmcIIIOverallMsgStatus};
    $self->add_info($info);
    if ($self->{cmcIIIOverallMsgStatus} ne 'ok') {
      $self->add_critical();
    } else {
      #$self->add_ok();
    }
    foreach (@{$self->{messages}}) {
      $_->check();
    }
    #delete $self->{variables};
  } else {
    $self->no_such_mode();
  }
}


package Classes::Rittal::CMCIII::Component::MessageSubsystem::Message;
our @ISA = qw(GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my $self = shift;
  $self->{cmcIIIDevIndex} = $self->{indices}->[0];
}

sub check {
  my $self = shift;
  $self->add_info(sprintf '%s message: %s',
      $self->{cmcIIIMsgQuality}, $self->{cmcIIIMsgStatusText});
  if ($self->{cmcIIIMsgQuality} =~ /^warning/) {
    $self->add_warning();
  } elsif ($self->{cmcIIIMsgQuality} =~ /^alarm/) {
    $self->add_critical();
  } elsif ($self->{cmcIIIMsgQuality} =~ /^undefined/) {
    $self->add_unknown();
  }
}

