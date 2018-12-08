set sum_file [open .tmp w]
set reboot 0
set errno ""

# this tests a proc for a returned pattern
proc lib_pat_test { cmd arglist pattern } {
    puts "CMD(lib_pat_test) is: $cmd $arglist"
    if { [catch { eval [list $cmd] [lrange $arglist 0 end] } result] == 0 } {
	puts "RESULT(lib_pat_test) was: \"${result}\"\
		for pattern \"$pattern\"."
	return [string match "$pattern" $result]
    } else {
	puts "RESULT(lib_pat_test) was error \"${result}\""
	return -1
    }
}

# this tests a proc for a returned regexp
proc lib_regexp_test { cmd arglist regexp } {
    puts "CMD(lib_regexp_test) is: $cmd $arglist"
    if { [catch { eval [list $cmd] [lrange $arglist 0 end] } result] == 0 } {
	puts "RESULT(lib_regexp_test) was: \"${result}\"\
		for regexp \"$regexp\"."
	return [regexp -- $regexp $result]
    } else {
	puts "RESULT(lib_regexp_test) was error \"${result}\""
	return -1
    }
}

# this tests a proc for a returned value
proc lib_ret_test { cmd arglist val } {
    puts "CMD(lib_ret_test) is: $cmd $arglist"
    if { [catch { eval [list $cmd] [lrange $arglist 0 end] } result] == 0 } {
	puts "RESULT(lib_ret_test) was: $result"
	return [string equal $result $val]
    } else {
	puts "RESULT(lib_ret_test) was error \"${result}\""
	return -1
    }
}

# this tests a proc for an expected boolean result
proc lib_bool_test { cmd arglist val } {
    puts "CMD(lib_bool_test) is: $cmd $arglist"
    if { [catch { eval [list $cmd] [lrange $arglist 0 end] } result] == 0 } {
	puts "RESULT(lib_bool_test) was: \"$result\" expecting $val."
	# the "odd" spacing is used to help make the operator grouping clear
	return [expr {  $val  ?   $result ? 1 : 0   :   $result ? 0 : 1   }]
    } else {
	puts "RESULT(lib_bool_test) was error \"${result}\""
	return -1
    }
}

# this tests that a proc raises an error matching a pattern
proc lib_errpat_test { cmd arglist pattern } {
    puts "CMD(lib_errpat_test) is: $cmd $arglist"
    if { [catch { eval [list $cmd] [lrange $arglist 0 end] } result] == 1 } {
	# caught exception code 1 (TCL_ERROR) as expected
	puts "RESULT(lib_errpat_test) was error\
		\"${result}\" for pattern \"$pattern\"."
	if { [string match $pattern $result] } {
	    # the expected error
	    return 1
	} else {
	    # an unexpected error
	    return -1
	}
    } else {
	# no error -> fail
	puts "RESULT(lib_errpat_test) was: \"${result}\"\
		without error; failing."
	return 0
    }
}

# this tests that a proc raises an error matching a regexp
proc lib_errregexp_test { cmd arglist regexp } {
    puts "CMD(lib_errregexp_test) is: $cmd $arglist"
    if { [catch { eval [list $cmd] [lrange $arglist 0 end] } result] == 1 } {
	# caught exception code 1 (TCL_ERROR) as expected
	puts "RESULT(lib_errregexp_test) was error\
		\"${result}\" for regexp \"$regexp\"."
	if { [regexp -- $regexp $result] } {
	    # the expected error
	    return 1
	} else {
	    # an unexpected error
	    return -1
	}
    } else {
	# no error -> fail
	puts "RESULT(lib_errregexp_test) was: \"${result}\"\
		without error; failing."
	return 0
    }
}

# this tests that a proc raises an error matching an exact string
proc lib_err_test { cmd arglist val } {
    puts "CMD(lib_err_test) is: $cmd $arglist"
    if { [catch { eval [list $cmd] [lrange $arglist 0 end] } result] == 1 } {
	# caught exception code 1 (TCL_ERROR) as expected
	puts "RESULT(lib_err_test) was error: $result"
	if { $result eq $val } {
	    # the expected error
	    return 1
	} else {
	    # an unexpected error
	    return -1
	}
    } else {
	# no error -> fail
	puts "RESULT(lib_err_test) was: \"${result}\"\
		without error; failing."
	return 0
    }
}

#
# This runs a standard test for a proc. The list is set up as:
# |test proc|proc being tested|args|pattern|message|
# test proc is something like lib_pat_test or lib_ret_test.
#
proc run_tests { tests } {
    foreach test $tests {
	# skip comments in test lists
	if { [lindex $test 0] eq "#" } { continue }
	set result [eval [lrange $test 0 3]]
	switch -- $result {
	    "-1" {
		puts "ERRORED: [lindex $test 4]"
	    }
	    "1" {
		puts "PASSED: [lindex $test 4]"
	    }
	    "0" {
		puts "FAILED: [lindex $test 4]"
	    }
	    default {
		puts "BAD VALUE: [lindex $test 4]"
	    }
	}
    }
}

proc send_log { args } {
    # this is just a stub for testing
}

proc pass { msg } {
    puts "PASSED: $msg"
}

proc fail { msg } {
    puts "FAILED: $msg"
}

proc perror { msg } {
    global errno
    puts "ERRORED: $msg"
    set errno "$msg"
}

proc warning { msg } {
    global errno
    puts "WARNED: $msg"
    set errno "$msg"
}

proc untested { msg } {
    puts "NOTTESTED: $msg"
}

proc unsupported { msg } {
    puts "NOTSUPPORTED: $msg"
}
proc verbose { args } {
    puts [lindex $args 0]
}
