# Creates a kylin 3.0.1 + HDP 3.1 + Centos8 image

FROM centos:8
LABEL maintainer="Ranlab Organization"

USER root

ADD HDP.repo /etc/yum.repos.d/HDP.repo
ADD HDP-UTILS.repo /etc/yum.repos.d/HDP-UTILS.repo

# install dev tools
RUN yum clean all; \
    rpm --rebuilddb; \
    yum install -y epel-release curl which wget tar sudo openssh-server openssh-clients rsync
# update libselinux. see https://github.com/sequenceiq/hadoop-docker/issues/14
RUN yum update -y libselinux

# passwordless ssh
RUN ssh-keygen -q -N "" -t dsa -f /etc/ssh/ssh_host_dsa_key
RUN ssh-keygen -q -N "" -t rsa -f /etc/ssh/ssh_host_rsa_key
RUN ssh-keygen -q -N "" -t rsa -f /root/.ssh/id_rsa
RUN cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

# java
RUN yum -y remove java*
RUN yum -y install java-1.8.0-openjdk java-1.8.0-openjdk-devel
ENV JAVA_HOME /usr/lib/jvm/java
ENV PATH $PATH:$JAVA_HOME/bin
ADD hadoop_java.sh /etc/profile.d/hadoop_java.sh

# Installation Hadoop
ENV HADOOP_RELEASE=3.2.1
RUN adduser hadoop --uid 1001 --password $(openssl passwd -1 pw4hadoop)
RUN usermod -aG wheel hadoop
RUN wget -q https://www-eu.apache.org/dist/hadoop/common/hadoop-$HADOOP_RELEASE/hadoop-$HADOOP_RELEASE.tar.gz -O /tmp/hadoop-$HADOOP_RELEASE.tar.gz \
    && tar xfz /tmp/hadoop-$HADOOP_RELEASE.tar.gz -C /opt && rm -f /tmp/hadoop-$HADOOP_RELEASE.tar.gz
RUN chown -R hadoop:hadoop /opt/hadoop-$HADOOP_RELEASE
RUN ln -s /opt/hadoop-3.2.1 /opt/hadoop


USER hadoop
RUN ssh-keygen -q -N "" -t rsa -f /home/hadoop/.ssh/id_rsa
RUN cat /home/hadoop/.ssh/id_rsa.pub >> /home/hadoop/.ssh/authorized_keys
RUN chmod 0600 /home/hadoop/.ssh/authorized_keys




# hadoop, hive, hbase
RUN yum install -y hbase tez hadoop snappy snappy-devel hadoop-libhdfs ambari-log4j hive hive-hcatalog hive-webhcat webhcat-tar-hive mysql-connector-java 


# java
RUN curl -LO 'http://download.oracle.com/otn-pub/java/jdk/8u241-b07/jdk-8u241-linux-x64.rpm' -H 'Cookie: oraclelicense=accept-securebackup-cookie'
RUN rpm -i jdk-8u241-linux-x64.rpmm
RUN rm jdk-8u241-linux-x64.rpm

ENV JAVA_HOME /usr/java/default
ENV PATH $PATH:$JAVA_HOME/bin
RUN rm /usr/bin/java && ln -s $JAVA_HOME/bin/java /usr/bin/java

# kylin 3.0.1
RUN curl -s https://www.apache.org/dyn/closer.cgi/kylin/apache-kylin-3.0.1/apache-kylin-3.0.1-bin-hadoop3.tar.gz | tar -xz -C /usr/local/
RUN cd /usr/local && ln -s ./apache-kylin-3.0.1-bin kylin
ENV KYLIN_HOME /usr/local/kylin

ADD ssh_config /root/.ssh/config
RUN chmod 600 /root/.ssh/config && chown root:root /root/.ssh/config

ADD bootstrap.sh /etc/bootstrap.sh
RUN chown root:root /etc/bootstrap.sh && chmod 700 /etc/bootstrap.sh

ENV BOOTSTRAP /etc/bootstrap.sh

# fix the 254 error code
RUN sed  -i "/^[^#]*UsePAM/ s/.*/#&/"  /etc/ssh/sshd_config
RUN echo "UsePAM no" >> /etc/ssh/sshd_config
RUN echo "Port 2122" >> /etc/ssh/sshd_config

CMD ["/etc/bootstrap.sh", "-d"]

ENV JAVA_LIBRARY_PATH /usr/hdp/2.4.0.0-169/hadoop/lib/native:$JAVA_LIBRARY_PATH

# Kylin and Other ports
EXPOSE 7070 7443 49707 2122

ENV HADOOP_CONF_DIR /etc/hadoop/conf
ENV HBASE_CONF_DIR /etc/hbase/conf
ENV HIVE_CONF_DIR /etc/hive/conf

# Add configuration files
ADD conf/core-site.xml $HADOOP_CONF_DIR/core-site.xml
ADD conf/hdfs-site.xml $HADOOP_CONF_DIR/hdfs-site.xml
ADD conf/mapred-site.xml $HADOOP_CONF_DIR/mapred-site.xml
ADD conf/yarn-site.xml $HADOOP_CONF_DIR/yarn-site.xml
ADD conf/hbase-site.xml $HBASE_CONF_DIR/hbase-site.xml
ADD conf/hdfs-site.xml $HBASE_CONF_DIR/hdfs-site.xml
ADD conf/hive-site.xml $HIVE_CONF_DIR/hive-site.xml
ADD conf/mapred-site.xml $HIVE_CONF_DIR/mapred-site.xml
ADD conf/kylin.properties $KYLIN_HOME/conf/kylin.properties
