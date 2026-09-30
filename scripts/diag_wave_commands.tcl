set fh [open /tmp/xsim_wave_cmds.txt w]
puts $fh "=== *zoom* ==="
puts $fh [lsort [info commands *zoom*]]
puts $fh "=== *wave* ==="
puts $fh [lsort [info commands *wave*]]
puts $fh "=== *fit* ==="
puts $fh [lsort [info commands *fit*]]
puts $fh "=== restart/run ==="
puts $fh [lsort [info commands run]]
puts $fh [lsort [info commands restart]]
close $fh
