#!/usr/bin/perl -w
# Copyright:examples/2/echonl.0.pl  examples/2/echonl.1.pl
# Demon for foreach contain 'ARGV', and for loop (like in c)
# and regexes(// and s///), 4 operators for array(pop, push, shift, unshift)
if ($#ARGV ne -1) {
    foreach $arg (@ARGV) {
        $pr = $arg;
        $pr =~ s/[aeiou]//g;
        print "$pr\n";
    }
    foreach $i (0..$#ARGV) {
        push @elements, $ARGV[$i]
    }
    for($a = 0; $a < 15; $a++) {
        print "-";
    }
    print "\n";
    $b = pop @elements;
    print "Pop $b\n";
    unshift @elements, $b;
    print "Unshift $b\n";
    $b = shift(@elements);
    print "Shift $b\n";
    if ($b =~ /[0-9]/) {
        print "Input contains number\n";
    } else {
        print "Input not contains number\n";
    }
} else {
    print "Nothing input\n";
}
