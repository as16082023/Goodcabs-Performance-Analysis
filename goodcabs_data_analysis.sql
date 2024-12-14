use trips_db;



-- Total Trips
select count(trip_id) as total_trips
from fact_trips;

------------------------------------------------------------------------------------------------
-- Total Fare (Revenue)
select sum(fare_amount) as total_fare
from fact_trips;

--------------------------------------------------------------------------------------
-- Total Distance Travelled
select sum(distance_travelled_km) as total_distance_travelled
from fact_trips;

-------------------------------------------------------------------------------------------------------
-- Average Passenger Rating and Average Driver Rating
select avg(passenger_rating) as avg_passenger_rating, 
	   avg(driver_rating) as avg_driver_rating
from fact_trips;

--------------------------------------------------------------------------------------
-- Average Fare per Trip
select avg(fare_amount) as avg_fare_per_trip
from fact_trips;

------------------------------------------------------------------------------------------
-- Average Fare per km
select sum(fare_amount)/sum(distance_travelled_km) as avg_fare_per_km
from fact_trips;

-------------------------------------------------------------------------------------
-- Average Trip Distance
select avg(distance_travelled_km) as avg_trip_distance
from fact_trips;

---------------------------------------------------------------------------------------------
-- Max and Min Distance
select max(distance_travelled_km) as Max_distance,
       min(distance_travelled_km) as Min_distance
from fact_trips;
------------------------------------------------------------------------------------
-- New Trips
select count(passenger_type) as new_trips
from fact_trips 
where passenger_type = "new";
------------------------------------------------------------------
-- Repeated Trips
select count(passenger_type) as repeated_trips
from fact_trips 
where passenger_type = "repeated";

------------------------------------------------------------------------
-- Total Passengers
select sum(total_passengers) as total_passengers
from fact_passenger_summary;

-------------------------------------------------------------------------------------------
-- New Passengers
select sum(new_passengers) as new_passengers
from fact_passenger_summary;

--------------------------------------------------------------------------------------
-- Repeat Passengers
select sum(repeat_passengers) as repeat_passengers
from fact_passenger_summary;

-------------------------------------------------------------------------------------
-- Repeat Passenger Rate
WITH cte1 AS (
    SELECT 
        SUM(new_passengers) AS new_passengers,
        SUM(repeat_passengers) AS repeated_passengers
    FROM fact_passenger_summary
)
SELECT 
    new_passengers, 
    repeated_passengers, 
    ROUND(
        new_passengers / NULLIF(repeated_passengers, 0), 2
    ) AS new_vs_repeat_ratio
FROM cte1;

WITH cte1 AS (
    SELECT 
        SUM(total_passengers) AS total_passengers,
        SUM(repeat_passengers) AS repeat_passengers
    FROM fact_passenger_summary
)
SELECT 
    total_passengers, 
    repeat_passengers, 
    (
        repeat_passengers / NULLIF(total_passengers, 0)
    )*100 AS repeat_passenger_rate
FROM cte1;

--------------------------------------------------------------------------------------------
-- Revenue Growth Rate Monthly

WITH monthly_revenue AS (
    SELECT 
        dc.city_name as city_name, 
        DATE_FORMAT(ft.date, '%Y-%m') AS month, -- Extract year and month in 'YYYY-MM' format
        SUM(ft.fare_amount) AS current_month_revenue,
        LAG(SUM(ft.fare_amount)) OVER(PARTITION BY city_name ORDER BY DATE_FORMAT(ft.date, '%Y-%m')) AS previous_month_revenue
    FROM 
        fact_trips ft
	JOIN 
        dim_city dc
	ON ft.city_id = dc.city_id
    GROUP BY 
        dc.city_name, DATE_FORMAT(date, '%Y-%m')
)
SELECT 
   *,
    ROUND(
        (current_month_revenue - previous_month_revenue) / NULLIF(previous_month_revenue, 0) * 100, 2
    ) AS revenue_growth_rate
FROM 
    monthly_revenue 
ORDER BY 
    city_name, month;
    
-------------------------------------------------------
-- Top and Bottom Performing Cities

select dc.city_name, count(ft.trip_id) as total_trips, 
       row_number() over( order by count(ft.trip_id) desc) as city_rank
from fact_trips ft
join dim_city dc 
on ft.city_id = dc.city_id
group by dc.city_name
order by 2 desc;

-----------------------------------------------------------------------------------------------
-- Average Fare per Trip by City

WITH city_stats AS (
    SELECT 
        dc.city_name as city_name, 
        ROUND(AVG(ft.fare_amount), 2) AS avg_fare_per_trip, -- Average fare per trip
        ROUND(AVG(ft.distance_travelled_km), 2) AS avg_trip_distance -- Average trip distance
    FROM 
        fact_trips ft
	JOIN 
        dim_city dc 
	ON ft.city_id = dc.city_id
    GROUP BY 
        city_name
),
min_max_fare AS (
    SELECT 
        MAX(avg_fare_per_trip) AS max_avg_fare, -- Maximum average fare
        MIN(avg_fare_per_trip) AS min_avg_fare -- Minimum average fare
    FROM 
        city_stats
)
SELECT 
    cs.city_name,
    cs.avg_fare_per_trip,
    cs.avg_trip_distance,
    CASE 
        WHEN cs.avg_fare_per_trip = mm.max_avg_fare THEN 'Highest Avg Fare'
        WHEN cs.avg_fare_per_trip = mm.min_avg_fare THEN 'Lowest Avg Fare'
        ELSE 'Normal'
    END AS fare_efficiency
