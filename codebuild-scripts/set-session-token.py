#!/usr/bin/env python
import json
import sys
import os


resp = json.load(sys.stdin)
os.environ['AWS_ACCESS_KEY_ID'] = resp['Credentials']['AccessKeyId']
os.environ['AWS_SECRET_ACCESS_KEY'] = resp['Credentials']['SecretAccessKey']
os.environ['AWS_SESSION_TOKEN'] = resp['Credentials']['SessionToken']
