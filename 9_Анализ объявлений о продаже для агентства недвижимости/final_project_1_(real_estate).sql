			--Задача 1. Время активности объявлений

WITH clean_data AS ( -- фильтрация данных от выбросов и пропусков
				SELECT id
				FROM real_estate.flats f 
				JOIN real_estate.advertisement a USING (id)
				WHERE 
				total_area < (SELECT percentile_disc(0.99) WITHIN GROUP (ORDER BY total_area) FROM real_estate.flats) AND 
				rooms < (SELECT percentile_disc(0.99) WITHIN GROUP (ORDER BY rooms) FROM real_estate.flats) OR rooms IS NULL AND 
				balcony < (SELECT percentile_cont(0.99) WITHIN GROUP (ORDER BY balcony) FROM real_estate.flats) OR balcony IS null AND
				ceiling_height > (SELECT percentile_disc(0.01) WITHIN GROUP (ORDER BY ceiling_height) FROM real_estate.flats) OR ceiling_height IS NULL AND
				ceiling_height < (SELECT percentile_disc(0.99) WITHIN GROUP (ORDER BY ceiling_height) FROM real_estate.flats) and
				a.last_price > (SELECT percentile_disc(0.01) WITHIN GROUP (ORDER BY last_price) FROM real_estate.advertisement) AND 
				a.last_price < (SELECT percentile_disc(0.99) WITHIN GROUP (ORDER BY last_price) FROM real_estate.advertisement)
				),
	segmented_data AS (
				SELECT *,
					CASE 
						WHEN city = 'Санкт-Петербург'
						THEN 'Санкт-Петербург'
						ELSE 'ЛенОбл'
					END AS region,
					CASE 
						WHEN days_exposition BETWEEN 1 AND 30
							THEN 'до месяца'
						WHEN days_exposition BETWEEN 31 AND 90
							THEN 'до трех месяцев'
						WHEN days_exposition BETWEEN 91 AND 180
							THEN 'до полугода'
						WHEN days_exposition > 180
							THEN 'более полугода'
					END AS activity_segment,
					last_price/total_area :: NUMERIC AS cost_per_square_meter
				FROM real_estate.flats
				JOIN real_estate.advertisement USING (id)
				JOIN real_estate.city USING (city_id)
				JOIN real_estate.type USING (type_id)
				WHERE days_exposition IS NOT NULL AND TYPE = 'город' AND id IN (SELECT id FROM clean_data)
				)
SELECT region,
		activity_segment,
		count(id),
		round ((count (id) * 100 / sum (count(id)) OVER (PARTITION BY (region))) :: numeric, 0) AS shere,
		round (avg (cost_per_square_meter)::numeric, 0) AS avg_cost_per_square_meter,
		round (avg (total_area)::numeric, 1) AS avg_total_area,
		percentile_disc(0.5) WITHIN GROUP (ORDER BY rooms) AS median_rooms,
		round (avg (ceiling_height) ::NUMERIC, 1) AS avg_ceiling_height,
		percentile_disc(0.5) WITHIN GROUP (ORDER BY floor) median_floor,
		round (avg (avg (cost_per_square_meter)) OVER (PARTITION BY region) :: NUMERIC, 0) avg_area_price_by_region
FROM segmented_data
GROUP BY region, activity_segment
ORDER BY region DESC, avg (days_exposition)
		

		--Задача 2. Сезонность объявлений

