#!/usr/bin/perl -w
# not just need inilize the hash, but also need to intial values in hash
while ($line = <>) {
    $count{$line}++;
}
