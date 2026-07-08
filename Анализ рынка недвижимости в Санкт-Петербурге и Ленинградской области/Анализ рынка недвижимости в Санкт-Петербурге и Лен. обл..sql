/* Анализ данных для агентства недвижимости
 *
 * Автор: Мельников Даниил
 * Дата:22.12.25
 * 
 * Описание кейса:
 * Агентство недвижимости планирует выйти на рынок Санкт-Петербурга и Ленинградской области. Необходимо подготовить анализ объявлений о продаже
 * жилой недвижимости в данных регионах, чтобы найти самые перспективные сегменты недвижимости.
*/



-- Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats),     
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)),     
categorization AS(
SELECT filtered_id.*,
--Категоризация по региону
	CASE
		WHEN city_id = '6X8I' THEN 'Санкт-Петербург'
		ELSE 'ЛенОбл'
	END AS region,
--Категоризация по времени активности	
	CASE
		WHEN days_exposition BETWEEN 1 AND 30 THEN 'около одного месяца'
		WHEN days_exposition BETWEEN 31 AND 90 THEN 'от одного до трех месяцев'
		WHEN days_exposition BETWEEN 91 AND 180 THEN 'от трех месяцев до полугода'
		WHEN days_exposition >= 181 THEN 'более полугода'
		ELSE 'non category'
	END AS activity_cat
FROM filtered_id
LEFT JOIN real_estate.flats USING(id)
LEFT JOIN real_estate.city USING(city_id)
LEFT JOIN real_estate.advertisement USING(id)
LEFT JOIN real_estate.type USING(type_id)
WHERE TYPE = 'город' AND EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018)
SELECT region,
		activity_cat,
		-- Количество объявлений:
		COUNT(*) AS advertisement_count,
		-- Доля объявлений:
		ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY region), 2) AS advertisement_share,
		-- Средняя стоимость кв. м.:
		ROUND(AVG(last_price / total_area)::numeric, 2) AS avg_price_per_sqm,
		-- Средняя площадь:
		ROUND(AVG(total_area)::numeric, 2) AS avg_total_area,
		-- Медиана количества комнат:
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS rooms_mediana,
		-- Медиана количества балконов:
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS balcony_mediana,
		-- Медиана количества этажей:
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS floor_mediana 
FROM categorization
LEFT JOIN filtered_id USING(id)
LEFT JOIN real_estate.flats f USING(id)
LEFT JOIN real_estate.advertisement a USING(id)
WHERE activity_cat != 'non category'
GROUP BY region, activity_cat
ORDER BY region DESC,
		CASE activity_cat 
			WHEN 'около одного месяца' THEN 1
			WHEN 'от одного до трех месяцев' THEN 2
			WHEN 'от трех месяцев до полугода' THEN 3
			WHEN 'более полугода' THEN 4
		END;

-- Результат:
-- region         |activity_cat               |advertisement_count|advertisement_share|avg_price_per_sqm|avg_total_area|rooms_mediana|balcony_mediana|floor_mediana|
-- ---------------+---------------------------+-------------------+-------------------+-----------------+--------------+-------------+---------------+-------------+
-- Санкт-Петербург|около одного месяца        |               1794|              16.98|        108919.78|         54.66|            2|            1.0|            5|
-- Санкт-Петербург|от одного до трех месяцев  |               3020|              28.59|        110874.32|         56.58|            2|            1.0|            5|
-- Санкт-Петербург|от трех месяцев до полугода|               2244|              21.24|        111973.67|         60.55|            2|            1.0|            5|
-- Санкт-Петербург|более полугода             |               3506|              33.19|        114981.07|         65.76|            2|            1.0|            5|
-- ЛенОбл         |около одного месяца        |                340|              12.93|         71907.63|         48.75|            2|            1.0|            4|
-- ЛенОбл         |от одного до трех месяцев  |                864|              32.85|         67423.80|         50.85|            2|            1.0|            3|
-- ЛенОбл         |от трех месяцев до полугода|                553|              21.03|         69809.30|         51.83|            2|            1.0|            3|
-- ЛенОбл         |более полугода             |                873|              33.19|         68215.11|         55.03|            2|            1.0|            3|

-- Наиболее распространенной является категория «более полугода» в обоих регионах, хотя в Ленинградской области примерно в равных соотношениях
-- популярна категория "от одного до трех месяцев". В Санкт-Петербурге в категории "более полугода" наблюдается 3506 объявлений (33% от общего числа),
-- а Ленинградской области – 873 (те же 33% от общего числа). Соответственно, если в Санкт-Петербурге преобладает длительная продажа,
-- то в Ленинградской области квартиры либо продаются быстро, либо также ожидают своего покупателя более полугода.

-- В Санкт-Петербурге стоимость квадратного метра примерно равна в разрезе категорий активности, но чуть выше в категории "более полугода",
-- т.е. более высокая стоимость одного квадратного время может влиять на сроки продажи, но ключевым критерием не является.
-- И в Санкт-Петербурге, и в Ленинградской области быстрее всего продаются квартиры с наименьшей площадью. Такие показатели, как кол-во комнат,
-- балконов, этажность имеют примерно равные значения в разрезе категорий, поэтому прямого влияния на скорость продажи они не оказывают.