--1), 3) В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? А в какие — по снятию? Это показывает динамику активности покупателей.
-- Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? Что можно сказать о зависимости этих параметров от месяца?
WITH clean_data AS (
				SELECT id
				FROM real_estate.flats f 
				JOIN real_estate.advertisement a USING (id)
				WHERE 
				--total_area > (SELECT percentile_cont(0.01) WITHIN GROUP (ORDER BY total_area) FROM flats) AND
				total_area < (SELECT percentile_disc(0.99) WITHIN GROUP (ORDER BY total_area) FROM real_estate.flats) AND 
				--rooms > (SELECT percentile_disc(0.01) WITHIN GROUP (ORDER BY rooms) FROM flats) AND
				rooms < (SELECT percentile_disc(0.99) WITHIN GROUP (ORDER BY rooms) FROM real_estate.flats) OR rooms IS NULL AND 
				balcony < (SELECT percentile_cont(0.99) WITHIN GROUP (ORDER BY balcony) FROM real_estate.flats) OR balcony IS null AND
				ceiling_height > (SELECT percentile_disc(0.01) WITHIN GROUP (ORDER BY ceiling_height) FROM real_estate.flats) OR ceiling_height IS NULL AND
				ceiling_height < (SELECT percentile_disc(0.99) WITHIN GROUP (ORDER BY ceiling_height) FROM real_estate.flats) and
				a.last_price > (SELECT percentile_disc(0.01) WITHIN GROUP (ORDER BY last_price) FROM real_estate.advertisement) AND 
				a.last_price < (SELECT percentile_disc(0.99) WITHIN GROUP (ORDER BY last_price) FROM real_estate.advertisement)
				)
SELECT 
CASE 
	WHEN city = 'Санкт-Петербург'
	THEN 'Санкт-Петербург'
	ELSE 'ЛенОбл'
END AS region,
TO_CHAR (first_day_exposition, 'month') month_name,
count (id) cnt_ads,
round (count (id) / sum (count (id)) OVER (PARTITION BY CASE WHEN city = 'Санкт-Петербург' THEN 'Санкт-Петербург' ELSE 'ЛенОбл' END) :: numeric, 2) cnt_ads_share, -- доля кол-ва объявлений, размещенных в этом месяце и в этом регионе за 4 года наблюдения к общему кол-ву в этом регионе за 4 года
round (avg (total_area) ::numeric, 0) AS avg_area,
round (avg (last_price/total_area) ::numeric, 0) AS avg_area_price
--avg (avg (last_price/total_area)) over() - avg (last_price/total_area) AS avg_price_dev
FROM real_estate.advertisement
JOIN real_estate.flats USING (id)
JOIN real_estate.city c USING (city_id)
WHERE first_day_exposition between '2015-01-01' AND '2018-12-31' AND id IN (SELECT id FROM clean_data)
GROUP BY region, TO_CHAR (first_day_exposition, 'month')
ORDER BY region , cnt_ads DESC

-- 2), 3) Совпадают ли периоды активной публикации объявлений и периоды, когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? Что можно сказать о зависимости этих параметров от месяца?
WITH clean_data AS (
				SELECT id
				FROM real_estate.flats f 
				JOIN real_estate.advertisement a USING (id)
				WHERE 
				--total_area > (SELECT percentile_cont(0.01) WITHIN GROUP (ORDER BY total_area) FROM flats) AND
				total_area < (SELECT percentile_disc(0.99) WITHIN GROUP (ORDER BY total_area) FROM real_estate.flats) AND 
				--rooms > (SELECT percentile_disc(0.01) WITHIN GROUP (ORDER BY rooms) FROM flats) AND
				rooms < (SELECT percentile_disc(0.99) WITHIN GROUP (ORDER BY rooms) FROM real_estate.flats) OR rooms IS NULL AND 
				balcony < (SELECT percentile_cont(0.99) WITHIN GROUP (ORDER BY balcony) FROM real_estate.flats) OR balcony IS null AND
				ceiling_height > (SELECT percentile_disc(0.01) WITHIN GROUP (ORDER BY ceiling_height) FROM real_estate.flats) OR ceiling_height IS NULL AND
				ceiling_height < (SELECT percentile_disc(0.99) WITHIN GROUP (ORDER BY ceiling_height) FROM real_estate.flats) and
				a.last_price > (SELECT percentile_disc(0.01) WITHIN GROUP (ORDER BY last_price) FROM real_estate.advertisement) AND 
				a.last_price < (SELECT percentile_disc(0.99) WITHIN GROUP (ORDER BY last_price) FROM real_estate.advertisement)
				),
			t1 AS (
				SELECT id,
				first_day_exposition,
				days_exposition,
				first_day_exposition + days_exposition :: integer AS close_day,
				last_price
				FROM real_estate.advertisement
				WHERE days_exposition IS NOT NULL
				)
SELECT 
CASE 
	WHEN city = 'Санкт-Петербург'
	THEN 'Санкт-Петербург'
	ELSE 'ЛенОбл'
