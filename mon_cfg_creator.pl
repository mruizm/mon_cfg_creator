################################################################################
#To be considered when creating CSV line and documentation
# -> When using for df_mon, escape * (\*) to define * FS wildcard
# -> When using for perf_mon, instance separated by '-': "GBL_CPU_TOTAL_UTIL-NONE"
# -> Use NA as value if no cfg mon global variables needed
# -> xxx_mon.cfg global varibles can be set as defined in user guide or some of them have shorter names
#       srv_mon:    AUTO_S_EXP_L => "AUTOMATIC_SERVICES_MONITORING_EXCEPTION_LIST"
#                   AUTO_S_RSTART => "AUTOMATIC_SERVICES_RESTART_TRIAL",
#                   AUTO_S_RSTART_EXP_L => "AUTOMATIC_SERVICES_RESTART_EXCEPTION_LIST",
################################################################################
# Error codes:
#   NOK_MON_NODE_OS:			          Node OS not compatible with xxx_mon module
#   NOK_NODE_IN_HPOM:		            Node not found within HPOM
#   NOK_NODE_SSL:			              SSL to node not working
#   NOK_NODE_PREF_SRV_MON_CFG:	    script unable to find xxx_mon.cfg not found in prefered path
#   NOK_DWN_SRV_MON_CFG_NODE:	      script unable to download xxx_mon.cfg from prefered path
#   NOK_SRV_MON_CFG_IN_HPOM:	      script downloaded file but not found in dir /var/opt/OpC_local/MON_CFG_CREATOR/tmp/xxx_mon/
#   NOK_CSV_OS_NODE_OS              mismatch between node OS in csv line and one within in HPOM db
#   NOK_NON_OS_NODE                 node is not an OS based server (MACH_BBC_OTHER)
#   NOK_CSV_SYNTAX:			            input csv line pattern mismatch
#
#
################################################################################
# Filename: mon_cfg_creator.pl
# Purpose:  Script that takes a CSV file containing mon threshold
#           definitions and based on that, creates a WINMON/UXMON module cfg
#           You can define either just create the file or afterwards it's
#           created, push it to the managed node.
# Author:   Marco Ruiz (mruizm@hpe.com)
# Version:  1.0
#
# Options:
#           -p parses current xxx_mon.cfg into csv line for script usage
#           -f <input_file>: define input CSV threshold file
#           -n creates new xxx_mon.cfg file using baseline xxx_mon.cfg
#           -e creates new xxx_mon.cfg file using previous cfg within managed node
#           -d deploy cfg to managed node
#           -m <mon_module>: df_mon|srv_mon|ps_mon|perfmon
#           -v Verbose mode
#           -s <event_mon_codes>
# Routines:
################################################################################
#v1.1
#   - Routines created:
#       parse_csv_mon_line_to_gvars_thresholds()
#       create_script_dirs()
#       create_soft_link_cfgs()
################################################################################
#dirs to create initially:
# /opt/OpC_local/mon_cfg_creator
# /opt/OpC_local/mon_cfg_creator/cfg/dfmon
# /opt/OpC_local/mon_cfg_creator/templates/dfmon
# /opt/OpC_local/mon_cfg_creator/log/dfmon
# /opt/OpC_local/mon_cfg_creator/cfg/perfmon
# /opt/OpC_local/mon_cfg_creator/templates/perfmon
# /opt/OpC_local/mon_cfg_creator/log/perfmon
#  perl mon_cfg_creator.pl -f $1 -m df_mon -d -v
#  perl mon_cfg_creator.pl -f node.lst -m perf_mon -d -v
# /opt/perf/bin/agsysdb -actions always
# ovpa restart alarm
#111111 Warning/222222 Error
#perl mon_cfg_creator.pl -f cma.lst -m event_mon -d -v
################################################################################
#Event codes for CSV event_mon
#WINDOWS SYSTEM LOG
#
#SYS:				      Source:* Severity:*
#SYS_CLU:			    Source:FailoverClustering Severity:*
#SYS_AD:				  Source:ActiveDirectory_DomainService Severity:*
#SYS_VirtDiskSrv:	Source:Virtual Disk Service Severity:Error
#SYS_Eventlog:		Source:EventLog Severity:Error
#SYS_HPFC:			  Source:HP Fibre Channel Severity:Error
#SYS_VHPEVA:			Source:VHPEVA Severity:Normal
#SYS_Disk:			  Source:Disk Severity:Warning
#SYS_SCSI:			  Source:iScsiPrt Severity:Warning
#SYS_QA12300:		  Source:ql2300 Severity:Error

#WINDOWS APPLICATION LOG
#APP:				      Source:* Severity:*
#APP_AD:				  Source:ActiveDirectory_DomainService Severity:*
#APP_C_AUTH:			Source:CertificationAuthority Severity:*
#APP_SQL_SERVER:	Source:MSSQLSERVER Severity:Normal
#APP_MSEXCH_SUB:	Source:MSExchangeMailSubmission Severity: Error
#APP_MSEXCH_REPL:	Source:MSExchangeRepl Severity:Warning
#APP_MSEXCH_IS:		Source:MSExchangeIS Severity:Error
#APP_BB_Disp:		  Source:BlackBerry Dispatcher TBK-BES Severity:Error
#APP_BB_ROUTER:		Source:BlackBerry Router Severity:Error
################################################################################
#Event_mon cfg file format:
#   <nodename>,<WIN>,[<CMA>],<WIN_LOGFILE_CODE>,<cr|ma|mi|wa><event_id_number>,....,EOL
#   Example:
#     tkpaimap01.transbank.local,WIN,[OS],SYS_QA12300,wa11,SYS_Disk,wa51,SYS_SCSI,wa20,SYS_Eventlog,wa6008,SYS_VirtDiskSrv,wa1,SYS_VHPEVA,wa13,APP_BB_Disp,wa10000,APP_BB_ROUTER,wa10000,EOL
#Df_mon cfg file format:
#     <nodename>,<WIN|UNIX>,[<CMA>],<FS>,<cr|ma|mi|wa><threshold>-<currency>,...,EOF
#   Example:
#     tkpaictxapp08.transbank.local,WIN,[OS],*,cr5-%,ma15-%,EOL
#Perf_mon cfg file format:
#     <nodename>,<WIN|UNIX>,[CMA],<PERF_METRIC_NAME>-<INSTANCE>,<cr|ma|mi|wa><threshold>-<duration>,...,EOL
#   Example:
#     tkpaidc01.transbank.local,WIN,[OS],GBL_MEM_UTIL-NONE,cr95-5,wa85-5,GBL_CPU_TOTAL_UTIL-NONE,cr95-5,wa85-5,EOL
#Srv_mon cfg file format:
#     <nodename>,<WIN>,AUTO_SRV_MODE=<YES|NO>,AUTO_SRV_EXP_L="<srv_name_1","<srv_name_2>",...,AUTO_SRV_RESTART=<YES|NO>,AUTO_SRV_RESTART_EXP_L="<srv_name_1","<srv_name_2>",...,[CMA]="srv_name_1",<cr|ma|mi|wa><31|11|5|3|1|0>,...,EOF
#   Example:
#     tkpaidc01.transbank.local,WIN,AUTO_SRV_MODE=NO,AUTO_SRV_EXP_L="Smartcard*",AUTO_SRV_RESTART=NO,[OS,Oracle]="oracle.exe",cr31-0,[OS]="ovcd.exe",cr31,EOF
#

#Recursive patter for global vars: WIN,((?:[\w=\"\w\*\",]|(?R))*),
#Matches: tkpaidc01.transbank.local,WIN,AUTO_SRV_RESTART=NO,AUTO_SRV_MODE="NO",AUTO_SRV_EXP_L="Smartcard*","oracle.exe",cr31,"ovcd.exe",cr31,EOF

use warnings;
use strict;
use Getopt::Std;
use Data::Dumper qw(Dumper);

our %opts = ();
getopts("f:c:m:s:evd", \%opts) or exit 1;

#Global script variables

my $datetime_stamp = `date "+%m%d%Y_%H%M%S"`;
chomp($datetime_stamp);
my @node_drive_tokens = ();
my @node_drive_tokens_sorted = ();
my @ovdeploy_file_cmd = ();
my $script_path = '/opt/OpC_local/MON_CFG_CREATOR';
my $script_path_var = '/var/opt/OpC_local/MON_CFG_CREATOR';
my $csv_input_filename = "";
my $modules_to_cfg = "";
my $csv_input_line = "";
my $deploy_flag = "0";
my $verbose_flag = "0";
# Variables for dfmon module
my @array_to_dfmon_cfg = ();
my $script_dfmon_created_cfgs = $script_path_var."/cfg/df_mon";
my $script_dfmon_template_cfgs = $script_path."/templates/df_mon";
my $script_dfmon_tmp = $script_path_var."/tmp/df_mon";
my $script_dfmon_log_path = $script_path_var."/log/df_mon";
my $script_dfmon_log_file_path = $script_path_var."/log/df_mon/df_mon_cfg_push.log.$datetime_stamp";

# Variables for perfmon module
my @array_to_perfmon_cfg = ();
my $script_perfmon_created_cfgs = $script_path_var."/cfg/perf_mon";
my $script_perfmon_template_cfgs = $script_path."/templates/perf_mon";
my $script_perfmon_tmp = $script_path_var."/tmp/perf_mon";
my $script_perfmon_log_path = $script_path_var."/log/perf_mon";
my $script_perfmon_log_file_path = $script_path_var."/log/perf_mon/perf_mon_cfg_push.log.$datetime_stamp";

my @array_to_event_mon_cfg = ();
my $script_event_mon_created_cfgs = $script_path_var."/cfg/event_mon";
my $script_event_mon_template_cfgs = $script_path."/templates/event_mon";
my $script_event_mon_tmp = $script_path_var."/tmp/event_mon";
my $script_event_mon_log_path = $script_path_var."/log/event_mon";
my $script_event_mon_log_file_path = $script_path_var."/log/event_mon/event_mon_cfg_push.log.$datetime_stamp";

my @array_to_srv_mon_cfg = ();
my $script_srv_mon_created_cfgs = $script_path_var."/cfg/srv_mon";
my $script_srv_mon_template_cfgs = $script_path."/templates/srv_mon";
my $script_srv_mon_tmp = $script_path_var."/tmp/srv_mon";
my $script_srv_mon_log_path = $script_path_var."/log/srv_mon";
my $script_srv_mon_log_file_path = $script_path_var."/log/srv_mon/srv_mon_cfg_push.log.$datetime_stamp";

#v1.1: Use a global dir for cfg templates
my $script_template_dir = $script_path."/templates";

#v1.1: Create needed directories
my @script_mon_cfg_mondules = ('df_mon', 'srv_mon', 'perf_mon', 'event_mon', 'test_srv_mon');

#Location of baseline xxx_mon.cfg in HPOM
my @baseline_mon_cfgs = ('/var/opt/OV/share/databases/OpC/mgd_node/customer/ms/x64/win2k3/actions/df_mon.cfg',
                         '/var/opt/OV/share/databases/OpC/mgd_node/customer/linux/x64/linux26/cmds/df_mon.cfg',
                         '/var/opt/OV/share/databases/OpC/mgd_node/customer/ms/x64/win2k3/actions/perf_mon.cfg',
                         '/var/opt/OV/share/databases/OpC/mgd_node/customer/ms/x64/win2k3/actions/srv_mon.cfg',
                         '/var/opt/OV/share/databases/OpC/mgd_node/customer/ms/x64/win2k3/actions/event_mon.cfg',
                         '/var/opt/OV/share/databases/OpC/mgd_node/customer/linux/x64/linux26/cmds/UXMONperf.cfg');

#v1.1: Create needed directories
create_script_dirs(\@script_mon_cfg_mondules, $script_path_var);
#v1.1: Create needed soft links
create_soft_link_cfgs(\@baseline_mon_cfgs, $script_path_var);
#v1.1: To define is uses new or existing cfg as base file
my $user_existing_cfg = "0";
my $in_csv_line = '';
my $in_csv_line_counter = 0;
# If -f and -m options are not defined
#if ((defined $opts{s}) || (!defined $opts{f}) || (!defined $opts{c}) || (!defined $opts{m}) || (!defined $opts{v}) || (!defined $opts{d}))
#{
#  if($opts{s} eq "event_mon")
#  {
#    print "\nCodes for event_mon CSV:\n";
#    print "\nFor System logfile:\n";
#    print " SYS:\t\t\tSource:* Severity:*\n";
#    print " SYS_CLU:\t\tSource:FailoverClustering Severity:*\n";
#    print " SYS_AD:\t\tSource:ActiveDirectory_DomainService Severity:*\n";
#    print " SYS_VirtDiskSrv:\tSource:Virtual Disk Service Severity:Error\n";
#    print " SYS_Eventlog:\t\tSource:EventLog Severity:Error\n";
#    print " SYS_HPFC:\t\tSource:HP Fibre Channel Severity:Error\n";
#    print " SYS_VHPEVA:\t\tSource:VHPEVA Severity:Normal\n";
#    print " SYS_Disk:\t\tSource:Disk Severity:Warning\n";
#    print " SYS_SCSI:\t\tSource:iScsiPrt Severity:Warning\n";
#    print " SYS_QA12300:\t\tSource:ql2300 Severity:Error\n\n";
#    print "For Application logfile:\n";
#    print " APP:\t\t\tSource:* Severity:*\n";
#    print " APP_AD:\t\tSource:ActiveDirectory_DomainService Severity:*\n";
#    print " APP_C_AUTH:\t\tSource:CertificationAuthority Severity:*\n";
#    print " APP_SQL_SERVER:\tSource:MSSQLSERVER Severity:Normal\n";
#    print " APP_MSEXCH_SUB:\tSource:MSExchangeMailSubmission Severity:Error\n";
#    print " APP_MSEXCH_REPL:\tSource:MSExchangeRepl Severity:Warning\n";
#    print " APP_MSEXCH_IS:\t\tSource:MSExchangeIS Severity:Error\n";
#    print " APP_BB_Disp:\t\tSource:BlackBerry Dispatcher TBK-BES Severity:Error\n";
#    print " APP_BB_ROUTER:\t\tSource:BlackBerry Router Severity:Error\n\n";
#    exit 0;
#  }
#}

