#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
app_dir="${repo_root}/apps/flink/energy_market"
dependency_dir="${app_dir}/managed-flink-dependencies"
build_dir="${repo_root}/build/managed-flink"
stage_dir="${build_dir}/stage"
zip_path="${build_dir}/raw_fr_energy_grid_to_s3.zip"

if ! command -v zip >/dev/null 2>&1; then
  echo "Error: zip is required to build the Managed Flink application archive." >&2
  exit 1
fi

build_dependency_jar_from_downloads() {
  local jars_dir="${build_dir}/downloaded-jars"
  local unpack_dir="${build_dir}/dependency-jar"
  local failed=0

  if ! command -v curl >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1 || ! command -v jar >/dev/null 2>&1; then
    return 1
  fi

  rm -rf "${jars_dir}" "${unpack_dir}"
  mkdir -p "${jars_dir}" "${unpack_dir}"

  curl -fsSL \
    "https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka/3.2.0-1.19/flink-sql-connector-kafka-3.2.0-1.19.jar" \
    -o "${jars_dir}/flink-sql-connector-kafka.jar" || failed=1
  curl -fsSL \
    "https://repo1.maven.org/maven2/org/apache/flink/flink-parquet/1.19.1/flink-parquet-1.19.1.jar" \
    -o "${jars_dir}/flink-parquet.jar" || failed=1
  curl -fsSL \
    "https://repo1.maven.org/maven2/org/apache/parquet/parquet-hadoop-bundle/1.13.1/parquet-hadoop-bundle-1.13.1.jar" \
    -o "${jars_dir}/parquet-hadoop-bundle.jar" || failed=1
  curl -fsSL \
    "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-mapreduce-client-core/3.3.4/hadoop-mapreduce-client-core-3.3.4.jar" \
    -o "${jars_dir}/hadoop-mapreduce-client-core.jar" || failed=1

  if [ "${failed}" -ne 0 ]; then
    return 1
  fi

  for jar_path in "${jars_dir}"/*.jar; do
    unzip -oq "${jar_path}" -d "${unpack_dir}"
  done

  rm -f "${unpack_dir}/META-INF/"*.SF "${unpack_dir}/META-INF/"*.DSA "${unpack_dir}/META-INF/"*.RSA
  (
    cd "${unpack_dir}"
    jar cf "${dependency_dir}/target/pyflink-dependencies.jar" .
  )

  test -s "${dependency_dir}/target/pyflink-dependencies.jar"
}

mkdir -p "${dependency_dir}/target"

if command -v mvn >/dev/null 2>&1; then
  mvn -q -f "${dependency_dir}/pom.xml" package
elif build_dependency_jar_from_downloads; then
  true
elif command -v docker >/dev/null 2>&1; then
  docker run --rm \
    -v "${repo_root}:/workspace" \
    -w "/workspace/apps/flink/energy_market/managed-flink-dependencies" \
    maven:3.9-eclipse-temurin-17 \
    mvn -q package
else
  echo "Error: mvn, public Maven artifact downloads, or docker is required to build the Managed Flink dependency jar." >&2
  exit 1
fi

test -s "${dependency_dir}/target/pyflink-dependencies.jar"

rm -rf "${stage_dir}"
mkdir -p "${stage_dir}/jobs" "${stage_dir}/lib"

cp "${app_dir}/pyproject.toml" "${stage_dir}/"
cp "${app_dir}/jobs/"*.py "${stage_dir}/jobs/"
cp "${dependency_dir}/target/pyflink-dependencies.jar" "${stage_dir}/lib/pyflink-dependencies.jar"

rm -f "${zip_path}"
(
  cd "${stage_dir}"
  zip -qr "${zip_path}" .
)

echo "${zip_path}"
