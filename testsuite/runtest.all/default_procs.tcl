set sum_file [open .tmp w]
set reboot 0
set errno ""

# this tests a proc for a returned pattern
proc lib_pat_test { cmd arglist pattern } {
    catch { eval [list $cmd] $arglist } result
    puts "CMD(lib_pat_test) was: $cmd \"$arglist\""
    puts "RESULT(lib_pat_test) was: \"${result}\" for pattern \"$pattern\"."
    if [ regexp -- "with too many" $result ] {
	return -1
    }
    if [ string match "$pattern" $result ] {
	return 1
    } else {
	return 0
    }
}

# this tests a proc for a returned value
proc lib_ret_test { cmd arglist val } {
    catch { eval [list $cmd] $arglist } result
    puts "CMD(lib_ret_test) was: $cmd $arglist"
    puts "RESULT(lib_ret_test) was: $result"

    if { $result eq $val } {
	return 1
    } else {
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
