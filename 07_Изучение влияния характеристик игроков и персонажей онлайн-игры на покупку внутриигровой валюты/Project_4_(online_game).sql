/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Вячеслав Зайко
 * Дата: 05.02.2025
 * Версия: 2
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
					--Оптимизировал запрос по полю "payer"
SELECT 
    COUNT(payer) AS total_users, -- общее количество игроков
    SUM(payer) AS total_payers, -- количество платящих (сумма единичек)
    ROUND (AVG(payer):: NUMERIC, 4) AS payers_share -- доля платящих (среднее значение)
FROM fantasy.users



-- 1.2. Доля платящих пользователей в разрезе расы персонажа: 
					--Оптимизировал запрос по полю "payer"
SELECT 
	r.race,
	SUM (payer) paying_users,
	COUNT (id) total_users,
	ROUND (SUM (payer) / COUNT(id) :: NUMERIC, 4) AS paying_users_per_total_users
FROM fantasy.users
LEFT JOIN fantasy.race r USING (race_id)
GROUP BY race
ORDER BY paying_users_per_total_users DESC
	

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount БЕЗ УЧЕТА НУЛЕВЫХ ПОКУПОК:
					--Поменял PERCENTILE_DISC на PERCENTILE_CONT  
SELECT 
	COUNT (transaction_id) AS total_events,
	SUM (amount) AS total_amount,
	MIN (amount) AS min_amount,
	MAX (amount) AS max_amount,
	ROUND (AVG (amount) :: NUMERIC, 2) AS avg_amount,
	ROUND (PERCENTILE_CONT (0.5) WITHIN GROUP (ORDER BY amount) :: NUMERIC, 2)  AS mid_amount,
	ROUND (STDDEV (amount) :: NUMERIC, 2)  AS stddev_amount
FROM fantasy.events e 
WHERE amount <> 0


-- 2.2: Аномальные нулевые покупки:
					-- Заменил подзавпрос в Select на Filter c функцией Count
SELECT 
    COUNT(*) FILTER (WHERE amount = 0) AS zero_amounts, -- количество нулевых покупок
    COUNT(*) AS total_amounts, -- общее количество покупок
    COUNT(*) FILTER (WHERE amount = 0)::REAL / COUNT(*) AS zero_share -- доля нулевых покупок
FROM fantasy.events;


-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
					--Исключил нулевые покупки из анализа и скоректировал тип присоединение, чтобы расчет был только по пользователям с транзакциями
WITH table_1 AS 
	(
	SELECT u.id,
		CASE 
			WHEN payer = 1
			THEN 'Платящие игроки'
			WHEN payer = 0
			THEN 'Неплатящие игроки'
		END AS user_type,
		COUNT(e.transaction_id) AS user_events,
		SUM (e.amount) AS user_amount
	FROM fantasy.users u 
	JOIN fantasy.events e USING (id)
	WHERE amount <> 0
	GROUP BY u.id)
SELECT 
	user_type,
	COUNT (id) AS total_users,
	ROUND (AVG (user_events) :: NUMERIC, 0) AS avg_user_events,
	ROUND (AVG (user_amount) :: NUMERIC, 2) AS avg_user_amount
FROM table_1
group BY user_type
	

-- 2.4: Популярные эпические предметы:
					--Исключил нулевые покупки из анализа и расчитал долю в правом столбце не от всех игроков, а от покупателей
SELECT
	game_items,
	COUNT (transaction_id) transactions_count,
	COUNT (transaction_id) /  (SELECT COUNT (transaction_id) FROM fantasy.events) :: REAL item_trans_per_all_trans,
	COUNT (DISTINCT id) / (SELECT COUNT (DISTINCT id) FROM fantasy.events) :: REAL unique_users_per_all_users
FROM fantasy.events
RIGHT JOIN fantasy.items i USING (item_code)
WHERE amount <> 0
GROUP BY item_code, game_items
ORDER BY transactions_count DESC 


