#!/bin/sh

if [ $# -ne 2 ]; then
        echo "Usage: ./run_power_test.sh <scale_factor> <perf_run_number>"
        exit
fi

scale_factor=$1
perf_run_num=$2
qgen_dir="$DBT3_INSTALL_PATH/datagen/dbgen"
run_dir="$DBT3_INSTALL_PATH/run"
seed_file="$DBT3_INSTALL_PATH/seed"
query_file="$run_dir/power_query"
tmp_query_file="$run_dir/tmp_query.sql"
param_file="$run_dir/power_param"

GTIME="${DBT3_INSTALL_PATH}/dbdriver/utils/gtime"

echo "`date`: =======power test $perf_run_num========"

s_time_power=`$GTIME`
echo "sql_execute insert into time_statistics (task_name, s_time, int_time) values ('PERF${perf_run_num}.POWER', timestamp, $s_time_power)"
dbmcli -d $SID -u dbm,dbm -uSQL dbt,dbt "sql_execute insert into time_statistics (task_name, s_time, int_time) values ('PERF${perf_run_num}.POWER', timestamp, $s_time_power)"

#***run rf1
cd $DBT3_INSTALL_PATH/dbdriver/scripts
#get the start time
echo "`date`: start rf1 " 
s_time=`$GTIME`
echo "sql_execute insert into time_statistics (task_name, s_time, int_time) values ('PERF${perf_run_num}.POWER.RF1', timestamp, $s_time)"
dbmcli -d $SID -u dbm,dbm -uSQL dbt,dbt "sql_execute insert into time_statistics (task_name, s_time, int_time) values ('PERF${perf_run_num}.POWER.RF1', timestamp, $s_time)"
./run_rf1.sh $scale_factor 
echo "sql_execute update time_statistics set e_time=timestamp where task_name='PERF${perf_run_num}.POWER.RF1' and int_time=$s_time"
dbmcli -d $SID -u dbm,dbm -uSQL dbt,dbt "sql_execute update time_statistics set e_time=timestamp where task_name='PERF${perf_run_num}.POWER.RF1' and int_time=$s_time"
e_time=`$GTIME`
echo "`date`: rf1 end " 
let "diff_time=$e_time-$s_time"
echo "elapsed time for rf1 $diff_time" 

#run the queries
./run_power_query.sh $scale_factor $perf_run_num

cd $DBT3_INSTALL_PATH/dbdriver/scripts
#get the start time
echo "`date`: start rf2 " 
s_time=`$GTIME`
echo "sql_execute insert into time_statistics (task_name, s_time, int_time) values ('PERF${perf_run_num}.POWER.RF2', timestamp, $s_time)"
dbmcli -d $SID -u dbm,dbm -uSQL dbt,dbt "sql_execute insert into time_statistics (task_name, s_time, int_time) values ('PERF${perf_run_num}.POWER.RF2', timestamp, $s_time)"
./run_rf2.sh
echo "sql_execute update time_statistics set e_time=timestamp where task_name='PERF${perf_run_num}.POWER.RF2' and int_time=$s_time"
dbmcli -d $SID -u dbm,dbm -uSQL dbt,dbt "sql_execute update time_statistics set e_time=timestamp where task_name='PERF${perf_run_num}.POWER.RF2' and int_time=$s_time"
e_time=`$GTIME`
echo "`date`: rf2 end " 
let "diff_time=$e_time-$s_time"
echo "elapsed time for rf2 $diff_time" 

echo "sql_execute update time_statistics set e_time=timestamp where task_name='PERF${perf_run_num}.POWER' and int_time=$s_time_power"
dbmcli -d $SID -u dbm,dbm -uSQL dbt,dbt "sql_execute update time_statistics set e_time=timestamp where task_name='PERF${perf_run_num}.POWER' and int_time=$s_time_power"

e_time_power=`$GTIME`
echo "`date`: end power test run "
let "diff_time=$e_time_power-$s_time_power"
echo "elapsed time for power test $diff_time"
