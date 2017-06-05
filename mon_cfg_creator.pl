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
#           -f <input_file>: define input CSV threshold file
#           -c creates df_mon.cfg file for managed node
#           -d deploy cfg to managed node
#           -m <mon_module>: df_mon|srv_mon|ps_mon|perfmon
#           -v Verbose mode
# Routines:
################################################################################
#dirs to create initially:
# /opt/OpC_local/mon_cfg_creator
# /opt/OpC_local/mon_cfg_creator/cfg/dfmon
# /opt/OpC_local/mon_cfg_creator/templates/dfmon
# /opt/OpC_local/mon_cfg_creator/log/dfmon
# /opt/OpC_local/mon_cfg_creator/cfg/perfmon
# /opt/OpC_local/mon_cfg_creator/templates/perfmon
# /opt/OpC_local/mon_cfg_creator/log/perfmon
#  perl mon_cfg_creator.pl -f hp_sag.csv -m df_mon -d -v
#  perl mon_cfg_creator.pl -f node.lst -m perf_mon -d -v
# /opt/perf/bin/agsysdb -actions always
# ovpa restart alarm
#111111 Warning/222222 Error
#perl mon_cfg_creator.pl -f cma.lst -m event_mon -d -v
use warnings;
use strict;
use Getopt::Std;
use Data::Dumper qw(Dumper);

our %opts = ();
getopts("f:c:m:vd", \%opts) or exit 1;

#Global script variables
my $datetime_stamp = `date "+%m%d%Y_%H%M%S"`;
chomp($datetime_stamp);
my @node_drive_tokens = ();
my @node_drive_tokens_sorted = ();
my @ovdeploy_file_cmd = ();
my $script_path = '/opt/OpC_local/MON_CFG_CREATOR';
my $csv_input_filename = "";
my $modules_to_cfg = "";
my $csv_input_line = "";
my $deploy_flag = "0";
my $verbose_flag = "0";
# Variables for dfmon module
my @array_to_dfmon_cfg = ();
my $script_dfmon_created_cfgs = $script_path."/cfg/dfmon";
my $script_dfmon_template_cfgs = $script_path."/templates/dfmon";
my $script_dfmon_tmp = $script_path."/tmp/dfmon";
my $script_dfmon_log_file_path = $script_path."/log/dfmon/dfmon_cfg_push.log.$datetime_stamp";

# Variables for perfmon module
my @array_to_perfmon_cfg = ();
my $script_perfmon_created_cfgs = $script_path."/cfg/perfmon";
my $script_perfmon_template_cfgs = $script_path."/templates/perfmon";
my $script_perfmon_tmp = $script_path."/tmp/perfmon";
my $script_perfmon_log_file_path = $script_path."/log/perfmon/perfmon_cfg_push.log.$datetime_stamp";

my @array_to_event_mon_cfg = ();
my $script_event_mon_created_cfgs = $script_path."/cfg/event_mon";
my $script_event_mon_template_cfgs = $script_path."/templates/event_mon";
my $script_event_mon_tmp = $script_path."/tmp/event_mon";
my $script_event_mon_log_file_path = $script_path."/log/event_mon/event_mon_cfg_push.log.$datetime_stamp";
#my $r = 0;

# If -f and -m options are not defined
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
if ($modules_to_cfg !~ m/df_mon|perf_mon|event_mon/)
{
  print "Invalid parameter value (\"$modules_to_cfg\") for -m option!\nPlease use one of the parameters: df_mon, perf_mon, event_mon\n\n";
  exit 1;
}
#Open CSV file for reading
open (FSCSV, "< $script_path/$csv_input_filename")
  or die "\nFile $csv_input_filename does not exits in path $script_path/!\n\n";

