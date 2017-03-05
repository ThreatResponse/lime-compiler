FROM ruby:2.3
MAINTAINER jf@threatresponse.cloud

# Switch to testing packages to get gpg v2.1+
RUN sed -i 's/jessie main/testing main/g' /etc/apt/sources.list
RUN apt-get update && apt-get install -y gnupg2
ADD Gemfile /opt/Gemfile
RUN gem install bundler specific_install
RUN bundle install --gemfile=/opt/Gemfile
RUN gem specific_install -l https://github.com/ThreatResponse/lime-compiler.git

VOLUME /opt/archive
VOLUME /opt/build
VOLUME /opt/conf
VOLUME /var/run/docker.sock

WORKDIR /opt

ENTRYPOINT ["/bin/bash", "-c"]
CMD ["lime-compiler -c $CONFIG_PATH -m $BUILD_ROOT -a $ARCHIVE_ROOT $SIGNING_ARGS $OPTIONAL_ARGS"]
