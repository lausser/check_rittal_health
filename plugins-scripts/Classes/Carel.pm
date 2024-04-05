package Classes::Carel;
our @ISA = qw(Classes::Device);
use strict;

sub init {
  my $self = shift;
  if ($self->implements_mib('KELVIN-PCOWEB-LCP-DX-MIB') and
      $self->get_snmp_object("KELVIN-PCOWEB-LCP-DX-MIB", "current-year") == 21) {
    bless $self, 'Classes::Carel::pCOWeb';
    $self->debug('using Classes::Carel::pCOWeb');
  } else {
    $self->no_such_model();
  }
  $self->init();
}

