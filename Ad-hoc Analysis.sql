-- Q1. City Level Fare and Trip Summary Report

select 
	dc.city_name,
    count(trip_id) as total_trips,
    round((sum(fare_amount)  / 
	sum(distance_travelled_km))) as avg_fare_per_km,
    round((sum(fare_amount) / 
    count(trip_id))) as avg_fare_per_trip,
    round(count(trip_id) / (select count(trip_id) from fact_trips) * 100,2) as `%_contribution_to_total_trips` 
from dim_city dc 
join fact_trips ft on dc.city_id=ft.city_id
group by dc.city_name ;

-- Q2. Monthly City Level Trip Target Performance Report

with trips_data as (
select 
    dc.city_name,
    dd.month_name,
    COUNT(ft.trip_id) AS actual_trips,
    tt.total_target_trips AS target_trips
from dim_city dc
join fact_trips ft ON dc.city_id = ft.city_id
join dim_date dd ON dd.date = ft.date
join targets_db.monthly_target_trips tt on dc.city_id = tt.city_id and dd.start_of_month = tt.month
group by 
    dc.city_name, 
    dd.month_name, 
    dd.start_of_month, 
    tt.total_target_trips
)
select *,
       case
           when actual_trips > target_trips then "Above Target"
           when actual_trips <= target_trips then "Below Target" 
	   end as Performance_status,
       round((actual_trips - target_trips)*100 / target_trips,2) as `%_difference`
from trips_data
order by city_name;

-- Q3. City level Repeat Passenger Trip Frequency Report 

with repeat_passenger as (
select 
	dc.city_name,
    td.trip_count,
    sum(td.repeat_passenger_count) as repeat_passenger_count
from dim_repeat_trip_distribution td 
join dim_city dc on dc.city_id=td.city_id 
group by dc.city_name,td.trip_count ),

repeat_passengers_total as (
select 
	city_name,
    sum(repeat_passenger_count) as total_repeat_passengers
from repeat_passenger
group by city_name ),

percentage_distribution as ( 
select 
	rp.city_name,
    trip_count,
    round((repeat_passenger_count / total_repeat_passengers)*100,2) as percentage
from  repeat_passenger rp
join  repeat_passengers_total rpt on rp.city_name=rpt.city_name
)

select 
	city_name,
    MAX(CASE WHEN trip_count = '2-Trips' THEN percentage ELSE 0 END) AS "2-Trips (%)",
    MAX(CASE WHEN trip_count = '3-Trips' THEN percentage ELSE 0 END) AS "3-Trips (%)",
    MAX(CASE WHEN trip_count = '4-Trips' THEN percentage ELSE 0 END) AS "4-Trips (%)",
    MAX(CASE WHEN trip_count = '5-Trips' THEN percentage ELSE 0 END) AS "5-Trips (%)",
    MAX(CASE WHEN trip_count = '6-Trips' THEN percentage ELSE 0 END) AS "6-Trips (%)",
    MAX(CASE WHEN trip_count = '7-Trips' THEN percentage ELSE 0 END) AS "7-Trips (%)",
    MAX(CASE WHEN trip_count = '8-Trips' THEN percentage ELSE 0 END) AS "8-Trips (%)",
    MAX(CASE WHEN trip_count = '9-Trips' THEN percentage ELSE 0 END) AS "9-Trips (%)",
    MAX(CASE WHEN trip_count = '10-Trips' THEN percentage ELSE 0 END) AS "10-Trips (%)"
from Percentage_Distribution
group by city_name;

-- Q4. Identify Cities with highest and lowest total new passengers

with rankedcities as (
select 
	dc.city_name,
	sum(ps.new_passengers) as total_new_passengers,
    row_number() over(order by sum(ps.new_passengers) desc) as rank_desc,
    row_number() over(order by sum(ps.new_passengers) asc) as rank_asc
from dim_city dc 
join fact_passenger_summary ps on ps.city_id=dc.city_id
group by 1 ),

category as (
select 
	city_name,
    total_new_passengers,
    case 
		when rank_desc <= 3 then "Top 3"
        when rank_asc <=3 then "Bottom 3"
	end as city_category
from rankedcities )

select * from category
where city_category in ('Top 3','Bottom 3')
order by total_new_passengers desc;

-- Q5. Identify months with highest revenue for each city

with Total_city_revenue AS (
    select 
        dc.city_name,
        SUM(ft.fare_amount) AS city_total_revenue
    from fact_trips ft
    join dim_city dc ON ft.city_id = dc.city_id
    group by dc.city_name
),
highest_revenue_month as (
select 
	dc.city_name,
    dd.month_name,
    sum(ft.fare_amount) as revenue,
    round(sum(ft.fare_amount)/cr.city_total_revenue *100,2) as `percentage_contribution_%`,
    rank() over(partition by dc.city_name order by sum(ft.fare_amount) desc) as rnk
from fact_trips ft 
join dim_city dc on ft.city_id=dc.city_id
join dim_date dd on dd.date=ft.date
join Total_city_revenue cr on cr.city_name=dc.city_name
group by dc.city_name,dd.month_name )
 
select 
	city_name,
    month_name,
    revenue,
    `percentage_contribution_%`
from highest_revenue_month
where rnk = 1
order by city_name;

-- Q6. Repeat Passenger Rate Analysis

with passenger_data as (
select 
	dc.city_name,
    dd.month_name,
    sum(fps.total_passengers) as total_passenger,
    sum(fps.repeat_passengers) as repeat_passenger
from dim_city dc 
join fact_passenger_summary fps on fps.city_id=dc.city_id
join dim_date dd on dd.date=fps.month 
group by dc.city_name,dd.month_name ),

monthly_rates as (
select *,
       round((repeat_passenger / total_passenger)* 100,2) as monthly_repeat_passenger_rate
from passenger_data ),

city_rates as (
select 
	city_name,
    sum(total_passenger) as total_passenger_city,
    sum(repeat_passenger) as repeat_passenger_city,
    round((sum(repeat_passenger) / sum(total_passenger))*100,2) as city_repeat_passenger_rate
from passenger_data
group by city_name )

select 
	m.city_name,
    m.month_name,
    m.total_passenger,
    m.repeat_passenger,
    m.monthly_repeat_passenger_rate,
    c.city_repeat_passenger_rate
from monthly_rates m 
join city_rates c on m.city_name=c.city_name
order by m.city_name, m.month_name;




