Задача 1. Расчёт DAU
Первая задача — расчёт DAU. Рассчитайте ежедневное количество активных зарегистрированных клиентов (user_id) за май и июнь 2021 года в городе Саранске. Критерием активности клиента считайте размещение заказа. Это позволит оценить эффективность вовлечения клиентов в ключевую бизнес-цель — совершение покупки.

SELECT log_date AS  "Дата события",
COUNT (distinct user_id) AS DAU
FROM analytics_events
WHERE (log_date BETWEEN '2021-05-01' AND '2021-06-30') AND city_id in (select city_id from cities where city_name = 'Саранск') AND event = 'order'
GROUP BY log_date
ORDER BY log_date
LIMIT 10



Задача 2. Расчёт Conversion Rate
Теперь вам нужно определить активность аудитории: как часто зарегистрированные пользователи переходят к размещению заказа, будет ли одинаковым этот показатель по дням или видны сезонные колебания в поведении пользователей. Для решения этой задачи рассчитайте конверсию зарегистрированных пользователей, которые посещают приложение, в активных клиентов. Напомним, что критерий активности — размещение заказа. Конверсия должна быть рассчитана за каждый день в мае и июне 2021 года для клиентов из Саранска.

SELECT
    log_date AS "Дата события",
    ROUND (COUNT (DISTINCT user_id) FILTER (WHERE event = 'order') :: numeric /
    COUNT (DISTINCT user_id), 2 ) AS CR
FROM analytics_events
WHERE (log_date BETWEEN '2021-05-01' AND '2021-06-30') AND city_id in (select city_id from cities where city_name = 'Саранск')
GROUP BY log_date
ORDER BY log_date
LIMIT 10

Задача 3. Расчёт среднего чека
Следующая метрика, за которой следят аналитики сервиса «Всё.из.кафе», — средний чек. В рамках этой задачи вам предстоит рассчитать средний чек активных клиентов в Саранске в мае и в июне.
Напомним: средний чек — это средний доход за одну транзакцию, то есть заказ. Учитывайте, что вы анализируете средний чек сервиса доставки, а не ресторанов. Значит, вам необходимо вычислить его как среднее значение комиссии со всех заказов за месяц. Таким образом, для корректного расчёта метрики вычислите общий размер комиссии и количество заказов. Разделив сумму комиссии на количество заказов, вы рассчитаете величину среднего чека за месяц.

