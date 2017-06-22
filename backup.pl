#!/usr/bin/perl -w

# written by Yunhe Zhang(z5045582)
@checkloop = ();
@checkvtype = ();
@checkarray = ();
@checkhash = ();
sub split_join {
    my ($sj) = @_;
    if ($sj =~ /split\s*\(*\/(.*)\/,\s*([^)]*)\)*/) {
	$temp1 = &variable($2);
	$temp2 = &variable($1);
	$sj = "$temp1.split(\'$temp2\')";
    } elsif ($sj =~ /join\s*\(*(.*)\,\s*([^)]*)\)*/) {
	$temp1 = &variable($1);
	$temp2 = &variable($2);
	$sj = "$temp1.join($temp2)";
    }
    return $sj;
}
sub variable {
    my ($v) = @_;
    my $lenflag = 0;
    my $argvflag = 0;
    if ($v =~ /^\$/) {
	$v =~ s/^\$//g;
	if ($v =~ /^\#(.*)/) {
	    $v =~ s/^\#//g;
	    if ($v eq "ARGV") {
		$imp_dic{"sys"} = 1;
		$v = "sys.argv";
		$argvflag = 1;
	    }
	    $lenflag = 1;
	} elsif ($v =~ /(.*)\[(.*)\]/ || $v =~/(.*)\{(.*)\}/) {
	    $aname = $1;
	    $anum = &variable($2);
	    if ($aname eq "ARGV") {
		$imp_dic{"sys"} = 1;
		$argvflag = 1;
		$aname = "sys.argv";
		$anum .= " + 1";
	    }
	    $v = "$aname\[$anum\]";
	}
    } elsif ($v =~ /^@(.*)/) {
	if ($1 =~ /^ARGV$/) {
	    $imp_dic{"sys"} = 1; 
	    $v = "sys.argv[1:]";
	    $argvflag = 1;
	} else {
	    $v = $1;
	}
    } elsif ($v =~ /^%(.*)/) {
	$v = $1;
    }
    if ($lenflag ne 0) {
	if ($argvflag ne 0) {
	    $v = "len($v) - 2";
	} else {
	    $v = "len($v) - 1";
	}
    }
    return $v
}
sub pstring {
    my ($s) = @_;
    my @str = split(/\s+/, $s);
    my @ps_list = ();
    my @v_list = ();
    foreach $s_str (@str) {
	if ($s_str =~ /(^\$.*)/) {
	    push @ps_list, "%s"; 
	    push @v_list, &variable($1);
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
	} elsif ($cs =~ /\./) { 
	    push @sc_list, "\+";
	} else {
	    push @sc_list, &variable($cs);
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
	    if ($#checkvtype ne -1) {
		if ($checkvtype[0] eq &variable($sconele) && $con =~ /\<|\>/) {
		    $output[$checkvtype[2]] = "$checkvtype[3]$checkvtype[0] = float\($checkvtype[1]\)\n";
		    @checkvtype = ();
		}
	    }
	    push @con_list, &variable($sconele);
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

sub regex {
    my ($reg, $regl) = @_;
    $imp_dic{"re"} = 1;
    if ($reg =~ /^s\/(.*)\/(.*)\//) {
	$reg = "re.sub(r\'$1\', \'$2\', $regl)"
    }
    return $reg;
}

sub array_hash {
    my ($ahname, $mode) = @_;
    if ($mode eq "array") {
	if ( !grep( /^$ahname$/, @checkarray ) ) {
	    @cache = ();
	    while ($#output ne -1) {
		$temp1 = pop @output;
	        unshift @cache, $temp1;
		if ($temp1 =~ /while|for/ || $#output eq -1) {
		    $temp1 =~ /^(\s*)/;
		    push @output, "$1$ahname = []\n";
		    foreach $temp2 (@cache) {
			push @output, $temp2;
		    }
		    push @checkarray, $ahname;
		    return 0;
		}
	    }
	}
    } elsif($mode eq "hash") {
	if ( !grep( /^$ahname$/, @checkhash ) ) {
	    @cache = ();
	    while ($#output ne -1) {
                $temp1 = pop @output;
                unshift @cache, $temp1;
		if ($temp1 =~ /while|for/ || $#output eq -1) {
		    $temp1 =~ /^(\s*)/;
		    push @output, "$1$ahname = {}\n";
		    foreach $temp2 (@cache) {
			push @output, $temp2;
		    }
		    push @checkhash, $ahname;
		    return 0;
                }
            }
        }
    }
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
		    while ($c =~ m/(\$[^\$|\s]*)/g) {
			push @mulv, &variable($1);
		    }
		    $p .= join(',', @mulv);
		    @mulv = ();
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
	$ifl = "$1";
	if ($2 eq "elsif") {
	    $ifl .= "elif ";
	} else {
	    $ifl .= "if ";
	}
	$line =~ /\((.*)\)/;
	$ifl .= &condition($1);
	$ifl .= ":\n";
	push @output, $ifl;

    } elsif ($line =~ /^(\s*)\s*while\s*\((.*)\)/) {
	$whl = "$1";
	$temp1 = $2;
	if ($temp1 =~ /([^\s]*)\s*=\s*<(.*)>/) {
	    $temp2 = &variable($1);
	    $temp3 = $2;
	    if ($temp3 eq "") {
		$imp_dic{"fileinput"} = 1;
		$whl .= "for $temp2 in fileinput.input()";
	    } elsif ($temp3 eq "STDIN") {
		$imp_dic{"sys"} = 1;
		$whl .= "for $temp2 in sys.stdin";
	    }
	} else {
	    $whl .= "while ";
	    $whl .= &condition($temp1);
	} 
	$whl .= ":\n";
	push @output, $whl;

    } elsif ($line =~ /^(\s*)foreach\s*([^\s]*)\s*\((.*)\)/) {
	$fo = "$1for ";
	$fo .= &variable($2);
	$fo .= " in ";
	$focon = $3;
	if ($focon =~ /([^\.]*)\.\.([^\.]*)/) {
	    $fostart = &variable($1);
	    $foend = &variable($2);
	    if ($foend =~ /^\d+$/) {
		$foend++;
	    } else {
		$foend .= " + 1";
	    }
	    if ($fostart eq 0) {
		$fo .= "range($foend)";
	    } else {
		$fo .= "range($fostart, $foend)";
	    }
	} else {
	    @finac = split(/\s+/, $focon);
	    if ($#finac eq 0) {
		$fo .= &variable($finac[0]);
	    }
	}
	$fo .= ":\n";
	push @output, $fo;

    } elsif ($line =~ /^(\s*)for\s*\((.*)\)/) {
	$space = $1;
	@forloop = split(/;/, $2);
	$forloop[0] =~ /([^\s]*)\s*=\s*([^\s]*)/;
	$ini = &variable($1);
	$ini .= " = ";
	$ini .= &variable($2);
	push @output, "$space$ini\n";
	$forloopcon = &condition($forloop[1]);
	$fo2 = "$space";
	$fo2 .= "while $forloopcon:\n";
	push @output, $fo2;
	if ($forloop[2] =~ /\s*([^\s]*)\+\+/) {
	    $checkloop[0] = length($space) + 4;
            $checkloop[1] = "$space    ";
            $checkloop[1] .= &variable($1);
            $checkloop[1] .= " += 1\n";
	} elsif ($forloop[2] =~ /\s*([^\s]*)\-\-/) {
	    $checkloop[0] = length($space) + 4;
	    $checkloop[1] = "$space    ";
            $checkloop[1] .= &variable($1);
            $checkloop[1] .= " -= 1\n";
	}

    } elsif ($line =~ /^(\s*)([^\s]*)\s*=\s*([^;]*)/) {
	$space = $1;
	$equal = "$space";
	$haflag = "";
	$right = $3;
	$content = $2;
	$mode = 0;
	if ($right =~ /^\(\)/) {
	    if ($content =~ /^\@/) {
		$right = "[]";
	    } elsif ($content =~ /^\%/) {
		$right = "{}";
	    }
	}
	if ($content =~ /.*\[.*\]/) {
	    $haflag = "array";
	} elsif ($content =~ /.*\{.*\}/) {
	    $haflag = "hash";
	}
	$left = &variable($content);
	if ($left =~ /(.*)\[.*\]/) {
	    &array_hash($1, $haflag);
	}
	if ($right =~ /^~\s*(.*)/) {
	    $right = &regex($1, $left);
	} elsif ($right =~ /split/) {
	    $right = &split_join($right);
	} elsif ($right =~ /join/) {
	    $right = &split_join($right);
	} elsif ($right =~ /[\+\-\*\/\%]+/ || $right =~ /^\d+/) {
	    $right = &calculation($right);
	} elsif ($right =~ /^<STDIN>$/) {
	    $imp_dic{"sys"} = 1;
	    $right = "sys.stdin.readline()";
	    $checkvtype[0] = $left;
	    $checkvtype[1] = $right;
	    $checkvtype[2] = $#output + 1;
	    $checkvtype[3] = $equal;
	} elsif ($right =~ /[\<\>\^\|\&\~]/) {
            $right = &calculation($right);
	} elsif ($right =~ /\s*\.\s*/) {
	    $right = &calculation($right);
	} elsif ($right =~ /^pop\(*([^\)]*)\)*/) {
	    $pop = &variable($1);
	    $right = "$pop.pop()";
	} elsif ($right =~ /^shift\(*([^\)]*)\)*/) {
	    $shift = &variable($1);
	    $right = "$shift\[0\]";
	    $mode = "$space";
	    $mode .= "del $shift\[0\]";
	} else {
	    $right = &variable($right);
	}
	if ($left =~ /(.*)\./) {
	    $equal .= "$1 += $right\n";
	} else {
	    $equal .= "$left = $right\n";
	}
	push @output, $equal;
	if ($mode ne 0) {
	    push @output, "$mode\n";
	}

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
	$chomp = &variable($2);
	push @output, "$1$chomp = $chomp.rstrip()\n";

    } elsif ($line =~ /^\s*exit/) {
	$line =~ s/;//g;
	push @output, $line;

    } elsif ($line =~ /^(\s*)(.*)\+\+/) {
	$space = $1;
        $haflag = "";
	$content = $2;
        if ($content =~ /.*\[.*\]/) {
            $haflag = "array";
        } elsif ($content =~ /.*\{.*\}/) {
            $haflag = "hash";
        }
	$plus = &variable($content);
	if ($plus =~ /(.*)\[.*\]/) {
	    &array_hash($1, $haflag);
	}
	push @output, "$space$plus += 1\n";

    } elsif ($line =~ /^(\s*)(.*)\-\-/) {
	$space = $1;
        $haflag = "";
        $content = $2;
        if ($content =~ /.*\[.*\]/) {
            $haflag = "array";
        } elsif ($content =~ /.*\{.*\}/) {
            $haflag = "hash";
        }
        $plus = &variable($content);
	if ($plus =~ /(.*)\[.*\]/) {
            &array_hash($1, $haflag);
        }
        push @output, "$space$plus -= 1\n";

    } elsif ($line =~ /(\s*)push\s*\(*(.*)\,\s*([^;|\)]*)/) {
	$space = $1;
	$name = &variable($2);
	$ele = &variable($3);
	&array_hash($name, "array");
	push @output, "$space$name\.append($ele)\n";
    } elsif ($line =~ /^(\s*)pop\(*([^\)]*)\)*/) {
	$pop = &variable($2);
	$space = $1;
	push @output, "$space$pop.pop()\n";
    } elsif ($line =~ /(\s*)unshift\s*\(*(.*)\,\s*([^;|\)]*)/) {
	$space = $1;
        $name = &variable($2);
        $ele = &variable($3);
	&array_hash($name, "array");
	push @output, "$space$name = \[$ele\] + $name\n";
    } elsif ($line =~ /^(\s*)shift\(*([^\)]*)\)*/) {
            $shift = &variable($2);
	    $temp1 = "$1";
            $temp1 .= "del $shift\[0\]\n";
	    push @output, $temp1;
    
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
#print "$#output\n";
