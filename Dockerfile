# THIS IS A WORK IN PROGRESS!

# How I'm running the container after building it:
#docker run -d --name sagetv-client \
#  -v /mnt/vms/docker-config/sagetv:/config \
#  -p 3389:3389 -p 8080:8080 -p 8081:8081 \
#  -t coppit/sagetv-client

FROM hurricane/dockergui:x11rdp1.3

MAINTAINER David Coppit <david@coppit.org>

ENV APP_NAME="SageTV Media Center Client"

# Use baseimage-docker's init system
CMD ["/sbin/my_init"]

ENV DEBIAN_FRONTEND noninteractive

# Speed up APT
RUN echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/02apt-speedup \
  && echo "Acquire::http {No-Cache=True;};" > /etc/apt/apt.conf.d/no-cache

# Remove built-in Java 7
RUN apt-get purge -y openjdk-\* icedtea\*

# Auto-accept Oracle JDK license
RUN echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections

# Install Oracle Java 8
RUN add-apt-repository ppa:webupd8team/java \
  && apt-get update \
  && apt-get install -y oracle-java8-installer

# Create dir to keep things tidy
RUN mkdir /files

RUN set -x \
  # For libfaac0
  && apt-add-repository multiverse \
  && apt-get update \
  && apt-get install -y unzip \
    build-essential libfaac0 \
    libx11-dev libxt-dev libraw1394-dev libavc1394-dev libiec61883-dev libfreetype6-dev yasm autoconf libtool

# Now let's fetch down a specific version of SageTV (for reproducible builds) and build it
RUN wget -O /files/sagetv.zip https://github.com/google/sagetv/archive/d9ed4ecbcf9cb8e8553f4fde56d345f552d8491a.zip

RUN unzip -d /files /files/sagetv.zip 

WORKDIR /files/sagetv-d9ed4ecbcf9cb8e8553f4fde56d345f552d8491a/build

# HACKS for 64-bit and newer Java
RUN set -x \
  && sed -i 's/i386/amd64/' ubuntufiles/client/DEBIAN/control \
  && sed -i 's/sun-java6-jre/oracle-java8-installer/' ubuntufiles/client/DEBIAN/control 

RUN export JDK_HOME=/usr/lib/jvm/java-8-oracle \
  && ./buildall.sh

# It seems like everything is statically linked. At least, startsage didn't complain about missing shared libs when I
# removed all this stuff.
RUN set -x \
  && apt-get purge -y unzip \
    build-essential \
    libx11-dev libxt-dev libraw1394-dev libavc1394-dev libiec61883-dev libfreetype6-dev yasm autoconf libtool \
  && apt-get autoremove -y \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# HACK: i386 is a lie here. It's amd64.
RUN dpkg -i sagetv-client_9.0.0_i386.deb

RUN rm -rf /files

WORKDIR /

VOLUME ["/config"]

# For RDP and Guacamole
EXPOSE 3389 8080 8081

# User/Group Id gui app will be executed as
ENV USER_ID=0
ENV GROUP_ID=0

# Default resolution
ENV WIDTH=1280
ENV HEIGHT=720

# Otherwise RDP rendering of the UI doesn't work right.
RUN sed -i 's/java -cp/java -Dsun.java2d.xrender=false -cp/' /opt/sagetv/client/sageclient.sh

COPY startapp.sh /startapp.sh
