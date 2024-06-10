package CheckRittalHealth::Device;
our @ISA = qw(Monitoring::GLPlugin::SNMP);
use strict;

sub classify {
  my $self = shift;
  if (! ($self->opts->hostname || $self->opts->snmpwalk)) {
    $self->add_unknown('either specify a hostname or a snmpwalk file');
  } else {
    $self->check_snmp_and_model();
    if ($self->opts->servertype) {
      $self->{productname} = 'storeever' if $self->opts->servertype eq 'storeever';
    }
    if (! $self->check_messages()) {
      if ($self->opts->verbose && $self->opts->verbose) {
        printf "I am a %s\n", $self->{productname};
      }
      if ($self->opts->mode =~ /^my-/) {
        $self->load_my_extension();
      } elsif ($self->{productname} =~ /Rittal/i) {
        bless $self, 'CheckRittalHealth::Rittal';
        $self->debug('using CheckRittalHealth::Rittal');
      } elsif ($self->implements_mib("CAREL-UG40CDZ-MIB")) {
        bless $self, 'CheckRittalHealth::Carel';
        $self->debug('using CheckRittalHealth::Carel');
      } else {
        if (my $class = $self->discover_suitable_class()) {
          bless $self, $class;
          $self->debug('using '.$class);
        } else {
          bless $self, 'CheckRittalHealth::Generic';
          $self->debug('using CheckRittalHealth::Generic');
        }
      }
    }
  }
  return $self;
}


package CheckRittalHealth::Generic;
our @ISA = qw(CheckRittalHealth::Device);
use strict;

sub init {
  my $self = shift;
  if ($self->mode =~ /something specific/) {
  } else {
    bless $self, 'Monitoring::GLPlugin::SNMP';
    $self->no_such_mode();
  }
}

