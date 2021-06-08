set search_path to bookings;

-- 1	В каких городах больше одного аэропорта?	
/*
 * Группирую таблицу аэропортов по городу и вывожу только те, у которых количество airport_code больше 1
 */
select city "Город"
from airports a
group by city 
having count(airport_code) > 1;


-- 2	В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета?	
-- - Подзапрос
/*
 * Подзапрос получает код самолета с самыой большой дальностью (с помощью сортировки и ограничения вывода).
 * Далее в основном запросе указывается условие соответствия самолета.
 * Основной запрос получает имя аэропорта по джойну с таблицей перелётов
 */

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
/*
 * Отбираю только те рейсы, которые вылетели (actual_departure заполнено)
 * Задержка считается простым вычитанием.
 * Наконец, сортировка по убыванию и ограничение вывода
 */
select 
	f.flight_id,
	f.scheduled_departure,
	f.actual_departure,
	f.actual_departure - f.scheduled_departure "Задержка"
from flights f
where f.actual_departure is not null
order by "Задержка" desc
limit 10;



-- 4	Были ли брони, по которым не были получены посадочные талоны?	- Верный тип JOIN
/*
 * Left join, т.к. нужно полное множество броней.
 * Джойню таблицу tickets т.к. таблица броней связывается с талонами через билет.
 */
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
-- Добавьте столбец с накопительным итогом - суммарное накопление количества вывезенных пассажиров из каждого аэропорта на каждый день. 
-- Т.е. в этом столбце должна отражаться накопительная сумма - сколько человек уже вылетело из данного аэропорта на этом или более ранних рейсах за день.	
-- - Оконная функция
-- - Подзапросы или cte
/*
 * CTE boarded получает количество выданных посадочных талонов по каждому рейсу
 * Ограничение actual_departure is not null для того, чтобы отслеживать уже вылетевшие рейсы
 * CTE max_seats_by_aircraft получает количество мест в самолёте
 * В итоговом запросе оба CTE джойнятся по aircraft_code
 * Для подсчета накопительной суммы использется оконная функция c разделением по аэропорту отправления и времени вылета приведенному к формату date. 
 */
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
/*
 * Используется подзапрос для получения общего числа полетов (проверяем, вылетел ли самолет при подсчете)
 * В основном запросе используется группировка по полю model
 */
select 
	a.model "Модель самолета",
	count(f.flight_id) "Количество рейсов",
	round(count(f.flight_id) /
		(select 
			count(f.flight_id)
		from flights f 
		where f.actual_departure is not null
		)::dec * 100, 4) "В процентах от общего числа"
from aircrafts a 
join flights f on f.aircraft_code = a.aircraft_code 
where f.actual_departure is not null
group by a.model;

-- 7	Были ли города, в которые можно  добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета?	
-- - CTE
/*
 * В CTE prices собираются стоимости билетов на рейс: максимальная для Эконома и минимальная для бизнеса.
 * Затем из него отбираются эти стоимости и группируются в одну строку по каждому аэропорту - это внешний
 * CTE eco_busi. Результаты фильтруются по сравнению полей b_min_amount и e_max_amount
 * Далее этот CTE джойнится с таблицами рейсов и аэропортов, чтобы достать из них города отправления и прибытия.
 * Судя по тому, что результат пустой, таких рейсов нет
 */
with eco_busi as (
	with prices as(
		select  
			f.flight_id,
			case when tf.fare_conditions  = 'Business' then min(tf.amount) end b_min_amount,
			case when tf.fare_conditions  = 'Economy' then max(tf.amount) end e_max_amount
		from ticket_flights tf 
		join flights f on tf.flight_id = f.flight_id 
		group by 
			f.flight_id, tf.fare_conditions
	)
	select 
		p.flight_id,
		min(p.b_min_amount),
		max(p.e_max_amount)
	from prices p
		group by p.flight_id
	having min(p.b_min_amount) < max(p.e_max_amount)
	)
select 
	e.flight_id,
	a.city depatrure_city,
	a2.city arrival_city
from eco_busi e 
join flights f on e.flight_id = f.flight_id 
join airports a on f.departure_airport = a.airport_code
join airports a2 on f.arrival_airport = a2.airport_code
	
-- 8	Между какими городами нет прямых рейсов?	
-- - Декартово произведение в предложении FROM
-- - Самостоятельно созданные представления
-- - Оператор EXCEPT
/*
 * Создаю представление для получения городов, между которыми есть рейсы
 * Два джойна в представлении по той же причине, что и в 3 запросе
 * В основном запросе получаю декартово произведение всех городов, с условием их неравенства
 * Затем из него убираю данные, которые есть в представлении.
 */
create view dep_arr_city as
select distinct 
	a.city departure_city,
	a2.city arrival_city
from flights f 
join airports a on f.departure_airport = a.airport_code 
join airports a2 on f.arrival_airport = a2.airport_code;

select distinct 
	a.city departure_city,
	a2.city arrival_city 
from airports a, airports a2 
where a.city != a2.city
except 
select * from dep_arr_city

-- 9	Вычислите расстояние между аэропортами, связанными прямыми рейсами, сравните с допустимой максимальной дальностью перелетов  
-- в самолетах, обслуживающих эти рейсы *	- Оператор RADIANS или использование sind/cosd
-- - CASE 
/*
 * Опять два раза джойн таблицы аэропортов.
 * Поле "Долетит?" заполняется по условию того, что рассчитанная дальность между городами меньше дальности самолета.
 * Расстояние между городами делал по формуле из задания не особо задумываясь об этом
 */
select distinct 
	ad.airport_name "Из",
	aa.airport_name "В",
	a."range" "Дальность самолета",
	round((acos(sind(ad.latitude) * sind(aa.latitude) + cosd(ad.latitude) * cosd(aa.latitude) * cosd(ad.longitude - aa.longitude)) * 6371)::dec, 2) "Расстояние",		
	case when 
		a."range" <
		acos(sind(ad.latitude) * sind(aa.latitude) + cosd(ad.latitude) * cosd(aa.latitude) * cosd(ad.longitude - aa.longitude)) * 6371 
		then 'Нет!'
		else 'Да!'
		end "Долетит?"
from flights f
join airports ad on f.departure_airport = ad.airport_code
join airports aa on f.arrival_airport = aa.airport_code
join aircrafts a on a.aircraft_code = f.aircraft_code 

