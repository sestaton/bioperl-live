# $Id$
#
# BioPerl module for Bio::PopGen::Statistics
#
# Cared for by Jason Stajich <jason-at-bioperl-dot-org>
#
# Copyright Jason Stajich
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::PopGen::Statistics - Population Genetics statistical tests  

=head1 SYNOPSIS

  use Bio::PopGen::Statistics;
  use Bio::AlignIO;
  use Bio::PopGen::Simulation::Coalescent;
 
  my $sim = new Bio::PopGen::Simulation::Coalescent( -samplesample_size => 12);

  my $tree = $sim->next_tree;
  
  $factory->add_Mutations($tree,20);

  my $stats = new Bio::PopGen::Statistics();
  my $pi = $stats->pi($tree);
  my $D = $stats->tajima_d($tree);
  

=head1 DESCRIPTION

This object is intended to provide implementations some standard
population genetics statistics about alleles in populations.

This module was previously named Bio::Tree::Statistics.

This object is a place to accumulate routines for calculating various
statistics from the coalescent simulation, marker/allele, or from
aligned sequence data given that you can calculate alleles, number of
segregating sites.

Currently implemented:
 Fu and Li's D  (fu_and_li_D)
 Fu and Li's D* (fu_and_li_D_star)
 Fu and Li's F  (fu_and_li_F)
 Tajima's D     (tajima_D)
 theta          (theta)
 pi             (pi) - number of pairwise differences


In all cases where a the method expects an arrayref of
L<Bio::PopGen::IndividualI> objects and L<Bio::PopGen::PopulationI>
object will also work.

=head2 REFERENCES

Fu Y.X and Li W.H. (1993) "Statistical Tests of Neutrality of
Mutations." Genetics 133:693-709.

Fu Y.X. (1996) "New Statistical Tests of Neutrality for DNA samples
from a Population." Genetics 143:557-570.

Tajima F. (1989) "Statistical method for testing the neutral mutation
hypothesis by DNA polymorphism." Genetics 123:585-595.


=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to
the Bioperl mailing list.  Your participation is much appreciated.

  bioperl-l@bioperl.org              - General discussion
  http://bioperl.org/MailList.shtml  - About the mailing lists

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
of the bugs and their resolution. Bug reports can be submitted via
the web:

  http://bugzilla.bioperl.org/

=head1 AUTHOR - Jason Stajich, Matthew Hahn

Email jason-at-bioperl-dot-org
Matt Hahn E<lt>matthew.hahn-at-duke.dukeE<gt>

=head1 CONTRIBUTORS

Additional contributors names and emails here

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::PopGen::Statistics;
use vars qw(@ISA);
use strict;

use Bio::Root::Root;

@ISA = qw(Bio::Root::Root );

=head2 new

 Title   : new
 Usage   : my $obj = new Bio::PopGen::Statistics();
 Function: Builds a new Bio::PopGen::Statistics object 
 Returns : an instance of Bio::PopGen::Statistics
 Args    : none


=cut


=head2 fu_and_li_D

 Title   : fu_and_li_D
 Usage   : my $D = $statistics->fu_an_li_D(\@ingroup,$extmutations);
 Function: Fu and Li D statistic for a list of individuals
           given an outgroup and the number of external mutations
           (either provided or calculated from list of outgroup individuals)
 Returns : decimal
 Args    : $individuals - array refence which contains ingroup individuals 
           (L<Bio::PopGen::Individual> or derived classes)
           $extmutations - number of external mutations OR
           arrayref of outgroup individuals
=cut

