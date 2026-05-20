from pyspark import pipelines as dp
from pyspark.sql import functions as F


CATALOG = spark.conf.get("energy_market.catalog", "energy_market_demo")
BRONZE_SCHEMA = spark.conf.get("energy_market.bronze_schema", "bronze")
SILVER_SCHEMA = spark.conf.get("energy_market.silver_schema", "silver")
GOLD_SCHEMA = spark.conf.get("energy_market.gold_schema", "gold")
SOURCE_VOLUME_PATH = spark.conf.get(
    "energy_market.source_volume_path",
    "/Volumes/energy_market_demo/bronze/streaming_lake",
).rstrip("/")

RAW_TABLE = f"{CATALOG}.{BRONZE_SCHEMA}.raw_fr_energy_grid"
SILVER_TABLE = f"{CATALOG}.{SILVER_SCHEMA}.fr_energy_market_snapshots_15min"
GOLD_TABLE = f"{CATALOG}.{GOLD_SCHEMA}.fr_energy_market_kpis_daily"
SOURCE_PATH = f"{SOURCE_VOLUME_PATH}/bronze/raw_fr_energy_grid/"


def payload(path: str):
    return F.get_json_object(F.col("payload_json"), path)


def number(path: str):
    return payload(path).cast("double")


@dp.table(
    name=RAW_TABLE,
    comment="Raw France energy-grid events written by the local Flink bronze sink.",
)
def raw_fr_energy_grid():
    return (
        spark.readStream.format("cloudFiles")
        .option("cloudFiles.format", "parquet")
        .load(SOURCE_PATH)
    )


@dp.table(
    name=SILVER_TABLE,
    comment="Normalized France Eco2mix 15-minute energy market snapshots.",
    partition_cols=["country_code", "event_date"],
)
def fr_energy_market_snapshots_15min():
    source = spark.readStream.table(RAW_TABLE)

    consumption_mw = number("$.metric_value")
    forecast_current_day_mw = number("$.forecast_current_day_mw")
    oil_mw = F.coalesce(number("$.generation_mw.fioul"), F.lit(0.0))
    coal_mw = F.coalesce(number("$.generation_mw.charbon"), F.lit(0.0))
    gas_mw = F.coalesce(number("$.generation_mw.gaz"), F.lit(0.0))
    nuclear_mw = F.coalesce(number("$.generation_mw.nucleaire"), F.lit(0.0))
    wind_mw = F.coalesce(number("$.generation_mw.eolien"), F.lit(0.0))
    solar_mw = F.coalesce(number("$.generation_mw.solaire"), F.lit(0.0))
    hydro_mw = F.coalesce(number("$.generation_mw.hydraulique"), F.lit(0.0))
    bioenergy_mw = F.coalesce(number("$.generation_mw.bioenergies"), F.lit(0.0))

    total_generation_mw = (
        oil_mw
        + coal_mw
        + gas_mw
        + nuclear_mw
        + wind_mw
        + solar_mw
        + hydro_mw
        + bioenergy_mw
    )
    renewable_generation_mw = wind_mw + solar_mw + hydro_mw + bioenergy_mw
    fossil_generation_mw = oil_mw + coal_mw + gas_mw
    negative_generation = (
        F.least(
            oil_mw,
            coal_mw,
            gas_mw,
            nuclear_mw,
            wind_mw,
            solar_mw,
            hydro_mw,
            bioenergy_mw,
        )
        < 0
    )
    imbalance = (consumption_mw > 0) & (
        F.abs(consumption_mw - total_generation_mw) > consumption_mw * F.lit(0.2)
    )

    event_time = F.to_timestamp("source_event_time")
    quality_status = (
        F.when(consumption_mw.isNull(), F.lit("invalid"))
        .when(negative_generation, F.lit("invalid"))
        .when(imbalance, F.lit("warning"))
        .otherwise(F.lit("valid"))
    )
    quality_error_code = (
        F.when(consumption_mw.isNull(), F.lit("missing_consumption"))
        .when(negative_generation, F.lit("negative_generation"))
        .when(imbalance, F.lit("generation_imbalance"))
    )

    renewable_share = F.when(
        total_generation_mw != 0, renewable_generation_mw / total_generation_mw
    )
    fossil_share = F.when(total_generation_mw != 0, fossil_generation_mw / total_generation_mw)

    return source.select(
        F.col("event_id"),
        F.col("country_code"),
        F.col("source_system"),
        F.coalesce(payload("$.market_region"), F.lit("FR_NATIONAL")).alias("market_region"),
        event_time.alias("event_time"),
        F.to_timestamp("ingestion_time").alias("ingestion_time"),
        F.current_timestamp().alias("processing_time"),
        F.to_date(event_time).alias("event_date"),
        consumption_mw.alias("consumption_mw"),
        forecast_current_day_mw.alias("forecast_current_day_mw"),
        number("$.forecast_d_minus_1_mw").alias("forecast_d_minus_1_mw"),
        (consumption_mw - forecast_current_day_mw).alias("forecast_error_mw"),
        oil_mw.alias("oil_mw"),
        coal_mw.alias("coal_mw"),
        gas_mw.alias("gas_mw"),
        nuclear_mw.alias("nuclear_mw"),
        wind_mw.alias("wind_mw"),
        solar_mw.alias("solar_mw"),
        hydro_mw.alias("hydro_mw"),
        bioenergy_mw.alias("bioenergy_mw"),
        total_generation_mw.alias("total_generation_mw"),
        renewable_generation_mw.alias("renewable_generation_mw"),
        renewable_share.alias("renewable_share"),
        fossil_generation_mw.alias("fossil_generation_mw"),
        fossil_share.alias("fossil_share"),
        number("$.co2_intensity_g_per_kwh").alias("co2_intensity_g_per_kwh"),
        number("$.physical_exchanges_mw").alias("physical_exchanges_mw"),
        quality_status.alias("data_quality_status"),
        quality_error_code.alias("quality_error_code"),
        F.col("payload_json"),
        F.col("raw_event_json"),
    )


@dp.materialized_view(
    name=GOLD_TABLE,
    comment="Daily France energy-market KPIs derived from silver 15-minute snapshots.",
)
def fr_energy_market_kpis_daily():
    silver = spark.read.table(SILVER_TABLE)

    daily = silver.groupBy("country_code", "event_date").agg(
        F.avg("consumption_mw").alias("avg_consumption_mw"),
        F.max("consumption_mw").alias("peak_consumption_mw"),
        F.avg("renewable_share").alias("avg_renewable_share"),
        F.avg("fossil_share").alias("avg_fossil_share"),
        F.avg("co2_intensity_g_per_kwh").alias("avg_co2_intensity_g_per_kwh"),
        F.avg("forecast_error_mw").alias("avg_forecast_error_mw"),
        F.count("*").alias("snapshot_count"),
        F.sum(
            F.when(F.col("data_quality_status") == "invalid", F.lit(1)).otherwise(F.lit(0))
        ).alias("invalid_snapshot_count"),
    )

    return daily.withColumn(
        "market_stress_label",
        F.when(
            (F.col("avg_renewable_share") < 0.25)
            | (F.col("avg_co2_intensity_g_per_kwh") >= 80),
            F.lit("high"),
        )
        .when(F.col("avg_renewable_share") < 0.40, F.lit("medium"))
        .otherwise(F.lit("normal")),
    )
