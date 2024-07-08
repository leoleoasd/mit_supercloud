#!/usr/bin/env bash
# some environment variables for offline use
export HF_DATASETS_OFFLINE=1 TRANSFORMERS_OFFLINE=1

SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPT_HOME=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

partition="xeon-p8"
job_name="wandb"
job_time="100:00:00"

while getopts p:j:g:t:h flag
do
    case "${flag}" in
        p) partition=${OPTARG};;
        j) job_name=${OPTARG};;
        g) gpus=${OPTARG};;
        t) job_time=${OPTARG};;
        h|*) echo "usage: $0 [-p partition] [-j job_name] [-g gpus] [-t time]"; exit 1;;
    esac
done

existing_wandb=$(squeue --json | jq -r '.jobs[] | select(.name == "wandb") | select(.job_state == "RUNNING") .job_id')
if [ "$existing_wandb" != "" ]; then
    echo "There is already a wandb job running. Probing it's url..."
    forward_name="$(id -un | tr '[A-Z]' '[a-z]')-wandb"
    echo "Portal URL is: https://${forward_name}.fn.txe1-portal.mit.edu/"
    exit 1
fi

sbatch_output=$(sbatch << EOT
#!/bin/sh
#SBATCH --job-name=$job_name                                    # Job name
#SBATCH -p $partition                                           # Partition (queue) name
#SBATCH --nodes=1                                               # Number of nodes
#SBATCH --time=$job_time                                         # Time limit hrs:min:sec
#SBATCH --output=$SCRIPT_HOME/logs/wandb%j.log                # Standard output and error log
#SBATCH --cpus-per-task=24
#SBATCH --signal=B:USR1@60

USER=$(id -un | tr '[A-Z]' '[a-z]')

echo "export WANDB_BASE_URL=http://\$(hostname -s):8080" > ~/.wandb_env
rm -rf /state/partition1/user/\$USER/wandb
mkdir -p /state/partition1/user/\$USER/singularity/mnt/session
cd /state/partition1/user/\$USER
tar xfP \$(ls -t ~/wandb/wandb*.tar | head -1)
singularity run --writable --containall wandb &
WANDB_PID=\$!

PORTAL_FWNAME="\$(id -un | tr '[A-Z]' '[a-z]')-wandb"
PORTAL_FWFILE="/home/gridsan/portal-url-fw/\${PORTAL_FWNAME}"
echo "Forward name is: \${PORTAL_FWNAME}"
echo "Portal URL is: https://\${PORTAL_FWNAME}.fn.txe1-portal.mit.edu/"
echo "http://\$(hostname -s):8080/" > \$PORTAL_FWFILE
chmod u+x \${PORTAL_FWFILE}

on_exit() {
    trap - EXIT USR1
    echo "Received signal to exit. Killing wandb(\$WANDB_PID) process..."
    kill -INT \$WANDB_PID
    echo "Wandb process killed. waiting..."
    wait \$WANDB_PID
    # make sure process 'runsv' exists
    while pgrep -x "runsv" > /dev/null ; do sleep 1; echo 'waiting';  done
    echo "Updating tar..."
    tar cfP ~/wandb/wandb\$(date +%Y_%m_%d_%H_%M_%S).tar /state/partition1/user/\$USER/wandb
}

trap on_exit EXIT USR1
wait
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
echo "Job $job_id started. Waiting for wandb to start..."
echo "This may take a while, since all the dependencies are at a network drive and needed to be downloaded."
job_hostname=$(squeue -j ${job_id} --json | jq -r .jobs\[0\].job_resources.allocated_nodes\[0\].nodename)
# wait for file to exist
while [ ! -f $SCRIPT_HOME/logs/wandb${job_id}.log ]; do sleep 1; done
# find for "Forward name is: "
while true; do
    forward_name=$(grep -oP 'Forward name is: \K.*' $SCRIPT_HOME/logs/wandb${job_id}.log)
    if [ "$forward_name" != "" ]; then
        break
    fi
    echo -ne "."
    sleep 1
done
echo "Portal URL is: https://${forward_name}.fn.txe1-portal.mit.edu/"
