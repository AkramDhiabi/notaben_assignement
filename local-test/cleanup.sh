#!/bin/bash

if kind get clusters 2>/dev/null | grep -q "notaben-local"; then
    kind delete cluster --name notaben-local
else
    echo "No cluster found"
fi
