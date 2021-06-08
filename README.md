# Итоговая работа 

### В работе использовался локальный тип подключения.

[Вывод обработки sql файла](sql_output.txt)

![Скриншот подключения к БД](screenshot.png)

### Скриншот ER-диаграммы из DBeaver`a согласно Вашего подключения.

![Diagram](screenshot_er.png)

### Краткое описание БД - из каких таблиц и представлений состоит.

#### Таблицы:

1. **aircrafts**
    
    aircraft_code - Код самолета, IATA **первичный ключ**
    
    model - Модель самолета
    
    range - Максимальная дальность полета, км
   
1. **airports**
    
    airport_code - Код аэропорта **первичный ключ**

    airport_name - Название аэропорта

    city - Город
    
    longitude - Координаты аэропорта: долгота
    
    latitude - Координаты аэропорта: широта
    
    timezone - Временная зона аэропорта
   
1. **boarding_passes**

    ticket_no - Номер билета **первичный ключ**

    flight_id - Идентификатор рейса

    boarding_no - Номер посадочного талона
    
    seat_no - Номер места
   
1. **bookings**
    
    book_ref - Номер бронирования **первичный ключ**

    book_date - Дата бронирования
    
    total_amount - Полная сумма бронирования
   
1. **flights**

    flight_id - Идентификатор рейса **первичный ключ**

    flight_no - Номер рейса

    scheduled_departure - Время вылета по расписанию

    scheduled_arrival - Время прилёта по расписанию

    departure_airport - Аэропорт отправления

    arrival_airport - Аэропорт прибытия

    status - Статус рейса

    aircraft_code - Код самолета, IATA

    actual_departure - Фактическое время вылета

    actual_arrival - Фактическое время прилёта
   
1. **seats**

    aircraft_code - Код самолета, IATA

    seat_no - Номер места

    fare_conditions - Класс обслуживания

    _Первичный ключ комплексный (1 и 2 поля)_
   
1. **ticket_flights**

    ticket_no - Номер билета

    flight_id - Идентификатор рейса

    fare_conditions - Класс обслуживания

    amount - Стоимость перелета

    _Первичный ключ комплексный (1 и 2 поля)_
   
1. **tickets**

    ticket_no - Номер билета **первичный ключ**

    book_ref - Номер бронирования

    passenger_id - Идентификатор пассажира

    passenger_name - Имя пассажира

    contact_data - Контактные данные пассажира

#### Представления:

1. **flights_v**

    flight_id

    flight_no

    scheduled_departure

    scheduled_departure_local

    scheduled_arrival

    scheduled_arrival_local

    scheduled_duration

    departure_airport

    departure_airport_name

    departure_city

    arrival_airport

    arrival_airport_name

    arrival_city

    status

    aircraft_code

    actual_departure

    actual_departure_local

    actual_arrival

    actual_arrival_local

    actual_duration

#### Мат.представления:

1. **routes**

    flight_no

    departure_airport

    departure_airport_name

    departure_city

    arrival_airport

    arrival_airport_name

    arrival_city

    aircraft_code

    duration

    days_of_week

### Развернутый анализ БД - описание таблиц, логики, связей и бизнес области (частично можно взять из описания базы данных, оформленной в виде анализа базы данных). Бизнес задачи, которые можно решить, используя БД.

#### Таблица aircrafts

Каждая модель воздушного судна идентифицируется своим трехзначным кодом
(aircraft_code). Указывается также название модели (model) и максимальная дальность полета
в километрах (range).

Индексы:

- PRIMARY KEY, btree (aircraft_code)

Ограничения-проверки:

-  CHECK (range > 0)

Ссылки извне:

-  TABLE "flights" 
   - FOREIGN KEY (aircraft_code) REFERENCES aircrafts(aircraft_code)
 TABLE "seats"
    - FOREIGN KEY (aircraft_code) REFERENCES aircrafts(aircraft_code) ON DELETE CASCADE

#### Таблица airports

Аэропорт идентифицируется трехбуквенным кодом (airport_code) и имеет свое имя
(airport_name).

Для города не предусмотрено отдельной сущности, но название (city) указывается и может
служить для того, чтобы определить аэропорты одного города. Также указывается широта
(longitude), долгота (latitude) и часовой пояс (timezone).

Индексы:

