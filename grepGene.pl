use strict;
use Data::Dumper;
use Getopt::Long;

my $file;      #filename of the mutation matrix
my $type;
my $prefix;
my $sampleInfo;    #sample information

GetOptions (
            "file|f=s"       => \$file,     #filename
            "type|t=s"       => \$type,     #types of variations: coding,exonic,intronic,splicing,UTR,upstream,downstream,intergenic
            "prefix|p=s"     => \$prefix,
            "sampleInfo|s=s"     => \$sampleInfo,   #sampleInfo
            "help|h"         => sub{
              print "usage: $0 grep genes to generate mutation table for different types\n\nOptions:\n\t--file\t\tthe filename of mutation table output by pipeline\n";
              print "\t--type\t\tthe type of variants, coding,exonic,intronic,splicing,UTR,upstream,downstream,intergenic\n";
              print "\t--prefix\tthe prefix of samples' names, comma separated\n";
              print "\t--sampleInfo\t\tthe sample names matrix for the analysis, tab delimited tumor-normal pairs\n";
              print "\t--help\t\tprint this help message\n";
              print "\n";
              exit 0;
            },
           );



my @prefix = split(',', $prefix);
my $prefixReg = join('|', @prefix);
print STDERR "prefixReg is $prefixReg\n";


my %somatic;
my %germline;  #may have multiple tumors
if ($sampleInfo and -s "$sampleInfo") {

  open IN, "$sampleInfo";
  while ( <IN> ){
    chomp;
    s/[\s\n]$//;
    my @columns = split /\t/;
    my $tumor = $columns[0];
    my $normal = $columns[1];

    $somatic{$tumor} = $normal;
    push(@{$germline{$normal}}, $tumor) if $normal ne 'undef';
  }
  close IN;
  print STDERR Dumper (\%somatic);
  print STDERR Dumper (\%germline);

}
print STDERR "sample Info processed\n";

#these are samples from RECTAL-NETS##############################
#my @ileum = qw(AC444 AC445 AC446 AC516 AC517 AC518 AC519);
#my %ileum;
#foreach my $il (@ileum) {
#  $ileum{$il} = '';
#}
#my @rectum = qw(AC57 AC439 AC440 AC441 AC443 AC447 AC525 AC526 AC527 AC528 AC529 AC530 AC531 AC532 AC533 AC546 AC548 AC580 AC637 AC653 AC668);
#my %rectum;
#foreach my $rec (@rectum) {
#  $rectum{$rec} = '';
#}
#these are samples from RECTAL-NETS#############################

open IN, "$file";
my @name;
my %colindex;
my %result;
my @samples;

