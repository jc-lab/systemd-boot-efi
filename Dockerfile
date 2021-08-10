FROM alpine:3.13 as builder

RUN apk update && \
    apk add \
    bash git make gcc binutils file libc-dev gnu-efi-dev

RUN mkdir -p /work/src
ADD [".", "/work/src"]

RUN cd /work/src && \
    git submodule update --init && \
    make && \
    sha256sum *.o *.so *.efi

FROM scratch
COPY --from=builder ["/work/src/linux*.efi", "/"]

