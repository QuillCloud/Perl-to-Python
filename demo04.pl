#!/usr/bin/perl -w
# Copyright: examples/4/size.pl examples/4/odd0.pl
# Demo for change varible type of input, like change string to float
# also show $#array, regex s///, change value in array
print "Enter number:\n";
$a = <STDIN>;
if ($a < 0) {
    print "negative\n";
} elsif ($a >=0) {
    if ($a % 2 == 0) {
        print "Even\n";
    } else {
        print "Odd\n";
    }
}
print "Enter string(number will be replaced by ?):\n";
$b = <STDIN>;
chomp $b;
@bb = split (/ /, $b);
$l = $#bb + 1;
print "Number of words: $l\n";
foreach $i (0..$#bb) {
    $bb[$i] =~ s/[0-9]/?/g;
}
print join(' ', @bb), "\n";
