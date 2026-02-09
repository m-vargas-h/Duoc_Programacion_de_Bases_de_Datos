/*============================================================
ACTIVIDAD SUMATIVA 2:
DESARROLLANDO UN BLOQUE PL/SQL ANONIMO COMPLEJO

- Miguel Angel Vargas Huenul
============================================================*/

/*============================================================
CASO 1
============================================================*/

-- Definir variable bind
VAR b_anio NUMBER;
EXEC :b_anio := 2025;

DECLARE
    -- Tipos de transacción a procesar
    v_tipo1 CONSTANT VARCHAR2(40) := 'Avance en Efectivo';
    v_tipo2 CONSTANT VARCHAR2(40) := 'Súper Avance en Efectivo';

    -- Registro PL/SQL para detalle
    TYPE rec_det IS RECORD (
        numrun                  CLIENTE.numrun%TYPE,
        dvrun                   CLIENTE.dvrun%TYPE,
        nro_tarjeta             TARJETA_CLIENTE.nro_tarjeta%TYPE,
        nro_transaccion         TRANSACCION_TARJETA_CLIENTE.nro_transaccion%TYPE,
        fecha_transaccion       TRANSACCION_TARJETA_CLIENTE.fecha_transaccion%TYPE,
        tipo_transaccion        VARCHAR2(40),
        monto_total_transaccion TRANSACCION_TARJETA_CLIENTE.monto_total_transaccion%TYPE
    );
    rec_detalle rec_det;

    -- Variables auxiliares
    v_aporte_sbif    NUMBER(12);
    v_porc_aporte    NUMBER(5);
    v_contador       NUMBER := 0;
    v_expected_total NUMBER := 0;

    -- Excepción definida por usuario
    ex_iter_mismatch EXCEPTION;

    -- Cursor explícito para detalle
    CURSOR c_detalle IS
        SELECT
            c.numrun,
            c.dvrun,
            t.nro_tarjeta,
            tr.nro_transaccion,
            tr.fecha_transaccion,
            tt.nombre_tptran_tarjeta            AS tipo_transaccion,
            ROUND(tr.monto_total_transaccion,0) AS monto_total_transaccion
        FROM TRANSACCION_TARJETA_CLIENTE tr
        JOIN TARJETA_CLIENTE t ON tr.nro_tarjeta = t.nro_tarjeta
        JOIN CLIENTE c ON t.numrun = c.numrun
        JOIN TIPO_TRANSACCION_TARJETA tt ON tr.cod_tptran_tarjeta = tt.cod_tptran_tarjeta
        WHERE EXTRACT(YEAR FROM tr.fecha_transaccion) = :b_anio
            AND (tt.nombre_tptran_tarjeta = v_tipo1 OR tt.nombre_tptran_tarjeta = v_tipo2)
        ORDER BY 
            tr.fecha_transaccion ASC, 
            c.numrun ASC;

    -- Cursor explícito para resumen
    CURSOR c_resumen(p_anio NUMBER) IS
        SELECT
            TO_CHAR(tr.fecha_transaccion,'MMYYYY')      AS mes_anno,
            tt.nombre_tptran_tarjeta                    AS tipo_transaccion,
            ROUND(SUM(tr.monto_total_transaccion),0)    AS monto_total_transacciones
        FROM TRANSACCION_TARJETA_CLIENTE tr
        JOIN TIPO_TRANSACCION_TARJETA tt ON tr.cod_tptran_tarjeta = tt.cod_tptran_tarjeta
        WHERE EXTRACT(YEAR FROM tr.fecha_transaccion) = p_anio
            AND (tt.nombre_tptran_tarjeta = v_tipo1 OR tt.nombre_tptran_tarjeta = v_tipo2)
        GROUP BY 
            TO_CHAR(tr.fecha_transaccion,'MMYYYY'),
            tt.nombre_tptran_tarjeta
        ORDER BY 
            TO_CHAR(tr.fecha_transaccion,'MMYYYY') ASC,
            tt.nombre_tptran_tarjeta ASC;

