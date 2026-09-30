open_project ./vivado_prj/hls4ml_zcu104.xpr
open_bd_design ./vivado_prj/hls4ml_zcu104.srcs/sources_1/bd/hls4ml_system/hls4ml_system.bd

if {[llength [get_bd_cells myproject_0]] > 0} {
    set_property name mlp_classifier_0 [get_bd_cells myproject_0]
    puts "RENAME: myproject_0 -> mlp_classifier_0 done"
} else {
    puts "RENAME: myproject_0 not found, already renamed or missing"
}

validate_bd_design
save_bd_design
regenerate_bd_layout
save_bd_design
