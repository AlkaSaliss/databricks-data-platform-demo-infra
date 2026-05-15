FROM apache/flink:1.19.1-scala_2.12-java17

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/energy-market-flink

ADD https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka/3.2.0-1.19/flink-sql-connector-kafka-3.2.0-1.19.jar /opt/flink/lib/
ADD https://repo1.maven.org/maven2/org/apache/flink/flink-parquet/1.19.1/flink-parquet-1.19.1.jar /opt/flink/lib/

COPY pyproject.toml ./
COPY jobs ./jobs

RUN ln -sf /opt/flink/opt/flink-s3-fs-hadoop-*.jar /opt/flink/lib/ \
    && python3 -m pip install --no-cache-dir .

USER flink