sub fu_and_li_D { 
    my ($self,$ingroup,$outgroup) = @_;

    my ($seg_sites,$pi,$sample_size,$ext_mutations);
    if( ref($ingroup) =~ /ARRAY/i ) {
	$sample_size = scalar @$ingroup;
	# pi - all pairwise differences 
	$pi          = $self->pi($ingroup);  
	$seg_sites   = $self->segregating_sites_count($ingroup);
    } elsif( ref($ingroup) && 
	     $ingroup->isa('Bio::PopGen::PopulationI')) {
	$sample_size = $ingroup->get_number_individuals;
	$pi          = $self->pi($ingroup);
	$seg_sites   = $self->segregating_sites_count($ingroup);
    } else { 
	$self->throw("expected an array reference of a list of Bio::PopGen::IndividualI OR a Bio::PopGen::PopulationI object to tajima_D");
	return 0;
    }
    
    if( $seg_sites <= 0 ) { 
	$self->warn("mutation total was not > 0, cannot calculate a Fu and Li D");
	return 0;
    }

    if( ! defined $outgroup ) {
	$self->warn("Need to provide either an array ref to the outgroup individuals or the number of external mutations");
	return 0;
    } elsif( ref($outgroup) ) {
	$ext_mutations = $self->external_mutations($ingroup,$outgroup);
    } else { 
	$ext_mutations = $outgroup;
    }
    my $a = 0;
    for(my $k= 1; $k < $sample_size; $k++ ) {
        $a += ( 1 / $k );
    }

    my $b = 0;
    for(my $k= 1; $k < $sample_size; $k++ ) {
        $b += ( 1 / $k**2 );
    }

    my $c = 2 * ( ( ( $sample_size * $a ) - (2 * ( $sample_size -1 ))) /
                  ( ( $sample_size - 1) * ( $sample_size - 2 ) ) );

    my $v = 1 + ( ( $a**2 / ( $b + $a**2 ) ) * ( $c - ( ( $sample_size + 1) /
                                                        ( $sample_size - 1) ) ));

    my $u = $a - 1 - $v;
    my $D = ( $seg_sites - (  $a * $ext_mutations) ) /
	( sqrt ( ($u * $seg_sites ) + ( $v * $seg_sites **2) ) );

    return $D;
}

=head2 fu_and_li_D_star

 Title   : fu_and_li_D_star
 Usage   : my $D = $statistics->fu_an_li_D_star(\@individuals);
 Function: Fu and Li's D* statistic for a set of samples
            Without an outgroup
 Returns : decimal number
 Args    : array ref of L<Bio::PopGen::IndividualI> objects
           OR
           L<Bio::PopGen::PopulationI> object
=cut

#'
# fu_and_li_D*

sub fu_and_li_D_star {
    my ($self,$individuals) = @_;

    my ($seg_sites,$pi,$sample_size,$singletons);
    if( ref($individuals) =~ /ARRAY/i ) {
	$sample_size = scalar @$individuals;
	# pi - all pairwise differences 
	$pi          = $self->pi($individuals);  
	$seg_sites   = $self->segregating_sites_count($individuals);
	$singletons  = $self->singleton_count($individuals);
    } elsif( ref($individuals) && 
	     $individuals->isa('Bio::PopGen::PopulationI')) {
	my $pop = $individuals;
	$sample_size = $pop->get_number_individuals;
	$pi          = $self->pi($pop);
	$seg_sites   = $self->segregating_sites_count($pop);
	$singletons  = $self->singleton_count($pop);
    } else { 
	$self->throw("expected an array reference of a list of Bio::PopGen::IndividualI OR a Bio::PopGen::PopulationI object to tajima_D");
	return 0;
    }

    my $a = 0;
    for(my $k= 1; $k < $sample_size; $k++ ) {
	$a += ( 1 / $k );
    }

    my $a1 = 0;
    for(my $k= 1; $k <= $sample_size; $k++ ) {
	$a1 += ( 1 / $k );
    }

    my $b = 0;
    for(my $k= 1; $k < $sample_size; $k++ ) {
	$b += ( 1 / $k**2 );
    }

    my $c = 2 * ( ( ( $sample_size * $a ) - (2 * ( $sample_size -1 ))) / 
		  ( ( $sample_size - 1) * ( $sample_size - 2 ) ) );

    my $d = $c + ( ($sample_size -2) / ($sample_size - 1)**2 ) +
	( 2 / ($sample_size -1) * 
	  ( (3/2) - ( (2*$a1 - 3) / ($sample_size -2) ) - 
	    ( 1/ $sample_size) ) 
	  );
    my $v_star = ( ( ($sample_size/($sample_size-1) )**2)*$b + (($a**2)*$d) -
		 (2*( ($sample_size*$a*($a+1)) )/(($sample_size-1)**2)) )  /
		   (($a**2) + $b);

    my $u_star = ( ($sample_size/($sample_size-1))*
		   ($a - ($sample_size/
			  ($sample_size-1)))) - $v_star;

    my $D_star = ( (($sample_size/($sample_size-1))*$seg_sites) -
		   ($a*$singletons) ) / 
		   ( sqrt( ($u_star*$seg_sites) + ($v_star*($seg_sites**2)) ));
    return $D_star;
}

