FROM ceylon/ceylon:1.3.3-jre8-redhat-onbuild
LABEL maintainer="David Festal <dfestal@redhat.com>"

RUN ceylon compile

CMD ceylon run io.fabric8.tenant.che.migration.namespace