while ( <IN> ) {
  chomp;
  my @cols = split /\t/;
  if ($_ =~ /^[\#]?chr\t/) {
    @name = @cols;
    for (my $j = 0; $j <= $#cols; $j++){
      $colindex{$cols[$j]} = $j;
      print STDERR "function column is indexed $j\n" if $cols[$j] eq 'function';
    }
    for (my $i = 0; $i <= $#name; $i++) {
      if ($name[$i] =~ /^(($prefixReg)[A-Za-z0-9\-\_]+)maf/) {
        my $sampCur = $1;
        if (exists $somatic{$sampCur}){  #only push tumor samples
          push(@samples, $sampCur);
        }
      }
    }
    print STDERR "samples are:\n";
    print STDERR Dumper (\@samples);
    next;
  } else {
    my @genes = &grepGene($cols[$colindex{'function'}]);
    #print STDERR Dumper(\@genes);
    for (my $i = 0; $i <= $#cols; $i++) {
      if ($name[$i] =~ /^(($prefixReg)[A-Za-z0-9\-\_]+)maf$/) {
        my $name = $1;
        next unless (exists $somatic{$name});
        my $maf = $cols[$i];
        my $endsratio = 0;
        my $cmean = 0;
        my $cmedian = 0;
        my $depth = $cols[$i+1];

        if ($cols[$i] =~ /\|/) { #split the var surrounding information
          my @infos = split(/\|/, $cols[$i]);
          $maf = $infos[0];
          if ($#infos == 2){
            $endsratio = $infos[1];
            ($cmean, $cmedian) = split(',', $infos[2]);
          } elsif ($#infos == 1){    #TCGA raw calls
            $depth = $infos[1];
          }
        }

        my $vard = sprintf("%.1f", $maf*$depth);

        #print STDERR "$name\t$maf\t$vard\n";

        if (($endsratio <= 0.9 or ((1-$endsratio)*$vard >= 2)) and (($cmean+$cmedian) < 5.5 or $cmedian <= 2)) { #it looks good
          if ($maf >= 0.05 and $vard >= 2) {
            foreach my $gene (@genes) {
              if ($gene ne '') {
                $result{$gene}{$name}++;
              }                 #gene ne ''
            }                   #foreach
          }                     #found in this sample
        }                       #it looks good
      }                         #it is maf
    }                           #iterator
  }                             #else
}
close IN;


print "gene";
foreach my $sample (@samples) {
  print "\t$sample";
}
print "\n";

foreach my $gene (keys %result) {
  print "$gene";
  foreach my $sample (@samples) {
    if ($result{$gene}{$sample} ne '') {
      print "\t$result{$gene}{$sample}";
    } else {
      print "\t0";
    }
  }
  print "\n";
}

sub grepGene {
  my $line = shift;
  my @dummy;
  if ($line =~ /function=exonic\;geneName=([\w\.\-\_\,\/]+?)\;functionalClass=([^\;]+)\;/) {     #coding change
    my $g1 = $1;
    my $function = $2;
    if ($type =~ /exonic/){
      &splitGene($g1);
    } elsif ($type =~ /coding/) {
      if ($function =~ /^synonymous/ or $function =~ /^nonframeshift/) {
         return(@dummy);
      } else {
         &splitGene($g1);
      }
    }
  } elsif ($line =~ /function\=ncRNA\_exonic\;geneName=([\w\.\-\_\,\/]+?)\;/) {                  #RNA_exonic
    my $g1 = $1;
    &splitGene($g1) if ($type =~ /exonic/);
  } elsif ($line =~ /function\=ncRNA\_exonic\;geneName=([\w\.\-\_\,\/]+?)$/) {                   #RNA_exonic ending
    my $g1 = $1;
    &splitGene($g1) if ($type =~ /exonic/);
  } elsif ($line =~ /function=exonic\;splicing\;geneName=([\w\.\-\_\,\;\_]+?)\;(geneDetail\=[\S]+;)?functionalClass=([^\;]+)\;/) {   #splicing and coding
    my $g1 = $1;
    my $function = $3;
    if ($type =~ /exonic/ or $type =~ /splicing/){
       &splitGene($g1);
    } elsif ($type =~ /coding/) {
      if ($function =~ /^synonymous/ or $function =~ /^nonframeshift/) {
        return(@dummy);
      } else {
        &splitGene($g1);
      }
    }
  } elsif ($line =~ /function\=(ncRNA\_)?intronic\;geneName=([\w\.\-\_\,\/]+?)\;/) {                       #intronic
    my $g1 = $2;
    &splitGene($g1) if ($type =~ /intronic/);
  } elsif ($line =~ /function\=(ncRNA\_)?splicing\;geneName=([\w\.\-\_\,\/]+?)\;(geneDetail\=[\S]+;)?/) {  #splicing
    my $g1 = $2;
    &splitGene($g1) if ($type =~ /splicing/);
  } elsif ($line =~ /function\=ncRNA\_exonic\;splicing\;geneName=([\w\.\-\_\,\;\/]+?)\;(geneDetail\=[\S]+;)?[\w\.]+\=/) { #splicing
    my $g1 = $1;
    &splitGene($g1) if ($type =~ /splicing/ or $type =~ /exonic/);
  } elsif ($line =~ /function\=(ncRNA\_)?UTR\d\;geneName=([\w\.\-\_\,\/]+?)\;/) {                                     #UTR
    my $g1 = $2;
    &splitGene($g1) if ($type =~ /UTR/);
  } elsif ($line =~ /function\=UTR5\;UTR3\;geneName=([\w\.\-\_\,\;\/]+?)\;(geneDetail\=[\S]+;)?[\w\.]+\=/) {          #UTRs
    my $g1 = $1;
    &splitGene($g1) if ($type =~ /UTR/);
  } elsif ($line =~ /function\=upstream\;geneName=([\w\.\-\_\,\/]+?)\;/){                                             #upstream
    my $g1 = $1;
    &splitGene($g1) if ($type =~ /upstream/);
  } elsif ($line =~ /function\=downstream\;geneName=([\w\.\-\_\,\/]+?)\;/){                                           #downstream
    my $g1 = $1;
    &splitGene($g1) if ($type =~ /downstream/);
  } elsif ($line =~ /function\=upstream\;downstream\;geneName=([\w\.\-\_\,\;\/]+?)\;[\w\.]+\=/){                      #upstream,downstream
    my $g1 = $1;
    &splitGene($g1) if ($type =~ /upstream/ or $type =~ /downstream/);
  } elsif ($line =~ /function\=intergenic\;geneName\=(.+?)\(dist\=\w+\)\,(.+?)\(dist\=\w+\)/) {                       #intergenic
     my $g1 = $1;
     my $g2 = $2;
     &splitGene($g1) if ($type =~ /intergenic/ and $g1 ne 'NONE');
     &splitGene($g2) if ($type =~ /intergenic/ and $g2 ne 'NONE');
  } else {
    print STDERR "error:\t\t$_\n";
  }
}


sub splitGene {
  my $genes = shift;
  $genes =~ s/\(.+?\)//g;    #remove the splicing or intergenic parentheses
  my @genes = split (/[\,]/, $genes);
  my %tmp;
  foreach my $gene (@genes) {
    $tmp{$gene} = "";
  }
  @genes = keys %tmp;
  return(@genes);
}
