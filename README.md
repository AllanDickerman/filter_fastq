# filter_fastq
Filter out fastq reads that match a sequence pattern.

This project attempts to solve the problem of a fastq read set being contaminated with reads having an artificial construct that should not be there. The example that motivated this was a condition where bar-codes attached to PCR primers was present in a proportion of the reads.

The program filter_fastq_pair_single_pattern.pl does the following:
- Takes two parameters:
- 1 Read_1 fastq file name (gzipped or uncompressed)
- 2 sequence to be filtered out (or default CTGTCTCTTATACACATCT)
- - - The default sequence was the one that worked for the problem the program was designed for.

- The program will calculate the Read_2 file name by replacing _R1 with _R2 in the file name.
- - If your file names do not conform to this pattern you will need to alter the code or your file names.

- The program will then open the Read_1 file and examine the sequence data of each fastq record to find an approximate match to the specified (or default) sequence pattern. It uses a system call to agrep, which must be present on the system. It currently searches for patterns within 3 differences from the specified sequence. It stores the row numbers of all records that match the pattern.

- Then it does the same for the Read_2 file, adding the index of any records that match to the previous set.

- Then it reads Read_1 file again and write out all fastq records NOT on the list of 'bad' reads found in the preceding steps. Output is written to a file based on the Read_1 file plus the string 'filtered' plus the sequence that is being searched for. The output is gzip compressed.

- Then it does the same for the Read_2 file. 

In the end, you have two new gzipped fastq read files which are filtered of any reads matching the search sequence within a fixed tolerance (within 3 differences in current implementation). 
