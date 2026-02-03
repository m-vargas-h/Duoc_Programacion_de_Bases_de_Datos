/*============================================================
ACTIVIDAD FORMATIVA 3:
USANDO CURSORES EXPLÍCITOS COMPLEJOS PARA PROCESAR INFORMACIÓN MASIVA

GRUPO 17:
- Miguel Angel Vargas Huenul
- 
============================================================*/

/*============================================================
CASO 1 
============================================================*/

-- Definir variable bind para año anterior
VAR b_annio NUMBER;
EXEC :b_annio := (EXTRACT(YEAR FROM SYSDATE)) - 1;

DECLARE
    -- Cursor explícito con parámetro para obtener detalle de transacciones
    CURSOR cr_transacciones(p_annio NUMBER) IS
        SELECT 
            c.numrun, 
            c.dvrun, 
            t.nro_tarjeta, 
            tr.nro_transaccion,
            tr.fecha_transaccion, 
            tp.nombre_tptran_tarjeta AS tipo_transaccion,
            tr.monto_transaccion
        FROM cliente c
        INNER JOIN tarjeta_cliente t ON c.numrun = t.numrun
        INNER JOIN transaccion_tarjeta_cliente tr ON t.nro_tarjeta = tr.nro_tarjeta
        INNER JOIN tipo_transaccion_tarjeta tp ON tr.cod_tptran_tarjeta = tp.cod_tptran_tarjeta
        WHERE EXTRACT(YEAR FROM tr.fecha_transaccion) = p_annio
        ORDER BY 
            tr.fecha_transaccion, 
            c.numrun, 
            tr.nro_transaccion;

    -- Variable de cursor: resumen mensual de transacciones
    TYPE tp_cur_resumen IS REF CURSOR;
    v_cur_resumen tp_cur_resumen;

    -- VARRAY con valores de puntos normales y extras
    TYPE tp_varray_puntos IS VARRAY(4) OF NUMBER;
    var_puntos tp_varray_puntos := tp_varray_puntos(250, 300, 550, 700);

    --  Registro para cálculos de puntos
    TYPE tp_registro_puntos IS RECORD (
        puntos_normales NUMBER,
        puntos_extras   NUMBER,
        puntos_finales  NUMBER
    );
    rec_puntos tp_registro_puntos;

    -- Variables para resumen mensual
    v_mes_anno VARCHAR2(6);
    v_monto_compras NUMBER;
    v_puntos_compras NUMBER;
    v_monto_avances NUMBER;
    v_puntos_avances NUMBER;
    v_monto_savances NUMBER;
    v_puntos_savances NUMBER;

