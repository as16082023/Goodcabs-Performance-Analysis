use trips_db;


/* CITY-LEVEL FARE AND TRIP SUMMARY REPORT */
select dc.city_name,
       count(ft.trip_id) as total_trips,
       round(sum(ft.fare_amount)/sum(ft.distance_travelled_km),2) as avg_fare_per_km,
       round(avg(ft.fare_amount),2) as avg_fare_per_trip,
	   round((count(ft.trip_id) / (select count(*) from fact_trips)) * 100, 2) as pct_contribution_to_total_trips 
       from dim_city dc
       join fact_trips ft
       on dc.city_id = ft.city_id
group by city_name
order by total_trips desc;

------------------------------------------------------------------------------------------------------------------------
/* MONTHLY CITY-LEVEL TRIPS TARGET PERFORMANCE REPORT */
select
	dc.city_name,
    MONTHNAME(mt.month) AS month_name,
    COALESCE(ft.actual_trips, 0) AS actual_trips,
    mt.total_target_trips,
    CASE
    WHEN ft.actual_trips <= mt.total_target_trips THEN "Below Target"
    WHEN ft.actual_trips > mt.total_target_trips THEN "Above Target"
    END AS "performance_status",
    ROUND(((COALESCE(ft.actual_trips, 0) - mt.total_target_trips)/ mt.total_target_trips)*100.0, 2) AS "%_difference"
FROM 
    targets_db.monthly_target_trips AS mt
LEFT JOIN (
	SELECT 
        DATE_FORMAT(date, '%Y-%m-01') AS month,
        city_id,
        COUNT(*) AS actual_trips
    FROM 
        trips_db.fact_trips
    GROUP BY 
        city_id, month
) AS ft
ON mt.city_id = ft.city_id AND mt.month = ft.month
LEFT JOIN trips_db.dim_city AS dc
ON mt.city_id = dc.city_id
ORDER BY 
    dc.city_name,mt.month;

----------------------------------------------------------------------------------------------------------
/* CITY-LEVEL REPEAT PASSENGER TRIP FREQUENCY REPORT */
SELECT 
    city_name,
    ROUND(SUM(CASE WHEN trip_count = "2-Trips" THEN repeat_passenger_count ELSE 0 END) * 100.0 /
        SUM(repeat_passenger_count), 2) AS "2-Trips",
    ROUND(SUM(CASE WHEN trip_count = "3-Trips" THEN repeat_passenger_count ELSE 0 END) * 100.0 /
        SUM(repeat_passenger_count), 2) AS "3-Trips",
    ROUND(SUM(CASE WHEN trip_count = "4-Trips" THEN repeat_passenger_count ELSE 0 END) * 100.0 /
        SUM(repeat_passenger_count), 2) AS "4-Trips",
    ROUND(SUM(CASE WHEN trip_count = "5-Trips" THEN repeat_passenger_count ELSE 0 END) * 100.0 /
        SUM(repeat_passenger_count), 2) AS "5-Trips",
    ROUND(SUM(CASE WHEN trip_count = "6-Trips" THEN repeat_passenger_count ELSE 0 END) * 100.0 /
        SUM(repeat_passenger_count), 2) AS "6-Trips",
    ROUND(SUM(CASE WHEN trip_count = "7-Trips" THEN repeat_passenger_count ELSE 0 END) * 100.0 /
        SUM(repeat_passenger_count), 2) AS "7-Trips",
    ROUND(SUM(CASE WHEN trip_count = "8-Trips" THEN repeat_passenger_count ELSE 0 END) * 100.0 /
        SUM(repeat_passenger_count), 2) AS "8-Trips",
    ROUND(SUM(CASE WHEN trip_count = "9-Trips" THEN repeat_passenger_count ELSE 0 END) * 100.0 /
        SUM(repeat_passenger_count), 2) AS "9-Trips",
    ROUND(SUM(CASE WHEN trip_count = "10-Trips" THEN repeat_passenger_count ELSE 0 END) * 100.0 /
        SUM(repeat_passenger_count), 2) AS "10-Trips"
FROM dim_repeat_trip_distribution rt
LEFT JOIN dim_city dc
ON  dc.city_id = rt.city_id
GROUP BY city_name;

---------------------------------------------------------------------------------------------
/* CITIES WITH HIGHEST AND LOWEST TOTAL NEW PASSENGERS */
WITH cte1 AS (
    SELECT 
        dc.city_name,
        SUM(fp.new_passengers) AS total_new_passengers,
        ROW_NUMBER() OVER (ORDER BY SUM(fp.new_passengers) desc) AS city_rank
        
    FROM fact_passenger_summary fp
    LEFT JOIN dim_city dc
    ON dc.city_id = fp.city_id
    GROUP BY dc.city_name
    ORDER BY total_new_passengers desc
),
cte2 AS (
    SELECT 
               *,
        case when city_rank in (1,2,3) then "Top 3" else "Bottom 3" end as city_category
    FROM cte1
    WHERE city_rank < 4 or city_rank > 7
)
SELECT city_name, total_new_passengers, city_category
from cte2;

-----------------------------------------------------------------------------------------------------
/* MONTH WITH HIGHEST REVENUE FOR EACH CITY */
WITH cte1 AS (
	SELECT 
        dc.city_name,
        dt.month_name,
        SUM(ft.fare_amount) AS total_revenue
    FROM fact_trips ft
    LEFT JOIN dim_city dc
        ON ft.city_id = dc.city_id
    LEFT JOIN dim_date dt
        ON ft.date = dt.date
    GROUP BY dc.city_name, dt.month_name
),
cte2 AS (
    SELECT 
        city_name,
        month_name,
        total_revenue,
        ROW_NUMBER() OVER (PARTITION BY city_name ORDER BY total_revenue DESC) AS rank_desc,
        SUM(total_revenue) OVER (PARTITION BY city_name) AS city_total_revenue
    FROM cte1
)
SELECT 
    city_name,
    month_name AS "highest_revenue_month",
    total_revenue AS "revenue",
    ROUND((total_revenue / city_total_revenue) * 100, 2) AS "percentage_contribution (%)"
FROM cte2
WHERE rank_desc = 1
ORDER BY city_name;
----------------------------------------------------------------------------------------------------
/* REPEAT PASSENGER RATE ANALYSIS */
WITH monthly_repeat_rate as
(
SELECT 
    fps.month,
    dc.city_name,
    fps.repeat_passengers,
    fps.total_passengers,
    ROUND((fps.repeat_passengers / NULLIF(fps.total_passengers, 0)) * 100, 2) AS monthly_repeat_passenger_rate
FROM fact_passenger_summary fps
JOIN dim_city dc
    ON fps.city_id = dc.city_id
),
city_repeat_rate as (
SELECT 
    dc.city_name,
    SUM(fps.repeat_passengers) AS total_repeat_passengers,
    SUM(fps.total_passengers) AS total_passengers,
    ROUND((SUM(fps.repeat_passengers) / NULLIF(SUM(fps.total_passengers), 0)) * 100, 2) AS city_repeat_passenger_rate
FROM fact_passenger_summary fps
JOIN dim_city dc 
ON fps.city_id = dc.city_id
GROUP BY 1
)
SELECT 
mrr.city_name,
DATE_FORMAT(mrr.month, '%M') AS month,
mrr.total_passengers,
mrr.repeat_passengers,
mrr.monthly_repeat_passenger_rate,
crr.city_repeat_passenger_rate
FROM monthly_repeat_rate mrr
JOIN city_repeat_rate crr
ON crr.city_name = mrr.city_name
ORDER BY mrr.city_name, mrr.month;
        