#neither input csv file nor xxx_mon module is defined by user
if ((!defined $opts{f}) || (!defined $opts{m}))
{
  print "Option -f needs csv input file defined!\n" if (!defined $opts{f});
  print "Option -m needs one of the following parameters defined:\ndf_mon, srv_mon, ps_mon, perf_mon\n\n" if (!defined $opts{m});
  exit 1;
}

#Chomps parameter for -f and -m
chomp($csv_input_filename = $opts{f});
chomp($modules_to_cfg = $opts{m});

#Script exits if -m parameter does not match a valid module name
if (!grep {$modules_to_cfg eq $_} @script_mon_cfg_mondules)
{
  print "\nInvalid mon module (-m) value (\"$modules_to_cfg\")!\nPlease use one of the parameters:\n";
  print "@script_mon_cfg_mondules\n\n";
  exit 1;
}
#Open CSV file for reading
open (FSCSV, "< $script_path/$csv_input_filename")
  or die "\nFile $csv_input_filename does not exits in path $script_path/!\n\n";

#Reads CSV file
print "\nRunning mon_cfg_creator v1.0 ...\n\n";
if (defined $opts{v})
{
  print "Verbose mode activated!\n" ;
  $verbose_flag = "1";
}
if (defined $opts{d})
{
  print "Deployment mode activated!\n";
  $deploy_flag = "1";
}
#v1.1: To define is uses new or existing cfg as base file
if (defined $opts{e})
{
  $user_existing_cfg = "1";
}
#Read CSV input file line by line
while (<FSCSV>)
{
  $in_csv_line_counter++;
  chomp($in_csv_line = $_);
  #print "$in_csv_line\n";
  my %hash_csv_cfg_vals = parse_csv_mon_line_to_gvars_thresholds($in_csv_line);
  if ($hash_csv_cfg_vals{csv_parse_return} eq "OK")
  {
    #print "RETURNED(parse_csv_mon_line_to_gvars_thresholds):$hash_csv_cfg_vals{csv_parse_return}\n";
    #print "Passing returned hash to sub process_hash_to_cfg_lines()\n";
    my $r_process_hash_to_cfg_lines = process_hash_to_cfg_lines(\%hash_csv_cfg_vals, $modules_to_cfg, $script_path_var, $user_existing_cfg);
    #node is not wintel
    #print "RETURNED(process_hash_to_cfg_lines):$r_process_hash_to_cfg_lines[0]\n";
    #node OS not compatible with xxx_mon module
    if ($r_process_hash_to_cfg_lines == 1)
    {
      print "ERROR:NOK_MON_NODE_OS:LINE:$in_csv_line_counter\n";
    }
    #node not found within HPOM
    if ($r_process_hash_to_cfg_lines == 2)
    {
      #print "ERROR:NOK_NODE_IN_HPOM:LINE:$hash_csv_cfg_vals{csv_parse_return}:$r_process_hash_to_cfg_lines[0]\n";
      print "ERROR:NOK_NODE_IN_HPOM:LINE:$in_csv_line_counter\n";
    }
    #node ssl not working
    if ($r_process_hash_to_cfg_lines == 3)
    {
      #print "ERROR:NOK_NODE_IN_HPOM:LINE:$hash_csv_cfg_vals{csv_parse_return}:$r_process_hash_to_cfg_lines[0]\n";
      print "ERROR:NOK_NODE_SSL:LINE:$in_csv_line_counter\n";
    }
    #node prefered xxx_mon.cfg not found
    if ($r_process_hash_to_cfg_lines == 4)
    {
      #print "ERROR:NOK_NODE_IN_HPOM:LINE:$hash_csv_cfg_vals{csv_parse_return}:$r_process_hash_to_cfg_lines[0]\n";
      print "ERROR:NOK_NODE_PREF_SRV_MON_CFG:LINE:$in_csv_line_counter\n";
    }
    #error while downloading xxx_mon.cfg from node
    if ($r_process_hash_to_cfg_lines == 5)
    {
      #print "ERROR:NOK_NODE_IN_HPOM:LINE:$hash_csv_cfg_vals{csv_parse_return}:$r_process_hash_to_cfg_lines[0]\n";
      print "ERROR:NOK_DWN_SRV_MON_CFG_NODE:LINE:$in_csv_line_counter\n";
    }
    #xxx_mon.cfg not found in HPOM download path /var/opt/OpC_local/MON_CFG_CREATOR/tmp/
    if ($r_process_hash_to_cfg_lines == 6)
    {
      #print "ERROR:NOK_NODE_IN_HPOM:LINE:$hash_csv_cfg_vals{csv_parse_return}:$r_process_hash_to_cfg_lines[0]\n";
      print "ERROR:NOK_SRV_MON_CFG_IN_HPOM:LINE:$in_csv_line_counter\n";
    }
    if ($r_process_hash_to_cfg_lines == 7)
    {
      #print "ERROR:NOK_NODE_IN_HPOM:LINE:$hash_csv_cfg_vals{csv_parse_return}:$r_process_hash_to_cfg_lines[0]\n";
      print "ERROR:NOK_CSV_OS_NODE_OS:LINE:$in_csv_line_counter\n";
    }
    #node is not an OS based server (MACH_BBC_OTHER)
    if ($r_process_hash_to_cfg_lines == 8)
    {
      #print "ERROR:NOK_NODE_IN_HPOM:LINE:$hash_csv_cfg_vals{csv_parse_return}:$r_process_hash_to_cfg_lines[0]\n";
      print "ERROR:NOK_NON_OS_NODE:LINE:$in_csv_line_counter\n";
    }
  }
  else
  {
    #print "ERROR:NOK_NODE_IN_HPOM:LINE:$hash_csv_cfg_vals{csv_parse_return}\n";
    print "ERROR:NOK_CSV_SYNTAX:LINE:$in_csv_line_counter\n";
  }
  print "\rMoving to next node...";
  #}
  print "\n\n";
}
close(FSCSV);

################################################################################
# Sub name:     csv_parse_to_array
# Description:  sub that parses a csv threshold line and organizes it into a
#               multidimensional array
# Parms:        $fs_csv_line
# Return:       @array_to_dfmon
################################################################################
sub parse_csv_to_array
{
  my @array_to_dfmon = ();
  my @cma_thresholds_to_process = ();
  my $cma_value = "";
  my $drive_plus_thresholds = "";
  #my $drive_plus_thresholds_f = "";
  my $index_fs_found = 0;
  my $index_fs_sev = 0;
  my $grouped_severities = "";
  my $drive_fs_name = "";

  chomp(my $fs_csv_line = shift);
  #print "CSV LINE: $fs_csv_line\n";
  $fs_csv_line =~ s/\s\s+//;
  my @csv_line_into_array = split /,/, $fs_csv_line;

  #Loop through all array elements
  for (my $i = 0; $i <= (scalar @csv_line_into_array - 1); $i++)
  {
    #print "$csv_line_into_array[$i]\n";
    if (($csv_line_into_array[$i] =~ m/\[[\w\d]+\]/))
    {
      #If two CMA parameters are next two each other, merge them and remove from array second CMA parameter
      if (($csv_line_into_array[$i] =~ m/\[[\w\d]+\]/) && ($csv_line_into_array[$i+1] =~ m/\[[\w\d]+\]/))
      {
        #Merge consecutive array elements containing CMAs
        $cma_value = $csv_line_into_array[$i].",".$csv_line_into_array[$i+1];
        $csv_line_into_array[$i] = $cma_value;
        #print "i = $i\n";
        #Removes element from array
        splice @csv_line_into_array, ($i+1), 1;
      }
      my $j = $i+1;
      #Process array elements string while a [*] or EOF is not found
      while ($csv_line_into_array[$j] !~ m/\[.*\]|EOL/)
      {
        my $k = $j;
        # Obtain the drive FS letter or nameñ
        chomp($csv_line_into_array[$k]);
        $drive_fs_name = $csv_line_into_array[$k]."--";
        $k++;
        #print "$drive_fs_name\n";
        #Group array elements while regex cr\d+|ma\d+|mi\d+|wa\d+ is found within array element
        while($csv_line_into_array[$k] =~ m/cr\d+|ma\d+|mi\d+|wa\d+/)
        {
          $grouped_severities = $grouped_severities.$csv_line_into_array[$k].";";
          $index_fs_sev++;
          $k++;
        }
        #Appends drive/FS and grouped severities
        $drive_plus_thresholds = $drive_fs_name.$grouped_severities;
        $csv_line_into_array[$j] = $drive_plus_thresholds;
        #print "j=$j \$index_fs_sev=$index_fs_sev\n";
        #Removes the array elements that contained the severities
        splice @csv_line_into_array, ($j+1), ($index_fs_sev);
        $index_fs_sev = 0;
        #splice @csv_line_into_array, ($j+1), ($index_fs_sev - 1);
        #$drive_plus_thresholds = $drive_plus_thresholds."-".$csv_line_into_array[$j];
        $index_fs_found++;
        $j++;
        $grouped_severities = "";
      }
    }
  }
  #$r++;
  pop @csv_line_into_array;
  return @csv_line_into_array;
  #print "$r\n";
  #sleep 5;
}