-- Различия между недвижимостью в Санкт-Петербурге и Ленинградской областью:
-- 1. Более высокая стоимость одного квадратного метра в Санкт-Петербурге (почти в два раза);
-- 2. Объявлений о продаже количественно больше в Санкт-Петербурге;
-- 3. Средняя этажность домов также выше в Санкт-Петербурге.


-- Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
filtered_data AS(
SELECT id,
		last_price,
		total_area,
		-- Месяц публикации:
		EXTRACT(MONTH FROM a.first_day_exposition) AS exposition_month,
		-- Месяц снятия с публикации:
		EXTRACT(MONTH FROM a.first_day_exposition + INTERVAL '1 day' * a.days_exposition) AS removal_month 
FROM filtered_id
LEFT JOIN real_estate.advertisement a USING(id)
LEFT JOIN real_estate.flats f USING(id)
LEFT JOIN real_estate."type" t USING(type_id)
WHERE EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018 AND type_id = 'F8EM'),
exposition_stats AS(
SELECT exposition_month,
		-- Количество объявлений
		COUNT(id) AS exp_id_count,
		-- Средняя стоимость кв. м.:
		ROUND(AVG(last_price / total_area)::NUMERIC, 2) AS exp_avg_price_per_sqm, 
		-- Средняя площадь:
		ROUND(AVG(total_area)::numeric,2) AS exp_avg_total_area
FROM filtered_data
GROUP BY exposition_month),
removal_stats AS(
SELECT removal_month,
		COUNT(id) AS re_id_count,
		ROUND(AVG(last_price / total_area)::NUMERIC, 2) AS re_avg_price_per_sqm,
		ROUND(AVG(total_area)::numeric, 2) AS re_avg_total_area
FROM filtered_data
GROUP BY removal_month)
SELECT coalesce(exposition_month,removal_month) AS month_num,
		exp_id_count,
		exp_avg_price_per_sqm,
		exp_avg_total_area,
		re_id_count,
		re_avg_price_per_sqm,
		re_avg_total_area
FROM exposition_stats 
FULL JOIN removal_stats ON exposition_month = removal_month
WHERE exposition_month IS NOT NULL AND removal_month IS NOT NULL
ORDER BY month_num;

-- Результат:
-- month_num|exp_id_count|exp_avg_price_per_sqm|exp_avg_total_area|re_id_count|re_avg_price_per_sqm|re_avg_total_area|
-- ---------+------------+---------------------+------------------+-----------+--------------------+-----------------+
--         1|         735|            106106.24|             59.16|       1225|           104947.31|            57.53|
--         2|        1369|            103058.51|             60.10|       1048|           103883.72|            61.12|
--         3|        1119|            102429.95|             60.00|       1071|           106832.40|            60.37|
--         4|        1021|            102632.41|             60.60|       1031|           102444.24|            59.22|
--         5|         891|            102465.12|             59.19|        729|            99724.07|            57.78|
--         6|        1224|            104802.15|             58.37|        771|           101863.69|            59.82|
--         7|        1149|            104488.96|             60.42|       1108|           102290.72|            58.54|
--         8|        1166|            107034.70|             58.99|       1137|           100036.51|            56.83|
--         9|        1341|            107563.12|             61.04|       1238|           104070.07|            57.49|
--        10|        1437|            104065.11|             59.43|       1360|           104317.33|            58.86|
--        11|        1569|            105048.80|             59.58|       1301|           103791.36|            56.71|
--        12|        1024|            104775.39|             58.84|       1175|           105504.52|            59.26|

-- Наиболее часто объявления о публикации появляются в осенний период - в октябре и ноябре. В этот же период наблюдается наибольшая активность
-- по снятию публикаций (предполагаем продажу), т.е. октябрь и ноябрь - это пиковые месяцы нарынке недвижимости в Санкт-Петербурге и Ленинградской
-- области.
-- Периоды активной публикации объявлений и периоды, когда происходит повышенная продажа недвижимости практически совпадают. В заданный период
-- времени в октябре было опубликовано 1437 объявлений и снято 1360, а в ноябре - 1569 и 1301 объявление соответственно.
-- Весной в период наименьшей активности наблюдается снижение средней цены за квадратный метр при размещении, а в осенний период, наоборот, цена за
-- квадратный метр наибольшая, т.к. это самый активный сезон на рынке недвижимости. При этом разброс значений средней площади квартир незначителен,
-- от 57 до 61 кв м.

-- Общие выводы и рекомендации:
-- В Санкт-Петербурге стоит обратить внимание на длительную продажу (более полугода), т.к. наблюдается наибольшая цена за кв м, и такие объявлления
-- пользуются наибольшим спросом. В Ленинградской области можно сделать акцент на продаже небольших (по площади) квартир, но в быстрые сроки
-- (от 1 до 3 месяцев). Сезонность рынка недвижимости в данных регионах выражена явна. Ростцен продаж зимой и весной, летний спад, затем выход на пик
-- активности осенью.
