-- 1) Определить регионы с наибольшим количеством зарегистрированных доноров
SELECT
		CASE 	
			WHEN uad.region IS NULL
			THEN 'Регион не указан'
			ELSE uad.region
		END,
	count ( *)
FROM donorsearch.user_anon_data AS uad
GROUP BY uad.region
ORDER BY count ( *) DESC
LIMIT 11;

-- 2) Изучить динамику общего количества донаций в месяц за 2022 и 2023 годы
SELECT 
EXTRACT (YEAR FROM ud.donation_data :: timestamp) AS YEAR,
ROUND (SUM(ud.donation_count) :: numeric / 12, 0) AS avg_donors_per_month,
SUM	(ud.donation_count) AS total_donors
FROM donorsearch.user_donation AS ud
GROUP BY YEAR
HAVING EXTRACT (YEAR FROM ud.donation_data :: timestamp) > 2021
ORDER BY YEAR;

-- 2) Изучить динамику общего количества донаций в месяц за 2022 и 2023 годы
	/*WITH table_2022 AS(
		SELECT
		SUM	(ud.donation_count) AS sum_2022
		FROM donorsearch.user_donation AS ud
		WHERE EXTRACT (YEAR FROM ud.donation_data :: timestamp) = 2022),
			table_2023 AS(
		SELECT
		SUM	(ud.donation_count) AS sum_2023
		FROM donorsearch.user_donation AS ud
		WHERE EXTRACT (YEAR FROM ud.donation_data :: timestamp) = 2023)*/
SELECT 
date_trunc('MONTH', da.donation_date :: timestamp) :: DATE AS MONTH,
count(da.id) AS total_donations
FROM donorsearch.donation_anon AS da
GROUP BY MONTH
HAVING date_trunc('MONTH', da.donation_date :: timestamp) :: DATE BETWEEN '2022-01-01' AND '2023-12-31'
ORDER BY MONTH

--4) Оценить, как система бонусов влияет на зарегистрированные в системе донации. 0, 10, 25, 50, 75, 90

/*SELECT MIN (count_bonuses_taken),
AVG (count_bonuses_taken) ,
MAX (count_bonuses_taken)
FROM donorsearch.user_anon_data */

		WITH t_0 AS
				(SELECT user_id,
				COUNT (da.id) AS c
				FROM  donorsearch.donation_anon da
				LEFT JOIN donorsearch.user_anon_data uad ON  da.user_id = uad.id
				WHERE uad.count_bonuses_taken = 0
				GROUP BY user_id),
			t_1_10 AS
				(SELECT user_id,
				COUNT (da.id) c
				FROM  donorsearch.donation_anon da
				LEFT JOIN donorsearch.user_anon_data uad ON  da.user_id = uad.id
				WHERE uad.count_bonuses_taken BETWEEN 1 AND 10
				GROUP BY user_id),
			t_11_25 AS
				(SELECT user_id,
				COUNT (da.id) c
				FROM  donorsearch.donation_anon da
				LEFT JOIN donorsearch.user_anon_data uad ON  da.user_id = uad.id
				WHERE uad.count_bonuses_taken BETWEEN 11 AND 25
				GROUP BY user_id),
			t_26_50 AS
				(SELECT user_id,
				COUNT (da.id) c
				FROM  donorsearch.donation_anon da
				LEFT JOIN donorsearch.user_anon_data uad ON  da.user_id = uad.id
				WHERE uad.count_bonuses_taken BETWEEN 26 AND 50
				GROUP BY user_id),
			t_51_75 AS
				(SELECT user_id,
				COUNT (da.id) c
				FROM  donorsearch.donation_anon da
				LEFT JOIN donorsearch.user_anon_data uad ON  da.user_id = uad.id
				WHERE uad.count_bonuses_taken BETWEEN 51 AND 75
				GROUP BY user_id),
			t_76_90 AS
				(SELECT user_id,
				COUNT (da.id) c
				FROM  donorsearch.donation_anon da
				LEFT JOIN donorsearch.user_anon_data uad ON  da.user_id = uad.id
				WHERE uad.count_bonuses_taken BETWEEN 76 AND 90
				GROUP BY user_id)		
SELECT 
	EXTRACT (YEAR FROM da.donation_added_date :: timestamp) AS YEAR,
	round (AVG (t_0.c) :: NUMERIC) count_bonuses_0,
	round (AVG (t_1_10.c) :: NUMERIC) count_bonuses_1_10,
	round (AVG (t_11_25.c) :: NUMERIC) count_bonuses_11_25,
	round (AVG (t_26_50.c) :: NUMERIC) count_bonuses_26_50,
	round (AVG (t_51_75.c) :: NUMERIC) count_bonuses_51_75,
	round (AVG (t_76_90.c) :: NUMERIC) count_bonuses_76_90
FROM donorsearch.donation_anon AS da
LEFT JOIN t_0 USING (user_id)
LEFT JOIN t_1_10 USING (user_id)
LEFT JOIN t_11_25 USING (user_id)
LEFT JOIN t_26_50 USING (user_id)
LEFT JOIN t_51_75 USING (user_id)
LEFT JOIN t_76_90 USING (user_id)
GROUP BY YEAR
ORDER BY YEAR;

