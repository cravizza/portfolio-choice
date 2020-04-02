*** Portfolio Choice
*** MAKE ALL
clear all
global data "../../../Data/SP"
global general "../"
set more off
	
	di "-- Cleaning raw datasets"
		do "./clean_pre"
		do "./clean_merge"
		do "./clean_basic"
		do "./clean_newvars"
		shell "C:\Python32\python.exe" test.py
		do "./clean_fyf"
	
	di "-- Derived datasets"
		do "./derived_hpa"
		do "./derived_event_study"
		do "./derived_fyf"
	
	di "-- Analysis"
		do "./analysis_graph_fees"
		do "./analysis_ret_corr"
		do "./analysis_ret_corr_monthly"
		do "./analysis_general"
		do "./analysis_event_study"
		do "./analysis_fyf_follower"
		do "./analysis_fyf_follower_corr"
		do "./analysis_fyf_advisor"
		do "./analysis_return_chasing"
		do "./analysis_cret_2-12"
		do "./analysis_cret_plot"
		do "./analysis_TI"

