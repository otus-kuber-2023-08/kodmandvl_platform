#!/bin/bash
helm pull oci://harbor.158.160.65.62.nip.io/library/frontend --version 0.1.0 --insecure-skip-tls-verify
helm pull oci://harbor.158.160.65.62.nip.io/library/hipster-shop --version 0.1.0 --insecure-skip-tls-verify
tar -xzvf frontend-0.1.0.tgz
tar -xzvf hipster-shop-0.1.0.tgz
# Tip! How to install if you need:
# Hipster-Shop with FrontEnd:
# helm upgrade --install hipster-shop hipster-shop --namespace hipster-shop --create-namespace
# FrontEnd only:
# helm upgrade --install frontend frontend --namespace hipster-shop --create-namespace

