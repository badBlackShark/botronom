FROM crystallang/crystal

RUN mkdir /app
COPY . /app
WORKDIR /app
RUN shards update
RUN shards build
ENTRYPOINT /app/bin/botronom
