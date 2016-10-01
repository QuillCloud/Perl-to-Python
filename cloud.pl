#!/usr/bin/perl -w

# written by Yunhe Zhang(z5045582)
@checkloop = ();
sub split_join {
    my ($sj) = @_;
    if ($sj =~ /split\s*\(*\/(.*)\/,\s*([^)]*)\)*/) {
	$temp1 = &varible($2);
	$temp2 = &varible($1);
	$sj = "$temp1.split(\'$temp2\')";
    } elsif ($sj =~ /join\s*\(*(.*)\,\s*([^)]*)\)*/) {
	$temp1 = &varible($1);
	$temp2 = &varible($2);
	$sj = "$temp1.join($temp2)";
    }
    return $sj;
}
sub varible {
    my ($v) = @_;
    my $lenflag = 0;
    if ($v =~ /^\$/) {
	$v =~ s/\$//g;
	if ($v =~ /^\#(.*)/) {
	    $v =~ s/\#//g;
	    $lenflag = 1;
	}
    } elsif ($v =~ /@(.*)/) {
	if ($1 =~ /^ARGV$/) {
	    $imp_dic{"sys"} = 1; 
	    $v = "sys.argv[1:]";
	} else {
	    $v = $1;
	}
    }
    if ($lenflag ne 0) {
	$v = "len($v) - 1";
    }
    return $v
}
sub pstring {
    my ($s) = @_;
    my @str = split(/ /, $s);
    my @ps_list = ();
    my @v_list = ();
    foreach $s_str (@str) {
	if ($s_str =~ /^\$(.*)/) {
	    push @ps_list, "%s"; 
	    push @v_list, &varible($1);
	} else {
	    push @ps_list, $s_str;
	}
    }
    if ($#ps_list eq 0 && $#v_list eq 0) {
	$s = $v_list[0];
    } elsif ($#ps_list ne -1)  {
	$s = join(' ', @ps_list);
	$s = "\"" . $s . "\"";
	if ($#v_list ne -1) {
	    $temp = join(' ', @v_list);
	    $s .= " % $temp";
	}
    }
    return $s;
}