END AS region,
TO_CHAR (close_day, 'month') month_name,
count (id) cnt_ads,
round (count (id) / sum (count (id)) OVER (PARTITION BY CASE WHEN city = 'Санкт-Петербург' THEN 'Санкт-Петербург' ELSE 'ЛенОбл' END) :: numeric, 2) cnt_ads_share, -- доля кол-ва объявлений, снятых в этом месяце и в этом регионе за 4 года наблюдения к общему кол-ву в этом регионе за 4 года
round (avg (total_area) ::numeric, 0) AS avg_area,
round (avg (last_price/total_area) ::numeric, 0) AS avg_area_price
FROM t1
JOIN real_estate.flats USING (id)
JOIN real_estate.city c USING (city_id)
WHERE close_day between '2015-01-01' AND '2018-12-31' AND id IN (SELECT id FROM clean_data)
GROUP BY region, TO_CHAR (close_day, 'month')
ORDER BY region, cnt_ads DESC 


			--Задача 3. Анализ рынка недвижимости Ленобласти
-- 1) В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
-- 2) В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? Это может указывать на высокую долю продажи недвижимости.
--3) Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? Есть ли вариация значений по этим метрикам?
-- 4) Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? То есть где недвижимость продаётся быстрее, а где — медленнее.

WITH clean_data AS (
				SELECT id
				FROM real_estate.flats f 
				JOIN real_estate.advertisement a USING (id)
				WHERE 
				--total_area > (SELECT percentile_cont(0.01) WITHIN GROUP (ORDER BY total_area) FROM flats) AND
				total_area < (SELECT percentile_disc(0.99) WITHIN GROUP (ORDER BY total_area) FROM real_estate.flats) AND 
				--rooms > (SELECT percentile_disc(0.01) WITHIN GROUP (ORDER BY rooms) FROM flats) AND
				rooms < (SELECT percentile_disc(0.99) WITHIN GROUP (ORDER BY rooms) FROM real_estate.flats) OR rooms IS NULL AND 
				balcony < (SELECT percentile_cont(0.99) WITHIN GROUP (ORDER BY balcony) FROM real_estate.flats) OR balcony IS null AND
				ceiling_height > (SELECT percentile_disc(0.01) WITHIN GROUP (ORDER BY ceiling_height) FROM real_estate.flats) OR ceiling_height IS NULL AND
				ceiling_height < (SELECT percentile_disc(0.99) WITHIN GROUP (ORDER BY ceiling_height) FROM real_estate.flats) and
				a.last_price > (SELECT percentile_disc(0.01) WITHIN GROUP (ORDER BY last_price) FROM real_estate.advertisement) AND 
				a.last_price < (SELECT percentile_disc(0.99) WITHIN GROUP (ORDER BY last_price) FROM real_estate.advertisement)
				)
SELECT t1.city,
		TYPE,
	    all_cnt,
	    sold_cnt,
	    round (sold_cnt::numeric / all_cnt,2) AS sold_share,
	   avg_days,
	   avg_area_cost,
	   avg_area
FROM (
    SELECT city, 
    		type,
           count(DISTINCT ID) AS sold_cnt,
           round (avg (days_exposition) :: NUMERIC, 0 ) avg_days,
           round (avg(last_price/total_area) :: NUMERIC,0) AS avg_area_cost, 
           round (avg (total_area) :: NUMERIC, 2 ) avg_area
    FROM real_estate.FLATS f
    JOIN real_estate.city c USING (city_id)
    JOIN real_estate.advertisement a USING (id)
    JOIN real_estate.TYPE USING (type_id)
    WHERE c.city <> 'Санкт-Петербург' AND a.days_exposition IS NOT NULL AND id IN (SELECT id FROM clean_data)
    GROUP BY city, type
   --ORDER BY count(ID) DESC 
    ) t1
JOIN (
-- Количество всех объявлений в Ленобласти по населенным пунктам можно найти по запросу 
    SELECT city,
           count(*) AS all_cnt 
    FROM real_estate.FLATS f
    JOIN real_estate.city c USING (city_id)
    JOIN real_estate.advertisement a USING (id)
    WHERE c.city <> 'Санкт-Петербург' AND id IN (SELECT id FROM clean_data)
    GROUP BY city
   --ORDER BY count(ID) DESC
    ) t2 USING (city)
    WHERE all_cnt >50
