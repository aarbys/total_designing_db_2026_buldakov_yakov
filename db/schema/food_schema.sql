--
-- PostgreSQL database dump
--

-- Dumped from database version 17.2
-- Dumped by pg_dump version 17.0

-- Started on 2026-11-15 16:41:29

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 5 (class 2615 OID 16868)
-- Name: buldakov_food; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA buldakov_food;


ALTER SCHEMA buldakov_food OWNER TO postgres;

--
-- TOC entry 888 (class 1247 OID 16884)
-- Name: courier_status; Type: TYPE; Schema: buldakov_food; Owner: postgres
--

CREATE TYPE buldakov_food.courier_status AS ENUM (
    'свободен',
    'занят',
    'на_доставке',
    'уволен'
);


ALTER TYPE buldakov_food.courier_status OWNER TO postgres;

--
-- TOC entry 891 (class 1247 OID 16894)
-- Name: order_status; Type: TYPE; Schema: buldakov_food; Owner: postgres
--

CREATE TYPE buldakov_food.order_status AS ENUM (
    'создан',
    'готовится',
    'в_доставке',
    'доставлен',
    'отменён'
);


ALTER TYPE buldakov_food.order_status OWNER TO postgres;

--
-- TOC entry 903 (class 1247 OID 16906)
-- Name: pay_status; Type: TYPE; Schema: buldakov_food; Owner: postgres
--

CREATE TYPE buldakov_food.pay_status AS ENUM (
    'ожидает',
    'оплачен',
    'ошибка'
);


ALTER TYPE buldakov_food.pay_status OWNER TO postgres;

--
-- TOC entry 894 (class 1247 OID 16914)
-- Name: payment_status; Type: TYPE; Schema: buldakov_food; Owner: postgres
--

CREATE TYPE buldakov_food.payment_status AS ENUM (
    'успех',
    'ошибка',
    'в_обработке'
);


ALTER TYPE buldakov_food.payment_status OWNER TO postgres;

--
-- TOC entry 897 (class 1247 OID 16922)
-- Name: payment_type; Type: TYPE; Schema: buldakov_food; Owner: postgres
--

CREATE TYPE buldakov_food.payment_type AS ENUM (
    'карта',
    'наличные',
    'безнал'
);


ALTER TYPE buldakov_food.payment_type OWNER TO postgres;

--
-- TOC entry 906 (class 1247 OID 16876)
-- Name: product_status; Type: TYPE; Schema: buldakov_food; Owner: postgres
--

CREATE TYPE buldakov_food.product_status AS ENUM (
    'доступно',
    'нет_в_наличии',
    'архив'
);


ALTER TYPE buldakov_food.product_status OWNER TO postgres;

--
-- TOC entry 885 (class 1247 OID 16870)
-- Name: restaurant_status; Type: TYPE; Schema: buldakov_food; Owner: postgres
--

CREATE TYPE buldakov_food.restaurant_status AS ENUM (
    'активен',
    'неактивен'
);


ALTER TYPE buldakov_food.restaurant_status OWNER TO postgres;

--
-- TOC entry 900 (class 1247 OID 16930)
-- Name: review_entity_type; Type: TYPE; Schema: buldakov_food; Owner: postgres
--

CREATE TYPE buldakov_food.review_entity_type AS ENUM (
    'блюдо',
    'ресторан',
    'заказ'
);


ALTER TYPE buldakov_food.review_entity_type OWNER TO postgres;

