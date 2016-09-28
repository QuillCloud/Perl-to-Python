#!/usr/bin/perl -w

# written by Yunhe Zhang(z5045582)
@output = ();
%import_dic = ();
sub argv_f {
    my ($a) = @_;
    $import_dic{sys} = 1;
    return "sys.argv[1:]"
}
sub join_f {
    my ($inter, $array) = @_;
    if ($array eq "ARGV") {
	$array = argv_f($array);
    }
    return "\'$inter\'.join\($array\)";
}
while ($line = <>) {
    if ($line =~ /^#!/ && $. == 1) {
    
        # translate #! line 
        
        print "#!/usr/local/bin/python3.5 -u\n";
    } elsif ($line =~ /^\s*#/ || $line =~ /^\s*$/) {

        # Blank & comment lines can be passed unchanged
        
        push @output, $line;
    } elsif ($line =~ /(\s*)chomp\s*\$(.*);/) {

	#deal with 'chomp' line
	
	push @output, "$1$2 = $2.rstrip()\n";
    } elsif ($line =~ /(.*)print\s*(.*);$/) {
        
        # Python's print adds a new-line character by default
        # so we need to delete it from the Perl print statement
	
	# Check if print contain the varibles
	push @output, "$1print(";
	$p_content = $2;
	$p_content =~ s/\\n//g;
	if ($p_content =~ /(.*),\s*(.*)/) {
	    $p = $1;
	    $p =~ s/\$//g;
	    if ($p =~ /join\(\'(.*)\', @(.*)\)/) {
		$p = join_f($1, $2);
	    }
	    push @output, "$p";
	} elsif ($p_content =~ /"\$(.*)"/) {
	    push @output, "$1";
	} else {
	    push @output, "$p_content";
	}
	if ($line =~ /\\n\";/) {
	    push @output, ")\n";
	} else {
	    push @output, ", end = '')\n";
	}
    } elsif ($line =~ /(\s*)(.*)=\s*(.*);$/){
	
	#give the value to varible, detect the '='
	push @output, "$1";
	$right = $3;
	$left = $2;
	if ($left =~ /\$/) {
	    if ($right =~ /\<STDIN\>/) {
		$import_dic{"sys"} = 1;
		$right = "sys.stdin.readline()";
	    } elsif ($right =~ /join\(\'(.*)\', @(.*)\)/) {
		$right = join_f($1, $2);
	    } elsif ($right =~ /\$/) {
		$right =~ s/\$//g;
	    }
	} elsif ($left =~ /@/) {
	    if ($right =~ /split\s*\/(.*)\/,\s*\$(.*)/) {
		$right = "$2.split('$1')"
	    }
	}
        $left =~ s/\$|@//g;
	push @output, "$left= $right\n";
    } elsif ($line =~ /if/||$line =~ /while/){
	
	#deal with if and while, change '||' to 'and'
	#change '$$' to 'or', change 'ne' to '!=',
	#change 'eq' to '=='
	
	$p = $line;
	$p =~ s/ \|\| / and /g;
	$p =~ s/ && / or /g;
	$p =~ s/\$|\(|\)//g;
	$p =~ s/ ne / != /g;
	$p =~ s/ eq / == /g;
	$p =~ s/\s*{/:/g;
	push @output, "$p";
	
    } elsif ($line =~ /(\s*)foreach\s*\$(.*)\s*\((.*)\)/) {

	#deal with foreach

	push @output, "$1for $2in ";

	#deal with senario like "foreach $x (@y)"
	if ($3 =~ /@(.*)/) {
	    $fep = $1;
	    if ($fep eq "ARGV") {
		$fep = argv_f($fep);
	    }
	    push @output, "$fep:\n";
	}
	#deal with senario like "foreach $x (1..20)"
	elsif ($3 =~ /(\d+)..(\d+)/) {
	    $num = $2 + 1;
	    push @output, "range($1,$num):\n";
	}
    } elsif ($line =~ /(\s*)for\(\$(.*);\s*\$(.*);\s*\$(.*)\+\+\)/) {
	
	#deal with for, use 3 lines
	
	push @output, "$1$2\n";
	push @output, "$1while $3:\n";
	push @output, "$1$4 += 1\n";
    } elsif ($line =~ /\s*}\n/){
	
        #deal with "}"

	next;
    } elsif ($line =~ /(\s*)\$(.*)\+\+/) {

	#deal with ++

	push @output, "$1$2 += 1\n";
    } elsif ($line =~ /(\s*)\$(.*)\-\-/) {
	
	#deal wiht --

	push @output, "$1$2 -= 1\n";
    } elsif ($line =~ /(\s*)next;/) {
	
	#translate next to continue
	
	push @output, "$1";
	push @output, "continue\n";
    }  elsif ($line =~ /(\s*)last;/) {
	
	#translate last to break
	
        push @output, "$1";
        push @output, "break\n";
    } else {
	
        # Lines we can't translate are turned into comments
        
	push @output, "#$line\n";
    }
}
foreach $i (keys %import_dic) {
    print "import $i\n";
}
foreach $x (@output) {
    print "$x";
}
