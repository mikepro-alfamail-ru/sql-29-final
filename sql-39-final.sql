set search_path to bookings;

-- 1	В каких городах больше одного аэропорта?	
select city "Город"
from airports a
group by city 
having count(airport_code) > 1;


-- 2	В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета?	- Подзапрос
explain analyse 
select distinct 
	a.airport_name "Аэропорт"
from airports a  
join flights f on a.airport_code = f.departure_airport 
where f.aircraft_code = (
	select a.aircraft_code 
	from aircrafts a 
	order by a."range" desc limit 1
);


-- 3	Вывести 10 рейсов с максимальным временем задержки вылета	- Оператор LIMIT
select 
	f.flight_id,
	ad.airport_name "Departure Airport",
	aa.airport_name "Arrival Airport",
	f.scheduled_departure,
	f.actual_departure,
	f.actual_departure - f.scheduled_departure "Задержка"
from flights f
join airports ad on ad.airport_code = f.departure_airport 
join airports aa on aa.airport_code = f.arrival_airport 
where f.actual_departure is not null
order by "Задержка" desc
limit 10;


-- 4	Были ли брони, по которым не были получены посадочные талоны?	- Верный тип JOIN
select 
	case when count(b.book_ref) > 0 then 'Да'
	else 'Нет'
	end "Наличие броней без пт",
	count(b.book_ref) "Их количество" 
from bookings b 
join tickets t on t.book_ref = b.book_ref 
left join boarding_passes bp on bp.ticket_no = t.ticket_no 
where bp.boarding_no is null;


-- 5	Найдите свободные места для каждого рейса, их % отношение к общему количеству мест в самолете.
-- Добавьте столбец с накопительным итогом - суммарное накопление количества вывезенных пассажиров из каждого аэропорта на каждый день. Т.е. в этом столбце должна отражаться накопительная сумма - сколько человек уже вылетело 
-- из данного аэропорта на этом или более ранних рейсах за день.	
-- - Оконная функция
-- - Подзапросы или cte
with boarded as (
	select 
		f.flight_id,
		f.flight_no,
		f.aircraft_code,
		f.departure_airport,
		f.scheduled_departure,
		f.actual_departure,
		count(bp.boarding_no) boarded_count
	from flights f 
	join boarding_passes bp on bp.flight_id = f.flight_id 
	where f.actual_departure is not null
	group by f.flight_id 
),
max_seats_by_aircraft as(
	select 
		s.aircraft_code,
		count(s.seat_no) max_seats
	from seats s 
	group by s.aircraft_code 
)
select 
	b.flight_no,
	b.departure_airport,
	b.scheduled_departure,
	b.actual_departure,
	b.boarded_count,
	m.max_seats - b.boarded_count free_seats, 
	round((m.max_seats - b.boarded_count) / m.max_seats :: dec, 2) * 100 free_seats_percent,
	sum(b.boarded_count) over (partition by (b.departure_airport, b.actual_departure::date) order by b.actual_departure) "Накопительно пассажиров"
from boarded b 
join max_seats_by_aircraft m on m.aircraft_code = b.aircraft_code;

-- 6	Найдите процентное соотношение перелетов по типам самолетов от общего количества.	- Подзапрос
-- - Оператор ROUND
select 
	a.model "Модель самолета",
	count(f.flight_id) "Количество рейсов",
	round(count(f.flight_id) / 
		(select 
			count(f.flight_id)
		from flights f 
		where f.actual_departure is not null
		)::dec, 2) * 100 "В процентах от общего числа"
from aircrafts a 
join flights f on f.aircraft_code = a.aircraft_code 
where f.actual_departure is not null
group by a.aircraft_code;

-- 7	Были ли города, в которые можно  добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета?	- CTE
with prices_by_flight as (
	select  distinct 
		f.flight_id,
		a.city dep_city,
		a2.city arr_city,
		case when tf.fare_conditions = 'Economy' 
			then tf.amount 
			else -tf.amount
		end amount
	from ticket_flights tf 
	join flights f on tf.flight_id = f.flight_id 
	join airports a on f.departure_airport = a.airport_code
	join airports a2 on f.arrival_airport = a2.airport_code
)
select 
	pbf.flight_id,
	pbf.dep_city,
	pbf.arr_city,
	sum(pbf.amount)
from prices_by_flight pbf
group by pbf.flight_id, pbf.dep_city, pbf.arr_city
having 	sum(pbf.amount) > 0


-- 8	Между какими городами нет прямых рейсов?	- Декартово произведение в предложении FROM
-- - Самостоятельно созданные представления
-- - Оператор EXCEPT


-- 9	Вычислите расстояние между аэропортами, связанными прямыми рейсами, сравните с допустимой максимальной дальностью перелетов  в самолетах, обслуживающих эти рейсы *	- Оператор RADIANS или использование sind/cosd
-- - CASE 

