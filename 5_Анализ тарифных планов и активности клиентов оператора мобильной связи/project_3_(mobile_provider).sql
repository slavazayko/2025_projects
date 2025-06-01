-- 1) Длительность разговоров клиента в месяц
'''Для каждого клиента посчитайте суммарную длительность всех звонков в месяц.
При агрегации данных за месяц округлите полученные значения вверх до ближайшего целого числа — именно в таком виде оператор выставляет счёт пользователям.'''

WITH monthly_duration AS (
       SELECT
	       user_id,
	       DATE_TRUNC ('month', call_date :: timestamp) :: date AS dt_month,
	       CEIL (SUM (duration)) AS month_duration
       FROM telecom.calls
       GROUP BY user_id, dt_month)
       SELECT *
       FROM monthly_duration

       
-- 2) Количество интернет-трафика в месяц
'''По аналогии с предыдущим заданием для каждого клиента посчитайте суммарное количество потраченного интернет-трафика в месяц.'''

-- Суммарная длительность разговоров клиента в месяц:
WITH monthly_duration AS (
    SELECT
    	user_id,
    -- Выделяем месяц из даты звонка: 
        DATE_TRUNC('month', call_date::timestamp)::date AS dt_month,    
        CEIL(SUM(duration)) AS month_duration
    FROM telecom.calls
    GROUP BY user_id, dt_month
), 
    monthly_internet AS (
    SELECT
    	user_id,
    -- Выделяем месяц из даты звонка: 
        DATE_TRUNC('month', session_date::timestamp)::date AS dt_month, 
        SUM(mb_used) AS month_mb_traffic
    FROM telecom.internet
    GROUP BY user_id, dt_month)
SELECT *
FROM monthly_internet
LIMIT 5
       

-- 3) Количество сообщений в месяц
'''Продолжите изучать ежемесячную активность клиентов. Теперь для каждого клиента посчитайте суммарное количество отправленных сообщений в месяц.'''

-- Суммарная длительность разговоров клиента в месяц:
WITH monthly_duration AS (
    SELECT user_id,
           -- Выделяем месяц из даты звонка: 
           DATE_TRUNC('month', call_date::timestamp)::date AS dt_month,    
           CEIL(SUM(duration)) AS month_duration
    FROM telecom.calls
    GROUP BY user_id, dt_month
),
-- Суммарное количество потраченного интернет-трафика в месяц:
monthly_internet AS (
    SELECT user_id,
           DATE_TRUNC('month', session_date::timestamp)::date AS dt_month,  
           SUM(mb_used) AS month_mb_traffic
    FROM telecom.internet
    GROUP BY user_id, dt_month
),
monthly_sms AS (
    SELECT user_id,
           DATE_TRUNC('month', message_date::timestamp)::date AS dt_month, 
          COUNT(id) AS month_sms
    FROM telecom.messages
    GROUP BY user_id, dt_month)
    
SELECT *
FROM monthly_sms
LIMIT 5


-- 4) Соединяем данные о клиентах и их месячную активность
'''Чтобы дальше проводить расчёты и анализировать данные, нужно объединить всю информацию в одну таблицу — так, чтобы для каждого клиента и месяца его активности была информация о длительности разговоров, интернет-трафике и отправленных сообщениях.'''

-- Суммарная длительность разговоров клиента в месяц:
WITH monthly_duration AS (
    SELECT user_id,
           -- Выделяем месяц из даты звонка: 
           DATE_TRUNC('month', call_date::timestamp)::date AS dt_month,    
           CEIL(SUM(duration)) AS month_duration
    FROM telecom.calls
    GROUP BY user_id, dt_month
),
-- Суммарное количество потраченного интернет-трафика в месяц:
monthly_internet AS (
    SELECT user_id,
           DATE_TRUNC('month', session_date::timestamp)::date AS dt_month,  
           SUM(mb_used) AS month_mb_traffic
    FROM telecom.internet
    GROUP BY user_id, dt_month
),
-- Суммарное количество сообщений в месяц:
monthly_sms AS (
    SELECT user_id,
           DATE_TRUNC('month', message_date::timestamp)::date AS dt_month,  
           COUNT(message_date) AS month_sms
    FROM telecom.messages
    GROUP BY user_id, dt_month
),
    
    user_activity_months AS (
    SELECT  user_id,
        dt_month
    FROM monthly_duration  
  /* GROUP BY user_id, dt_month
        ORDER BY user_id, dt_month */
           UNION 
          SELECT  user_id,
        dt_month
    FROM monthly_internet
   /* GROUP BY user_id, dt_month
        ORDER BY user_id, dt_month */
            UNION
          SELECT  user_id,
        dt_month
    FROM monthly_sms  
 /* GROUP BY user_id, dt_month
        ORDER BY user_id, dt_month */
        
        
        )
SELECT *
FROM user_activity_months
ORDER BY user_id, dt_month
LIMIT 5

