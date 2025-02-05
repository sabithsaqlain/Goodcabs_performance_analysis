-- 1.City level fare and trip summary report

WITH CTE AS (
SELECT 
	city_name AS city,
    COUNT(trip_id) AS total_trips, 
    ROUND(AVG(fare_amount/distance_travelled_km), 1) AS avg_fare_per_km,
    ROUND(AVG(fare_amount), 1) AS avg_fare_per_trip
FROM 
	fact_trips JOIN dim_city USING (city_id)
GROUP BY 
	city
)    
SELECT
	*, ROUND(total_trips * 100/ (SELECT count(*) FROM fact_trips), 1) AS trips_pct_contribution
FROM 
	CTE
ORDER BY
	total_trips DESC ;
  
  
-----------------------------------------------------------------------------------------------------------------------------------	

-- 2.Month and city level target performance report

WITH actual_trip AS (
SELECT
	city_id, month(date) AS month, count(trip_id) AS actual_trips 
FROM
	fact_trips
GROUP BY 
city_id, month
),
target_trip AS (
SELECT
	city_id, month(month) AS month, total_target_trips AS target_trips 
FROM
	targets_db.monthly_target_trips
)
SELECT 
	city_name AS city, month, actual_trips, target_trips,
	CASE WHEN actual_trips > target_trips THEN "Above Target" 
	WHEN actual_trips <= target_trips THEN "Below target"
	END performance_status,
	round((actual_trips - target_trips) *100 / actual_trips, 1) AS pct_difference  
FROM 
	actual_trip 
		JOIN target_trip USING(city_id, month)
		JOIN dim_city USING (city_id)
ORDER BY
	city, month ;
 
 
-----------------------------------------------------------------------------------------------------------------------------------

-- 3.City level passenger trip frequency report

WITH trip_count AS
(
SELECT city_id,
SUM(CASE WHEN trip_count = '2-Trips' THEN repeat_passenger_count END) AS 2_trips,
SUM(CASE WHEN trip_count = '3-Trips' THEN repeat_passenger_count END) AS 3_trips,
SUM(CASE WHEN trip_count = '4-Trips' THEN repeat_passenger_count END) AS 4_trips,
SUM(CASE WHEN trip_count = '5-Trips' THEN repeat_passenger_count END) AS 5_trips,
SUM(CASE WHEN trip_count = '6-Trips' THEN repeat_passenger_count END) AS 6_trips,
SUM(CASE WHEN trip_count = '7-Trips' THEN repeat_passenger_count END) AS 7_trips,
SUM(CASE WHEN trip_count = '8-Trips' THEN repeat_passenger_count END) AS 8_trips,
SUM(CASE WHEN trip_count = '9-Trips' THEN repeat_passenger_count END) AS 9_trips,
SUM(CASE WHEN trip_count = '10-Trips' THEN repeat_passenger_count END) AS 10_trips,
SUM(repeat_passenger_count) AS TOTAL
FROM 
	dim_repeat_trip_distribution
GROUP BY
	city_id
)
SELECT city_name AS city,
ROUND(2_trips * 100/TOTAL,1) 2_trips,
ROUND(3_trips * 100/TOTAL,1) 3_trips,
ROUND(4_trips * 100/TOTAL,1) 4_trips,
ROUND(5_trips * 100/TOTAL,1) 5_trips,
ROUND(6_trips * 100/TOTAL,1) 6_trips,
ROUND(7_trips * 100/TOTAL,1) 7_trips,
ROUND(8_trips * 100/TOTAL,1) 8_trips,
ROUND(9_trips * 100/TOTAL,1) 9_trips,
ROUND(10_trips * 100/TOTAL,1) 10_trips
FROM 
	trip_count JOIN dim_city USING (city_id) ;
 
 
-----------------------------------------------------------------------------------------------------------------------------------

-- 4. Cities with highest and lowest new passengers 

WITH new_passengers_count AS(
SELECT 
	city_name AS city, 
	SUM(new_passengers) AS total_new_passengers,
	dense_rank() over(order by SUM(new_passengers) DESC) AS rnk
FROM
	fact_passenger_summary JOIN dim_city USING(city_id)
GROUP BY
	city_name
),
city_rank AS
(
SELECT 
	*,
	CASE 
		WHEN rnk<=3 THEN "Top 3"
		WHEN rnk>=8 THEN "Bottom 3"
		END AS city_category
FROM
	new_passengers_count
) 
SELECT city, total_new_passengers, city_category 
FROM city_rank 
WHERE city_category IN ("Top 3","Bottom 3") ;



-----------------------------------------------------------------------------------------------------------------------------------

-- 5. Month with highest revenue for each city 

WITH monthly_revenue AS (
SELECT 
	city_id,
	MONTHNAME(date) AS month,
	ROUND(SUM(fare_amount)/1000000,2) AS revenue
FROM
	fact_trips
GROUP BY 
	MONTH, city_id
),
monthly_ranking AS (
SELECT 
	city_id, month,
    revenue,
	round(revenue * 100/sum(revenue) OVER(PARTITION BY city_id), 1) pct_contribution,
	DENSE_RANK() OVER(PARTITION BY city_id ORDER BY revenue DESC) rnk
FROM 
	monthly_revenue 
)
SELECT
	city_name AS city, month, revenue AS revenue_in_millions, pct_contribution 
FROM 
	monthly_ranking JOIN dim_city USING (city_id)
WHERE rnk = 1
ORDER BY city ;


----------------------------------------------------------------------------------------------------------------------------------- 

-- 6.Repeat passenger rate analysis 

WITH monthly_rpr AS (
SELECT 
	city_name AS city,
	month(month) AS month,
	total_passengers,
	repeat_passengers,
	ROUND(repeat_passengers * 100 /(SELECT 
										sum(repeat_passengers)
									FROM 
										fact_passenger_summary), 1) AS monthly_repeat_passenger_rate
FROM
	fact_passenger_summary JOIN dim_City USING (city_id)

)
SELECT
	*, 
    ROUND(SUM(monthly_repeat_passenger_rate) OVER(PARTITION BY city), 1) AS city_repeat_passenger_rate 
FROM 
	monthly_rpr
ORDER BY 
	city, month ;  