#!/usr/bin/perl -w
#Demon for numeric constants, some calculations, bitwise operator, ++
#print multiple varible, or with calculation, or without '\n'
#while/if/elsif/else with comparison operators, last/next/exit
$num1 = 10;
$num2 = ($num1 * $num1 + 2) % $num1;
$num3 = ($num1 - 7) ** 2;
$num4 = $num2 << 1;
print "$num2 $num3\n";
print $num1 - $num2, "\n";
print $num4 >> 1, "\n";
while ($num3 eq 9) {
    if ($num2 eq 2) {
        $num2++;
        next;
    } elsif ($num1 > $num2 || $num2 == 2) {
        print "Line not change";
        if ($num1 != 0 && $num3 <= $num1) {
            print " Line change\n";
            last;
	}
    } else {
        exit(0);
    }
}
