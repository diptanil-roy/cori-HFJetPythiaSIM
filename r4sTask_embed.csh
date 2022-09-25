#!/bin/tcsh 
# this script produced from template on: February 12 2022 09:44PM

# sequence of steps for one r4s embedding task
# *) parse input vars 
# *) build fset-dependent sandbox using final path staring w/ ${Trigger set name}/bhla
# *) run embedding in the sandbox
# *) gzip r4s-log file 

echo r4s-start `date` "  host-is " `hostname`

# set the time spread per task on each node
if ( ! -f ${WRK_DIR}/skewdone ) then
   set WNODES=`expr $SLURM_JOB_NUM_NODES - 1`
   set SKEWPERNODE=`expr $SKEW / $WNODES`
   set  nsleep=`perl -e "srand; print int(rand($SKEWPERNODE))"`
   echo nsleep=$nsleep seconds sleep for this task \(SKEW=$SKEW, SKEWPERNODE=$SKEWPERNODE\)
   sleep $nsleep
endif

# Note, all code in this scrpt is executed under tcsh

    set coreN = $argv[1]    
    set fSet = $argv[2]
    if ( "$argv[3]" == "" ) then 
	echo "use global NUM_EVE ="$NUM_EVE
    else 
	set NUM_EVE = $argv[3]
	echo "use task-varied NUM_EVE ="$NUM_EVE
    endif

    # those variables could have been set in the SLURM job script
    #  and need to be overwritten when templeate is processed
    set STAR_VER = SL16d_embed
    set PATH_DAQ = /global/homes/s/staremb/zhux/simu/git_jason
        
    echo  starting new r4s PATH_DAQ=$PATH_DAQ, coreN=$coreN, execName=$EXEC_NAME, NUM_EVE=$NUM_EVE, fSet=$fSet, workerName=`hostname -f`', startDate='`date`
    echo 'pwd='`pwd` ' WRK_DIR='${WRK_DIR}  

    set daqN = `sed -n "${fSet}p" $PATH_DAQ/$coreN`
    set daqNbase = `basename $daqN`
    set fzdN =  $daqNbase.fzd
    set r4sLogFile = ${daqNbase}.r4s_${fSet}.log

    ls -l $daqN

    cd ${WRK_DIR} # important, no clue why I  need to do it again
    pwd
    ls -la  . StRoot/ 



    # Prepare final storage dir, aka sandbox
    # for the final storage of embedding data the FSET_PATH is
    # ./${trigger set name}/${Embeded Particle}_${fSet}_${embedding requestID}/
    # The files in each fSet the REQUEST_PATH
    # ${Embeded Particle}_${fSet}_${embedding requestID}/${starProdID}.${STARLIB}/${YEAR}/${DAY}/st*
    # e.g: 
    # ls production_pp200_2015/Psi2SMuMu_104_20163401/P16id.SL16d/2015/114
    # st_mtd_adc_16114049_raw_5500008.30D2B4FE3C7A1F23_548.log.gz
    # st_mtd_adc_16114049_raw_5500008.event.root
    # st_mtd_adc_16114049_raw_5500008.geant.root

    set FSET_PATH = ${SCRATCH}/embedding/HFJetSimuRun14pp200
    set LOG_PATH = ${SCRATCH}/embedding/HFJetSimuRun14pp200_log
    echo my FSET_PATH=$FSET_PATH
    
    #
    # - - - -  D O   N O T  T O U C H  T H I S   S E C T I O N- - - - 
    #

    echo os-in-shifter is
    cat /etc/*release

    echo "check if in shifter (expected 1)"
    env | grep  SHIFTER_RUNTIME
    
    whoami    

    set localDBconfig = $DB_SERVER_LOCAL_CONFIG
    echo  load STAR enviroment 
    set cvmfs=1
    if ( "$cvmfs" == "1" ) then
	 set NCHOS = sl74
	 set SCHOS = 74
	 set DECHO = 1
	 setenv GROUP_DIR /cvmfs/star.sdcc.bnl.gov/group
	 setenv USE_CVMFS 1
    else
	 set NCHOS = sl64
	 set SCHOS = 64
	 set DECHO = 1
	 setenv GROUP_DIR /common/star/star${SCHOS}/group/
    endif
    source $GROUP_DIR/star_cshrc.csh    
     
    echo testing STAR setup $STAR_VER in `pwd`
    #stardev
    starver SL21d
    env |grep STAR

    echo 'my new STAR ver='$STAR'  test '$EXEC_NAME' '
    $EXEC_NAME -b -q 

    #
    # - - - -   Y O U   C A N   C H A N G E   B E L O W  - - - -
    #
    echo my pwd=`pwd`
    ls -la  . StRoot/ 
    #set sandBox = $FSET_PATH/$REQUEST_PATH
    set sandBox = `hostname`.$$
    echo check sandbox  $sandBox
    if ( -d $sandBox) then 
	echo "sandbox exist - delete it !"
	rm -rf $sandBox
    endif
    pwd
    umask 2
    mkdir -p $sandBox
    ln -s ${WRK_DIR}/StRoot  $sandBox
    if ( -d ${WRK_DIR}/mgr ) then
      ln -s ${WRK_DIR}/mgr  $sandBox
    endif
    if ( -d ${WRK_DIR}/Input ) then
      ln -s ${WRK_DIR}/Input  $sandBox
    endif
    echo step into sandbox 

    set localDB=1
    if ( "$localDB" == "1" ) then
    echo "  DB  DB  DB  DB    DB  DB  DB  DB    DB  DB  DB  DB  --- check start"
    setenv DB_SERVER_LOCAL_CONFIG $localDBconfig
    echo get IP of local DB to verify it is accessible
    cat $DB_SERVER_LOCAL_CONFIG
    set dbIP = `grep "Host name=" $DB_SERVER_LOCAL_CONFIG | cut -f2 -d\"`
    echo star-db-IP=$dbIP  tables seen by st_db_maker
    mysql  --socket=/mysqlVault/mysql.sock -h$dbIP -e 'show databases'
    echo check if loadbalancer sees  processlist
    #    mysql -u loadbalancer -P3306 -plbdb -h $dbIP -e 'show processlist';
    mysql -P3306 -h $dbIP -e 'show processlist';

    echo "  DB  DB  DB  DB    DB  DB  DB  DB    DB  DB  DB  DB  --- check end"
    endif
  
    cd $sandBox
    pwd

    if ( -f ${WRK_DIR}/consdone ) then
      echo "'cons' was done, make a symlink for .sl${SCHOS}* to sandbox if necessary!"
      set wconsdir=`find ${WRK_DIR}/ -maxdepth 1 -type d -name ".sl${SCHOS}*"`
      if ( "$wconsdir" != "" ) then
         ln -s $wconsdir 
      endif
    else 
      echo "'cons' was not done, do it now."
      if ( ! -f ${WRK_DIR}/consing ) then
        echo "no one else is doing 'cons' now, let me do it."
        touch ${WRK_DIR}/consing
        echo "put a lock first!"
        cons
        echo "cons done!"
        set consdir=`find . -type d -name ".sl${SCHOS}*"`
	  if ( "$consdir" == "" ) then
	    echo "claim that cons is done!"
	    touch ${WRK_DIR}/consdone
	    echo "release the lock!"
	    rm -f ${WRK_DIR}/consing
	  else
          if ( ! -d ${WRK_DIR}/$consdir ) then
		 mv $consdir ${WRK_DIR}/
		 echo "claim that cons is done!"
		 touch ${WRK_DIR}/consdone
		 echo "release the lock!"
		 rm -f ${WRK_DIR}/consing
		 echo "copied..."
		 echo "$consdir"
		 echo "-->"
		 echo "${WRK_DIR}"
		 cp -rpnv ${WRK_DIR}/$consdir .
	    else
		 echo "someone else is copying, I do nothing"
	    endif
        endif
      else
        echo "someone else is doing 'cons' now, I will wait."
        while ( ! -f ${WRK_DIR}/consdone )
          sleep 1s 
        end
        set wconsdir=`find ${WRK_DIR}/ -maxdepth 1 -type d -name ".sl${SCHOS}*"`
        if ( "$wconsdir" != "" ) then
          ln -s $wconsdir 
        endif
      endif
    endif

    ls -la  . StRoot/ .sl${SCHOS}* 
    ls -la  .sl${SCHOS}*/lib/  
    echo "===FIRE  $EXEC_NAME for coreN=$coreN fSet=$fSet "`date`

    # make sure local .cxx was copied to wrk-dir and compiled correctly in advance 
    echo start embedding for $NUM_EVE events  on $coreN fset $fSet r4sLogFile=$r4sLogFile
    echo full r4s log  $sandBox/$r4sLogFile
    if ( -f $r4sLogFile ) then
	 rm -f $r4sLogFile
    endif
    #touch $r4sLogFile

    # setup and executing simulator
    echo "JobStartTime="`/bin/date`