################################################################################
#                                                                              #
################################################################################
#                                                                              #
################################################################################
sub array_element_to_perfmon_cfg
{
  my ($perf_mon_template_dir, $perf_mon_cfg_dir, $array_with_perfmon_parms, $deploy_flag, $date_and_time, $script_log_file_path, $verbose_flag) = @_;
  my $cfg_prefered_path = "";
  my $perfmon_template_file = "";
  my $perfmon_data_template_file = "";  #--->new
  my $cma_parameter = "";
  my $metric_def_instance = "";
  my $metric_def = "";
  my $metric_instance = "";
  my $alert_def = "";
  my $alert_threshold_duration = "";
  my @array_of_metric_def = ();
  my @array_metric_def_instance = ();
  my $separated_severity_def = "";
  my $separated_threshold_def = "";
  my $array_index_counter = "0";
  my $perfmon_cfg_filename = "";
  my $perfmon_data_filename = "";     #--->new
  my $perfmoncfg_exists_in_path = "";
  my $perfmondat_exists_in_path = ""; #--->new
  my $check_nodes_prefered_path = "";
  my $ssl_to_node_result = "";
  my $perf_mon_file_name = "";
  my $perf_mon_data_file_name = "";   #--->new
  my $alarmdef_path = "/var/opt/perf";
  my $perfmon_alarmdef_filename = "";
  #Dereference array and extracts nodename
  my $node_name = shift @{$array_with_perfmon_parms};
  #Dereference array and extracts node os
  my $node_os = lc(shift @{$array_with_perfmon_parms});
  my $dont_deploy_file = "0";
  chomp($deploy_flag);

  print "\nProcessing node: $node_name - OS: $node_os\n" if (!defined $opts{v});
  print "\nNodename: $node_name \nOS: $node_os\n" if (defined $opts{v});
  if ($node_os eq "unix")
  {
    chomp($node_os);
    $perf_mon_file_name = "UXMONperf.cfg";
    $perf_mon_data_file_name = "alarmdef";
    $perfmon_template_file = $perf_mon_template_dir."/"."UXMONperf.cfg.unix";
    $cfg_prefered_path = "/var/opt/OV/conf/OpC";
    $perfmon_cfg_filename = $perf_mon_cfg_dir."/".$perf_mon_file_name.".".$node_name.".".$node_os;
    $perfmon_alarmdef_filename = $alarmdef_path."/".$perf_mon_data_file_name;
  }
  #If node is win
  if ($node_os eq "win")
  {
    $perf_mon_file_name = "perf_mon.cfg";
    $perf_mon_data_file_name = "perf_mon.dat";
    $perfmon_template_file = $perf_mon_template_dir."/"."perf_mon.cfg.win";
    $perfmon_data_template_file = $perf_mon_template_dir."/"."perf_mon.dat";
    $cfg_prefered_path = 'c:\osit\etc';
    $perfmon_cfg_filename = $perf_mon_cfg_dir."/".$perf_mon_file_name.".".$node_name.".".$node_os;
    #print "$dfmon_cfg_prefered_path\n";
  }
  print "Creating file $perfmon_cfg_filename\n" if (!defined $opts{v});
  open(WRITE_PERFMON, '>>', $perfmon_cfg_filename);
  if (open(TEMPLATE_PERFMON, '<', $perfmon_template_file))
  {
    print "Template file: $perfmon_template_file\nScript log: $script_log_file_path\n" if (defined $opts{v});
    while(<TEMPLATE_PERFMON>)
    {
      chomp($_);
      print WRITE_PERFMON "$_\n";
    }
  }
  else
  {
    script_logger($date_and_time, $script_log_file_path, "array_element_to_perfmon_cfg\($node_name\)::Error::Could not open file '$perfmon_template_file'");
    print "Could not open file '$perfmon_template_file'\n";
    exit 1;
  }
  close(TEMPLATE_DFMON);
  print "CFG filename: $perfmon_cfg_filename\n" if (defined $opts{v});
  print "Perf_mon alert definition(s):\n" if (defined $opts{v});
  print "------------------------------------------------------------------------------\n" if (defined $opts{v});
  print WRITE_PERFMON "#******************************************************************************\n";
  print WRITE_PERFMON "#                             AUTO GENERATED LINES\n";
  print WRITE_PERFMON "#******************************************************************************\n";
  foreach my $array_with_perfmon_parms_values (@{$array_with_perfmon_parms})
  {
    $array_index_counter++;
    chomp($array_with_perfmon_parms_values);
    #print "Current line is: $array_with_perfmon_parms_values\n";
    #When line matches a CMA pattern
    if ($array_with_perfmon_parms_values =~ m/\[.*\]/)
    {
      $cma_parameter = $array_with_perfmon_parms_values;
      print "CMA is: $cma_parameter\n" if (defined $opts{v});
      print WRITE_PERFMON $cma_parameter."\n" if ($node_os eq "win");
    }
    #print "$array_with_perfmon_parms_values\n";
    #When line matches <fs>-<alert_definitions> pattern
    if ($array_with_perfmon_parms_values =~ m/([\w+\s+?]+;\w+)--(\w+\d+;.*)/)
    {
      #print "$array_with_perfmon_parms_values\n";
      #Separates fs value
      $metric_def_instance = $1;
      @array_metric_def_instance = split /;/, $metric_def_instance;
      $metric_def = $array_metric_def_instance[0];
      $metric_instance = $array_metric_def_instance[1];
      chomp($metric_def);
      chomp($metric_instance);
      $metric_def = "\"".$array_metric_def_instance[0]."\"";
      $metric_instance = "\"".$array_metric_def_instance[1]."\"";
      #To assign array element in a dereferenced array
      $alert_threshold_duration = $array_with_perfmon_parms->[$array_index_counter];
      chomp($alert_threshold_duration);
      #print "Duration: $alert_threshold_duration\n";
      #print "$metric_def\n";
      #print "$metric_instance\n";
      #Separates alert definitions
      $alert_def = $2;
      #print "$alert_def\n\n";
      #Split alert definitions and writes them into array
      @array_of_metric_def = split /;/, $alert_def;
      #Loops through fs alert definitions
      foreach my $alert_metric_line (@array_of_metric_def)
      {
        $alert_metric_line =~ m/(\w{2})(\d+)/;
        chomp($separated_severity_def = $1);
        chomp($separated_threshold_def =$2);
        #chomp($separated_threshold_currency =$3);
        #Translate severity code into severity used by df_mon
        if($separated_severity_def eq "cr")
        {
          $separated_severity_def = "Critical";
        }
        if($separated_severity_def eq "ma")
        {
          $separated_severity_def = "Major\t";
        }
        if($separated_severity_def eq "mi")
        {
          $separated_severity_def = "Minor\t";
        }
        if($separated_severity_def eq "wa")
        {
          $separated_severity_def = "Warning\t";
        }
        $alert_threshold_duration =~ s/-//g;
        if ($node_os eq "win")
        {
          print "$metric_def\t$metric_instance\t$alert_threshold_duration\t$separated_severity_def\t$separated_threshold_def\t*\t0000    2400\n" if (defined $opts{v});
          print WRITE_PERFMON "$metric_def\t$metric_instance\t$alert_threshold_duration\t$separated_severity_def\t$separated_threshold_def\t*\t0000    2400\n";
        }
        if ($node_os eq "unix")
        {
          $separated_severity_def =~ s/\s+//;
          $metric_def =~ s/"//g;
          print "ALARM $metric_def > $separated_threshold_def for $alert_threshold_duration MINUTES\n" if (defined $opts{v});
          print "START EXEC \"echo \'PERFMON: $separated_severity_def Message: $metric_def Exceeds threshold of $separated_threshold_def\' >> /var/opt/OV/log/OpC/perf_mon.log\"\n" if (defined $opts{v});
          print "REPEAT EVERY 15 MINUTES\n" if (defined $opts{v});
          print "EXEC \"echo \'PERFMON: $separated_severity_def Message: $metric_def Exceeds threshold of $separated_threshold_def\' >> /var/opt/OV/log/OpC/perf_mon.log\"\n" if (defined $opts{v});
          print "END EXEC \" echo \'$metric_def > $separated_threshold_def ENDED\' >> /var/opt/OV/log/OpC/perf_mon.log\"\n\n" if (defined $opts{v});
          #Print to file
          print WRITE_PERFMON "ALARM $metric_def > $separated_threshold_def for $alert_threshold_duration MINUTES\n";
          print WRITE_PERFMON "START EXEC \"echo \'PERFMON: $separated_severity_def Message: $metric_def Exceeds threshold of $separated_threshold_def\' >> /var/opt/OV/log/OpC/perf_mon.log\"\n";
          print WRITE_PERFMON "REPEAT EVERY 15 MINUTES\n";
          print WRITE_PERFMON "EXEC \"echo \'PERFMON: $separated_severity_def Message: $metric_def Exceeds threshold of $separated_threshold_def\' >> /var/opt/OV/log/OpC/perf_mon.log\"\n";
          print WRITE_PERFMON "END EXEC \" echo \'$metric_def > $separated_threshold_def ENDED\' >> /var/opt/OV/log/OpC/perf_mon.log\"\n\n";
        }
      }
    }
  }
  print "------------------------------------------------------------------------------\n" if (defined $opts{v});
  print WRITE_PERFMON "#******************************************************************************\n";
  print WRITE_PERFMON "#\tend of perf_mon.cfg\t\n" if ($node_os eq "win");
  print WRITE_PERFMON "#\tend of UXMONperf.cfg\t\n" if ($node_os eq "unix");
  print WRITE_PERFMON "#******************************************************************************\n";
  close(WRITE_PERFMON);
  if ($deploy_flag eq "1")
  {
    print "Testing port 383 SSL communication to node ...";
    $ssl_to_node_result = testOvdeploy_HpomToNode_SSL($node_name, "3000", $date_and_time, $script_log_file_path);
    print "\n" if ($verbose_flag eq "1");
    print "\rTesting port 383 SSL communication to node ... FAILED!\n" if ($ssl_to_node_result eq "1");
    if ($ssl_to_node_result eq "0")
    {
      print "\rTesting port 383 SSL communication to node ... OK!\n" ;
      print "Checking if prefered path exists within node ...\n";
      $check_nodes_prefered_path = check_nodes_prefered_path($date_and_time, $script_log_file_path, $node_name, $node_os, $cfg_prefered_path, $verbose_flag);
      print "\n" if ($verbose_flag eq "1");
      #If prefered path exists within managed node
      if ($check_nodes_prefered_path eq "0")
      {
        print "\rChecking if prefered path exists within node ... FOUND\n";
      }
      if ($check_nodes_prefered_path eq "1")
      {
        print "\rChecking prefered path exists within node ... NOT FOUND\n";
        print "Creating $cfg_prefered_path directory ...\n";
        create_dir_routine($date_and_time, $script_log_file_path, $cfg_prefered_path, $node_name, $node_os, $verbose_flag);
      }
      print "Checking if a previous $perf_mon_file_name exists in prefered path ...";
      $perfmoncfg_exists_in_path = file_existance_in_path($date_and_time, $script_log_file_path, $node_name, $node_os, $cfg_prefered_path, $perf_mon_file_name, $verbose_flag);
      if ($node_os eq "win")
      {
        print "\nChecking if a previous $perf_mon_data_file_name exists in prefered path ...";
        $perfmondat_exists_in_path = file_existance_in_path($date_and_time, $script_log_file_path, $node_name, $node_os, $cfg_prefered_path, $perf_mon_data_file_name, $verbose_flag);
      }
      if ($node_os eq "unix")
      {
        print "\nChecking if a previous $perf_mon_data_file_name exists in prefered path ...";
        #print "\nAlarmdef: $alarmdef_path\/$perf_mon_data_file_name";
        $perfmondat_exists_in_path = file_existance_in_path($date_and_time, $script_log_file_path, $node_name, $node_os, $alarmdef_path, $perf_mon_data_file_name, $verbose_flag);
      }
      print "\n" if ($verbose_flag eq "1");
      if ($perfmoncfg_exists_in_path eq "0")
      {
        print "\rChecking if a previous $perf_mon_file_name exists in prefered path ... FOUND!\n";
        print "Backing backup of $perf_mon_file_name ...\n";
        rename_file_routine($date_and_time, $script_log_file_path, $cfg_prefered_path, $cfg_prefered_path, $perf_mon_file_name,  $node_name, $node_os, $verbose_flag);
        print "Renaming file for upload routine...\n";
        system("mv $perfmon_cfg_filename $perf_mon_cfg_dir\/$perf_mon_file_name");
        print "Deploying $perf_mon_file_name to node ...\n";
        upload_mon_file($date_and_time, $script_log_file_path, $node_name, $perf_mon_file_name, $perf_mon_cfg_dir, $cfg_prefered_path, $verbose_flag, "3000");
        print "Deployment completed!\n";
        system("rm -f $perf_mon_cfg_dir\/$perf_mon_file_name");
      }
      #If alarmdef or perf_mon.dat is found
      if ($perfmondat_exists_in_path eq "0")
      {
        print "\rChecking if a previous $perf_mon_data_file_name exists in prefered path ... FOUND!\n";
        if ($node_os eq "unix")
        {
          print "\nDownloading $alarmdef_path\/$perf_mon_data_file_name from node...";
          $cfg_prefered_path = $alarmdef_path;
          system("ovdeploy -download -file $perf_mon_data_file_name -sd $alarmdef_path -td $perf_mon_template_dir -node $node_name > /dev/null");
          system("grep -E \"\^Include\" $perf_mon_template_dir\/$perf_mon_data_file_name > /dev/null");
          #print "\nReturn code: $?\n";
          if($? eq 0)
          {
            print "\nFile $perf_mon_data_file_name already contains needed line!";
            $dont_deploy_file = "1";
          }
          else
          {
            print "\nModifying $perf_mon_template_dir\/$perf_mon_data_file_name...";
            system("sed -i \'1iInclude \"/var/opt/OV/conf/OpC/UXMONperf.cfg\"\' $perf_mon_template_dir\/$perf_mon_data_file_name");
            print "\rModifying $perf_mon_template_dir\/$perf_mon_data_file_name...COMPLETED!";
          }
          #Modify alarmef to include line at begignig of file
          #ovdeploy -cmd "mv /var/opt/perf/alarmdef.*.mcfgc /var/opt/perf/alarmdef" -node alerce2.transbank.cl
          #ovdeploy -cmd "ls -l /var/opt/perf/" -node alerce2.transbank.cl
        }
        if ($dont_deploy_file eq "0")
        {
          print "\nBacking backup of $perf_mon_data_file_name ...\n";
          rename_file_routine($date_and_time, $script_log_file_path, $cfg_prefered_path, $cfg_prefered_path, $perf_mon_data_file_name,  $node_name, $node_os, $verbose_flag);
          print "Deploying $perf_mon_data_file_name to node ...\n";
          upload_mon_file($date_and_time, $script_log_file_path, $node_name, $perf_mon_data_file_name, $perf_mon_template_dir, $cfg_prefered_path, $verbose_flag, "3000");
          print "Deployment completed!\n";
        }
        if ($perf_mon_data_file_name eq "alarmdef")
        {
          system("rm -f $perf_mon_template_dir\/$perf_mon_data_file_name");
        }
      }
      #For perf_mon.dat
      if ($perfmoncfg_exists_in_path eq "1")
      {
        print "\rChecking if a previous $perf_mon_file_name exists in prefered path ... NOT FOUND!\n";
        if ($node_os eq "unix")
        {
          $cfg_prefered_path = "/var/opt/OV/conf/OpC";
        }
        print "Renaming file for upload routine...\n";
        system("mv $perfmon_cfg_filename $perf_mon_cfg_dir\/$perf_mon_file_name");
        print "Deploying $perf_mon_file_name to node ...\n";
        upload_mon_file($date_and_time, $script_log_file_path, $node_name, $perf_mon_file_name, $perf_mon_cfg_dir, $cfg_prefered_path, $verbose_flag, "3000");
        print "Deployment completed!\n";
        system("rm -f $perf_mon_cfg_dir\/$perf_mon_file_name");
      }
      if ($perfmondat_exists_in_path eq "1")
      {
        print "\rChecking if a previous $perf_mon_data_file_name exists in prefered path ... NOT FOUND!\n";
        if ($node_os eq "unix")
        {
          print "\nUsing default $perf_mon_data_file_name...";
          $cfg_prefered_path = $alarmdef_path;
          #system("ovdeploy -download -file $perf_mon_data_file_name -sd $alarmdef_path -td $perf_mon_template_dir -node $node_name > /dev/null");
          #print "\nModifying $perf_mon_template_dir\/$perf_mon_data_file_name...";
          system("cp $perf_mon_template_dir\/$perf_mon_data_file_name.unix $perf_mon_template_dir\/$perf_mon_data_file_name");
        }
        print "\nDeploying $perf_mon_data_file_name to node ...\n";
        upload_mon_file($date_and_time, $script_log_file_path, $node_name, $perf_mon_data_file_name, $perf_mon_template_dir, $cfg_prefered_path, $verbose_flag, "3000");
        print "Deployment completed!\n";
      }
      if ($node_os eq "unix")
      {
                system("rm -f $perf_mon_template_dir\/$perf_mon_data_file_name");
      }
      if ($node_os eq "unix")
      {
        print "\nActivating OVPA integartion...";
        system("ovdeploy -cmd \"/opt/perf/bin/agsysdb -actions always\" -node $node_name > /dev/null");
        system("ovdeploy -cmd \"/opt/perf/bin/ovpa restart alarm\" -node $node_name > /dev/null");
      }
    }
  }
}

