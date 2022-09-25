#!/bin/bash

touch starTask_$1.list

for i in `seq 1 1000`
do
echo shifter --module=cvmfs /bin/tcsh  \${WRK_DIR}/r4sTask_embed.csh cori.simulation.y2014x.pythia8.HFjets.input.list.$1 $i 1000  \>\&   \${WRK_DIR}/logs/starTask_$1.$i.taskLog >> starTask_$1.list
done
