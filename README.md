# MIT Supercloud Scripts
Here are all the scripts I used on MIT Supercloud. Just clone this repo and soft link the scripts to your PATH.
```
git clone https://github.com/leoleoasd/mit_supercloud.git
cd mit_supercloud
ln -s $PWD/launch_jupyter.sh /path/to/your/bin/launch_jupyter
```

## Launch Jupyter
This script lauches a Jupyter notebook on the supercloud in your current environment & path, and set up the proxy.
```bash
$ usage: ./launch_jupyter.sh [-p partition] [-j job_name] [-g gpus]
```
