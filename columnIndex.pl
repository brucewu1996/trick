use strict;

my $column = shift;
my $columnIndex = "not found";
my $file = shift;
my $headerPattern = shift;
if ($headerPattern eq ''){
  $headerPattern = '#';
}

my @colnames;
open IN, "$file";
while ( <IN> ){
  chomp;
  if (/^#/ or /^[cC][hH][rR][oO]?[mM]?\t/ or /^[gG]ene\t/ or /^$headerPattern/){
    @colnames = split /\t/;
    for(my $i = 0; $i <= $#colnames; $i++){
      if ($colnames[$i] eq $column){
         $columnIndex = $i;
      }
    }
  } else {
    last;
  }
}
close IN;

print "$columnIndex\n";

exit 0;
