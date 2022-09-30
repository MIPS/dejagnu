# Copyright (C) 2022 Free Software Foundation, Inc.
#
# This file is part of DejaGnu.
#
# DejaGnu is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# DejaGnu is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with DejaGnu; if not, write to the Free Software Foundation,
# Inc., 51 Franklin Street - Fifth Floor, Boston, MA 02110-1301, USA.

# This file was written by Jacob Bachmeyer.

# This library provides convenience procedures for emulating a partial
# filesystem while running isolated tests of DejaGnu procedures in a slave
# interpreter.  These are designed to be run in the child process used by
# the DejaGnu library tests.  Intended use is with mockutil.tcl.

# This implementation is by no means complete, but is sufficient for the
# purposes of internal DejaGnu unit tests and will be expanded as needed.

proc create_mockvfs { vfsname } {
    upvar #0 $vfsname vfs

    array unset vfs
    array set vfs {
	chan,hint 1
    }
}

# create_mock_file vfsname {filename contents}...
proc create_mock_file { vfsname args } {
    upvar #0 $vfsname vfs

    foreach {filename contents} $args {
	if { [regexp -- {\A\n\s+} $contents indent] } {
	    regsub "\\A$indent" $contents "" contents
	    regsub -all -- $indent $contents "\n" contents
	    regsub {\n\s+\Z} $contents "\n" contents
	}
	set vfs(file,data,$filename) $contents
	set vfs(file,length,$filename) [string length $contents]
    }
}

# Install mockvfs procedure aliases in slave interpreter
proc attach_mockvfs { sicmd vfsname } {
    # supply operations for file name operations
    foreach cmd { file glob open } {
	$sicmd alias $cmd "mockvfs_op_${cmd}" $vfsname $sicmd
    }
    # override I/O channel-using commands present in a safe interpreter
    foreach cmd {
	close eof flush gets puts read seek tell
    } {
	$sicmd hide $cmd
	$sicmd alias $cmd "mockvfs_op_${cmd}" $vfsname $sicmd
    }
    # DejaGnu uses Expect instead of the Tcl event loop at this time, so
    #  fconfigure, fcopy, and fileevent are left untouched for now.
    # The mock VFS does not have a current directory, so cd is omitted.
}

# operations normally not available in safe interpreters:
proc mockvfs_op_file	{ vfsname sicmd op args } {
    upvar #0 $vfsname vfs

    switch -- $op {
	dirname {
	    set name [lindex $args 0]
	    set point [string last / $name]
	    if { $point == -1 } { return . }
	    return [string range $name 0 [expr {$point-1}]]
	}
	tail {
	    set name [lindex $args 0]
	    set point [string last / $name]
	    if { $point == -1 } { return $name }
	    return [string range $name [expr {$point+1}] end]
	}
	default {
	    error "mockvfs: file $op not implemented"
	}
    }
}
proc mockvfs_op_glob	{ vfsname sicmd args } {
    upvar #0 $vfsname vfs

    error "mockvfs: glob not implemented"
}
proc mockvfs_op_open	{ vfsname sicmd
			  fileName {access r} {permissions 0666} } {
    upvar #0 $vfsname vfs

    if { ! [info exists vfs(file,data,$fileName)] } {
	error "couldn't open \"$fileName\": no such file or directory"
    }

    switch -glob -- $access {
	?+	-
	[wa]*	-
	*WR*	{ error "couldn't open \"$fileName\": read-only file system" }
    }

    set fnum $vfs(chan,hint)
    while { [info exists vfs(chan,mock${fnum},pos)] } { incr fnum }
    set vfs(chan,hint) $fnum
    set handle mock${fnum}
    set vfs(chan,$handle,pos) 0
    set vfs(chan,$handle,file) $fileName

    return $handle
}

