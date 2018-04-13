#http://oaeproject.org/2017/10/11/getting-started-with-libreoffice-online.html

####################################################################

FROM ubuntu:17.10

RUN apt-get update && apt-get install -y build-essential  curl dpkg-dev devscripts zlib1g-dev checkinstall
RUN mkdir /tmp/libpng && curl -sSL https://netcologne.dl.sourceforge.net/project/libpng/libpng12/1.2.59/libpng-1.2.59.tar.gz  | tar xz -C /tmp/libpng --strip-components=1
WORKDIR /tmp/libpng 
RUN ./configure --prefix=/opt/libpng
RUN make check
RUN make install -j $(getconf _NPROCESSORS_ONLN)

####################################################################

RUN apt update && apt-get install -y libssl-dev openssl
RUN mkdir -p /tmp/poco && curl -sSL https://pocoproject.org/releases/poco-1.9.0/poco-1.9.0-all.tar.gz | tar xz -C /tmp/poco  --strip-components=1
WORKDIR /tmp/poco
RUN ./configure --prefix=/opt/poco
RUN make -s install -j $(getconf _NPROCESSORS_ONLN)

####################################################################

RUN sed -Ei 's/^# deb-src/deb-src/' /etc/apt/sources.list
RUN apt-get update && apt-get build-dep -y libreoffice
RUN apt-get install libkrb5-dev nasm
RUN mkdir /tmp/libreoffice && curl -sSL https://github.com/LibreOffice/core/archive/libreoffice-6.0.0.3.tar.gz | tar xz -C  /tmp/libreoffice --strip-components=1
WORKDIR /tmp/libreoffice
RUN  echo "lo_sources_ver=6.0.0.3" > sources.ver
RUN ./autogen.sh
RUN make
#RUN ./configure --prefix=/opt/libreoffice
#RUN make install -j $(getconf _NPROCESSORS_ONLN)
RUN export MASTER=$(pwd)
####################################################################

RUN apt-get update && apt-get install -y libcppunit-dev libcppunit-doc pkg-config
RUN apt-get update && apt install -y  libtool m4 automake 
RUN mkdir /tmp/libreoffice-online && curl -sSL https://github.com/LibreOffice/online/archive/libreoffice-6.0.0.3.tar.gz | tar xz -C  /tmp/libreoffice-online --strip-components=1
WORKDIR /tmp/libreoffice-online
RUN apt-get update && apt install -y libcap2-bin libcap-dev
RUN ./autogen.sh
RUN ./configure --prefix=/opt/lool --enable-silent-rules --with-lokit-path=${MASTER}/include --with-lo-path=${MASTER}/instdir --enable-debug --with-poco-includes=/opt/poco/include --with-poco-libs=/opt/poco/lib --with-libpng-includes=/opt/libpng/include --with-libpng-libs=/opt/libpng/lib --with-max-connections=100000 --with-max-documents=100000
RUN make
#RUN  make install -j $(getconf _NPROCESSORS_ONLN)

####################################################################

RUN sed -i  "s/<enable type=\"bool\" default=\"true\">true<\/enable>/<enable type=\"bool\" default=\"true\">false<\/enable>/g"  /etc/libreoffice/loolwsd.xml

RUN setcap cap_fowner,cap_mknod,cap_sys_chroot=ep /usr/bin/loolforkit
RUN setcap cap_sys_admin=ep /usr/bin/loolmount
RUN adduser --quiet --system --group --home /opt/lool lool
RUN mkdir -p /var/cache/loolwsd && chown lool: /var/cache/loolwsd
RUN rm -rf /var/cache/loolwsd/*
RUN rm -rf /opt/lool
RUN mkdir -p /opt/lool/child-roots
RUN chown lool: /opt/lool
RUN chown lool: /opt/lool/child-roots
RUN su lool --shell=/bin/sh -c "loolwsd-systemplate-setup /opt/lool/systemplate /opt/libreoffice"
RUN touch /var/log/loolwsd.log
RUN chown lool /var/log/loolwsd.log

USER lool

ENTRYPOINT /usr/bin/loolwsd --version --o:sys_template_path=/opt/lool/systemplate --o:lo_template_path=/opt/libreoffice5.4 --o:child_root_path=/opt/lool/child-roots --o:file_server_root_path=/usr/share/libreoffice-online