--
-- TOC entry 261 (class 1255 OID 17148)
-- Name: add_product(character varying, uuid, numeric, uuid, text, numeric, buldakov_food.product_status, text); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.add_product(IN product_name character varying, IN product_category_id uuid, IN price numeric, IN restaurant_id uuid, IN photo_url text, IN rating numeric, IN status buldakov_food.product_status, IN description text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_product_id UUID;
BEGIN
	new_product_id := exts.uuid_generate_v4();
    insert into buldakov_food.product values(
		new_product_id,
		product_name,
		product_category_id,
		price,
		restaurant_id,
		photo_url,
		rating,
		status,
		description
	);
END;
$$;


ALTER PROCEDURE buldakov_food.add_product(IN product_name character varying, IN product_category_id uuid, IN price numeric, IN restaurant_id uuid, IN photo_url text, IN rating numeric, IN status buldakov_food.product_status, IN description text) OWNER TO postgres;

--
-- TOC entry 264 (class 1255 OID 17155)
-- Name: courier_salary(); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.courier_salary()
    LANGUAGE plpgsql
    AS $$
begin
	INSERT INTO buldakov_food.courier_pay
	SELECT
	    EXTRACT(YEAR FROM CURRENT_DATE)::INT,
	    EXTRACT(MONTH FROM CURRENT_DATE)::INT,
	    c.courier_id,
	    coalesce(cp.coefficient_used,c.coefficient) * COALESCE(SUM(o.commission), 0),
	    coalesce(cp.coefficient_used,c.coefficient)
	FROM buldakov_food.courier c
	LEFT JOIN buldakov_food."order" o
	    ON c.courier_id = o.courier_id
	    AND o.status = 'доставлен'
	    AND o.delivery_timestamp >= date_trunc('month', CURRENT_DATE)
	    AND o.delivery_timestamp < date_trunc('month', CURRENT_DATE) + INTERVAL '1 month'
	LEFT JOIN buldakov_food.courier_pay cp
	    ON c.courier_id = cp.courier_id
	    AND cp.year = EXTRACT(YEAR FROM CURRENT_DATE)::INT
	    AND cp.month = EXTRACT(MONTH FROM CURRENT_DATE)::INT
	GROUP BY c.courier_id, c.coefficient, cp.coefficient_used
	ON CONFLICT (year, month, courier_id)
	DO UPDATE SET
	    amount = EXCLUDED.amount,
	    coefficient_used = EXCLUDED.coefficient_used;
	update buldakov_food.courier c 
	set coefficient = CASE
		    WHEN stats.delivered_count <= 150 THEN 0.1
		    WHEN stats.delivered_count <= 250 THEN 0.2
		    WHEN stats.delivered_count <= 500 THEN 0.3
		    ELSE 0.5
		END
	FROM (
	    SELECT
	        c.courier_id,
	        COUNT(o.order_id) AS delivered_count
	    FROM buldakov_food.courier c
	    LEFT JOIN buldakov_food."order" o
	        ON o.courier_id = c.courier_id
	        AND o.status = 'доставлен'
	        AND o.delivery_timestamp >= date_trunc('month', CURRENT_DATE)
	        AND o.delivery_timestamp < date_trunc('month', CURRENT_DATE) + INTERVAL '1 month'
	    GROUP BY c.courier_id
	) stats
	WHERE c.courier_id = stats.courier_id
	  AND c.status <> 'уволен';
END;
$$;


ALTER PROCEDURE buldakov_food.courier_salary() OWNER TO postgres;

--
-- TOC entry 260 (class 1255 OID 17145)
-- Name: erase_test_data(); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.erase_test_data()
    LANGUAGE plpgsql
    AS $$
begin
	delete from buldakov_food.review;
	delete from buldakov_food.payment;
	delete from buldakov_food.order_structure;
	delete from buldakov_food.courier_pay;
	delete from buldakov_food."order";
	delete from buldakov_food.product;
	delete from buldakov_food.restaurant;
	delete from buldakov_food.client_address;
	delete from buldakov_food.address;
	delete from buldakov_food.courier;
	delete from buldakov_food.client;
	delete from buldakov_food.product_category;
end;
$$;


ALTER PROCEDURE buldakov_food.erase_test_data() OWNER TO postgres;

--
-- TOC entry 254 (class 1255 OID 17134)
-- Name: generate_addresses(integer, uuid[], uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.generate_addresses(IN p_value integer, INOUT restaurant_address_ids uuid[], INOUT client_address_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_address_id UUID;
    new_apartment VARCHAR(20);
BEGIN
    IF p_value <= 0 THEN
        RAISE EXCEPTION 'Значение должно быть больше нуля';
    END IF;
	restaurant_address_ids := ARRAY[]::UUID[];
    client_address_ids := ARRAY[]::UUID[];
	--
	--
	for i in 1..p_value*5 loop
    IF FLOOR(RANDOM() * 2)::INT = 1 THEN
        new_apartment := NULL;
    ELSE
        new_apartment := FLOOR(RANDOM() * 200 + 1)::text;
    END IF;
	-- айдишка адреса, потом для связи с ресторанами понадобится
	new_address_id := exts.uuid_generate_v4();
	insert into buldakov_food.address values 
	(	new_address_id,
		'street_' || exts.uuid_generate_v4()::text,
		FLOOR(RANDOM()*300 + 1)::text,
		new_apartment
	);
	if i <=p_value then
		restaurant_address_ids := array_append(
			restaurant_address_ids,
			new_address_id
		);
	else client_address_ids := array_append(
			client_address_ids,
			new_address_id
		);
	end if;
end loop;
end;
$$;


ALTER PROCEDURE buldakov_food.generate_addresses(IN p_value integer, INOUT restaurant_address_ids uuid[], INOUT client_address_ids uuid[]) OWNER TO postgres;

--
-- TOC entry 266 (class 1255 OID 17133)
-- Name: generate_base_data(integer, uuid[], uuid[], uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.generate_base_data(IN p_value integer, INOUT client_ids uuid[], INOUT courier_ids uuid[], INOUT product_category_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_client_id UUID;
    new_courier_id UUID;
    new_product_category_id UUID;

    new_phone VARCHAR(20);
    is_exists BOOLEAN;

    new_courier_status buldakov_food.courier_status;
    hire_date DATE;
    dismissal_date DATE;
BEGIN
RAISE NOTICE 'Передано значение: %', p_value;
	if p_value <=0 then
	RAISE EXCEPTION 'Значение должно быть больше нуля';
	end if;
    client_ids := ARRAY[]::UUID[];
    courier_ids := ARRAY[]::UUID[];
    product_category_ids := ARRAY[]::UUID[];

for i in 1..p_value loop
	--Генерация клиента
	--Генерация номера телефона
	loop
		new_phone := '+7' || LPAD(FLOOR(RANDOM() * 1000000000)::text, 10, '0');
		select exists(select 1 from buldakov_food.client where phone_number = new_phone) into is_exists;
		exit when not is_exists;
	end loop;
	--Генерация айдишки для последующей связи с адресами
	new_client_id := exts.uuid_generate_v4();
	client_ids := array_append(client_ids,new_client_id);
	insert into buldakov_food.client values 
	(	new_client_id,
		'client_' || exts.uuid_generate_v4()::text,
		md5(random()::text),
		new_phone
	);
	--Генерация курьера
	loop 
		new_phone := '7' || LPAD(FLOOR(RANDOM() * 1000000000)::text, 10, '0');
		select exists(select 1 from buldakov_food.courier where phone_number = new_phone) into is_exists;
		exit when not is_exists;
	end loop;
	--Статус курьеру выдаем, с проверкой что хотя бы 1 у нас не уволенный
	-- Хотя бы 1 курьер будет работать у нас
	if i = 1 then
		new_courier_status := 'свободен';
		hire_date := CURRENT_DATE-180;
		dismissal_date := NULL;
	else
		new_courier_status :=
		    (enum_range(NULL::buldakov_food.courier_status))
		    [floor(random() * 4 + 1)::INT];
		hire_date := CURRENT_DATE - floor(random()*180)::int;
		--Дата увольнения если он уволенный
		if new_courier_status = 'уволен' then
			dismissal_date := hire_date + floor(random() * (CURRENT_DATE- hire_date +1))::int;
		else dismissal_date := null;
		end if;
	end if;
	
	new_courier_id := exts.uuid_generate_v4();
	courier_ids = array_append(courier_ids, new_courier_id);
	insert into buldakov_food.courier(
		courier_id,
		phone_number,
		status,
		hire_date,
		dismissal_date,
		coefficient,
		last_name,
		first_name,
		middle_name
		) values 
	(	new_courier_id,
		new_phone,
		new_courier_status,
		hire_date,
		dismissal_date,
		0.1,
		'Фамилия_' || left(exts.uuid_generate_v4()::text, 5),
		'Имя' || left(exts.uuid_generate_v4()::text, 5),
		'Отчество' || left(exts.uuid_generate_v4()::text, 5)
	);
	--категории продуктов
	new_product_category_id := exts.uuid_generate_v4();
	product_category_ids :=
            array_append(product_category_ids, new_product_category_id);
	insert into buldakov_food.product_category values (
		new_product_category_id,
		'product_cat_' || exts.uuid_generate_v4()::text
	);
end loop;
end;
$$;


ALTER PROCEDURE buldakov_food.generate_base_data(IN p_value integer, INOUT client_ids uuid[], INOUT courier_ids uuid[], INOUT product_category_ids uuid[]) OWNER TO postgres;

--
-- TOC entry 257 (class 1255 OID 17136)
-- Name: generate_client_addresses(integer, uuid[], uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.generate_client_addresses(IN p_value integer, IN client_ids uuid[], IN client_address_ids uuid[])
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF p_value <= 0 THEN
        RAISE EXCEPTION 'Количество клиентов должно быть больше нуля';
    END IF;
    FOR i IN 1..p_value LOOP
        FOR j IN 1..4 LOOP
            INSERT INTO buldakov_food.client_address VALUES
            (
                client_ids[i],
                client_address_ids[(i-1)*4+j]
            );
        END LOOP;
    END LOOP;
    RAISE NOTICE 'Было создано: % связей клиента и адреса', p_value * 4;
END;
$$;


ALTER PROCEDURE buldakov_food.generate_client_addresses(IN p_value integer, IN client_ids uuid[], IN client_address_ids uuid[]) OWNER TO postgres;

--
-- TOC entry 267 (class 1255 OID 17142)
-- Name: generate_courier_pay(uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.generate_courier_pay(IN courier_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    current_courier_id UUID;

    current_coefficient NUMERIC;
    new_coefficient NUMERIC;

    current_dismissal_date DATE;
	current_hire_date DATE;
    month_start DATE;
    month_end DATE;

    delivered_orders_count INT;
    total_commission NUMERIC;
    payment_amount NUMERIC;

BEGIN

    -- Перебираем всех созданных курьеров
    FOREACH current_courier_id IN ARRAY courier_ids LOOP

        -- Получаем коэффициент и дату увольнения
        SELECT coefficient, hire_date, dismissal_date
        FROM buldakov_food.courier
        WHERE courier_id = current_courier_id
        INTO current_coefficient, current_hire_date, current_dismissal_date;

        -- Последние 6 месяцев
        FOR i IN 0..5 LOOP

            month_start :=
                (
                    DATE_TRUNC('month', CURRENT_DATE)
                    - (6 - i) * INTERVAL '1 month'
                )::DATE;

            month_end :=
                (month_start + INTERVAL '1 month')::DATE;
			if current_hire_date >= month_end then
				continue;
			end if;
			if current_dismissal_date is not null and current_dismissal_date < month_start
				then
					continue;
			end if;
            -- Количество доставленных заказов и сумма комиссий
            SELECT
                COUNT(*),
                COALESCE(SUM(commission), 0)
            FROM buldakov_food."order"
            WHERE courier_id = current_courier_id
                AND status = 'доставлен'
                AND delivery_timestamp >= month_start
                AND delivery_timestamp < month_end
            INTO delivered_orders_count, total_commission;

            -- Рассчитываем выплату
            payment_amount :=
                ROUND(total_commission * current_coefficient, 2);

            -- Сохраняем выплату
            INSERT INTO buldakov_food.courier_pay VALUES (
                EXTRACT(YEAR FROM month_start)::INT,
                EXTRACT(MONTH FROM month_start)::INT,
                current_courier_id,
                payment_amount,
                current_coefficient
            );

            -- Рассчитываем коэффициент на следующий месяц
            IF delivered_orders_count <= 150 THEN
                new_coefficient := 0.1;

            ELSIF delivered_orders_count <= 250 THEN
                new_coefficient := 0.2;

            ELSIF delivered_orders_count <= 500 THEN
                new_coefficient := 0.3;

            ELSE
                new_coefficient := 0.5;

            END IF;

            -- Обновляем коэффициент, если месяц завершён
            -- и курьер не был уволен в течение этого месяца
            IF month_end <= DATE_TRUNC('month', CURRENT_DATE)::DATE
                AND (
                    current_dismissal_date IS NULL
                    OR current_dismissal_date >= month_end
                )
            THEN

                current_coefficient := new_coefficient;

                UPDATE buldakov_food.courier
                SET coefficient = new_coefficient
                WHERE courier_id = current_courier_id;

            END IF;

        END LOOP;

    END LOOP;

END;
$$;


ALTER PROCEDURE buldakov_food.generate_courier_pay(IN courier_ids uuid[]) OWNER TO postgres;

--
-- TOC entry 256 (class 1255 OID 17143)
-- Name: generate_orders(integer, uuid[], uuid[], uuid[], uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.generate_orders(IN p_value integer, IN client_ids uuid[], IN courier_ids uuid[], IN restaurant_ids uuid[], INOUT order_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_order_id UUID;
    new_order_timestamp TIMESTAMP;
    new_order_client_id UUID;
    new_order_address_id UUID;
    new_order_restaurant_id UUID;
    new_order_courier_id UUID;

    order_product_count INT;
    order_product_ids UUID[];
    product_quantities NUMERIC[];

    new_order_amount NUMERIC;
    new_commission NUMERIC;
    new_total_amount NUMERIC;

    new_product_id UUID;
    new_product_price NUMERIC;
    new_quantity NUMERIC;

    first_product_id UUID;
    first_product_price NUMERIC;
    first_product_quantity NUMERIC;

    new_order_status buldakov_food.order_status;
    new_pay_status buldakov_food.pay_status;
    new_delivery_timestamp TIMESTAMP;

    status_roll INT;
BEGIN
	order_ids := ARRAY[]::UUID[];
    FOR i IN 1..p_value*5 LOOP

        -- Время заказа
        new_order_timestamp :=
            CURRENT_TIMESTAMP - RANDOM() * INTERVAL '180 days';

        -- ID заказа
        new_order_id := exts.uuid_generate_v4();

        -- ID клиента
        new_order_client_id :=
            client_ids[FLOOR(RANDOM()*p_value)::INT+1];

        -- ID адреса
        SELECT address_id
        FROM buldakov_food.client_address
        WHERE client_id = new_order_client_id
        ORDER BY RANDOM()
        LIMIT 1
        INTO new_order_address_id;

        -- ID ресторана
        new_order_restaurant_id :=
            restaurant_ids[FLOOR(RANDOM()*p_value)::INT+1];

        -- Подбор курьера
        SELECT courier_id
        FROM buldakov_food.courier
        WHERE (
            hire_date <= new_order_timestamp::DATE
            AND (
                dismissal_date IS NULL
                OR dismissal_date >= new_order_timestamp::DATE
            )
            AND courier_id = ANY(courier_ids)
        )
        ORDER BY RANDOM()
        LIMIT 1
        INTO new_order_courier_id;

        -- Подбираем товары для заказа
        order_product_count := FLOOR(RANDOM()*5)::INT + 1;

        SELECT ARRAY(
            SELECT product_id
            FROM buldakov_food.product
            WHERE restaurant_id = new_order_restaurant_id
				AND status = 'доступно'
            ORDER BY RANDOM()
            LIMIT order_product_count
        )
        INTO order_product_ids;

        new_order_amount := 0;
        first_product_id := NULL;
        product_quantities := ARRAY[]::NUMERIC[];

        FOREACH new_product_id IN ARRAY order_product_ids LOOP

            SELECT price
            FROM buldakov_food.product
            WHERE product_id = new_product_id
            INTO new_product_price;

            new_quantity := FLOOR(RANDOM() * 3 + 1);

            IF first_product_id IS NULL THEN
                first_product_id := new_product_id;
                first_product_price := new_product_price;
                first_product_quantity := new_quantity;
            END IF;

            product_quantities :=
                ARRAY_APPEND(product_quantities, new_quantity);

            new_order_amount :=
                new_order_amount + new_product_price * new_quantity;

        END LOOP;

        -- Сумма заказа до 1000 рублей
        WHILE new_order_amount < 1000 LOOP

            first_product_quantity := first_product_quantity + 1;

            new_order_amount :=
                new_order_amount + first_product_price;

        END LOOP;

        product_quantities[1] := first_product_quantity;

        -- Комиссия и итоговая сумма
        new_commission := new_order_amount * 0.1;
        new_total_amount := new_order_amount + new_commission;

        -- Статус заказа
        status_roll := FLOOR(RANDOM()*10)::INT + 1;

        IF status_roll <= 6 THEN
            new_order_status := 'доставлен';
            new_pay_status := 'оплачен';

            new_delivery_timestamp := least(
                new_order_timestamp + RANDOM() * INTERVAL '24 hours',
					CURRENT_TIMESTAMP
				);
        ELSIF status_roll = 7 THEN
            new_order_status := 'отменён';
            new_pay_status := 'ошибка';
            new_delivery_timestamp := NULL;

        ELSIF status_roll = 8 THEN
            new_order_status := 'создан';
            new_pay_status := 'ожидает';
            new_delivery_timestamp := NULL;

        ELSIF status_roll = 9 THEN
            new_order_status := 'готовится';
            new_pay_status := 'оплачен';
            new_delivery_timestamp := NULL;

        ELSE
            new_order_status := 'в_доставке';
            new_pay_status := 'ожидает';
            new_delivery_timestamp := NULL;

        END IF;

        -- Создаём заказ
        INSERT INTO buldakov_food."order" VALUES (
            new_order_id,
            new_order_courier_id,
            new_order_client_id,
            new_order_address_id,
            new_order_restaurant_id,
            new_order_timestamp,
            new_delivery_timestamp,
            new_order_amount,
            new_commission,
            new_total_amount,
            new_order_status,
            new_pay_status,
            'Тестовый заказ'
        );
		order_ids := ARRAY_APPEND(order_ids, new_order_id);
        -- Состав заказа
		order_product_count := CARDINALITY(order_product_ids);
        FOR j IN 1..order_product_count LOOP

            INSERT INTO buldakov_food.order_structure VALUES (
                new_order_id,
                order_product_ids[j],
                product_quantities[j]
            );

        END LOOP;

    END LOOP;

END;
$$;


ALTER PROCEDURE buldakov_food.generate_orders(IN p_value integer, IN client_ids uuid[], IN courier_ids uuid[], IN restaurant_ids uuid[], INOUT order_ids uuid[]) OWNER TO postgres;

--
-- TOC entry 262 (class 1255 OID 17141)
-- Name: generate_payments(uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.generate_payments(IN p_order_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    current_order_id UUID;

    new_payment_id UUID;
    new_payment_type buldakov_food.payment_type;
    new_payment_status buldakov_food.payment_status;

    new_payment_amount NUMERIC;
    new_payment_timestamp TIMESTAMP;
    new_transaction_id VARCHAR(255);

    current_order_timestamp TIMESTAMP;
    current_pay_status buldakov_food.pay_status;

BEGIN
    FOREACH current_order_id IN ARRAY p_order_ids LOOP
        -- Данные заказа
        SELECT total_amount, order_timestamp, pay_status
        FROM buldakov_food."order"
        WHERE order_id = current_order_id
        INTO
            new_payment_amount,
            current_order_timestamp,
            current_pay_status;
        -- ID платежа
        new_payment_id := exts.uuid_generate_v4();
        -- Тип платежа
		new_payment_type :=
			    (enum_range(NULL::buldakov_food.payment_type))
			    [floor(random() * 3 + 1)::INT];
        -- Статус платежа
        IF current_pay_status = 'оплачен' THEN
            new_payment_status := 'успех';
        ELSIF current_pay_status = 'ошибка' THEN
            new_payment_status := 'ошибка';
        ELSE
            new_payment_status := 'в_обработке';
        END IF;
        -- Время
        new_payment_timestamp := least(
            current_order_timestamp + RANDOM() * INTERVAL '1 hour',
			CURRENT_TIMESTAMP);
        -- ID транзакции
        new_transaction_id := exts.uuid_generate_v4()::TEXT;
        INSERT INTO buldakov_food.payment VALUES (
            new_payment_id,
            current_order_id,
            new_payment_type,
            new_payment_amount,
            new_transaction_id,
            new_payment_timestamp,
            new_payment_status
        );
    END LOOP;

END;
$$;


ALTER PROCEDURE buldakov_food.generate_payments(IN p_order_ids uuid[]) OWNER TO postgres;

--
-- TOC entry 255 (class 1255 OID 17137)
-- Name: generate_products(integer, uuid[], uuid[], uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.generate_products(IN p_value integer, IN restaurant_ids uuid[], IN product_category_ids uuid[], INOUT product_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_product_id UUID;
    new_product_status buldakov_food.product_status;
BEGIN
    IF p_value <= 0 THEN
        RAISE EXCEPTION 'Количество ресторанов должно быть больше нуля';
    END IF;

    product_ids := ARRAY[]::UUID[];

    FOR i IN 1..p_value LOOP
        FOR j IN 1..5 LOOP
            new_product_id := exts.uuid_generate_v4();
			if j = 1 then
				new_product_status := 'доступно';
			else
				new_product_status :=
			    	(enum_range(NULL::buldakov_food.product_status))
			    	[floor(random() * 3 + 1)::INT];
			end if;
            INSERT INTO buldakov_food.product VALUES (
                new_product_id,
                'Product_' || exts.uuid_generate_v4()::TEXT,
                product_category_ids[
                    FLOOR(RANDOM() * CARDINALITY(product_category_ids) + 1)::INT
                ],
                FLOOR(RANDOM() * 1000 + 1),
                restaurant_ids[i],
                NULL,
                NULL,
                new_product_status,
                'Какое-то описание продукта ' || exts.uuid_generate_v4()::TEXT
            );

            product_ids := ARRAY_APPEND(product_ids, new_product_id);
        END LOOP;
    END LOOP;

    RAISE NOTICE 'Было создано: % продуктов для % ресторанов', p_value * 5, p_value;
END;
$$;


ALTER PROCEDURE buldakov_food.generate_products(IN p_value integer, IN restaurant_ids uuid[], IN product_category_ids uuid[], INOUT product_ids uuid[]) OWNER TO postgres;

--
-- TOC entry 265 (class 1255 OID 17135)
-- Name: generate_restaurants(integer, uuid[], uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.generate_restaurants(IN p_value integer, IN restaurant_address_ids uuid[], INOUT restaurant_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_restaurant_id UUID;
    new_work_start TIME;
    new_work_end TIME;
	new_restaurant_status buldakov_food.restaurant_status;
BEGIN

    IF p_value <= 0 THEN
        RAISE EXCEPTION 'Значение должно быть больше нуля';
    END IF;
    restaurant_ids := ARRAY[]::UUID[];
    -- Создаём рестораны
    FOR i IN 1..p_value LOOP
        --Время открытия
		-- max start = 10:00
        new_work_start :=
            TIME '00:00' +
            FLOOR(RANDOM() * 600)::INT * INTERVAL '1 minute';
        --время закрытия
		--max close = max start + 10hours + 2 hours = 22:00
        new_work_end :=
            new_work_start +
            FLOOR(RANDOM() * 600)::INT * INTERVAL '1 minute' +
            INTERVAL '2 hours';
        new_restaurant_id := exts.uuid_generate_v4();
		new_restaurant_status :=
		    (enum_range(NULL::buldakov_food.restaurant_status))
		    [floor(random() * 2 + 1)::INT];
        INSERT INTO buldakov_food.restaurant(
			restaurant_id,
			restaurant_name,
			address_id,
			description,
			work_start,
			work_end,
			rating,
			status,
			inn,
			ogrn,
			bank_account
			) VALUES (
            new_restaurant_id,
            'restaurant_' || exts.uuid_generate_v4()::TEXT,
            restaurant_address_ids[i],
            'Описание ресторана ' ||
                FLOOR(i * RANDOM() * 1000)::TEXT,
            new_work_start,
            new_work_end,
            NULL,
            new_restaurant_status,
			lpad((FLOOR(RANDOM() * 1000000000000)::bigint)::text,12,'0'), -- 12 значный ИНН
			lpad((FLOOR(RANDOM() * 1000000000000)::bigint)::text,15,'0'), -- 15 значный огрн
			lpad(FLOOR(RANDOM() * 1000000000000)::bigint::text,20,'0') -- 20 значный рассчетный счет
        );
        restaurant_ids := ARRAY_APPEND(
            restaurant_ids,
            new_restaurant_id
        );
    END LOOP;
    RAISE NOTICE 'Было создано: % ресторанов', p_value;
END;
$$;


ALTER PROCEDURE buldakov_food.generate_restaurants(IN p_value integer, IN restaurant_address_ids uuid[], INOUT restaurant_ids uuid[]) OWNER TO postgres;

--
-- TOC entry 253 (class 1255 OID 17146)
-- Name: generate_reviews(uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.generate_reviews(IN p_order_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    i INT;

    new_review_id UUID;
    new_client_id UUID;
    new_order_id UUID;
    new_entity_id UUID;
    new_entity_type buldakov_food.review_entity_type;

    new_review_timestamp TIMESTAMP;
    new_description TEXT;
    new_rating NUMERIC;
BEGIN

    IF p_order_ids IS NULL OR CARDINALITY(p_order_ids) = 0 THEN
        RAISE EXCEPTION 'Массив заказов пуст';
    END IF;

    -- Отзыв = 1 заказ
    for i in 1..CARDINALITY(p_order_ids) LOOP
		loop
			--Забираем то на что у нас ревьюшка
			new_entity_type :=
			    (enum_range(NULL::buldakov_food.review_entity_type))
			    [floor(random() * 3 + 1)::INT];
			-- выбираем заказ персоны
			select order_id,client_id,order_timestamp from buldakov_food."order"
			where order_id = p_order_ids[i]
			order by random()
			limit 1 into new_order_id,new_client_id,new_review_timestamp;
			--теперь смотрим что выпало и в зависимости берем нужную айдишку
	
			if new_entity_type = 'заказ' then
				new_entity_id := new_order_id;
			elsif new_entity_type = 'ресторан' then
				select restaurant_id 
				from buldakov_food."order"
				where order_id = new_order_id into new_entity_id;
			else
				select product_id 
				from buldakov_food.order_structure
				where order_id = new_order_id
				order by random()
				limit 1 into new_entity_id;
			end if; 
			 
			if not exists (
				select 1 from buldakov_food.review
				where order_id = new_order_id
				and entity_type = new_entity_type
				and entity_id = new_entity_id
				) then exit;
			end if;
		end loop;

        -- Генерируем дату отзыва после создания заказа
        new_review_timestamp :=
            new_review_timestamp
            + RANDOM() * (CURRENT_TIMESTAMP - new_review_timestamp);

        new_review_id := exts.uuid_generate_v4();

        new_rating := FLOOR(RANDOM() * 5 + 1);

        new_description := (
            ARRAY[
                'Круто',
                'Все супер',
                'Not bad',
                'can be better',
                'Tasty'
            ]
        )[FLOOR(RANDOM() * 5 + 1)::INT];

        INSERT INTO buldakov_food.review VALUES (
            new_review_id,
            new_client_id,
            new_review_timestamp,
            new_entity_id,
            new_entity_type,
            new_order_id,
            new_description,
            NULL,
            new_rating
        );

    END LOOP;

    RAISE NOTICE 'Создано отзывов: %', CARDINALITY(p_order_ids);

END;
$$;


ALTER PROCEDURE buldakov_food.generate_reviews(IN p_order_ids uuid[]) OWNER TO postgres;

--
-- TOC entry 258 (class 1255 OID 17154)
-- Name: get_statistic(); Type: FUNCTION; Schema: buldakov_food; Owner: postgres
--

CREATE FUNCTION buldakov_food.get_statistic() RETURNS TABLE(restaurant_name character varying, best_product_name character varying, total_amount numeric, avg_amount numeric, best_user character varying)
    LANGUAGE sql
    AS $$
	with delivery_orders as (
		select order_id, restaurant_id, client_id, total_amount
		from buldakov_food."order"
		where status ='доставлен'
	),
	-- Чеки для ресторанов
	restaurant_stats as (
		select 
		restaurant_id, 
		sum(total_amount) as total_amount,
		avg(total_amount) as avg_amount
		from delivery_orders
		group by restaurant_id
	),
	-- Проданные блюда
	product_stats as (
		select d.restaurant_id,
		p.product_id,
		p.product_name,
		sum(os.quantity) as total_quantity
		from delivery_orders d
		join buldakov_food.order_structure os
			on d.order_id = os.order_id
		join buldakov_food.product p
			on os.product_id = p.product_id
		group by d.restaurant_id, p.product_id,p.product_name
		),
	-- Популярное блюдо
	popular_product as (
		select distinct on (restaurant_id)
		restaurant_id,
		product_name as best_product_name
		from product_stats
		order by restaurant_id, total_quantity desc
		),
	-- Заказы клиентоа
	user_stats as (
		select d.restaurant_id,
		c.client_id,
		c.login,
		count(*) as order_count
	 	from delivery_orders d
		join buldakov_food.client c 
			on c.client_id = d.client_id
		group by d.restaurant_id,c.client_id, c.login
	),
	best_user as (
		select distinct on (restaurant_id)
		restaurant_id,
		login as best_user
		from user_stats
		order by restaurant_id, order_count desc
	)
	select r.restaurant_name,
	pp.best_product_name,
	rs.total_amount,
	rs.avg_amount,
	bu.best_user
	from buldakov_food.restaurant r
	left join restaurant_stats rs
		on r.restaurant_id = rs.restaurant_id
	left join popular_product pp
		on r.restaurant_id = pp.restaurant_id
	left join best_user bu
		on r.restaurant_id = bu.restaurant_id
$$;


ALTER FUNCTION buldakov_food.get_statistic() OWNER TO postgres;

--
-- TOC entry 259 (class 1255 OID 17128)
-- Name: insert_test_data(integer); Type: PROCEDURE; Schema: buldakov_food; Owner: postgres
--

CREATE PROCEDURE buldakov_food.insert_test_data(IN value integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    client_ids UUID[];
    courier_ids UUID[];
    product_category_ids UUID[];
    restaurant_address_ids UUID[];
    client_address_ids UUID[];
    restaurant_ids UUID[];
    product_ids UUID[];
	order_ids UUID[];
BEGIN
RAISE NOTICE 'Передано значение: %', value;
	if value <=0 then
	RAISE EXCEPTION 'Значение должно быть больше нуля';
	end if;
--Благодаря рефакторингу кода все внутренний функции по созданию вынесены
--Создаем клиентов, курьеров и категории продуктов
call buldakov_food.generate_base_data(
	value,
	client_ids,
	courier_ids,
	product_category_ids
);
--Создаем адреса
call buldakov_food.generate_addresses(
	value,
	restaurant_address_ids,
	client_address_ids
);
--Создаем рестораны
call buldakov_food.generate_restaurants(
	value,
	restaurant_address_ids,
	restaurant_ids
);
--Ну тут связь адреса и клиента
call buldakov_food.generate_client_addresses(
	value,
	client_ids,
	client_address_ids
);
-- Продукты для ресторанов
call buldakov_food.generate_products(
	value,
	restaurant_ids,
	product_category_ids,
	product_ids
);

-- Делаем заказы и платежка к ним
call buldakov_food.generate_orders(
    value,
    client_ids,
    courier_ids,
    restaurant_ids,
    order_ids
);
call buldakov_food.generate_payments(order_ids);
-- Выплаты курьерам
call buldakov_food.generate_courier_pay(
    courier_ids
);
--Ревьюшка
call buldakov_food.generate_reviews(
    order_ids
);
END;
$$;


ALTER PROCEDURE buldakov_food.insert_test_data(IN value integer) OWNER TO postgres;

--
-- TOC entry 263 (class 1255 OID 17149)
-- Name: rating_change(); Type: FUNCTION; Schema: buldakov_food; Owner: postgres
--

CREATE FUNCTION buldakov_food.rating_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	if TG_OP = 'DELETE' or (
		TG_OP = 'UPDATE'
		and (
			(old.entity_type,old.entity_id)
				is distinct from (new.entity_type,new.entity_id)
				)
			) then
		if old.entity_type = 'блюдо' then
			update buldakov_food.product
				set rating = (
						select avg(r.rating) from buldakov_food.review r
						where r.entity_type = 'блюдо'
						and r.entity_id = OLD.entity_id
						)where product_id = OLD.entity_id;

		elsif old.entity_type = 'ресторан' then
			update buldakov_food.restaurant
				set rating = (
						select avg(r.rating) from buldakov_food.review r
						where r.entity_type = 'ресторан'
						and r.entity_id = OLD.entity_id
						)where restaurant_id = OLD.entity_id;
		end if;
	end if;
	if TG_OP = 'INSERT' or TG_OP = 'UPDATE' then
		if new.entity_type = 'блюдо' then
			update buldakov_food.product
				set rating = (
						select avg(r.rating) from buldakov_food.review r
						where r.entity_type = 'блюдо'
						and r.entity_id = new.entity_id
						)where product_id = new.entity_id;

		elsif new.entity_type = 'ресторан' then
			update buldakov_food.restaurant
				set rating = (
						select avg(r.rating) from buldakov_food.review r
						where r.entity_type = 'ресторан'
						and r.entity_id = new.entity_id
						)where restaurant_id = new.entity_id;
		end if;
	end if;
return null;
END;
$$;


ALTER FUNCTION buldakov_food.rating_change() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 221 (class 1259 OID 16947)
-- Name: address; Type: TABLE; Schema: buldakov_food; Owner: postgres
--

CREATE TABLE buldakov_food.address (
    address_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    street character varying(100) NOT NULL,
    house_number character varying(32) NOT NULL,
    apartment_office character varying(20)
);


ALTER TABLE buldakov_food.address OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 16937)
-- Name: client; Type: TABLE; Schema: buldakov_food; Owner: postgres
--

CREATE TABLE buldakov_food.client (
    client_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    login character varying(100) NOT NULL,
    password character varying(32) NOT NULL,
    phone_number character(12) NOT NULL
);


ALTER TABLE buldakov_food.client OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 16953)
-- Name: client_address; Type: TABLE; Schema: buldakov_food; Owner: postgres
--

CREATE TABLE buldakov_food.client_address (
    client_id uuid NOT NULL,
    address_id uuid NOT NULL
);


ALTER TABLE buldakov_food.client_address OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 16985)
-- Name: courier; Type: TABLE; Schema: buldakov_food; Owner: postgres
--

CREATE TABLE buldakov_food.courier (
    courier_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    phone_number character(11) NOT NULL,
    status buldakov_food.courier_status NOT NULL,
    hire_date date NOT NULL,
    dismissal_date date,
    coefficient numeric(2,1) DEFAULT 0.1 NOT NULL,
    last_name character varying(50) NOT NULL,
    first_name character varying(50) NOT NULL,
    middle_name character varying(50),
    CONSTRAINT courier_check CHECK (((dismissal_date IS NULL) OR (dismissal_date >= hire_date))),
    CONSTRAINT courier_coefficient_check CHECK (((coefficient >= 0.1) AND (coefficient <= 0.5)))
);


ALTER TABLE buldakov_food.courier OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 17056)
-- Name: courier_pay; Type: TABLE; Schema: buldakov_food; Owner: postgres
--

CREATE TABLE buldakov_food.courier_pay (
    year integer NOT NULL,
    month integer NOT NULL,
    courier_id uuid NOT NULL,
    amount numeric(12,2) NOT NULL,
    coefficient_used numeric(2,1) NOT NULL,
    CONSTRAINT courier_pay_amount_check CHECK ((amount >= (0)::numeric)),
    CONSTRAINT courier_pay_coefficient_used_check CHECK (((coefficient_used >= 0.1) AND (coefficient_used <= 0.5))),
    CONSTRAINT courier_pay_month_check CHECK (((month >= 1) AND (month <= 12)))
);


ALTER TABLE buldakov_food.courier_pay OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 17004)
-- Name: order; Type: TABLE; Schema: buldakov_food; Owner: postgres
--

CREATE TABLE buldakov_food."order" (
    order_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    courier_id uuid NOT NULL,
    client_id uuid NOT NULL,
    address_id uuid NOT NULL,
    restaurant_id uuid NOT NULL,
    order_timestamp timestamp without time zone NOT NULL,
    delivery_timestamp timestamp without time zone,
    order_amount numeric(12,2) NOT NULL,
    commission numeric(12,2) NOT NULL,
    total_amount numeric(12,2) NOT NULL,
    status buldakov_food.order_status NOT NULL,
    pay_status buldakov_food.pay_status NOT NULL,
    description text,
    CONSTRAINT order_check CHECK ((delivery_timestamp >= order_timestamp)),
    CONSTRAINT order_check1 CHECK (((commission > (0)::numeric) AND ((order_amount * 0.1) = commission))),
    CONSTRAINT order_check2 CHECK (((total_amount >= (1000)::numeric) AND ((order_amount + commission) = total_amount))),
    CONSTRAINT order_order_amount_check CHECK ((order_amount >= (0)::numeric))
);


ALTER TABLE buldakov_food."order" OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 17105)
-- Name: order_structure; Type: TABLE; Schema: buldakov_food; Owner: postgres
--

CREATE TABLE buldakov_food.order_structure (
    order_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity numeric(10,2) NOT NULL,
    CONSTRAINT order_structure_quantity_check CHECK ((quantity > (0)::numeric))
);


ALTER TABLE buldakov_food.order_structure OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 17092)
-- Name: payment; Type: TABLE; Schema: buldakov_food; Owner: postgres
--

CREATE TABLE buldakov_food.payment (
    payment_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    order_id uuid NOT NULL,
    payment_type buldakov_food.payment_type NOT NULL,
    amount numeric(12,2) NOT NULL,
    transaction_id character varying(255) NOT NULL,
    transaction_timestamp timestamp without time zone NOT NULL,
    status buldakov_food.payment_status NOT NULL
);


ALTER TABLE buldakov_food.payment OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 17036)
-- Name: product; Type: TABLE; Schema: buldakov_food; Owner: postgres
--

CREATE TABLE buldakov_food.product (
    product_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    product_name character varying(100) NOT NULL,
    product_category_id uuid NOT NULL,
    price numeric(12,2) NOT NULL,
    restaurant_id uuid NOT NULL,
    photo_url text,
    rating numeric(2,1),
    status buldakov_food.product_status NOT NULL,
    description text NOT NULL,
    CONSTRAINT product_price_check CHECK ((price >= (0)::numeric)),
    CONSTRAINT product_rating_check CHECK (((rating >= (0)::numeric) AND (rating <= (5)::numeric)))
);


ALTER TABLE buldakov_food.product OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 16998)
-- Name: product_category; Type: TABLE; Schema: buldakov_food; Owner: postgres
--

CREATE TABLE buldakov_food.product_category (
    product_category_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    product_category_name character varying(100) NOT NULL
);


ALTER TABLE buldakov_food.product_category OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 16968)
-- Name: restaurant; Type: TABLE; Schema: buldakov_food; Owner: postgres
--

CREATE TABLE buldakov_food.restaurant (
    restaurant_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    restaurant_name character varying(100) NOT NULL,
    address_id uuid NOT NULL,
    description text NOT NULL,
    work_start time without time zone NOT NULL,
    work_end time without time zone NOT NULL,
    rating numeric(2,1),
    status buldakov_food.restaurant_status NOT NULL,
    inn character varying(12) NOT NULL,
    ogrn character varying(15) NOT NULL,
    bank_account character varying(20) NOT NULL,
    CONSTRAINT restaurant_check CHECK ((work_end > work_start)),
    CONSTRAINT restaurant_rating_check CHECK (((rating >= (0)::numeric) AND (rating <= (5)::numeric)))
);


ALTER TABLE buldakov_food.restaurant OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 17071)
-- Name: review; Type: TABLE; Schema: buldakov_food; Owner: postgres
--

CREATE TABLE buldakov_food.review (
    review_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    client_id uuid NOT NULL,
    review_timestamp timestamp without time zone NOT NULL,
    entity_id uuid NOT NULL,
    entity_type buldakov_food.review_entity_type NOT NULL,
    order_id uuid NOT NULL,
    description text NOT NULL,
    photo_url text,
    rating numeric(2,1) NOT NULL,
    CONSTRAINT review_rating_check CHECK (((rating >= (1)::numeric) AND (rating <= (5)::numeric)))
);


ALTER TABLE buldakov_food.review OWNER TO postgres;

--
-- TOC entry 4960 (class 0 OID 16947)
-- Dependencies: 221
-- Data for Name: address; Type: TABLE DATA; Schema: buldakov_food; Owner: postgres
--

COPY buldakov_food.address (address_id, street, house_number, apartment_office) FROM stdin;
3d82c26b-a58f-4588-a6a4-385826ed3b16	street_21443876-cd7a-4aa3-abef-f52e5f7c91df	167	\N
10649047-ae37-4a0c-ae3d-a95c7b04e9b0	street_35db8908-054f-42d6-a75f-d20184872f2e	113	\N
0db63742-13b3-4bde-905d-1f311528f7f5	street_180aae74-3808-4fd2-862b-1f8e9f99c5dd	98	34
aaf379a9-c215-4093-9405-6b999b409e07	street_77a8d5b7-5a6e-40c6-b995-da985f3447b9	225	\N
db0ed65a-3b86-4384-8c50-33e6e53112c9	street_e8372ffb-3d71-4184-9195-64acf685ce1e	175	167
7fc87ed5-2426-4c4d-965c-659a8872d018	street_26c34a19-a651-4d07-9883-d8ef1a84c7f2	74	\N
7ae3bb8b-d550-4e4d-9db2-09a476eab585	street_33b31907-bacd-48c8-a61c-b2860db8a3d6	83	137
55f5f8eb-400a-439b-b5ee-f1b1b36d3a52	street_7e5e3d44-354d-4798-8dd3-f5399a6e2047	221	87
c51bd7bc-8677-473a-a59f-5b20b80fd465	street_1a0f2772-68d6-4597-bd14-f2d338699cbb	226	89
d8e96489-5207-4421-ad40-1a7371599849	street_876eeed2-653c-4367-b8f7-e324e5792eb1	252	75
bf1fd4df-435c-4f06-8f9d-707355bfcdc0	street_f3615f48-47e8-4c24-ad28-2f58a307b860	157	\N
1cf1c2a6-4216-4d81-ac03-c155c6cf3a79	street_76581e31-a611-4e97-aabe-154b210b4f9e	73	\N
281e26dd-0c08-4279-84fb-3c76de0addb6	street_980bc4c1-9f4f-4916-9392-ecba85b02b2b	260	136
031fb82a-5a51-420c-aaf0-bff95ac05b04	street_1057ef35-44f6-4ad0-9059-7ea2186e2b2e	66	14
f1fd491c-971a-4a37-be49-fc4457eb0f89	street_506a0406-7558-4a11-8154-26989ac64a46	265	\N
98a42fa1-3ef6-4af6-8a25-0c82a7238cf2	street_b3aa750d-bc48-42cb-8791-f687df6d896e	200	1
025d84c2-51f4-45e5-a845-677cbbee1333	street_952b3b44-e40e-432e-b332-2a93827e7801	157	\N
d5e8a59b-3173-42cf-a0f7-05fff6abb6a0	street_6064372a-2e35-4716-a4c8-114d43319b88	148	194
e6e60060-b95a-423a-8d21-7f9e9bc8b225	street_9ba787d2-f37b-4da1-af60-0500e43633b0	73	\N
39a05b71-d640-4ac2-9585-d60e7ca4b86c	street_43f0942e-21e1-45d4-871a-5992e239d8b6	123	\N
bd36d7b2-394a-4f3d-ac92-952a9efb2884	street_8c860130-1aa0-425a-b37e-26da98b69fcb	50	\N
523289f1-a9da-42b7-895a-ed030dc7bf4d	street_1cde90e5-92a0-4606-b679-4faf54ca805e	276	\N
afc449d5-cf58-442b-9c10-87aa923501b1	street_ab7ea993-85a2-467d-902b-76ceb34ffefa	5	185
91590add-cbb9-49be-a560-37e7ecd74347	street_db6413b4-f998-4fb9-bed5-c47057f41d2c	85	36
92d8a596-0a5a-47f3-8a76-6c9a4c1bf3b8	street_14a4c82a-4374-4953-ba4c-d7dcd00baf88	197	\N
d01240df-3c8e-4200-9ca5-279aebbadc92	street_9ec52ebc-03c8-4075-bf2f-4f7a48799f52	200	71
ccd153a1-027b-44e8-848a-26a8472aa490	street_c8c0f1f6-77c5-4cbf-9d96-c49dd6b57717	190	\N
6cfe98fb-33ba-4ced-b58a-fd3459cf4fe7	street_a6e8d51e-6da3-4e2c-9e31-d40a7a0b4b93	222	\N
004901c4-bdec-40dc-8462-8f49520c09d7	street_e8d2c0b4-67f1-40ff-ad61-dbded92bd87b	237	102
b8930533-46b3-49f0-9141-cdf044cf7705	street_d6ffd459-96bb-49af-aee4-f62a36c438c7	237	115
8e38c561-a2dc-4373-a7a8-66863390333e	street_db04718c-e48a-44a3-b75a-af5581b179de	138	92
5ef759cf-7700-4c82-ad1b-a895c97e1224	street_c76de3fc-f3bc-4ec9-b9b5-acc6aa0e6bdb	177	\N
773cb06c-6972-49ea-be14-90a634687a6e	street_3e0b706d-6ef5-4fdb-94fb-6ab3dc49878e	264	25
b1165400-7dd3-408f-9973-80c4ff7e4730	street_d0b97184-2ce6-4ab4-be2c-0f9d20d05f95	165	\N
7a3eeae5-9aee-473a-aed4-81c25ae84db6	street_99c00207-c118-433d-b7d9-d8bc45d8928d	11	\N
9d4ca644-ff9a-41ee-bfb4-539d0d4b5e02	street_fdaa8518-655a-426c-bd0a-44598e8b7d0a	169	\N
545c7de9-1183-4ac3-8106-c0cc2b19cd11	street_49466081-cf1c-4be9-b8f3-bb9c00158b55	225	\N
0352f69d-647c-4e8b-be34-af5d26853429	street_100d850f-b1a6-4bea-a266-9fd98009cef1	1	\N
1c0cc06e-a04d-4f5c-85a2-6f29beeaad71	street_0c48991c-e6a9-428f-a937-c928972d78b3	80	\N
7cbb3e90-a945-4aaa-91da-12267500493e	street_5ba9dc5d-3148-4369-9771-4180e3cb69ae	277	66
6d9c022d-2533-40c7-9490-22003cceaf3c	street_6ed644b7-184e-4b33-95a4-0a257041aa76	274	\N
99dbe280-7a9b-409d-b4f7-6db3fc5c469d	street_b8e5aa19-6ca9-432a-976a-077d150ed788	281	18
2e05a4b5-8cd5-4889-874e-0fe4f24055de	street_9ba977ae-5df7-4f65-be64-304716e527e7	234	\N
bc0adb06-9f2a-47d9-ab8a-63ddf4e4cba5	street_6c3e1044-38c9-4b10-9207-c000df4b5625	149	64
5293f614-0ca2-4192-9d50-048d866b8aa8	street_8f34ac77-4540-4f2e-ad3c-625cb99fff9e	251	127
ec4a2ac0-92be-403a-a094-f7aa0f3066e6	street_a1081c31-876b-47ca-9757-258ee71a979a	9	\N
956da3e9-cd2c-4247-9fb9-d916530bb7cd	street_1192478a-7dad-4036-a8e9-b80b8a72636c	258	\N
ba9d249b-e663-4aff-a55c-bd5298340472	street_95066649-a3e8-4118-9f85-f9e1c4c6032c	148	\N
3996b3c6-cb73-4551-ae2b-0f8b311374b5	street_67108546-40f1-43f3-adbe-d7921ee778c5	52	\N
abd1ca45-c34c-448c-a851-8678e9328fdb	street_a3fa9f1d-a376-4bc7-a41e-eba7dce5b2cb	275	154
\.


--
-- TOC entry 4959 (class 0 OID 16937)
-- Dependencies: 220
-- Data for Name: client; Type: TABLE DATA; Schema: buldakov_food; Owner: postgres
--

COPY buldakov_food.client (client_id, login, password, phone_number) FROM stdin;
27b8654e-ac63-4a9b-9564-0691dc934a72	client_39bd41e4-7d22-4318-8756-6a7845a3d7dc	116a996e8b7c950d625d528644cbce4c	+70597611155
859c4ca6-6f29-4ab1-a3a3-312c64a2042d	client_fae1e137-6466-4304-9c5a-7376781919c1	5055338bde5249b52f33506e92ed9400	+70033139390
fad83466-2a6d-4c90-b57b-c216e5856038	client_72fa6f0d-e9a1-480e-8a5c-d5908d31e201	dc3bb8e637730b626fbd6746d3b14312	+70833574442
03838d52-94eb-42f6-aec6-1f59201a3a05	client_d5a685f5-5c6f-4fba-9949-c6cf83cea214	2eba2616aa3ea4a951e9bc24d686321d	+70366597558
e653208d-c757-40ee-9297-7a4824805a1c	client_b3e1704c-ae22-4bf3-b8b5-b369e26e7c04	49167804e2b936a7af848f4eef46a2ce	+70918672747
b300a5a7-9cb1-4a7e-a4ff-b40b709809ab	client_92a491d5-6bdb-4624-84fc-21185422ce5f	159a5ec338179b658f35ea48d56ed2d2	+70019399973
16a33dfb-b96c-4117-8fb9-fc064baf86d5	client_7b55c99f-f00f-469c-860a-2b97cf4ba9ba	27cfcde26a82f9ae2ca790fddfe7a9f2	+70022343337
fff1ab96-27a5-4e02-95a3-5a4ea623f599	client_60f3ec49-e366-4aae-b506-12cc3a9b2601	abd24f89e3f7ef927aec7645d5f4e5f0	+70175651652
b864179e-f78f-46f9-8a13-06fbad92ef2a	client_4dac9997-16c4-4cb7-82ad-4f4354c80ac2	c440247fe6da1692e04c983972abd351	+70107770755
e841d07d-42a9-40b9-bec8-a22c15209e49	client_2ef4823f-b434-4403-a40e-3a4c2a9bcdcd	4e2eb0c41c1e9c58df52eccfd208d817	+70490770956
\.


--
-- TOC entry 4961 (class 0 OID 16953)
-- Dependencies: 222
-- Data for Name: client_address; Type: TABLE DATA; Schema: buldakov_food; Owner: postgres
--

COPY buldakov_food.client_address (client_id, address_id) FROM stdin;
27b8654e-ac63-4a9b-9564-0691dc934a72	bf1fd4df-435c-4f06-8f9d-707355bfcdc0
27b8654e-ac63-4a9b-9564-0691dc934a72	1cf1c2a6-4216-4d81-ac03-c155c6cf3a79
27b8654e-ac63-4a9b-9564-0691dc934a72	281e26dd-0c08-4279-84fb-3c76de0addb6
27b8654e-ac63-4a9b-9564-0691dc934a72	031fb82a-5a51-420c-aaf0-bff95ac05b04
859c4ca6-6f29-4ab1-a3a3-312c64a2042d	f1fd491c-971a-4a37-be49-fc4457eb0f89
859c4ca6-6f29-4ab1-a3a3-312c64a2042d	98a42fa1-3ef6-4af6-8a25-0c82a7238cf2
859c4ca6-6f29-4ab1-a3a3-312c64a2042d	025d84c2-51f4-45e5-a845-677cbbee1333
859c4ca6-6f29-4ab1-a3a3-312c64a2042d	d5e8a59b-3173-42cf-a0f7-05fff6abb6a0
fad83466-2a6d-4c90-b57b-c216e5856038	e6e60060-b95a-423a-8d21-7f9e9bc8b225
fad83466-2a6d-4c90-b57b-c216e5856038	39a05b71-d640-4ac2-9585-d60e7ca4b86c
fad83466-2a6d-4c90-b57b-c216e5856038	bd36d7b2-394a-4f3d-ac92-952a9efb2884
fad83466-2a6d-4c90-b57b-c216e5856038	523289f1-a9da-42b7-895a-ed030dc7bf4d
03838d52-94eb-42f6-aec6-1f59201a3a05	afc449d5-cf58-442b-9c10-87aa923501b1
03838d52-94eb-42f6-aec6-1f59201a3a05	91590add-cbb9-49be-a560-37e7ecd74347
03838d52-94eb-42f6-aec6-1f59201a3a05	92d8a596-0a5a-47f3-8a76-6c9a4c1bf3b8
03838d52-94eb-42f6-aec6-1f59201a3a05	d01240df-3c8e-4200-9ca5-279aebbadc92
e653208d-c757-40ee-9297-7a4824805a1c	ccd153a1-027b-44e8-848a-26a8472aa490
e653208d-c757-40ee-9297-7a4824805a1c	6cfe98fb-33ba-4ced-b58a-fd3459cf4fe7
e653208d-c757-40ee-9297-7a4824805a1c	004901c4-bdec-40dc-8462-8f49520c09d7
e653208d-c757-40ee-9297-7a4824805a1c	b8930533-46b3-49f0-9141-cdf044cf7705
b300a5a7-9cb1-4a7e-a4ff-b40b709809ab	8e38c561-a2dc-4373-a7a8-66863390333e
b300a5a7-9cb1-4a7e-a4ff-b40b709809ab	5ef759cf-7700-4c82-ad1b-a895c97e1224
b300a5a7-9cb1-4a7e-a4ff-b40b709809ab	773cb06c-6972-49ea-be14-90a634687a6e
b300a5a7-9cb1-4a7e-a4ff-b40b709809ab	b1165400-7dd3-408f-9973-80c4ff7e4730
16a33dfb-b96c-4117-8fb9-fc064baf86d5	7a3eeae5-9aee-473a-aed4-81c25ae84db6
16a33dfb-b96c-4117-8fb9-fc064baf86d5	9d4ca644-ff9a-41ee-bfb4-539d0d4b5e02
16a33dfb-b96c-4117-8fb9-fc064baf86d5	545c7de9-1183-4ac3-8106-c0cc2b19cd11
16a33dfb-b96c-4117-8fb9-fc064baf86d5	0352f69d-647c-4e8b-be34-af5d26853429
fff1ab96-27a5-4e02-95a3-5a4ea623f599	1c0cc06e-a04d-4f5c-85a2-6f29beeaad71
fff1ab96-27a5-4e02-95a3-5a4ea623f599	7cbb3e90-a945-4aaa-91da-12267500493e
fff1ab96-27a5-4e02-95a3-5a4ea623f599	6d9c022d-2533-40c7-9490-22003cceaf3c
fff1ab96-27a5-4e02-95a3-5a4ea623f599	99dbe280-7a9b-409d-b4f7-6db3fc5c469d
b864179e-f78f-46f9-8a13-06fbad92ef2a	2e05a4b5-8cd5-4889-874e-0fe4f24055de
b864179e-f78f-46f9-8a13-06fbad92ef2a	bc0adb06-9f2a-47d9-ab8a-63ddf4e4cba5
b864179e-f78f-46f9-8a13-06fbad92ef2a	5293f614-0ca2-4192-9d50-048d866b8aa8
b864179e-f78f-46f9-8a13-06fbad92ef2a	ec4a2ac0-92be-403a-a094-f7aa0f3066e6
e841d07d-42a9-40b9-bec8-a22c15209e49	956da3e9-cd2c-4247-9fb9-d916530bb7cd
e841d07d-42a9-40b9-bec8-a22c15209e49	ba9d249b-e663-4aff-a55c-bd5298340472
e841d07d-42a9-40b9-bec8-a22c15209e49	3996b3c6-cb73-4551-ae2b-0f8b311374b5
e841d07d-42a9-40b9-bec8-a22c15209e49	abd1ca45-c34c-448c-a851-8678e9328fdb
\.


--
-- TOC entry 4963 (class 0 OID 16985)
-- Dependencies: 224
-- Data for Name: courier; Type: TABLE DATA; Schema: buldakov_food; Owner: postgres
--

COPY buldakov_food.courier (courier_id, phone_number, status, hire_date, dismissal_date, coefficient, last_name, first_name, middle_name) FROM stdin;
52d023b3-6f69-4978-912c-c4121988dc40	70670114083	свободен	2026-05-19	\N	0.1	Фамилия_4fbec	Имя1d255	Отчество9489a
345d851e-b7ff-41d2-b912-7936ae4a82ea	70292109019	занят	2026-07-18	\N	0.1	Фамилия_cdfc2	Имя3c1b9	Отчество4b0c2
8d86e87d-410f-49db-8dde-45fc90075a6f	70221907324	занят	2026-10-30	\N	0.1	Фамилия_07181	Имя08dd4	Отчество108eb
988ff19a-b3c4-4c2e-987d-c50c6260c2b0	70294664212	свободен	2026-05-22	\N	0.1	Фамилия_bff68	Имя4ce8b	Отчествоa161f
bef4bae5-1877-4ec3-a574-fa62dba982e0	70888128265	на_доставке	2026-07-21	\N	0.1	Фамилия_dac78	Имя72842	Отчествоc954c
165a4355-04e3-4f05-87b4-9ffdcf297a0b	70540365425	уволен	2026-07-01	2026-08-19	0.1	Фамилия_73df4	Имяf325b	Отчествоd0f18
44079337-1686-46c0-94bf-eda3a53093e0	70888438990	свободен	2026-08-13	\N	0.1	Фамилия_bda4a	Имяf53a4	Отчествоdd95c
30da6886-fbde-4031-9c30-472af6ed66ba	70017881762	свободен	2026-09-05	\N	0.1	Фамилия_32bee	Имяcb7be	Отчествоd53ac
b6263dbb-9a5d-4014-9e77-1dd1306104ea	70602023480	свободен	2026-06-19	\N	0.1	Фамилия_9af60	Имя0e572	Отчествоba763
8c33736b-7830-4f07-956c-5ba1e78aa0ef	70272835292	на_доставке	2026-11-01	\N	0.1	Фамилия_48dbc	Имя87916	Отчествоe9b03
\.


--
-- TOC entry 4967 (class 0 OID 17056)
-- Dependencies: 228
-- Data for Name: courier_pay; Type: TABLE DATA; Schema: buldakov_food; Owner: postgres
--

COPY buldakov_food.courier_pay (year, month, courier_id, amount, coefficient_used) FROM stdin;
2026	5	52d023b3-6f69-4978-912c-c4121988dc40	0.00	0.1
2026	6	52d023b3-6f69-4978-912c-c4121988dc40	31.89	0.1
2026	7	52d023b3-6f69-4978-912c-c4121988dc40	0.00	0.1
2026	8	52d023b3-6f69-4978-912c-c4121988dc40	59.77	0.1
2026	9	52d023b3-6f69-4978-912c-c4121988dc40	27.03	0.1
2026	10	52d023b3-6f69-4978-912c-c4121988dc40	0.00	0.1
2026	7	345d851e-b7ff-41d2-b912-7936ae4a82ea	72.66	0.1
2026	8	345d851e-b7ff-41d2-b912-7936ae4a82ea	31.89	0.1
2026	9	345d851e-b7ff-41d2-b912-7936ae4a82ea	0.00	0.1
2026	10	345d851e-b7ff-41d2-b912-7936ae4a82ea	36.65	0.1
2026	10	8d86e87d-410f-49db-8dde-45fc90075a6f	0.00	0.1
2026	5	988ff19a-b3c4-4c2e-987d-c50c6260c2b0	46.65	0.1
2026	6	988ff19a-b3c4-4c2e-987d-c50c6260c2b0	54.75	0.1
2026	7	988ff19a-b3c4-4c2e-987d-c50c6260c2b0	0.00	0.1
2026	8	988ff19a-b3c4-4c2e-987d-c50c6260c2b0	73.33	0.1
2026	9	988ff19a-b3c4-4c2e-987d-c50c6260c2b0	0.00	0.1
2026	10	988ff19a-b3c4-4c2e-987d-c50c6260c2b0	19.36	0.1
2026	7	bef4bae5-1877-4ec3-a574-fa62dba982e0	0.00	0.1
2026	8	bef4bae5-1877-4ec3-a574-fa62dba982e0	24.04	0.1
2026	9	bef4bae5-1877-4ec3-a574-fa62dba982e0	0.00	0.1
2026	10	bef4bae5-1877-4ec3-a574-fa62dba982e0	0.00	0.1
2026	7	165a4355-04e3-4f05-87b4-9ffdcf297a0b	20.63	0.1
2026	8	165a4355-04e3-4f05-87b4-9ffdcf297a0b	0.00	0.1
2026	8	44079337-1686-46c0-94bf-eda3a53093e0	0.00	0.1
2026	9	44079337-1686-46c0-94bf-eda3a53093e0	69.15	0.1
2026	10	44079337-1686-46c0-94bf-eda3a53093e0	0.00	0.1
2026	9	30da6886-fbde-4031-9c30-472af6ed66ba	19.38	0.1
2026	10	30da6886-fbde-4031-9c30-472af6ed66ba	0.00	0.1
2026	6	b6263dbb-9a5d-4014-9e77-1dd1306104ea	0.00	0.1
2026	7	b6263dbb-9a5d-4014-9e77-1dd1306104ea	0.00	0.1
2026	8	b6263dbb-9a5d-4014-9e77-1dd1306104ea	134.27	0.1
2026	9	b6263dbb-9a5d-4014-9e77-1dd1306104ea	0.00	0.1
2026	10	b6263dbb-9a5d-4014-9e77-1dd1306104ea	0.00	0.1
\.


--
-- TOC entry 4965 (class 0 OID 17004)
-- Dependencies: 226
-- Data for Name: order; Type: TABLE DATA; Schema: buldakov_food; Owner: postgres
--

COPY buldakov_food."order" (order_id, courier_id, client_id, address_id, restaurant_id, order_timestamp, delivery_timestamp, order_amount, commission, total_amount, status, pay_status, description) FROM stdin;
2f4b9ac5-9865-4387-9cea-8cf4f6d6e6cc	44079337-1686-46c0-94bf-eda3a53093e0	27b8654e-ac63-4a9b-9564-0691dc934a72	1cf1c2a6-4216-4d81-ac03-c155c6cf3a79	083bc952-958d-403d-a9b1-5b71d09d74a9	2026-11-15 04:38:08.450129	\N	3288.00	328.80	3616.80	создан	ожидает	Тестовый заказ
27daf419-8208-42ed-825a-ecfc30ed855a	52d023b3-6f69-4978-912c-c4121988dc40	fad83466-2a6d-4c90-b57b-c216e5856038	bd36d7b2-394a-4f3d-ac92-952a9efb2884	1158ccbd-4b38-49de-a19e-e1b3adbe3f31	2026-05-31 15:04:53.133063	\N	1644.00	164.40	1808.40	в_доставке	ожидает	Тестовый заказ
01457044-2191-46ee-9df6-6170e24db5ad	165a4355-04e3-4f05-87b4-9ffdcf297a0b	03838d52-94eb-42f6-aec6-1f59201a3a05	91590add-cbb9-49be-a560-37e7ecd74347	97f5b71a-7860-4bc8-8071-63e50efe9090	2026-08-10 23:28:05.158532	\N	2782.00	278.20	3060.20	отменён	ошибка	Тестовый заказ
2c1fb20b-2f38-4c07-99be-1ed2cd161c15	988ff19a-b3c4-4c2e-987d-c50c6260c2b0	b864179e-f78f-46f9-8a13-06fbad92ef2a	5293f614-0ca2-4192-9d50-048d866b8aa8	97f5b71a-7860-4bc8-8071-63e50efe9090	2026-06-03 06:43:40.157312	2026-06-03 12:49:41.870144	1032.00	103.20	1135.20	доставлен	оплачен	Тестовый заказ
11c2a8ff-b1a7-4f71-9438-6cdfbf510353	52d023b3-6f69-4978-912c-c4121988dc40	e653208d-c757-40ee-9297-7a4824805a1c	b8930533-46b3-49f0-9141-cdf044cf7705	083bc952-958d-403d-a9b1-5b71d09d74a9	2026-06-18 13:14:11.473588	2026-06-19 07:48:36.941043	3189.00	318.90	3507.90	доставлен	оплачен	Тестовый заказ
d4b5dd82-d687-42ed-9eb6-edd8b7bb18cb	988ff19a-b3c4-4c2e-987d-c50c6260c2b0	b864179e-f78f-46f9-8a13-06fbad92ef2a	2e05a4b5-8cd5-4889-874e-0fe4f24055de	f93b7f35-33bf-416a-8039-a2152fdd8c02	2026-11-15 07:37:45.032233	\N	2868.00	286.80	3154.80	готовится	оплачен	Тестовый заказ
611d753f-d254-4d12-af5d-b14d31bdadf8	988ff19a-b3c4-4c2e-987d-c50c6260c2b0	fff1ab96-27a5-4e02-95a3-5a4ea623f599	1c0cc06e-a04d-4f5c-85a2-6f29beeaad71	be34e6cb-9360-4773-8167-ae8d58775d78	2026-05-28 02:23:00.763765	2026-05-28 04:21:11.774767	1468.00	146.80	1614.80	доставлен	оплачен	Тестовый заказ
4ffe635e-7440-4a06-b306-d5816857f263	b6263dbb-9a5d-4014-9e77-1dd1306104ea	fff1ab96-27a5-4e02-95a3-5a4ea623f599	6d9c022d-2533-40c7-9490-22003cceaf3c	1158ccbd-4b38-49de-a19e-e1b3adbe3f31	2026-10-14 09:34:53.369894	\N	2466.00	246.60	2712.60	создан	ожидает	Тестовый заказ
42fad3ce-5a1a-4bb3-af20-b3865604f44a	b6263dbb-9a5d-4014-9e77-1dd1306104ea	fff1ab96-27a5-4e02-95a3-5a4ea623f599	6d9c022d-2533-40c7-9490-22003cceaf3c	e402b693-2121-4345-a6e9-df52223f82c1	2026-08-29 17:04:31.617577	\N	2869.00	286.90	3155.90	готовится	оплачен	Тестовый заказ
e57d44c5-b81b-4225-abb3-02e531c79e1b	b6263dbb-9a5d-4014-9e77-1dd1306104ea	27b8654e-ac63-4a9b-9564-0691dc934a72	1cf1c2a6-4216-4d81-ac03-c155c6cf3a79	f93b7f35-33bf-416a-8039-a2152fdd8c02	2026-08-20 02:31:52.40816	2026-08-20 18:08:59.53783	2083.00	208.30	2291.30	доставлен	оплачен	Тестовый заказ
062b19b6-5eb5-4d03-896e-e4c651ab5e88	44079337-1686-46c0-94bf-eda3a53093e0	b300a5a7-9cb1-4a7e-a4ff-b40b709809ab	b1165400-7dd3-408f-9973-80c4ff7e4730	58351ddb-7140-48d0-9ea3-0c068293e707	2026-11-01 11:55:44.965795	2026-11-01 13:54:24.851778	5724.00	572.40	6296.40	доставлен	оплачен	Тестовый заказ
c9409596-ffdf-43a2-b589-80bfa522421e	30da6886-fbde-4031-9c30-472af6ed66ba	e653208d-c757-40ee-9297-7a4824805a1c	b8930533-46b3-49f0-9141-cdf044cf7705	58351ddb-7140-48d0-9ea3-0c068293e707	2026-10-08 23:03:56.084006	\N	3718.00	371.80	4089.80	в_доставке	ожидает	Тестовый заказ
1c8c00ef-dc11-470a-891c-cdd3b473e90c	30da6886-fbde-4031-9c30-472af6ed66ba	03838d52-94eb-42f6-aec6-1f59201a3a05	92d8a596-0a5a-47f3-8a76-6c9a4c1bf3b8	1158ccbd-4b38-49de-a19e-e1b3adbe3f31	2026-09-27 19:21:57.089833	2026-09-28 03:53:34.44708	1938.00	193.80	2131.80	доставлен	оплачен	Тестовый заказ
364a1dde-0097-4094-af12-8f3ef37cb9ea	b6263dbb-9a5d-4014-9e77-1dd1306104ea	859c4ca6-6f29-4ab1-a3a3-312c64a2042d	d5e8a59b-3173-42cf-a0f7-05fff6abb6a0	39968751-82a2-4940-9fc0-1cda08ea02b9	2026-08-29 22:50:44.586376	2026-08-30 00:22:27.417036	4937.00	493.70	5430.70	доставлен	оплачен	Тестовый заказ
1720ed8b-6332-4312-bb27-e990d77a4a80	52d023b3-6f69-4978-912c-c4121988dc40	b864179e-f78f-46f9-8a13-06fbad92ef2a	bc0adb06-9f2a-47d9-ab8a-63ddf4e4cba5	f93b7f35-33bf-416a-8039-a2152fdd8c02	2026-09-08 16:54:31.213365	2026-09-09 08:39:44.415852	2703.00	270.30	2973.30	доставлен	оплачен	Тестовый заказ
19b504d5-572d-438c-a497-c1e2be16e08b	bef4bae5-1877-4ec3-a574-fa62dba982e0	b864179e-f78f-46f9-8a13-06fbad92ef2a	2e05a4b5-8cd5-4889-874e-0fe4f24055de	083bc952-958d-403d-a9b1-5b71d09d74a9	2026-07-27 23:29:31.7344	\N	2991.00	299.10	3290.10	отменён	ошибка	Тестовый заказ
1b1dec13-625a-47a7-8518-c6c3eb5784a3	b6263dbb-9a5d-4014-9e77-1dd1306104ea	27b8654e-ac63-4a9b-9564-0691dc934a72	1cf1c2a6-4216-4d81-ac03-c155c6cf3a79	e402b693-2121-4345-a6e9-df52223f82c1	2026-06-24 16:55:36.197555	\N	4291.00	429.10	4720.10	готовится	оплачен	Тестовый заказ
4ec19e2b-c69c-42ac-91a8-76b3ec645b22	52d023b3-6f69-4978-912c-c4121988dc40	27b8654e-ac63-4a9b-9564-0691dc934a72	bf1fd4df-435c-4f06-8f9d-707355bfcdc0	083bc952-958d-403d-a9b1-5b71d09d74a9	2026-07-31 20:13:13.143144	\N	2291.00	229.10	2520.10	создан	ожидает	Тестовый заказ
84f9e3f1-0f77-4d1e-94e1-ce2389edb529	988ff19a-b3c4-4c2e-987d-c50c6260c2b0	fff1ab96-27a5-4e02-95a3-5a4ea623f599	7cbb3e90-a945-4aaa-91da-12267500493e	f93b7f35-33bf-416a-8039-a2152fdd8c02	2026-06-29 08:57:00.584198	2026-06-29 11:54:12.136584	1443.00	144.30	1587.30	доставлен	оплачен	Тестовый заказ
42388ad7-5a73-4c7c-8d13-9f98694b2ed7	988ff19a-b3c4-4c2e-987d-c50c6260c2b0	fad83466-2a6d-4c90-b57b-c216e5856038	523289f1-a9da-42b7-895a-ed030dc7bf4d	97f5b71a-7860-4bc8-8071-63e50efe9090	2026-06-25 05:03:27.556538	\N	3126.00	312.60	3438.60	в_доставке	ожидает	Тестовый заказ
92f3fe6b-15a1-48c4-9955-50bc30f5892c	52d023b3-6f69-4978-912c-c4121988dc40	03838d52-94eb-42f6-aec6-1f59201a3a05	d01240df-3c8e-4200-9ca5-279aebbadc92	f93b7f35-33bf-416a-8039-a2152fdd8c02	2026-08-30 12:51:58.098104	2026-08-30 13:17:42.949246	2874.00	287.40	3161.40	доставлен	оплачен	Тестовый заказ
50560a13-94ed-4daa-80e7-974d296fbef6	345d851e-b7ff-41d2-b912-7936ae4a82ea	16a33dfb-b96c-4117-8fb9-fc064baf86d5	545c7de9-1183-4ac3-8106-c0cc2b19cd11	f93b7f35-33bf-416a-8039-a2152fdd8c02	2026-10-28 21:38:15.92079	2026-10-29 12:38:02.490674	3665.00	366.50	4031.50	доставлен	оплачен	Тестовый заказ
0a250efe-edef-4100-880f-feff5b12c9be	b6263dbb-9a5d-4014-9e77-1dd1306104ea	b864179e-f78f-46f9-8a13-06fbad92ef2a	2e05a4b5-8cd5-4889-874e-0fe4f24055de	f93b7f35-33bf-416a-8039-a2152fdd8c02	2026-08-16 17:42:09.023959	\N	2564.00	256.40	2820.40	готовится	оплачен	Тестовый заказ
0f3825eb-d7b9-4c1b-9bf3-1730dcc97f38	52d023b3-6f69-4978-912c-c4121988dc40	b864179e-f78f-46f9-8a13-06fbad92ef2a	5293f614-0ca2-4192-9d50-048d866b8aa8	39968751-82a2-4940-9fc0-1cda08ea02b9	2026-06-02 22:02:17.796941	\N	1951.00	195.10	2146.10	в_доставке	ожидает	Тестовый заказ
0006a201-1d4a-49e4-b9ce-d004cd4fe27c	bef4bae5-1877-4ec3-a574-fa62dba982e0	fad83466-2a6d-4c90-b57b-c216e5856038	e6e60060-b95a-423a-8d21-7f9e9bc8b225	58351ddb-7140-48d0-9ea3-0c068293e707	2026-08-02 07:51:36.907389	\N	2007.00	200.70	2207.70	в_доставке	ожидает	Тестовый заказ
5028f5c5-4bce-43a7-b06f-759c169350d0	988ff19a-b3c4-4c2e-987d-c50c6260c2b0	fad83466-2a6d-4c90-b57b-c216e5856038	523289f1-a9da-42b7-895a-ed030dc7bf4d	58351ddb-7140-48d0-9ea3-0c068293e707	2026-05-24 07:47:32.40984	2026-05-25 01:11:38.343356	3197.00	319.70	3516.70	доставлен	оплачен	Тестовый заказ
168e030a-20bc-45a6-8d47-10f013613115	b6263dbb-9a5d-4014-9e77-1dd1306104ea	fff1ab96-27a5-4e02-95a3-5a4ea623f599	1c0cc06e-a04d-4f5c-85a2-6f29beeaad71	58351ddb-7140-48d0-9ea3-0c068293e707	2026-06-29 12:11:20.36273	\N	3459.00	345.90	3804.90	создан	ожидает	Тестовый заказ
6596a699-4ea5-4ee9-98b8-9c8729f2ec47	44079337-1686-46c0-94bf-eda3a53093e0	03838d52-94eb-42f6-aec6-1f59201a3a05	d01240df-3c8e-4200-9ca5-279aebbadc92	f93b7f35-33bf-416a-8039-a2152fdd8c02	2026-08-29 14:53:26.214699	\N	1266.00	126.60	1392.60	отменён	ошибка	Тестовый заказ
30ebc613-fbf7-49cf-ae4e-cb3f3d217209	345d851e-b7ff-41d2-b912-7936ae4a82ea	859c4ca6-6f29-4ab1-a3a3-312c64a2042d	98a42fa1-3ef6-4af6-8a25-0c82a7238cf2	58351ddb-7140-48d0-9ea3-0c068293e707	2026-09-09 01:02:31.21485	\N	1338.00	133.80	1471.80	создан	ожидает	Тестовый заказ
40396bc9-ef2e-4627-9af5-26dbe8c675ad	988ff19a-b3c4-4c2e-987d-c50c6260c2b0	16a33dfb-b96c-4117-8fb9-fc064baf86d5	0352f69d-647c-4e8b-be34-af5d26853429	97f5b71a-7860-4bc8-8071-63e50efe9090	2026-10-07 03:53:40.331151	2026-10-07 08:48:22.122335	1936.00	193.60	2129.60	доставлен	оплачен	Тестовый заказ
63c8c1d1-572e-49b3-97b0-e3cdd799c889	44079337-1686-46c0-94bf-eda3a53093e0	fff1ab96-27a5-4e02-95a3-5a4ea623f599	6d9c022d-2533-40c7-9490-22003cceaf3c	083bc952-958d-403d-a9b1-5b71d09d74a9	2026-09-01 09:11:02.867311	\N	1294.00	129.40	1423.40	в_доставке	ожидает	Тестовый заказ
a9920c23-0e7c-4c3a-8daf-139fa136320c	52d023b3-6f69-4978-912c-c4121988dc40	fad83466-2a6d-4c90-b57b-c216e5856038	e6e60060-b95a-423a-8d21-7f9e9bc8b225	515a0759-8881-4f0b-bd5a-3d28605c9cd7	2026-11-09 22:14:55.933931	2026-11-10 10:19:03.310368	2571.00	257.10	2828.10	доставлен	оплачен	Тестовый заказ
e492437d-6615-4b6f-afa2-a01235cbe128	988ff19a-b3c4-4c2e-987d-c50c6260c2b0	fad83466-2a6d-4c90-b57b-c216e5856038	523289f1-a9da-42b7-895a-ed030dc7bf4d	97f5b71a-7860-4bc8-8071-63e50efe9090	2026-07-06 13:18:02.155097	\N	2084.00	208.40	2292.40	отменён	ошибка	Тестовый заказ
51474f4f-cd53-466b-9dda-8c50eb19c884	bef4bae5-1877-4ec3-a574-fa62dba982e0	859c4ca6-6f29-4ab1-a3a3-312c64a2042d	98a42fa1-3ef6-4af6-8a25-0c82a7238cf2	97f5b71a-7860-4bc8-8071-63e50efe9090	2026-08-03 07:19:12.707807	2026-08-03 12:09:46.903097	2404.00	240.40	2644.40	доставлен	оплачен	Тестовый заказ
1f6795df-4f04-46ba-8fc4-f1ff598fc204	b6263dbb-9a5d-4014-9e77-1dd1306104ea	27b8654e-ac63-4a9b-9564-0691dc934a72	bf1fd4df-435c-4f06-8f9d-707355bfcdc0	39968751-82a2-4940-9fc0-1cda08ea02b9	2026-08-13 12:01:59.945096	\N	4202.00	420.20	4622.20	готовится	оплачен	Тестовый заказ
511ea4d1-a08f-4052-bf56-d920733ef6c3	44079337-1686-46c0-94bf-eda3a53093e0	b300a5a7-9cb1-4a7e-a4ff-b40b709809ab	773cb06c-6972-49ea-be14-90a634687a6e	e402b693-2121-4345-a6e9-df52223f82c1	2026-10-09 22:09:57.652386	\N	5291.00	529.10	5820.10	отменён	ошибка	Тестовый заказ
b7e4483d-187f-417e-8621-fa09866f05a8	b6263dbb-9a5d-4014-9e77-1dd1306104ea	27b8654e-ac63-4a9b-9564-0691dc934a72	bf1fd4df-435c-4f06-8f9d-707355bfcdc0	e162c52c-87b9-4885-a7dd-2b400d15063a	2026-08-22 17:46:07.184458	2026-08-22 20:12:59.427236	3302.00	330.20	3632.20	доставлен	оплачен	Тестовый заказ
6e3a1ff8-5719-487d-8ac6-934c5b6d4323	52d023b3-6f69-4978-912c-c4121988dc40	b864179e-f78f-46f9-8a13-06fbad92ef2a	5293f614-0ca2-4192-9d50-048d866b8aa8	e402b693-2121-4345-a6e9-df52223f82c1	2026-08-19 02:09:39.005893	\N	4819.00	481.90	5300.90	отменён	ошибка	Тестовый заказ
7e6d040b-c1bb-4086-914b-cee6ac204403	52d023b3-6f69-4978-912c-c4121988dc40	fff1ab96-27a5-4e02-95a3-5a4ea623f599	7cbb3e90-a945-4aaa-91da-12267500493e	58351ddb-7140-48d0-9ea3-0c068293e707	2026-08-14 04:34:41.455658	\N	3197.00	319.70	3516.70	готовится	оплачен	Тестовый заказ
f76c125a-dafb-4ad1-85a8-c2cb5d716cd3	b6263dbb-9a5d-4014-9e77-1dd1306104ea	fad83466-2a6d-4c90-b57b-c216e5856038	523289f1-a9da-42b7-895a-ed030dc7bf4d	39968751-82a2-4940-9fc0-1cda08ea02b9	2026-08-08 18:24:52.383487	2026-08-09 04:32:18.608564	3105.00	310.50	3415.50	доставлен	оплачен	Тестовый заказ
49b0d3f9-20d6-404f-9aa6-9856b02c9fdb	988ff19a-b3c4-4c2e-987d-c50c6260c2b0	859c4ca6-6f29-4ab1-a3a3-312c64a2042d	d5e8a59b-3173-42cf-a0f7-05fff6abb6a0	e162c52c-87b9-4885-a7dd-2b400d15063a	2026-07-03 16:41:29.413401	\N	2866.00	286.60	3152.60	отменён	ошибка	Тестовый заказ
4377dcaf-a953-454f-b8a6-939e26310eff	345d851e-b7ff-41d2-b912-7936ae4a82ea	859c4ca6-6f29-4ab1-a3a3-312c64a2042d	d5e8a59b-3173-42cf-a0f7-05fff6abb6a0	083bc952-958d-403d-a9b1-5b71d09d74a9	2026-08-20 00:02:41.364783	2026-08-20 22:16:44.5271	3189.00	318.90	3507.90	доставлен	оплачен	Тестовый заказ
feda119d-0179-448a-9308-01011934f172	b6263dbb-9a5d-4014-9e77-1dd1306104ea	b864179e-f78f-46f9-8a13-06fbad92ef2a	bc0adb06-9f2a-47d9-ab8a-63ddf4e4cba5	be34e6cb-9360-4773-8167-ae8d58775d78	2026-10-24 23:59:43.511457	\N	1056.00	105.60	1161.60	готовится	оплачен	Тестовый заказ
60058adb-d8bb-4130-bcb0-1b00f9d307c5	988ff19a-b3c4-4c2e-987d-c50c6260c2b0	fad83466-2a6d-4c90-b57b-c216e5856038	bd36d7b2-394a-4f3d-ac92-952a9efb2884	f93b7f35-33bf-416a-8039-a2152fdd8c02	2026-08-02 22:55:33.512108	2026-08-03 14:00:23.189826	1101.00	110.10	1211.10	доставлен	оплачен	Тестовый заказ
3963cb86-42fd-4839-9835-257fb83291c3	52d023b3-6f69-4978-912c-c4121988dc40	03838d52-94eb-42f6-aec6-1f59201a3a05	afc449d5-cf58-442b-9c10-87aa923501b1	39968751-82a2-4940-9fc0-1cda08ea02b9	2026-07-31 22:47:23.37795	2026-08-01 02:09:05.625734	3103.00	310.30	3413.30	доставлен	оплачен	Тестовый заказ
877278fa-38fe-4cbc-894f-ad969910735b	345d851e-b7ff-41d2-b912-7936ae4a82ea	b300a5a7-9cb1-4a7e-a4ff-b40b709809ab	773cb06c-6972-49ea-be14-90a634687a6e	e402b693-2121-4345-a6e9-df52223f82c1	2026-07-27 22:00:15.897181	2026-07-28 18:57:38.093563	7266.00	726.60	7992.60	доставлен	оплачен	Тестовый заказ
620c2992-7cc0-4b7c-9b5a-4094c82e752f	988ff19a-b3c4-4c2e-987d-c50c6260c2b0	b300a5a7-9cb1-4a7e-a4ff-b40b709809ab	8e38c561-a2dc-4373-a7a8-66863390333e	e162c52c-87b9-4885-a7dd-2b400d15063a	2026-08-24 17:02:23.74889	2026-08-24 18:43:06.496076	6232.00	623.20	6855.20	доставлен	оплачен	Тестовый заказ
e03e1071-d9e2-4ffa-9d32-d0304b4e7658	988ff19a-b3c4-4c2e-987d-c50c6260c2b0	e653208d-c757-40ee-9297-7a4824805a1c	004901c4-bdec-40dc-8462-8f49520c09d7	e402b693-2121-4345-a6e9-df52223f82c1	2026-06-02 02:00:25.395937	2026-06-02 03:02:40.865352	3000.00	300.00	3300.00	доставлен	оплачен	Тестовый заказ
29591e2b-78c1-484e-8f7f-c2588fee47e3	165a4355-04e3-4f05-87b4-9ffdcf297a0b	e841d07d-42a9-40b9-bec8-a22c15209e49	abd1ca45-c34c-448c-a851-8678e9328fdb	f93b7f35-33bf-416a-8039-a2152fdd8c02	2026-07-17 20:40:47.755311	2026-07-18 14:17:15.697682	2063.00	206.30	2269.30	доставлен	оплачен	Тестовый заказ
a9194dba-02bf-453d-83c4-8f01c9a9b7b5	44079337-1686-46c0-94bf-eda3a53093e0	b864179e-f78f-46f9-8a13-06fbad92ef2a	2e05a4b5-8cd5-4889-874e-0fe4f24055de	58351ddb-7140-48d0-9ea3-0c068293e707	2026-09-09 18:04:10.762236	2026-09-09 19:34:00.810345	6915.00	691.50	7606.50	доставлен	оплачен	Тестовый заказ
\.


--
-- TOC entry 4970 (class 0 OID 17105)
-- Dependencies: 231
-- Data for Name: order_structure; Type: TABLE DATA; Schema: buldakov_food; Owner: postgres
--

COPY buldakov_food.order_structure (order_id, product_id, quantity) FROM stdin;
2f4b9ac5-9865-4387-9cea-8cf4f6d6e6cc	c428ea12-ea6f-4c02-9f23-152876230c36	3.00
2f4b9ac5-9865-4387-9cea-8cf4f6d6e6cc	a57b61ba-233e-4f7b-960b-8dcdf848d948	3.00
27daf419-8208-42ed-825a-ecfc30ed855a	a988b24a-3a15-486f-bd11-a7aeb111b1ee	2.00
27daf419-8208-42ed-825a-ecfc30ed855a	6ebdbe79-85d5-49be-bc98-fdec5257d7dc	2.00
01457044-2191-46ee-9df6-6170e24db5ad	54afd303-b036-4551-8950-29c6f5d694b3	3.00
01457044-2191-46ee-9df6-6170e24db5ad	8fb0f601-d347-4031-998a-425e1aff0449	3.00
01457044-2191-46ee-9df6-6170e24db5ad	b4a97f66-13a7-44c6-98c7-8466cc8188c2	1.00
2c1fb20b-2f38-4c07-99be-1ed2cd161c15	b4a97f66-13a7-44c6-98c7-8466cc8188c2	6.00
11c2a8ff-b1a7-4f71-9438-6cdfbf510353	a57b61ba-233e-4f7b-960b-8dcdf848d948	2.00
11c2a8ff-b1a7-4f71-9438-6cdfbf510353	c428ea12-ea6f-4c02-9f23-152876230c36	3.00
d4b5dd82-d687-42ed-9eb6-edd8b7bb18cb	cd7d7fdf-3253-4d4e-99b4-c9eb28c8f4ea	3.00
d4b5dd82-d687-42ed-9eb6-edd8b7bb18cb	ad6b9a76-c98f-46dc-9322-4cec5dbe9846	3.00
611d753f-d254-4d12-af5d-b14d31bdadf8	66868615-922e-42b5-9659-1952c9619e4a	2.00
611d753f-d254-4d12-af5d-b14d31bdadf8	d77d2e8d-e864-400e-a9f3-3d10caed3967	2.00
4ffe635e-7440-4a06-b306-d5816857f263	a988b24a-3a15-486f-bd11-a7aeb111b1ee	3.00
4ffe635e-7440-4a06-b306-d5816857f263	6ebdbe79-85d5-49be-bc98-fdec5257d7dc	3.00
42fad3ce-5a1a-4bb3-af20-b3865604f44a	bdad3081-fd72-4e14-8d03-d3eb26472180	1.00
42fad3ce-5a1a-4bb3-af20-b3865604f44a	3c7a48d6-2148-4f5c-94e8-e565a44a5f38	1.00
42fad3ce-5a1a-4bb3-af20-b3865604f44a	d668750f-1542-4c48-b5dd-9c96d200642e	2.00
e57d44c5-b81b-4225-abb3-02e531c79e1b	b01c16c7-eee4-4f4b-bd50-9de73c1c4c6d	1.00
e57d44c5-b81b-4225-abb3-02e531c79e1b	ad6b9a76-c98f-46dc-9322-4cec5dbe9846	1.00
e57d44c5-b81b-4225-abb3-02e531c79e1b	cd7d7fdf-3253-4d4e-99b4-c9eb28c8f4ea	2.00
062b19b6-5eb5-4d03-896e-e4c651ab5e88	2f803397-c3e9-4596-b971-7cb8fc9afc15	3.00
062b19b6-5eb5-4d03-896e-e4c651ab5e88	c4490879-0885-4d26-954e-f75a0f3f06e3	3.00
062b19b6-5eb5-4d03-896e-e4c651ab5e88	b8c177f2-f24a-4bed-9762-9a08dc1048ff	1.00
c9409596-ffdf-43a2-b589-80bfa522421e	b8c177f2-f24a-4bed-9762-9a08dc1048ff	2.00
c9409596-ffdf-43a2-b589-80bfa522421e	c4490879-0885-4d26-954e-f75a0f3f06e3	2.00
1c8c00ef-dc11-470a-891c-cdd3b473e90c	a988b24a-3a15-486f-bd11-a7aeb111b1ee	1.00
1c8c00ef-dc11-470a-891c-cdd3b473e90c	6ebdbe79-85d5-49be-bc98-fdec5257d7dc	3.00
364a1dde-0097-4094-af12-8f3ef37cb9ea	3fa9d626-2d35-4d41-9a74-41602b4f3499	1.00
364a1dde-0097-4094-af12-8f3ef37cb9ea	a82b81f9-3b0d-41c3-b19f-eb2b3867d984	3.00
364a1dde-0097-4094-af12-8f3ef37cb9ea	87096f52-a915-486b-893e-fdaa0123f132	3.00
364a1dde-0097-4094-af12-8f3ef37cb9ea	fc1c0d99-cf16-43d5-a895-add9bf6ca76c	2.00
1720ed8b-6332-4312-bb27-e990d77a4a80	ad6b9a76-c98f-46dc-9322-4cec5dbe9846	3.00
1720ed8b-6332-4312-bb27-e990d77a4a80	b01c16c7-eee4-4f4b-bd50-9de73c1c4c6d	1.00
1720ed8b-6332-4312-bb27-e990d77a4a80	cd7d7fdf-3253-4d4e-99b4-c9eb28c8f4ea	2.00
19b504d5-572d-438c-a497-c1e2be16e08b	c428ea12-ea6f-4c02-9f23-152876230c36	3.00
1b1dec13-625a-47a7-8518-c6c3eb5784a3	3c7a48d6-2148-4f5c-94e8-e565a44a5f38	2.00
1b1dec13-625a-47a7-8518-c6c3eb5784a3	bdad3081-fd72-4e14-8d03-d3eb26472180	1.00
1b1dec13-625a-47a7-8518-c6c3eb5784a3	d668750f-1542-4c48-b5dd-9c96d200642e	3.00
4ec19e2b-c69c-42ac-91a8-76b3ec645b22	c428ea12-ea6f-4c02-9f23-152876230c36	2.00
4ec19e2b-c69c-42ac-91a8-76b3ec645b22	a57b61ba-233e-4f7b-960b-8dcdf848d948	3.00
84f9e3f1-0f77-4d1e-94e1-ce2389edb529	b01c16c7-eee4-4f4b-bd50-9de73c1c4c6d	3.00
42388ad7-5a73-4c7c-8d13-9f98694b2ed7	54afd303-b036-4551-8950-29c6f5d694b3	3.00
42388ad7-5a73-4c7c-8d13-9f98694b2ed7	b4a97f66-13a7-44c6-98c7-8466cc8188c2	3.00
42388ad7-5a73-4c7c-8d13-9f98694b2ed7	8fb0f601-d347-4031-998a-425e1aff0449	3.00
92f3fe6b-15a1-48c4-9955-50bc30f5892c	cd7d7fdf-3253-4d4e-99b4-c9eb28c8f4ea	2.00
92f3fe6b-15a1-48c4-9955-50bc30f5892c	ad6b9a76-c98f-46dc-9322-4cec5dbe9846	2.00
92f3fe6b-15a1-48c4-9955-50bc30f5892c	b01c16c7-eee4-4f4b-bd50-9de73c1c4c6d	2.00
50560a13-94ed-4daa-80e7-974d296fbef6	cd7d7fdf-3253-4d4e-99b4-c9eb28c8f4ea	2.00
50560a13-94ed-4daa-80e7-974d296fbef6	ad6b9a76-c98f-46dc-9322-4cec5dbe9846	3.00
50560a13-94ed-4daa-80e7-974d296fbef6	b01c16c7-eee4-4f4b-bd50-9de73c1c4c6d	3.00
0a250efe-edef-4100-880f-feff5b12c9be	b01c16c7-eee4-4f4b-bd50-9de73c1c4c6d	2.00
0a250efe-edef-4100-880f-feff5b12c9be	ad6b9a76-c98f-46dc-9322-4cec5dbe9846	1.00
0a250efe-edef-4100-880f-feff5b12c9be	cd7d7fdf-3253-4d4e-99b4-c9eb28c8f4ea	2.00
0f3825eb-d7b9-4c1b-9bf3-1730dcc97f38	a82b81f9-3b0d-41c3-b19f-eb2b3867d984	1.00
0f3825eb-d7b9-4c1b-9bf3-1730dcc97f38	87096f52-a915-486b-893e-fdaa0123f132	1.00
0f3825eb-d7b9-4c1b-9bf3-1730dcc97f38	fc1c0d99-cf16-43d5-a895-add9bf6ca76c	2.00
0006a201-1d4a-49e4-b9ce-d004cd4fe27c	2f803397-c3e9-4596-b971-7cb8fc9afc15	3.00
5028f5c5-4bce-43a7-b06f-759c169350d0	c4490879-0885-4d26-954e-f75a0f3f06e3	1.00
5028f5c5-4bce-43a7-b06f-759c169350d0	2f803397-c3e9-4596-b971-7cb8fc9afc15	2.00
5028f5c5-4bce-43a7-b06f-759c169350d0	b8c177f2-f24a-4bed-9762-9a08dc1048ff	1.00
168e030a-20bc-45a6-8d47-10f013613115	2f803397-c3e9-4596-b971-7cb8fc9afc15	1.00
168e030a-20bc-45a6-8d47-10f013613115	b8c177f2-f24a-4bed-9762-9a08dc1048ff	3.00
6596a699-4ea5-4ee9-98b8-9c8729f2ec47	ad6b9a76-c98f-46dc-9322-4cec5dbe9846	2.00
6596a699-4ea5-4ee9-98b8-9c8729f2ec47	cd7d7fdf-3253-4d4e-99b4-c9eb28c8f4ea	1.00
30ebc613-fbf7-49cf-ae4e-cb3f3d217209	2f803397-c3e9-4596-b971-7cb8fc9afc15	2.00
40396bc9-ef2e-4627-9af5-26dbe8c675ad	54afd303-b036-4551-8950-29c6f5d694b3	3.00
40396bc9-ef2e-4627-9af5-26dbe8c675ad	b4a97f66-13a7-44c6-98c7-8466cc8188c2	3.00
40396bc9-ef2e-4627-9af5-26dbe8c675ad	8fb0f601-d347-4031-998a-425e1aff0449	1.00
63c8c1d1-572e-49b3-97b0-e3cdd799c889	a57b61ba-233e-4f7b-960b-8dcdf848d948	3.00
63c8c1d1-572e-49b3-97b0-e3cdd799c889	c428ea12-ea6f-4c02-9f23-152876230c36	1.00
a9920c23-0e7c-4c3a-8daf-139fa136320c	1ee4f4a1-6012-438c-894e-bd6bfce56650	3.00
e492437d-6615-4b6f-afa2-a01235cbe128	8fb0f601-d347-4031-998a-425e1aff0449	2.00
e492437d-6615-4b6f-afa2-a01235cbe128	b4a97f66-13a7-44c6-98c7-8466cc8188c2	2.00
e492437d-6615-4b6f-afa2-a01235cbe128	54afd303-b036-4551-8950-29c6f5d694b3	2.00
51474f4f-cd53-466b-9dda-8c50eb19c884	8fb0f601-d347-4031-998a-425e1aff0449	3.00
51474f4f-cd53-466b-9dda-8c50eb19c884	b4a97f66-13a7-44c6-98c7-8466cc8188c2	2.00
51474f4f-cd53-466b-9dda-8c50eb19c884	54afd303-b036-4551-8950-29c6f5d694b3	1.00
1f6795df-4f04-46ba-8fc4-f1ff598fc204	fc1c0d99-cf16-43d5-a895-add9bf6ca76c	2.00
1f6795df-4f04-46ba-8fc4-f1ff598fc204	3fa9d626-2d35-4d41-9a74-41602b4f3499	1.00
1f6795df-4f04-46ba-8fc4-f1ff598fc204	a82b81f9-3b0d-41c3-b19f-eb2b3867d984	2.00
1f6795df-4f04-46ba-8fc4-f1ff598fc204	87096f52-a915-486b-893e-fdaa0123f132	3.00
511ea4d1-a08f-4052-bf56-d920733ef6c3	3c7a48d6-2148-4f5c-94e8-e565a44a5f38	2.00
511ea4d1-a08f-4052-bf56-d920733ef6c3	d668750f-1542-4c48-b5dd-9c96d200642e	3.00
511ea4d1-a08f-4052-bf56-d920733ef6c3	bdad3081-fd72-4e14-8d03-d3eb26472180	2.00
b7e4483d-187f-417e-8621-fa09866f05a8	8b5d4c6f-f15e-4342-86a7-7ddf8f84e24d	1.00
b7e4483d-187f-417e-8621-fa09866f05a8	a275bcda-ecf2-4930-98b7-28ce9beecdbf	2.00
b7e4483d-187f-417e-8621-fa09866f05a8	d61a205b-f831-4a63-a8ac-641d7ba91416	2.00
b7e4483d-187f-417e-8621-fa09866f05a8	c78b2e8b-bab3-4089-99ec-82611c5bf638	2.00
6e3a1ff8-5719-487d-8ac6-934c5b6d4323	3c7a48d6-2148-4f5c-94e8-e565a44a5f38	3.00
6e3a1ff8-5719-487d-8ac6-934c5b6d4323	d668750f-1542-4c48-b5dd-9c96d200642e	2.00
6e3a1ff8-5719-487d-8ac6-934c5b6d4323	bdad3081-fd72-4e14-8d03-d3eb26472180	1.00
7e6d040b-c1bb-4086-914b-cee6ac204403	c4490879-0885-4d26-954e-f75a0f3f06e3	1.00
7e6d040b-c1bb-4086-914b-cee6ac204403	b8c177f2-f24a-4bed-9762-9a08dc1048ff	1.00
7e6d040b-c1bb-4086-914b-cee6ac204403	2f803397-c3e9-4596-b971-7cb8fc9afc15	2.00
f76c125a-dafb-4ad1-85a8-c2cb5d716cd3	3fa9d626-2d35-4d41-9a74-41602b4f3499	1.00
f76c125a-dafb-4ad1-85a8-c2cb5d716cd3	87096f52-a915-486b-893e-fdaa0123f132	1.00
f76c125a-dafb-4ad1-85a8-c2cb5d716cd3	a82b81f9-3b0d-41c3-b19f-eb2b3867d984	3.00
49b0d3f9-20d6-404f-9aa6-9856b02c9fdb	d61a205b-f831-4a63-a8ac-641d7ba91416	3.00
49b0d3f9-20d6-404f-9aa6-9856b02c9fdb	ff2666b9-2809-4045-bdc6-f8b794475b9a	2.00
4377dcaf-a953-454f-b8a6-939e26310eff	a57b61ba-233e-4f7b-960b-8dcdf848d948	2.00
4377dcaf-a953-454f-b8a6-939e26310eff	c428ea12-ea6f-4c02-9f23-152876230c36	3.00
feda119d-0179-448a-9308-01011934f172	66868615-922e-42b5-9659-1952c9619e4a	2.00
60058adb-d8bb-4130-bcb0-1b00f9d307c5	ad6b9a76-c98f-46dc-9322-4cec5dbe9846	2.00
60058adb-d8bb-4130-bcb0-1b00f9d307c5	b01c16c7-eee4-4f4b-bd50-9de73c1c4c6d	1.00
3963cb86-42fd-4839-9835-257fb83291c3	3fa9d626-2d35-4d41-9a74-41602b4f3499	3.00
3963cb86-42fd-4839-9835-257fb83291c3	a82b81f9-3b0d-41c3-b19f-eb2b3867d984	1.00
3963cb86-42fd-4839-9835-257fb83291c3	87096f52-a915-486b-893e-fdaa0123f132	1.00
3963cb86-42fd-4839-9835-257fb83291c3	fc1c0d99-cf16-43d5-a895-add9bf6ca76c	3.00
877278fa-38fe-4cbc-894f-ad969910735b	d668750f-1542-4c48-b5dd-9c96d200642e	3.00
877278fa-38fe-4cbc-894f-ad969910735b	bdad3081-fd72-4e14-8d03-d3eb26472180	3.00
877278fa-38fe-4cbc-894f-ad969910735b	3c7a48d6-2148-4f5c-94e8-e565a44a5f38	3.00
620c2992-7cc0-4b7c-9b5a-4094c82e752f	c78b2e8b-bab3-4089-99ec-82611c5bf638	3.00
620c2992-7cc0-4b7c-9b5a-4094c82e752f	a275bcda-ecf2-4930-98b7-28ce9beecdbf	3.00
620c2992-7cc0-4b7c-9b5a-4094c82e752f	8b5d4c6f-f15e-4342-86a7-7ddf8f84e24d	3.00
620c2992-7cc0-4b7c-9b5a-4094c82e752f	d61a205b-f831-4a63-a8ac-641d7ba91416	3.00
620c2992-7cc0-4b7c-9b5a-4094c82e752f	ff2666b9-2809-4045-bdc6-f8b794475b9a	2.00
e03e1071-d9e2-4ffa-9d32-d0304b4e7658	bdad3081-fd72-4e14-8d03-d3eb26472180	3.00
29591e2b-78c1-484e-8f7f-c2588fee47e3	ad6b9a76-c98f-46dc-9322-4cec5dbe9846	2.00
29591e2b-78c1-484e-8f7f-c2588fee47e3	b01c16c7-eee4-4f4b-bd50-9de73c1c4c6d	3.00
a9194dba-02bf-453d-83c4-8f01c9a9b7b5	c4490879-0885-4d26-954e-f75a0f3f06e3	3.00
a9194dba-02bf-453d-83c4-8f01c9a9b7b5	b8c177f2-f24a-4bed-9762-9a08dc1048ff	3.00
a9194dba-02bf-453d-83c4-8f01c9a9b7b5	2f803397-c3e9-4596-b971-7cb8fc9afc15	2.00
\.


--
-- TOC entry 4969 (class 0 OID 17092)
-- Dependencies: 230
-- Data for Name: payment; Type: TABLE DATA; Schema: buldakov_food; Owner: postgres
--

COPY buldakov_food.payment (payment_id, order_id, payment_type, amount, transaction_id, transaction_timestamp, status) FROM stdin;
d24fb109-4814-4add-a8e4-3ac855df0d6c	2f4b9ac5-9865-4387-9cea-8cf4f6d6e6cc	безнал	3616.80	1c0d1531-7c8e-4870-b1c3-034cb354aca6	2026-11-15 05:21:09.157354	в_обработке
705ca8a4-091e-4e42-ac9a-41570eadc329	27daf419-8208-42ed-825a-ecfc30ed855a	безнал	1808.40	0f7ffac4-9568-4fa3-a966-e6b1d81f2067	2026-05-31 15:55:42.864181	в_обработке
dcf53c77-89dc-4b18-9f0e-4407f130ff84	01457044-2191-46ee-9df6-6170e24db5ad	наличные	3060.20	7672dfa1-ffa8-4093-bd92-5f47905d950b	2026-08-11 00:11:38.628261	ошибка
5dafa233-5619-41cc-af8b-e78d7cfd1d5c	2c1fb20b-2f38-4c07-99be-1ed2cd161c15	безнал	1135.20	0226d92e-8565-4530-9192-73e6d292f472	2026-06-03 07:39:04.907551	успех
0dfc138c-c4e9-447d-8c0e-16d91c90efd9	11c2a8ff-b1a7-4f71-9438-6cdfbf510353	наличные	3507.90	a6985740-d6ee-4b6c-b0fe-097bf0a9b27b	2026-06-18 13:22:27.303023	успех
dce7ac3f-c27f-4a26-9f5b-3da623d18876	d4b5dd82-d687-42ed-9eb6-edd8b7bb18cb	наличные	3154.80	f4c79b26-454e-479b-9773-6496098c6c41	2026-11-15 07:43:13.029783	успех
cec71183-6329-4caf-bd5e-b1095c90010d	611d753f-d254-4d12-af5d-b14d31bdadf8	безнал	1614.80	34c547a9-6a17-4d68-be71-d0689b2857df	2026-05-28 02:33:20.005609	успех
71bd3d58-95c9-4a39-81de-7a02923100f0	4ffe635e-7440-4a06-b306-d5816857f263	карта	2712.60	2a0130d6-69a2-454c-bb97-3c91ad737566	2026-10-14 09:54:10.624904	в_обработке
8358c6b2-a439-467d-984b-f27cd6e95fdc	42fad3ce-5a1a-4bb3-af20-b3865604f44a	карта	3155.90	cc703d81-8bd2-4e9d-907d-743549d6588c	2026-08-29 17:59:33.336937	успех
b0c35954-a7ed-4bed-84ff-2564f1dba7d3	e57d44c5-b81b-4225-abb3-02e531c79e1b	карта	2291.30	e1bbc2ca-cfe8-48f3-aa6b-f49a28568a79	2026-08-20 02:39:03.014006	успех
a6e4e46b-304e-433c-907a-bb9a6ef5a57c	062b19b6-5eb5-4d03-896e-e4c651ab5e88	безнал	6296.40	5ad6dc22-aee0-47b9-943d-6f98d4050212	2026-11-01 12:05:24.717868	успех
70d5d0fd-8773-42b4-a0d6-4455535e0ee1	c9409596-ffdf-43a2-b589-80bfa522421e	карта	4089.80	bb44883f-cd1c-4c48-a791-6c2f4ecb292f	2026-10-08 23:56:56.282799	в_обработке
7779f554-0816-4521-b7ec-8f8631bbd310	1c8c00ef-dc11-470a-891c-cdd3b473e90c	наличные	2131.80	f902b40f-b867-46fa-96af-e2ba0a50b535	2026-09-27 20:09:25.779122	успех
32feb4ff-3d02-4a0b-a226-bcd34cee324e	364a1dde-0097-4094-af12-8f3ef37cb9ea	карта	5430.70	aa520cbd-1159-48e5-8be0-54d07343390a	2026-08-29 22:56:12.797606	успех
04094b73-706e-4424-b40a-bebf6bf46f2b	1720ed8b-6332-4312-bb27-e990d77a4a80	наличные	2973.30	72877fad-16fe-44ad-bc38-86616c6216af	2026-09-08 17:51:36.961101	успех
54a68098-20a2-4882-9e37-4eba6a422f43	19b504d5-572d-438c-a497-c1e2be16e08b	наличные	3290.10	7843eada-d03c-4b72-8f01-d3d61d978443	2026-07-28 00:29:23.750796	ошибка
22deff47-ee37-4838-8094-0682d0963a8c	1b1dec13-625a-47a7-8518-c6c3eb5784a3	наличные	4720.10	0b987d73-23ea-4252-aad0-828135d42649	2026-06-24 16:58:38.074433	успех
54bc734e-eb57-4acc-a7c7-be16e9a52218	4ec19e2b-c69c-42ac-91a8-76b3ec645b22	безнал	2520.10	750f2058-7637-4a9c-a5ff-7866f40f4313	2026-07-31 21:12:57.975759	в_обработке
352f711e-4483-48d0-95b1-fe9a7052dcd9	84f9e3f1-0f77-4d1e-94e1-ce2389edb529	безнал	1587.30	9f9cc876-73f2-4cd1-bcca-859cdc980faf	2026-06-29 09:21:40.345886	успех
c4611064-03d3-421a-bf12-9531114d9179	42388ad7-5a73-4c7c-8d13-9f98694b2ed7	карта	3438.60	83e4f49b-4745-4b64-9844-683130a7fd0d	2026-06-25 05:37:35.379196	в_обработке
4bb47c87-0d2b-45ef-9102-d7eaef324913	92f3fe6b-15a1-48c4-9955-50bc30f5892c	безнал	3161.40	4f2fae5e-0d3b-40ca-b81e-a8cc10e444f3	2026-08-30 13:33:12.095443	успех
63ba7863-90c5-4f94-aa6c-10cebb533e30	50560a13-94ed-4daa-80e7-974d296fbef6	наличные	4031.50	0eea30af-fdd6-47e8-abb1-4e62f08d0774	2026-10-28 22:18:15.829564	успех
1982ed7a-c41e-48a0-8400-c36297dc4288	0a250efe-edef-4100-880f-feff5b12c9be	наличные	2820.40	5d3f03c9-ebdf-47d5-89ef-f2894acb3628	2026-08-16 18:26:48.642851	успех
deb6d5a5-091d-445b-ad84-16e374160ab0	0f3825eb-d7b9-4c1b-9bf3-1730dcc97f38	наличные	2146.10	38f50a9a-b423-4c6c-a7ed-c59361181ad6	2026-06-02 22:13:55.175544	в_обработке
d3d787ac-5d6a-4404-9f8d-1f829155fb40	0006a201-1d4a-49e4-b9ce-d004cd4fe27c	наличные	2207.70	e167f93d-a52f-4ba2-9106-2f9f10b0d248	2026-08-02 08:31:00.195079	в_обработке
772874f9-1542-4d4e-b3a1-c04a4ba860ce	5028f5c5-4bce-43a7-b06f-759c169350d0	безнал	3516.70	d3eaf58b-6e8b-48ce-8040-1f0a9b18b405	2026-05-24 08:47:20.588061	успех
ce8be0c6-e7ae-4b95-97b0-b34f22666909	168e030a-20bc-45a6-8d47-10f013613115	карта	3804.90	0409e699-a307-4de3-a1f4-f894c0c8e97d	2026-06-29 12:42:41.728686	в_обработке
b08dacff-eb77-440a-bdc5-37cbfb9278d2	6596a699-4ea5-4ee9-98b8-9c8729f2ec47	безнал	1392.60	f6fd8d94-f73c-4d81-a7a5-b36540e67c81	2026-08-29 15:31:20.577973	ошибка
b84121d7-3379-442b-a584-ab469f160ac0	30ebc613-fbf7-49cf-ae4e-cb3f3d217209	наличные	1471.80	1fa612f1-f14b-4590-a633-11226a8e6d34	2026-09-09 01:40:05.048409	в_обработке
a9bc20f0-61dc-4ac6-a7dc-642ad553e148	40396bc9-ef2e-4627-9af5-26dbe8c675ad	наличные	2129.60	831d2cbf-35c5-45d6-a798-8e758d3edc8d	2026-10-07 04:50:54.143963	успех
f650516b-6c5b-4780-8696-9fdb03a6af61	63c8c1d1-572e-49b3-97b0-e3cdd799c889	карта	1423.40	eab1635e-fdba-45ad-9aa1-11eb0b54282e	2026-09-01 09:34:49.952808	в_обработке
770a1928-d5cf-440e-8259-ce7616a6f968	a9920c23-0e7c-4c3a-8daf-139fa136320c	карта	2828.10	4a7aad56-6c13-4eca-b7cf-771d4cf10349	2026-11-09 23:01:54.160568	успех
0f7f15d9-7b0c-4f83-a92e-4a3c69a04f2c	e492437d-6615-4b6f-afa2-a01235cbe128	карта	2292.40	0072e20c-9029-4328-bb16-df0cdc1ee171	2026-07-06 13:41:28.657379	ошибка
60b3b434-2b1c-494c-96bc-8df6516d615d	51474f4f-cd53-466b-9dda-8c50eb19c884	карта	2644.40	ccc43549-e34d-47c5-bc02-5b1953b6dbb7	2026-08-03 07:40:41.63659	успех
d6e62001-51b3-4264-a3d6-2bc16656fe14	1f6795df-4f04-46ba-8fc4-f1ff598fc204	наличные	4622.20	54272846-d562-49a7-b564-88c53b2070ae	2026-08-13 12:24:14.648124	успех
630d203c-714d-4fc7-9deb-5796c4f2bdd7	511ea4d1-a08f-4052-bf56-d920733ef6c3	наличные	5820.10	94787645-c0f0-4fb4-a44a-397fe2274112	2026-10-09 22:10:48.483225	ошибка
77b20ef9-2d34-4ca0-8830-80565aeb7211	b7e4483d-187f-417e-8621-fa09866f05a8	карта	3632.20	b6e9e5aa-da0a-41b4-8e44-5d50f06d45ef	2026-08-22 18:08:11.017592	успех
a3f3bc97-2f9d-430c-ae13-9766b562cd3e	6e3a1ff8-5719-487d-8ac6-934c5b6d4323	безнал	5300.90	88efc7a0-70e0-403f-92ea-2541ccb1da2f	2026-08-19 02:56:52.640172	ошибка
e6a34808-a601-48b9-8768-f1d14bbbe0fb	7e6d040b-c1bb-4086-914b-cee6ac204403	наличные	3516.70	7fcf90b8-6492-41d7-96c3-2884137cf74b	2026-08-14 05:06:47.506222	успех
985474f9-cd18-478f-8fdb-ad6f6968964a	f76c125a-dafb-4ad1-85a8-c2cb5d716cd3	карта	3415.50	36b29843-1784-48db-9301-180c2caeba23	2026-08-08 19:12:35.356582	успех
99999783-4f96-45e6-a0a1-bd89cfbdee92	49b0d3f9-20d6-404f-9aa6-9856b02c9fdb	наличные	3152.60	8d0e6d43-e0e7-48b8-bc2e-1921c4f53b01	2026-07-03 17:15:27.631167	ошибка
3df2e15f-a41a-4175-9988-29649f48a217	4377dcaf-a953-454f-b8a6-939e26310eff	карта	3507.90	cb5d49d5-0aa4-4cc5-b6e8-4a7b07120954	2026-08-20 00:24:46.454253	успех
2ac8cf0b-28b6-4b05-8af3-a259cb5e9fa3	feda119d-0179-448a-9308-01011934f172	наличные	1161.60	fb3d87cf-6c97-4041-bfc9-44b3a07c2a71	2026-10-25 00:39:18.09639	успех
c040c5fa-eba2-444b-8041-85f602b09026	60058adb-d8bb-4130-bcb0-1b00f9d307c5	наличные	1211.10	c16311d6-49b4-44b4-82a1-7877f92f7f76	2026-08-02 23:54:04.756399	успех
1c11c5bf-06e9-4b86-80e3-493a8b28629e	3963cb86-42fd-4839-9835-257fb83291c3	карта	3413.30	78ed516a-79f2-4291-8721-65502765373d	2026-07-31 23:15:38.493618	успех
0742f4c6-ee83-43bd-b633-ecba1236128d	877278fa-38fe-4cbc-894f-ad969910735b	безнал	7992.60	ca26b92c-d6a0-4478-870f-5529fc703670	2026-07-27 22:38:32.64079	успех
40706feb-2ef0-4169-aa83-d4be3c2a090e	620c2992-7cc0-4b7c-9b5a-4094c82e752f	наличные	6855.20	307cd0c1-1f84-46e6-b91c-01ca07486a39	2026-08-24 17:09:54.662463	успех
62a0d824-5d2e-4247-9e92-ff8c1889d608	e03e1071-d9e2-4ffa-9d32-d0304b4e7658	наличные	3300.00	22af7247-93fa-4765-a256-75b9aa5e1271	2026-06-02 02:57:45.850121	успех
10eb0417-3058-48a7-8a22-a2531e05bbc5	29591e2b-78c1-484e-8f7f-c2588fee47e3	безнал	2269.30	8a3fca28-018e-4976-b31c-e9a9190c56f3	2026-07-17 21:37:44.786045	успех
ef1f6a6e-3fdd-4cd5-aab7-125e09b237ac	a9194dba-02bf-453d-83c4-8f01c9a9b7b5	безнал	7606.50	920ee006-887b-4aa6-bc7c-e6054e85cd79	2026-09-09 18:19:11.1947	успех
\.


--
-- TOC entry 4966 (class 0 OID 17036)
-- Dependencies: 227
-- Data for Name: product; Type: TABLE DATA; Schema: buldakov_food; Owner: postgres
--

COPY buldakov_food.product (product_id, product_name, product_category_id, price, restaurant_id, photo_url, rating, status, description) FROM stdin;
a57b61ba-233e-4f7b-960b-8dcdf848d948	Product_27ab10eb-49fe-47cd-82bc-1e669deaffbf	80093a4f-edde-4356-93a8-96cb0e877c6b	99.00	083bc952-958d-403d-a9b1-5b71d09d74a9	\N	\N	доступно	Какое-то описание продукта a850ec0b-95a7-40a9-a7c6-41488d26c620
c3334fff-cced-4e6e-8f82-00b32ff277a0	Product_dfca8fc9-eb5a-485c-b605-9101b2309a0c	54324710-35d7-432f-906a-547542d6f61c	738.00	083bc952-958d-403d-a9b1-5b71d09d74a9	\N	\N	архив	Какое-то описание продукта 7e333818-1cdb-4033-9564-e58b6c00b348
5a5f3d0e-79a2-4e49-9c53-9d9a4a655e3b	Product_32d3affd-d792-47b1-b6e1-b8b54157f86c	ac84ecf1-ec7c-40c0-967e-294331bf5ce5	84.00	083bc952-958d-403d-a9b1-5b71d09d74a9	\N	\N	архив	Какое-то описание продукта 4744db83-3551-4644-a404-0876e5846d9b
c1362cf9-fbc4-4219-a6e3-cff0732504b1	Product_58e99084-4dba-4ca2-a78d-594b1287ef83	d358d203-d778-4135-8481-e491d78dcec6	454.00	083bc952-958d-403d-a9b1-5b71d09d74a9	\N	\N	нет_в_наличии	Какое-то описание продукта 6618c535-a20c-4f39-a89c-f54c25924e76
c428ea12-ea6f-4c02-9f23-152876230c36	Product_81e17b02-e6b1-42a4-ae4d-37516838aa18	852340d9-f4a5-4c0e-a433-741c54839a0a	997.00	083bc952-958d-403d-a9b1-5b71d09d74a9	\N	3.0	доступно	Какое-то описание продукта a0653e0c-1e13-4fe7-afca-7333cc411a70
c4490879-0885-4d26-954e-f75a0f3f06e3	Product_e4304d23-9753-4e83-9434-153a411c7cd8	f343f4a8-8c4b-42cb-9a9f-ac7e724ffe89	929.00	58351ddb-7140-48d0-9ea3-0c068293e707	\N	\N	доступно	Какое-то описание продукта e9d96db3-4da7-4b2b-91d4-f1614b06e85f
4e5b3883-2bf5-4f58-a1d6-0fb3eaf70dea	Product_2dd4eaf7-69a7-472f-8877-766d6eb1f0db	ae51b47c-58fa-4364-80e8-55966116a212	579.00	58351ddb-7140-48d0-9ea3-0c068293e707	\N	\N	нет_в_наличии	Какое-то описание продукта 494d23c2-4e8f-4000-bbe3-429604e0439e
20fa8aee-d594-4e14-a990-fe6e91cae817	Product_b0b4bdfb-c201-491c-bf5d-5b7c89e8f394	54324710-35d7-432f-906a-547542d6f61c	417.00	58351ddb-7140-48d0-9ea3-0c068293e707	\N	\N	архив	Какое-то описание продукта 560280e8-65ee-47e4-b1a1-2506698dea6f
b8c177f2-f24a-4bed-9762-9a08dc1048ff	Product_3571de6a-7e65-4292-8443-c91a93e313f2	d358d203-d778-4135-8481-e491d78dcec6	930.00	58351ddb-7140-48d0-9ea3-0c068293e707	\N	\N	доступно	Какое-то описание продукта 8f97b1a2-6fbd-42bc-8295-e2a781857672
5444867b-f4fa-4e47-a768-c6fa751e0b04	Product_4385a64a-ab6f-4383-afed-dc03fabc4222	2f274b57-065b-4a21-96c9-f2281b965c25	495.00	97f5b71a-7860-4bc8-8071-63e50efe9090	\N	\N	нет_в_наличии	Какое-то описание продукта 4cea1079-ee4e-4061-bde8-7f4181dedc59
0bfd93a2-cb63-4181-9db1-567b729f8c7f	Product_d27040f4-3542-4e5a-9e82-f024fbd7343e	2f274b57-065b-4a21-96c9-f2281b965c25	980.00	97f5b71a-7860-4bc8-8071-63e50efe9090	\N	\N	архив	Какое-то описание продукта 8beae3e1-a193-4689-9c9d-dc77305b2f30
3c7a48d6-2148-4f5c-94e8-e565a44a5f38	Product_ea8cec25-b8c6-4ba8-ae9e-8f79b5413811	aa42a66d-164f-4214-a586-1783480d4c1a	975.00	e402b693-2121-4345-a6e9-df52223f82c1	\N	\N	доступно	Какое-то описание продукта 2fc9a0de-2fcd-4f03-a79a-49f53b99dcdc
d668750f-1542-4c48-b5dd-9c96d200642e	Product_2fe3f8c2-a38b-440b-9a96-cad6ecd5b9b6	852340d9-f4a5-4c0e-a433-741c54839a0a	447.00	e402b693-2121-4345-a6e9-df52223f82c1	\N	\N	доступно	Какое-то описание продукта 3e5895b9-18c0-47f5-8b59-5884c30aa7c5
4e533d28-50f4-4d6d-8d8b-ff58f9442c32	Product_5d9c996f-0f6e-46b0-b0d0-b556030cf1c5	852340d9-f4a5-4c0e-a433-741c54839a0a	476.00	e402b693-2121-4345-a6e9-df52223f82c1	\N	\N	нет_в_наличии	Какое-то описание продукта e2f83aeb-7948-477d-8291-3c6677da4e65
d383f3e7-355a-45cd-ba37-2555a39cffa3	Product_188dca80-34f5-4ffe-9d43-3287dccf2f6c	0a5ca0c4-389a-453d-972d-e9f09ad6d30e	459.00	e402b693-2121-4345-a6e9-df52223f82c1	\N	\N	архив	Какое-то описание продукта ee9e7c7b-d7e1-439a-ad6b-47063a9efd6c
d77d2e8d-e864-400e-a9f3-3d10caed3967	Product_6b1b349c-fa3c-4ab0-971a-ec43ca73650e	d358d203-d778-4135-8481-e491d78dcec6	206.00	be34e6cb-9360-4773-8167-ae8d58775d78	\N	\N	доступно	Какое-то описание продукта f894cd23-8e6d-4bbd-86cb-7f81fbdcddc5
6c9245e5-0094-47d2-94e9-b69ae68cf20f	Product_6e574455-e657-43c0-be87-24a137951136	f343f4a8-8c4b-42cb-9a9f-ac7e724ffe89	524.00	be34e6cb-9360-4773-8167-ae8d58775d78	\N	\N	архив	Какое-то описание продукта 4f708316-01ab-4b74-b77f-86d56da36706
94fe38a4-9094-45da-9f1d-18c811f008b8	Product_6eea4409-5950-4436-b2ef-0bc97cbcba37	f343f4a8-8c4b-42cb-9a9f-ac7e724ffe89	726.00	be34e6cb-9360-4773-8167-ae8d58775d78	\N	\N	архив	Какое-то описание продукта 7cd8284d-1ca7-4870-96f1-4fa52ab4fe12
a2684208-12b5-4eb4-889a-0ef99920a890	Product_3171d307-e256-4d2b-ba26-6b518fe2401f	aa42a66d-164f-4214-a586-1783480d4c1a	660.00	be34e6cb-9360-4773-8167-ae8d58775d78	\N	\N	архив	Какое-то описание продукта 81e46c9c-e5d3-4ea5-acdb-c437c96b7243
ffec2bd6-1c76-4bc1-871e-ad85af0a3555	Product_f7360b84-5776-47b6-a41f-fe20bc8b62a5	54324710-35d7-432f-906a-547542d6f61c	152.00	f93b7f35-33bf-416a-8039-a2152fdd8c02	\N	\N	архив	Какое-то описание продукта d642eb95-fda5-4b19-8076-71fd03b4ba4e
0b9f3b2f-96cf-42fd-bb52-23f9e99279f5	Product_188149a7-999f-4d6f-9287-a80a45a36046	54324710-35d7-432f-906a-547542d6f61c	908.00	f93b7f35-33bf-416a-8039-a2152fdd8c02	\N	\N	архив	Какое-то описание продукта 5daab542-e7a5-4c63-8e0f-b66747316567
b01c16c7-eee4-4f4b-bd50-9de73c1c4c6d	Product_08f64bfc-8c2f-4c66-bb50-70b45da0933c	80093a4f-edde-4356-93a8-96cb0e877c6b	481.00	f93b7f35-33bf-416a-8039-a2152fdd8c02	\N	\N	доступно	Какое-то описание продукта 4781f730-0865-4f37-a360-aa88a717edaa
9b90ffbc-ab00-44e6-b9e8-80c7cc5b2d9b	Product_3b8327d6-599b-4664-8565-ba59cd917366	80093a4f-edde-4356-93a8-96cb0e877c6b	819.00	515a0759-8881-4f0b-bd5a-3d28605c9cd7	\N	\N	доступно	Какое-то описание продукта 4a7d724d-802c-4e22-8336-4ca665672345
6e167cc9-b733-4010-8289-cd386ca614fc	Product_03bf3a67-afa7-4e67-9f01-5e64c0c621ca	2f274b57-065b-4a21-96c9-f2281b965c25	646.00	515a0759-8881-4f0b-bd5a-3d28605c9cd7	\N	\N	архив	Какое-то описание продукта 4e284ab7-9938-4aae-a02c-3da11e2ef24c
343f1d81-1b9f-44c0-affc-98e0db71f137	Product_0e5b9b37-c74a-4780-a1c4-167d2f944c16	852340d9-f4a5-4c0e-a433-741c54839a0a	492.00	515a0759-8881-4f0b-bd5a-3d28605c9cd7	\N	\N	нет_в_наличии	Какое-то описание продукта 01bb99f8-eee6-4739-b10d-3e83bc1e32de
89b4aa94-3bb1-4510-915a-84046101b7f3	Product_7bc2e8b8-e679-44ae-b586-2b93181eb2c2	852340d9-f4a5-4c0e-a433-741c54839a0a	781.00	515a0759-8881-4f0b-bd5a-3d28605c9cd7	\N	\N	доступно	Какое-то описание продукта 16d6adcc-fe86-47ed-b802-ee542b5ba0fe
1ee4f4a1-6012-438c-894e-bd6bfce56650	Product_49982f49-b2dc-4372-82bd-2bc24ef89ad1	80093a4f-edde-4356-93a8-96cb0e877c6b	857.00	515a0759-8881-4f0b-bd5a-3d28605c9cd7	\N	\N	доступно	Какое-то описание продукта ca206722-dddc-4e97-a5b8-2132a0be6cc3
a988b24a-3a15-486f-bd11-a7aeb111b1ee	Product_12e17457-4eb5-44be-aaf4-7b35b60ad074	852340d9-f4a5-4c0e-a433-741c54839a0a	264.00	1158ccbd-4b38-49de-a19e-e1b3adbe3f31	\N	\N	доступно	Какое-то описание продукта 875675f2-3926-43e5-852d-5bf798364d9a
d1a5afd2-b579-4d8a-a820-51b0ef6cd4f9	Product_1cfd299e-13a2-4bc5-987c-3f43325f21b4	ac84ecf1-ec7c-40c0-967e-294331bf5ce5	959.00	1158ccbd-4b38-49de-a19e-e1b3adbe3f31	\N	\N	нет_в_наличии	Какое-то описание продукта 53c6d03e-4084-4942-a329-5b92cc259a58
e53bbb09-478c-4b3b-95b4-b2070655b183	Product_918225c2-7a61-4665-95f0-fd6bb0dd571d	852340d9-f4a5-4c0e-a433-741c54839a0a	932.00	1158ccbd-4b38-49de-a19e-e1b3adbe3f31	\N	\N	нет_в_наличии	Какое-то описание продукта d8e7028b-efa2-4e57-8457-97dd2b4a3d3a
6ebdbe79-85d5-49be-bc98-fdec5257d7dc	Product_1ce2480f-4c5f-437f-9793-7f03e75aaf35	80093a4f-edde-4356-93a8-96cb0e877c6b	558.00	1158ccbd-4b38-49de-a19e-e1b3adbe3f31	\N	\N	доступно	Какое-то описание продукта 614a5f83-e9ce-4eeb-9afb-2211c595b60b
93714edb-1788-4d35-93fe-1e278d85286b	Product_f5d701d6-de8a-4d38-9f85-e1f72c104765	2f274b57-065b-4a21-96c9-f2281b965c25	432.00	1158ccbd-4b38-49de-a19e-e1b3adbe3f31	\N	\N	нет_в_наличии	Какое-то описание продукта 09813645-7dfd-44b6-ac58-5b6112ea3247
a275bcda-ecf2-4930-98b7-28ce9beecdbf	Product_15a32f6c-629e-4439-a662-e2ddff85c994	f343f4a8-8c4b-42cb-9a9f-ac7e724ffe89	427.00	e162c52c-87b9-4885-a7dd-2b400d15063a	\N	\N	доступно	Какое-то описание продукта 349bbdc9-59e8-4ca7-a7a5-901eca8cde5e
d61a205b-f831-4a63-a8ac-641d7ba91416	Product_497ed05a-702c-41db-b480-d4becf962f9b	f343f4a8-8c4b-42cb-9a9f-ac7e724ffe89	864.00	e162c52c-87b9-4885-a7dd-2b400d15063a	\N	\N	доступно	Какое-то описание продукта fa4b7f99-707b-4194-a82f-6070bdb62958
8b5d4c6f-f15e-4342-86a7-7ddf8f84e24d	Product_67bdba59-e2ed-4d66-a1cd-a97ec6cb3c35	aa42a66d-164f-4214-a586-1783480d4c1a	670.00	e162c52c-87b9-4885-a7dd-2b400d15063a	\N	\N	доступно	Какое-то описание продукта a7ac641b-4e9a-4d81-a276-8eab9fd79b3c
c78b2e8b-bab3-4089-99ec-82611c5bf638	Product_f09a9c1d-ce18-43b4-ad81-256244471a6f	d358d203-d778-4135-8481-e491d78dcec6	25.00	e162c52c-87b9-4885-a7dd-2b400d15063a	\N	\N	доступно	Какое-то описание продукта f54ce10a-8a7d-4ba1-b298-df7165b92bba
87096f52-a915-486b-893e-fdaa0123f132	Product_e0c720ac-f13f-4306-b5a1-a6e61e26b8b6	f343f4a8-8c4b-42cb-9a9f-ac7e724ffe89	616.00	39968751-82a2-4940-9fc0-1cda08ea02b9	\N	\N	доступно	Какое-то описание продукта f1d6e0c3-2f46-4bce-be1e-e898dd8f8a2b
3fa9d626-2d35-4d41-9a74-41602b4f3499	Product_d3b0a32e-9de0-43cb-b1ad-d467a1895ef2	852340d9-f4a5-4c0e-a433-741c54839a0a	284.00	39968751-82a2-4940-9fc0-1cda08ea02b9	\N	\N	доступно	Какое-то описание продукта 432e2413-8cb9-417d-b5d9-4b2ec264bfa2
e4830fbb-ac51-4d79-acf8-9a67ed06d18f	Product_a7ebd356-ee65-4c72-ac06-05c011152ed6	852340d9-f4a5-4c0e-a433-741c54839a0a	759.00	39968751-82a2-4940-9fc0-1cda08ea02b9	\N	\N	архив	Какое-то описание продукта 2e724b4e-67b6-4198-a386-8f149aea9960
b4a97f66-13a7-44c6-98c7-8466cc8188c2	Product_53af53f7-dda2-4e10-8560-c8d6135fa9b7	852340d9-f4a5-4c0e-a433-741c54839a0a	172.00	97f5b71a-7860-4bc8-8071-63e50efe9090	\N	5.0	доступно	Какое-то описание продукта 861b32e9-4987-44f3-adc6-62d38677ac77
bdad3081-fd72-4e14-8d03-d3eb26472180	Product_7f09ac40-15bd-44a0-9e4b-3d1fe08e75e7	54324710-35d7-432f-906a-547542d6f61c	1000.00	e402b693-2121-4345-a6e9-df52223f82c1	\N	1.0	доступно	Какое-то описание продукта 9f8cc3b7-8afd-41d2-ad36-d45c9d2ab4d1
a82b81f9-3b0d-41c3-b19f-eb2b3867d984	Product_b910c77a-2942-4fa7-b193-1bd4e546a540	0a5ca0c4-389a-453d-972d-e9f09ad6d30e	735.00	39968751-82a2-4940-9fc0-1cda08ea02b9	\N	5.0	доступно	Какое-то описание продукта 1c43ce74-d358-4047-92b0-582733c2a4ad
ad6b9a76-c98f-46dc-9322-4cec5dbe9846	Product_568847ef-7f24-4152-8df4-f41458667f14	852340d9-f4a5-4c0e-a433-741c54839a0a	310.00	f93b7f35-33bf-416a-8039-a2152fdd8c02	\N	4.0	доступно	Какое-то описание продукта 8525345b-c663-40e0-b86b-42a30a16d308
fc1c0d99-cf16-43d5-a895-add9bf6ca76c	Product_1482d84a-0099-4040-905e-b7b2bcbf8de3	aa42a66d-164f-4214-a586-1783480d4c1a	300.00	39968751-82a2-4940-9fc0-1cda08ea02b9	\N	2.0	доступно	Какое-то описание продукта 8e1e659b-a633-41fa-bbd4-cd43d5947cdf
2f803397-c3e9-4596-b971-7cb8fc9afc15	Product_c2468df4-305b-4792-a0aa-9d99870d2826	ae51b47c-58fa-4364-80e8-55966116a212	669.00	58351ddb-7140-48d0-9ea3-0c068293e707	\N	3.5	доступно	Какое-то описание продукта 887037c0-9514-41cf-9e1c-b9a4ef4f6076
cd7d7fdf-3253-4d4e-99b4-c9eb28c8f4ea	Product_dbe6c243-5e0b-44e2-9d22-e3da55e2ba24	ac84ecf1-ec7c-40c0-967e-294331bf5ce5	646.00	f93b7f35-33bf-416a-8039-a2152fdd8c02	\N	2.0	доступно	Какое-то описание продукта 508aa407-b572-4ff6-8d94-402aec50abb1
54afd303-b036-4551-8950-29c6f5d694b3	Product_7f43daee-2343-4f6c-a10b-16e97b29fbb8	ae51b47c-58fa-4364-80e8-55966116a212	275.00	97f5b71a-7860-4bc8-8071-63e50efe9090	\N	1.0	доступно	Какое-то описание продукта 2259ef35-8bd2-4daf-a7ee-3dc1c620bfdd
8fb0f601-d347-4031-998a-425e1aff0449	Product_909c5ef3-e397-40d9-a09a-faf813f38fa1	2f274b57-065b-4a21-96c9-f2281b965c25	595.00	97f5b71a-7860-4bc8-8071-63e50efe9090	\N	3.0	доступно	Какое-то описание продукта 048731cb-124b-4ea7-952c-5b4dd8bda021
ff2666b9-2809-4045-bdc6-f8b794475b9a	Product_1511371b-84ef-474c-a0d5-15a4213b2427	ac84ecf1-ec7c-40c0-967e-294331bf5ce5	137.00	e162c52c-87b9-4885-a7dd-2b400d15063a	\N	4.0	доступно	Какое-то описание продукта 181de558-dca2-49fe-8ab3-0661e06c4a02
66868615-922e-42b5-9659-1952c9619e4a	Product_907e2b55-62cd-4b4f-a17b-f2611b74cbd6	ac84ecf1-ec7c-40c0-967e-294331bf5ce5	528.00	be34e6cb-9360-4773-8167-ae8d58775d78	\N	3.0	доступно	Какое-то описание продукта 38b43ff8-4bcb-40e9-b583-a1d95e034c64
\.


--
-- TOC entry 4964 (class 0 OID 16998)
-- Dependencies: 225
-- Data for Name: product_category; Type: TABLE DATA; Schema: buldakov_food; Owner: postgres
--

COPY buldakov_food.product_category (product_category_id, product_category_name) FROM stdin;
f343f4a8-8c4b-42cb-9a9f-ac7e724ffe89	product_cat_7beffaa4-fb8e-4a44-89d7-9e60d889d265
2f274b57-065b-4a21-96c9-f2281b965c25	product_cat_a30f3fd5-e8ce-4aa1-97dd-7821b2bb1ba0
ae51b47c-58fa-4364-80e8-55966116a212	product_cat_609451e0-a4ba-4b55-ba02-d8e18928c60a
80093a4f-edde-4356-93a8-96cb0e877c6b	product_cat_cffe956d-ba12-4997-9050-1e2ca224dcc8
54324710-35d7-432f-906a-547542d6f61c	product_cat_79b2027a-462a-4f8e-8e94-79555d5438e9
aa42a66d-164f-4214-a586-1783480d4c1a	product_cat_45f3fc5c-61ca-42b7-975c-c49957594e08
0a5ca0c4-389a-453d-972d-e9f09ad6d30e	product_cat_eb6572b4-43df-4a14-ae59-15723c90c889
d358d203-d778-4135-8481-e491d78dcec6	product_cat_c8038664-14c1-4ec8-8a3f-5ca938d98eb8
ac84ecf1-ec7c-40c0-967e-294331bf5ce5	product_cat_5b3b3527-863b-4cdd-b886-9a1717f82bb0
852340d9-f4a5-4c0e-a433-741c54839a0a	product_cat_d05b80df-bcd3-40aa-b4cf-df883a5582f5
\.


--
-- TOC entry 4962 (class 0 OID 16968)
-- Dependencies: 223
-- Data for Name: restaurant; Type: TABLE DATA; Schema: buldakov_food; Owner: postgres
--

COPY buldakov_food.restaurant (restaurant_id, restaurant_name, address_id, description, work_start, work_end, rating, status, inn, ogrn, bank_account) FROM stdin;
be34e6cb-9360-4773-8167-ae8d58775d78	restaurant_9f35ff48-e350-402d-af89-cd5387af45b8	db0ed65a-3b86-4384-8c50-33e6e53112c9	Описание ресторана 4978	09:25:00	17:05:00	\N	активен	100774728927	000461538870691	00000000643683776842
97f5b71a-7860-4bc8-8071-63e50efe9090	restaurant_73dfa0f9-9375-4a00-8152-9c2a9b36d633	0db63742-13b3-4bde-905d-1f311528f7f5	Описание ресторана 48	05:43:00	11:11:00	3.0	неактивен	817791505696	000581806956528	00000000281759059151
1158ccbd-4b38-49de-a19e-e1b3adbe3f31	restaurant_20b9ba45-1579-4c30-825c-d2d6a75bc677	55f5f8eb-400a-439b-b5ee-f1b1b36d3a52	Описание ресторана 5823	06:44:00	14:16:00	1.0	неактивен	779565783409	000857114657250	00000000486193943657
515a0759-8881-4f0b-bd5a-3d28605c9cd7	restaurant_6ccaa194-199b-463c-9fac-2e7378cda142	7ae3bb8b-d550-4e4d-9db2-09a476eab585	Описание ресторана 1196	08:01:00	13:43:00	3.0	активен	987769005676	000324355716819	00000000866536950406
e162c52c-87b9-4885-a7dd-2b400d15063a	restaurant_67e7f451-851a-4c99-b829-a5fd4c93cc93	c51bd7bc-8677-473a-a59f-5b20b80fd465	Описание ресторана 6292	00:19:00	06:48:00	1.0	активен	317249895875	000963594122554	00000000652295699652
39968751-82a2-4940-9fc0-1cda08ea02b9	restaurant_35a72d58-380a-443b-8fbb-1dba8c855928	d8e96489-5207-4421-ad40-1a7371599849	Описание ресторана 3168	00:37:00	11:24:00	1.0	неактивен	929324004871	000758071745256	00000000629014222531
083bc952-958d-403d-a9b1-5b71d09d74a9	restaurant_219eb969-b034-46d9-a9ae-ffb940cff0b1	3d82c26b-a58f-4588-a6a4-385826ed3b16	Описание ресторана 702	07:18:00	18:27:00	4.3	активен	888486428606	000314768838792	00000000331108884972
e402b693-2121-4345-a6e9-df52223f82c1	restaurant_dcfbf653-2337-41c3-8450-a03e09e4e687	aaf379a9-c215-4093-9405-6b999b409e07	Описание ресторана 3135	01:26:00	06:12:00	2.3	неактивен	965242629478	000982967282240	00000000247224387576
f93b7f35-33bf-416a-8039-a2152fdd8c02	restaurant_e5d9553d-5b02-4d59-91e9-344cd55b2507	7fc87ed5-2426-4c4d-965c-659a8872d018	Описание ресторана 5342	06:20:00	14:17:00	3.8	неактивен	236848426404	000523714593222	00000000818425518092
58351ddb-7140-48d0-9ea3-0c068293e707	restaurant_61f4cc54-1d97-4330-91ad-4226e5098aca	10649047-ae37-4a0c-ae3d-a95c7b04e9b0	Описание ресторана 1324	06:09:00	12:03:00	4.0	активен	612113242862	000325042362983	00000000700912236176
\.


--
-- TOC entry 4968 (class 0 OID 17071)
-- Dependencies: 229
-- Data for Name: review; Type: TABLE DATA; Schema: buldakov_food; Owner: postgres
--

COPY buldakov_food.review (review_id, client_id, review_timestamp, entity_id, entity_type, order_id, description, photo_url, rating) FROM stdin;
eb17faee-6374-455c-a2c8-ac50fad50892	27b8654e-ac63-4a9b-9564-0691dc934a72	2026-11-15 14:00:19.610643	083bc952-958d-403d-a9b1-5b71d09d74a9	ресторан	2f4b9ac5-9865-4387-9cea-8cf4f6d6e6cc	Все супер	\N	3.0
8fcc7573-b699-43fa-9b8d-963bd0057064	fad83466-2a6d-4c90-b57b-c216e5856038	2026-08-16 01:23:36.884819	1158ccbd-4b38-49de-a19e-e1b3adbe3f31	ресторан	27daf419-8208-42ed-825a-ecfc30ed855a	Круто	\N	1.0
c1e2ce05-7622-493c-aa21-63cdcdcbe224	03838d52-94eb-42f6-aec6-1f59201a3a05	2026-10-23 20:00:51.041162	97f5b71a-7860-4bc8-8071-63e50efe9090	ресторан	01457044-2191-46ee-9df6-6170e24db5ad	can be better	\N	3.0
3b0d8773-fd7f-48ea-8349-52dc71108d15	b864179e-f78f-46f9-8a13-06fbad92ef2a	2026-06-05 17:41:08.084303	b4a97f66-13a7-44c6-98c7-8466cc8188c2	блюдо	2c1fb20b-2f38-4c07-99be-1ed2cd161c15	Все супер	\N	5.0
a9ef1451-23b2-46e0-a1d2-fe235d04abdc	e653208d-c757-40ee-9297-7a4824805a1c	2026-09-18 12:16:30.436146	11c2a8ff-b1a7-4f71-9438-6cdfbf510353	заказ	11c2a8ff-b1a7-4f71-9438-6cdfbf510353	can be better	\N	4.0
f6730877-fcd7-4941-83f9-48c4c021bb22	b864179e-f78f-46f9-8a13-06fbad92ef2a	2026-11-15 15:56:05.869705	f93b7f35-33bf-416a-8039-a2152fdd8c02	ресторан	d4b5dd82-d687-42ed-9eb6-edd8b7bb18cb	Not bad	\N	4.0
ed620264-a7c1-4a0d-b9bc-bc4755b5c5d0	fff1ab96-27a5-4e02-95a3-5a4ea623f599	2026-09-16 10:56:56.003677	66868615-922e-42b5-9659-1952c9619e4a	блюдо	611d753f-d254-4d12-af5d-b14d31bdadf8	Круто	\N	5.0
538eccd1-4127-4a0a-a275-22ec753894ba	fff1ab96-27a5-4e02-95a3-5a4ea623f599	2026-10-21 02:32:45.064921	1158ccbd-4b38-49de-a19e-e1b3adbe3f31	ресторан	4ffe635e-7440-4a06-b306-d5816857f263	Все супер	\N	1.0
974f512e-b42a-45d1-9900-df8ce8545617	fff1ab96-27a5-4e02-95a3-5a4ea623f599	2026-09-06 05:40:29.15981	bdad3081-fd72-4e14-8d03-d3eb26472180	блюдо	42fad3ce-5a1a-4bb3-af20-b3865604f44a	Круто	\N	1.0
880c192b-0143-43fb-a5af-393bba41b942	27b8654e-ac63-4a9b-9564-0691dc934a72	2026-09-29 06:14:51.936031	e57d44c5-b81b-4225-abb3-02e531c79e1b	заказ	e57d44c5-b81b-4225-abb3-02e531c79e1b	Все супер	\N	3.0
5820424b-f859-4f48-8784-aa7fb4310845	b300a5a7-9cb1-4a7e-a4ff-b40b709809ab	2026-11-13 10:15:11.652431	2f803397-c3e9-4596-b971-7cb8fc9afc15	блюдо	062b19b6-5eb5-4d03-896e-e4c651ab5e88	can be better	\N	2.0
20cb8b49-047c-4a72-8b4b-1fd672ed47d0	e653208d-c757-40ee-9297-7a4824805a1c	2026-10-23 19:13:18.8913	c9409596-ffdf-43a2-b589-80bfa522421e	заказ	c9409596-ffdf-43a2-b589-80bfa522421e	Круто	\N	2.0
9bd4cac0-7b9b-43ce-ac1a-97b0c47b0dd5	03838d52-94eb-42f6-aec6-1f59201a3a05	2026-10-07 17:34:54.226378	1c8c00ef-dc11-470a-891c-cdd3b473e90c	заказ	1c8c00ef-dc11-470a-891c-cdd3b473e90c	Not bad	\N	2.0
fdb4261c-a686-48ca-a9e4-cbfe71d20ebf	859c4ca6-6f29-4ab1-a3a3-312c64a2042d	2026-09-26 10:18:11.797533	a82b81f9-3b0d-41c3-b19f-eb2b3867d984	блюдо	364a1dde-0097-4094-af12-8f3ef37cb9ea	can be better	\N	5.0
0a985c5f-32f5-4943-aced-e59728892808	b864179e-f78f-46f9-8a13-06fbad92ef2a	2026-09-25 04:00:10.53818	ad6b9a76-c98f-46dc-9322-4cec5dbe9846	блюдо	1720ed8b-6332-4312-bb27-e990d77a4a80	Все супер	\N	5.0
bb464d9d-377d-4e3e-a4ce-d48f5dbeb94d	b864179e-f78f-46f9-8a13-06fbad92ef2a	2026-10-20 01:46:53.383437	c428ea12-ea6f-4c02-9f23-152876230c36	блюдо	19b504d5-572d-438c-a497-c1e2be16e08b	Not bad	\N	3.0
ebf7fe15-8b69-4b73-8458-f1ecf0535823	27b8654e-ac63-4a9b-9564-0691dc934a72	2026-07-19 06:12:22.048782	1b1dec13-625a-47a7-8518-c6c3eb5784a3	заказ	1b1dec13-625a-47a7-8518-c6c3eb5784a3	can be better	\N	5.0
187c8eb2-eed5-4f8f-93f1-bc920fded0f0	27b8654e-ac63-4a9b-9564-0691dc934a72	2026-09-17 18:18:36.976573	083bc952-958d-403d-a9b1-5b71d09d74a9	ресторан	4ec19e2b-c69c-42ac-91a8-76b3ec645b22	can be better	\N	5.0
482bfa44-0802-48db-a93b-c7b2a7944544	fff1ab96-27a5-4e02-95a3-5a4ea623f599	2026-07-04 19:48:57.535229	f93b7f35-33bf-416a-8039-a2152fdd8c02	ресторан	84f9e3f1-0f77-4d1e-94e1-ce2389edb529	Not bad	\N	1.0
8f9891dc-c617-46c5-88fa-933504ef5bcb	fad83466-2a6d-4c90-b57b-c216e5856038	2026-08-25 16:40:26.626645	42388ad7-5a73-4c7c-8d13-9f98694b2ed7	заказ	42388ad7-5a73-4c7c-8d13-9f98694b2ed7	Tasty	\N	1.0
9fc65629-80b3-4492-86ea-0c0b185a6ffb	03838d52-94eb-42f6-aec6-1f59201a3a05	2026-09-23 12:18:23.791235	ad6b9a76-c98f-46dc-9322-4cec5dbe9846	блюдо	92f3fe6b-15a1-48c4-9955-50bc30f5892c	Круто	\N	2.0
e3ce8837-f728-4542-9348-618d757e6472	16a33dfb-b96c-4117-8fb9-fc064baf86d5	2026-11-07 19:07:22.059635	50560a13-94ed-4daa-80e7-974d296fbef6	заказ	50560a13-94ed-4daa-80e7-974d296fbef6	Not bad	\N	5.0
14af51d5-631d-47c4-931d-d8b5ee65a2f1	b864179e-f78f-46f9-8a13-06fbad92ef2a	2026-09-09 02:36:11.44109	ad6b9a76-c98f-46dc-9322-4cec5dbe9846	блюдо	0a250efe-edef-4100-880f-feff5b12c9be	Tasty	\N	5.0
61b6f6c7-cb18-4f3d-be39-67b6160e2d9c	b864179e-f78f-46f9-8a13-06fbad92ef2a	2026-07-07 09:28:34.006527	fc1c0d99-cf16-43d5-a895-add9bf6ca76c	блюдо	0f3825eb-d7b9-4c1b-9bf3-1730dcc97f38	can be better	\N	2.0
a1551def-2975-4100-9ae7-db8417625ca2	fad83466-2a6d-4c90-b57b-c216e5856038	2026-08-05 05:54:32.454341	58351ddb-7140-48d0-9ea3-0c068293e707	ресторан	0006a201-1d4a-49e4-b9ce-d004cd4fe27c	can be better	\N	5.0
f24fc330-6c00-4eb5-904c-f99f6370bb63	fad83466-2a6d-4c90-b57b-c216e5856038	2026-07-06 23:55:55.622237	2f803397-c3e9-4596-b971-7cb8fc9afc15	блюдо	5028f5c5-4bce-43a7-b06f-759c169350d0	Not bad	\N	5.0
bd29ef8c-61c2-4936-a9ea-848a533263ec	fff1ab96-27a5-4e02-95a3-5a4ea623f599	2026-07-20 09:50:33.888531	168e030a-20bc-45a6-8d47-10f013613115	заказ	168e030a-20bc-45a6-8d47-10f013613115	Not bad	\N	1.0
bf1f8c53-3854-45a4-8774-cac7335fd78f	03838d52-94eb-42f6-aec6-1f59201a3a05	2026-10-18 14:27:33.805621	cd7d7fdf-3253-4d4e-99b4-c9eb28c8f4ea	блюдо	6596a699-4ea5-4ee9-98b8-9c8729f2ec47	Not bad	\N	2.0
39928918-0412-4fd6-aff2-8dab932a2184	859c4ca6-6f29-4ab1-a3a3-312c64a2042d	2026-10-24 03:11:23.693131	58351ddb-7140-48d0-9ea3-0c068293e707	ресторан	30ebc613-fbf7-49cf-ae4e-cb3f3d217209	Not bad	\N	2.0
187f3597-80d3-4130-85c6-9fbc58bb924a	16a33dfb-b96c-4117-8fb9-fc064baf86d5	2026-11-07 03:44:21.920627	54afd303-b036-4551-8950-29c6f5d694b3	блюдо	40396bc9-ef2e-4627-9af5-26dbe8c675ad	Not bad	\N	1.0
0d73caa8-c652-492e-b2e8-5a55a218476f	fff1ab96-27a5-4e02-95a3-5a4ea623f599	2026-09-15 02:41:51.665969	63c8c1d1-572e-49b3-97b0-e3cdd799c889	заказ	63c8c1d1-572e-49b3-97b0-e3cdd799c889	Все супер	\N	2.0
41b2c10e-1b33-4cee-8f2a-1206661235f7	fad83466-2a6d-4c90-b57b-c216e5856038	2026-11-14 07:51:56.328537	515a0759-8881-4f0b-bd5a-3d28605c9cd7	ресторан	a9920c23-0e7c-4c3a-8daf-139fa136320c	can be better	\N	3.0
5a9d5e71-5d45-478d-9984-ad6d7f530c40	fad83466-2a6d-4c90-b57b-c216e5856038	2026-10-25 19:14:26.520629	8fb0f601-d347-4031-998a-425e1aff0449	блюдо	e492437d-6615-4b6f-afa2-a01235cbe128	Круто	\N	3.0
32674383-6d4f-433e-9f49-ac77ea43eadf	859c4ca6-6f29-4ab1-a3a3-312c64a2042d	2026-09-26 17:18:58.291852	51474f4f-cd53-466b-9dda-8c50eb19c884	заказ	51474f4f-cd53-466b-9dda-8c50eb19c884	can be better	\N	2.0
32b73cb6-ae8a-49fd-b688-a4e2ba18b305	27b8654e-ac63-4a9b-9564-0691dc934a72	2026-09-16 07:47:40.128243	1f6795df-4f04-46ba-8fc4-f1ff598fc204	заказ	1f6795df-4f04-46ba-8fc4-f1ff598fc204	Not bad	\N	2.0
474f603f-a8e9-408a-a7cf-fd2d43e035cc	b300a5a7-9cb1-4a7e-a4ff-b40b709809ab	2026-10-29 06:31:56.781546	e402b693-2121-4345-a6e9-df52223f82c1	ресторан	511ea4d1-a08f-4052-bf56-d920733ef6c3	Все супер	\N	1.0
ddbd48f0-0a89-40ea-94a0-697d93b09c32	27b8654e-ac63-4a9b-9564-0691dc934a72	2026-10-01 20:32:10.985461	e162c52c-87b9-4885-a7dd-2b400d15063a	ресторан	b7e4483d-187f-417e-8621-fa09866f05a8	can be better	\N	1.0
9fd21836-74ac-40ac-ade3-5d315ccd2e61	b864179e-f78f-46f9-8a13-06fbad92ef2a	2026-10-24 02:40:18.787931	e402b693-2121-4345-a6e9-df52223f82c1	ресторан	6e3a1ff8-5719-487d-8ac6-934c5b6d4323	Tasty	\N	5.0
b694c3d0-3b13-46ac-a890-a15b0f8e455b	fff1ab96-27a5-4e02-95a3-5a4ea623f599	2026-09-04 11:45:27.601057	7e6d040b-c1bb-4086-914b-cee6ac204403	заказ	7e6d040b-c1bb-4086-914b-cee6ac204403	Tasty	\N	5.0
5b2efc79-d194-42b5-9078-c4651776072d	fad83466-2a6d-4c90-b57b-c216e5856038	2026-09-05 18:47:09.704222	39968751-82a2-4940-9fc0-1cda08ea02b9	ресторан	f76c125a-dafb-4ad1-85a8-c2cb5d716cd3	Все супер	\N	1.0
7e822666-2398-4333-bd84-e2878e66661e	859c4ca6-6f29-4ab1-a3a3-312c64a2042d	2026-07-04 12:12:56.796843	ff2666b9-2809-4045-bdc6-f8b794475b9a	блюдо	49b0d3f9-20d6-404f-9aa6-9856b02c9fdb	Tasty	\N	4.0
943411f3-b2f6-4532-aa3d-98ab14700d97	859c4ca6-6f29-4ab1-a3a3-312c64a2042d	2026-09-03 17:36:09.865922	083bc952-958d-403d-a9b1-5b71d09d74a9	ресторан	4377dcaf-a953-454f-b8a6-939e26310eff	Все супер	\N	5.0
b25d36cd-5c70-4167-a035-7ef88d6603db	b864179e-f78f-46f9-8a13-06fbad92ef2a	2026-10-31 08:05:55.360019	66868615-922e-42b5-9659-1952c9619e4a	блюдо	feda119d-0179-448a-9308-01011934f172	Все супер	\N	1.0
34a931de-352b-463f-abc6-bcf65918869d	fad83466-2a6d-4c90-b57b-c216e5856038	2026-10-21 16:04:28.527783	f93b7f35-33bf-416a-8039-a2152fdd8c02	ресторан	60058adb-d8bb-4130-bcb0-1b00f9d307c5	Все супер	\N	5.0
24cdf7f2-f9b7-4212-9fd0-94c6158c14c1	03838d52-94eb-42f6-aec6-1f59201a3a05	2026-08-28 04:08:25.134703	3963cb86-42fd-4839-9835-257fb83291c3	заказ	3963cb86-42fd-4839-9835-257fb83291c3	Tasty	\N	5.0
a47037a6-ac42-410c-bd83-142a40be1676	b300a5a7-9cb1-4a7e-a4ff-b40b709809ab	2026-10-30 14:15:41.207383	e402b693-2121-4345-a6e9-df52223f82c1	ресторан	877278fa-38fe-4cbc-894f-ad969910735b	Tasty	\N	1.0
cea75e65-ddf7-4a74-aa7a-4dbbcfb83349	b300a5a7-9cb1-4a7e-a4ff-b40b709809ab	2026-11-08 14:55:42.821959	620c2992-7cc0-4b7c-9b5a-4094c82e752f	заказ	620c2992-7cc0-4b7c-9b5a-4094c82e752f	Tasty	\N	4.0
73a04bf5-ebc5-4cd9-b118-d331c14fcc5a	e653208d-c757-40ee-9297-7a4824805a1c	2026-09-20 08:23:20.242127	e03e1071-d9e2-4ffa-9d32-d0304b4e7658	заказ	e03e1071-d9e2-4ffa-9d32-d0304b4e7658	Not bad	\N	5.0
a5661e02-7ee1-4148-8a79-05353969811f	e841d07d-42a9-40b9-bec8-a22c15209e49	2026-10-16 20:55:51.753119	f93b7f35-33bf-416a-8039-a2152fdd8c02	ресторан	29591e2b-78c1-484e-8f7f-c2588fee47e3	can be better	\N	5.0
eaa1f20a-3d85-47cb-911e-4299c72a575b	b864179e-f78f-46f9-8a13-06fbad92ef2a	2026-10-10 16:23:17.381003	58351ddb-7140-48d0-9ea3-0c068293e707	ресторан	a9194dba-02bf-453d-83c4-8f01c9a9b7b5	Все супер	\N	5.0
\.


--
-- TOC entry 4768 (class 2606 OID 16952)
-- Name: address address_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.address
    ADD CONSTRAINT address_pkey PRIMARY KEY (address_id);


--
-- TOC entry 4770 (class 2606 OID 16957)
-- Name: client_address client_address_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.client_address
    ADD CONSTRAINT client_address_pkey PRIMARY KEY (client_id, address_id);


--
-- TOC entry 4762 (class 2606 OID 16944)
-- Name: client client_login_key; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.client
    ADD CONSTRAINT client_login_key UNIQUE (login);


--
-- TOC entry 4764 (class 2606 OID 17903)
-- Name: client client_phone_number_key; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.client
    ADD CONSTRAINT client_phone_number_key UNIQUE (phone_number);


--
-- TOC entry 4766 (class 2606 OID 16942)
-- Name: client client_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.client
    ADD CONSTRAINT client_pkey PRIMARY KEY (client_id);


--
-- TOC entry 4786 (class 2606 OID 17065)
-- Name: courier_pay courier_pay_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.courier_pay
    ADD CONSTRAINT courier_pay_pkey PRIMARY KEY (year, month, courier_id);


--
-- TOC entry 4776 (class 2606 OID 16997)
-- Name: courier courier_phone_number_key; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.courier
    ADD CONSTRAINT courier_phone_number_key UNIQUE (phone_number);


--
-- TOC entry 4778 (class 2606 OID 16995)
-- Name: courier courier_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.courier
    ADD CONSTRAINT courier_pkey PRIMARY KEY (courier_id);


--
-- TOC entry 4782 (class 2606 OID 17015)
-- Name: order order_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food."order"
    ADD CONSTRAINT order_pkey PRIMARY KEY (order_id);


--
-- TOC entry 4796 (class 2606 OID 17112)
-- Name: order_structure order_structure_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.order_structure
    ADD CONSTRAINT order_structure_pkey PRIMARY KEY (order_id, product_id);


--
-- TOC entry 4792 (class 2606 OID 17097)
-- Name: payment payment_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.payment
    ADD CONSTRAINT payment_pkey PRIMARY KEY (payment_id);


--
-- TOC entry 4794 (class 2606 OID 17099)
-- Name: payment payment_transaction_id_key; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.payment
    ADD CONSTRAINT payment_transaction_id_key UNIQUE (transaction_id);


--
-- TOC entry 4780 (class 2606 OID 17003)
-- Name: product_category product_category_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.product_category
    ADD CONSTRAINT product_category_pkey PRIMARY KEY (product_category_id);


--
-- TOC entry 4784 (class 2606 OID 17045)
-- Name: product product_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.product
    ADD CONSTRAINT product_pkey PRIMARY KEY (product_id);


--
-- TOC entry 4772 (class 2606 OID 16979)
-- Name: restaurant restaurant_address_id_key; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.restaurant
    ADD CONSTRAINT restaurant_address_id_key UNIQUE (address_id);


--
-- TOC entry 4774 (class 2606 OID 16977)
-- Name: restaurant restaurant_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.restaurant
    ADD CONSTRAINT restaurant_pkey PRIMARY KEY (restaurant_id);


--
-- TOC entry 4788 (class 2606 OID 17081)
-- Name: review review_order_id_entity_type_entity_id_key; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.review
    ADD CONSTRAINT review_order_id_entity_type_entity_id_key UNIQUE (order_id, entity_type, entity_id);


--
-- TOC entry 4790 (class 2606 OID 17079)
-- Name: review review_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.review
    ADD CONSTRAINT review_pkey PRIMARY KEY (review_id);


--
-- TOC entry 4813 (class 2620 OID 17150)
-- Name: review review_rating_trigger; Type: TRIGGER; Schema: buldakov_food; Owner: postgres
--

CREATE TRIGGER review_rating_trigger AFTER INSERT OR DELETE OR UPDATE ON buldakov_food.review FOR EACH ROW EXECUTE FUNCTION buldakov_food.rating_change();


--
-- TOC entry 4797 (class 2606 OID 16963)
-- Name: client_address client_address_address_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.client_address
    ADD CONSTRAINT client_address_address_id_fkey FOREIGN KEY (address_id) REFERENCES buldakov_food.address(address_id);


--
-- TOC entry 4798 (class 2606 OID 16958)
-- Name: client_address client_address_client_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.client_address
    ADD CONSTRAINT client_address_client_id_fkey FOREIGN KEY (client_id) REFERENCES buldakov_food.client(client_id);


--
-- TOC entry 4807 (class 2606 OID 17066)
-- Name: courier_pay courier_pay_courier_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.courier_pay
    ADD CONSTRAINT courier_pay_courier_id_fkey FOREIGN KEY (courier_id) REFERENCES buldakov_food.courier(courier_id);


--
-- TOC entry 4800 (class 2606 OID 17026)
-- Name: order order_address_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food."order"
    ADD CONSTRAINT order_address_id_fkey FOREIGN KEY (address_id) REFERENCES buldakov_food.address(address_id);


--
-- TOC entry 4801 (class 2606 OID 17123)
-- Name: order order_client_address_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food."order"
    ADD CONSTRAINT order_client_address_fkey FOREIGN KEY (client_id, address_id) REFERENCES buldakov_food.client_address(client_id, address_id);


--
-- TOC entry 4802 (class 2606 OID 17021)
-- Name: order order_client_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food."order"
    ADD CONSTRAINT order_client_id_fkey FOREIGN KEY (client_id) REFERENCES buldakov_food.client(client_id);


--
-- TOC entry 4803 (class 2606 OID 17016)
-- Name: order order_courier_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food."order"
    ADD CONSTRAINT order_courier_id_fkey FOREIGN KEY (courier_id) REFERENCES buldakov_food.courier(courier_id);


--
-- TOC entry 4804 (class 2606 OID 17031)
-- Name: order order_restaurant_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food."order"
    ADD CONSTRAINT order_restaurant_id_fkey FOREIGN KEY (restaurant_id) REFERENCES buldakov_food.restaurant(restaurant_id);


--
-- TOC entry 4811 (class 2606 OID 17113)
-- Name: order_structure order_structure_order_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.order_structure
    ADD CONSTRAINT order_structure_order_id_fkey FOREIGN KEY (order_id) REFERENCES buldakov_food."order"(order_id);


--
-- TOC entry 4812 (class 2606 OID 17118)
-- Name: order_structure order_structure_product_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.order_structure
    ADD CONSTRAINT order_structure_product_id_fkey FOREIGN KEY (product_id) REFERENCES buldakov_food.product(product_id);


--
-- TOC entry 4810 (class 2606 OID 17100)
-- Name: payment payment_order_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.payment
    ADD CONSTRAINT payment_order_id_fkey FOREIGN KEY (order_id) REFERENCES buldakov_food."order"(order_id);


--
-- TOC entry 4805 (class 2606 OID 17046)
-- Name: product product_product_category_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.product
    ADD CONSTRAINT product_product_category_id_fkey FOREIGN KEY (product_category_id) REFERENCES buldakov_food.product_category(product_category_id);


--
-- TOC entry 4806 (class 2606 OID 17051)
-- Name: product product_restaurant_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.product
    ADD CONSTRAINT product_restaurant_id_fkey FOREIGN KEY (restaurant_id) REFERENCES buldakov_food.restaurant(restaurant_id);


--
-- TOC entry 4799 (class 2606 OID 16980)
-- Name: restaurant restaurant_address_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.restaurant
    ADD CONSTRAINT restaurant_address_id_fkey FOREIGN KEY (address_id) REFERENCES buldakov_food.address(address_id);


--
-- TOC entry 4808 (class 2606 OID 17082)
-- Name: review review_client_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.review
    ADD CONSTRAINT review_client_id_fkey FOREIGN KEY (client_id) REFERENCES buldakov_food.client(client_id);


--
-- TOC entry 4809 (class 2606 OID 17087)
-- Name: review review_order_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: postgres
--

ALTER TABLE ONLY buldakov_food.review
    ADD CONSTRAINT review_order_id_fkey FOREIGN KEY (order_id) REFERENCES buldakov_food."order"(order_id);


--
-- TOC entry 4976 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA buldakov_food; Type: ACL; Schema: -; Owner: postgres
--

GRANT ALL ON SCHEMA buldakov_food TO inspector;


--
-- TOC entry 4977 (class 0 OID 0)
-- Dependencies: 261
-- Name: PROCEDURE add_product(IN product_name character varying, IN product_category_id uuid, IN price numeric, IN restaurant_id uuid, IN photo_url text, IN rating numeric, IN status buldakov_food.product_status, IN description text); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.add_product(IN product_name character varying, IN product_category_id uuid, IN price numeric, IN restaurant_id uuid, IN photo_url text, IN rating numeric, IN status buldakov_food.product_status, IN description text) TO inspector;


--
-- TOC entry 4978 (class 0 OID 0)
-- Dependencies: 264
-- Name: PROCEDURE courier_salary(); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.courier_salary() TO inspector;


--
-- TOC entry 4979 (class 0 OID 0)
-- Dependencies: 260
-- Name: PROCEDURE erase_test_data(); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.erase_test_data() TO inspector;


--
-- TOC entry 4980 (class 0 OID 0)
-- Dependencies: 254
-- Name: PROCEDURE generate_addresses(IN p_value integer, INOUT restaurant_address_ids uuid[], INOUT client_address_ids uuid[]); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.generate_addresses(IN p_value integer, INOUT restaurant_address_ids uuid[], INOUT client_address_ids uuid[]) TO inspector;


--
-- TOC entry 4981 (class 0 OID 0)
-- Dependencies: 266
-- Name: PROCEDURE generate_base_data(IN p_value integer, INOUT client_ids uuid[], INOUT courier_ids uuid[], INOUT product_category_ids uuid[]); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.generate_base_data(IN p_value integer, INOUT client_ids uuid[], INOUT courier_ids uuid[], INOUT product_category_ids uuid[]) TO inspector;


--
-- TOC entry 4982 (class 0 OID 0)
-- Dependencies: 257
-- Name: PROCEDURE generate_client_addresses(IN p_value integer, IN client_ids uuid[], IN client_address_ids uuid[]); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.generate_client_addresses(IN p_value integer, IN client_ids uuid[], IN client_address_ids uuid[]) TO inspector;


--
-- TOC entry 4983 (class 0 OID 0)
-- Dependencies: 267
-- Name: PROCEDURE generate_courier_pay(IN courier_ids uuid[]); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.generate_courier_pay(IN courier_ids uuid[]) TO inspector;


--
-- TOC entry 4984 (class 0 OID 0)
-- Dependencies: 256
-- Name: PROCEDURE generate_orders(IN p_value integer, IN client_ids uuid[], IN courier_ids uuid[], IN restaurant_ids uuid[], INOUT order_ids uuid[]); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.generate_orders(IN p_value integer, IN client_ids uuid[], IN courier_ids uuid[], IN restaurant_ids uuid[], INOUT order_ids uuid[]) TO inspector;


--
-- TOC entry 4985 (class 0 OID 0)
-- Dependencies: 262
-- Name: PROCEDURE generate_payments(IN p_order_ids uuid[]); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.generate_payments(IN p_order_ids uuid[]) TO inspector;


--
-- TOC entry 4986 (class 0 OID 0)
-- Dependencies: 255
-- Name: PROCEDURE generate_products(IN p_value integer, IN restaurant_ids uuid[], IN product_category_ids uuid[], INOUT product_ids uuid[]); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.generate_products(IN p_value integer, IN restaurant_ids uuid[], IN product_category_ids uuid[], INOUT product_ids uuid[]) TO inspector;


--
-- TOC entry 4987 (class 0 OID 0)
-- Dependencies: 265
-- Name: PROCEDURE generate_restaurants(IN p_value integer, IN restaurant_address_ids uuid[], INOUT restaurant_ids uuid[]); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.generate_restaurants(IN p_value integer, IN restaurant_address_ids uuid[], INOUT restaurant_ids uuid[]) TO inspector;


--
-- TOC entry 4988 (class 0 OID 0)
-- Dependencies: 253
-- Name: PROCEDURE generate_reviews(IN p_order_ids uuid[]); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.generate_reviews(IN p_order_ids uuid[]) TO inspector;


--
-- TOC entry 4989 (class 0 OID 0)
-- Dependencies: 258
-- Name: FUNCTION get_statistic(); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON FUNCTION buldakov_food.get_statistic() TO inspector;


--
-- TOC entry 4990 (class 0 OID 0)
-- Dependencies: 259
-- Name: PROCEDURE insert_test_data(IN value integer); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON PROCEDURE buldakov_food.insert_test_data(IN value integer) TO inspector;


--
-- TOC entry 4991 (class 0 OID 0)
-- Dependencies: 263
-- Name: FUNCTION rating_change(); Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON FUNCTION buldakov_food.rating_change() TO inspector;


--
-- TOC entry 4992 (class 0 OID 0)
-- Dependencies: 221
-- Name: TABLE address; Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON TABLE buldakov_food.address TO inspector;


--
-- TOC entry 4993 (class 0 OID 0)
-- Dependencies: 220
-- Name: TABLE client; Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON TABLE buldakov_food.client TO inspector;


--
-- TOC entry 4994 (class 0 OID 0)
-- Dependencies: 222
-- Name: TABLE client_address; Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON TABLE buldakov_food.client_address TO inspector;


--
-- TOC entry 4995 (class 0 OID 0)
-- Dependencies: 224
-- Name: TABLE courier; Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON TABLE buldakov_food.courier TO inspector;


--
-- TOC entry 4996 (class 0 OID 0)
-- Dependencies: 228
-- Name: TABLE courier_pay; Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON TABLE buldakov_food.courier_pay TO inspector;


--
-- TOC entry 4997 (class 0 OID 0)
-- Dependencies: 226
-- Name: TABLE "order"; Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON TABLE buldakov_food."order" TO inspector;


--
-- TOC entry 4998 (class 0 OID 0)
-- Dependencies: 231
-- Name: TABLE order_structure; Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON TABLE buldakov_food.order_structure TO inspector;


--
-- TOC entry 4999 (class 0 OID 0)
-- Dependencies: 230
-- Name: TABLE payment; Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON TABLE buldakov_food.payment TO inspector;


--
-- TOC entry 5000 (class 0 OID 0)
-- Dependencies: 227
-- Name: TABLE product; Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON TABLE buldakov_food.product TO inspector;


--
-- TOC entry 5001 (class 0 OID 0)
-- Dependencies: 225
-- Name: TABLE product_category; Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON TABLE buldakov_food.product_category TO inspector;


--
-- TOC entry 5002 (class 0 OID 0)
-- Dependencies: 223
-- Name: TABLE restaurant; Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON TABLE buldakov_food.restaurant TO inspector;


--
-- TOC entry 5003 (class 0 OID 0)
-- Dependencies: 229
-- Name: TABLE review; Type: ACL; Schema: buldakov_food; Owner: postgres
--

GRANT ALL ON TABLE buldakov_food.review TO inspector;


-- Completed on 2026-11-15 16:41:29

--
-- PostgreSQL database dump complete
--