#Reads CSV file
print "Running mon_cfg_creator v1.0 ...\n";
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
#Read CSV input file line by line
while (<FSCSV>)
{
  #Moves to next line if empty
  if ($_ =~ m/^\s/)
  {
    next;
  }
  #Array that has the elements to create the df_mon.cfg per OS
  if ($modules_to_cfg eq "df_mon")
  {
    @array_to_dfmon_cfg = parse_csv_to_array($_);
    #print Dumper \@array_to_dfmon_cfg;
    chomp($datetime_stamp = `date "+%m%d%Y_%H%M%S"`);
    array_element_to_dfmon_cfg($script_dfmon_template_cfgs, $script_dfmon_created_cfgs, \@array_to_dfmon_cfg, $deploy_flag, $datetime_stamp, $script_dfmon_log_file_path, $verbose_flag);
  }
  if ($modules_to_cfg eq "perf_mon")
  {
    @array_to_perfmon_cfg = parse_csv_to_array($_);
    array_element_to_perfmon_cfg($script_perfmon_template_cfgs, $script_perfmon_created_cfgs, \@array_to_perfmon_cfg, $deploy_flag, $datetime_stamp, $script_perfmon_log_file_path, $verbose_flag);
    #chomp($datetime_stamp = `date "+%m%d%Y_%H%M%S"`);
    #print Dumper \@array_to_perfmon_cfg;
  }
  if ($modules_to_cfg eq "event_mon")
  {
    @array_to_event_mon_cfg = parse_csv_to_array($_);
    ##print Dumper @array_to_eventmon_cfg;
    array_element_to_event_mon_cfg($script_event_mon_template_cfgs, $script_event_mon_created_cfgs, \@array_to_event_mon_cfg, $deploy_flag, $datetime_stamp, $script_event_mon_log_file_path, $verbose_flag)
  }
  local $| = 1;
  #for (my $i = 5; $i >= 0; $i--)
  #{
    #sleep 1;
    #print "\rMoving to next node in $i seconds ...";
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
  my $node_os = "";
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

  #Validate that node exists within HPOM db
  #[MACH_BBC_LX26|MACH_BBC_SOL|MACH_BBC_HPUX|MACH_BBC_AIX|MACH_BBC_WIN]
  my @check_node_in_HPOM = check_node_in_HPOM($node_name);
  if ($check_node_in_HPOM[0] eq "1")
  {
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
    #print "$array_with_dfmon_parms_values\n";
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
      #print "$array_with_dfmon_parms_values\n";
      #Separates fs value
      $separated_win_log_type_source = $1;
      #Condition for "Log-->Application"
      if ($separated_win_log_type_source eq "APP")
      {
        $ev_logfile = "Application";
        $ev_source = "*";
        $ev_sev = "*"
      }
      #Condition for "Log-->System"
      if ($separated_win_log_type_source eq "SYS")
      {
        $ev_logfile = "System";
        $ev_source = "*";
        $ev_sev = "*"
      }
      #Condition for "Log-->System/Source-->FailoverClustering"
      if ($separated_win_log_type_source eq "SYS_CLU")
      {
        $ev_logfile = "System";
        $ev_source = "FailoverClustering";
        $ev_sev = "*"
      }
      #Condition for "Log-->Application/Source-->ActiveDirectory_DomainService"
      if ($separated_win_log_type_source eq "APP_AD")
      {
        $ev_logfile = "Application";
        $ev_source = "ActiveDirectory_DomainService";
        $ev_sev = "*"
      }
      #Condition for "Log-->System/Source-->ActiveDirectory_DomainService"
      if ($separated_win_log_type_source eq "SYS_AD")
      {
        $ev_logfile = "System";
        $ev_source = "ActiveDirectory_DomainService";
        $ev_sev = "*"
      }
      #Condition for "Log-->System/Source-->ActiveDirectory_DomainService"
      if ($separated_win_log_type_source eq "APP_C_AUTH")
      {
        $ev_logfile = "Application";
        $ev_source = "CertificationAuthority";
        $ev_sev = "*"
      }
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
          print $separated_win_log_type_source = "\"$ev_name\"\t\"+\"\t\"$ev_logfile\"\t\"$ev_source\"\t\"*\"\t\"*\"\t$separated_event_id_def\t$ev_sev\t*\t0000\t2400\t$separated_severity_def\tT\t$ev_action\n" if (defined $opts{v});
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

#Sub that test communication from HPOM to managed node
#Parms:   $node_name:               managed node FQDN (or alias)
#         $cmdtimeout:              miliseconds to determine managed node is not reacheable
#         $date_and_time:           actual timestamp
#         $script_logfile:          string to be logged into log file
#Return:  0                         if communication ok
#         1                         if communication failed
sub testOvdeploy_HpomToNode_SSL
{
	chomp(my $node_name = shift);
  chomp(my $cmdtimeout = shift);
  chomp(my $date_and_time = shift);
  chomp(my $logfilename_with_path = shift);
	chomp(my $HPOM_ip = `hostname`);
	my $eServiceOK_found = "";
	my @remote_bbcutil_ping_node_ssl = qx{ovdeploy -cmd bbcutil -par \"-ping https://$node_name\" -host $HPOM_ip -cmd_timeout $cmdtimeout};
	my @remote_bbcutil_ping_node_ssl_edited = ();
	foreach my $bbcutil_line_out_ssl (@remote_bbcutil_ping_node_ssl)
	{
		chomp($bbcutil_line_out_ssl);
    print "\n--> $bbcutil_line_out_ssl" if ($verbose_flag eq "1");
		if ($bbcutil_line_out_ssl =~ m/eServiceOK/)
		{
      script_logger($date_and_time, $logfilename_with_path, "$node_name\:\:testOvdeploy_HpomToNode_SSL\(\)::Information::SSL communication OK!");
			return 0;
		}
		if ($bbcutil_line_out_ssl =~ m/^ERROR:/)
		{
      script_logger($date_and_time, $logfilename_with_path, "$node_name\:\:testOvdeploy_HpomToNode_SSL\(\)::Error::SSL \cCommunication timedout!");
      return 1;
		}
	}
}

#Sub to check the existance of a file within the OS fs
#Parms:   $logfilename_with_path
#         $date_and_time
#         $os_family:   windows|unix
#         $file_path:   path of file to verify
#         $file_name:   name of file to verify
#         $debug_flag   to get debug output
#Return:  $file_exists_in_path:   0 --> file exists in path
#                                 1 --> file does not exists in path
sub file_existance_in_path
{
  chomp(my $date_and_time = shift);
  chomp(my $logfilename_with_path = shift);
  chomp(my $node_name = shift);
  chomp(my $node_os = shift);
  chomp(my $file_path = shift);
  chomp(my $file_name = shift);
  chomp(my $verbose_flag = shift);
  my @check_file_cmd = ();
  my $check_file_cmd_line = '';
  my $file_exists_in_path = '1';

  @check_file_cmd = qx{ovdeploy -cmd if -par \"[ -f $file_path"/"$file_name ]; then echo FOUND $file_name !;else echo NOT_FOUND $file_name;fi\" -host $node_name} if ($node_os eq "unix");
  @check_file_cmd = qx{ovdeploy -cmd if -par \"exist $file_path\\$file_name (echo FOUND $file_name) else (echo NOT_FOUND $file_name)\" -host $node_name} if ($node_os eq "win");
  #@check_file_cmd = qx{ovdeploy -cmd ls -par \"-l $file_path"/"$file_name\" -host $node_name} if ($os_family eq "unix");
  #@check_file_cmd = qx{ovdeploy -cmd dir -par "$file_path'\\'$file_name" -host $node_name} if ($os_family eq "win");

  foreach $check_file_cmd_line (@check_file_cmd)
  {
    chomp($check_file_cmd_line);
    print "\n--> $check_file_cmd_line" if ($verbose_flag eq "1");
    #print "$check_file_cmd_line";
    if ($check_file_cmd_line =~ m/^FOUND/)
    #if ($check_file_cmd_line =~ m/.*$file_name$/)
    {
      #print "$check_file_cmd_line\n";
      script_logger($date_and_time, $logfilename_with_path, "$node_name\:\:file_existance_in_path\(\)::Information::$file_name FOUND!");
      $file_exists_in_path = '0';
      last;
    }
  }
  #Log when file is not found
  if ($file_exists_in_path eq "1")
  {
    script_logger($date_and_time, $logfilename_with_path, "$node_name\:\:file_existance_in_path\(\)::Information::$file_name NOT FOUND!");
  }
  return $file_exists_in_path;
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
