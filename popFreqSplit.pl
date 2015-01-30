use strict;
use List::Util qw(first max maxstr min minstr reduce shuffle sum);
use Data::Dumper;

my $file = shift;
my $type = shift;  #snv or indel

if ($type eq ''){$type = 'snv'};

print STDERR "type is $type\n";

my %colnames;

open IN, "$file";
while ( <IN> ){
  chomp;
  my @cols = split /\t/;
  if ($_ =~ /^[\#]?[cC]hr\t/){
    #now it is the header
    for(my $i = 0; $i <= $#cols; $i++){
       $colnames{$cols[$i]} = $i;
    }
    print "$_\tfreq\n";
    #print STDERR Dumper(\%colnames);
  } #the clonames has been set

  else {
    #now it is the real stuff
    my $ref = $cols[$colnames{'ref'}];
    my $alt = $cols[$colnames{'alt'}];

    my $freq = -1;
    if ($cols[$colnames{'clinical'}] =~ /\;CAF\=\[([\d\.\,]+)\]\;/){
      my @freqs = split (/\,/, $1);

      $cols[$colnames{'clinical'}] =~ /\;REFALT\=([ACGT\-\,]+)$/;
      my @alleles = split(/\,/, $1);
      my $index = -1;
      my $minlengthdiff = 1000;

      for (my $i = 0; $i <= $#alleles; $i++) {
        if ($type eq 'snv'){
          if ($alleles[$i] eq $alt) {
            $index = $i;
            last;
          }
        } elsif ($type =~ /indel/) {
          my $lengthdiff = abs(length($alt) - length($alleles[$i]));
          if ($lengthdiff <= $minlengthdiff){
            $index = $i;
            $minlengthdiff = $lengthdiff;
          } else {
            next;
          }
        }
      } #find index

      if ($index != -1){
        $freq = $freqs[$index];
        if ($freq eq ''){
          shift @freqs;
          $freq = max(@freqs);
        }
        if ($type eq 'indelclean'){
          $ref =~ s/\-//;
          $alt =~ s/\-//;
          my $realdiff = length($alt)-length($ref);
          my $knowndiff = length($alleles[$index]-$alleles[0]);
          next if $realdiff ne $knowndiff;
        }
      } else {
        shift @freqs;
        $freq = max(@freqs);
      }
    } elsif ($cols[$colnames{'id'}] =~ /^[\dKGESP]+\=([\d\.]+)$/){
      $freq = $1;
    }
    if ($type eq 'indelclean') {
      if ($freq eq $cols[$colnames{'freq'}]){
        print "$_\n";
      } else {
        next;
      }
      next;
    }
    print "$_\t$freq\n";
  }
}
close IN;