################################################################################
# Sub name:     array_element_to_dfmon_cfg
# Description:  sub that change array value into df_mon.cfg syntax lines and then
#               saves lines to df_mon.cfg
# Parms:        df_mon_template_dir, array string value, deploy_flag, date_and_time, $script_log_file_path
# Return:       None
################################################################################
sub array_element_to_dfmon_cfg
{
  my ($df_mon_template_dir, $df_mon_cfg_dir, $array_with_dfmon_parms, $deploy_flag, $date_and_time, $script_log_file_path, $verbose_flag) = @_;
  #Dereference array and extracts nodename
  my $node_name = shift @{$array_with_dfmon_parms};
  #Dereference array and extracts node os
  my $node_os = lc(shift @{$array_with_dfmon_parms});
  chomp($deploy_flag);
  my $current_cfg_line = "";
  my $array_index_counter = 0;
  my $cma_parameter = "";
  my $fs_def = "";
  my $alert_def = "";
  my @array_of_alert_def = ();
  my $separated_severity_def = "";
  my $separated_threshold_def = "";
  my $separated_threshold_currency = "";
  my $dfmon_cfg_filename = $df_mon_cfg_dir."/"."df_mon.cfg.".$node_name.".".$node_os;
  my $dfmon_template_file = "";
  my $ssl_to_node_result = "";
  my $dfmoncfg_exists_in_path = "";
  my $cfg_prefered_path = "";
  my $check_nodes_prefered_path = "";
  my $rename_file_routine_result = "";
  print "\nProcessing node: $node_name - OS: $node_os\n" if (!defined $opts{v});
  print "\nNodename: $node_name \nOS: $node_os\n" if (defined $opts{v});
  print "CFG filename: $dfmon_cfg_filename\n" if (defined $opts{v});

  #Based on node's OS, define which df_mon.cfg template file to use
  #If node is unix
  if ($node_os eq "unix")
  {
      $dfmon_template_file = $df_mon_template_dir."/"."df_mon.cfg.unix";
      $cfg_prefered_path = "/var/opt/OV/conf/OpC";
  }
  #If node is win
  if ($node_os eq "win")
  {
    $dfmon_template_file = $df_mon_template_dir."/"."df_mon.cfg.win";
    $cfg_prefered_path = 'c:\osit\etc';
    #print "$dfmon_cfg_prefered_path\n";
  }
  #Make a copy of the df_mon.cfg template file for the processed managed based on OS
  print "Creating file $dfmon_cfg_filename\n" if (!defined $opts{v});
  open(WRITE_DFMON, '>', $dfmon_cfg_filename);
  if (open(TEMPLATE_DFMON, '<', $dfmon_template_file))
  {
    print "Template file: $dfmon_template_file\nScript log: $script_log_file_path\n" if (defined $opts{v});
    while(<TEMPLATE_DFMON>)
    {
      chomp($_);
      print WRITE_DFMON "$_\n";
    }
  }
  else
  {
    script_logger($date_and_time, $script_log_file_path, "array_element_to_dfmon_cfg\($node_name\)::Error::Could not open file '$dfmon_template_file'");
    print "Could not open file '$dfmon_template_file'\n";
    exit 1;
  }
  close(TEMPLATE_DFMON);
  print "Df_mon.cfg FS alert definition(s):\n" if (defined $opts{v});
  print "------------------------------------------------------------------------------\n" if (defined $opts{v});
  print WRITE_DFMON "#******************************************************************************\n";
  print WRITE_DFMON "#                             AUTO GENERATED LINES\n";
  print WRITE_DFMON "#******************************************************************************\n";
  foreach my $array_with_dfmon_parms_values (@{$array_with_dfmon_parms})
  {
    chomp($array_with_dfmon_parms_values);
    #print "$array_with_dfmon_parms_values\n";
    #When line matches a CMA pattern
    if ($array_with_dfmon_parms_values =~ m/\[.*\]/)
    {
      $cma_parameter = $array_with_dfmon_parms_values;
      if ($node_os eq "unix")
      {
        $cma_parameter =~ s/\],\[/,/;
        #my $cma_1 = $1;
        #my $cma_2 = $2;
        #$cma_parameter = "\[$cma_1,$cma_1\]";
      }
      print "$cma_parameter\n" if (defined $opts{v});
      print WRITE_DFMON $cma_parameter."\n";
    }
    #When line matches <fs>--<alert_definitions> pattern
    if ($array_with_dfmon_parms_values =~ m/([*]|[\w\d:\/-]+)--(\w+\d+[MB|GB|%];.*)/)
    {
      #print "$array_with_dfmon_parms_values\n";
      #Separates fs value
      $fs_def = $1;
      #print "FS: $fs_def\n";
      #Separates alert definitions
      $alert_def = $2;
      #print "$alert_def\n";
      #Split alert definitions and writes them into array
      @array_of_alert_def = split /;/, $alert_def;
      #Loops through fs alert definitions
      foreach my $alert_def_line (@array_of_alert_def)
      {
        #Separates alert definition into severity, threshold, currency
        $alert_def_line =~ m/(\w{2})(\d+)([MB|GB|%])/;
        chomp($separated_severity_def = $1);
        chomp($separated_threshold_def =$2);
        chomp($separated_threshold_currency =$3);
        #Translate severity code into severity used by df_mon
        if($separated_severity_def eq "cr")
        {
          $separated_severity_def = "Critical";
        }
        if($separated_severity_def eq "ma")
        {
          $separated_severity_def = "Major\t";
        }
        if($separated_severity_def eq "mi")
        {
          $separated_severity_def = "Minor\t";
        }
        if($separated_severity_def eq "wa")
        {
          $separated_severity_def = "Warning";
        }
        #df_mon alert syntax line
        #“c:” Warning 5 500 MB NT 0-6 0700 2200
        #/home/userx 50Mb - 0800-1700 *
        #print "$fs_def $separated_severity_def $separated_threshold_def $separated_threshold_currency\n";
        if ($node_os eq "unix")
        {
          print "$fs_def\t$separated_threshold_def$separated_threshold_currency\t$separated_severity_def\t0000-2400\t*\n" if (defined $opts{v});
          print WRITE_DFMON "$fs_def\t$separated_threshold_def$separated_threshold_currency\t$separated_severity_def\t0000-2400\t*\n";
        }
        if ($node_os eq "win")
        {
          print "\"$fs_def\"\t$separated_severity_def\t$separated_threshold_def\t$separated_threshold_currency\t*\t0000    2400\n" if (defined $opts{v});
          print WRITE_DFMON "\"$fs_def\"\t$separated_severity_def\t$separated_threshold_def\t$separated_threshold_currency\t*\t0000    2400\n";
        }
      }
      #print Dumper @array_of_alert_def;
    }
    $array_index_counter++;
  }
  print "------------------------------------------------------------------------------\n" if (defined $opts{v});
  print WRITE_DFMON "#******************************************************************************\n";
  print WRITE_DFMON "#\tend of df_mon.cfg\t\n";
  print WRITE_DFMON "#******************************************************************************\n";
  close(WRITE_DFMON);
  if ($deploy_flag eq "1")
  {
    print "Testing port 383 SSL communication to node ...";
    $ssl_to_node_result = testOvdeploy_HpomToNode_SSL($node_name, "3000", $date_and_time, $script_log_file_path);
    print "\n" if ($verbose_flag eq "1");
    print "\rTesting port 383 SSL communication to node ... FAILED!\n" if ($ssl_to_node_result eq "1");
    if ($ssl_to_node_result eq "0")
    {
      print "\rTesting port 383 SSL communication to node ... OK!\n" ;
      print "Checking if prefered path exists within node ...";
      $check_nodes_prefered_path = check_nodes_prefered_path($date_and_time, $script_log_file_path, $node_name, $node_os, $cfg_prefered_path, $verbose_flag);
      print "\n" if ($verbose_flag eq "1");
      #If prefered path exists within managed node
      if ($check_nodes_prefered_path eq "0")
      {
        print "\rChecking if prefered path exists within node ... FOUND\n";
        print "Checking if a previous df_mon.cfg exists in prefered path ...";
        $dfmoncfg_exists_in_path = file_existance_in_path($date_and_time, $script_log_file_path, $node_name, $node_os, $cfg_prefered_path, "df_mon.cfg", $verbose_flag);
        print "\n" if ($verbose_flag eq "1");
        if ($dfmoncfg_exists_in_path eq "0")
        {
          print "\rChecking if a previous df_mon.cfg exists in prefered path ... FOUND!\n";
          print "Backing backup of df_mon.cfg ...\n";
          rename_file_routine($date_and_time, $script_log_file_path, $cfg_prefered_path, $cfg_prefered_path, "df_mon.cfg",  $node_name, $node_os, $verbose_flag);
          print "Renaming file for upload routine...\n";
          system("mv $dfmon_cfg_filename $df_mon_cfg_dir\/df_mon.cfg");
          print "Deploying df_mon.cfg to node ...\n";
          upload_mon_file($date_and_time, $script_log_file_path, $node_name, "df_mon.cfg", $df_mon_cfg_dir, $cfg_prefered_path, $verbose_flag, "3000");
          print "Deployment completed!\n";
          system("rm -f $dfmon_cfg_filename\/df_mon.cfg");
        }
        if ($dfmoncfg_exists_in_path eq "1")
        {
          print "\rChecking if a previous df_mon.cfg exists in prefered path ... NOT FOUND!\n";
          print "Renaming file for upload routine...\n";
          system("mv $dfmon_cfg_filename $df_mon_cfg_dir\/df_mon.cfg");
          print "Deploying df_mon.cfg to node ...\n";
          upload_mon_file($date_and_time, $script_log_file_path, $node_name, "df_mon.cfg", $df_mon_cfg_dir, $cfg_prefered_path, $verbose_flag, "3000");
          print "Deployment completed!\n";
          system("rm -f $dfmon_cfg_filename\/df_mon.cfg");
        }
      }
      #If does not exists create it
      if ($check_nodes_prefered_path eq "1")
      {
          print "\rChecking prefered path exists within node ... NOT FOUND\n";
          print "Creating $cfg_prefered_path directory ...\n";
          create_dir_routine($date_and_time, $script_log_file_path, $cfg_prefered_path, $node_name, $node_os, $verbose_flag);
          print "Renaming file for upload routine...\n";
          system("mv $dfmon_cfg_filename $df_mon_cfg_dir\/df_mon.cfg");
          print "Deploying df_mon.cfg to node ...\n";
          upload_mon_file($date_and_time, $script_log_file_path, $node_name, "df_mon.cfg", $df_mon_cfg_dir, $cfg_prefered_path, $verbose_flag, "3000");
          print "Deployment completed!\n";
          system("rm -f $dfmon_cfg_filename\/df_mon.cfg");
      }
    }
  }
  #print Dumper @{$array_with_dfmon_parms};
}