=head2 fu_and_li_F

 Title   : fu_and_li_F
 Usage   : my $D = Bio::PopGen::Statistics->fu_and_li_F(\@ingroup,$ext_muts);
 Function: Calculate Fu and Li's F on an ingroup with either the set of 
           outgroup individuals, or the number of external mutations
 Returns : decimal number
 Args    : array ref of L<Bio::PopGen::IndividualI> objects for the ingroup
           OR a L<Bio::PopGen::PopulationI> object
            
           number of external mutations OR list of individuals for the outgroup

=cut
#'

sub fu_and_li_F {
    my ($self,$ingroup,$outgroup) = @_;
    my ($seg_sites,$pi,$sample_size,$ext_mutations);
    if( ref($ingroup) =~ /ARRAY/i ) {
	$sample_size = scalar @$ingroup;
	# pi - all pairwise differences 
	$pi          = $self->pi($ingroup);  
	$seg_sites   = $self->segregating_sites_count($ingroup);
    } elsif( ref($ingroup) && 
	     $ingroup->isa('Bio::PopGen::PopulationI')) {
	$sample_size = $ingroup->get_number_individuals;
	$pi          = $self->pi($ingroup);
	$seg_sites   = $self->segregating_sites_count($ingroup);
    } else { 
	$self->throw("expected an array reference of a list of Bio::PopGen::IndividualI OR a Bio::PopGen::PopulationI object to tajima_D");
	return 0;
    }
    
    if( ! defined $outgroup ) {
	$self->warn("Need to provide either an array ref to the outgroup individuals or the number of external mutations");
	return 0;
    } elsif( ref($outgroup) ) {
	$ext_mutations = $self->external_mutations($ingroup,$outgroup);
    } else { 
	$ext_mutations = $outgroup;
    }
    
    my $a = 0;
    for(my $k= 1; $k < $sample_size; $k++ ) {
	$a += ( 1 / $k );
    }

    my $a1 = 0;
    for(my $k= 1; $k <= $sample_size; $k++ ) {
	$a1 += ( 1 / $k );
    }

    my $b = 0;
    for(my $k= 1; $k < $sample_size; $k++ ) {
	$b += ( 1 / $k**2 );
    }

    my $c = 2 * ( ( ( $sample_size * $a ) - (2 * ( $sample_size -1 ))) / 
		  ( ( $sample_size - 1) * ( $sample_size - 2 ) ) );

    my $v_F = ( $c + ( (2*(($sample_size**2)+$sample_size+3)) / 
		       ( (9*$sample_size)*($sample_size-1) ) ) -
		(2/($sample_size-1)) ) / ( ($a**2)+$b );

    my $u_F = ( 1 + ( ($sample_size+1)/(3*($sample_size-1)) )-
		( 4*( ($sample_size+1)/(($sample_size-1)**2) ))*
		($a1 - ((2*$sample_size)/($sample_size+1))) ) /
		($a - $v_F);

    my $F = ($pi - $ext_mutations) / ( sqrt( ($u_F*$seg_sites) +
					     ($v_F*($seg_sites**2)) ) );

    return $F;
}

