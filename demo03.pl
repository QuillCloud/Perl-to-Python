#!/usr/bin/perl -w
# Copyright: examples/4/devowel.pl examples/5/count_enrollments.pl
# demo for '<>', hash(dictionary in python), and exists sort
# open file, read each line
print "Test for <>. Please enter some words\n";
while ($line = <>) {
    chomp $line;
    if (exists $hash{$line}) {
        $hash{$line}++;
    } else {
        $hash{$line} = 1;
    }
}
print "------------\n";
foreach $a (sort keys %hash) {
    print "$a : $hash{$a}\n"
}
print "------------\n";
open F, "<plpy.pl";
$count = 0;
while ($f = <F>) {
    if ($f =~ /^\s*#/) {
        $count++;
    }
}
print "Comment lines of plpy.pl: $count\n";
