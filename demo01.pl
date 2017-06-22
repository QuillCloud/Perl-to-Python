#!/usr/bin/perl -w 
#Demo for <STDIN> (two ways), simple array with push
#foreach, '.' and '.=', chomp, join, split, reverse, sort
print "Input some words. Type 'end' for exit\n";
while ($line = <STDIN>) {
    chomp $line;
    if ($line eq "end") {
        last;
    }
    push @check, $line;
}
$b = "";
print "Print in reverse:";
foreach $a (reverse @check) {
    $b .= $a . " ";
}
print "$b\n";
print "Print not reverse:";
print join(' ', @check), "\n";
print "Input a sentence\n";
$sentence = <STDIN>;
chomp $sentence;
@words = split / /, $sentence;
print "Print with sort:\n";
foreach $i (sort @words) {
    print "$i\n";
}
