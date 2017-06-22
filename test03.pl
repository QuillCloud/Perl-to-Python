#!/usr/bin/perl -w
# change input string to float might not work well with some comparison 
# like 'eq' since stirng and float both can use 'eq'
$a = <STDIN>;
if ($a < 1) {
    print "test change type\n";
}
$b = <STDIN>;
if ($b eq 1) {
    print "test change type\n";
}
