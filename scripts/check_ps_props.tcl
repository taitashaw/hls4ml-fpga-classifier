create_project -in_memory -part xczu7ev-ffvc1156-2-e
create_bd_design "tmp"
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 zynq_ultra_ps_e_0
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1"} [get_bd_cells zynq_ultra_ps_e_0]
puts "M_AXI_GP0 = [get_property CONFIG.PSU__USE__M_AXI_GP0 [get_bd_cells zynq_ultra_ps_e_0]]"
puts "M_AXI_GP1 = [get_property CONFIG.PSU__USE__M_AXI_GP1 [get_bd_cells zynq_ultra_ps_e_0]]"
puts "HPM_pins = [get_bd_intf_pins -of [get_bd_cells zynq_ultra_ps_e_0] -filter {NAME =~ "*HPM*"}]"
