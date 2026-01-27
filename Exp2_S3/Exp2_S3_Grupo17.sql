/*============================================================
ACTIVIDAD FORMATIVA 2:

GRUPO 17:
- Miguel Angel Vargas Huenul
- 
============================================================*/

/*============================================================
CASO 1
============================================================*/
-- Declaración variables bind
VAR b_anio NUMBER;

-- Asignación valor variables bind
EXEC :b_anio := 2025;

DECLARE
    -- Definición de VARRAY con los valores de multa por especialidad
    TYPE t_multas IS VARRAY(7) OF NUMBER;
    v_multas t_multas := t_multas(1200, 1300, 1700, 1900, 1100, 2000, 2300);

    -- RECORD para almacenar los datos obtenidos desde el cursor
    TYPE t_pago IS RECORD (
        pac_run PACIENTE.pac_run%TYPE,
        dv_run PACIENTE.dv_run%TYPE,
        nombre VARCHAR2(100),
        ate_id ATENCION.ate_id%TYPE,
        fecha_venc DATE,
        fecha_pago DATE,
        especialidad VARCHAR2(40),
        fecha_nac DATE
    );
    v_pago t_pago;

    -- Variables auxiliares para cálculos
    v_dias NUMBER;
    v_multa NUMBER;
    v_desc NUMBER;
    v_edad NUMBER;
    v_contador NUMBER := 0;

    /*
    CURSOR EXPLÍCITO: obtiene todas las atenciones con pago atrasado, incluye nombre completo del 
    paciente y ordena por fecha de vencimiento y apellido paterno
    */
    CURSOR c_todos_pagos IS
        SELECT 
            p.pac_run, 
            p.dv_run, 
            p.pnombre || ' ' || p.snombre || ' ' || p.apaterno || ' ' || p.amaterno AS nombre,
            pa.ate_id, 
            pa.fecha_venc_pago, 
            pa.fecha_pago,
            e.nombre AS especialidad, 
            p.fecha_nacimiento
        FROM PACIENTE p
        JOIN ATENCION a ON p.pac_run = a.pac_run
        JOIN PAGO_ATENCION pa ON a.ate_id = pa.ate_id
        JOIN ESPECIALIDAD e ON a.esp_id = e.esp_id
        WHERE pa.fecha_pago IS NOT NULL
            AND pa.fecha_pago > pa.fecha_venc_pago
        ORDER BY pa.fecha_venc_pago, p.apaterno;

