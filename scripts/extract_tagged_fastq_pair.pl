use IO::Uncompress::Gunzip;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use strict;

my $num_to_output = 100;

if (@ARGV < 1) {
    print "Usage: $0 read_file_with_tag-barcode_R1.fastq.gz [tag_1 tag_2]\n";
    print "will search for tag_1 in the R1 read file and tag_2 in the R2 file\n";
    print "a match in either R1 or R2 will trigger both reads being written to the output file (i.e. pairing will be maintained)\n";
    print "output: the first $num_to_output reads containing tags will be output as tag1_xxxx_reads.fasta and tag2_xxxx_reads.fasta\n";
    print "if tags are not specified and are present as 8bp stretches in file name flanked by '-' or '_', these will be used\n";
    exit(0);
}
my ($read1_file, $tag1, $tag2) = @ARGV;

if ($tag1 and $tag2) {
    $tag1 =~ /^[ACGT]*$/ or die "tag1 has non-(ACGT) characters, exiting.\n";
    $tag2 =~ /^[ACGT]*$/ or die "tag2 has non-(ACGT) characters, exiting.\n";
}
else {
    print "Two tags not provided, will try to parse from file name.\n";
    $read1_file =~ /[_-]([ACGT]{8})[_-]([ACGT]{8})[_-]/ or die "cannot parse tags from file name: $read1_file";
    ($tag1, $tag2) = ($1, $2);
}
my @pattern = ($tag1, $tag2);

print STDERR "saving reads with tags as tag_1_reads.fasta and tag_2_reads.fasta\n";

my $read2_file = $read1_file;
$read2_file =~ s/_R1/_R2/ or die "cannot switch R1 to R2 to find read 2 file";
die "cannot find read 2 file $read2_file" unless -f $read2_file;

print STDERR "read1 fastq file = $read1_file\nextract read pairs with either of these tags: ", join(" ", @pattern), "\n";

my %tagged_read_ids;
my @read_files = ($read1_file, $read2_file);
for my $index (0..1) {
    my $read_file = $read_files[$index];
    my $tag = $pattern[$index]; 
    print STDOUT "reading $read_file looking for $tag\n";
    my $zin = IO::Uncompress::Gunzip->new($read_file, MultiStream => 1 ) or die "IO::Uncompress::Gunzip failed: $GunzipError\n"; 
    my $line_no = 0;
    my $num_tagged = 0;
    my $num_read = 0;
    while (<$zin>) {
        chomp;
        my $id = $_; 
        $id =~ s/ .*//;
        $_ = <$zin>;
        if (/$tag/) {
            $tagged_read_ids{$id} = 1;
            $num_tagged++
        }
        <$zin>; #second id line
        <$zin>; #quality scores
        $num_read++;
        last if $num_tagged >= $num_to_output;
    }
    print STDERR "Number of tagged reads this file = $num_tagged\nNumber read = $num_read\n";
    print STDERR "Number of tagged read ids: ", scalar keys %tagged_read_ids, "\n";
    #print STDERR "file pos is ", tell $z, "\n";
    close($zin);
}

for my $index (0..1) {
    my $read_file = $read_files[$index];
    my $tag = $pattern[$index]; 
    my $read_num = $index + 1; # one-based
    my $out_file = "tag${read_num}_${tag}_reads.fasta";
    open my $tagged_out, ">$out_file";
    print STDOUT "writing $out_file\n";
    my $zin = IO::Uncompress::Gunzip->new($read_file, MultiStream => 1 ) or die "IO::Uncompress::Gunzip failed: $GunzipError\n"; 
    my $total_reads = 0;
    my $num_tagged = 0;
    while (<$zin>) {
        my $id = $_; 
        chomp($id);
        $id =~ s/ .*//;
        my $seq = <$zin>;
        if (exists $tagged_read_ids{$id}) {
            $num_tagged++;
            print $tagged_out ">${tag}_$num_tagged\n$seq";
        }
        $_ = <$zin>;
        $_ = <$zin>;
        $total_reads++;
        last if $num_tagged >= $num_to_output;
    }
    print "Total reads = $total_reads (stopping after $num_to_output tagged ones)\nNum tagged = $num_tagged\n";
    print "R$read_num reads with tag$read_num ($tag) are written to $out_file\n";
    close($zin);
    close $tagged_out;
}