-  PRIMARY KEY, btree (airport_code)

Ссылки извне:
-  TABLE "flights"
    - FOREIGN KEY (arrival_airport) REFERENCES airports(airport_code)
    - FOREIGN KEY (departure_airport)  REFERENCES airports(airport_code)

#### Таблица boarding_passes

При регистрации на рейс, которая возможна за сутки до плановой даты отправления,
пассажиру выдается посадочный талон. Он идентифицируется также, как и перелет —
номером билета и номером рейса.

Посадочным талонам присваиваются последовательные номера (boarding_no) в порядке
регистрации пассажиров на рейс (этот номер будет уникальным только в пределах данного
рейса). В посадочном талоне указывается номер места (seat_no).

Индексы:
 
- PRIMARY KEY, btree (ticket_no, flight_id)

    - UNIQUE CONSTRAINT, btree (flight_id, boarding_no)

    - UNIQUE CONSTRAINT, btree (flight_id, seat_no)

Ограничения внешнего ключа:

- FOREIGN KEY (ticket_no, flight_id) REFERENCES ticket_flights(ticket_no, flight_id)

#### Таблица bookings

Пассажир заранее (book_date, максимум за месяц до рейса) бронирует билет себе и,
возможно, нескольким другим пассажирам. Бронирование идентифицируется номером
(book_ref, шестизначная комбинация букв и цифр).

Поле total_amount хранит общую стоимость включенных в бронирование перелетов всех
пассажиров.

Индексы:

- PRIMARY KEY, btree (book_ref)

Ссылки извне:

- TABLE "tickets" FOREIGN KEY (book_ref) REFERENCES bookings(book_ref)

#### Таблица flights

Естественный ключ таблицы рейсов состоит из двух полей — номера рейса (flight_no) и даты
отправления (scheduled_departure). Чтобы сделать внешние ключи на эту таблицу компактнее,
в качестве первичного используется суррогатный ключ (flight_id).

Рейс всегда соединяет две точки — аэропорты вылета (departure_airport) и прибытия
(arrival_airport). Такое понятие, как «рейс с пересадками» отсутствует: если из одного
аэропорта до другого нет прямого рейса, в билет просто включаются несколько необходимых
рейсов.

У каждого рейса есть запланированные дата и время вылета (scheduled_departure) и прибытия
(scheduled_arrival). Реальные время вылета (actual_departure) и прибытия (actual_arrival)
могут отличаться: обычно не сильно, но иногда и на несколько часов, если рейс задержан.

Статус рейса (status) может принимать одно из следующих значений:

- Scheduled Рейс доступен для бронирования. Это происходит за месяц до плановой даты вылета;
до этого запись о рейсе не существует в базе данных.

- On Time Рейс доступен для регистрации (за сутки до плановой даты вылета) и не задержан.

- Delayed Рейс доступен для регистрации (за сутки до плановой даты вылета), но задержан.

- Departed Самолет уже вылетел и находится в воздухе.

- Arrived Самолет прибыл в пункт назначения.

- Cancelled Рейс отменен.

Индексы:

- PRIMARY KEY, btree (flight_id) UNIQUE CONSTRAINT, btree (flight_no, scheduled_departure)

Ограничения-проверки:

- CHECK (scheduled_arrival > scheduled_departure)

- CHECK ((actual_arrival IS NULL)
 OR ((actual_departure IS NOT NULL AND actual_arrival IS NOT NULL)
 AND (actual_arrival > actual_departure)))

- CHECK (status IN ('On Time', 'Delayed', 'Departed',
 'Arrived', 'Scheduled', 'Cancelled'))

Ограничения внешнего ключа:

- FOREIGN KEY (aircraft_code)
 REFERENCES aircrafts(aircraft_code)
  
- FOREIGN KEY (arrival_airport)
 REFERENCES airports(airport_code)

- FOREIGN KEY (departure_airport)
 REFERENCES airports(airport_code)

Ссылки извне:
- TABLE "ticket_flights" FOREIGN KEY (flight_id)
 REFERENCES flights(flight_id)

#### Таблица seats

Места определяют схему салона каждой модели. Каждое место определяется своим номером
(seat_no) и имеет закрепленный за ним класс обслуживания (fare_conditions) — Economy,
Comfort или Business.

Индексы:

