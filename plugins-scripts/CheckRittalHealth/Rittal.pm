package CheckRittalHealth::Rittal;
our @ISA = qw(CheckRittalHealth::Device);
use strict;

sub init {
  my $self = shift;
  if ($self->{productname} =~ /Rittal CMC.*III/ ||
      $self->implements_mib('RITTAL-CMC-III-MIB')) {
    bless $self, 'CheckRittalHealth::Rittal::CMCIII';
    $self->debug('using CheckRittalHealth::Rittal::CMCIII');
  } elsif ($self->{productname} =~ /Rittal CMC/ ||
      $self->implements_mib('RITTAL-CMC-TC-MIB')) {
    bless $self, 'CheckRittalHealth::Rittal::CMCII';
    $self->debug('using CheckRittalHealth::Rittal::CMCII');
  } else {
    $self->no_such_model();
  }
  $self->init();
}

