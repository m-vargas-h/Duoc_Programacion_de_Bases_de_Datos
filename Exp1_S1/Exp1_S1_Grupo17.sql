/*============================================================
ACTIVIDAD FORMATIVA 1:
MI PRIMER BLOQUE PL/SQL ANONIMO SIMPLE

Grupo 17:
- Miguel Angel Vargas Huenul
- 
============================================================*/

/*============================================================
CASO 1
============================================================*/

-- Variables Bind
VAR b_run NUMBER;
VAR b_dv VARCHAR2(1);
VAR b_pesos_normales NUMBER;
VAR b_pesos_extra1 NUMBER;
VAR b_pesos_extra2 NUMBER;
VAR b_pesos_extra3 NUMBER;
VAR b_tramo1_limite NUMBER;
VAR b_tramo2_limite NUMBER;

-- KAREN SOFIA PRADENAS MANDIOLA
--EXEC :b_run := 21242003;
--EXEC :b_dv := '4';

-- SILVANA MARTINA VALENZUELA DUARTE
--EXEC :b_run := 22176845;
--EXEC :b_dv := '2';

-- DENISSE ALICIA DIAZ MIRANDA
--EXEC :b_run := 18858542;
--EXEC :b_dv := '6';

-- AMANDA ROMINA LIZANA MARAMBIO
--EXEC :b_run := 22558061;
--EXEC :b_dv := '8';

-- LUIS CLAUDIO LUNA JORQUERA
EXEC :b_run := 21300628;
EXEC :b_dv := '2';

-- Valores pesos normales y extra
EXEC :b_pesos_normales := 1200;
EXEC :b_pesos_extra1 := 100;
EXEC :b_pesos_extra2 := 300;
EXEC :b_pesos_extra3 := 550;

-- Valores para los tramos de montos solicitados
EXEC :b_tramo1_limite := 1000000;
EXEC :b_tramo2_limite := 3000000;

DECLARE
    -- Variables para datos del cliente
    v_nro_cliente       NUMBER(5,0);
    v_numrun            NUMBER(10);
    v_dvrun             VARCHAR2(1);
    v_nombre_cliente    VARCHAR2(200);
    v_tipo_cliente      VARCHAR2(30);

    -- Variables para cálculos
    v_monto_total       NUMBER(10,0);
    v_pesos_normales    NUMBER(8,0) := 0;
    v_pesos_extras      NUMBER(8,0) := 0;
    v_pesos_final       NUMBER(8,0) := 0;
    
BEGIN
    -- Recuperar datos del cliente desde la tabla CLIENTE
    SELECT
        c.nro_cliente,
        c.numrun,
        c.dvrun,
        -- se considera la posibilidad de que no se registre segundo nombre o apellido materno
        c.pnombre || ' ' || NVL(c.snombre,'') || ' ' || c.appaterno || ' ' || NVL(c.apmaterno,''),
        t.nombre_tipo_cliente
    INTO v_nro_cliente, v_numrun, v_dvrun, v_nombre_cliente, v_tipo_cliente
    FROM cliente c
    JOIN tipo_cliente t
        ON c.cod_tipo_cliente = t.cod_tipo_cliente
    WHERE c.numrun = :b_run;

    -- Recuperar suma de montos solicitados del año anterior
    SELECT NVL(SUM(monto_solicitado),0)
    INTO v_monto_total
    FROM credito_cliente
    WHERE nro_cliente = v_nro_cliente
        AND EXTRACT(YEAR FROM fecha_solic_cred) = EXTRACT(YEAR FROM SYSDATE) - 1;


    -- Calcular pesos normales
    v_pesos_normales := (v_monto_total / 100000) * :b_pesos_normales;

    -- Calcular pesos extras según tramo
    IF v_monto_total < :b_tramo1_limite THEN
        v_pesos_extras := (v_monto_total / 100000) * :b_pesos_extra1;
    ELSIF v_monto_total BETWEEN (:b_tramo1_limite + 1) AND :b_tramo2_limite THEN
        v_pesos_extras := (v_monto_total / 100000) * :b_pesos_extra2;
    ELSE
        v_pesos_extras := (v_monto_total / 100000) * :b_pesos_extra3;
    END IF;

    -- Total final
    v_pesos_final := v_pesos_normales + v_pesos_extras;

    -- Insertar resultado en CLIENTE_TODOSUMA
    INSERT INTO cliente_todosuma(
        nro_cliente,
        run_cliente,
        nombre_cliente,
        tipo_cliente,
        monto_solic_creditos,
        monto_pesos_todosuma
    )
    VALUES (
        v_nro_cliente,
        -- Formatea el run de forma 12.123.456 y concatena con el digito verificador
        REGEXP_REPLACE(LPAD(TO_CHAR(v_numrun), 8, '0'),
               '([0-9]{1,2})([0-9]{3})([0-9]{3})', '\1.\2.\3') || '-' || v_dvrun,
        v_nombre_cliente,
        v_tipo_cliente,
        v_monto_total,
        v_pesos_final
    );

    -- Mostrar salida en consola con nombre de cliente y total de puntos
    DBMS_OUTPUT.PUT_LINE('Cliente: ' || v_nombre_cliente);
    DBMS_OUTPUT.PUT_LINE('Pesos TODOSUMA: ' || v_pesos_final);
END;
/

