package CheckRittalHealth::Carel;
our @ISA = qw(CheckRittalHealth::Device);
use strict;

sub init {
  my $self = shift;
  if ($self->implements_mib('KELVIN-PCOWEB-LCP-DX-MIB') and
      $self->get_snmp_object("KELVIN-PCOWEB-LCP-DX-MIB", "current-year") == 21) {
    bless $self, 'CheckRittalHealth::Carel::pCOWeb';
    $self->debug('using CheckRittalHealth::Carel::pCOWeb');
  } else {
    $self->no_such_model();
  }
  $self->init();
}

