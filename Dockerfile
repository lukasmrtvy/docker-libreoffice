#http://oaeproject.org/2017/10/11/getting-started-with-libreoffice-online.html


####################################################################

FROM ubuntu:17.10 as libpng-builder
RUN apt-get update && apt-get install -y build-essential  curl dpkg-dev devscripts zlib1g-dev
RUN mkdir /tmp/libpng && curl -sSL https://netcologne.dl.sourceforge.net/project/libpng/libpng12/1.2.59/libpng-1.2.59.tar.gz  | tar xz -C /tmp/libpng --strip-components=1
WORKDIR /tmp/libpng
RUN ./configure
RUN make install

#RUN make check
#RUN apt-get install checkinstall
#RUN checkinstall -y

####################################################################


RUN mkdir -p /tmp/poco && curl -sSL https://pocoproject.org/releases/poco-1.9.0/poco-1.9.0.tar.gz | tar xz -C /tmp/poco  --strip-components=1
WORKDIR /tmp/poco
RUN ./configure --prefix=/opt/poco
RUN make -j $(getconf _NPROCESSORS_ONLN)


#RUN apt-get update && apt-get install -y software-properties-common
#RUN add-apt-repository universe
#RUN apt-get update && apt-get install -y poco

####################################################################



#FROM ubuntu:17.10 as libreoffice-builder
RUN sed -Ei 's/^# deb-src/deb-src/' /etc/apt/sources.list
RUN apt-get update && apt-get build-dep -y libreoffice
RUN apt-get install libkrb5-dev nasm
RUN mkdir /tmp/libreoffice && curl -sSL https://github.com/LibreOffice/core/archive/libreoffice-6.0.0.3.tar.gz | tar xz -C  /tmp/libreoffice --strip-components=1
WORKDIR /tmp/libreoffice
RUN  echo "lo_sources_ver=6.0.0.3" > sources.ver
RUN cat sources.ver
RUN ./autogen.sh
RUN make
RUN export MASTER=$(pwd)

####################################################################

#FROM ubuntu:17.10 as libreoffice-online-builder
RUN apt-get update && apt-get install libcppunit-dev libcppunit-doc pkg-config
RUN mkdir /tmp/libreoffice-online && curl -sSL https://github.com/LibreOffice/online/archive/libreoffice-6.0.0.3.tar.gz | tar xz -C  /tmp/libreoffice-online --strip-components=1
WORKDIR /tmp/libreoffice-online
RUN ./configure --enable-silent-rules --with-lokit-path=${MASTER}/include --with-lo-path=${MASTER}/instdir --enable-debug --with-poco-includes=/opt/poco/include --with-poco-libs=/opt/poco/lib
RUN ./autogen.sh
RUN  make

###################################################################
###################################################################

#FROM ubuntu:17.10

#COPY --from=libpng-builder /tmp/libpng/libpng_0-1_amd64.deb /tmp/

# get the latest fixes
RUN apt-get update && apt-get upgrade -y

# install LibreOffice run-time dependencies
# install apt-transport-https in order to set up repo for Poco
# install adduser, findutils and cpio that we need later
RUN apt-get -y install apt-transport-https locales-all libxinerama1 libgl1-mesa-glx libfontconfig1 libfreetype6 libxrender1 libxcb-shm0 libxcb-render0 adduser cpio findutils

# set up 3rd party repo of Poco, dependency of loolwsd
#RUN echo "deb https://collaboraoffice.com/repos/Poco/ /" >> /etc/apt/sources.list.d/poco.list
#RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 0C54D189F4BA284D
#RUN apt-get update
#RUN apt-get -y install libpoco*48

RUN dpkg -i /tmp/libpng_0-1_amd64.deb

# copy freshly built LibreOffice master and LibreOffice Online master with latest translations
COPY /instdir /

# copy the shell script which can start LibreOffice Online (loolwsd)
COPY /scripts/run-lool.sh /

# set up LibreOffice Online (normally done by postinstall script of package)
RUN setcap cap_fowner,cap_mknod,cap_sys_chroot=ep /usr/bin/loolforkit
RUN setcap cap_sys_admin=ep /usr/bin/loolmount
RUN adduser --quiet --system --group --home /opt/lool lool
RUN mkdir -p /var/cache/loolwsd && chown lool: /var/cache/loolwsd
RUN rm -rf /var/cache/loolwsd/*
RUN rm -rf /opt/lool
RUN mkdir -p /opt/lool/child-roots
RUN chown lool: /opt/lool
RUN chown lool: /opt/lool/child-roots
RUN su lool --shell=/bin/sh -c "loolwsd-systemplate-setup /opt/lool/systemplate /opt/libreoffice >/dev/null 2>&1"
RUN touch /var/log/loolwsd.log
RUN chown lool /var/log/loolwsd.log
CMD bash /run-lool.sh
