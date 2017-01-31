FROM fedora:24
MAINTAINER jf@threatresponse.cloud

COPY build-info/docker.repo /etc/yum.repos.d/docker.repo

# Install rvm and ruby dependencies
RUN echo "deltarpm=0" >> /etc/dnf/dnf.conf && \
    dnf update -y && \
    dnf install -y which findutils procps-ng git gnupg2 docker-engine \
                   patch libyaml-devel glibc-headers autoconf gcc-c++ \
                   glibc-devel patch readline-devel zlib-devel \
                   libffi-devel openssl-devel make bzip2 automake \
                   libtool bison sqlite-devel && \
    dnf clean all

RUN gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 && \
    \curl -sSL https://get.rvm.io | bash -s stable

RUN /usr/local/rvm/bin/rvm install 2.3 && \
    bash -l -c "rvm use 2.3 --default"

RUN mkdir -p /opt/lime-compiler && \
    bash -l -c "gem install bundler && gem install specific_install"

ADD Gemfile /opt/lime-compiler/Gemfile

RUN bash -l -c "cd /opt/lime-compiler && bundle install && gem specific_install -l https://github.com/ThreatResponse/lime-compiler.git"

VOLUME /opt/lime-compiler/archive
VOLUME /opt/lime-compiler/build
VOLUME /opt/lime-compiler/conf
VOLUME /var/run/docker.sock

WORKDIR /opt/lime-compiler