=head2 fu_and_li_F_star

 Title   : fu_and_li_F_star
 Usage   : my $D = Bio::PopGen::Statistics->fu_and_li_F_star(\@ingroup);
 Function: Calculate Fu and Li's F* on an ingroup without an outgroup
           It uses count of singleton alleles instead 
 Returns : decimal number
 Args    : array ref of L<Bio::PopGen::IndividualI> objects for the ingroup
           OR
           L<Bio::PopGen::PopulationI> object
=cut
#' keep my emacs happy

sub fu_and_li_F_star {
    my ($self,$individuals) = @_;

    my ($seg_sites,$pi,$sample_size,$singletons);
    if( ref($individuals) =~ /ARRAY/i ) {
	$sample_size = scalar @$individuals;
	# pi - all pairwise differences 
	$pi          = $self->pi($individuals);  
	$seg_sites   = $self->segregating_sites_count($individuals);
	$singletons  = $self->singleton_count($individuals);
    } elsif( ref($individuals) && 
	     $individuals->isa('Bio::PopGen::PopulationI')) {
	my $pop = $individuals;
	$sample_size = $pop->get_number_individuals;
	$pi          = $self->pi($pop);
	$seg_sites   = $self->segregating_sites_count($pop);
	$singletons  = $self->singleton_count($pop);
    } else { 
	$self->throw("expected an array reference of a list of Bio::PopGen::IndividualI OR a Bio::PopGen::PopulationI object to tajima_D");
	return 0;
    }
    my $a = 0;
    for(my $k= 1; $k < $sample_size; $k++ ) {
	$a += ( 1 / $k );
    }
    
    my $a1 = 0;
    for(my $k= 1; $k <= $sample_size; $k++ ) {
	$a1 += ( 1 / $k );
    }

    my $b = 0;
    for(my $k= 1; $k < $sample_size; $k++ ) {
	$b += ( 1 / $k**2 );
    }
    # eq (14) 
    my $c = 2 * ( (($sample_size * $a) - (2 * ( $sample_size -1 ))) / 
		  (( $sample_size - 1) * ($sample_size - 2)) );
    # eq (46) 
    my $d = $c + ( ($sample_size -2)/ (($sample_size - 1)**2)) +
	     ((2/($sample_size -1))*
	      ((3/2) - ((2*$a1 - 3)/($sample_size -2)) - 
	       (1/$sample_size)));
    
    my $v_F_star = ( $d + ( 2*($sample_size**2+$sample_size+3) /
			    (9*$sample_size*($sample_size-1))) -
		     ( (2/($sample_size-1))*
		       (4*$b - 6 + (8/$sample_size))) )/
		       ($a**2 + $b);
    
    my $u_F_star = ( ($sample_size / ($sample_size-1)) + 
		     (($sample_size+1)/(3*($sample_size-1))) -
		     ( 2 * (2 / ($sample_size * ($sample_size-1)))) +
		     (2*( ($sample_size+1)/($sample_size-1)**2)*
		      ($a1 - ((2*$sample_size)/($sample_size+1))) )) /
		      ($a - $v_F_star);
    
    my $F_star = ( $pi - (( ($sample_size-1)/ $sample_size)*$singletons)) /
	sqrt ( ($u_F_star*$seg_sites) + ($v_F_star*($seg_sites**2)));
    return $F_star;
} 

=head2 tajima_D

 Title   : tajima_D
 Usage   : my $D = Bio::PopGen::Statistics->tajima_D(\@samples);
 Function: Calculate Tajima's D on a set of samples 
 Returns : decimal number
 Args    : array ref of L<Bio::PopGen::IndividualI> objects
           OR 
           L<Bio::PopGen::PopulationI> object


=cut

#'