BEGIN
    -- Mensaje informativo en consola
    DBMS_OUTPUT.PUT_LINE('Procesando año: ' || :b_anio);
    DBMS_OUTPUT.PUT_LINE('Pagos del año: ' || (:b_anio - 1));

    -- TRUNCAR la tabla PAGO_MOROSO antes de insertar nuevos registros
    EXECUTE IMMEDIATE 'TRUNCATE TABLE PAGO_MOROSO';

    -- Abrir cursor y recorrer cada registro
    OPEN c_todos_pagos;

    LOOP
        FETCH c_todos_pagos INTO v_pago;
        EXIT WHEN c_todos_pagos%NOTFOUND;

        -- Filtrar solo pagos correspondientes al año anterior (variable bind)
        IF EXTRACT(YEAR FROM v_pago.fecha_pago) != (:b_anio - 1) THEN
            CONTINUE;
        END IF;

        v_contador := v_contador + 1;

        -- Calcular días de morosidad (diferencia entre pago y vencimiento)
        v_dias := v_pago.fecha_pago - v_pago.fecha_venc;
        IF v_dias <= 0 THEN
            CONTINUE;
        END IF;

        /*
        Determinar multa según especialidad usando estructuras condicionales, cada grupo de 
        especialidades se asocia a un índice del VARRAY
        */
        IF v_pago.especialidad IN ('Cirugía General','Dermatología') THEN
            v_multa := v_dias * v_multas(1);
        ELSIF v_pago.especialidad = 'Ortopedia y Traumatología' THEN
            v_multa := v_dias * v_multas(2);
        ELSIF v_pago.especialidad IN ('Inmunología','Otorrinolaringología') THEN
            v_multa := v_dias * v_multas(3);
        ELSIF v_pago.especialidad IN ('Fisiatría','Medicina Interna') THEN
            v_multa := v_dias * v_multas(4);
        ELSIF v_pago.especialidad = 'Medicina General' THEN
            v_multa := v_dias * v_multas(5);
        ELSIF v_pago.especialidad = 'Psiquiatría Adultos' THEN
            v_multa := v_dias * v_multas(6);
        ELSIF v_pago.especialidad IN ('Cirugía Digestiva','Reumatología') THEN
            v_multa := v_dias * v_multas(7);
        ELSE
            v_multa := v_dias * 1000;
        END IF;

        -- Calcular edad del paciente y aplicar descuento tercera edad
        v_desc := 0;
        v_edad := TRUNC(MONTHS_BETWEEN(v_pago.fecha_pago, v_pago.fecha_nac) / 12);

        BEGIN
            SELECT porcentaje_descto INTO v_desc
            FROM PORC_DESCTO_3RA_EDAD
            WHERE v_edad BETWEEN anno_ini AND anno_ter;

            v_multa := v_multa - (v_multa * v_desc / 100);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;

        -- Insertar resultado en la tabla PAGO_MOROSO
        INSERT INTO PAGO_MOROSO (
            pac_run, 
            pac_dv_run, 
            pac_nombre,
            ate_id, 
            fecha_venc_pago, 
            fecha_pago,
            dias_morosidad, 
            especialidad_atencion, 
            monto_multa
        ) VALUES (
            v_pago.pac_run, 
            v_pago.dv_run, 
            v_pago.nombre,
            v_pago.ate_id, 
            TO_DATE(TO_CHAR(v_pago.fecha_venc,'DD/MM/YYYY'),'DD/MM/YYYY'),
            TO_DATE(TO_CHAR(v_pago.fecha_pago,'DD/MM/YYYY'),'DD/MM/YYYY'),
            v_dias, 
            v_pago.especialidad, 
            ROUND(v_multa, 0)
        );

    END LOOP;

    CLOSE c_todos_pagos;
    COMMIT;

    -- Mensaje final con cantidad de registros procesados
    DBMS_OUTPUT.PUT_LINE('Proceso completado. Registros: ' || v_contador);
END;
/

-- Revision tabla resultante
select * from pago_moroso;

/*============================================================
CASO 2
============================================================*/
VAR b_anio NUMBER;
EXEC :b_anio := 2026;

DECLARE
    -- VARRAY con las posibles destinaciones
    TYPE t_destinaciones IS VARRAY(3) OF VARCHAR2(50);
    v_destinos t_destinaciones := t_destinaciones(
        'Servicio de Atención Primaria de Urgencia (SAPU)',
        'Centros de Salud Familiar (CESFAM)',
        'Hospitales del área de la Salud Pública'
    );

    -- RECORD para almacenar datos del cursor
    TYPE t_medico IS RECORD (
        med_run MEDICO.med_run%TYPE,
        dv_run MEDICO.dv_run%TYPE,
        nombre VARCHAR2(50),
        apaterno VARCHAR2(15),
        uni_nombre VARCHAR2(40),
        total_atenciones NUMBER
    );
    v_medico t_medico;

    -- Variables auxiliares
    v_destinacion VARCHAR2(50);
    v_correo VARCHAR2(25);
    v_contador NUMBER := 0;

    -- CURSOR: obtiene médicos y total de atenciones del año anterior
    CURSOR c_medicos IS
        SELECT 
            m.med_run,
            m.dv_run,
            m.pnombre || ' ' || m.snombre || ' ' || m.apaterno || ' ' || m.amaterno AS nombre,
            m.apaterno,
            u.nombre AS uni_nombre,
            NVL((SELECT COUNT(*) FROM ATENCION a
                WHERE a.med_run = m.med_run
                    AND EXTRACT(YEAR FROM a.fecha_atencion) = (:b_anio - 1)),0) AS total_atenciones
        FROM MEDICO m
        JOIN UNIDAD u ON m.uni_id = u.uni_id
        ORDER BY 
            u.nombre, 
            m.apaterno;

