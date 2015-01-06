package Classes::Rittal::CMCII::Component::UnitSubsystem;
use strict;
our @ISA = qw(GLPlugin::SNMP::Item);

sub init {
  my $self = shift;
  $self->{units} = [];
  foreach (1..4) {
    next if $self->opts->name && $self->opts->name ne $_;
    my $unit = Classes::Rittal::CMCII::Component::UnitSubsystem::Unit->new(unit => $_);
    push(@{$self->{units}}, $unit) if $unit->{cmcTcUnitStatus} ne "notAvail";
  }
}

sub check {
  my $self = shift;
  if ($self->mode =~ /device::units::list/) {
    foreach (@{$self->{units}}) {
      printf "unit %d (type %s, %d sensors)\n",
          $_->{unit}, $_->{cmcTcUnitTypeOfDevice}, scalar(@{$_->{sensors}});
    }
  } elsif ($self->mode =~ /device::sensors::list/) {
    foreach my $unit (@{$self->{units}}) {
      foreach (@{$unit->{sensors}}) {
        printf "unit %d sensor %d (type %s)\n",
            $unit->{unit}, $_->{unitSensorIndex}, $_->{unitSensorType};
      }
    }
  } elsif ($self->mode =~ /device::sensors::health/) {
    foreach (@{$self->{units}}) {
      $_->check();
    }
    if (! $self->check_messages) {
      $self->clear_all();
      $self->add_ok("all units are working fine");
    } else {
      $self->clear_ok(); # show only faulted sensors
    }
  }
}

package Classes::Rittal::CMCII::Component::UnitSubsystem::Unit;
use strict;
our @ISA = qw(GLPlugin::SNMP::Item);

sub init {
  my $self = shift;
  my %params = @_;
  $self->{unit} = $params{unit};
  $self->get_snmp_objects('RITTAL-CMC-TC-MIB', (
      'cmcTcUnit'.$self->{unit}.'TypeOfDevice',
      'cmcTcUnit'.$self->{unit}.'Text',
      'cmcTcUnit'.$self->{unit}.'Status',
      'cmcTcUnit'.$self->{unit}.'NumberOfSensors'
  ));
  foreach (qw(TypeOfDevice Text Status NumberOfSensors)) {
    $self->{'cmcTcUnit'.$_} = $self->{'cmcTcUnit'.$self->{unit}.$_};
    delete $self->{'cmcTcUnit'.$self->{unit}.$_};
  }
  $self->add_info(sprintf 'unit %d has status %s',
      $self->{unit}, $self->{'cmcTcUnitStatus'});
  if ($self->{'cmcTcUnitStatus'} ne "notAvail") {
    $self->get_snmp_tables('RITTAL-CMC-TC-MIB', [
        ['sensors', 'cmcTcUnit'.$self->{unit}.'SensorTable', 'Classes::Rittal::CMCII::Component::SensorSubsystem::Sensor', sub { my $o = shift; ($o->{unitSensorStatus} ne "notAvail") && (! $self->opts->name2 || ($self->opts->name2 && $self->opts->name2 eq $o->{unitSensorIndex})) }],
    ]);
  }
}

sub check {
  my $self = shift;
  $self->info(sprintf "%s -unit %d has status %s (%s)",
      $self->{cmcTcUnitTypeOfDevice}, $self->{unit}, $self->{cmcTcUnitStatus},
      $self->{cmcTcUnitText});
  if ($self->{cmcTcUnitStatus} =~ /^(ok|detected)$/) {
    $self->add_ok();
  } elsif ($self->{cmcTcUnitStatus} =~ /^(timeout|error)$/) {
    $self->add_critical();
  } elsif ($self->{cmcTcUnitStatus} =~ /^(timeout|error)$/) {
    $self->add_warning();
  }
  foreach (@{$self->{sensors}}) {
    $_->check();
  }
}

