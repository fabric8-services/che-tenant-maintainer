FROM centos:7

ENV JAVA_HOME /etc/alternatives/jre
ENV CHE_TENANT_MAINTAINER_HOME /opt/che-tenant-maintainer

RUN yum update -y && \
    yum install -y \
       java-1.8.0-openjdk java-1.8.0-openjdk-devel git && \
    yum clean all

WORKDIR $CHE_TENANT_MAINTAINER_HOME

RUN chown -R 1000:0 ${CHE_TENANT_MAINTAINER_HOME} && chmod -R ug+rw ${CHE_TENANT_MAINTAINER_HOME}

COPY io.fabric8.tenant.che.migration.rest.jar ${CHE_TENANT_MAINTAINER_HOME}/
COPY agent-bond/* ${CHE_TENANT_MAINTAINER_HOME}/agent-bond/
COPY startRestEndpointsLocally.sh ${CHE_TENANT_MAINTAINER_HOME}/
COPY jolokia-readonly-access.xml ${CHE_TENANT_MAINTAINER_HOME}/

EXPOSE 8080
EXPOSE 8778

ENTRYPOINT ["/opt/che-tenant-maintainer/startRestEndpointsLocally.sh"]