#!/usr/bin/perl -w
# in perl, value in array change, in python, might not change
$s = "1 2 3 4 5";
@ta = split (/ /, $s);
foreach $i (@ta) {
    $i = 0;
}
print join(' ', @ta), "\n";
