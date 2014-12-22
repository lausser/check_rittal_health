package Classes::Rittal;
our @ISA = qw(Classes::Device);
use strict;

sub init {
  my $self = shift;
  if ($self->{productname} =~ /Rittal CMC.*III/ ||
      $self->implements_mib('RITTAL-CMC-III-MIB')) {
    bless $self, 'Classes::Rittal::CMCIII';
    $self->debug('using Classes::Rittal::CMCIII');
  } elsif ($self->{productname} =~ /Rittal CMC/ ||
      $self->implements_mib('RITTAL-CMC-TC-MIB')) {
    bless $self, 'Classes::Rittal::CMCII';
    $self->debug('using Classes::Rittal::CMCII');
  } else {
    $self->no_such_model();
  }
  $self->init();
}