sub tajima_D {
    my ($self,$individuals) = @_;
    my ($seg_sites,$pi,$sample_size);

    if( ref($individuals) =~ /ARRAY/i ) {
	$sample_size = scalar @$individuals;
	# pi - all pairwise differences 
	$pi          = $self->pi($individuals);  
	$seg_sites = $self->segregating_sites_count($individuals);

    } elsif( ref($individuals) && 
	     $individuals->isa('Bio::PopGen::PopulationI')) {
	my $pop = $individuals;
	$sample_size = $pop->get_number_individuals;
	$pi          = $self->pi($pop);
	$seg_sites = $self->segregating_sites_count($pop);
    } else { 
	$self->throw("expected an array reference of a list of Bio::PopGen::IndividualI OR a Bio::PopGen::PopulationI object to tajima_D");
	return 0;
    }
    my $a1 = 0; 
    for(my $k= 1; $k < $sample_size; $k++ ) {
	$a1 += ( 1 / $k );
    }

     my $a2 = 0;
     for(my $k= 1; $k < $sample_size; $k++ ) {
	 $a2 += ( 1 / $k**2 );
     }

    
    my $b1 = ( $sample_size + 1 ) / ( 3* ( $sample_size - 1) );
    my $b2 = ( 2 * ( $sample_size ** 2 + $sample_size + 3) ) / 
	     ( ( 9 * $sample_size) * ( $sample_size - 1) );
    my $c1 = $b1 - ( 1 / $a1 );
    my $c2 = $b2 - ( ( $sample_size + 2 ) /
		     ( $a1 * $sample_size))+( $a2 / $a1 ** 2);
    my $e1 = $c1 / $a1;
    my $e2 = $c2 / ( $a1**2 + $a2 );
    
    my $D = ( $pi - ( $seg_sites / $a1 ) ) / 
	sqrt ( ($e1 * $seg_sites) + (( $e2 * $seg_sites) * ( $seg_sites - 1)));

    return $D;
}

=head2 pi

 Title   : pi
 Usage   : my $pi = Bio::PopGen::Statistics->pi(\@inds)
 Function: Calculate pi (...explain here...) given a list of individuals 
           which have the same number of markers/sites/mutation as 
           available from the get_Genotypes() call in 
           L<Bio::PopGen::IndividualI>
 Returns : decimal number
 Args    : Arg1= array ref of L<Bio::PopGen::IndividualI> objects
             which have markers/mutations.  We expect all individuals to
             have a marker - we will deal with missing data as a special case.
           OR
           Arg1= L<Bio::PopGen::PopulationI> object.  In the event that
                 only allele frequency data is available, storing it in
                 Population object will make this available.
           num sites [optional], an optional second argument (integer)
             which is the number of sites, then pi returned is pi/site.

=cut

sub pi {
    my ($self,$individuals,$numsites) = @_;
    my (%data,@marker_names,$sample_size);

    if( ref($individuals) =~ /ARRAY/i ) {
	# one possible argument is an arrayref of Bio::PopGen::IndividualI objs
	@marker_names = $individuals->[0]->get_marker_names;
	$sample_size = scalar @$individuals;

	# Here we're calculating the allele frequencies
	my %marker_total;
	foreach my $ind ( @$individuals ) {
	    if( ! $ind->isa('Bio::PopGen::IndividualI') ) {
		$self->warn("Expected an arrayref of Bio::PopGen::IndividualI objects, this is a ".ref($ind)."\n");
		return 0;
	    }
	    foreach my $m ( @marker_names ) {
		foreach my $allele (map { $_->get_Alleles} 
			       $ind->get_Genotypes($m) ) {
		    $data{$m}->{$allele}++;
		    $marker_total{$m}++;
		}
	    }
	}
	while( my ($marker,$count) =  each %marker_total ) {
	    foreach my $c ( values %{$data{$marker}} ) {
		$c /= $count;
	    }
	}
	# %data will contain allele frequencies for each marker, allele
    } elsif( ref($individuals) && 
	     $individuals->isa('Bio::PopGen::PopulationI') ) {
	my $pop = $individuals;
	$sample_size = $pop->get_number_individuals;
	foreach my $marker( $pop->get_Markers ) {
	    push @marker_names, $marker->name;
	    $data{$marker->name} = {$marker->get_Allele_Frequencies};
	}
    } else { 
	$self->throw("expected an array reference of a list of Bio::PopGen::IndividualI to pi");
    }
    # doing all pairwise combinations

    # For now we assume that all individuals have the same markers
    my ($diffcount,$totalcompare) = (0,0);
    my $pi = 0;
    foreach my $markerdat ( values %data ) {
	my $totalalleles; # this will only be different among markers
	                  # when there is missing data
	my @alleles = keys %$markerdat;
	foreach my $al ( @alleles ) { $totalalleles += $markerdat->{$al} }
	for( my $i =0; $i < scalar @alleles -1; $i++ ) {
	    my ($a1,$a2) = ( $alleles[$i], $alleles[$i+1]);
	    $pi += $self->heterozygosity($sample_size, 
					 $markerdat->{$a1} / $totalalleles,
					 $markerdat->{$a2} / $totalalleles);
	}
    }
    $self->debug( "pi=$pi\n");
    if( $numsites ) { 
	return $pi / $numsites;
    } else { 
	return $pi;
    }
}

