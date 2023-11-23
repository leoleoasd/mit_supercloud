#!/usr/bin/env bash

SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPT_HOME=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

partition="xeon-p8"
job_name="tensorboard"
job_time="08:00:00"
logdir=runs

while getopts p:j:t:hr: flag
do
    case "${flag}" in
        p) partition=${OPTARG};;
        j) job_name=${OPTARG};;
        t) job_time=${OPTARG};;
        r) logdir=${OPTARG};;
        h|*) echo "usage: $0 [-p partition] [-j job_name] [-t time] [-r logdir]"; exit 1;;
    esac
done

sbatch_output=$(sbatch << EOT
#!/bin/sh
#SBATCH --job-name=$job_name                                    # Job name
#SBATCH -p $partition                                           # Partition (queue) name
#SBATCH --nodes=1                                               # Number of nodes
#SBATCH --time=$job_time                                         # Time limit hrs:min:sec
#SBATCH --output=$SCRIPT_HOME/logs/tensorboard%j.log                # Standard output and error log

srun --resv-ports=1 \
    bash << EOF
    RANDOM_ID=\\\$(uuidgen | cut -c1-8)
    PORTAL_FWNAME="\\\$(id -un | tr '[A-Z]' '[a-z]')-\\\$RANDOM_ID-tensorboard"
    PORTAL_FWFILE="/home/gridsan/portal-url-fw/\\\${PORTAL_FWNAME}"
    echo "Forward name is: \\\${PORTAL_FWNAME}"
    echo "Portal URL is: https://\\\${PORTAL_FWNAME}.fn.txe1-portal.mit.edu/"
    echo "http://\\\$(hostname -s):\\\${SLURM_STEP_RESV_PORTS}/" > \\\$PORTAL_FWFILE
    # cat \$PORTAL_FWFILE
    chmod u+x \\\${PORTAL_FWFILE}
    tensorboard --port \\\${SLURM_STEP_RESV_PORTS} --host "0.0.0.0" --logdir $logdir
EOF
EOT
)

job_id=$(echo "$sbatch_output" | awk '{print $4}')
echo "JobID: $job_id submitted; waiting for it to start..."

while true; do
    job_state=$(squeue -j ${job_id} --json | jq -r .jobs\[0\].job_state)
    if [ "$job_state" != "PENDING" ]; then
        break
    fi
    echo -ne "."
    sleep 1
done
echo ""
echo "Job $job_id started. Waiting for tensorboard to start..."
echo "This may take a while, since all the dependencies are at a network drive and needed to be downloaded."
job_hostname=$(squeue -j ${job_id} --json | jq -r .jobs\[0\].job_resources.allocated_nodes\[0\].nodename)
# wait for file to exist
while [ ! -f $SCRIPT_HOME/logs/tensorboard${job_id}.log ]; do sleep 1; done
# find for "Forward name is: "
while true; do
    portal_url=$(grep -oP 'Portal URL is: \K.*' $SCRIPT_HOME/logs/tensorboard${job_id}.log)
    if [ "$portal_url" != "" ]; then
        break
    fi
    echo -ne "."
    sleep 1
done
while true; do
    tensorboard_at=$(grep -m1 -oP "TensorBoard [0-9\.]* at" $SCRIPT_HOME/logs/tensorboard${job_id}.log)
    if [ "$tensorboard_at" != "" ]; then
        break
    fi
    echo -ne "."
    sleep 1
done
echo ""
echo "Portal URL is: $portal_url"