ORDER BY  avg_days 
LIMIT 10


-- Архивный код для расчета доли количества объявлений и среднему сроку публикации в разрезе типа населенного пункта

/*WITH clean_data AS (
				SELECT id
				FROM real_estate.flats f 
				JOIN real_estate.advertisement a USING (id)
				WHERE 
				--total_area > (SELECT percentile_cont(0.01) WITHIN GROUP (ORDER BY total_area) FROM flats) AND
				total_area < (SELECT percentile_disc(0.99) WITHIN GROUP (ORDER BY total_area) FROM real_estate.flats) AND 
				--rooms > (SELECT percentile_disc(0.01) WITHIN GROUP (ORDER BY rooms) FROM flats) AND
				rooms < (SELECT percentile_disc(0.99) WITHIN GROUP (ORDER BY rooms) FROM real_estate.flats) OR rooms IS NULL AND 
				balcony < (SELECT percentile_cont(0.99) WITHIN GROUP (ORDER BY balcony) FROM real_estate.flats) OR balcony IS null AND
				ceiling_height > (SELECT percentile_disc(0.01) WITHIN GROUP (ORDER BY ceiling_height) FROM real_estate.flats) OR ceiling_height IS NULL AND
				ceiling_height < (SELECT percentile_disc(0.99) WITHIN GROUP (ORDER BY ceiling_height) FROM real_estate.flats) and
				a.last_price > (SELECT percentile_disc(0.01) WITHIN GROUP (ORDER BY last_price) FROM real_estate.advertisement) AND 
				a.last_price < (SELECT percentile_disc(0.99) WITHIN GROUP (ORDER BY last_price) FROM real_estate.advertisement)
				)
SELECT TYPE,
count (id) cnt_ads,
round (count (id) / sum (count (id)) OVER () :: numeric, 4) ads_share
FROM real_estate.flats
JOIN real_estate.type USING (type_id)
JOIN real_estate.city USING (city_id)
WHERE city <> 'Санкт-Петербург' AND id IN (SELECT id FROM clean_data)
GROUP BY TYPE
order BY count (id) DESC


WITH clean_data AS (
				SELECT id
				FROM real_estate.flats f 
				JOIN real_estate.advertisement a USING (id)
				WHERE 
				--total_area > (SELECT percentile_cont(0.01) WITHIN GROUP (ORDER BY total_area) FROM flats) AND
				total_area < (SELECT percentile_disc(0.99) WITHIN GROUP (ORDER BY total_area) FROM real_estate.flats) AND 
				--rooms > (SELECT percentile_disc(0.01) WITHIN GROUP (ORDER BY rooms) FROM flats) AND
				rooms < (SELECT percentile_disc(0.99) WITHIN GROUP (ORDER BY rooms) FROM real_estate.flats) OR rooms IS NULL AND 
				balcony < (SELECT percentile_cont(0.99) WITHIN GROUP (ORDER BY balcony) FROM real_estate.flats) OR balcony IS null AND
				ceiling_height > (SELECT percentile_disc(0.01) WITHIN GROUP (ORDER BY ceiling_height) FROM real_estate.flats) OR ceiling_height IS NULL AND
				ceiling_height < (SELECT percentile_disc(0.99) WITHIN GROUP (ORDER BY ceiling_height) FROM real_estate.flats) and
				a.last_price > (SELECT percentile_disc(0.01) WITHIN GROUP (ORDER BY last_price) FROM real_estate.advertisement) AND 
				a.last_price < (SELECT percentile_disc(0.99) WITHIN GROUP (ORDER BY last_price) FROM real_estate.advertisement)
				)
SELECT TYPE,
round (avg(days_exposition) :: NUMERIC, 0) avg_days
FROM real_estate.flats f 
JOIN real_estate.type t USING (type_id)
JOIN real_estate.advertisement a USING (id)
JOIN real_estate.city c USING  (city_id)
WHERE id IN (SELECT id FROM clean_data) AND city <> 'Санкт-Петербург'
GROUP BY TYPE
ORDER BY avg_days*/

	