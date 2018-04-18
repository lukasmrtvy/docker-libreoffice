####################################################################

FROM ubuntu:17.10 as builder

ENV POCO_VERSION 1.2.59
ENV LIBPNG_VERSION 1.9.0
ENV LO_VERSION 6.0.3.2

RUN apt-get update && apt-get install -y build-essential  curl dpkg-dev devscripts zlib1g-dev checkinstall
RUN mkdir /tmp/libpng && curl -sSL https://netcologne.dl.sourceforge.net/project/libpng/libpng12/${LIBPNG_VERSION}/libpng-${LIBPNG_VERSION}.tar.gz  | tar xz -C /tmp/libpng --strip-components=1
WORKDIR /tmp/libpng 
RUN ./configure --prefix=/opt/libpng
RUN make check
RUN make install -j $(getconf _NPROCESSORS_ONLN)

####################################################################

RUN apt update && apt-get install -y libssl-dev openssl
RUN mkdir -p /tmp/poco && curl -sSL https://pocoproject.org/releases/poco-${POCO_VERSION}/poco-${POCO_VERSION}-all.tar.gz | tar xz -C /tmp/poco  --strip-components=1
WORKDIR /tmp/poco
RUN ./configure --prefix=/opt/poco
RUN make -s install -j $(getconf _NPROCESSORS_ONLN)

####################################################################

RUN apt-get install -y gstreamer1.0-libav libkrb5-dev nasm graphviz ccache


RUN sed -Ei 's/^# deb-src/deb-src/' /etc/apt/sources.list
RUN apt-get update && apt-get build-dep -y libreoffice
RUN apt-get install libkrb5-dev nasm
RUN mkdir /tmp/libreoffice && curl -sSL https://github.com/LibreOffice/core/archive/libreoffice-${LO_VERSION}.tar.gz | tar xz -C  /tmp/libreoffice --strip-components=1
WORKDIR /tmp/libreoffice
RUN  echo "lo_sources_ver=${LO_VERSION}" > sources.ver
COPY autogen.input /tmp/libreoffice/
RUN apt install -y uuid-runtime # uuidgen
COPY make.fetch.patch /tmp/libreoffice/
RUN patch < make.fetch.patch
RUN rm -rf /tmp/libreoffice/dictionaries /tmp/libreoffice/translations
RUN ./autogen.sh
RUN make -j $(getconf _NPROCESSORS_ONLN)



##################################################################

RUN mkdir -p /opt/libreoffice
RUN cp -a /tmp/libreoffice/instdir /opt/libreoffice


RUN mkdir -p /usr/share/hunspell
RUN mkdir -p /usr/share/hyphen
RUN mkdir -p /opt/lool/systemplate/usr/share/hyphen
RUN mkdir -p /usr/share/mythes



