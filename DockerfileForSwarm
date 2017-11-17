FROM centos:7
LABEL maintainer="David Festal <dfestal@redhat.com>"

ENV F8_USER_NAME=fabric8
RUN useradd  -s /bin/bash ${F8_USER_NAME}

RUN yum install -y epel-release && yum install -y java-1.8.0-openjdk-devel && yum clean all 

WORKDIR /home/${F8_USER_NAME}
COPY io.fabric8.tenant.che.migration.workspaces-*-swarm.jar io.fabric8.tenant.che.migration.workspaces-swarm.jar

RUN chmod -R +777 /home/${F8_USER_NAME}
USER ${F8_USER_NAME}

EXPOSE 8080

CMD java -jar io.fabric8.tenant.che.migration.workspaces-swarm.jar
