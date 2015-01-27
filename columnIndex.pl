use strict;

my $column = shift;
my $columnIndex = "not found";
my $file = shift;

my @colnames;
open IN, "$file";
while ( <IN> ){
  chomp;
  if (/^#/ or /^chr\t/ or /^gene\t/){
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
