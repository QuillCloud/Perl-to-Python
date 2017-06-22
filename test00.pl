#!/usr/bin/perl -w
# when print get some special meaning symbol, might not translate well
# for example "%" ","
$a = 102;
$b = $a % 10;
print "$a % 10 = $b", "\n";
