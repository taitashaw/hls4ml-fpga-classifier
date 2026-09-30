create_project -in_memory -part xczu7ev-ffvc1156-2-e
set_property board_part xilinx.com:zcu104:part0:1.0 [current_project] -quiet
puts "ZYNQ_PS: [get_ipdefs -filter {VLNV =~ "*zynq_ultra_ps_e*"}]"
puts "AXI_DMA: [get_ipdefs -filter {VLNV =~ "*axi_dma*"}]"
puts "AXI_SMARTCONNECT: [get_ipdefs -filter {VLNV =~ "*smartconnect*"}]"
puts "AXI_INTERCONNECT: [get_ipdefs -filter {VLNV =~ "*axi_interconnect*"}]"
puts "BOARD_PARTS: [get_board_parts -filter {NAME =~ "*zcu104*"} -quiet]"