BEGIN
    -- Limpiar tablas antes de insertar
    EXECUTE IMMEDIATE 'TRUNCATE TABLE DETALLE_PUNTOS_TARJETA_CATB';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE RESUMEN_PUNTOS_TARJETA_CATB';

    -- Procesar detalle de transacciones
    FOR reg IN cr_transacciones(:b_annio) LOOP
        -- Calcular puntos normales
        rec_puntos.puntos_normales := (reg.monto_transaccion / 100000) * var_puntos(1);

        -- Inicializar puntos extras
        rec_puntos.puntos_extras := 0;

        -- Aplicar puntos extras según monto
        IF reg.tipo_transaccion IN ('Compras Tiendas Retail o Asociadas', 
                                    'Avance en Efectivo', 
                                    'Súper Avance en Efectivo') THEN
            IF reg.monto_transaccion BETWEEN 500000 AND 700000 THEN
                rec_puntos.puntos_extras := (reg.monto_transaccion / 100000) * var_puntos(2);
            ELSIF reg.monto_transaccion BETWEEN 700001 AND 900000 THEN
                rec_puntos.puntos_extras := (reg.monto_transaccion / 100000) * var_puntos(3);
            ELSIF reg.monto_transaccion > 900000 THEN
                rec_puntos.puntos_extras := (reg.monto_transaccion / 100000) * var_puntos(4);
            END IF;
        END IF;

        -- Puntos finales
        rec_puntos.puntos_finales := rec_puntos.puntos_normales + rec_puntos.puntos_extras;

        -- Insertar en tabla detalle
        INSERT INTO DETALLE_PUNTOS_TARJETA_CATB
        VALUES (
            reg.numrun, 
            reg.dvrun, 
            reg.nro_tarjeta,
            reg.nro_transaccion, 
            reg.fecha_transaccion,
            reg.tipo_transaccion, 
            reg.monto_transaccion,
            rec_puntos.puntos_finales
            );
            
    END LOOP;

    -- Procesar resumen mensual
    OPEN v_cur_resumen FOR
        SELECT 
            TO_CHAR(tr.fecha_transaccion, 'MMYYYY') AS mes_anno,
            SUM(CASE WHEN tp.nombre_tptran_tarjeta = 'Compras Tiendas Retail o Asociadas' 
                THEN tr.monto_transaccion ELSE 0 END),
            SUM(CASE WHEN tp.nombre_tptran_tarjeta = 'Compras Tiendas Retail o Asociadas' 
                THEN (tr.monto_transaccion/100000)*var_puntos(1) ELSE 0 END),
            SUM(CASE WHEN tp.nombre_tptran_tarjeta = 'Avance en Efectivo' 
                THEN tr.monto_transaccion ELSE 0 END),
            SUM(CASE WHEN tp.nombre_tptran_tarjeta = 'Avance en Efectivo' 
                THEN (tr.monto_transaccion/100000)*var_puntos(1) ELSE 0 END),
            SUM(CASE WHEN tp.nombre_tptran_tarjeta = 'Súper Avance en Efectivo' 
                THEN tr.monto_transaccion ELSE 0 END),
            SUM(CASE WHEN tp.nombre_tptran_tarjeta = 'Súper Avance en Efectivo' 
                THEN (tr.monto_transaccion/100000)*var_puntos(1) ELSE 0 END)
        FROM transaccion_tarjeta_cliente tr
        INNER JOIN tipo_transaccion_tarjeta tp ON tr.cod_tptran_tarjeta = tp.cod_tptran_tarjeta
        WHERE EXTRACT(YEAR FROM tr.fecha_transaccion) = :b_annio
        GROUP BY 
            TO_CHAR(tr.fecha_transaccion, 'MMYYYY')
        ORDER BY 
            TO_CHAR(tr.fecha_transaccion, 'MMYYYY');

    LOOP
        FETCH v_cur_resumen INTO v_mes_anno,
            v_monto_compras, v_puntos_compras,
            v_monto_avances, v_puntos_avances,
            v_monto_savances, v_puntos_savances;

        EXIT WHEN v_cur_resumen%NOTFOUND;

        INSERT INTO RESUMEN_PUNTOS_TARJETA_CATB
        VALUES (
            v_mes_anno,
            v_monto_compras, 
            v_puntos_compras,
            v_monto_avances, 
            v_puntos_avances,
            v_monto_savances, 
            v_puntos_savances
            );
            
    END LOOP;

    CLOSE v_cur_resumen;

    COMMIT; -- Confirmar transacciones
END;
/

-- Verificar resultados del detalle de puntos acumulados
SELECT * FROM DETALLE_PUNTOS_TARJETA_CATB;

-- Verificar resultados del resumen mensual de puntos acumulados
SELECT * FROM RESUMEN_PUNTOS_TARJETA_CATB;

/*============================================================
CASO 2
============================================================*/

-- Definir variable bind para año actual
VAR b_annio NUMBER;
EXEC :b_annio := EXTRACT(YEAR FROM SYSDATE);

