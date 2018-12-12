FROM openshift/jenkins-slave-maven-centos7

USER root
RUN yum clean all && \
    yum -y update && \
    yum install -y \
        ImageMagick \
        vnc4server \
        fluxbox \
        gtk2 \
        gtk3 \
        yum-utils \
        device-mapper-persistent-data \
        lvm2 \
        apt-transport-https \
        ca-certificates \
        software-properties-common \
        device-mapper-persistent-data \
        svn

# Download tigervnc-server-1.8.0-5.el7
RUN curl https://www.rpmfind.net/linux/centos/7.5.1804/os/x86_64/Packages/tigervnc-server-1.8.0-5.el7.x86_64.rpm --output tigervnc.rpm && \
yum localinstall -y tigervnc.rpm

# All we need is a statically linked client library - no need to install daemon deps: https://get.docker.com/builds/
RUN curl -fsSLO https://download.docker.com/linux/static/stable/x86_64/docker-17.03.2-ce.tgz && \
    tar --strip-components=1 -xvzf docker-17.03.2-ce.tgz -C /usr/local/bin
ENV SHARED_DOCKER_SERVICE true

# Selenium needs a geckodriver in order to work properly
RUN curl -fsSLO https://github.com/mozilla/geckodriver/releases/download/v0.22.0/geckodriver-v0.22.0-linux64.tar.gz && \
tar -xvzf geckodriver-v0.22.0-linux64.tar.gz -C /usr/local/bin

# Download firefox 45.9.0 - esr to /tmp & extract
ADD https://ftp.mozilla.org/pub/firefox/releases/45.9.0esr/linux-x86_64/en-US/firefox-45.9.0esr.tar.bz2 /tmp
RUN tar xvjf /tmp/firefox-45.9.0esr.tar.bz2

# Allow injecting uid and git to match directory ownership
ARG user=ath-user
ARG group=jenkins
ARG uid=1001
ARG gid=1000

ENV uid $uid
ENV gid $gid
ENV HOME /home/${user}
RUN groupadd -g ${gid} ${group}
RUN useradd -c "Jenkins user" -d $HOME -u ${uid} -g ${gid} -G 0 -m ${user}
LABEL Description="This is a base image, which provides the Jenkins agent executable (slave.jar)" Vendor="Jenkins project" Version="3.27"

EXPOSE 50000

SHELL ["/bin/bash", "-c"]
# So it is owned by root and has the permissions vncserver seems to require:
RUN chmod 1777 /tmp/.X11-unix/

USER ${user}
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
RUN mkdir -p src/main; \
    cd src/main; \
    svn checkout https://github.com/jenkinsci/acceptance-test-harness/trunk/src/main/tool_installers

# Set SUID and SGID for docker binary so it can communicate with mapped socket its uid:gid we can not control. Alternative
# approach used for this is adding ath-user to the group of /var/run/docker.sock but that require root permission we do not
# have in ENTRYPOINT as the container is started as ath-user.
USER root
RUN chmod ug+s "$(which docker)"

RUN eval $(./vnc.sh)