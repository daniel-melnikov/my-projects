/* Анализ активности и мотивации доноров DonorSearch
 * 
 * Автор: Мельников Даниил
 * Дата: 10.06.2026
 * 
 * Описание кейса:
 * Проект DonorSearch, занимающийся популяризацией донорства, запросил провести анализ данных
 * с целью выявления факторов, влияющих на активность доноров, и разработки стратегий для их мотивации.
 */

-- Количество зарегистрированных доноров по регионам:
SELECT
	region,
	COUNT(DISTINCT id) AS reg_count,
	ROUND(COUNT(DISTINCT id) * 100.0 / (SELECT COUNT(id) FROM donorsearch.user_anon_data uad), 2) AS reg_count_perc 
FROM donorsearch.user_anon_data uad 
WHERE registration_date IS NOT NULL
GROUP BY region 
ORDER BY reg_count DESC
LIMIT 5;

-- Результат:
-- region                         |reg_count|reg_count_perc|
-- -------------------------------+---------+--------------+
--                                |   100574|         37.83|
-- Россия, Москва                 |    37819|         14.23|
-- Россия, Санкт-Петербург        |    13137|          4.94|
-- Россия, Татарстан, Казань      |     6610|          2.49|
-- Украина, Киевская область, Киев|     3541|          1.33|

-- Наибольшее количество зарегистрированных доноров наблюдается в Москве и Санкт-Петербурге.
-- Однако почти у 40% доноров не указан регион, что необходимо исправить для корректного анализа данных.


-- Динамика донаций по месяцам:
SELECT
	DATE_TRUNC('month', donation_date) AS month,
	COUNT(id) AS donation_count
FROM donorsearch.donation_anon da  
WHERE donation_date BETWEEN '2022-01-01' AND '2023-12-31'
GROUP BY month;

--Результат:
-- month                        |donation_count|
-- -----------------------------+--------------+
-- 2023-10-01 00:00:00.000 +0300|          2117|
-- 2023-11-01 00:00:00.000 +0300|          1509|
-- 2023-08-01 00:00:00.000 +0300|          2433|
-- и т.д.

-- В 2022 г. наблюдается планомерный рост с января по апрель, затем просадка в мае и вновь постепенный рост вплоть до конца года.
-- В 2023 г. количество донаций в первой половине года стабильно высокое, далее наблюдается спад вплоть до ноября (данные за декабрь отсутствуют)
-- В оба года наблюдается сезонное повышение активности в марте и апреле.


-- Наиболее активные доноры:
SELECT 
	user_id,
	COUNT(id) AS confirmed_donations
FROM donorsearch.donation_anon da
GROUP BY user_id
ORDER BY confirmed_donations DESC
LIMIT 5;

-- Результат:
-- user_id|confirmed_donations|
-- -------+-------------------+
--  235391|                361|
--  273317|                256|
--  201521|                236|
--  211970|                236|
--  132946|                227|

-- В топ-10 самых активных доноров входят те, кто совершил более 200 донаций, самым активным стал донор с 361 донацией.


-- Влияние системы бонусов на активность зарегистрированных доноров:
WITH user_activity AS(
	SELECT
		uad.id,
		uad.confirmed_donations,
		COALESCE(user_bonus_count, 0) AS user_bonus_count
	FROM donorsearch.user_anon_data uad
	LEFT JOIN donorsearch.user_anon_bonus uab ON uad.id = uab.user_id
)
SELECT
	CASE 
		WHEN user_bonus_count > 0 THEN 'Бонусы начислены'
		ELSE 'Бонусы не начислены'
	END AS bonus_status,
	COUNT(id) AS users_count,
	AVG(confirmed_donations) AS avg_confirmed_donations
FROM user_activity
GROUP BY bonus_status;

--Результат:
-- bonus_status       |users_count|avg_confirmed_donations|
-- -------------------+-----------+-----------------------+
-- Бонусы начислены   |      21108|    13.9017907902217169|
-- Бонусы не начислены|     256491| 0.52503596617425172813|

-- Доноры, которые получили бонусы, активнее принимают участие в донациях, чем те, кто их не получил.
-- Следовательно, можно говорить о том, что программа лояльности влияет на количество донаций.
-- Поскольку количество доноров, получивших бонусы (21108), значительно меньше не получивших, рекомендовано расширить программу лояльности
-- с целью увеличения количества донаций и удержаниях наиболее активных доноров.


--Каналы привлечения новых доноров:
SELECT 
	CASE 
		WHEN autho_vk THEN 'VK'
		WHEN autho_ok THEN 'Одноклассники'
		WHEN autho_tg THEN 'Telegram'
		WHEN autho_yandex THEN 'Яндекс'
		WHEN autho_google THEN 'Google'
		ELSE 'Не авторизован через соц. сети'
	END AS channel,
	COUNT(id) AS users_count,
	ROUND(AVG(confirmed_donations), 2) AS avg_confirmed_donations
FROM donorsearch.user_anon_data uad
GROUP BY channel
ORDER BY users_count DESC, avg_confirmed_donations DESC;

-- Результат:
-- channel                       |users_count|avg_confirmed_donations|
-- ------------------------------+-----------+-----------------------+
-- VK                            |     127254|                   0.91|
-- Не авторизован через соц. сети|     113266|                   0.71|
-- Google                        |      14292|                   1.08|
-- Одноклассники                 |       6410|                   0.56|
-- Яндекс                        |       4133|                   1.73|
-- Telegram                      |        481|                   1.17|

