/*============================================================
ACTIVIDAD FORMATIVA 4:
CREANDO PROCEDIMIENTOS Y FUNCIONES ALMACENADAS

Grupo 17:
- Miguel Angel Vargas Huenul
- 
============================================================*/

/* ============================================================
Procedimiento auxiliar: inserta registros en GASTO_COMUN_PAGO_CERO
============================================================ */
CREATE OR REPLACE PROCEDURE SP_INSERT_PAGO_CERO (
    p_periodo   NUMBER,      -- Ej: 202605 (año+mes)
    p_valor_uf  NUMBER       -- Ej: 29509
) AS
BEGIN
    -- Cursor para obtener departamentos sin pago en el período anterior
    FOR reg IN (
        SELECT 
            gc.anno_mes_pcgc,
            e.id_edif,
            e.nombre_edif,
            a.numrun_adm || '-' || a.dvrun_adm          AS run_adm,
            a.pnombre_adm || ' ' || a.appaterno_adm     AS nombre_adm,
            gc.nro_depto,
            r.numrun_rpgc || '-' || r.dvrun_rpgc        AS run_resp,
            r.pnombre_rpgc || ' ' || r.appaterno_rpgc   AS nombre_resp
        FROM   gasto_comun gc
        JOIN   edificio e ON gc.id_edif = e.id_edif
        JOIN   administrador a ON e.numrun_adm = a.numrun_adm
        JOIN   responsable_pago_gasto_comun r ON gc.numrun_rpgc = r.numrun_rpgc
        WHERE  gc.anno_mes_pcgc = TO_NUMBER(TO_CHAR(ADD_MONTHS(TO_DATE(p_periodo,'YYYYMM'), -1),'YYYYMM'))
            -- Filtra departamentos que no tienen ningún pago registrado en el período
            AND NOT EXISTS (
                SELECT 1
                FROM pago_gasto_comun pgc
                WHERE pgc.anno_mes_pcgc = gc.anno_mes_pcgc
                    AND pgc.id_edif = gc.id_edif
                    AND pgc.nro_depto = gc.nro_depto
            )
    ) LOOP
        -- Insertar registro en tabla de pago cero
        INSERT INTO gasto_comun_pago_cero (
            anno_mes_pcgc, 
            id_edif, 
            nombre_edif,
            run_administrador, 
            nombre_admnistrador,
            nro_depto, 
            run_responsable_pago_gc,
            nombre_responsable_pago_gc,
            valor_multa_pago_cero, 
            observacion
        ) 
        VALUES (
            p_periodo, 
            reg.id_edif, 
            reg.nombre_edif,
            reg.run_adm, 
            reg.nombre_adm,
            reg.nro_depto, 
            reg.run_resp,
            reg.nombre_resp,
            2 * p_valor_uf, -- multa inicial (2 UF)
            'Aviso de corte de agua y combustible'
        );
    END LOOP;

    COMMIT;
END;
/

/* ============================================================
Procedimiento principal: genera multas y actualiza GASTO_COMUN
============================================================ */
CREATE OR REPLACE PROCEDURE SP_PROC_MULTAS (
    p_periodo   NUMBER,   -- por ejemplo: 202605 (año+mes)
    p_valor_uf  NUMBER    -- por ejemplo: 29509
) AS
    v_multa NUMBER;
BEGIN
    -- Cursor para departamentos sin pago en los últimos dos períodos
    FOR reg IN (
        SELECT 
            gc.id_edif, gc.nro_depto,
            COUNT(*)                    AS meses_atraso
        FROM   gasto_comun gc
        LEFT JOIN pago_gasto_comun pgc ON gc.anno_mes_pcgc = pgc.anno_mes_pcgc
            AND gc.id_edif = pgc.id_edif
            AND gc.nro_depto = pgc.nro_depto
        WHERE  gc.anno_mes_pcgc IN (
                   TO_NUMBER(TO_CHAR(ADD_MONTHS(TO_DATE(p_periodo,'YYYYMM'), -1),'YYYYMM')),
                   TO_NUMBER(TO_CHAR(ADD_MONTHS(TO_DATE(p_periodo,'YYYYMM'), -2),'YYYYMM'))
               )
            AND pgc.anno_mes_pcgc IS NULL
        GROUP BY 
            gc.id_edif, 
            gc.nro_depto
    ) LOOP
        -- Determinar multa según meses de atraso
        IF reg.meses_atraso = 1 THEN
            v_multa := 2 * p_valor_uf;
        ELSE
            v_multa := 4 * p_valor_uf;
        END IF;

        -- Actualizar multa en GASTO_COMUN
        UPDATE gasto_comun
        SET multa_gc = v_multa
        WHERE anno_mes_pcgc = p_periodo
            AND id_edif = reg.id_edif
            AND nro_depto = reg.nro_depto;

        -- Insertar detalle en tabla auxiliar
        INSERT INTO gasto_comun_pago_cero (
            anno_mes_pcgc, 
            id_edif, nombre_edif,
            run_administrador,
            nombre_admnistrador,
            nro_depto, 
            run_responsable_pago_gc,
            nombre_responsable_pago_gc,
            valor_multa_pago_cero, 
            observacion
        )
        SELECT 
            p_periodo, 
            e.id_edif, 
            e.nombre_edif,
            a.numrun_adm || '-' || a.dvrun_adm,
            a.pnombre_adm || ' ' || a.appaterno_adm,
            d.nro_depto,
            r.numrun_rpgc || '-' || r.dvrun_rpgc,
            r.pnombre_rpgc || ' ' || r.appaterno_rpgc,
            v_multa,
            CASE WHEN reg.meses_atraso = 1
                THEN 'Aviso de corte de agua y combustible'
                ELSE 'Corte programado en fecha de pago actual'
            END
        FROM   edificio e
        JOIN   administrador a ON e.numrun_adm = a.numrun_adm
        JOIN   departamento d ON e.id_edif = d.id_edif
        JOIN   responsable_pago_gasto_comun r
            -- Obtiene el RUN del responsable de pago para el período y depto actual
            ON r.numrun_rpgc = (
                SELECT numrun_rpgc
                FROM   gasto_comun
                WHERE  anno_mes_pcgc = p_periodo
                   AND id_edif = reg.id_edif
                   AND nro_depto = reg.nro_depto
            )
        WHERE  d.id_edif = reg.id_edif
            AND d.nro_depto = reg.nro_depto;
    END LOOP;

    COMMIT;
END;
/

-- Simulación para mayo del año actual con UF = 29.509
BEGIN
    SP_PROC_MULTAS(202605, 29509);
END;
/

-- Muestra todos los registros de la tabla GASTO_COMUN_PAGO_CERO
SELECT * FROM gasto_comun_pago_cero
ORDER BY 
    nombre_edif, 
    nro_depto;

-- Departamentos con pago cero según instrucciones específicas
SELECT 
    gc.anno_mes_pcgc,
    gc.id_edif,
    gc.nro_depto,
    gc.fecha_desde_gc,
    gc.fecha_hasta_gc,
    gc.multa_gc
FROM gasto_comun gc
JOIN gasto_comun_pago_cero gcp0 ON gc.anno_mes_pcgc = gcp0.anno_mes_pcgc
   AND gc.id_edif = gcp0.id_edif
   AND gc.nro_depto = gcp0.nro_depto
ORDER BY 
    gc.id_edif, 
    gc.nro_depto;