-- 5) Объединяем данные о клиентах в одну таблицу
-- Суммарная длительность разговоров клиента в месяц:
WITH monthly_duration AS (
    SELECT user_id,
           -- Выделяем месяц из даты звонка: 
           DATE_TRUNC('month', call_date::timestamp)::date AS dt_month,    
           CEIL(SUM(duration)) AS month_duration
    FROM telecom.calls
    GROUP BY user_id, dt_month
),
-- Суммарное количество потраченного интернет-трафика в месяц:
monthly_internet AS (
    SELECT user_id,
           DATE_TRUNC('month', session_date::timestamp)::date AS dt_month,  
           SUM(mb_used) AS month_mb_traffic
    FROM telecom.internet
    GROUP BY user_id, dt_month
),
-- Суммарное количество сообщений в месяц:
monthly_sms AS (
    SELECT user_id,
           DATE_TRUNC('month', message_date::timestamp)::date AS dt_month,  
           COUNT(message_date) AS month_sms
    FROM telecom.messages
    GROUP BY user_id, dt_month
),
-- Формирование уникальной пары значений user_id и dt_month:
user_activity_months AS (
    -- Первое множество значений user_id и dt_month с учётом разговорной активности клиента:
    SELECT user_id, dt_month
    FROM monthly_duration
    UNION
    -- Второе множество значений user_id и dt_month с учётом интернет-активности клиента:
    SELECT user_id, dt_month
    FROM monthly_internet   
    UNION
    -- Третье множество значений user_id и dt_month с учётом активности клиента по сообщениям:
    SELECT user_id, dt_month
    FROM monthly_sms
),

       users_stat AS (
           SELECT uam.user_id,
           uam.dt_month, 
          md.month_duration,
           mi.month_mb_traffic,
           ms.month_sms
           FROM user_activity_months AS uam
          LEFT JOIN monthly_duration AS md USING (user_id, dt_month) 
           LEFT JOIN monthly_internet AS mi USING (user_id, dt_month)
           LEFT JOIN monthly_sms AS ms USING (user_id, dt_month) 
          
           )
SELECT *
FROM users_stat

ORDER BY user_id, dt_month
LIMIT 10


-- 6) Траты клиентов вне тарифного лимита
--Вы посчитали основную статистику по использованию услуг компании. Теперь можно приступать к расчёту трат каждого клиента с учётом его тарифного плана.
-- Суммарная длительность разговоров клиента в месяц:
WITH monthly_duration AS (
    SELECT user_id,
           -- Выделяем месяц из даты звонка: 
           DATE_TRUNC('month', call_date::timestamp)::date AS dt_month,    
           CEIL(SUM(duration)) AS month_duration
    FROM telecom.calls
    GROUP BY user_id, dt_month
),
-- Суммарное количество потраченного интернет-трафика в месяц:
monthly_internet AS (
    SELECT user_id,
           DATE_TRUNC('month', session_date::timestamp)::date AS dt_month,  
           SUM(mb_used) AS month_mb_traffic
    FROM telecom.internet
    GROUP BY user_id, dt_month
),
-- Суммарное количество сообщений в месяц:
monthly_sms AS (
    SELECT user_id,
           DATE_TRUNC('month', message_date::timestamp)::date AS dt_month,  
           COUNT(message_date) AS month_sms
    FROM telecom.messages
    GROUP BY user_id, dt_month
),
-- Формирование уникальной пары значений user_id и dt_month:
user_activity_months AS (
    -- Первое множество значений user_id и dt_month с учётом разговорной активности клиента:
    SELECT user_id, dt_month
    FROM monthly_duration
    UNION
    -- Второе множество значений user_id и dt_month с учётом интернет-активности клиента:
    SELECT user_id, dt_month
    FROM monthly_internet   
    UNION
    -- Третье множество значений user_id и dt_month с учётом активности клиента по сообщениям:
    SELECT user_id, dt_month
    FROM monthly_sms
),
-- Соединение посчитанных значений активности клиента в одну таблицу:
users_stat AS (
    SELECT 
        u.user_id,
        u.dt_month,
        month_duration,
        month_mb_traffic,
        month_sms
    -- В качестве основной таблицы используем данные из CTE user_activity_months:
    FROM user_activity_months AS u
    -- Последовательно присоединяем данные по звонкам, интернет-трафику и сообщениям.
    -- При объединении данных используем пары значений user_id и dt_month:
    LEFT JOIN monthly_duration AS md ON u.user_id = md.user_id AND u.dt_month= md.dt_month
    LEFT JOIN monthly_internet AS mi ON u.user_id = mi.user_id AND u.dt_month= mi.dt_month
    LEFT JOIN monthly_sms AS mm ON u.user_id = mm.user_id AND u.dt_month= mm.dt_month
),
        user_over_limits AS (
       SELECT 
        us.user_id,
        us.dt_month,
        tariff,
        us.month_duration,
        us.month_mb_traffic,
        us.month_sms,
            
             CASE
                    WHEN us.month_duration > t.minutes_included
                    THEN us.month_duration - t.minutes_included
                    ELSE 0
             END AS  duration_over,
            
            CASE
                    WHEN us.month_mb_traffic > t.mb_per_month_included
                    THEN (us.month_mb_traffic - t.mb_per_month_included) / 1024
                    ELSE 0
             END AS  gb_traffic_over,
            
              CASE
                    WHEN  us.month_sms > t.messages_included
                    THEN  us.month_sms - t.messages_included
                    ELSE 0
             END AS  sms_over 
            
        FROM users_stat AS us
        LEFT JOIN telecom.users AS u USING (user_id)
        JOIN telecom.tariffs AS t ON u.tariff = t.tariff_name
        )
SELECT *
FROM user_over_limits
ORDER BY user_id, dt_month
LIMIT 10

