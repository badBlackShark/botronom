FROM jrei/crystal-alpine

RUN mkdir /app
COPY . /app
WORKDIR /app
RUN shards build
ENTRYPOINT /app/bin/botronom