################################################################################
# Sub name:     array_element_to_eventmon_cfg
# Description:  sub that change array value into df_mon.cfg syntax lines and then
#               saves lines to df_mon.cfg
# Parms:        df_mon_template_dir, array string value, deploy_flag, date_and_time, $script_log_file_path
# Return:       None
################################################################################
sub array_element_to_event_mon_cfg
{
  my ($event_mon_template_dir, $event_mon_cfg_dir, $array_with_event_mon_parms, $deploy_flag, $date_and_time, $script_log_file_path, $verbose_flag) = @_;
  #Dereference array and extracts node name
  my $node_name = shift @{$array_with_event_mon_parms};
  my $node_os = lc(shift @{$array_with_event_mon_parms});
  #Dereference array and extracts node os
  #my $node_os = lc(shift @{$array_with_eventmon_parms});
  chomp($deploy_flag);
  my $current_cfg_line = "";
  my $array_index_counter = 0;
  my $cma_parameter = "";
  my $separated_win_log_type_source = "";
  my $alert_def = "";
  my @array_of_alert_def = ();
  my $separated_severity_def = "";
  my $separated_event_id_def = "";
  my $event_mon_cfg_filename = $event_mon_cfg_dir."/"."event_mon.cfg.".$node_name.".".$node_os;
  my $event_mon_template_file = "";
  my $ssl_to_node_result = "";
  my $event_mon_cfg_exists_in_path = "";
  my $cfg_prefered_path = "";
  my $check_nodes_prefered_path = "";
  my $rename_file_routine_result = "";
  my ($ev_name, $ev_logfile, $ev_source, $ev_id, $ev_sev, $tck_sev, $ev_action) = ("", "", "", "", "", "", "");
  print "\nProcessing node: $node_name - OS: $node_os\n" if (!defined $opts{v});
  #print "\nNodename: $node_name \nOS: $node_os\n" if (defined $opts{v});
  #print "CFG filename: $event_mon_cfg_filename\n" if (defined $opts{v});

  #Validate that node exists within HPOM db
  #[MACH_BBC_LX26|MACH_BBC_SOL|MACH_BBC_HPUX|MACH_BBC_AIX|MACH_BBC_WIN]
  my @check_node_in_HPOM = check_node_in_HPOM($node_name);

  if ($check_node_in_HPOM[0] eq "1")
  {
    #print "Node was FOUND!\n";
    if ($check_node_in_HPOM[3] =~ m/MACH_BBC_WIN/)
    {
      $node_os = "win";
    }
    else
    {
      #OS node supported
      return 2;
    }
  }
  else
  {
    #print "Node was NOT FOUND!\n";
    #Node not found within HPOM
    return 1;
  }
  #If node is win
  if ($node_os eq "win")
  {
    $event_mon_template_file = $event_mon_template_dir."/"."event_mon.cfg.win";
    $cfg_prefered_path = 'c:\osit\etc';
    #print "$dfmon_cfg_prefered_path\n";
  }
  $event_mon_cfg_filename = $event_mon_cfg_dir."/"."event_mon.cfg.".$node_name.".".$node_os;
  print "\nNodename: $node_name \nOS: $node_os\n" if (defined $opts{v});
  print "CFG filename: $event_mon_cfg_filename\n" if (defined $opts{v});
  #Make a copy of the event_mon.cfg template file for the processed managed based on OS
  print "Creating file $event_mon_cfg_filename\n" if (!defined $opts{v});
  open(WRITE_EVENT_MON, '>', $event_mon_cfg_filename);
  if (open(TEMPLATE_EVENT_MON, '<', $event_mon_template_file))
  {
    print "Template file: $event_mon_template_file\nScript log: $script_log_file_path\n" if (defined $opts{v});
    while(<TEMPLATE_EVENT_MON>)
    {
      chomp($_);
      print WRITE_EVENT_MON "$_\n";
    }
  }
  else
  {
    script_logger($date_and_time, $script_log_file_path, "array_element_to_dfmon_cfg\($node_name\)::Error::Could not open file '$event_mon_template_file'");
    print "Could not open file '$event_mon_template_file'\n";
    exit 1;
  }
  close(TEMPLATE_EVENT_MON);
  print "Event_mon.cfg event id alert definition(s):\n" if (defined $opts{v});
  print "------------------------------------------------------------------------------\n" if (defined $opts{v});
  print WRITE_EVENT_MON "#******************************************************************************\n";
  print WRITE_EVENT_MON "#                             AUTO GENERATED LINES\n";
  print WRITE_EVENT_MON "#******************************************************************************\n";
  foreach my $array_with_event_mon_parms_values (@{$array_with_event_mon_parms})
  {
    chomp($array_with_event_mon_parms_values);
    #print "TEST: $array_with_event_mon_parms_values\n";
    #When line matches a CMA pattern
    if ($array_with_event_mon_parms_values =~ m/\[.*\]/)
    {
      $cma_parameter = $array_with_event_mon_parms_values;
      print "$cma_parameter\n" if (defined $opts{v});
      ###print WRITE_DFMON $cma_parameter."\n";
    }
    #When line matches <fs>--<alert_definitions> pattern
    if ($array_with_event_mon_parms_values =~ m/([*]|[\w\d:\/-]+)--(\w+\d+;.*)/)
    {
      ##print "$array_with_event_mon_parms_values\n";
      #Separates fs value
      $separated_win_log_type_source = $1;
      #print "EVENT_SOURCE: $separated_win_log_type_source\n";
#START##################################################################################SYSTEM LOFGILE EVENTS
      #Condition for "Log-->System"
      if ($separated_win_log_type_source eq "SYS")
      {
        $ev_logfile = "System";
        $ev_source = "*";
        $ev_sev = "*";
      }
      #Condition for "Log-->System/Source-->FailoverClustering"
      if ($separated_win_log_type_source eq "SYS_CLU")
      {
        $ev_logfile = "System";
        $ev_source = "FailoverClustering";
        $ev_sev = "*";
      }
      #Condition for "Log-->System/Source-->ActiveDirectory_DomainService"
      if ($separated_win_log_type_source eq "SYS_AD")
      {
        $ev_logfile = "System";
        $ev_source = "ActiveDirectory_DomainService";
        $ev_sev = "*";
      }
      if ($separated_win_log_type_source eq "SYS_VirtDiskSrv")
      {
        $ev_logfile = "System";
        $ev_source = "Virtual Disk Service";
        $ev_sev = "Error";
      }
      if ($separated_win_log_type_source eq "SYS_Eventlog")
      {
        $ev_logfile = "System";
        $ev_source = "EventLog";
        $ev_sev = "Error";
      }
      if ($separated_win_log_type_source eq "SYS_HPFC")
      {
        $ev_logfile = "System";
        $ev_source = "HP Fibre Channel";
        $ev_sev = "Error";
      }
      if ($separated_win_log_type_source eq "SYS_VHPEVA")
      {
        $ev_logfile = "System";
        $ev_source = "VHPEVA";
        $ev_sev = "Normal";
      }
      if ($separated_win_log_type_source eq "SYS_Disk")
      {
        $ev_logfile = "System";
        $ev_source = "Disk";
        $ev_sev = "Warning";
      }
      if ($separated_win_log_type_source eq "SYS_SCSI")
      {
        $ev_logfile = "System";
        $ev_source = "iScsiPrt";
        $ev_sev = "Warning";
      }
      if ($separated_win_log_type_source eq "SYS_QA12300")
      {
        $ev_logfile = "System";
        $ev_source = "ql2300";
        $ev_sev = "Error";
      }
#END##################################################################################SYSTEM LOFGILE EVENTS
#START################################################################################APPLICATION LOFGILE EVENTS
      #Condition for "Log-->Application"
      if ($separated_win_log_type_source eq "APP")
      {
        $ev_logfile = "Application";
        $ev_source = "*";
        $ev_sev = "*";
      }
      #Condition for "Log-->Application/Source-->ActiveDirectory_DomainService"
      if ($separated_win_log_type_source eq "APP_AD")
      {
        $ev_logfile = "Application";
        $ev_source = "ActiveDirectory_DomainService";
        $ev_sev = "*";
      }
      #Condition for "Log-->System/Source-->ActiveDirectory_DomainService"
      if ($separated_win_log_type_source eq "APP_C_AUTH")
      {
        $ev_logfile = "Application";
        $ev_source = "CertificationAuthority";
        $ev_sev = "*";
      }
      if ($separated_win_log_type_source eq "APP_SQL_SERVER")
      {
        $ev_logfile = "Application";
        $ev_source = "MSSQLSERVER";
        $ev_sev = "Normal";
      }
      if ($separated_win_log_type_source eq "APP_MSEXCH_SUB")
      {
        $ev_logfile = "Application";
        $ev_source = "MSExchangeMailSubmission";
        $ev_sev = "Error";
      }
      if ($separated_win_log_type_source eq "APP_MSEXCH_REPL")
      {
        $ev_logfile = "Application";
        $ev_source = "MSExchangeRepl";
        $ev_sev = "Warning";
      }
      if ($separated_win_log_type_source eq "APP_MSEXCH_IS")
      {
        $ev_logfile = "Application";
        $ev_source = "MSExchangeIS";
        $ev_sev = "Error";
      }
      if ($separated_win_log_type_source eq "APP_BB_Disp")
      {
        $ev_logfile = "Application";
        $ev_source = "BlackBerry Dispatcher TBK-BES";
        $ev_sev = "Error";
      }
      if ($separated_win_log_type_source eq "APP_BB_ROUTER")
      {
        $ev_logfile = "Application";
        $ev_source = "BlackBerry Router";
        $ev_sev = "Error";
      }
#END################################################################################APPLICATION LOFGILE EVENTS
      #print "FS: $fs_def\n";
      #Separates alert definitions
      $alert_def = $2;
      #print "$alert_def\n";
      #Split alert definitions and writes them into array
      @array_of_alert_def = split /;/, $alert_def;
      #Loops through fs alert definitions
      foreach my $alert_def_line (@array_of_alert_def)
      {
        #Separates alert definition into severity, event_id
        $alert_def_line =~ m/(\w{2})(\d+)/;
        chomp($separated_severity_def = $1);
        chomp($separated_event_id_def =$2);
        $ev_name = "EventId_$separated_event_id_def";
        if ($separated_event_id_def eq "111111")
        {
          $ev_sev = "Warning";
          $separated_event_id_def = "*";
          $ev_name = "EventId_allWarning";
        }
        if ($separated_event_id_def eq "222222")
        {
          $ev_sev = "Error";
          $separated_event_id_def = "*";
          $ev_name = "EventId_allError";
        }

        #Translate severity code into severity used by df_mon
        if($separated_severity_def eq "cr")
        {
          $separated_severity_def = "Critical";
        }
        if($separated_severity_def eq "ma")
        {
          $separated_severity_def = "Major\t";
        }
        if($separated_severity_def eq "mi")
        {
          $separated_severity_def = "Minor\t";
        }
        if($separated_severity_def eq "wa")
        {
          $separated_severity_def = "Warning";
        }
        #df_mon alert syntax line
        #“c:” Warning 5 500 MB NT 0-6 0700 2200
        #/home/userx 50Mb - 0800-1700 *
        #print "$fs_def $separated_severity_def $separated_threshold_def $separated_threshold_currency\n";
        if ($node_os eq "win")
        {
          $separated_win_log_type_source = "\"$ev_name\"\t\"+\"\t\"$ev_logfile\"\t\"$ev_source\"\t\"*\"\t\"*\"\t$separated_event_id_def\t$ev_sev\t*\t0000\t2400\t$separated_severity_def\tTT\t$ev_action\n" if (defined $opts{v});
          print "$separated_win_log_type_source\n";
          print WRITE_EVENT_MON $separated_win_log_type_source;
        }
      }
      #print Dumper @array_of_alert_def;
    }
    $array_index_counter++;
  }
  print "------------------------------------------------------------------------------\n" if (defined $opts{v});
  print WRITE_EVENT_MON "#******************************************************************************\n";
  print WRITE_EVENT_MON "#\tend of event_mon.cfg\t\n";
  print WRITE_EVENT_MON "#******************************************************************************\n";
  close(WRITE_EVENT_MON);
  if ($deploy_flag eq "1")
  {
    print "Testing port 383 SSL communication to node ...";
    $ssl_to_node_result = testOvdeploy_HpomToNode_SSL($node_name, "3000", $date_and_time, $script_log_file_path);
    print "\n" if ($verbose_flag eq "1");
    print "\rTesting port 383 SSL communication to node ... FAILED!\n" if ($ssl_to_node_result eq "1");
    if ($ssl_to_node_result eq "0")
    {
      print "\rTesting port 383 SSL communication to node ... OK!\n" ;
      print "Checking if prefered path exists within node ...";
      $check_nodes_prefered_path = check_nodes_prefered_path($date_and_time, $script_log_file_path, $node_name, $node_os, $cfg_prefered_path, $verbose_flag);
      print "\n" if ($verbose_flag eq "1");
      #If prefered path exists within managed node
      if ($check_nodes_prefered_path eq "0")
      {
        print "\rChecking if prefered path exists within node ... FOUND\n";
        print "Checking if a previous df_mon.cfg exists in prefered path ...";
        $event_mon_cfg_exists_in_path = file_existance_in_path($date_and_time, $script_log_file_path, $node_name, $node_os, $cfg_prefered_path, "event_mon.cfg", $verbose_flag);
        print "\n" if ($verbose_flag eq "1");
        if ($event_mon_cfg_exists_in_path eq "0")
        {
          print "\rChecking if a previous event_mon.cfg exists in prefered path ... FOUND!\n";
          print "Backing backup of event_mon.cfg ...\n";
          rename_file_routine($date_and_time, $script_log_file_path, $cfg_prefered_path, $cfg_prefered_path, "event_mon.cfg",  $node_name, $node_os, $verbose_flag);
          print "Renaming file for upload routine...\n";
          system("mv $event_mon_cfg_filename $event_mon_cfg_dir\/event_mon.cfg");
          print "Deploying event_mon.cfg to node ...\n";
          upload_mon_file($date_and_time, $script_log_file_path, $node_name, "event_mon.cfg", $event_mon_cfg_dir, $cfg_prefered_path, $verbose_flag, "3000");
          print "Deployment completed!\n";
          system("rm -f $event_mon_cfg_filename\/event_mon.cfg");
        }
        if ($event_mon_cfg_exists_in_path eq "1")
        {
          print "\rChecking if a previous df_mon.cfg exists in prefered path ... NOT FOUND!\n";
          print "Renaming file for upload routine...\n";
          system("mv $event_mon_cfg_filename $event_mon_cfg_dir\/event_mon.cfg");
          print "Deploying event_mon.cfg to node ...\n";
          upload_mon_file($date_and_time, $script_log_file_path, $node_name, "event_mon.cfg", $event_mon_cfg_dir, $cfg_prefered_path, $verbose_flag, "3000");
          print "Deployment completed!\n";
          system("rm -f $event_mon_cfg_filename\/event_mon.cfg");
        }
      }
      #If does not exists create it
      if ($check_nodes_prefered_path eq "1")
      {
          print "\rChecking prefered path exists within node ... NOT FOUND\n";
          print "Creating $cfg_prefered_path directory ...\n";
          create_dir_routine($date_and_time, $script_log_file_path, $cfg_prefered_path, $node_name, $node_os, $verbose_flag);
          print "Renaming file for upload routine...\n";
          system("mv $event_mon_cfg_filename $event_mon_cfg_dir\/df_mon.cfg");
          print "Deploying event_mon.cfg to node ...\n";
          upload_mon_file($date_and_time, $script_log_file_path, $node_name, "event_mon.cfg", $event_mon_cfg_dir, $cfg_prefered_path, $verbose_flag, "3000");
          print "Deployment completed!\n";
          system("rm -f $event_mon_cfg_filename\/event_mon.cfg");
      }
    }
  }
}

