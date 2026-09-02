# Python Environment Setup

Anything you build or test with Bazel brings its own Python, so this is only needed for the tools that run outside it, such as `util/dvsim/dvsim.py`, `util/regtool.py` and the other generators.

Install their dependencies into a virtual environment, which keeps the versions from clashing with anything else on your system:

```sh
sudo apt install python3-venv
python3 -m venv $REPO_TOP/.venv
source $REPO_TOP/.venv/bin/activate
pip3 install -r $REPO_TOP/python-requirements.txt --require-hashes
```

We recommend matching the Python version `MODULE.bazel` pins for the Bazel toolchain, so that a tool behaves the same whether you run it or Bazel does.

Re-activate the environment with `source $REPO_TOP/.venv/bin/activate` whenever you return to the repository, or activate it from your shell rc file (e.g. bashrc, cshrc, zshrc).
