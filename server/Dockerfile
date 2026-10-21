# The Forgotten Server 1.4.2, the official release for Tibia client 10.98, built from the source in this folder.
FROM ubuntu:22.04 AS build
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential cmake \
    libluajit-5.1-dev libmysqlclient-dev libpugixml-dev libcrypto++-dev libfmt-dev \
    libboost-system-dev libboost-iostreams-dev libboost-filesystem-dev libboost-date-time-dev \
 && rm -rf /var/lib/apt/lists/*
COPY cmake /src/cmake/
COPY src /src/src/
COPY CMakeLists.txt /src/
WORKDIR /src/build
# Today's compilers warn about things the 1.4.2 sources predate; keep those as warnings, not errors.
RUN sed -i 's/ -Werror//' ../CMakeLists.txt \
 && cmake -DCMAKE_BUILD_TYPE=Release .. \
 && make -j"$(nproc)"

FROM ubuntu:22.04
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    libluajit-5.1-2 libmysqlclient21 libpugixml1v5 libcrypto++8 libfmt8 \
    libboost-system1.74.0 libboost-iostreams1.74.0 libboost-filesystem1.74.0 libboost-date-time1.74.0 \
    mariadb-client tzdata \
 && rm -rf /var/lib/apt/lists/*
COPY --from=build /src/build/tfs /usr/local/bin/tfs
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
# Strip Windows line endings in case the repo was checked out with them.
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh \
 && useradd --create-home --uid 1000 tfs
USER tfs
WORKDIR /srv
EXPOSE 7171 7172
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
