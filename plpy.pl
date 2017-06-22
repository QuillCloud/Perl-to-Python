#!/usr/bin/perl -w

# written by Yunhe Zhang(z5045582)

# also have @output array, and %imp_dic hash
# @output used for storing each transalted line
# %imp_dic used for storing things need be imported
@checkloop = ();
@checkvtype = ();
@checkarray = ();
@checkhash = ();

sub split_join {
    
    # function for split and join
    
    my ($sj) = @_;
    if ($sj =~ /split\s*\(*\/(.*)\/,\s*([^\)]*)\)*/) {

	# split
	
	$temp1 = &variable($2);
	$temp2 = &variable($1);
	$sj = "$temp1.split(\'$temp2\')";
    } elsif ($sj =~ /join\s*\(*(.*)\,\s*([^)]*)\)*/) {

	# join

	$temp1 = &variable($1);
	$temp2 = &variable($2);
	$sj = "$temp1.join($temp2)";
    }
    return $sj;
}

sub variable {
    
    # change perl variables to python variables
    
    my ($v) = @_;
    my $lenflag = 0;
    my $argvflag = 0;
    if ($v =~ /^\$/) {

	# if start with $

	$v =~ s/^\$//g;
	if ($v =~ /^\#(.*)/) {
	    
	    # deal with $#
	    
	    $v =~ s/^\#//g;
	    if ($v eq "ARGV") {

		# special senario ARGV

		$imp_dic{"sys"} = 1;
		$v = "sys.argv";
		$argvflag = 1;
	    }
	    $lenflag = 1;
	} elsif ($v =~ /(.*)\[(.*)\]/ || $v =~/(.*)\{(.*)\}/) {

	    #deal with array or hash, need call variable itself

	    $aname = $1;
	    $anum = &variable($2);
	    if ($aname eq "ARGV") {

		# special senario ARGV

		$imp_dic{"sys"} = 1;
		$argvflag = 1;
		$aname = "sys.argv";
		$anum .= " + 1";
	    }
	    $v = "$aname\[$anum\]";
	}
    } elsif ($v =~ /^@(.*)/) {

	# start with @

	if ($1 =~ /^ARGV$/) {

	    # special senario ARGV

	    $imp_dic{"sys"} = 1; 
	    $v = "sys.argv[1:]";
	    $argvflag = 1;
	} else {

	    $v = $1;
	}
    } elsif ($v =~ /^%(.*)/) {

	# start with % (hash)

	$v = $1;
    }
    if ($lenflag ne 0) {
	
	# more translate for $#

	if ($argvflag ne 0) {
	    $v = "len($v) - 2";
	} else {
	    $v = "len($v) - 1";
	}
    }
    return $v
}

sub pstring {
    
    #for print string that contain variables, like "test $a"
    
    my ($s) = @_;

    # saparate the input string

    my @str = split(/\s+/, $s);
    my @ps_list = ();
    my @v_list = ();
    foreach $s_str (@str) {
	if ($s_str =~ /(^\$.*)/ || $s_str =~ /(^\@.*)/) {
	    
	    # if it is varible, push to @v_list

	    push @ps_list, "%s"; 
	    push @v_list, &variable($1);
	} else {
	    push @ps_list, $s_str;
	}
    }

    if ($#ps_list eq 0 && $#v_list eq 0) {
	
	# if only a varible,nothing else
	
	$s = $v_list[0];
    } elsif ($#ps_list ne -1)  {
	
	# if multiple variables or string combine variables
	
	$s = join(' ', @ps_list);
	$s = "\"" . $s . "\"";
	if ($#v_list ne -1) {
	    $temp = join(', ', @v_list);
	    $s .= " % \($temp\)";
	}
    }
    return $s;
}

sub calculation {
    
    # function for calculation, including bitwise operation

    my ($cal) = @_;
    my @sc_list = ();

    # separate the string, deal with each elemnts in proper way

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
    
    # join elements and return it

    $cal = join(' ', @sc_list);
    $cal =~ s/\$|\@//g;
    return $cal;
}