-- Рассчитываем величину комиссии с каждого заказа, отбираем заказы по дате и городу
WITH orders AS
    (SELECT *,
            revenue * commission AS commission_revenue
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE revenue IS NOT NULL
         AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск')

-- Напишите ваш код 
SELECT 
    DATE_TRUNC ('month', log_date) :: date AS "Месяц",
    COUNT (DISTINCT order_id) AS "Количество заказов",
    ROUND (SUM (commission_revenue):: numeric, 2) AS "Сумма комиссии",
    ROUND (SUM (commission_revenue) :: numeric / COUNT (DISTINCT order_id) , 2) AS "Средний чек"
FROM orders
GROUP BY 1
ORDER BY 1



Задача 4. Расчёт LTV ресторанов
Определите три ресторана из Саранска с наибольшим LTV с начала мая до конца июня. Как правило, LTV рассчитывается для пользователя приложения. Однако клиентами для сервиса доставки будут и рестораны, как и пользователи, которые делают заказы.
В рамках этой задачи считайте LTV как суммарную комиссию, которая была получена от заказов в ресторане за эти два месяца.

-- Рассчитываем величину комиссии с каждого заказа, отбираем заказы по дате и городу
WITH orders AS
    (SELECT analytics_events.rest_id,
            analytics_events.city_id,
            revenue * commission AS commission_revenue
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE revenue IS NOT NULL
         AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск')

SELECT orders.rest_id,
       chain AS "Название сети",
       type AS "Тип кухни",
       ROUND(SUM(commission_revenue)::numeric, 2) AS LTV
FROM orders
JOIN partners ON orders.rest_id = partners.rest_id AND orders.city_id = partners.city_id
GROUP BY 1, 2, 3
ORDER BY LTV DESC
LIMIT 3;

Задача 5. Расчёт LTV ресторанов — самые популярные блюда
Как вы видите, наибольший LTV с большим отрывом у двух ресторанов Саранска: «Гурманское Наслаждение» и «Гастрономический Шторм». Теперь вам нужно узнать, сколько LTV принесли пять самых популярных блюд этих ресторанов. При этом популярных блюд должно быть всего пять, а не по пять из каждого ресторана.
Вам необходимо проанализировать данные о ресторанах и их блюдах, чтобы определить вклад самых популярных блюд из двух ресторанов Саранска — «Гурманское Наслаждение» и «Гастрономический Шторм» — в общий показатель LTV. Для этого нужно выбрать пять блюд с максимальным LTV за весь рассматриваемый период, то есть за май — июнь, из этих двух ресторанов.
Для каждого блюда требуется вывести название ресторана, название блюда, признаки того, является ли блюдо острым, рыбным или мясным, а также значение LTV, округлённое до копеек.


-- Рассчитываем величину комиссии с каждого заказа, отбираем заказы по дате и городу
WITH orders AS
    (SELECT analytics_events.rest_id,
            analytics_events.city_id,
            analytics_events.object_id,
            revenue * commission AS commission_revenue
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE revenue IS NOT NULL
         AND log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск'), 

-- Рассчитываем два ресторана с наибольшим LTV 
top_ltv_restaurants AS
    (SELECT orders.rest_id,
            chain,
            type,
            ROUND(SUM(commission_revenue)::numeric, 2) AS LTV
     FROM orders
     JOIN partners ON orders.rest_id = partners.rest_id AND orders.city_id = partners.city_id
     GROUP BY 1, 2, 3
     ORDER BY LTV DESC
     LIMIT 2)

-- Напишите ваш код ниже
SELECT 
chain AS "Название сети",
name AS "Название блюда",
spicy,
fish,
meat,
ROUND (SUM (commission_revenue):: numeric, 2) AS LTV
FROM orders
JOIN top_ltv_restaurants USING (rest_id)
JOIN dishes USING (object_id)
GROUP BY 1, 2, 3, 4, 5
ORDER BY LTV DESC
LIMIT 5

Задача 6. Расчёт Retention Rate
В рамках этой задачи вам предстоит определить показатель возвращаемости: какой процент пользователей возвращается в приложение в течение первой недели после регистрации и в какие дни. Рассчитайте показатель Retention Rate в первую неделю для всех новых пользователей в Саранске.
Напомним, что в проекте вы анализируете данные за май и июнь, и для корректного расчёта недельного Retention Rate нужно, чтобы с момента первого посещения прошла хотя бы неделя. Поэтому для этой задачи ограничьте дату первого посещения продукта, выбрав промежуток с начала мая по 24 июня. Retention Rate считайте по любой активности пользователей, а не только по факту размещения заказа.
В данных могут встречаться дубликаты по полю user_id, поэтому для корректного расчёта используйте условие log_date >= first_date.
Вам необходимо вывести следующие поля:
day_since_install — срок жизни пользователя в днях.
retained_users — количество пользователей, которые вернулись в приложение в конкретный день.
retention_rate — коэффициент удержания для вернувшихся пользователей по отношению к общему числу пользователей, которые установили приложение.
Результаты отсортируйте по полю day_since_install в порядке возрастания. Округлите метрику Retention Rate до двух знаков после точки.

-- Рассчитываем новых пользователей по дате первого посещения продукта
WITH new_users AS
    (SELECT DISTINCT first_date,
                     user_id
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE first_date BETWEEN '2021-05-01' AND '2021-06-24'
         AND city_name = 'Саранск'),

-- Рассчитываем активных пользователей по дате события
active_users AS
    (SELECT DISTINCT log_date,
                     user_id
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск'),

daily_retention AS (
SELECT n.user_id,
first_date,
log_date::date - first_date::date AS day_since_install
FROM new_users n
JOIN active_users a
on n.user_id = a.user_id
WHERE log_date >= first_date)

SELECT
    day_since_install,
    COUNT(DISTINCT user_id) AS retained_users,
    ROUND (1.0 * COUNT(DISTINCT user_id) / MAX(COUNT(DISTINCT user_id)) OVER():: numeric, 2) AS retention_rate
FROM daily_retention
WHERE day_since_install < 8
GROUP BY day_since_install
ORDER BY day_since_install

Задача 7. Сравнение Retention Rate по месяцам
Используя эталонный код из предыдущей задачи, разделите пользователей на две когорты по месяцу первого посещения продукта. Так вы сможете сравнить Retention Rate этих когорт между собой.


-- Рассчитываем новых пользователей по дате первого посещения продукта
WITH new_users AS
    (SELECT DISTINCT first_date,
                     user_id
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE first_date BETWEEN '2021-05-01' AND '2021-06-24'
         AND city_name = 'Саранск'),

-- Рассчитываем активных пользователей по дате события
active_users AS
    (SELECT DISTINCT log_date,
                     user_id
     FROM analytics_events
     JOIN cities ON analytics_events.city_id = cities.city_id
     WHERE log_date BETWEEN '2021-05-01' AND '2021-06-30'
         AND city_name = 'Саранск'),

-- Соединяем таблицы с новыми и активными пользователями
daily_retention AS
    (SELECT new_users.user_id,
            first_date,
            log_date::date - first_date::date AS day_since_install
     FROM new_users
     JOIN active_users ON new_users.user_id = active_users.user_id
     AND log_date >= first_date)
     
SELECT DISTINCT CAST(DATE_TRUNC('month', first_date) AS date) AS "Месяц",
                day_since_install,
                COUNT(DISTINCT user_id) AS retained_users,
                ROUND((1.0 * COUNT(DISTINCT user_id) / MAX(COUNT(DISTINCT user_id)) OVER (PARTITION BY CAST(DATE_TRUNC('month', first_date) AS date) ORDER BY day_since_install))::numeric, 2) AS retention_rate
FROM daily_retention
WHERE day_since_install < 8
GROUP BY "Месяц", day_since_install
ORDER BY "Месяц", day_since_install;

