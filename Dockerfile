FROM openshift/jenkins-slave-maven-centos7 
MAINTAINER ayosef@redhat.com 
# <-- Download all packeges for all tasks -->
    USER root
    RUN yum clean all && \
        yum -y update && \
        yum install -y \
            sudo \
            ImageMagick \
            vnc4server \
            fluxbox \
            gcc \
            python-virtualenv \
            redhat-rpm-config \
            gtk2 \
            gtk3 \
            yum-utils \
            device-mapper-persistent-data \
            lvm2 \
            apt-transport-https \
            ca-certificates \
            software-properties-common \
            firefox && \
        yum groupinstall -y "X Window System" "Desktop" "Fonts" 
            
    # script for CA 
    ADD modify.sh /modify.sh
    RUN sh /modify.sh

    # Download tigervnc-server-1.8.0-5.el7
    RUN curl ftp://ftp.icm.edu.pl/vol/rzm3/linux-slc/centos/7.5.1804/os/x86_64/Packages/tigervnc-server-1.8.0-5.el7.x86_64.rpm --output tigervnc.rpm && \
    yum localinstall -y tigervnc.rpm

    # Selenium needs a geckodriver in order to work properly
    RUN curl -fsSLO https://github.com/mozilla/geckodriver/releases/download/v0.22.0/geckodriver-v0.22.0-linux64.tar.gz && \
    tar -xvzf geckodriver-v0.22.0-linux64.tar.gz -C /usr/local/bin

# Allow injecting uid and git to match directory ownership
ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000

EXPOSE 5901 

ENV uid $uid
ENV gid $gid
ENV HOME /home/${user}
RUN groupadd -g ${gid} ${group}
RUN useradd -c "ATH-jenkins user" -d $HOME -u ${uid} -g ${gid} -G 0 -m ${user}

SHELL ["/bin/bash", "-c"]

# <-- Docker TASK -->
    # Add RHEL 7 extras repo
    ARG rhelRepoPath=/etc/yum.repos.d/rhel-extras.repo
    RUN echo "[RHEL 7 Extras Repo]" >> ${rhelRepoPath};\
        echo "name=rhel_extras" >> ${rhelRepoPath};\
        echo "baseurl=http://pulp.dist.prod.ext.phx2.redhat.com/content/dist/rhel/server/7/7Server/x86_64/extras/os/"  >> ${rhelRepoPath};\
        echo "enabled=1" >> ${rhelRepoPath};\
        echo "gpgcheck=0" >> ${rhelRepoPath}

    # Add upstream Docker repo
    ARG dockerRepoPath=/etc/yum.repos.d/docker-repo.repo
    RUN echo "[Docker CE Repo]" >> ${dockerRepoPath};\
        echo "docker_repo" >> ${dockerRepoPath};\
        echo "baseurl=https://download-stage.docker.com/linux/centos/7/$basearch/stable" >> ${dockerRepoPath};\
        echo "enabled=1" >> ${dockerRepoPath};\
        echo "gpgcheck=1"  >> ${dockerRepoPath};\
        echo "gpgkey=https://download-stage.docker.com/linux/centos/gpg" >> ${dockerRepoPath};

    # Create Docker config directory
    RUN mkdir -p /etc/systemd/docker.service.d && chmod -R 0755 /etc/systemd/docker.service.d

    # Add Docker config with Red Hat Registry
    ARG dockerSrc=https://gitlab.cee.redhat.com/ci-ops/jenkins-update-centers/raw/master/playbooks/acceptance-test-harness/files/docker.conf
    ARG dockerDst=/etc/systemd/docker.service.d/docker.conf
    RUN curl ${dockerSrc} --output ${dockerDst}  && chmod 0644 ${dockerDst}

    # Add Jenkins user to Docker group
    RUN sudo groupadd docker;sudo usermod -aG docker ${user} 

    # Reload systemd to pick up new Docker config
    # RUN sudo systemctl daemon-reload

    # Restart Docker to pick up new config
    # RUN sudo systemctl docker restart

    # < -- we might wanna use it instead..?(can't run systemctl inside of container) -->
    # # All we need is a statically linked client library - no need to install daemon deps: https://get.docker.com/builds/
    RUN curl -fsSLO https://download.docker.com/linux/static/stable/x86_64/docker-17.03.2-ce.tgz && \
        tar --strip-components=1 -xvzf docker-17.03.2-ce.tgz -C /usr/local/bin
    ENV SHARED_DOCKER_SERVICE true

# So it is owned by root and has the permissions vncserver seems to require:
RUN chmod 1777 /tmp/.X11-unix/

# TODO seems this can be picked up from the host, which is unwanted:
ENV XAUTHORITY /home/${user}/.Xauthority


# <-- VNC TASK -->
    # Create directory for jenkins VNC configuration
    RUN mkdir -p ${HOME}/.vnc && chmod -R 0755 ${HOME}/.vnc
    
    # Set VNC password for jenkins user
    RUN echo notsecure | vncpasswd -f > ${HOME}/.vnc/passwd

    # Set VNC password file permissions for jenkins user
    RUN chmod -R 0600 ${HOME}/.vnc/passwd

    # Add xstartup file for jenkins's VNC
    ARG VNCsrc=https://gitlab.cee.redhat.com/ci-ops/jenkins-update-centers/raw/master/playbooks/acceptance-test-harness/files/xstartup
    ARG VNCdest=${HOME}/.vnc/xstartup

    RUN curl ${VNCsrc} --output ${VNCdest} && chmod 0755 ${VNCdest}
    RUN chown -R ${user}:${group} ${HOME}/.vnc

USER ${user}
WORKDIR /home/${user}

# Prevent xauth to complain in a confusing way
RUN touch /home/${user}/.Xauthority

# Set SUID and SGID for docker binary so it can communicate with mapped socket its uid:gid we can not control. Alternative
# approach used for this is adding ath-user to the group of /var/run/docker.sock but that require root permission we do not
# have in ENTRYPOINT as the container is started as ath-user.
USER root
RUN chmod ug+s "$(which docker)"

RUN sudo chmod -R 777 ${HOME} /usr/local/bin/ \
    && sudo chgrp -R 0 ${HOME} /usr/local/bin/ \
    && sudo chmod -R g=u ${HOME} /usr/local/bin/
       
ADD run-jnlp-client /usr/local/bin/run-jnlp-client
RUN chmod a+x /usr/local/bin/run-jnlp-client
ENTRYPOINT ["/usr/local/bin/run-jnlp-client"]

USER 1000
