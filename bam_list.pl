use strict;
use File::Glob ':glob';



my %chr;
for(1..22) {
  $chr{$_} = '';
}
$chr{'X'} = '';
$chr{'Y'} = '';
$chr{'MT'} = '';

my $root = shift;
my $sample = shift;
my $suffix = shift;
my $delim = shift;   #by default it will generate bam files line by line


my @bam_files = bsd_glob("$root/*\.$suffix");
foreach my $bam_file (@bam_files){
  $bam_file =~ /^$root\/$sample\.(.+?)\.$suffix$/;
  my $chr = $1;
  if (exists($chr{$chr})) {
    if ($delim =~ /space/){
       print "$bam_file ";
       next;
    } elsif ($delim =~ /comma/){
       print "$bam_file,";
       next;
    }
    print "$bam_file\n";
  }
}
print "\n";