BEGIN
    DBMS_OUTPUT.PUT_LINE('Procesando año: ' || :b_anio);
    DBMS_OUTPUT.PUT_LINE('Atenciones del año: ' || (:b_anio - 1));

    -- Limpiar tabla antes de insertar
    EXECUTE IMMEDIATE 'TRUNCATE TABLE MEDICO_SERVICIO_COMUNIDAD';

    OPEN c_medicos;

    LOOP
        FETCH c_medicos INTO v_medico;
        EXIT WHEN c_medicos%NOTFOUND;

        v_contador := v_contador + 1;

        -- Determinar destinación según unidad y cantidad de atenciones
        IF v_medico.uni_nombre IN ('ATENCIÓN AMBULATORIA','ATENCIÓN ADULTO') THEN
            v_destinacion := v_destinos(1); -- SAPU
        ELSIF v_medico.uni_nombre = 'ATENCIÓN URGENCIA' AND v_medico.total_atenciones <= 3 THEN
            v_destinacion := v_destinos(1); -- SAPU
        ELSIF v_medico.uni_nombre = 'ATENCIÓN URGENCIA' AND v_medico.total_atenciones > 3 THEN
            v_destinacion := v_destinos(3); -- Hospitales
        ELSIF v_medico.uni_nombre IN ('CARDIOLOGÍA','ONCOLÓGICA') THEN
            v_destinacion := v_destinos(3); -- Hospitales
        ELSIF v_medico.uni_nombre IN ('CIRUGÍA','CIRUGÍA PLÁSTICA') AND v_medico.total_atenciones <= 3 THEN
            v_destinacion := v_destinos(1); -- SAPU
        ELSIF v_medico.uni_nombre IN ('CIRUGÍA','CIRUGÍA PLÁSTICA') AND v_medico.total_atenciones > 3 THEN
            v_destinacion := v_destinos(3); -- Hospitales
        ELSIF v_medico.uni_nombre = 'PACIENTE CRÍTICO' THEN
            v_destinacion := v_destinos(3); -- Hospitales
        ELSIF v_medico.uni_nombre = 'PSIQUIATRÍA Y SALUD MENTAL' THEN
            v_destinacion := v_destinos(2); -- CESFAM
        ELSIF v_medico.uni_nombre = 'TRAUMATOLOGÍA ADULTO' AND v_medico.total_atenciones <= 3 THEN
            v_destinacion := v_destinos(1); -- SAPU
        ELSIF v_medico.uni_nombre = 'TRAUMATOLOGÍA ADULTO' AND v_medico.total_atenciones > 3 THEN
            v_destinacion := v_destinos(3); -- Hospitales
        ELSE
            v_destinacion := 'Sin destinación definida';
        END IF;

        -- Generar correo institucional
        v_correo := LOWER(SUBSTR(v_medico.uni_nombre,1,2))
                    || LOWER(SUBSTR(v_medico.apaterno, LENGTH(v_medico.apaterno)-2, 2))
                    || SUBSTR(v_medico.med_run, LENGTH(v_medico.med_run)-2, 3)
                    || '@ketekura.cl';

        -- Insertar en tabla MEDICO_SERVICIO_COMUNIDAD
        INSERT INTO MEDICO_SERVICIO_COMUNIDAD (
            unidad, 
            run_medico, nombre_medico,
            correo_institucional, total_aten_medicas, destinacion
        ) VALUES (
            v_medico.uni_nombre,
            v_medico.med_run || '-' || v_medico.dv_run,
            v_medico.nombre,
            v_correo,
            v_medico.total_atenciones,
            v_destinacion
        );

    END LOOP;

    CLOSE c_medicos;
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Proceso completado. Médicos procesados: ' || v_contador);
END;
/

-- Revision tabla resultante
select * from MEDICO_SERVICIO_COMUNIDAD;