FROM 
    city_stats cs
CROSS JOIN 
    min_max_fare mm
ORDER BY 
    cs.avg_fare_per_trip DESC;
    
    
    ----------------------------------------------------------------------------------------
    -- Average Ratings by City and Passenger Type
    
        SELECT 
        dc.city_name,
        ft.passenger_type, -- Assuming 'passenger_type' has values like 'new' and 'repeat'
        ROUND(AVG(ft.passenger_rating), 2) AS avg_passenger_rating,
        ROUND(AVG(ft.driver_rating), 2) AS avg_driver_rating
    FROM 
        fact_trips ft
	JOIN 
        dim_city dc 
	ON ft.city_id = dc.city_id
    WHERE ft.passenger_type = "new"
    GROUP BY 
        city_name, passenger_type
	ORDER BY 
            avg_passenger_rating desc;
            
	        SELECT 
        dc.city_name,
        ft.passenger_type, -- Assuming 'passenger_type' has values like 'new' and 'repeat'
        ROUND(AVG(ft.passenger_rating), 2) AS avg_passenger_rating,
        ROUND(AVG(ft.driver_rating), 2) AS avg_driver_rating
    FROM 
        fact_trips ft
	JOIN 
        dim_city dc 
	ON ft.city_id = dc.city_id
    WHERE ft.passenger_type = "repeated"
    GROUP BY 
        city_name, passenger_type
	ORDER BY 
            avg_passenger_rating desc;
	
     select dc.city_name as city_name,
            avg(ft.passenger_rating) as avg_passenger_rating,
            avg(ft.driver_rating) as avg_driver_rating
	from fact_trips ft
    join dim_city dc
    on ft.city_id = dc.city_id
    group by city_name
    order by avg_passenger_rating desc;
  
  --------------------------------------------------------------------------------------------
    -- Peak and Low Demand Months by City
    
    WITH monthly_trips AS (
    SELECT 
        dc.city_name as city_name,
        DATE_FORMAT(ft.date,'%M') AS trip_month, -- Extracting year and month
        COUNT(*) AS total_trips
    FROM 
        fact_trips ft
	JOIN 
        dim_city dc
	ON ft.city_id = dc.city_id
    GROUP BY 
        city_name, trip_month
),
peak_low_months AS (
    SELECT 
        city_name,
        MAX(total_trips) AS peak_trips,
        MIN(total_trips) AS low_trips
    FROM 
        monthly_trips
    GROUP BY 
        city_name
)
SELECT 
    plm.city_name,
    (SELECT trip_month 
     FROM monthly_trips 
     WHERE city_name = plm.city_name AND total_trips = plm.peak_trips LIMIT 1) AS peak_dd_month,
    (SELECT trip_month 
     FROM monthly_trips 
     WHERE city_name = plm.city_name AND total_trips = plm.low_trips LIMIT 1) AS low_dd_month
FROM 
    peak_low_months plm;
    
    
  
  ----------------------------------------------------------------------------------------------------
  -- Weekend vs. Weekday Trip Demand by City
  
    WITH weekday_weekend_trips AS (
    SELECT 
        dc.city_id,
        dd.day_type,
        COUNT(ft.trip_id) AS total_trips
    FROM 
        fact_trips ft
    JOIN 
        dim_date dd
    ON 
        ft.date = dd.date
    JOIN 
        dim_city dc
    ON 
        ft.city_id = dc.city_id
    GROUP BY 
        dc.city_id, dd.day_type
),
city_preferences AS (
    SELECT 
        city_id,
        MAX(CASE WHEN day_type = 'Weekend' THEN total_trips ELSE 0 END) AS weekend_trips,
        MAX(CASE WHEN day_type = 'Weekday' THEN total_trips ELSE 0 END) AS weekday_trips,
        CASE 
            WHEN MAX(CASE WHEN day_type = 'Weekend' THEN total_trips ELSE 0 END) > MAX(CASE WHEN day_type = 'Weekday' THEN total_trips ELSE 0 END) 
            THEN 'Weekend Preference'
            ELSE 'Weekday Preference'
        END AS preference
    FROM 
        weekday_weekend_trips
    GROUP BY 
        city_id
)
SELECT 
    c.city_id,
    c.city_name,
    cp.weekend_trips,
    cp.weekday_trips,
    cp.preference
FROM 
    city_preferences cp
JOIN 
    dim_city c
ON 
    cp.city_id = c.city_id
ORDER BY 
    cp.weekend_trips + cp.weekday_trips DESC;
    
    
    
    
    
    
    
    
    