-- Select para revisar los datos ingresados en la tabla
SELECT * FROM cliente_todosuma;

/*============================================================
CASO 2
============================================================*/

-- Variables bind
VAR b_nro_cliente NUMBER;
VAR b_nro_sol_credito NUMBER;
VAR b_cant_cuotas NUMBER;

-- SEBASTIAN PATRICIO QUINTANA BERRIOS
--EXEC :b_nro_cliente := 5;
--EXEC :b_nro_sol_credito := 2001;
--EXEC :b_cant_cuotas := 2;

-- KAREN SOFIA PRADENAS MANDIOLA
--EXEC :b_nro_cliente := 67;
--EXEC :b_nro_sol_credito := 3004;
--EXEC :b_cant_cuotas := 1;

-- JULIAN PAUL ARRIAGADA LUJAN
EXEC :b_nro_cliente := 13;
EXEC :b_nro_sol_credito := 2004;
EXEC :b_cant_cuotas := 1;

DECLARE
    -- Variables para datos del crédito
    v_cod_credito        NUMBER(3);     
    v_ultima_cuota       NUMBER(3);     
    v_fecha_venc_ultima  DATE;          
    v_valor_cuota        NUMBER(10,2);  

    -- Variables para cálculos
    v_nueva_cuota        NUMBER(3);     
    v_nuevo_valor        NUMBER(10,2);  

    -- Variable para verificar créditos del año anterior
    v_cant_creditos      NUMBER;
    
BEGIN
    -- Recuperar tipo de crédito y datos de la última cuota
    SELECT
        c.cod_credito,
        MAX(q.nro_cuota),
        MAX(q.fecha_venc_cuota),
        MAX(q.valor_cuota)
    INTO v_cod_credito, v_ultima_cuota, v_fecha_venc_ultima, v_valor_cuota
    FROM credito_cliente c
    JOIN cuota_credito_cliente q
        ON c.nro_solic_credito = q.nro_solic_credito
    WHERE c.nro_cliente = :b_nro_cliente
        AND c.nro_solic_credito = :b_nro_sol_credito
    GROUP BY c.cod_credito;

    -- Generar nuevas cuotas según tipo de crédito y cantidad solicitada
    FOR v_i IN 1..:b_cant_cuotas LOOP
        v_nueva_cuota := v_ultima_cuota + v_i;

        -- Calcular fecha de vencimiento: mes siguiente(s) a la última cuota
        v_fecha_venc_ultima := ADD_MONTHS(v_fecha_venc_ultima, 1);

        -- Calcular valor de la nueva cuota según tipo de crédito
        IF v_cod_credito = 1 THEN
            -- Crédito hipotecario
            IF :b_cant_cuotas = 1 THEN
                v_nuevo_valor := v_valor_cuota; -- sin interés
            ELSE
                v_nuevo_valor := v_valor_cuota * 1.005; -- 0.5% interés
            END IF;
        ELSIF v_cod_credito = 2 THEN
            -- Crédito de consumo
            v_nuevo_valor := v_valor_cuota * 1.01; -- 1% interés
        ELSIF v_cod_credito = 3 THEN
            -- Crédito automotriz
            v_nuevo_valor := v_valor_cuota * 1.02; -- 2% interés
        ELSE
            -- Otros créditos: sin interés adicional
            v_nuevo_valor := v_valor_cuota;
        END IF;

        -- Insertar nueva cuota en la tabla
        INSERT INTO cuota_credito_cliente(
            nro_solic_credito,
            nro_cuota,
            fecha_venc_cuota,
            valor_cuota,
            fecha_pago_cuota,
            monto_pagado,
            saldo_por_pagar,
            cod_forma_pago
        )
        VALUES (
            :b_nro_sol_credito,
            v_nueva_cuota,
            v_fecha_venc_ultima,
            v_nuevo_valor,
            NULL,   -- fecha de pago
            NULL,   -- monto pagado
            NULL,   -- saldo por pagar
            NULL    -- forma de pago
        );
    END LOOP;

    -- Verificar si el cliente tuvo mas de un credito el año anterior
    -- Si es así, marcar la última cuota original como pagada
    SELECT COUNT(*)
    INTO v_cant_creditos
    FROM credito_cliente
    WHERE nro_cliente = :b_nro_cliente
        AND EXTRACT(YEAR FROM fecha_solic_cred) = EXTRACT(YEAR FROM SYSDATE) - 1;

    IF v_cant_creditos > 1 THEN
        UPDATE cuota_credito_cliente
        SET monto_pagado = valor_cuota,
            fecha_pago_cuota = fecha_venc_cuota,
            saldo_por_pagar = 0,
            cod_forma_pago = NULL
        WHERE nro_solic_credito = :b_nro_sol_credito
          AND nro_cuota = v_ultima_cuota;
    END IF;

    -- Mostrar salida en consola
    DBMS_OUTPUT.PUT_LINE('Cliente: ' || :b_nro_cliente || ' - Crédito: ' || :b_nro_sol_credito);
    DBMS_OUTPUT.PUT_LINE('Se postergaron ' || :b_cant_cuotas || ' cuota(s).');
END;
/

-- Select con sustitucion para verificar las nuevas cuotas del credito
SELECT * FROM cuota_credito_cliente
    WHERE nro_solic_credito = &nro_solic_credito
ORDER BY nro_cuota;