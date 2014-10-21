package CXGN::Phenome::GenericGenePage;
use strict;
use warnings;
use English;
use Carp;

use CXGN::DB::Connection;
CXGN::DB::Connection->verbose(0);

use CXGN::Phenome::Locus;
use CXGN::Tools::Class qw/parricide/;
use CXGN::Marker;
use CXGN::Cview::MapFactory;
use CXGN::Chado::Organism;

=head1 NAME

CXGN::Phenome::GenericGenePage - implementation of Bio::GMOD::GenericGenePage for SGN

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BASE CLASS(ES)

L<Bio::GMOD::GenericGenePage>

=cut

use base qw/ Bio::GMOD::GenericGenePage /;

=head1 SUBCLASSES

none

=head1 METHODS

Implements all abstract methods in L<Bio::GMOD::GenericGenePage>

=cut

sub new {
  my ($class,%args) = @_;

  my $self = $class->SUPER::new(%args);

  $self->{locus} = CXGN::Phenome::Locus->new( $self->_dbh,
					      $args{-id} || croak '-id required',
					    );
  return $self;
}

#shared dbh among all CXGN::Phenome::GenericGenePage objects
sub _dbh {
  return our $dbh ||= CXGN::DB::Connection->new;
}

sub _locus {
  shift->{locus}
}

sub name {
  shift->_locus->get_locus_name;
}

sub synonyms {
  my ($self) = @_;
  return map $_->get_locus_alias, $self->_locus->get_locus_aliases;
}

sub map_locations {
  my ($self) = @_;

  return map {
    my $lmo = $_;

    my $marker_id= $lmo->get_marker_id(); #{marker_id};
    my $marker=CXGN::Marker->new( $self->_dbh, $marker_id); #a new marker object
	
    my $marker_name=$marker->name_that_marker();
    my $experiments=$marker->current_mapping_experiments();
    if ($experiments and @{$experiments}) {
      map {
	my $loc= $_->{location};
	my $map_version_id=$loc->map_version_id();
	my $lg_name=$loc->lg_name();
	unless ($map_version_id) {
	  ()
	} else {
	  my $map_factory=CXGN::Cview::MapFactory->new( $self->_dbh );
	  my $map = $map_factory->create({map_version_id=>$map_version_id});
	  my $map_version_id=$map->get_id();
	  my $map_name=$map->get_short_name();
			
	  {
	    map_name   => $map_name,
	    chromosome => $lg_name,
	    marker     => $marker_name,
	    position   => $loc->position,
	    units      => 'cm',
	  }
	}
      }
      grep $_->{location},
      @$experiments
    } else {
      () #< if no experiments, then no locations
    }
  } $self->_locus->get_locus_markers;
}

sub ontology_terms {
  my ($self) = @_;

  my $locus = $self->_locus;

  return map {
      my $t = $_;
      $t->get_db_name.':'.$t->get_accession => $t->get_cvterm_name()
      } $locus->get_dbxrefs_by_type("ontology");
}

sub dbxrefs {
    my ($self) = @_;
    return map {
	my $t = $_;
	$t->get_db_name.':'.$t->get_accession
	} $self->_locus->get_dbxrefs();
}

sub literature_references {
    my ($self) = @_;
    return map {
	my $t = $_;
	$t->get_db_name.':'.$t->get_accession
	} $self->_locus->get_dbxrefs_by_type("literature");
}

sub summary_text {
    my ($self) = @_;
    return $self->_locus->get_description;
}

sub organism {
    my ($self) = @_;
    my $locus=$self->_locus();
    my $organism= CXGN::Chado::Organism->new_with_common_name($self->_dbh(), $locus->get_common_name() );
    my $taxon_id=  $organism->get_genbank_taxon_id();
    
    return
    {  ncbi_taxon_id => $organism->get_genbank_taxon_id(),
       binomial => $organism->get_genus() . " " . $organism->get_species(),
       common => $organism->get_common_name(),
   }
}


=head1 AUTHOR(S)

Robert Buels
Naama Menda

=cut

sub DESTROY {
  return parricide(shift,our @ISA);
}

###
1;#do not remove
###