--3) Определить наиболее активных доноров в системе, учитывая только данные о зарегистрированных и подтвержденных донациях.

SELECT
id,
COALESCE (donations_of_time_registration, 0) donations_of_time_registration,
confirmed_donations,
COALESCE (donations_of_time_registration + confirmed_donations, confirmed_donations)  AS total_donations
FROM donorsearch.user_anon_data uad 
ORDER BY total_donations DESC 
LIMIT 5

-- 5) Исследовать вовлечение новых доноров через социальные сети, учитывая только тех, кто совершил хотя бы одну донацию. 
--Узнать, сколько по каким каналам пришло доноров, и среднее количество донаций по каждому каналу.

SELECT 
	CASE 
		WHEN autho_vk THEN 'ВКонтакте'
		WHEN autho_ok THEN 'Одноклассники'
		WHEN autho_tg THEN 'Telegram'
		WHEN autho_yandex THEN 'Яндекс'
		WHEN autho_google THEN 'Google'
		ELSE 'Без регистрации через соцсеть'	
	END AS registration_channel,
	COUNT (id) count_users,
	ROUND (AVG (confirmed_donations):: NUMERIC, 2) avg_donation
FROM donorsearch.user_anon_data
WHERE user_anon_data.confirmed_donations >=1
GROUP BY registration_channel
ORDER BY count_users DESC

--6) Сравнить активность однократных доноров со средней активностью повторных доноров.

SELECT 
	CASE 
		WHEN user_anon_data.confirmed_donations =1 THEN 'Однократные доноры'
		WHEN user_anon_data.confirmed_donations >1 THEN 'Повторные доноры'
		ELSE 'Доноры без подтвержденных донаций'	
	END AS donor_type,
	COUNT (id) count_users,
	ROUND (AVG (confirmed_donations):: NUMERIC, 0) avg_donation
FROM donorsearch.user_anon_data
GROUP BY donor_type
ORDER BY count_users;

WITH donor_activity AS (
  SELECT user_id,
         COUNT(*) AS total_donations,
         (MAX(donation_date) - MIN(donation_date)) AS activity_duration_days,
         (MAX(donation_date) - MIN(donation_date)) / (COUNT(*) - 1) AS avg_days_between_donations,
         EXTRACT(YEAR FROM MIN(donation_date)) AS first_donation_year,
         EXTRACT(YEAR FROM AGE(CURRENT_DATE, MIN(donation_date))) AS years_since_first_donation
  FROM donorsearch.donation_anon
  GROUP BY user_id
  HAVING COUNT(*) > 1
)
SELECT first_donation_year,
       CASE 
           WHEN total_donations BETWEEN 2 AND 3 THEN '2-3 донации'
           WHEN total_donations BETWEEN 4 AND 5 THEN '4-5 донаций'
           ELSE '6 и более донаций'
       END AS donation_frequency_group,
       COUNT(user_id) AS donor_count,
       AVG(total_donations) AS avg_donations_per_donor,
       AVG(activity_duration_days) AS avg_activity_duration_days,
       AVG(avg_days_between_donations) AS avg_days_between_donations,
       AVG(years_since_first_donation) AS avg_years_since_first_donation
FROM donor_activity
GROUP BY first_donation_year, donation_frequency_group
ORDER BY first_donation_year, donation_frequency_group;
  
	
--7) Сравнить данные о планируемых донациях с фактическими данными, чтобы оценить эффективность планирования
-- разбив по годам
-- кол план сред
-- план общ
-- кол факт сред
-- кол факт общ

WITH plan_donation AS
		( SELECT user_id,
		plan_date,
		donation_date,
		donation_type
		FROM donorsearch.donation_plan
			),
	actual_donation AS
		(SELECT user_id,
		plan_date,
		donation_date
		FROM donorsearch.donation_anon
			),
	planed_vs_actual AS (
	SELECT
	pd.user_id,
    pd.donation_date AS planned_date,
    pd.donation_type,
    CASE WHEN ad.user_id IS NOT NULL THEN 1 ELSE 0 END AS completed
  FROM plan_donation pd
  LEFT JOIN actual_donation ad USING (user_id, donation_date) )
SELECT 
	donation_type,
	count (*) AS total_planed_donations,
	sum (completed) AS completed_donations,
	round (sum (completed) *100.0 / count (*) , 2) AS complition_rate
FROM planed_vs_actual
GROUP BY donation_type
	
FROM planed_vs_actual
SELECT EXTRACT (YEAR FROM da.donation_date :: timestamp) AS YEAR,
count (id) total_count,
count (pf.id),
Round (count (pf.id) / count (id):: numeric *100, 1 ) AS percent
FROM donorsearch.donation_anon da
LEFT JOIN count_planfact pf USING (id)
group BY EXTRACT (YEAR FROM da.donation_date :: timestamp)
HAVING EXTRACT (YEAR FROM da.donation_date :: timestamp) BETWEEN 2020 AND EXTRACT(YEAR FROM CURRENT_DATE)

---