=head2 theta

 Title   : theta
 Usage   : my $theta = Bio::PopGen::Statistics->theta($sampsize,$segsites);
 Function: Calculates theta (...explanation here... ) from the sample size 
           and the number of segregating sites.
           Providing the third parameter, total number of sites will
           return theta per site          
 Returns : decimal number 
 Args    : sample size (integer),
           num segregating sites (integer)
           total sites (integer) [optional] (to calculate theta per site)
           OR
           provide an arrayref of the L<Bio::PopGen::IndividualI> objects
           total sites (integer) [optional] (to calculate theta per site)
           OR
           provide an L<Bio::PopGen::PopulationI> object
           total sites (integer)[optional]
=cut

sub theta {
    my $self = shift;    
    my ( $sample_size, $seg_sites,$totalsites) = @_;
    if( ref($sample_size) =~ /ARRAY/i ) {
	my $samps = $sample_size;
	$totalsites = $seg_sites; # only 2 arguments if one is an array
	my %data;
	my @marker_names = $samps->[0]->get_marker_names;
	# we need to calculate number of polymorphic sites
	$seg_sites = $self->segregating_sites_count($samps);
	$sample_size = scalar @$samps;

    } elsif(ref($sample_size) &&
	    $sample_size->isa('Bio::PopGen::PopulationI') ) {
	# This will handle the case when we pass in a PopulationI object
	my $pop = $sample_size;
	$totalsites = $seg_sites; # shift the arguments over by one
	$sample_size = $pop->get_number_individuals;
	$seg_sites = $self->segregating_sites_count($pop);
    }
    my $a1 = 0; 
    for(my $k= 1; $k < $sample_size; $k++ ) {
	$a1 += ( 1 / $k );
    }    
    if( $totalsites ) { # 0 and undef are the same can't divide by them
	$seg_sites /= $totalsites;
    }
    return $seg_sites / $a1;
}

=head2 singleton_count

 Title   : singleton_count
 Usage   : my ($singletons) = Bio::PopGen::Statistics->singleton_count(\@inds)
 Function: Calculate the number of mutations/alleles which only occur once in
           a list of individuals for all sites/markers
 Returns : (integer) number of alleles which only occur once (integer)
 Args    : arrayref of L<Bio::PopGen::IndividualI> objects
           OR
           L<Bio::PopGen::PopulationI> object


=cut

sub singleton_count {
    my ($self,$individuals) = @_;

    my @inds;
    if( ref($individuals) =~ /ARRAY/ ) {
	@inds = @$individuals;
    } elsif( ref($individuals) && 
	     $individuals->isa('Bio::PopGen::PopulationI') ) {
	my $pop = $individuals;
	@inds = $pop->get_Individuals();
	unless( @inds ) { 
	    $self->warn("Need to provide a population which has individuals loaded, not just a population with allele frequencies");
	    return 0;
	}
    } else {
	$self->warn("Expected either a PopulationI object or an arrayref of IndividualI objects");
	return 0;
    }
    # find number of sites where a particular allele is only seen once

    my ($singleton_allele_ct,%sites) = (0);
    # first collect all the alleles into a hash structure
    
    foreach my $n ( @inds ) {
	if( ! $n->isa('Bio::PopGen::IndividualI') ) {
	    $self->warn("Expected an arrayref of Bio::PopGen::IndividualI objects, this is a ".ref($n)."\n");
	    return 0;
	}
	foreach my $g ( $n->get_Genotypes ) {
	    my ($nm,@alleles) = ($g->marker_name, $g->get_Alleles);
	    foreach my $allele (@alleles ) {
		$sites{$nm}->{$allele}++;
	    }
	}
    }
    foreach my $site ( values %sites ) { # don't really care what the name is
	foreach my $allelect ( values %$site ) { # 
            # find the sites which have an allele with only 1 copy
 	    $singleton_allele_ct++ if( $allelect == 1 );
	}
    }
    return $singleton_allele_ct;
}