- PRIMARY KEY, btree (aircraft_code, seat_no)

Ограничения-проверки:

- CHECK (fare_conditions IN ('Economy', 'Comfort', 'Business'))

Ограничения внешнего ключа:
- FOREIGN KEY (aircraft_code)
 REFERENCES aircrafts(aircraft_code) ON DELETE CASCADE

#### Таблица ticket_flights

Перелет соединяет билет с рейсом и идентифицируется их номерами.

Для каждого перелета указываются его стоимость (amount) и класс обслуживания
(fare_conditions).

Индексы:

- PRIMARY KEY, btree (ticket_no, flight_id)

Ограничения-проверки:

- CHECK (amount >= 0)

- CHECK (fare_conditions IN ('Economy', 'Comfort', 'Business'))

Ограничения внешнего ключа:

- FOREIGN KEY (flight_id) REFERENCES flights(flight_id)

- FOREIGN KEY (ticket_no) REFERENCES tickets(ticket_no)

Ссылки извне:
- TABLE "boarding_passes" FOREIGN KEY (ticket_no, flight_id)
 REFERENCES ticket_flights(ticket_no, flight_id)

#### Таблица tickets

Билет имеет уникальный номер (ticket_no), состоящий из 13 цифр.

Билет содержит идентификатор пассажира (passenger_id) — номер документа,
удостоверяющего личность, — его фамилию и имя (passenger_name) и контактную
информацию (contact_date).

Ни идентификатор пассажира, ни имя не являются постоянными (можно поменять паспорт,
можно сменить фамилию), поэтому однозначно найти все билеты одного и того же пассажира
невозможно.

Индексы:

- PRIMARY KEY, btree (ticket_no)

Ограничения внешнего ключа:

- FOREIGN KEY (book_ref) REFERENCES bookings(book_ref)

Ссылки извне:

- TABLE "ticket_flights" FOREIGN KEY (ticket_no) REFERENCES tickets(ticket_no)

#### Представление flights_v

Над таблицей flights создано представление flights_v, содержащее дополнительную
информацию:

- расшифровку данных об аэропорте вылета
(departure_airport, departure_airport_name, departure_city),

- расшифровку данных об аэропорте прибытия
(arrival_airport, arrival_airport_name, arrival_city),

- местное время вылета
(scheduled_departure_local, actual_departure_local),

- местное время прибытия
(scheduled_arrival_local, actual_arrival_local),

- продолжительность полета
(scheduled_duration, actual_duration).

#### Материализованное представление routes

Таблица рейсов содержит избыточность: из нее можно было бы выделить информацию
о маршруте (номер рейса, аэропорты отправления и назначения), которая не зависит
от конкретных дат рейсов.

Именно такая информация и составляет материализованное представление routes.

```
Столбец                 | Тип       | Описание
------------------------+-----------+-------------------------------------
flight_no               | char(6)   | Номер рейса
departure_airport       | char(3)   | Код аэропорта отправления
departure_airport_name  | text      | Название аэропорта отправления
departure_city          | text      | Город отправления
arrival_airport         | char(3)   | Код аэропорта прибытия
arrival_airport_name    | text      | Название аэропорта прибытия
arrival_city            | text      | Город прибытия
aircraft_code           | char(3)   | Код самолета, IATA
duration                | interval  | Продолжительность полета
days_of_week            | integer[] | Дни недели, когда выполняются рейсы`
```

### Бизнес задачи, которые можно решить, используя БД 

1. Множество вариантов анализа наполненности рейсов:
   
    - по направлениям,
    - по дням недели,
    - по классу обслуживания,
    
    и т.п.
    
    Данный пункт позволяет предложить варианты оптимизации расходов с помощью объединения или отмены некоторых рейсов.

1. Получение ресов с задержкой вылета для последующего изучения причин.

1. Получение данных для возврата денег за неиспользованные билеты.

1. Возможность развития новых направлений перелетов с помощью получения городов, между которыми нет прямых рейсов.

1. Анализ нагрузки и подсчет полётных часов.

### Список SQL запросов из приложения №2 с описанием логики их выполнения.

Ниже приведена ссылка на файл со списком запросов. Описание логики их выполнения дано в текстовом комментарии перед каждым запросом.

#### [Файл с запросами](sql-39-final.sql)
