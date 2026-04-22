# Building ngdevkit from source on any platform that supports Docker

## Pre-requisite

* Docker

### Shell
The following command will let access the container that contains the embedded devkit and the current folder at /tmp/workdir. So, you will be able to make the build your on rom easily without any local dependency

```shell
make -f Makefile.docker shell
```

### Push
To avoid waiting the image creating you can push the finished one as following

```shell
make -f Makefile.docker USER=<YOUR_DOCKERHUB_USER> push
```

Congratulations! You are now ready to experiment with the devkit.
Please follow the [main README](README.md) for additional information
on how to download and build the example ROMs, run the emulator or
run the debugger.

