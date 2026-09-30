set matches [get_parts -filter {NAME =~ "*zu7ev*"}]
puts "MATCHES: $matches"
if {[llength [get_parts xczu7ev-ffvc1156-2-e]] > 0} {
  puts "EXACT_MATCH: xczu7ev-ffvc1156-2-e confirmed in part database"
}
