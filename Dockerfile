FROM ubuntu:latest
LABEL authors="marechaljas"

ENTRYPOINT ["top", "-b"]