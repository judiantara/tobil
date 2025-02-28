#!/usr/bin/env bash

set -euo pipefail

( od -An -vtx1 | tr -d ' \n' )
