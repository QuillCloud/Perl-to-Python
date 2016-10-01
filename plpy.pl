#!/usr/bin/perl -w

# written by Yunhe Zhang(z5045582)

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
    } elsif ($line =~ /(.*)print\s*(.*)/) {
        
        # Python's print adds a new-line character by default
        # so we need to delete it from the Perl print statement
	
	# Check if print contain the varibles
	push @output, "$1print(";
	$p_content = $2;
	$p_content =~ s/\\n|;//g;
	if ($p_content =~ /(.*),\s*(.*)/) {
	    $p = $1;
	    $p =~ s/\$//g;
	    if ($p =~ /join\(\'(.*)\', @(.*)\)/) {
		$p = join_f($1, $2);
	    }
	    push @output, "$p";
	} elsif ($p_content =~ /"\$(.*)"/) {
	    $p_content = $1;
	    if ($p_content =~ /ARGV\[\$*(.*)\]/) {
		$import_dic{sys} = 1;
		$p_content = "sys.argv[$1 + 1]";
	    }
	    push @output, "$p_content";
	} else {
	    push @output, "$p_content";
	}
	if ($line =~ /\\n\"/) {
	    push @output, ")\n";
	} else {
	    push @output, ", end = '')\n";
	}
    } elsif ($line =~ /(\s*)}\s*elsif(.*)/) {
        push @output, "$1elif";
        $p = $2;
        $p =~ s/ \|\| / and /g;
        $p =~ s/ && / or /g;
        $p =~ s/\$|\(|\)//g;
        $p =~ s/ ne / != /g;
        $p =~ s/ eq / == /g;
        $p =~ s/\s*{/:/g;
        $p =~ s/elsif//g;
        $p =~ s/}//g;
        push @output, "$p\n";
    } elsif ($line =~ /if/||$line =~ /while/){
	
	#deal with if and while, change '||' to 'and'
	#change '$$' to 'or', change 'ne' to '!=',
	#change 'eq' to '=='
	$p = $line;
	if ($p =~ /(\s*)\$(.*)=\s*<>/) {
	    $import_dic{"fileinput"} = 1;
	    $p = "$1for $2in fileinput.input():\n";
	} elsif ($p =~ /(\s*)\$(.*)=\s*<STDIN>/) {
	    $import_dic{sys} = 1;
	    $p = "$1for $2in sys.stdin:\n";
	} elsif ($p =~ /(\s*)(.*)\(\s*\$(.*)\s+=~\s*\/(.*)\/\)/) {
	    $import_dic{re} = 1;
	    $p = "$1$2re.search('$4', $3):\n"; 
	} else {
	    $p =~ s/ \|\| / and /g;
	    $p =~ s/ && / or /g;
	    $p =~ s/\$|\(|\)//g;
	    $p =~ s/ ne / != /g;
	    $p =~ s/ eq / == /g;
	    $p =~ s/\s*{/:/g;
	}
	push @output, "$p";
    } elsif ($line =~ /(\s*)(.*)=\s*(.*);*/){

        #give the value to varible, detect the '='
        push @output, "$1";
        $right = $3;
        $left = $2;
        $left =~ s/\./+/g;
        $right =~ s/\./+/g;
        if ($left =~ /\$/) {
            $left =~ s/\$//g;
	    if ($left =~ /(.*){(.*)}/) {
		$create_dic{$1} = 1;
		$left = "$1\[$2\] ";
	    }
            if ($right =~ /\<STDIN\>/) {
                $import_dic{sys} = 1;
                $right = "sys.stdin.readline()";
            } elsif ($right =~ /join\(\'(.*)\', @(.*)\)/) {
                $right = join_f($1, $2);
            } elsif ($right =~ /\$/) {
                $right =~ s/\$//g;
                if ($right =~ /ARGV\[\$*(.*)\]/) {
                    $import_dic{sys} = 1;
                    $right = "sys.argv[$1 + 1]";
                }
            } elsif ($right =~ /^~\s*s\/(.*)\/(.*)\//) {
                $import_dic{re} = 1;
                $right = "re.sub(r'$1', '$2',$left)";
            }
        } elsif ($left =~ /@/) {
            $left =~ s/@//g;
            if ($right =~ /split\s*\/(.*)\/,\s*\$(.*)/) {
                $right = "$2.split('$1')"
            }
        }
        $right =~ s/;//g;
        push @output, "$left= $right\n";
    } elsif ($line =~ /(\s*)}\s*else/) {
	push @output, "$1else:\n";
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
	
	elsif ($3 =~ /(.*)\.\.(.*)/) {
	    $start = $1;
	    $end = $2;
	    if ($start =~ /^\$(.*)/) {
		$start = $1;
	    }
	    if ($end =~ /^\$(.*)/) {
		$end = $1;
		if ($end =~ /^\#(.*)/) {
		    $end = $1;
		    if ($end =~ /ARGV/){
			$import_dic{sys} = 1;
			$end = "sys.argv";
		    }
		    $end = "len($end)";
		}
	    }
	    if ($start eq 0) {
		push @output, "range($end + 1):\n";
	    } else {
		push @output, "range($start, $end + 1):\n";
	    }
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
    } elsif ($line =~ /^(\s*)exit(.*);/) {
	push @output, "$1exit$2\n";
    } else {
	
        # Lines we can't translate are turned into comments
        
	push @output, "#$line\n";
    }
}
foreach $i (keys %import_dic) {
    print "import $i\n";
}
foreach $d (keys %create_dic) {
    print "$d = {}\n";
}
foreach $x (@output) {
    print "$x";
}
