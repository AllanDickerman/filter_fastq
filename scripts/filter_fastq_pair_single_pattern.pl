use IO::Uncompress::Gunzip;
use IO::Compress::Gzip;
use IO::Compress::Gzip qw(gzip $GzipError);
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use strict;

if (@ARGV < 1) {
    print "Usage: $0 read_file_with_barcode-barcode_R1.fastq.gz [pattern default CTGTCTCTTATACACATCT]\n";
    print "will parse barcodes from file name and search for them in R1 and R2\n";
    print "output: reads lacking barcodes in read_file_R1_filtered_{pattern}.fastq.gz (and ..._R2_filtered_{pattern}...).\n";
    print "reads with pattern are written in fasta files as  ..R1_contam_{pattern}.fasta.\n";
    exit(0);
}
my ($read1_file, $pattern) = @ARGV;
$pattern = 'CTGTCTCTTATACACATCT' unless $pattern; #default
$pattern =~ /^[ACGT]*$/ or die "sequence pattern must consist solely of A,C,G,T ($pattern)\n";

my $read2_file = $read1_file;
$read2_file =~ s/_R1/_R2/ or die "cannot switch R1 to R2 to find read 2 file";
die "cannot find read 2 file $read2_file" unless -f $read2_file;

print STDERR "read fastq files: \n$read1_file\n$read2_file\nfilter out reads with approximation (within 2) of this pattern: $pattern\n";
$| = 1;
my %bad_read_index;
my $max_bad_index = 0;
for my $read_file ($read1_file, $read2_file) {
    my $command = 'zcat -f ' . $read_file . ' | perl -ne \'print if $i++ % 4 == 1\' | agrep -3 -n ' . $pattern;
    print STDERR "command = #$command#\n";
    open my $PROC, "$command|";
    my $line_no = 0;
    while (<$PROC>) {
        my ($index, $read) = split(":", $_);
        print "Got $index -- $read\n" if $line_no < 1;
        $bad_read_index{$index} = 1;
        $line_no++;
        $max_bad_index = $index if $index > $max_bad_index;
    }
    close($PROC);
    print "Number of matching reads: $line_no\n";
    print "max_bad_index = $max_bad_index\n";
    print "Number of non-redundnat bad indexes = ". scalar keys %bad_read_index, "\n";
}


for my $read_file ($read1_file, $read2_file) {
    my $out_file = $read_file;
    $out_file =~ s/fastq.gz/filtered_${pattern}_fastq.gz/ or die "Could not format output file name by replacing 'fastq.gz' extension on $read_file";
    print STDOUT "writing good reads to $out_file\n";
    my $zout = IO::Compress::Gzip->new($out_file) or die "IO::Compress::Gzip failed: $GzipError\n";
    my $zin = IO::Uncompress::Gunzip->new($read_file, MultiStream => 1 ) or die "IO::Uncompress::Gunzip failed: $GunzipError\n"; 
    my $fasta_out;
    if (0) {
        $out_file = $read_file;
        $out_file =~ s/fastq.gz/containing_${pattern}.fasta/ or die "cannot create fasta outfile name by substituting.";
        open ($fasta_out, ">", $out_file) or die "cannot open $out_file for writing: : $!";
    }
    my $line_no = 0;
    my $fastq_record_index = 0; # 1-based record index, to match against bad_read_index
    my $num_bad = 0;
    my $num_good = 0;
    while (<$zin>) {
        $fastq_record_index++;
        if (exists $bad_read_index{"$fastq_record_index"}) {
            #print STDERR "found bad index: $fastq_record_index\n";
            # read 4 lines (including current) but do not write anything
            $_ = <$zin>;
            if (0) {
                print $fasta_out ">$fastq_record_index\n$_";
            }
            $_ = <$zin>;
            $_ = <$zin>;
            $num_bad++;
        }
        else { # read and write this record
            #print STDERR "good index: $fastq_record_index\n";
            print $zout $_;
            $_ = <$zin>;
            print $zout $_;
            $_ = <$zin>;
            print $zout $_;
            $_ = <$zin>;
            print $zout $_;
            $num_good++;
        }
        last if $fastq_record_index >= $max_bad_index;
    }
    print STDOUT "Num good reads = $num_good\n";
    print STDOUT "Num bad reads = $num_bad\n";
    close($zin);
    close($zout);
    close($fasta_out) if 0;
}