RUN for i in `find /tmp/libreoffice/instdir/share/extensions/ -name hyph*.dic`;do cp -a $i /opt/lool/systemplate/usr/share/hyphen;done
RUN for i in `find /tmp/libreoffice/instdir/share/extensions/ -name hyph*.dic`;do cp -a $i /usr/share/hyphen;done
RUN cp -a /tmp/libreoffice/instdir/share/extensions/dict-en/en_US.* /usr/share/hunspell
RUN cp -a /tmp/libreoffice/instdir/share/extensions/dict-en/en_GB.* /usr/share/hunspell
RUN cp -a /tmp/libreoffice/instdir/share/extensions/dict-it/it_IT.* /usr/share/hunspell
RUN cp -a /tmp/libreoffice/instdir/share/extensions/dict-nl/nl_NL.* /usr/share/hunspell
RUN cp -a /tmp/libreoffice/instdir/share/extensions/dict-pl/pl_PL.* /usr/share/hunspell
RUN cp -a /tmp/libreoffice/instdir/share/extensions/dict-ru/ru_RU.* /usr/share/hunspell
RUN cp -a /tmp/libreoffice/instdir/share/extensions/dict-pt-BR/pt_BR.* /usr/share/hunspell
RUN cp -a /tmp/libreoffice/instdir/share/extensions/dict-pt-PT/pt_PT.* /usr/share/hunspell
RUN cp -a /tmp/libreoffice/instdir/share/extensions/dict-fr/fr.dic /usr/share/hunspell/fr_FR.dic
RUN cp -a /tmp/libreoffice/instdir/share/extensions/dict-fr/fr.aff /usr/share/hunspell/fr_FR.aff
RUN cp -a /tmp/libreoffice/instdir/share/extensions/dict-es/es_ANY.dic /usr/share/hunspell/es_ES.dic
RUN cp -a /tmp/libreoffice/instdir/share/extensions/dict-es/es_ANY.aff /usr/share/hunspell/es_ES.aff
RUN cp -a /tmp/libreoffice/instdir/share/extensions/dict-de/de_AT_frami.dic /usr/share/hunspell/de_AT.dic
RUN cp -a /tmp/libreoffice/instdir/share/extensions/dict-de/de_AT_frami.aff /usr/share/hunspell/de_AT.aff
RUN cp -a /tmp/libreoffice/instdir/share/extensions/dict-de/de_CH_frami.dic /usr/share/hunspell/de_CH.dic
RUN cp -a /tmp/libreoffice/instdir/share/extensions/dict-de/de_CH_frami.aff /usr/share/hunspell/de_CH.aff
RUN cp -a /tmp/libreoffice/instdir/share/extensions/dict-de/de_DE_frami.dic /usr/share/hunspell/de_DE.dic
RUN cp -a /tmp/libreoffice/instdir/share/extensions/dict-de/de_DE_frami.aff /usr/share/hunspell/de_DE.aff
RUN for i in de en fr it pl pt-PT ru;do cp -a /tmp/libreoffice/instdir/share/extensions/dict-$i/th_* /usr/share/mythes;done

###################################################################

RUN apt-get update && apt-get install -y libcppunit-dev libcppunit-doc pkg-config sudo cpio 
RUN apt-get update && apt install -y  libtool m4 automake 
RUN mkdir /tmp/libreoffice-online && curl -sSL https://github.com/LibreOffice/online/archive/libreoffice-${LO_VERSION}.tar.gz | tar xz -C  /tmp/libreoffice-online --strip-components=1
WORKDIR /tmp/libreoffice-online
RUN apt-get update && apt install -y libcap2-bin libcap-dev
RUN apt install -y npm python-polib node-jake
RUN ./autogen.sh
RUN ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --enable-silent-rules --with-lokit-path=/tmp/libreoffice/include --with-lo-path=/tmp/libreoffice/instdir --enable-debug --with-poco-includes=/opt/poco/include --with-poco-libs=/opt/poco/lib --with-libpng-includes=/opt/libpng/include --with-libpng-libs=/opt/libpng/lib --with-max-connections=100000 --with-max-documents=100000

####################################################################

RUN apt install -y wget translate-toolkit

RUN scripts/downloadpootle.sh
RUN cd loleaflet && make l10n

RUN scripts/locorestrings.py /tmp/libreoffice-online/ /tmp/libreoffice/translations
RUN scripts/unocommands.py --update /tmp/libreoffice-online /tmp/libreoffice/libreoffice
RUN scripts/unocommands.py --translate /tmp/libreoffice-online /tmp/libreoffice/libreoffice/translations

####################################################################


RUN make -j $(getconf _NPROCESSORS_ONLN)
RUN make install -j $(getconf _NPROCESSORS_ONLN)


####################################################################

#FROM ubuntu:17.10

#COPY --from=builder  /usr/share/hunspell/ /usr/share/hunspell/
#COPY --from=builder/usr/share/hyphen /usr/share/hyphen
#COPY --from=builder /opt/lool/systemplate/usr/share/hyphen /opt/lool/systemplate/usr/share/hyphen
#COPY --from=builder /usr/share/mythes /usr/share/mythes
#COPY --from=builder /tmp/libreoffice/instdir/ /opt/libreoffice/


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

RUN loolwsd-systemplate-setup /opt/lool/systemplate /opt/libreoffice/

USER lool

EXPOSE 9980

ENTRYPOINT /usr/bin/loolwsd --version --o:sys_template_path=/opt/lool/systemplate --o:lo_template_path=/opt/libreoffice --o::child_root_path=/opt/lool/child-roots --o:file_server_root_path=/usr/share/libreoffice-online
