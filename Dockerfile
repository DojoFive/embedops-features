FROM ubuntu:latest

RUN --mount=source=install.sh,target=/tmp/install.sh \
    /tmp/install.sh