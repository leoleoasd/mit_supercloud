#!/usr/bin/env bash
# some environment variables for offline use
export HF_DATASETS_OFFLINE=1 TRANSFORMERS_OFFLINE=1 WANDB_MODE=offline

SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPT_HOME=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

partition="debug-gpu"
job_name="jupyter"
gpus=1
job_time="01:00:00"

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

sbatch_output=$(sbatch << EOT
#!/bin/sh
#SBATCH --job-name=$job_name                                    # Job name
#SBATCH -p $partition                                           # Partition (queue) name
#SBATCH --nodes=1                                               # Number of nodes
#SBATCH --gpus=$gpus                                            # Number of GPUs to allocate
#SBATCH --time=$job_time                                         # Time limit hrs:min:sec
#SBATCH --output=$SCRIPT_HOME/logs/jupyter%j.log                # Standard output and error log

srun --resv-ports=1 \
    bash << EOF
    RANDOM_ID=\\\$(uuidgen | cut -c1-8)
    PORTAL_FWNAME="\\\$(id -un | tr '[A-Z]' '[a-z]')-\\\$RANDOM_ID-jupyter"
    PORTAL_FWFILE="/home/gridsan/portal-url-fw/\\\${PORTAL_FWNAME}"
    echo "Forward name is: \\\${PORTAL_FWNAME}"
    echo "Portal URL is: https://\\\${PORTAL_FWNAME}.fn.txe1-portal.mit.edu/"
    echo "http://\\\$(hostname -s):\\\${SLURM_STEP_RESV_PORTS}/" > \\\$PORTAL_FWFILE
    # cat \$PORTAL_FWFILE
    chmod u+x \\\${PORTAL_FWFILE}
    jupyter lab --port \\\${SLURM_STEP_RESV_PORTS} --ip \\\$(hostname -s) --no-browser
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
echo "Job $job_id started. Waiting for jupyter to start..."
echo "This may take a while, since all the dependencies are at a network drive and needed to be downloaded."
job_hostname=$(squeue -j ${job_id} --json | jq -r .jobs\[0\].job_resources.allocated_nodes\[0\].nodename)
# wait for file to exist
while [ ! -f $SCRIPT_HOME/logs/jupyter${job_id}.log ]; do sleep 1; done
# find for "Forward name is: "
while true; do
    forward_name=$(grep -oP 'Forward name is: \K.*' $SCRIPT_HOME/logs/jupyter${job_id}.log)
    if [ "$forward_name" != "" ]; then
        break
    fi
    echo -ne "."
    sleep 1
done
target_name=$(cat /home/gridsan/portal-url-fw/${forward_name})
# Find for something like "http://$job_hostname:.../"
while true; do
    jupyter_url=$(grep -m1 -oP ".*\Khttp://$job_hostname.*" $SCRIPT_HOME/logs/jupyter${job_id}.log)
    if [ "$jupyter_url" != "" ]; then
        break
    fi
    echo -ne "."
    sleep 1
done
echo ""
# replace target name in jupyter_url to PORTAL_FWNAME
output_url=$(echo $jupyter_url | sed "s|$target_name|https://$forward_name.fn.txe1-portal.mit.edu/|")
echo "Portal URL is: $output_url"
echo "Jupyter URL is: $jupyter_url"