sub srv_mon_deploy
{
  my ($node_name, $srv_mon_cfg_dir,$deploy_flag, $date_and_time, $script_log_file_path, $verbose_flag) = @_;
  #Dereference array and extracts node name
  my $srv_mon_cfg_filename = $srv_mon_cfg_dir."/"."srv_mon.cfg";
  my $cfg_prefered_path = 'c:\osit\etc';
  my $check_nodes_prefered_path;
  my $srv_mon_cfg_exists_in_path;
  my $node_os;
  my $ssl_to_node_result;
  my @check_node_in_HPOM = check_node_in_HPOM($node_name);

  if ($check_node_in_HPOM[0] eq "1")
  {
    #print "Node was FOUND!\n";
    if ($check_node_in_HPOM[3] =~ m/MACH_BBC_WIN/)
    {
      $node_os = "win";
    }
    else
    {
      #OS node supported
      return 2;
    }
  }
  else
  {
    #print "Node was NOT FOUND!\n";
    #Node not found within HPOM
    return 1;
  }
  #If node is win
  if ($node_os eq "win")
  {
    $cfg_prefered_path = 'c:\osit\etc';
    #print "$dfmon_cfg_prefered_path\n";
  }
  print "\nNodename: $node_name \nOS: $node_os\n" if (defined $opts{v});
  print "CFG filename: $srv_mon_cfg_filename\n" if (defined $opts{v});
  if ($deploy_flag eq "1")
  {
    print "Testing port 383 SSL communication to node ...";
    $ssl_to_node_result = testOvdeploy_HpomToNode_SSL($node_name, "3000", $date_and_time, $script_log_file_path);
    print "\n" if ($verbose_flag eq "1");
    print "\rTesting port 383 SSL communication to node ... FAILED!\n" if ($ssl_to_node_result eq "1");
    if ($ssl_to_node_result eq "0")
    {
      print "\rTesting port 383 SSL communication to node ... OK!\n" ;
      print "Checking if prefered path exists within node ...";
      $check_nodes_prefered_path = check_nodes_prefered_path($date_and_time, $script_log_file_path, $node_name, $node_os, $cfg_prefered_path, $verbose_flag);
      print "\n" if ($verbose_flag eq "1");
      #If prefered path exists within managed node
      if ($check_nodes_prefered_path eq "0")
      {
        print "\rChecking if prefered path exists within node ... FOUND\n";
        print "Checking if a previous srv_mon.cfg exists in prefered path ...";
        $srv_mon_cfg_exists_in_path = file_existance_in_path($date_and_time, $script_log_file_path, $node_name, $node_os, $cfg_prefered_path, "srv_mon.cfg", $verbose_flag);
        print "\n" if ($verbose_flag eq "1");
        if ($srv_mon_cfg_exists_in_path eq "0")
        {
          print "\rChecking if a previous srv_mon.cfg exists in prefered path ... FOUND!\n";
          print "Backing backup of srv_mon.cfg ...\n";
          rename_file_routine($date_and_time, $script_log_file_path, $cfg_prefered_path, $cfg_prefered_path, "srv_mon.cfg",  $node_name, $node_os, $verbose_flag);
          print "Deploying srv_mon.cfg to node ...\n";
          upload_mon_file($date_and_time, $script_log_file_path, $node_name, "srv_mon.cfg", $srv_mon_cfg_dir, $cfg_prefered_path, $verbose_flag, "3000");
          print "Deployment completed!\n";
        }
        if ($srv_mon_cfg_exists_in_path eq "1")
        {
          print "\rChecking if a previous srv_mon.cfg exists in prefered path ... NOT FOUND!\n";
          print "Deploying srv_mon.cfg to node ...\n";
          upload_mon_file($date_and_time, $script_log_file_path, $node_name, "srv_mon.cfg", $srv_mon_cfg_dir, $cfg_prefered_path, $verbose_flag, "3000");
          print "Deployment completed!\n";
        }
      }
      #If does not exists create it
      if ($check_nodes_prefered_path eq "1")
      {
          print "\rChecking prefered path exists within node ... NOT FOUND\n";
          print "Creating $cfg_prefered_path directory ...\n";
          create_dir_routine($date_and_time, $script_log_file_path, $cfg_prefered_path, $node_name, $node_os, $verbose_flag);
          print "Deploying srv_mon.cfg to node ...\n";
          upload_mon_file($date_and_time, $script_log_file_path, $node_name, "srv_mon.cfg", $srv_mon_cfg_dir, $cfg_prefered_path, $verbose_flag, "3000");
          print "Deployment completed!\n";
      }
    }
  }
}