# Yes I know that singleton_count and segregating_sites_count are
# basically processing the same data so calling them both is
# redundant, something I want to fix later but want to make things
# correct and simple first

=head2 segregating_sites_count

 Title   : segregating_sites_count
 Usage   : my $segsites = Bio::PopGen::Statistics->segregating_sites_count
 Function: Gets the number of segregating sites (number of polymorphic sites)
 Returns : (integer) number of segregating sites
 Args    : arrayref of L<Bio::PopGen::IndividualI> objects 
           OR
           L<Bio::PopGen::PopulationI> object

=cut

# perhaps we'll change this in the future 
# to return the actual segregating sites
# so one can use this to pull in the names of those sites.
# Would be trivial if it is useful.

sub segregating_sites_count{
   my ($self,$individuals) = @_;
   my $type = ref($individuals);
   my $seg_sites = 0;
   if( $type =~ /ARRAY/i ) {
       my %sites;
       foreach my $n ( @$individuals ) {
	   if( ! $n->isa('Bio::PopGen::IndividualI') ) {
	       $self->warn("Expected an arrayref of Bio::PopGen::IndividualI objects, this is a ".ref($n)."\n");
	       return 0;
	   }
	   foreach my $g ( $n->get_Genotypes ) {
	       my ($nm,@alleles) = ($g->marker_name, $g->get_Alleles);
	       foreach my $allele (@alleles ) {
		   $sites{$nm}->{$allele}++;
	       }
	   }
       }
       foreach my $site ( values %sites ) { # use values b/c we don't 
	                                    # really care what the name is
	   # find the sites which >1 allele
	   $seg_sites++ if( keys %$site > 1 );
       }
   } elsif( $type && $individuals->isa('Bio::PopGen::PopulationI') ) {
       foreach my $marker ( $individuals->get_Markers ) {  
	   my @alleles = $marker->get_Alleles;	    
	   $seg_sites++ if ( scalar @alleles > 1 );
       }
   } else { 
       $self->warn("segregating_sites_count expects either a PopulationI object or a list of IndividualI objects");
       return 0;
   } 
   return $seg_sites;
}


=head2 heterozygosity

 Title   : heterozygosity
 Usage   : my $het = Bio::PopGen::Statistics->heterozygosity($sampsize,$freq1);
 Function: Calculate the heterozgosity for a sample set for a set of alleles
 Returns : decimal number
 Args    : sample size (integer)
           frequency of one allele (fraction - must be less than 1)
           [optional] frequency of another allele - this is only needed
                      in a non-binary allele system
Note     : p^2 + 2pq + q^2

=cut


sub heterozygosity {
    my ($self,$samp_size, $freq1,$freq2) = @_;
    if( ! $freq2 ) { $freq2 = 1 - $freq1 }
    if( $freq1 > 1 || $freq2 > 1 ) { 
	$self->warn("heterozygosity expects frequencies to be less than 1");
    }
    my $sum = ($freq1**2) + (($freq2)**2);
    my $h = ( $samp_size*(1- $sum) ) / ($samp_size - 1) ;
    return $h;
}

