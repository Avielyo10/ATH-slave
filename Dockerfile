FROM openshift/origin

RUN yum clean all && \
    yum -y update && \
    yum install -y \
        centos-release-scl-rh \
        java-1.8.0-openjdk-headless.i686 \
        lsof \
        rsync \
        bc \ 
        gettext \
        which \
        curl \
        git \
        ImageMagick \
        iptables \
        maven \
        unzip \
        vnc4server \
        bzip2 \
        fluxbox \
        groovy \
        gtk2 \
        gtk3 \
        tar \
        yum-utils \
        device-mapper-persistent-data \
        lvm2 \
        apt-transport-https \
        ca-certificates \
        software-properties-common \
        device-mapper-persistent-data 

RUN mkdir -p /home/jenkins && \
    chown -R 1001:0 /home/jenkins && \
    chmod -R g+w /home/jenkins && \
    chmod 664 /etc/passwd && \
    chmod -R 775 /etc/alternatives && \
    chmod -R 775 /var/lib/alternatives && \
    chmod -R 775 /usr/lib/jvm && \
    chmod 775 /usr/bin && \
    chmod 775 /usr/lib/jvm-exports && \
    chmod 775 /usr/share/man/man1 && \
    chmod 775 /var/lib/origin && \    
    unlink /usr/bin/java && \
    unlink /usr/bin/jjs && \
    unlink /usr/bin/keytool && \
    unlink /usr/bin/orbd && \
    unlink /usr/bin/pack200 && \
    unlink /usr/bin/policytool && \
    unlink /usr/bin/rmid && \
    unlink /usr/bin/rmiregistry && \
    unlink /usr/bin/servertool && \
    unlink /usr/bin/tnameserv && \
    unlink /usr/bin/unpack200 && \
    unlink /usr/lib/jvm-exports/jre && \
    unlink /usr/share/man/man1/java.1.gz && \
    unlink /usr/share/man/man1/jjs.1.gz && \
    unlink /usr/share/man/man1/keytool.1.gz && \
    unlink /usr/share/man/man1/orbd.1.gz && \
    unlink /usr/share/man/man1/pack200.1.gz && \
    unlink /usr/share/man/man1/policytool.1.gz && \
    unlink /usr/share/man/man1/rmid.1.gz && \
    unlink /usr/share/man/man1/rmiregistry.1.gz && \
    unlink /usr/share/man/man1/servertool.1.gz && \
    unlink /usr/share/man/man1/tnameserv.1.gz && \
    unlink /usr/share/man/man1/unpack200.1.gz


# Download tigervnc-server-1.8.0-5.el7
RUN curl https://www.rpmfind.net/linux/centos/7.5.1804/os/x86_64/Packages/tigervnc-server-1.8.0-5.el7.x86_64.rpm --output tigervnc.rpm && \
yum localinstall -y tigervnc.rpm

# All we need is a statically linked client library - no need to install daemon deps: https://get.docker.com/builds/
RUN curl -fsSLO https://download.docker.com/linux/static/stable/x86_64/docker-17.03.2-ce.tgz && \
    tar --strip-components=1 -xvzf docker-17.03.2-ce.tgz -C /usr/local/bin
ENV SHARED_DOCKER_SERVICE true

# Firefox 45.9.0 - esr to /tmp
ADD https://ftp.mozilla.org/pub/firefox/releases/45.9.0esr/linux-x86_64/en-US/firefox-45.9.0esr.tar.bz2 /tmp

# Allow injecting uid and git to match directory ownership
ARG user=ath-user
ARG group=jenkins
ARG uid=10001
ARG gid=10000

ENV uid $uid
ENV gid $gid
ENV HOME /home/${user}
RUN groupadd -g ${gid} ${group}
RUN useradd -c "Jenkins user" -d $HOME -u ${uid} -g ${gid} -m ${user}
LABEL Description="This is a base image, which provides the Jenkins agent executable (slave.jar)" Vendor="Jenkins project" Version="3.27"

EXPOSE 50000

SHELL ["/bin/bash", "-c"]
# So it is owned by root and has the permissions vncserver seems to require:
RUN chmod 1777 /tmp/.X11-unix/

ARG VERSION=3.27
ARG AGENT_WORKDIR=/home/${user}/agent

RUN curl --create-dirs -sSLo /usr/share/jenkins/slave.jar https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/${VERSION}/remoting-${VERSION}.jar \
  && chmod 755 /usr/share/jenkins \
  && chmod 644 /usr/share/jenkins/slave.jar

USER ${user}
ENV AGENT_WORKDIR=${AGENT_WORKDIR}
RUN mkdir /home/${user}/.jenkins && mkdir -p ${AGENT_WORKDIR}

VOLUME /home/${user}/.jenkins
VOLUME ${AGENT_WORKDIR}
WORKDIR /home/${user}

# TODO seems this can be picked up from the host, which is unwanted:
ENV XAUTHORITY /home/${user}/.Xauthority

# 'n' for "Would you like to enter a view-only password (y/n)?"
RUN mkdir /home/${user}/.vnc && (echo ${user}; echo ${user}; echo "n") | vncpasswd /home/${user}/.vnc/passwd
# Default content includes x-window-manager, which is not installed, plus other stuff we do not need (vncconfig, x-terminal-emulator, etc.):
RUN touch /home/${user}/.vnc/xstartup && chmod a+x /home/${user}/.vnc/xstartup
RUN echo "exec /etc/X11/Xsession" > /home/${user}/.Xsession && chmod +x /home/${user}/.Xsession
# Prevent xauth to complain in a confusing way
RUN touch /home/${user}/.Xauthority

# Download files to run the ATH tests
RUN curl https://raw.githubusercontent.com/jenkinsci/acceptance-test-harness/master/run.sh --output run.sh && \
    curl https://raw.githubusercontent.com/jenkinsci/acceptance-test-harness/master/vnc.sh --output vnc.sh && \
    curl https://raw.githubusercontent.com/jenkinsci/acceptance-test-harness/master/pom.xml --output pom.xml

RUN chmod a+x $HOME/vnc.sh $HOME/run.sh

# Download files to run the jnlp-client
RUN curl https://raw.githubusercontent.com/openshift/jenkins/master/slave-base/contrib/bin/configure-agent --output configure-agent && \
    curl https://raw.githubusercontent.com/openshift/jenkins/master/slave-base/contrib/bin/configure-slave --output configure-slave && \
    curl https://raw.githubusercontent.com/openshift/jenkins/master/slave-base/contrib/bin/generate_container_user --output generate_container_user && \
    curl https://raw.githubusercontent.com/openshift/jenkins/master/slave-base/contrib/bin/run-jnlp-client --output run-jnlp-client 
    
RUN chmod a+x configure-agent configure-slave generate_container_user run-jnlp-client

USER root
# Set SUID and SGID for docker binary so it can communicate with mapped socket its uid:gid we can not control. Alternative
# approach used for this is adding ath-user to the group of /var/run/docker.sock but that require root permission we do not
# have in ENTRYPOINT as the container is started as ath-user.
RUN mv configure-agent configure-slave generate_container_user run-jnlp-client /usr/local/bin/ && \
    chmod ug+s "$(which docker)"

RUN eval $(./vnc.sh) && \
./run.sh firefox latest -Dmaven.test.failure.ignore=true -DforkCount=1 -B -Dtest=...

# Run the Jenkins JNLP client
ENTRYPOINT ["/usr/local/bin/run-jnlp-client"]