sub condition {
    
    # function for conditions of 'if','while','elsif'
    # first separate string, deal with each elemnts
    # finally, join them

    my ($con) = @_;
    my @con_list = ();
    @conele = split(/\s+/, $con);
    foreach $sconele (@conele) {
	if ($sconele =~ /^\$/) {
	    if ($#checkvtype ne -1) { 

		# if condition need stdin value type be float, change stdin line

		if ($checkvtype[0] eq &variable($sconele) && $con =~ /\<|\>/) {
		    $output[$checkvtype[2]] = "$checkvtype[3]$checkvtype[0] = float\($checkvtype[1]\)\n";
		    @checkvtype = ();
		}
	    }
	    push @con_list, &variable($sconele);
	} else {

	    # translate some key symbol into python version

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

    # function for regex, including 'm//' '//' 's///'

    my ($reg, $regl) = @_;
    $imp_dic{"re"} = 1;
    if ($reg =~ /^s\/(.*)\/(.*)\//) {
	$reg = "re.sub(r\'$1\', \'$2\', $regl)"
    } elsif ($reg =~ /^m*\/(.*)\//) {
	$reg = "re.match(r\'$1\', $regl)";
    }
    return $reg;
}

sub array_hash {
    
    # function for initialize the hash and array

    my ($ahname, $mode) = @_;

    # for initialize, first check it is array or hash, and check if it is already exists.
    # if not then, pop from @output, find the while or for loop, store them in @cache
    # when find or @output is empty, add initialize code
    # finally push back line from @cache to @output
    
    if ($mode eq "array") {
	if ( !grep( /^$ahname$/, @checkarray ) ) {
	    @cache = ();
	    while ($#output ne -1) {
		$temp1 = pop @output;
	        unshift @cache, $temp1;
		if ($temp1 =~ /^(\s*)(while|for)/ || $#output eq -1) {
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
		if ($temp1 =~ /^\s*(while|for)/ || $#output eq -1) {
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

	# use for 'for' loop like for($i = 0; $i<2;$i++) 
	# the  $i++ need to translate i += 1 and put at end of 'for' loop

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

	# translate print line

	$clflag = 0;
	$p = "$1print(";
	$temp1 = $2;

	# separate the print content

	if ($temp1 =~ /[\'\/]\,/) {
	    @content = split(/\),/, $temp1);
	} else {
	    @content = split(/,/, $temp1);
	}

	# go through elements in print content

	foreach $c (@content) {
	    if ($c =~ /\"(.*)\"/) {
		$c = $1;
		if ($c =~ /\\n/) {

		    # set a flag if end with '\n'

		    $clflag = 1;
		    $c =~ s/\\n//g;
		}
		$p .= &pstring($c);

	    } elsif ($c =~ /split/ || $c =~ /join/) {

		# if contain split or join, call split_join function
		
		$p .= &split_join($c);
	    } else {
		if ($c =~ /([\+\-\*\/\%]+)/) {

		    # if contian + - * / %, call calculation
		    
		    $p .= &calculation($c);
		} elsif ($c =~ /([\|\^\&\<\>\~]+)/) {

		    # if contian bitwise operators, call calculation

		    $p .= &calculation($c);
		} else {

		    # may have multiple variables, tanslate them one by one

		    while ($c =~ m/(\$|@)([^\$|\s]*)/g) {
			push @mulv, &variable($2);
		    }
		    $p .= join(',', @mulv);
		    @mulv = ();
		}
	    }
	}

	# if \n flag not set, add end = '' in python print

	if ($clflag eq 1) {
	    $p .= ")";
	} else {
	    $p .= ", end = '')";
	}
	
	# translate done, push line to @output
	
	push @output, "$p\n";

    } elsif ($line =~ /^(\s*)\}*\s*(if|elsif)/) {

	# translate if/elsif line

	$space = "$1";
	$ifl = $space;

	# check is if or elsif
	
	if ($2 eq "elsif") {
	    $ifl .= "elif ";
	} else {
	    $ifl .= "if ";
	}

	# get condition and call function condition

	$line =~ /\((.*)\)/;
	$temp1 = &condition($1);
	if ($temp1 =~ /([^\s]*)\s*=~\s*(.*)/) {

	    # if conditon match regex, call function regex 

	    $temp2 = "$space";
	    $temp2 .= "m = ";
	    $temp2 .= &regex($2, $1);
	    $temp2 .= "\n";
	    
	    # add  line like 'm = re.match(...)' before the 'if' line
 
	    push @output, $temp2;
	    $ifl .= "m";
	} elsif ($temp1 =~ /^exists\s*(.*)\[(.*)\]/) {

	    # condition contains exists
	    
	    $ifl .= "$2 in $1";
	} else {
	    $ifl .= $temp1;
	}

	# add ':' at end, tanslate done, push line to @output

	$ifl .= ":\n";
	push @output, $ifl;

    } elsif ($line =~ /^(\s*)\s*while\s*\((.*)\)/) {

	# translate while line

	$whl = "$1";
	
	# get condition part

	$temp1 = $2;
	if ($temp1 =~ /([^\s]*)\s*=\s*<(.*)>/) {

	    # deal with the condition like <>, <STDIN>, <F>

	    $temp2 = &variable($1);
	    $temp3 = $2;
	    if ($temp3 eq "") {
		$imp_dic{"fileinput"} = 1;
		$whl .= "for $temp2 in fileinput.input()";
	    } elsif ($temp3 eq "STDIN") {
		$imp_dic{"sys"} = 1;
		$whl .= "for $temp2 in sys.stdin";
	    } elsif ($temp3 eq "F") {
		$file = $filecheck[$#filecheck];
		$whl .= "for $temp2 in open\($file\)";
	    }
	} else {

	    # deal with other condition, call function condition
	    
	    $whl .= "while ";
	    $whl .= &condition($temp1);
	}

	# add : at end, translate done, push line to @output
	
	$whl .= ":\n";
	push @output, $whl;

    } elsif ($line =~ /^(\s*)foreach\s*([^\s]*)\s*\((.*)\)/) {

	# translate foreach line, first create "for .. in"

	$fo = "$1for ";
	$fo .= &variable($2);
	$fo .= " in ";

	# get target element in ()

	$focon = $3;
	$closep = 0;
	if ($focon =~ /([^\.]*)\.\.([^\.]*)/) {

	    # if the element like "(variable1..variable2)"

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

	    # if the element is a hash or array

	    @finac = split(/\s+/, $focon);
	    if ($#finac eq 0) {
		
		# if only contains array
		
		$fo .= &variable($finac[0]);
	    } else {
		
		# if element is hash, or have 'sort' 'reverse'

		foreach $temp1 (@finac) {
		    if ($temp1 =~ /sort/) {
			$closep++;
			$fo .= "sorted("
		    } elsif ($temp1 =~ /reverse/) {
			$closep++;
			$fo .= "reversed(";
		    }
		    if ($temp1 =~ /^[\%\@]/) {
			$fo .= &variable($temp1);
		    }
		}
		while ($closep > 0) {

		    # for add ')' at end
		    
		    $fo .= "\)";
		    $closep--;
		}		
	    }
	}

	# add : at end translate done, push line to @output

	$fo .= ":\n";
	push @output, $fo;

    } elsif ($line =~ /^(\s*)for\s*\((.*)\)/) {

	# translate for line like in c 

	$space = $1;
	
	# separate into 3 parts
	
	@forloop = split(/;/, $2);

	# first part, initialize the variable

	$forloop[0] =~ /([^\s]*)\s*=\s*([^\s]*)/;
	$ini = &variable($1);
	$ini .= " = ";
	$ini .= &variable($2);
	push @output, "$space$ini\n";

	# second part, create while loop

	$forloopcon = &condition($forloop[1]);
	$fo2 = "$space";
	$fo2 .= "while $forloopcon:\n";
	push @output, $fo2;

	# store the last part, wait for end of loop, add it
	
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

    } elsif ($line =~ /^(\s*)([^\s]*)\s*(\.*|\+*|\-*)=\s*([^;]*)/) {

	# translate equal('=') line, including .=

	$space = $1;
	$equal = "$space";
	$haflag = "";

	# $content sotre left part, $right store right part

	$right = $4;
	$content = $2;
	$mode = 0;
	if ($right =~ /^\(\)/) {

	    # deal with line that initialize the hash or array
	    
	    if ($content =~ /^\@/) {
		$right = "[]";
	    } elsif ($content =~ /^\%/) {
		$right = "{}";
	    }
	}

	# if left part is a hash or array, set flag

	if ($content =~ /.*\[.*\]/) {
	    $haflag = "array";
	} elsif ($content =~ /.*\{.*\}/) {
	    $haflag = "hash";
	}

	# call variable for translate left part
	# if it is hash or array, call array_hash to check whether need to be initialized

	$left = &variable($content);
	if ($left =~ /(.*)\[.*\]/) {
	    &array_hash($1, $haflag);
	}
	
	# deal with right part
	
	if ($right =~ /^~\s*(.*)/) {
	    
	    # if it is regex like s///, call regex function

	    $right = &regex($1, $left);

	} elsif ($right =~ /split/) {

	    # if contains  split, call split_join function
	    
	    $right = &split_join($right);
	    push @checkarray, $left;

	} elsif ($right =~ /join/) {

	    # if contains join, call split_join function
	    
	    $right = &split_join($right);

	} elsif ($right =~ /[\+\-\*\/\%]+/ || $right =~ /^\d+/) {

	    # if contains + - * / % **, call calculation function

	    $right = &calculation($right);

	} elsif ($right =~ /^<STDIN>$/) {
	    
	    # if it is <STDIN>, translate it, and store some data in @checkvtype
	    # for change the value type if the input need to be float

	    $imp_dic{"sys"} = 1;
	    $right = "sys.stdin.readline()";
	    $checkvtype[0] = $left;
	    $checkvtype[1] = $right;
	    $checkvtype[2] = $#output + 1;
	    $checkvtype[3] = $equal;

	} elsif ($right =~ /^<F>$/) {
	    
	    # if it is <F>

	    $file = $filecheck[$#filecheck];
	    $right = "open($file)";

	} elsif ($right =~ /[\<\>\^\|\&\~]/) {

	    # if contains bitwise operators, call calculation function

            $right = &calculation($right);

	} elsif ($right =~ /\s*\.\s*/) {
	    
	    # if contians ' . ', call calculation function
	    
	    $right = &calculation($right);

	} elsif ($right =~ /^pop\s*\(*([^\)]*)\)*/) {
	    
	    # deal with pop

	    $pop = &variable($1);
	    $right = "$pop.pop()";

	} elsif ($right =~ /^shift\s*\(*([^\)]*)\)*/) {
	    
	    # deal with shift

	    $shift = &variable($1);
	    $right = "$shift\[0\]";
	    $mode = "$space";
	    $mode .= "del $shift\[0\]";

	} else {
	    
	    # else, call variable function
	    
	    $right = &variable($right);
	}

	# check if it is .= or += or -=
	
	if ($line =~ /\.=/ || $line =~ /\+=/) {
	    $equal .= "$left += $right\n";
	} elsif ($line =~ /\-=/) {
	    $equal .= "$left -= $right\n";
	} else {
	    $equal .= "$left = $right\n";
	}
	
	# trnaslate done, push line to @output
	
	push @output, $equal;
	
	# for shift, need to add additional line

	if ($mode ne 0) {
	    push @output, "$mode\n";
	}

    } elsif ($line =~ /^\s*}$/) {

	# translate line only have '}'

	next;

    } elsif ($line =~ /^(\s*)\}*\s*else/)  {
	
	# translate else line

	push @output, "$1else:\n";

    } elsif ($line =~ /^(\s*)(next|last);$/) {

	# translate next and last line

	$line =~ s/next/continue/g;
	$line =~ s/last/break/g;
	$line =~ s/;//g;
	push @output, $line;

    } elsif ($line =~ /^(\s*)chomp\s*([^;]*)/)  {

	# translate chomp line

	$chomp = &variable($2);
	push @output, "$1$chomp = $chomp.rstrip()\n";

    } elsif ($line =~ /^\s*exit/) {

	# translate exit line

	$line =~ s/;//g;
	push @output, $line;

    } elsif ($line =~ /^(\s*)(.*)\+\+/) {

	# translate ++ line
	
	$space = $1;
        $haflag = "";
	$content = $2;

	# need to check whether if the variable is hash or array

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
	
	# translate -- line

	$space = $1;
        $haflag = "";
        $content = $2;
	
	# need to check whether if the variable is hash or array
	
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

	# translate 'push' ahead line

	$space = $1;
	$name = &variable($2);
	$ele = &variable($3);
	&array_hash($name, "array");
	push @output, "$space$name\.append($ele)\n";

    } elsif ($line =~ /^(\s*)pop\(*([^\)]*)\)*/) {
	
	# translate 'pop' ahead line

	$pop = &variable($2);
	$space = $1;
	push @output, "$space$pop.pop()\n";

    } elsif ($line =~ /^(\s*)unshift\s*\(*(.*)\,\s*([^;|\)]*)/) {

	# translate 'unshift' ahead line

	$space = $1;
        $name = &variable($2);
        $ele = &variable($3);
	&array_hash($name, "array");
	push @output, "$space$name = \[$ele\] + $name\n";

    } elsif ($line =~ /^(\s*)shift\(*([^\)]*)\)*/) {

	# translate 'shift' ahead line

	$shift = &variable($2);
	$temp1 = "$1";
	$temp1 .= "del $shift\[0\]\n";
	push @output, $temp1;
    
    } elsif ($line =~ /\s*open\s*F,\s*([^;]*)/) {

	# translate open file line

	$file = &variable($1);
	$file =~ s/\<//g;
	push @filecheck, $file;

    } elsif ($line =~ /close F/) {
	
	# translate close file line
	
	next;

    } else {
	
        # Lines we can't translate are turned into comments

        push @output, "#$line\n";
    }
    
}

foreach $imp (keys %imp_dic) {

    # print the import first

    print "import $imp\n";
}

foreach $o (@output) {

    # print each line that already translated
    
    print "$o";

}