=head2 external_mutations

 Title   : external_mutations
 Usage   : my $ext = Bio::PopGen::Statistics->external_mutations($ingroup,$outgroup);
 Function: Calculate the number of alleles or (mutations) which are ancestral
 Returns : integer of number of mutations which are ancestral or 'external'
           based on the outgroup
 Args    : ingroup - L<Bio::PopGen::IndividualI>s arrayref OR 
                     L<Bio::PopGen::PopulationI>
           outgroup- L<Bio::PopGen::IndividualI>s arrayref OR 
                     L<Bio::PopGen::PopulationI> OR
                     a single L<Bio::PopGen::IndividualI>

=cut

sub external_mutations{
   my ($self,$ingroup,$outgroup) = @_;
   my (%indata,%outdata,@marker_names);
   # basically we have to do some type checking
   # if that perl were typed...
   my ($itype,$otype) = (ref($ingroup),ref($outgroup));

   return $outgroup unless( $otype ); # we expect arrayrefs or objects, nums
                                      # are already the value we 
                                      # are searching for
   # pick apart the ingroup
   # get the data
   if( ref($ingroup) =~ /ARRAY/i ) {
       if( ! ref($ingroup->[0]) ||
	   ! $ingroup->[0]->isa('Bio::PopGen::IndividualI') ) {
	   $self->warn("Expected an arrayref of Bio::PopGen::IndividualI objects or a Population for ingroup in external_mutations");
	   return 0;
       }
       # we assume that all individuals have the same markers 
       # i.e. that they are aligned
       @marker_names = $ingroup->[0]->get_marker_names;
       for my $ind ( @$ingroup ) {
	   for my $m ( @marker_names ) {
	       for my $allele ( map { $_->get_Alleles }
				    $ind->get_Genotypes($m) ) {
		   $indata{$m}->{$allele}++;
	       }
	   }
       }	   
   } elsif( ref($ingroup) && $ingroup->isa('Bio::PopGen::PopulationI') ) {
       @marker_names = $ingroup->get_marker_names;
       for my $ind ( $ingroup->get_Individuals() ) {
	   for my $m ( @marker_names ) {
	       for my $allele ( map { $_->get_Alleles} 
				    $ind->get_Genotypes($m) ) {
		   $indata{$m}->{$allele}++;
	       }
	   }
       }
   } else { 
       $self->warn("Need an arrayref of Bio::PopGen::IndividualI objs or a Bio::PopGen::Population for ingroup in external_mutations");
       return 0;
   }
    
   if( $otype =~ /ARRAY/i ) {
       if( ! ref($outgroup->[0]) ||
	   ! $outgroup->[0]->isa('Bio::PopGen::IndividualI') ) {
	   $self->warn("Expected an arrayref of Bio::PopGen::IndividualI objects or a Population for outgroup in external_mutations");
	   return 0;
       }
       for my $ind ( @$outgroup ) {
	   for my $m ( @marker_names ) {
	       for my $allele ( map { $_->get_Alleles }
				$ind->get_Genotypes($m) ) {
		   $outdata{$m}->{$allele}++;
	       }
	   }
       }
   
   } elsif( $otype->isa('Bio::PopGen::PopulationI') ) {
       for my $ind ( $outgroup->get_Individuals() ) {
	   for my $m ( @marker_names ) {
	       for my $allele ( map { $_->get_Alleles} 
				    $ind->get_Genotypes($m) ) {
		   $outdata{$m}->{$allele}++;
	       }
	   }
       }
   } elsif( $otype->isa('Bio::PopGen::PopulationI') ) { 
       $self->warn("Need an arrayref of Bio::PopGen::IndividualI objs or a Bio::PopGen::Population for outgroup in external_mutations");
       return 0;
   }
   my $external_alleles;
   foreach my $marker ( @marker_names ) {
       next if( keys %{$outdata{$marker}} > 1);
       my @in_alleles = keys %{$indata{$marker}};
       
       for my $allele ( @in_alleles ) {
	   if( $indata{$marker}->{$allele} == 1 &&
	       exists $outdata{$marker}->{$allele}  ) {
	       $external_alleles++;
	   }
       }
   }
   return $external_alleles;
}

1;