-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
					-- полностью переписал код
WITH 
		table_1 AS ( 
			SELECT
				race_id,
				COUNT (id) total_users
			FROM fantasy.users u 
			GROUP BY race_id
			),
		table_2 AS (
			SELECT 
				race_id,
				COUNT (id) users_with_trans,
				SUM (payer) payers
			FROM fantasy.users u 
			WHERE id IN (SELECT id FROM fantasy.events WHERE amount>0)
			GROUP BY race_id
			),
		table_3 AS (
			SELECT
				race_id,
				COUNT (transaction_id) transactions_count,
				SUM (amount) transactions_amount
				FROM fantasy.events e 
				JOIN fantasy.users USING (id)
				WHERE amount>0
				GROUP BY race_id
			)
	SELECT 
		race,
		total_users, -- общее количество зарегистрированных игроков
		users_with_trans, -- количество игроков, которые совершают внутриигровые ненулевые покупки
		ROUND (users_with_trans / total_users :: NUMERIC, 4) users_with_trans_share, -- их доля от общего количества
		ROUND (payers / users_with_trans :: NUMERIC, 4) payers_share, -- доля платящих игроков от количества игроков, которые совершили ненулевые покупки
		ROUND (transactions_count / users_with_trans :: NUMERIC, 0) avg_transactions_count, -- среднее количество покупок на одного игрока
		ROUND (transactions_amount :: numeric / users_with_trans / (transactions_count / users_with_trans :: NUMERIC), 2) avg_one_transaction_amount, --средняя стоимость одной покупки на одного игрока
		ROUND (transactions_amount :: numeric / users_with_trans, 2) avg_ransactions_amount -- средняя суммарная стоимость всех покупок на одного игрока
	FROM table_1
	JOIN table_2 USING (race_id)
	JOIN table_3 USING (race_id)
	JOIN fantasy.race r USING (race_id)
	ORDER BY payers_share desc

	
	
-- Задача 2: Частота покупок БЕЗ УЧЕТА ПОКУПОК С НУЛЕВОЙ СТОИМОСТЬЮ
WITH 
	transactions AS ( -- расчитываем количество покупок и ср. количество дней между ними по игрокам с фильтрацией
		SELECT
			id, 
			COUNT (transaction_id) trans_count,
			EXTRACT (DAY FROM age(MAX (date :: timestamp), min (date :: timestamp)) / (COUNT (transaction_id)-1)) avg_interval_between_trans
		FROM fantasy.events
		WHERE amount <> 0
		GROUP BY id 
		HAVING COUNT (transaction_id) >=25
			),
	ranked_users AS ( -- ранжируем игроков
		SELECT 
			*,
			NTILE (3) OVER (ORDER BY avg_interval_between_trans) user_rank
		FROM transactions ),
	p_users AS ( 
		SELECT id -- выводим всех платящих игроков
		FROM fantasy.users
		WHERE payer = 1
			)
SELECT CASE 
				WHEN user_rank =1
			THEN 'высокая частота'
				WHEN user_rank =2
			THEN 'умеренная частота'
				WHEN user_rank =3
			THEN 'низкая частота'
		END user_category,
		COUNT (r.id) users_with_trans_count, -- количество игроков, которые совершили покупки
		COUNT (pu.id) paying_users_with_trans_count, -- количество платящих игроков, совершивших покупки
		ROUND (COUNT (pu.id) / COUNT (r.id) :: NUMERIC, 4) paying_users_per_users_with_trans, -- их доля от общего количества игроков, совершивших покупку
		ROUND (AVG (trans_count):: NUMERIC, 0) avg_trans_per_user, -- среднее количество покупок на одного игрока
		ROUND (AVG (avg_interval_between_trans) :: NUMERIC, 0) avg_days_between_trans_per_user -- cреднее количество дней между покупками на одного игрока
FROM ranked_users r
LEFT JOIN p_users pu USING (id)
GROUP BY user_rank
	





































	
	
	
	