sub calculation {
    my ($cal) = @_;
    my @sc_list = ();
    @cstr = split(/\s+/, $cal);
    foreach $cs (@cstr) {
	if ($cs =~ /[\+\-\*\/\%\(\)]/) {
	    push @sc_list, $cs;
	} elsif ($cs =~ /[\<\>\^\|\&\~]/) {
	    push @sc_list, $cs;
	} else {
	    push @sc_list, &varible($cs);
	}
    }
    $cal = join(' ', @sc_list);
    return $cal;
}
sub condition {
    my ($con) = @_;
    my @con_list = ();
    @conele = split(/\s+/, $con);
    foreach $sconele (@conele) {
	if ($sconele =~ /^\$/) {
	    push @con_list, &varible($sconele);
	} else {
	    $sconele =~ s/\|\|/or/g;
	    $sconele =~ s/\&\&/and/g;
	    $sconele =~ s/eq/==/g;
	    $sconele =~ s/ne/!=/g;
	    if ($sconele ne "") {
		push @con_list, $sconele;
	    }
	}
    }
    $con = join(' ', @con_list);
    return $con;
}
while ($line = <>) {
    if ($#checkloop ne -1) {
	$line =~ /(\s*)[^\s]*/;
	if (length($1) < $checkloop[0]) {
	    push @output, $checkloop[1];
	    @checkloop = ();
	}
    }
    if ($line =~ /^#!/ && $. == 1) {

        # translate #! line

        print "#!/usr/local/bin/python3.5 -u\n";
    } elsif ($line =~ /^\s*#/ || $line =~ /^\s*$/) {

        # Blank & comment lines can be passed unchanged

        push @output, $line;
    } elsif ($line =~ /(\s*)print\s*([^;]*)/) {
	$clflag = 0;
	$p = "$1print(";
	@content = split(/[^\'\/],/, $2);
	foreach $c (@content) {
	    if ($c =~ /\"(.*)\"/) {
		$c = $1;
		if ($c =~ /\\n/) {
		    $clflag = 1;
		    $c =~ s/\\n//g;
		}
		$p .= &pstring($c);
	    } elsif ($c =~ /split/ || $c =~ /join/) {
		$p .= &split_join($c);
	    } else {
		if ($c =~ /([\+\-\*\/\%]+)/) {
		    $p .= &calculation($c);
		} else {
		    while ($c =~ m/\$([^\$| ]*)/g) {
			$p .= &varible($1);
		    }
		}
	    }
	}
	if ($clflag eq 1) {
	    $p .= ")";
	} else {
	    $p .= ", end = '')";
	}
	push @output, "$p\n";
    } elsif ($line =~ /^(\s*)\}*\s*(if|elsif)/) {
	push @output, "$1";
	if ($2 eq "elsif") {
	    $ifl = "elif ";
	} else {
	    $ifl = "if ";
	}
	$line =~ /\((.*)\)/;
	$ifl .= &condition($1);
	$ifl .= ":\n";
	push @output, $ifl;
    } elsif ($line =~ /^(\s*)\s*while\s*\((.*)\)/) {
	push @output, "$1";
	$whl = "while ";
	$whl .= &condition($2);
	$whl .= ":\n";
	push @output, $whl;
    } elsif ($line =~ /^(\s*)foreach\s*([^\s]*)\s*\((.*)\)/) {
	push @output, "$1for ";
	push @output, &varible($2);
	push @output, " in ";
	$focon = $3;
	if ($focon =~ /([^\.]*)\.\.([^\.]*)/) {
	    $fostart = &varible($1);
	    $foend = &varible($2);
	    if ($foend =~ /^\d+$/) {
		$foend++;
	    } else {
		$foend .= " + 1";
	    }
	    if ($fostart eq 0) {
		push @output, "range($foend)";
	    } else {
		push @output, "range($fostart, $foend)";
	    }
	} else {
	    @finac = split(/\s+/, $focon);
	    if ($#finac eq 0) {
		push @output, &varible($finac[0]);
	    }
	}
	push @output, ":\n";
    } elsif ($line =~ /^(\s*)for\s*\((.*)\)/) {
	$space = $1;
	@forloop = split(/;/, $2);
	$forloop[0] =~ /([^\s]*)\s*=\s*([^\s]*)/;
	$ini = &varible($1);
	$ini .= " = ";
	$ini .= &varible($2);
	push @output, "$space$ini\n";
	$forloopcon = &condition($forloop[1]);
	push @output, "$space";
	push @output, "while $forloopcon:\n";
	if ($forloop[2] =~ /\s*([^\s]*)\+\+/) {
	    $checkloop[0] = length($space) + 4;
            $checkloop[1] = "$space    ";
            $checkloop[1] .= &varible($1);
            $checkloop[1] .= " += 1\n";
	} elsif ($forloop[2] =~ /\s*([^\s]*)\-\-/) {
	    $checkloop[0] = length($space) + 4;
	    $checkloop[1] = "$space    ";
            $checkloop[1] .= &varible($1);
            $checkloop[1] .= " -= 1\n";
	}
    } elsif ($line =~ /(\s*)([^\s]*)\s*=\s*([^;]*)/) {
	push @output, $1;
	$left = varible($2);
	$right = $3;
	if ($right =~ /split/) {
	    $right = &split_join($right);
	} elsif ($right =~ /join/) {
	    $right = &split_join($right);
	} elsif ($right =~ /[\+\-\*\/\%]+/ || $right =~ /^\d+/) {
	    $right = &calculation($right);
	} elsif ($right =~ /[\<\>\^\|\&\~]/) {
	    $right = &calculation($right);
	} elsif ($right =~ /^<STDIN>$/) {
	    $imp_dic{"sys"} = 1;
	    $right = "sys.stdin.readline()";
	}
	push @output, "$left = $right\n";
    } elsif ($line =~ /^\s*}$/) {
	next;
    } elsif ($line =~ /^(\s*)\}*\s*else/)  {
	push @output, "$1else:\n";
    } elsif ($line =~ /^(\s*)(next|last);$/) {
	$line =~ s/next/continue/g;
	$line =~ s/last/break/g;
	$line =~ s/;//g;
	push @output, $line;
    } elsif ($line =~ /^(\s*)chomp\s*([^;]*)/)  {
	push @output, "$1";
	$chomp = &varible($2);
	push @output, "$chomp = $chomp.rstrip()\n";
    } elsif ($line =~ /^\s*exit/) {
	$line =~ s/;//g;
	push @output, $line;
    } elsif ($line =~ /^(\s*)(.*)\+\+/) {
	$plus = &varible($2);
	push @output, "$1$plus += 1\n";
    } elsif ($line =~ /^(\s*)(.*)\-\-/) {
        $plus = &varible($2);
        push @output, "$1$plus -= 1\n";
    } else {
	
        # Lines we can't translate are turned into comments

        push @output, "#$line\n";
    }
    
}
foreach $imp (keys %imp_dic) {
    print "import $imp\n";
}
foreach $o (@output) {
    print "$o";
}
