#!/bin/bash

# Note: this relies on Docker secrets to build, but that secret is not stored in Git.  This build script looks up one directory and down into a secrets subdir
# For github actions, should rely on the Github secrets stuff, adding each one seperately

docker build -t base-sssd:latest --secret id=LDAP_BIND_USER,src=../secrets/LDAP_BIND_USER.env --secret id=LDAP_BIND_PASSWORD,src=../secrets/LDAP_BIND_PASSWORD.env --secret id=DEFAULT_DOMAIN_SID,src=../secrets/DEFAULT_DOMAIN_SID.env .