DECLARE
    /*
      Cursor explícito DETALLE con parámetro, obtiene todas las transacciones de avances y 
      súper avances del año actual
    */
    CURSOR cr_detalle(p_annio NUMBER) IS
        SELECT 
            c.numrun, 
            c.dvrun, 
            t.nro_tarjeta, 
            tr.nro_transaccion,
            tr.fecha_transaccion, 
            tp.nombre_tptran_tarjeta AS tipo_transaccion,
            tr.monto_total_transaccion
        FROM cliente c
        INNER JOIN tarjeta_cliente t ON c.numrun = t.numrun
        INNER JOIN transaccion_tarjeta_cliente tr ON t.nro_tarjeta = tr.nro_tarjeta
        INNER JOIN tipo_transaccion_tarjeta tp ON tr.cod_tptran_tarjeta = tp.cod_tptran_tarjeta
        WHERE EXTRACT(YEAR FROM tr.fecha_transaccion) = p_annio
            AND tp.nombre_tptran_tarjeta LIKE '%Avance%'
        ORDER BY 
            tr.fecha_transaccion, 
            c.numrun;

    --  Cursor explícito RESUMEN con parámetro, agrupa por mes y tipo de transacción
    CURSOR cr_resumen(p_annio NUMBER) IS
        SELECT 
        TO_CHAR(tr.fecha_transaccion, 'MMYYYY') AS mes_anno,
        tp.nombre_tptran_tarjeta                AS tipo_transaccion,
        SUM(tr.monto_total_transaccion)         AS monto_total
        FROM transaccion_tarjeta_cliente tr
        INNER JOIN tipo_transaccion_tarjeta tp ON tr.cod_tptran_tarjeta = tp.cod_tptran_tarjeta
        WHERE EXTRACT(YEAR FROM tr.fecha_transaccion) = p_annio
            AND tp.nombre_tptran_tarjeta LIKE '%Avance%'
        GROUP BY 
            TO_CHAR(tr.fecha_transaccion, 'MMYYYY'), 
            tp.nombre_tptran_tarjeta
        ORDER BY 
            TO_CHAR(tr.fecha_transaccion, 'MMYYYY'), 
            tp.nombre_tptran_tarjeta;

    -- Registro PL/SQL para cálculo de aporte
    TYPE tp_registro_aporte IS RECORD (
        porcentaje NUMBER,
        aporte     NUMBER
    );
    rec_aporte tp_registro_aporte;

BEGIN
    -- Limpiar tablas antes de insertar
    EXECUTE IMMEDIATE 'TRUNCATE TABLE DETALLE_APORTE_SBIF';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE RESUMEN_APORTE_SBIF';

    -- Procesar detalle de transacciones
    FOR reg IN cr_detalle(:b_annio) LOOP
        -- Buscar porcentaje de aporte según tramo
        SELECT porc_aporte_sbif
        INTO rec_aporte.porcentaje
        FROM tramo_aporte_sbif
        WHERE reg.monto_total_transaccion BETWEEN tramo_inf_av_sav AND tramo_sup_av_sav;

        -- Calcular aporte
        rec_aporte.aporte := ROUND(reg.monto_total_transaccion * rec_aporte.porcentaje / 100);

        -- Insertar en tabla detalle
        INSERT INTO DETALLE_APORTE_SBIF (
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
            reg.numrun, 
            reg.dvrun, 
            reg.nro_tarjeta, 
            reg.nro_transaccion,
            reg.fecha_transaccion, 
            reg.tipo_transaccion,
            reg.monto_total_transaccion, 
            rec_aporte.aporte
        );
    END LOOP;

    -- Procesar resumen mensual
    FOR reg_res IN cr_resumen(:b_annio) LOOP
        -- Buscar porcentaje de aporte según tramo
        SELECT porc_aporte_sbif
        INTO rec_aporte.porcentaje
        FROM tramo_aporte_sbif
        WHERE reg_res.monto_total BETWEEN tramo_inf_av_sav AND tramo_sup_av_sav;

        -- Calcular aporte total
        rec_aporte.aporte := ROUND(reg_res.monto_total * rec_aporte.porcentaje / 100);

        -- Insertar en tabla resumen
        INSERT INTO RESUMEN_APORTE_SBIF (
            mes_anno, 
            tipo_transaccion, 
            monto_total_transacciones, 
            aporte_total_abif
        )
        VALUES (
            reg_res.mes_anno, 
            reg_res.tipo_transaccion,
            reg_res.monto_total, 
            rec_aporte.aporte
        );
    END LOOP;

    -- Confirmar transacciones
    COMMIT; 
END;
/

-- Verificar resultados del detalle de aportes SBIF
SELECT * FROM DETALLE_APORTE_SBIF 
ORDER BY fecha_transaccion;

-- Verificar resultados del resumen mensual de aportes SBIF
SELECT * FROM RESUMEN_APORTE_SBIF 
ORDER BY mes_anno, tipo_transaccion;
