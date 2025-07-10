
# PlanAhead Launch Script for Post-Synthesis floorplanning, created by Project Navigator

create_project -name Project2PingPong -dir "/home/student1/mppatel/Downloads/Project2PingPong/planAhead_run_1" -part xc3s500efg320-5
set_property design_mode GateLvl [get_property srcset [current_run -impl]]
set_property edif_top_file "/home/student1/mppatel/Downloads/Project2PingPong/PingPong.ngc" [ get_property srcset [ current_run ] ]
add_files -norecurse { {/home/student1/mppatel/Downloads/Project2PingPong} }
set_property target_constrs_file "PingPong.ucf" [current_fileset -constrset]
add_files [list {PingPong.ucf}] -fileset [get_property constrset [current_run]]
open_netlist_design
