FROM docker.io/centos/s2i-core-centos7:latest

LABEL author=VSHN \
      io.k8s.description="Platform for running modsecurity" \
      io.k8s.display-name="modsecurity" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="modsecurity"

EXPOSE 8080

VOLUME /modsecurity

RUN yum update -y && \
    yum install \
        httpd \
        httpd-devel \
        mod_ssl \
        git \
        gcc-c++ \
        automake \
        make \
        libtool \
        flex \
        bison \
        yajl \
        yajl-devel \
        curl-devel \
        curl \
        GeoIP-devel \
        doxygen \
        zlib-devel \
        libxml2-devel \
        lmdb-devel \
        ssdeep-devel \
        lua-devel \
        pcre-devel \
        -y

RUN git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity && \
    cd ModSecurity && \
    sh build.sh && \
    git submodule init && \
    git submodule update && \
    ./configure && \
    make && \
    make install

RUN git clone --depth 1 -b master --single-branch https://github.com/SpiderLabs/ModSecurity-apache && \
    cd ModSecurity-apache && \
    ls -al && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install

# Copy the S2I scripts from the specific language image to $STI_SCRIPTS_PATH
COPY ./s2i/bin/ $STI_SCRIPTS_PATH

# Each language image can have 'contrib' a directory with extra files needed to
# run and build the applications.
COPY ./contrib/ /opt/app-root

RUN cp /opt/app-root/etc/httpd.conf /etc/httpd/conf/httpd.conf && \
    CRS_VERSION="3.0.2" && \
    curl -O "https://codeload.github.com/SpiderLabs/owasp-modsecurity-crs/tar.gz/v${CRS_VERSION}" && \
    tar xf "v${CRS_VERSION}" && \
    ln -s "/opt/app-root/src/owasp-modsecurity-crs-${CRS_VERSION}/" /opt/app-root/crs && \
    cp /opt/app-root/crs/crs-setup.conf.example /opt/app-root/crs/crs-setup.conf && \
    rm "v${CRS_VERSION}" && \
    mkdir /opt/app-root/rules && \
    mkdir /opt/app-root/errors && \
    mkdir -p /modsecurity/{audit,upload,tmp,data,apache}

# In order to drop the root user, we have to make some directories world
# writeable as OpenShift default security model is to run the container under
# random UID.
RUN chown -R 1001:0 /opt/app-root && \
    chmod -R ug+rwx /opt/app-root && \
    chmod -R a+rwx /var/run/httpd && \
    chown -R 1001:0 /modsecurity && \
    chmod -R ug+rwx /modsecurity

USER 1001:0

CMD ${STI_SCRIPTS_PATH}/usage