#    setenv datevalue `cat ${SUBMITTINGDIRECTORY}/date.txt`


#       unsetenv NODEBUG

#    setup 32b

    # Check to see that everything is setup and making sense
    ls -la

#    rehash

    which starsim

    set runfile   = $daqN
#   set runnumber = `basename $runfile:t .txt`
    set runnumber = `echo $runfile:t | awk -F "_" '// { print $1 }'`
    set chunk     = `echo $runfile:t | awk -F "_" '// { print $2 }'`

    echo RUNNUMBER = ${runnumber}

    set   EMBEDDING_START_TIME = `date`
    # Run starsim and create 10 output fzd files

    echo ${runfile}
    echo ${runfile} > mc_${runnumber}_${chunk}.log
    echo SIMULATION_START_TIME = `date` >> mc_${runnumber}_${chunk}.log
    root4star -q -b Input/starsim.C\(${NUM_EVE},${runnumber},\"${runfile}\",1,\"${chunk}\",3,0\) >> mc_${runnumber}_${chunk}.log
    echo SIMULATION_END_TIME = `date` >> mc_${runnumber}_${chunk}.log

    set fzdin=`ls *.fzd`

    # Run reconstruction
    starver $STAR_VER 
      mv .$STAR_HOST_SYS meh

    setenv DB_SERVER_LOCAL_CONFIG $localDBconfig

    echo RECONSTRUCTION_START_TIME = `date` > rc_${runnumber}_${chunk}.log
    root4star -q -b Input/runBfc.C\(${NUM_EVE},\"${fzdin}\"\)             >> rc_${runnumber}_${chunk}.log
    echo RECONSTRUCTION_END_TIME = `date` >> rc_${runnumber}_${chunk}.log

    set   EMBEDDING_END_TIME = `date`

    echo EMBEDDING_START_TIME = ${EMBEDDING_START_TIME} > stats_${runnumber}_${chunk}.log
    echo EMBEDDING_END_TIME = ${EMBEDDING_END_TIME} >> stats_${runnumber}_${chunk}.log
    #grep SIMU*_TIME mc*_${chunk}.log >> stats_${runnumber}_${chunk}.log
    #grep RECO*_TIME rc*_${chunk}.log >> stats_${runnumber}_${chunk}.log
    ls -l --human-readable *.root *.fzd >> stats_${runnumber}_${chunk}.log

    if ( ! -d $FSET_PATH ) then
	 mkdir -p $FSET_PATH
    endif
    if ( ! -d $LOG_PATH ) then
	 mkdir -p $LOG_PATH
    endif

    cp *.MuDst.root $FSET_PATH
    cp *.pico*.root $FSET_PATH
    if ( ${NUM_EVE} < 11 ) then
       cp *.fzd $FSET_PATH
       cp *.log* $LOG_PATH
     else
       gzip --best *.log
       cp *.log* $LOG_PATH
     endif

    cd ${WRK_DIR}
    rm -rf $sandBox
    echo end of task  coreN=$coreN fSet=$fSet