BEGIN
    -- Truncar tablas destino 
    EXECUTE IMMEDIATE 'TRUNCATE TABLE DETALLE_APORTE_SBIF';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE RESUMEN_APORTE_SBIF';

    -- Obtener total esperado de transacciones a procesar
    SELECT COUNT(*) INTO v_expected_total
    FROM TRANSACCION_TARJETA_CLIENTE tr
    JOIN TIPO_TRANSACCION_TARJETA tt ON tr.cod_tptran_tarjeta = tt.cod_tptran_tarjeta
    WHERE EXTRACT(YEAR FROM tr.fecha_transaccion) = :b_anio
        AND (tt.nombre_tptran_tarjeta = v_tipo1 OR tt.nombre_tptran_tarjeta = v_tipo2);

    -- Inicializar contador
    v_contador := 0;

    -- Procesar detalle y calcular aporte por transacción
    FOR r IN c_detalle LOOP
        BEGIN
            -- Buscar porcentaje de aporte según tramo
            SELECT porc_aporte_sbif INTO v_porc_aporte
            FROM TRAMO_APORTE_SBIF
            WHERE r.monto_total_transaccion BETWEEN tramo_inf_av_sav AND tramo_sup_av_sav;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- Si no existe tramo, asignar 0%
                v_porc_aporte := 0;
        END;

        -- Calcular aporte 
        v_aporte_sbif := ROUND(
            r.monto_total_transaccion * v_porc_aporte / 100, 0
        );

        -- Insertar fila en DETALLE_APORTE_SBIF
        INSERT INTO DETALLE_APORTE_SBIF(
            numrun, 
            dvrun, 
            nro_tarjeta, 
            nro_transaccion, 
            fecha_transaccion,
            tipo_transaccion, 
            monto_transaccion, 
            aporte_sbif
        ) 
        VALUES (
            r.numrun, 
            r.dvrun, 
            r.nro_tarjeta, 
            r.nro_transaccion,
            r.fecha_transaccion, 
            r.tipo_transaccion,
            r.monto_total_transaccion, 
            v_aporte_sbif
        );

        -- Incrementar contador de iteraciones
        v_contador := v_contador + 1;
    END LOOP;

    -- Procesar resumen por mes y tipo calculando aporte total por transacción
    FOR r2 IN c_resumen(:b_anio) LOOP
        DECLARE
            v_aporte_mes NUMBER := 0;
        BEGIN
            -- Iterar transacciones del mes/tipo
            FOR tr_row IN (
                SELECT ROUND(tr.monto_total_transaccion,0) AS monto_total_transaccion
                FROM TRANSACCION_TARJETA_CLIENTE tr
                JOIN TIPO_TRANSACCION_TARJETA tt ON tr.cod_tptran_tarjeta = tt.cod_tptran_tarjeta
                WHERE TO_CHAR(tr.fecha_transaccion,'MMYYYY') = r2.mes_anno
                    AND tt.nombre_tptran_tarjeta = r2.tipo_transaccion
            ) LOOP
                BEGIN
                    -- Obtener porcentaje por tramo para cada transacción
                    SELECT porc_aporte_sbif INTO v_porc_aporte
                    FROM TRAMO_APORTE_SBIF
                    WHERE tr_row.monto_total_transaccion BETWEEN tramo_inf_av_sav AND tramo_sup_av_sav;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN v_porc_aporte := 0;
                END;

                -- Sumar aporte del mes
                v_aporte_mes := v_aporte_mes + ROUND(
                    tr_row.monto_total_transaccion * v_porc_aporte / 100, 0
                );
            END LOOP;

            -- Insertar resumen mensual en RESUMEN_APORTE_SBIF
            INSERT INTO RESUMEN_APORTE_SBIF(
                mes_anno, 
                tipo_transaccion, 
                monto_total_transacciones, 
                aporte_total_abif
            ) 
            VALUES (
                r2.mes_anno, 
                r2.tipo_transaccion, 
                r2.monto_total_transacciones,
                v_aporte_mes
            );
        END;
    END LOOP;

    -- Validar que se procesaron todas las transacciones esperadas
    IF v_contador != v_expected_total THEN RAISE ex_iter_mismatch;
    END IF;

    -- Confirmar cambios
    COMMIT;

    -- Mensaje final
    DBMS_OUTPUT.PUT_LINE('OK - Registros procesados: ' || v_contador);

EXCEPTION
    WHEN ex_iter_mismatch THEN
        -- Manejo de excepción
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(
            'ERROR - Discrepancia iteraciones. Procesados: ' || v_contador ||
            ' Esperados: ' || v_expected_total
        );
    WHEN OTHERS THEN
        -- Manejo de excepción no predefinida
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(
            'ERROR INESPERADO: ' || SQLCODE || ' - ' || SQLERRM
        );
END;
/

-- Consulta tablas finales
SELECT * FROM detalle_aporte_sbif;

SELECT * FROM resumen_aporte_sbif;