-- Наибольшее количество доноров авторизованы через Вконтакте, однако уровень их активности средний (0.91 донация).
-- Также значительная часть доноров не использует соцсети для авторизации, и уровень их вовлеченности низкий (0.71).
-- Наибольшую вовлеченность демонстрируют доноры, авторизованные через Яндекс, их среднее кол-во донаций (1.73) значительно выше
-- чем в других каналов привлечения, при низких охватах аудитории.
-- Также высокие показатели вовлеченности демонстрируют доноры, пришедшие через Telegram (1,17), при этом охват аудитории также является низким.
-- Google имеет средний уровень вовлеченности (1.08), а Одноклассники - самый низкий (0.56 донаций).

-- Рекомендовано:
-- 1) усилить маркетинговые кампании в Яндексе и Telegram для привлечения новых активных доноров.
-- 2) стимулировать пользователей, не использующих соц. сетей, программой предложений и акций для повышения их активности.


--Активность повторных доноров:
WITH donor_activity AS(
	SELECT
		user_id,
		COUNT(id) AS donations_count,
		-- Количество дней между первой и последней донации донора:
		MAX(donation_date) - MIN(donation_date) AS activity_days,
		-- Среднее количество дней между донациями:
		(MAX(donation_date) - MIN(donation_date)) / (COUNT(id) - 1) AS avg_days_between_donations,
		-- Год первой донации:
		EXTRACT(YEAR FROM MIN(donation_date)) AS first_donation_year, 
		-- Сколько лет прошло с момента первой донации:
		EXTRACT(YEAR FROM AGE(CURRENT_DATE, MIN(donation_date))) AS years_since_first_donation
	FROM donorsearch.donation_anon da
	GROUP BY user_id
	HAVING COUNT(id) > 1
)
SELECT 
	first_donation_year,
	CASE
		WHEN donations_count BETWEEN 2 AND 3 THEN '2-3 донации'
		WHEN donations_count BETWEEN 4 AND 5 THEN '4-5 донации'
		ELSE '6 и более донаций'
	END AS donations_count_category,
	COUNT(user_id) AS users_count,
	ROUND(AVG(donations_count), 2) AS avg_donations,
	ROUND(AVG(activity_days), 2) AS avg_activity_days,
	ROUND(AVG(avg_days_between_donations), 2) AS avg_days_between_donations,
	ROUND(AVG(years_since_first_donation), 2) AS avg_years_since_first_donation
FROM donor_activity
GROUP BY first_donation_year, donations_count_category
ORDER BY first_donation_year, donations_count_category;

-- Результат:
-- first_donation_year|donations_count_category|users_count|avg_donations|avg_activity_days|avg_days_between_donations|avg_years_since_first_donation|
-- -------------------+------------------------+-----------+-------------+-----------------+--------------------------+------------------------------+
--                 201|6 и более донаций       |          1|        26.00|        663670.00|                  26546.00|                       1825.00|
--                 207|6 и более донаций       |          1|        37.00|        661775.00|                  18382.00|                       1819.00|
--                 208|6 и более донаций       |          1|         7.00|        660907.00|                 110151.00|                       1818.00|
--                 214|6 и более донаций       |          1|        39.00|        658841.00|                  17337.00|                       1811.00|
--                1019|6 и более донаций       |          1|        33.00|        366097.00|                  11440.00|                       1006.00|
-- и т.д.

-- В результате запроса наблюдаем большое количество аномальных данных с столбцах с датой и промежутком времени.
-- Необходима очистка данных для корректного анализа.


--Выполнение плана по донациям:
WITH donation_planned AS(
	SELECT
		user_id,
		donation_date,
		donation_type
	FROM donorsearch.donation_plan dp
),
donation_actual AS(
	SELECT
		user_id,
		donation_date
	FROM donorsearch.donation_anon da
),
planned_vs_actual AS(
	SELECT
		dp.user_id,
		dp.donation_date,
		dp.donation_type,
		-- Выполненные по плану донации:
		CASE 
			WHEN da.user_id IS NOT NULL THEN 1
			ELSE 0
		END AS completed
	FROM donation_planned dp
	LEFT JOIN donation_actual da ON dp.user_id = da.user_id AND dp.donation_date = da.donation_date 
)
SELECT
	donation_type,
	COUNT(*) AS donation_planned_total,
	SUM(completed) AS donation_completed,
	ROUND(SUM(completed) * 100.0 / COUNT(*),2) AS completed_rate
FROM planned_vs_actual
GROUP BY donation_type;

-- Результат:
-- donation_type|donation_planned_total|donation_completed|completed_rate|
-- -------------+----------------------+------------------+--------------+
-- Безвозмездно |                 24362|              5280|         21.67|
-- Платно       |                  3470|               459|         13.23|

-- Процент выполенения плана низкий по обоим типам донаций: 21.67% для безвозмездных доноров и 13.23% для оплачиваемых.
-- Необходимо повысить вовлеченность доноров.


-- Общие выводы и рекомендации:
--	1) Уточнить полноту данных по полю регион, провести коррекцию и очистку данных, в особенности в датах. 
--	2) Рассмотреть возможность привлечения новых доноров в регионах с низкой активностью.
--	3) Рассмотреть возможность расширения бонусной программы для привлечениях новых доноров и удержания ныне активных.
--	4) В том числе, в маркетинговых кампаниях сделать акцент на вовлечение новых и уже имеющихся,
--	   но не авторизованных через соц. сети, доноров через Яндекс и Telegram.