# operations normally available in safe interpreters:
proc mockvfs_op_close	{ vfsname sicmd chan } {
    if { ! [string match mock* $chan] } {
	return [$sicmd invokehidden close $chan]
    }

    upvar #0 $vfsname vfs

    if { [info exists vfs(chan,$chan,pos)] } {
	array unset vfs chan,$chan,*
	scan $chan mock%d fnum
	if { $vfs(chan,hint) > $fnum } { set vfs(chan,hint) $fnum }
    } else {
	error "can not find channel named \"$chan\""
    }
}
proc mockvfs_op_eof	{ vfsname sicmd chan } {
    if { ! [string match mock* $chan] } {
	return [$sicmd invokehidden eof $chan]
    }

    upvar #0 $vfsname vfs

    if { ! [info exists vfs(chan,$chan,pos)] } {
	error "can not find channel named \"$chan\""
    }

    if { $vfs(chan,$chan,pos) >= $vfs(file,length,$vfs(chan,$chan,file)) } {
	return 1
    } else {
	return 0
    }
}
proc mockvfs_op_flush	{ vfsname sicmd chan } {
    if { ! [string match mock* $chan] } {
	return [$sicmd invokehidden flush $chan]
    }
    # do nothing for mockvfs channels
}
proc mockvfs_op_gets	{ vfsname sicmd chan args } {
    if { ! [string match mock* $chan] } {
	return [eval [list $sicmd invokehidden gets] $args]
    }

    upvar #0 $vfsname vfs
    if { [llength $args] > 1 } {
	error "too many arguments to gets: gets $chan $args"
    } elseif { [llength $args] == 1 } {
	set outvar [lindex $args 0]
    }

    if { ! [info exists vfs(chan,$chan,pos)] } {
	error "can not find channel named \"$chan\""
    }

    if { $vfs(chan,$chan,pos) >= $vfs(file,length,$vfs(chan,$chan,file)) } {
	# at EOF
	set output ""
	set outcnt -1
    } else {
	set bound [string first "\n" $vfs(file,data,$vfs(chan,$chan,file)) \
		       $vfs(chan,$chan,pos)]
	if { $bound == -1 } {
	    # no newline found before eof; return last partial line
	    set output [string range $vfs(file,data,$vfs(chan,$chan,file)) \
			    $vfs(chan,$chan,pos) end]
	    set outcnt [string length $output]
	    set vfs(chan,$chan,pos) $vfs(file,length,$vfs(chan,$chan,file))
	} else {
	    # return a full line
	    set output [string range $vfs(file,data,$vfs(chan,$chan,file)) \
			    $vfs(chan,$chan,pos) [expr {$bound-1}]]
	    set outcnt [string length $output]
	    incr vfs(chan,$chan,pos) [expr {1+$outcnt}]
	}
    }

    if { [info exists outvar] } {
	$sicmd eval [list set $outvar $output]
	return $outcnt
    } else {
	return $output
    }
}
proc mockvfs_op_read	{ vfsname sicmd chan args } {
    if { ! [string match mock* $chan] } {
	return [eval [list $sicmd invokehidden read] $args]
    }

    upvar #0 $vfsname vfs

    if { ! [info exists vfs(chan,$chan,pos)] } {
	error "can not find channel named \"$chan\""
    }

    error "mockvfs: read not implemented"
}
proc mockvfs_op_puts	{ vfsname sicmd args } {
    if { [llength $args] < 2
	 || ! [string match mock* [lindex $args end-1]] } {
	return [eval [list $sicmd invokehidden puts] $args]
    }

    upvar #0 $vfsname vfs

    if { ! [info exists vfs(chan,$chan,pos)] } {
	error "can not find channel named \"$chan\""
    }

    error "mockvfs is currently read-only"
}
proc mockvfs_op_seek	{ vfsname sicmd chan args } {
    if { ! [string match mock* $chan] } {
	return [eval [list $sicmd invokehidden seek] $args]
    }

    upvar #0 $vfsname vfs

    if { ! [info exists vfs(chan,$chan,pos)] } {
	error "can not find channel named \"$chan\""
    }

    error "mockvfs: seek not implemented"
}
proc mockvfs_op_tell	{ vfsname sicmd chan args } {
    if { ! [string match mock* $chan] } {
	return [eval [list $sicmd invokehidden tell] $args]
    }

    upvar #0 $vfsname vfs

    if { ! [info exists vfs(chan,$chan,pos)] } {
	error "can not find channel named \"$chan\""
    }

    error "mockvfs: tell not implemented"
}


#EOF
