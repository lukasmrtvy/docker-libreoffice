####################################################################

FROM ubuntu:17.10 as builder

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

RUN apt-get install -y gstreamer1.0-libav libkrb5-dev nasm graphviz ccache


RUN sed -Ei 's/^# deb-src/deb-src/' /etc/apt/sources.list
RUN apt-get update && apt-get build-dep -y libreoffice
RUN apt-get install libkrb5-dev nasm
RUN mkdir /tmp/libreoffice && curl -sSL https://github.com/LibreOffice/core/archive/libreoffice-6.0.0.3.tar.gz | tar xz -C  /tmp/libreoffice --strip-components=1
WORKDIR /tmp/libreoffice
RUN  echo "lo_sources_ver=6.0.0.3" > sources.ver
COPY autogen.input /tmp/libreoffice/
RUN apt install -y uuid-runtime # uuidgen
COPY make.fetch.patch /tmp/libreoffice/
RUN patch < make.fetch.patch
RUN rm -rf /tmp/libreoffice/dictionaries /tmp/libreoffice/translations
RUN ./autogen.sh
RUN make -j $(getconf _NPROCESSORS_ONLN)

###################################################################

RUN apt-get update && apt-get install -y libcppunit-dev libcppunit-doc pkg-config sudo cpio 
RUN apt-get update && apt install -y  libtool m4 automake 
RUN mkdir /tmp/libreoffice-online && curl -sSL https://github.com/LibreOffice/online/archive/libreoffice-6.0.0.3.tar.gz | tar xz -C  /tmp/libreoffice-online --strip-components=1
WORKDIR /tmp/libreoffice-online
RUN apt-get update && apt install -y libcap2-bin libcap-dev
RUN apt install -y npm python-polib node-jake
RUN ./autogen.sh
RUN ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --enable-silent-rules --with-lokit-path=/tmp/libreoffice/include --with-lo-path=/tmp/libreoffice/instdir --enable-debug --with-poco-includes=/opt/poco/include --with-poco-libs=/opt/poco/lib --with-libpng-includes=/opt/libpng/include --with-libpng-libs=/opt/libpng/lib --with-max-connections=100000 --with-max-documents=100000

RUN make -j $(getconf _NPROCESSORS_ONLN)
RUN make install -j $(getconf _NPROCESSORS_ONLN)

RUN echo a

RUN ls -lha /usr/share/libreoffice-online
RUN ls -lha /etc/libreoffice-online
#RUN find / -iname "*lool*"
RUN ls -lha /var/cache

RUN ls -lha /tmp/libreoffice/instdir

####################################################################

#FROM ubuntu:17.10

#COPY --from=builder /usr/lool /usr/


#RUN ls -lha /tmp/libreoffice-online

RUN sed -i  "s/<enable type=\"bool\" default=\"true\">true<\/enable>/<enable type=\"bool\" default=\"true\">false<\/enable>/g"  /etc/libreoffice-online/loolwsd.xml

RUN setcap cap_fowner,cap_mknod,cap_sys_chroot=ep /usr/bin/loolforkit
RUN setcap cap_sys_admin=ep /usr/bin/loolmount
RUN adduser --quiet --system --group --home /opt/lool lool
RUN mkdir -p /var/cache/libreoffice-online && chown lool: /var/cache/libreoffice-online
RUN rm -rf /var/cache/libreoffice-online/*
RUN rm -rf /opt/lool
RUN mkdir -p /opt/lool/child-roots
RUN ls -lha /tmp/libreoffice-online
RUN cp -R /tmp/libreoffice-online/systemplate/ /opt/lool/
RUN cp -R /tmp/libreoffice/instdir/. /opt/libreoffice/
RUN chown lool: /opt/lool
RUN chown lool: /opt/lool/child-roots
#WORKDIR /tmp/libreoffice-online/
#RUN su lool --shell=/bin/sh -c "./loolwsd-systemplate-setup /opt/lool/systemplate /tmp/libreoffice"
#RUN loolwsd-systemplate-setup /tmp/libreoffice-online/systemplate /tmp/libreoffice
#RUN find / -iname "*systemplate*"
RUN loolwsd-systemplate-setup /opt/lool/systemplate /opt/libreoffice/


#RUN touch /var/log/loolwsd.log
#RUN chown lool /var/log/loolwsd.log

#RUN echo a

#RUN ls -lha /tmp/libreoffice-online

USER lool

ENTRYPOINT /usr/bin/loolwsd --version --o:sys_template_path=/opt/lool/systemplate --o:lo_template_path=/opt/libreoffice --o::child_root_path=/opt/lool/child-roots --o:file_server_root_path=/usr/share/libreoffice-online
