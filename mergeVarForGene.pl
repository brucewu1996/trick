use strict;
use Data::Dumper;

my $files = shift;
my $prefix = shift;
my $sampleInfo = shift;
my $annotationdir = shift;
if ($annotationdir eq '') {
  $annotationdir = "/cygdrive/d/stanford_work/annotation";
}

my @files = split(/\,/, $files);
my @prefix = split(',', $prefix);
my $prefixReg = join('|', @prefix);
print STDERR "prefixReg is $prefixReg\n";

my %somatic;
my %germline;  #may have multiple tumors
if ($sampleInfo and -s "$sampleInfo") {

  open IN, "$sampleInfo" or die "$sampleInfo is not readable!\n";
  while ( <IN> ) {
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


my $biomart = "$annotationdir/hg19.biomart.txt";
my $gene2loc = "$annotationdir/entrez2loc.sorted.txt";
my $genelength = "$annotationdir/hg19.gencode_GC_Len.txt";
my $census = "$annotationdir/cancer_gene_census.txt";
my $tsg = "$annotationdir/TSGs";

my %gene2ens;
my %gene2entrez;
my %gene2chr;
open GL, "$gene2loc";
while ( <GL> ){
  chomp;
  next if /^#/;
  my ($ens, $symbol, $chr, $start, $end, $strand, $entrez) = split /\t/;
  $gene2ens{$symbol} = $ens;
  $gene2entrez{$symbol} = $entrez;
  $gene2chr{$symbol} = $chr;
}
close GL;

my %gene2des;
my %gene2biotype;
open BM, "$biomart";
while ( <BM> ){
  chomp;
  next if /^Ensembl/;
  my ($ens, $name, $biotype, $des, $entrez, $WikiName, $WikiDes) = split /\t/;
  $gene2des{$name} = $des;
  $gene2des{$ens} = $des;
  $gene2des{$entrez} = $des;
  $gene2biotype{$name} = $biotype;
  $gene2biotype{$ens} = $biotype;
  $gene2biotype{$entrez} = $biotype;
}
close BM;

my %gene2length;
open LL, "$genelength";
while ( <LL> ){
  chomp;
  my ($ens, $gc, $elength, $tlength, $ilength, $symbol, $entrez) = split /\t/;
  $gene2length{$symbol} = $elength;
  $gene2length{$ens} = $elength;
}
close LL;

my %tsgs;
open TSG, "$tsg";
while ( <TSG> ){
  chomp;
  next if /^Gene_symbol/;
  my @cols = split /\t/;
  $tsgs{$cols[0]} = 1;
}
close TSG;

my %census;
open CEN, "$census";
while ( <CEN> ){
  chomp;
  next if /^Gene Symbol/;
  my @cols = split /\t/;
  $census{$cols[0]} = 1;
}
close CEN;


my %type2int;
$type2int{'snv'} = 2;
$type2int{'snv&somatic'} = 3;
$type2int{'indel'} = 4;
$type2int{'indel&somatic'} = 5;
$type2int{'fusion'} = 6;
$type2int{'cnva'} = '+';
$type2int{'cnvd'} = '-';
$type2int{'hypermethy'} = 7;
my %int2type;
$int2type{2} = 'snv';
$int2type{3} = 'snv&somatic';
$int2type{4} = 'indel';
$int2type{5} = 'indel&somatic';
$int2type{6} = 'fusion';
$int2type{'+'} = 'cnva';
$int2type{'-'} = 'cnvd';
$int2type{7} = 'hypermethy';


my @rectum = sort {$a =~ /($prefixReg)(\d+)?([A-Za-z0-9\-\_]+)?/; my $pa = $1; my $ia = $2; my $ias = $3; $b =~ /($prefixReg)(\d+)?([A-Za-z0-9\-\_]+)?/; my $pb = $1; my $ib = $2; my $ibs = $3; $pa cmp $pb or $ia <=> $ib or $ias cmp $ibs} keys %somatic;
my %rectum;
foreach my $rec (@rectum) {
  $rectum{$rec} = '';
}

my %result;
foreach my $file (@files) {
  my $type;
  if ($file =~ /merged/) {  #it is an already merged table
    $type = 'merged';
  } else {
    if ($file =~ /snv/) {
      $type = 'snv';
      if ($file =~ /somatic/) {
        $type .= '&somatic';
      }
    } elsif ($file =~ /indel/) {
      $type = 'indel';
      if ($file =~ /somatic/) {
        $type .= '&somatic';
      }
    } elsif ($file =~ /fusion/) {
      $type = 'fusion';
    } elsif ($file =~ /copynumber/) {
      $type = 'cnv';
    } elsif ($file =~ /methy/) {
      $type = 'methy';
    }
  } #indiviual type

  open IN, "$file";
  my @name;
  while ( <IN> ) {
    chomp;
    next if ($_ =~ /^[\@\#]/);
    my @cols = split /\t/;
    if ($_ =~ /^gene\t/) {
      @name = @cols;
      next;
    } else {
      my $gene;
      for (my $i = 0; $i <= $#cols; $i++) {
        if ($name[$i] eq 'gene'){
          $gene = $cols[$i];
        }
        if ($name[$i] =~ /(($prefixReg)([A-Za-z0-9\-\_]+)?)$/) {
          my $sample = $1;
          my $typenow = $type;

          #already merged ones######################################
          if ( $type eq 'merged' ){  #already merged table processing
            $cols[$i] =~ s/23/3/;
            while ($cols[$i] =~ /([\+\-]?\d)/g) {
              if ($1 != 0){
                $typenow = $int2type{$1};
                #print STDERR "$typenow\n";
                $result{$gene}{$sample}{$typenow} = 1;
              }
            }
            next; #jump out for merged table
          }
          #already merged ones######################################

          if ($type eq 'cnv') {
            if ($cols[$i] eq 'NA') {
              #do nothing
            } elsif ($cols[$i] > 1) {
              $typenow = $type.'a';
            } elsif ($cols[$i] <= 1) {
              $typenow = $type.'d';
            }
          } elsif ($type eq 'methy') {
            if ($cols[$i] eq 'NA') {
              #do nothing
            } elsif ($cols[$i] >= 0.65) {
              $typenow = 'hypermethy';
            }
          }
          $result{$gene}{$sample}{$typenow} = $cols[$i];
        }                         #it is sample
      }                           #iterator
    }                             #else
  }
  close IN;
}


print "gene";
foreach my $sample (@rectum){
  print "\t$sample";
}
#foreach my $sample (@ileum){
#  print "\t$sample";
#}
print "\tsumT\tsum\tentrez\tchr\telength\tbiotype\tdes\tTSG\tCensus\n";

foreach my $gene (keys %result) {
  print "$gene";
  my $rectum = 0;
  #my $ileum  = 0;
  my %sumRec;
  #my %sumIle;
  foreach my $sample (@rectum) {     #rectum
    my $changed = 0;
    my $vars;
    foreach my $type (sort {my $ta = $type2int{$a}; my $tb = $type2int{$b}; $ta <=> $tb} keys %{$result{$gene}{$sample}}) {
      if ($result{$gene}{$sample}{$type} > 0 and $result{$gene}{$sample}{$type} ne 'NA') {
         #$vars .= $type.","
         $vars .= $type2int{$type};
         if ($vars ne ''){
           $changed = 1;
         }
         $sumRec{$type2int{$type}} = '';
      }
    }
    if ($vars eq ''){
      $vars = 0;
    }
    $rectum += $changed;
    print "\t$vars";
  }

  my $sumRec = join("", sort {$a <=> $b} keys %sumRec);
  $sumRec = ($sumRec eq '')? 0 : $sumRec;
  print "\t$sumRec\t$rectum";


  #add columns
  #entrez\tchr\telength\tbiotype\tdes\tTSG\tCensus
  my $entrez = $gene2entrez{$gene};
  my $chr = $gene2chr{$gene};

  my $elength = '';
  if (exists ($gene2length{$gene})){
    $elength = $gene2length{$gene};
  } elsif (exists ($gene2length{$gene2ens{$gene}})){
    $elength = $gene2length{$gene2ens{$gene}};
  }

  my $biotype = '';
  if (exists ($gene2biotype{$gene})){
    $biotype = $gene2biotype{$gene};
  } elsif (exists ($gene2biotype{$gene2ens{$gene}})){
    $biotype = $gene2biotype{$gene2ens{$gene}};
  } elsif (exists ($gene2biotype{$gene2entrez{$gene}})) {
    $biotype = $gene2biotype{$gene2entrez{$gene}};
  }

  my $des = '';
  if (exists ($gene2des{$gene})){
    $des = $gene2des{$gene};
  } elsif (exists ($gene2des{$gene2ens{$gene}})){
    $des = $gene2des{$gene2ens{$gene}};
  } elsif (exists ($gene2des{$gene2entrez{$gene}})) {
    $des = $gene2des{$gene2entrez{$gene}};
  }

  my $tumorsg = (exists($tsgs{$gene}))? $tsgs{$gene} : 0;
  my $censusg = (exists($census{$gene}))? $census{$gene} : 0;

  print "\t$entrez\t$chr\t$elength\t$biotype\t$des\t$tumorsg\t$censusg\n";

}

exit 0;

