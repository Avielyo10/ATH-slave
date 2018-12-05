FROM centos:latest

RUN yum clean all && \
    yum -y update && \
    yum install -y \
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
        device-mapper-persistent-data \
        tigervnc-server

# All we need is a statically linked client library - no need to install daemon deps: https://get.docker.com/builds/
RUN curl -fsSLO https://download.docker.com/linux/static/stable/x86_64/docker-17.03.2-ce.tgz && \
    tar --strip-components=1 -xvzf docker-17.03.2-ce.tgz -C /usr/local/bin
ENV SHARED_DOCKER_SERVICE true

# Firefox 45.9.0 - esr
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

EXPOSE 5942

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

# Set SUID and SGID for docker binary so it can communicate with mapped socket its uid:gid we can not control. Alternative
# approach used for this is adding ath-user to the group of /var/run/docker.sock but that require root permission we do not
# have in ENTRYPOINT as the container is started as ath-user.
COPY --chown=ath-user:jenkins run.sh $HOME
COPY --chown=ath-user:jenkins vnc.sh $HOME
COPY agent.jar ${AGENT_WORKDIR}
RUN chmod a+x $HOME/vnc.sh && chmod a+x $HOME/run.sh
USER root
RUN chmod ug+s "$(which docker)"
