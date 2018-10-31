# Che Tenant Maintainer

Tool and associated rest endpoints to perform migration or maintenance actions
on user Che tenants.

For example:
- migration from single-tenant to multi-tenant server, which was applied as a Job/Pod
run in the user OSIO namespace 
- migation of workspace metadata and files from Che 5 to Che 6, applied as a REST
endpoint deployed as a dsaas service
- possibly other types of maintenance actions such as workspace PVC cleaning, etc...

This tool is deployed in OSIO dsaas services as a REST application that
provides one REST endpoint for each available maintenance service or migration.

