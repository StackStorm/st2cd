#!/bin/bash

# Create the virtualenv
virtualenv venv

. venv/bin/activate && pip install -r requirements.txt
