#!/bin/bash

cp ../environment.yml .
docker build . -t "rnafusion-test"