#v1.1: removed log of errors within sub to just use return codes
#Sub that test communication from HPOM to managed node
#Parms:   $node_name:               managed node FQDN (or alias)
#         $cmdtimeout:              miliseconds to determine managed node is not reacheable
#         $date_and_time:           actual timestamp
#         $script_logfile:          string to be logged into log file
#Return:  0                         if communication ok
#         1                         if communication failed
sub testOvdeploy_HpomToNode_SSL_v1
{
  my ($node_name, $cmdtimeout) = @_;
	chomp(my $HPOM_ip = `hostname`);
	my $eServiceOK_found = "";
	my @remote_bbcutil_ping_node_ssl = qx{ovdeploy -cmd bbcutil -par \"-ping https://$node_name\" -host $HPOM_ip -cmd_timeout $cmdtimeout};
	my @remote_bbcutil_ping_node_ssl_edited = ();
	foreach my $bbcutil_line_out_ssl (@remote_bbcutil_ping_node_ssl)
	{
		chomp($bbcutil_line_out_ssl);
		if ($bbcutil_line_out_ssl =~ m/eServiceOK/)
		{
			return 0;
		}
		if ($bbcutil_line_out_ssl =~ m/^ERROR:/)
		{
      return 1;
		}
	}
}

#v1.1: removed log of errors within sub to just use return codes
#      removed $file_exists_in_path as return var
#Sub to check the existance of a file within the OS fs
#Parms:   $logfilename_with_path
#         $date_and_time
#         $os_family:   windows|unix
#         $file_path:   path of file to verify
#         $file_name:   name of file to verify
#         $debug_flag   to get debug output
#Return:  $file_exists_in_path:   0 --> file exists in path
#                                 1 --> file does not exists in path
sub file_existance_in_path_v1
{
  my ($node_name, $node_os, $file_path, $file_name) = @_;
  my @check_file_cmd = ();
  my $check_file_cmd_line = '';
  my $file_exists_in_path = 1;

  @check_file_cmd = qx{ovdeploy -cmd if -par \"[ -f $file_path"/"$file_name ]; then echo FOUND $file_name !;else echo NOT_FOUND $file_name;fi\" -host $node_name} if ($node_os =~ m/UNIX/i);
  @check_file_cmd = qx{ovdeploy -cmd if -par \"exist $file_path\\$file_name (echo FOUND $file_name) else (echo NOT_FOUND $file_name)\" -host $node_name} if ($node_os =~ m/WIN/i);
  #@check_file_cmd = qx{ovdeploy -cmd ls -par \"-l $file_path"/"$file_name\" -host $node_name} if ($os_family eq "unix");
  #@check_file_cmd = qx{ovdeploy -cmd dir -par "$file_path'\\'$file_name" -host $node_name} if ($os_family eq "win");

  foreach $check_file_cmd_line (@check_file_cmd)
  {
    chomp($check_file_cmd_line);
    #print "\n--> $check_file_cmd_line" if ($verbose_flag eq "1");
    #print "$check_file_cmd_line";
    if ($check_file_cmd_line =~ m/^FOUND/)
    #if ($check_file_cmd_line =~ m/.*$file_name$/)
    {
      #print "$check_file_cmd_line\n";
      #$file_exists_in_path = 0;
      #last;
      return 0;
    }
  }
  return 1;
  #return $file_exists_in_path;
}

# Sub that checks if the monitoring solutions prefered path exists
# Parms:      $date_time
#             $logfilename_with_path
#             $node_name
#             $node_os
#             $dir_path
#             $verbose_flag
sub check_nodes_prefered_path
{
  chomp(my $date_time = shift);
  chomp(my $logfilename_with_path = shift);
  chomp(my $node_name = shift);
  chomp(my $node_os = shift);
  chomp(my $dir_path = shift);
  chomp(my $verbose_flag = shift);
  my @check_dir_cmd = ();
  my $dir_exists = "0";

  @check_dir_cmd = qx{ovdeploy -cmd if -par \"[ -d $dir_path ]; then echo FOUND $dir_path;else echo NOT_FOUND $dir_path;fi\" -host $node_name} if ($node_os eq "unix");
  @check_dir_cmd = qx{ovdeploy -cmd if -par \"exist $dir_path (echo FOUND $dir_path) else (echo NOT_FOUND $dir_path)\" -host $node_name} if ($node_os eq "win");

  foreach my $check_dir_cmd_line (@check_dir_cmd)
  {
    chomp($check_dir_cmd_line);
    print "--> $check_dir_cmd_line\n" if ($verbose_flag eq "1");
    #print "$check_file_cmd_line";
    if ($check_dir_cmd_line =~ m/^NOT_FOUND/)
    {
      #print "$check_file_cmd_line\n";
      script_logger($date_time, $logfilename_with_path, "$node_name\:\:check_nodes_prefered_path\(\)::Information::$dir_path NOT FOUND!");
      $dir_exists = '1';
      last;
    }
    if ($check_dir_cmd_line =~ m/\s+/)
    {
      last;
    }
  }
  script_logger($date_time, $logfilename_with_path, "$node_name\:\:check_nodes_prefered_path\(\)::Information::$dir_path FOUND!") if ($dir_exists eq "0");
  return $dir_exists;
}

#Sub that log entries into mongodb_mon.log
#Parms:   $date_and_time:   when entry was added
#         $logfilename_with_path:   logfile with path where entry will be logged
#         $entry_to_log:            String to be logged into log file
#Return:  None
sub script_logger
{
  chomp(my $date_and_time = shift);
  chomp(my $logfilename_with_path = shift);
  chomp(my $entry_to_log = shift);
  open (MYFILE, ">> $logfilename_with_path")
   or die("File not found: $logfilename_with_path");
  print MYFILE "$date_and_time\:\:$entry_to_log\n";
  close (MYFILE);
}

#Sub that log entries into mongodb_mon.log
#Parms:   $logfilename_with_path:   logfile with path where entry will be logged
#          $filename_path_one:       Original target filename + path
#         $filename_path_two:       Backup target filename + path
#         $nodename:                Nodename
#         $node_os:                 Nodes OS
#Return:  None
sub rename_file_routine
{
  chomp(my $date_time = shift);
  chomp(my $logfilename_with_path = shift);
  chomp(my $file_path_one = shift);
	chomp(my $file_path_two = shift);
  chomp(my $filename = shift);
  chomp(my $nodename = shift);
  chomp(my $node_os = shift);
  chomp(my $verbose_flag = shift);
  my @rename_cmd = ();
  #print "$node_os\n";
  my $return_code = "0";
  if ($node_os eq "win")
  {
      $file_path_two =~ m/(.*\\)([\w\.]+)/;
      $file_path_two = $1;
  }
  #print "--> ovdeploy -cmd \'rename \"$file_path_one\\$filename\" \"$filename.$date_time.mcfgc\"\' -node $nodename\n" if ($verbose_flag eq "1");
  @rename_cmd = qx{ovdeploy -cmd \'rename \"$file_path_one\\$filename\" \"$filename.$date_time.mcfgc\"\' -node $nodename} if ($node_os eq "win");
  @rename_cmd = qx{ovdeploy -cmd \'mv \"$file_path_one\/$filename\" \"$file_path_two\/$filename.$date_time.mcfgc\"\' -node $nodename}   if ($node_os eq "unix");
  foreach my $rename_cmd_line (@rename_cmd)
  {
    chomp($rename_cmd_line);
    if ($rename_cmd_line eq "")
    {
      last;
    }
    else
    {
      print "--> $rename_cmd_line\n" if ($verbose_flag eq "1");
    }
  }
	if ($? ne "0")
	{
  	script_logger($date_time, $logfilename_with_path, "$nodename\:\:rename_file_routine\(\)::Error::Problems while renaming file $filename within path $file_path_one!");
    return 1;
  }
	else
	{
    return 0;
	}
}

#Sub that upload mon file to node
#Arguments:
#$date_time
#$logfilename_with_path
#$mon_filename
#$mon_file_sd
#$mon_file_td
#$nodename
#
sub upload_mon_file
{
  chomp(my $date_time = shift);
  chomp(my $logfilename_with_path = shift);
  chomp(my $nodename = shift);
	chomp(my $mon_filename = shift);
	chomp(my $mon_file_sd = shift);
	chomp(my $mon_file_td = shift);
  chomp(my $verbose_flag = shift);
  chomp(my $timeout = shift);
  chomp(my $HPOM_ip = `hostname`);
	my @upload_cmd = qx{ovdeploy -cmd \"ovdeploy -upload -file $mon_filename -sd $mon_file_sd -td \'$mon_file_td\' -node $nodename\" -node $HPOM_ip -cmd_timeout $timeout};
  foreach my $upload_cmd_line (@upload_cmd)
  {
    chomp($upload_cmd_line);
    print "--> $upload_cmd_line\n" if ($verbose_flag eq "1");
  }
	if ($? eq "0")
	{
    return 0;
	}
	else
	{
		script_logger($date_time, $logfilename_with_path, "$nodename\:\:upload_mon_file\(\)::Error::Problems while uploading file $mon_filename to directory $mon_file_td!");
		return 1;
	}
}

#Sub that creates a new directory within a managed node
#Parms:
#
#
#
#
#Return:  None
sub create_dir_routine
{
  chomp(my $date_time = shift);
  chomp(my $logfilename_with_path = shift);
  chomp(my $dir_to_create = shift);
  chomp(my $nodename = shift);
  chomp(my $node_os = shift);
  chomp(my $verbose_flag = shift);
  my @create_dir_cmd = ();
  #print "$node_os\n";
  my $return_code = "0";
  @create_dir_cmd = qx{ovdeploy -cmd \'mkdir \"$dir_to_create\"\' -node $nodename} if ($node_os eq "win");
  @create_dir_cmd = qx{ovdeploy -cmd \'mkdir -p \"$dir_to_create\"\' -node $nodename} if ($node_os eq "unix");
  foreach my $create_dir_cmd_line (@create_dir_cmd)
  {
    chomp($create_dir_cmd_line);
    print "--> $create_dir_cmd_line\n" if ($verbose_flag eq "1");
  }
  if ($? ne "0")
	{
  	script_logger($date_time, $logfilename_with_path, "$nodename\:\:rename_file_routine\(\)::Error::Problems while creating directory $dir_to_create!");
    return 1;
  }
	else
	{
    return 0;
	}
}

######################################################################
# Sub that checks if a managed node is within a HPOM and if found determine its ip_address, node_net_type, mach_type
#	@Parms:
#		$nodename : Nodename to check
#	Return:
#		@node_mach_type_ip_addr = (node_exists, node_ip_address, node_net_type, node_mach_type, comm_type)	:
#															[0|1],
#															[<ip_addr>],
#															[NETWORK_NO_NODE|NETWORK_IP|NETWORK_OTHER|NETWORK_UNKNOWN|PATTERN_IP_ADDR|PATTERN_IP_NAME|PATTERN_OTHER],
#															[MACH_BBC_LX26|MACH_BBC_SOL|MACH_BBC_HPUX|MACH_BBC_AIX|MACH_BBC_WIN|MACH_BBC_OTHER],
#                             [COMM_UNSPEC_COMM|COMM_BBC]
#		$node_mach_type_ip_addr[0] = 0: If nodename is not found within HPOM
#   $node_mach_type_ip_addr[0] = 1: If nodename is found within HPOM
######################################################################
sub check_node_in_HPOM
{
  my $nodename = shift;
	my $nodename_exists = 0;
	my @node_mach_type_ip_addr = ();
	my ($node_ip_address, $node_mach_type, $node_net_type, $node_comm_type) = ("", "", "", "");
	my @opcnode_out = qx{opcnode -list_nodes node_list=$nodename};
	foreach my $opnode_line_out (@opcnode_out)
	{
		chomp($opnode_line_out);
		if ($opnode_line_out =~ /^Name/)
		{
			$nodename_exists = 1;					# change to 0 if node is found
      push (@node_mach_type_ip_addr, $nodename_exists);
		}
		if ($opnode_line_out =~ m/IP-Address/)
		{
			$opnode_line_out =~ m/.*=\s(.*)/;
			$node_ip_address = $1;
			chomp($node_ip_address);
			push (@node_mach_type_ip_addr, $node_ip_address);
		}
		if ($opnode_line_out =~ m/Network\s+Type/)
		{
			$opnode_line_out =~ m/.*=\s(.*)/;
			$node_net_type = $1;
			chomp($node_net_type);
			push (@node_mach_type_ip_addr, $node_net_type);
		}
		if ($opnode_line_out =~ m/MACH_BBC_LX26|MACH_BBC_SOL|MACH_BBC_HPUX|MACH_BBC_AIX|MACH_BBC_WIN|MACH_BBC_OTHER/)
		{
			$opnode_line_out =~ m/.*=\s(.*)/;
			$node_mach_type = $1;
			chomp($node_mach_type);
			push (@node_mach_type_ip_addr, $node_mach_type);
		}
    if ($opnode_line_out =~ m/Comm\s+Type/)
    {
      $opnode_line_out =~ m/.*=\s(.*)/;
			$node_comm_type = $1;
			chomp($node_comm_type);
			push (@node_mach_type_ip_addr, $node_comm_type);
    }
	}
	# Nodename not found
	if ($nodename_exists eq 0)
	{
		$node_mach_type_ip_addr[0] = 0;
	}
  return @node_mach_type_ip_addr;
}

######################################################################
#Sub that creates xxx_mon.cfg soft link to be used by script
#@Parms:
# @mon_cfgs_files:        Array with path+filename to xxx_mon.cfg
# $cfg_template_dir:      Location where soft links should be created
#
#Exit codes:
# 0                       No errors
# 1                       If sctipt cannot find a baseline cfg
# 2                       If script cannot create a soft link for a cfg
######################################################################
sub create_soft_link_cfgs
{
  my ($ref_mon_cfgs_files, $base_script_var_path) = @_;
  my $script_template_dir = $base_script_var_path."/templates";
  my @dref_baseline_mon_cfgs_location = @{$ref_mon_cfgs_files};
  #Create soft links of xxx_mon.cfg within script template path
  foreach my $r_dref_baseline_mon_cfgs_location (@dref_baseline_mon_cfgs_location)
  {
    #if cfg cannot be found
    if (!-f $r_dref_baseline_mon_cfgs_location)
    {
      print "Script cannot find baseline cfg file:\n$r_dref_baseline_mon_cfgs_location\n";
      print "Contact the HPOM admin to fix it. Then run script again!!!\n\n";
      exit 1;
    }
    else
    {
      #if cfg is for wintel os
      if ($r_dref_baseline_mon_cfgs_location =~ m/.*\/ms\/.*\/(.*_mon.cfg)/)
      {
        chomp(my $cfg_file = $1);
        system("ls -l $script_template_dir/$cfg_file.win > /dev/null 2>&1");
        #create soft link
        if ($? ne "0")
        {
          print "Creating symbolic link for $cfg_file...\n";
          system("ln -s $r_dref_baseline_mon_cfgs_location $script_template_dir/$cfg_file.win > /dev/null 2>&1");
          #if error presented while creating soft link
          if ($? ne "0")
          {
            print "Error while creating symbolic link for $cfg_file!!!\n";
            print "Script cannot continue. Please check with mruizm\@hpe.com\n\n";
            exit 2;
          }
          else
          {
            print "Created symbolic link for $cfg_file!!!\n";
          }
        }
      }
      #if cfg is for unix-like os
      if ($r_dref_baseline_mon_cfgs_location =~ m/.*\/linux\/.*\/(.*_mon.cfg)/)
      {
        chomp(my $cfg_file = $1);
        system("ls -l $script_template_dir/$cfg_file.unix > /dev/null 2>&1");
        #create soft link
        if ($? ne "0")
        {
          print "Creating symbolic link for $cfg_file...\n";
          system("ln -s $r_dref_baseline_mon_cfgs_location $script_template_dir/$cfg_file.unix > /dev/null 2>&1");
          #if error presented while creating soft link
          if ($? ne "0")
          {
            print "Error while creating symbolic link for $cfg_file!!!\n";
            print "Script cannot continue. Please check with mruizm\@hpe.com\n\n";
            exit 2;
          }
          else
          {
            print "Created symbolic link for $cfg_file!!!\n";
          }
        }
      }
    }
  }
  return 0;
}

######################################################################
#Sub that creates initial dirs for script usage
#@Parms:
# @ref_mon_modules            :array with name of mon modules
# $base_script_path       :base script path
#
#Exit codes:
# 0                       No errors
# 1                       If sctipt cannot find a baseline cfg
# 2                       If script cannot create a soft link for a cfg
######################################################################
sub create_script_dirs
{
  my ($ref_mon_modules, $base_script_var_path) = @_;
  my @dref_mon_modules = @{$ref_mon_modules};

  #To check dir where cfg template files will be holded
  system("mkdir -p $base_script_var_path/templates > /dev/null 2>&1") if (!-d "$base_script_var_path/templates/");
  if ($? ne "0")
  {
    print "Cannot create dir \'$base_script_var_path.'/templates/'\'\n";
    print "Script cannot continue. Please check with mruizm\@hpe.com\n\n";
    exit 1;
  }
  #Loop through availble script mon modules and create script dir if needed
  foreach my $r_dref_mon_modules (@dref_mon_modules)
  {
    #To check cfg dir
    system("mkdir -p $base_script_var_path/cfg/$r_dref_mon_modules > /dev/null 2>&1") if (!-d "$base_script_var_path/cfg/$r_dref_mon_modules");
    if ($? ne "0")
    {
      print "Cannot create dir \'$base_script_var_path/cfg/$r_dref_mon_modules\'\n";
      print "Script cannot continue. Please check with mruizm\@hpe.com\n\n";
      exit 1;
    }
    #To check tmp dir
    system("mkdir -p $base_script_var_path/tmp/$r_dref_mon_modules > /dev/null 2>&1") if (!-d "$base_script_var_path/tmp/$r_dref_mon_modules");
    if ($? ne "0")
    {
      print "Cannot create dir \'$base_script_var_path/cfg/$r_dref_mon_modules\'\n";
      print "Script cannot continue. Please check with mruizm\@hpe.com\n\n";
      exit 1;
    }
    #To check log dir
    system("mkdir -p $base_script_var_path/log/$r_dref_mon_modules > /dev/null 2>&1") if (!-d "$base_script_var_path/log/$r_dref_mon_modules");
    if ($? ne "0")
    {
      print "Cannot create dir \'$base_script_var_path/cfg/$r_dref_mon_modules\'\n";
      print "Script cannot continue. Please check with mruizm\@hpe.com\n\n";
      exit 1;
    }
  }
  return 0;
}

######################################################################
#Sub that parses csv input line for mon module and separates it into global_cfg_vars
#variables and thresholds
#@Parms:
# $in_csv_mon_line:         csv input line format:    <node_name>,WIN|UNIX,<global_cfg_vars>,<mon_cfg_threshold_line>,EOL
#   if no need to set cfg global variables <global_cfg_vars>, type NA as field value
#
#Return:
# %hash_csv_cfg_values
# keys:
#   csv_parse_return:   NOK_A global pattern mis-match
#                       NOK_GV  global variables mis-match
#                       NOK_THR threshold values mis-match#
#   node_name
#   node_os
#   cfg_global_vars_val
#   cfg_threshold_val
#
######################################################################
sub parse_csv_mon_line_to_gvars_thresholds
{
  my ($in_csv_mon_line) = @_;
  my $node_name = '';
  my $node_os_type = '';
  my $mon_cfg_global_vars = '';
  my $mon_cfg_threshold_line = '';
  my %hash_csv_cfg_values = ();
  chomp($in_csv_mon_line);
  #If csv entry does not matches global pattern
  #When using for df_mon, escape * (\*) to define * FS wildcard
  if ($in_csv_mon_line !~ m/(.*),(WIN|UNIX),((?:[\w=\"\w\*\",]|(?R))*),(\[?.*\]?),EOL/)
  {
    $hash_csv_cfg_values{csv_parse_return} = "NOK_A:<$in_csv_mon_line>";
    return %hash_csv_cfg_values;
  }
  #sepatates csv into node_name, node_os_type, mon_cfg_global_vars, mon_cfg_threshold_values
  #Use 'NA' if no cfg mon global variables needed
  #Ex:
  #tkpaidc01.transbank.local,WIN,AUTO_SRV_RESTART=NO,AUTO_SRV_MODE="NO",AUTO_SRV_EXP_L="Smartcard*",[ORA,ORA,ORA],"oracle.exe",cr31,s0000-2400:0,1,2,3,4,5,6s,[HPOM,HPOM],"ovcd.exe",cr31,EOL
  $in_csv_mon_line =~ m/(.*),(WIN|UNIX),((?:[\w=\"\w\*\",]|(?R))*),(\[?.*\]?),EOL/;
  chomp($node_name = $1);
  chomp($node_os_type = $2);
  chomp($mon_cfg_global_vars = $3);
  chomp($mon_cfg_threshold_line = $4);

  #Checks syntax of mon cfg global variables
  #Ex:
  #AUTO_SRV_RESTART=NO,AUTO_SRV_MODE="NO",AUTO_SRV_EXP_L="Smartcard*"
  #Use 'NA' if no cfg mon global variables needed
  if ($mon_cfg_global_vars !~ m/(\w+=\"?[\w\*]+\"?,?(?R)?|NA)/)
  {
    $hash_csv_cfg_values{csv_parse_return} = "NOK_GV:<$mon_cfg_global_vars>";
    return %hash_csv_cfg_values;
  }
  # Checks syntax of mon cfg threshold lines
  #Ex:
  #"oracle.exe",cr31,"ovcd.exe",cr31,"oracle2.exe",cr11,[OS],"ovcd.exe",cr31
  #"\*",cr31-Mb,"C:\",cr90-%,ma80-%,[OS]
  #"/var/opt",cr31-Mb,"/opt/OV",cr90-%,ma80-%,s0000-2400:0,1,2,3,4,5,6s[OS],"/tmp"

  #When using for perf_mon, instance separated by '-': "GBL_CPU_TOTAL_UTIL-NONE"
  if($mon_cfg_threshold_line !~ m/(?:[.*\]?),?\"[\w\-\/\*\\\.?]+\",(?:cr|ma|mi|wa)\d+-?[\W|\d|\w]+(?R)?)/)
  #if($mon_cfg_threshold_line !~ m/(\"[\w\-\/\*\\\.?]+\",(?:cr|ma|mi|wa)\d+-?[\W|\d|\w]+(?R)?)/)
  {
    $hash_csv_cfg_values{csv_parse_return} = "NOK_THR:<$mon_cfg_threshold_line>";
    return %hash_csv_cfg_values;
  }
  $hash_csv_cfg_values{csv_parse_return} = 'OK';
  $hash_csv_cfg_values{node_name} = $node_name;
  $hash_csv_cfg_values{node_os} = $node_os_type;
  $hash_csv_cfg_values{cfg_global_vars_val} = $mon_cfg_global_vars;
  $hash_csv_cfg_values{cfg_threshold_val} = $mon_cfg_threshold_line;
  return %hash_csv_cfg_values;
}

######################################################################
#Sub that processes the hash returned with global vars and thresholds separated
#@Parms:
# %hash_csv_separated       :hash with keys cfg_global_vars_val/cfg_threshold_val
# $mon_module               :mon module to make processing of hash to cfg lines
# $base_script_var_path     :base path of script
# $use_existing_cfg         :define is use new or existing cfg as base file
#
#Return:
#
######################################################################
sub process_hash_to_cfg_lines
{
  my ($ref_hash_csv_separated, $mon_module, $base_script_var_path, $use_existing_cfg) = @_;
  my %dref_hash_csv_separated = %{$ref_hash_csv_separated};
  my $r_mon_cfg_creator;
  my $node_name = $dref_hash_csv_separated{node_name};
  my $node_os = $dref_hash_csv_separated{node_os};
  my $cfg_threshold_val = $dref_hash_csv_separated{cfg_threshold_val};
  my $cfg_global_vars_val = $dref_hash_csv_separated{cfg_global_vars_val};
  #print "process_hash_to_cfg_lines():$node_name:$node_os:$cfg_global_vars_val:$cfg_threshold_val\n";
  if ($mon_module eq "test_srv_mon")
  {
    #print "exec:srv_mon_cfg_creator()\n";
    $r_mon_cfg_creator = mon_cfg_creator($mon_module, $node_name, $node_os, $cfg_global_vars_val, $cfg_threshold_val, $base_script_var_path, $use_existing_cfg);
    #print "srv_mon_cfg_creator():$r_mon_cfg_creator\n";
  }
  #print "@r_mon_cfg_creator\n";
  return $r_mon_cfg_creator;

  #if ($node_os eq "unix")
  #{
  #    $dfmon_template_file = $df_mon_template_dir."/"."df_mon.cfg.unix";
  #    $cfg_prefered_path = "/var/opt/OV/conf/OpC";
  #}
  #If node is win
  #if ($node_os eq "win")
  #{
  #  $dfmon_template_file = $df_mon_template_dir."/"."df_mon.cfg.win";
  #  $cfg_prefered_path = 'c:\osit\etc';
    #print "$dfmon_cfg_prefered_path\n";
  #}
  #for my $key (keys %dref_hash_csv_separated)
  #{
  #  my $value = $dref_hash_csv_separated{$key};
  #  print "$key => $value\n";
  #}
}

######################################################################
#Sub that processes scalar with hash keys cfg_global_vars_val/cfg_threshold_val
#and generates srv_mon.cfg file
#@Parms:
# $node_name                   : node_name
# $node_os                     : node_os
# $s_cfg_global_vars_val       :scalar with hash key cfg_global_vars_val value
# $s_cfg_threshold_val         :scalar with hash key $s_cfg_threshold_val value
# $base_script_var_path        : scripts base path
# $use_existing_cfg            : define if use new or existing cfg as base file
#
#Return:
# 1                           :module is not compatible with node OS
# 2                           :node not found within HPOM
# 3                           :ssl comm to node NOK
# 4                           :xxx_mon.cfg not found in prefered path
# 5                           :error while downloading xxx_mon.cfg from node
# 6                           :xxx_mon.cfg not found in HPOM download path /var/opt/OpC_local/MON_CFG_CREATOR/tmp/
# 7                           :mismatch between node OS in csv line and one within in HPOM db
# 8                           :node is not an OS based server (MACH_BBC_OTHER)
# $mon_cfg_file_location      :path where xxx_mon.cfg was created
######################################################################
# MACH_BBC_LX26|MACH_BBC_SOL|MACH_BBC_HPUX|MACH_BBC_AIX|MACH_BBC_WIN|MACH_BBC_OTHER [3]
sub mon_cfg_creator
{
  my ($mon_module, $node_name, $node_os, $s_cfg_global_vars_val, $s_cfg_threshold_val, $base_script_var_path, $use_existing_cfg) = @_;
  my $timeout = "3000";
  #my $r_mon_cfg_creator = 0;
  my $file_path = "C:\\osit\\etc";
  $file_path = "/var/opt/OV/conf/OpC" if ($node_os !~ m/WIN/i);
  my %hash_mon_global_vars = ();
  if ($mon_module =~ m/test_srv_mon/)
  {
    $mon_module =~ s/test_srv_mon/srv_mon/;
    if ($node_os !~ m/WIN/i)
    {
      return 1;
    }
    %hash_mon_global_vars = (
                                  AUTO_S_EXP_L => "AUTOMATIC_SERVICES_MONITORING_EXCEPTION_LIST",
                                  AUTO_S_RSTART => "AUTOMATIC_SERVICES_RESTART_TRIAL",
                                  AUTO_S_RSTART_EXP_L => "AUTOMATIC_SERVICES_RESTART_EXCEPTION_LIST",
                                  );
  }
  my $mon_file = $mon_module.".cfg";
  my $base_mon_cfg_input_file = $base_script_var_path."/templates/".$mon_module.".cfg.".lc($node_os);
  my $mon_download_path = $base_script_var_path."/tmp/".$mon_module;
  system("rm -f $mon_download_path/* > /dev/null 2>&1");
  my @r_check_node_in_HPOM = check_node_in_HPOM($node_name);
  #node not found within HPOM
  if ($r_check_node_in_HPOM[0] == 0)
  {
    return 2;
    #$splitted_g_vars[1] = $node_name;
  }
  if ((($r_check_node_in_HPOM[3] =~ m/MACH_BBC_LX26|MACH_BBC_SOL|MACH_BBC_HPUX|MACH_BBC_AIX/) && ($node_os =~ /WIN/)) ||
       ($r_check_node_in_HPOM[3] =~ m/MACH_BBC_WIN/ && ($node_os =~ /UNIX/)))
  {
    #mismatch between node OS in csv line and one within in HPOM db
    return 7;
  }
  if ($r_check_node_in_HPOM[3] =~ m/MACH_BBC_OTHER/)
  {
    return 8;
  }
  #test SSL in uses existing cfg is activated
  if ($use_existing_cfg == 1)
  {
    my $r_testOvdeploy_HpomToNode_SSL = testOvdeploy_HpomToNode_SSL_v1($node_name, $timeout);
    #when ssl comm is nok to managed node
    if ($r_testOvdeploy_HpomToNode_SSL == 1)
    {
      return 3;
    }
    #check if xxx_mon.cfg exists in prefered path
    my $r_file_existance_in_path_v1 = file_existance_in_path_v1($node_name, $node_os, $file_path, $mon_file);
    #xxx_mon.cfg not found in prefered path
    if ($r_file_existance_in_path_v1 == 1)
    {
      return 4;
    }
    my $r_download_file_from_node = download_file_from_node($node_name, $node_os, $mon_file, $file_path, $mon_download_path, $timeout);
    #error while downloading srv_mon.cfg from node
    if ($r_download_file_from_node == 1)
    {
      return 5;
    }
    #rename xxx_mon.cfg to xxx_mon.cfg.<nodename>
    system("mv $mon_download_path/$mon_file $mon_download_path/$mon_file.$node_name > /dev/null 2>&1");
    #xxx_mon.cfg not found in HPOM download path /var/opt/OpC_local/MON_CFG_CREATOR/tmp/
    if ($? ne 0)
    {
      return 6
    }
    $base_mon_cfg_input_file = $mon_download_path."/".$mon_file.".".$node_name;
  }
  #print "srv_mon_cfg_creator(vals):<$s_cfg_global_vars_val>:<$s_cfg_threshold_val>\n";
  my @splitted_g_vars = ("NA");

  #start processing global vars and thresholds csv
  print "Processing global vars from file: $base_mon_cfg_input_file\n";
  open(MON_TMPL_FILE, "< $base_mon_cfg_input_file")
    or die "Cannot open file: $base_mon_cfg_input_file";
  #split global vars string into array elements
  if ($s_cfg_global_vars_val !~ m/NA/)
  {
    @splitted_g_vars = split(/,/, $s_cfg_global_vars_val);
  }
  #print "@splitted_g_vars\n";
  #print  "\$r_mon_cfg_creator():$r_mon_cfg_creator\n";
  #return $r_mon_cfg_creator;
  return 0;
}

######################################################################
#Sub that downlaods file from a managed node
#@Parms:
# $node_name                   : node_name
# $node_os                     : node_os
# $source_file_name
# $source_file_path
# $target_save_path
#Return:
# 0                           :file saved to target HPOM dir
# 1                           :error while downloading file from managed node
# 2                           :download executed but file not found within target path in HPOM
######################################################################
sub download_file_from_node
{
  my ($node_name, $node_os, $source_file_name, $source_file_path, $target_save_path, $timeout) = @_;
  #print "download_file_from_node():ovdeploy -cmd \"ovdeploy -download -file $source_file_name -sd \'$source_file_path\' -td $target_save_path -node $node_name\" -ovrg server -cmd_timeout $timeout > /dev/null\n";
  system("ovdeploy -cmd \"ovdeploy -download -file $source_file_name -sd \'$source_file_path\' -td $target_save_path -node $node_name\" -ovrg server -cmd_timeout $timeout > /dev/null 2>&1");
  if ($? eq "0")
  {
    return 0 if(-f $target_save_path."/".$source_file_name);
    return 2;
  }
  return 1;
}
