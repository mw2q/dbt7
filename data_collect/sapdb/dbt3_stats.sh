#!/bin/sh
set -x

# dbt3_stats.sh: run dbt3 test and collect database and system 
# statistics
# It is the same as dbdriver/script/run_dbt3.sh except statistics is collected
#
# This file is released under the terms of the Artistic License.  Please see
# the file LICENSE, included in this package, for details.
#
# Copyright (C) 2003 Open Source Development Lab, Inc.
#
# Author: Jenny Zhang
# March 2003

if [ $# -lt 3 ]; then
        echo "usage: dbt3_stats.sh <scale_factor> <num_stream> <output_dir> [-s seed -d duration -i interval]"
        exit
fi

scale_factor=$1
num_stream=$2
output_dir=$3

#estimated dbt3 run time, make it really long, it will be killed at the end
dbt3_test_time=21607

duration=0
interval=0
seed=0
shift 3
# process the command line parameters
while getopts ":s:d:i:" opt; do
	case $opt in
		d) duration=$OPTARG
				;;
		i) interval=$OPTARG
				;;
		s) seed=$OPTARG
				;;
		?) echo "Usage: $0 <scale_factor> <num_stream> [-d duration -i interval -s seed]"
			exit ;;
		esac
done

dbdriver_script_path=$DBT3_INSTALL_PATH/dbdriver/scripts
dbdriver_sapdb_path=$DBT3_INSTALL_PATH/dbdriver/scripts/sapdb
run_path=$DBT3_INSTALL_PATH/run
seed_file=$DBT3_INSTALL_PATH/run/seed
builddb_path=$DBT3_INSTALL_PATH/builddb
datacollect_path=$DBT3_INSTALL_PATH/data_collect
datacollect_sapdb_path=$DBT3_INSTALL_PATH/data_collect/sapdb
GTIME="${DBT3_INSTALL_PATH}/dbdriver/utils/gtime"

if [ $seed -eq 0 ]; then
	echo "running $SID with default seed"
	echo "`date`: generate seed0" 
	echo "seed file is $seed_file";
	$DBT3_INSTALL_PATH/dbdriver/scripts/init_seed.sh > $seed_file
else
	echo "running $SID with seed $seed"
	echo "seed file is $seed_file";
	echo "$seed" > $seed_file
fi

#if not specified, then use default value
if [ $interval -eq 0 ] 
then 
	interval=60
fi

if [ $duration -eq 0 ] 
then 
	duration=$dbt3_test_time
fi

#if interval is larger than duration, then reduce interval by half
while [ $interval -gt $duration ]
do
	let "interval = $interval/2"
done

#clean run dir
rm $run_path/*

#make output directory
echo "make output dir"
mkdir -p $output_dir

#get meminfo
echo "get meminfo0"
cat /proc/meminfo > $output_dir/meminfo0.out
sleep 2

#get run config
$datacollect_path/get_config.sh $scale_factor $num_stream $output_dir

#start sys_stats.sh
echo "start sys_stats.sh"
$datacollect_path/sys_stats.sh $interval $duration $output_dir &


#execute the query
echo "run dbt3 test for scale factor $scale_factor $num_stream streams"


#get time stamp
s_time_dbt3=`$GTIME`

#***load test
echo "`date +'%Y-%m-%d %H:%M:%S'` start load test" 
#get the start time
s_time=`$GTIME`
$builddb_path/build_db.pl -f build_db.conf
e_time=`$GTIME`
echo "`date +'%Y-%m-%d %H:%M:%S'` load test end" 
let "diff_time_load=$e_time-$s_time"
echo "elapsed time for load test $diff_time_load" 


#calculate count 
let "count=($duration-$diff_time_load)/$interval"
if [ $count -eq 0 ]
then
        count=1
fi

#get one more count
let "count=$count+1"
#get database statistics
$datacollect_sapdb_path/db_stats.sh $SID $output_dir $count $interval &

i=1
while [ $i -le 1 ]
do
        echo "start performance test $i"
	$dbdriver_sapdb_path/run_perf_test.sh $scale_factor $i $num_stream
        let "i=$i+1"
done

e_time_dbt3=`$GTIME`
echo "`date`: dbt3 test end" 
let "diff_time_dbt3=$e_time_dbt3-$s_time_dbt3"
echo "elapsed time for dbt3 test $diff_time_dbt3" 

ps -ef | grep -v grep | grep sar | awk '{print $2}' | xargs kill -9
ps -ef | grep -v grep | grep iostat | awk '{print $2}' | xargs kill -9
ps -ef | grep -v grep | grep vmstat | awk '{print $2}' | xargs kill -9
pgrep db_stats.sh | xargs kill -9

#get meminfo
cat /proc/meminfo > $output_dir/meminfo1.out

#get query time
dbmcli -d $SID -u dbm,dbm -uSQL dbt,dbt "sql_execute select task_name, s_time, e_time, timediff(e_time,s_time) from time_statistics" 2>&1 > $output_dir/q_time.out

#calculate composite power
$dbdriver_script_path/get_composite.pl -p 1 -s 1 -n $num_stream -o $output_dir/calc_composite.out

#copy dbt3.out
mv $datacollect_sapdb_path/dbt3.out $output_dir/dbt3.out

#copy thuput_qs* and refresh_stream* to output
cp $run_path/thuput_qs* $output_dir/
cp $run_path/refresh_stream* $output_dir/
