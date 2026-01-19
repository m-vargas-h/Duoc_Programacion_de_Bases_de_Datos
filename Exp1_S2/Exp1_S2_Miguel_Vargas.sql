/*============================================================
ACTIVIDAD SUMATIVA 1:
INCORPORANDO SENTENCIAS DML Y FUNCIONES SQL

- Miguel Angel Vargas Huenul
============================================================*/

/*============================================================
CASO 1
============================================================*/

-- Variable bind para la fecha de proceso
VAR b_fecha_proceso VARCHAR2(20);

EXEC :b_fecha_proceso := TO_CHAR(SYSDATE,'DD/MM/YYYY');
    
DECLARE
    -- Variables escalares con %TYPE para heredar tipos de las columnas
    v_id_emp        empleado.id_emp%TYPE;
    v_numrun        empleado.numrun_emp%TYPE;
    v_dvrun         empleado.dvrun_emp%TYPE;
    v_pnombre       empleado.pnombre_emp%TYPE;
    v_snombre       empleado.snombre_emp%TYPE;
    v_appaterno     empleado.appaterno_emp%TYPE;
    v_apmaterno     empleado.apmaterno_emp%TYPE;
    v_estado_civil  estado_civil.nombre_estado_civil%TYPE;
    v_sueldo        empleado.sueldo_base%TYPE;
    v_fecha_contrato empleado.fecha_contrato%TYPE;
    v_fecha_nac     empleado.fecha_nac%TYPE;

    -- Variables auxiliares
    v_usuario   VARCHAR2(50);
    v_clave     VARCHAR2(50);
    v_anios     NUMBER;
    v_letras    VARCHAR2(10);
    v_contador  NUMBER := 0;
    v_total     NUMBER;
    v_nombre_completo VARCHAR2(120);

BEGIN
    -- Truncar la tabla antes de comenzar
    EXECUTE IMMEDIATE 'TRUNCATE TABLE USUARIO_CLAVE';

    -- Obtener el total de empleados en el rango
    SELECT COUNT(*) INTO v_total 
    FROM empleado 
    WHERE id_emp BETWEEN 100 AND 320;

    -- Iterar sobre todos los empleados
    FOR rec IN (
        SELECT 
            e.id_emp, 
            e.numrun_emp, 
            e.dvrun_emp, 
            e.pnombre_emp, 
            e.snombre_emp,
            e.appaterno_emp, 
            e.apmaterno_emp, 
            e.sueldo_base, 
            e.fecha_contrato, 
            e.fecha_nac, 
            ec.nombre_estado_civil
        FROM empleado e
        JOIN estado_civil ec ON e.id_estado_civil = ec.id_estado_civil
        WHERE e.id_emp BETWEEN 100 AND 320
        ORDER BY e.id_emp
   ) LOOP
        v_id_emp            := rec.id_emp;
        v_numrun            := rec.numrun_emp;
        v_dvrun             := rec.dvrun_emp;
        v_pnombre           := rec.pnombre_emp;
        v_snombre           := rec.snombre_emp;
        v_appaterno         := rec.appaterno_emp;
        v_apmaterno         := rec.apmaterno_emp;
        v_estado_civil      := rec.nombre_estado_civil;
        v_sueldo            := rec.sueldo_base;
        v_fecha_contrato    := rec.fecha_contrato;
        v_fecha_nac         := rec.fecha_nac;

        -- Calcular años trabajados
        v_anios := ROUND(MONTHS_BETWEEN(SYSDATE, v_fecha_contrato)/12);

        -- Construcción del nombre de usuario
        v_usuario := LOWER(SUBSTR(v_estado_civil,1,1))      -- primera letra estado civil
                   || SUBSTR(v_pnombre,1,3)                 -- tres primeras letras nombre
                   || LENGTH(v_pnombre)                     -- largo del nombre
                   || '*'                                   -- asterisco
                   || SUBSTR(v_sueldo,-1)                   -- último dígito sueldo base
                   || v_dvrun                               -- dígito verificador RUN
                   || v_anios                               -- años trabajados
                   || CASE WHEN v_anios < 10 THEN 'X' END;  -- X si <10 años

        -- Construcción de la clave
        IF UPPER(v_estado_civil) = 'CASADO' 
            OR UPPER(v_estado_civil) = 'ACUERDO DE UNION CIVIL' THEN
            v_letras := LOWER(SUBSTR(v_appaterno,1,2));

        ELSIF UPPER(v_estado_civil) = 'DIVORCIADO' 
            OR UPPER(v_estado_civil) = 'SOLTERO' THEN
            v_letras := LOWER(SUBSTR(v_appaterno,1,1) || SUBSTR(v_appaterno,LENGTH(v_appaterno),1));

        ELSIF UPPER(v_estado_civil) = 'VIUDO' THEN
            v_letras := LOWER(SUBSTR(v_appaterno,LENGTH(v_appaterno)-2,2));

        ELSIF UPPER(v_estado_civil) = 'SEPARADO' THEN
            v_letras := LOWER(SUBSTR(v_appaterno,LENGTH(v_appaterno)-1,2));
        END IF;

        v_clave := SUBSTR(v_numrun,3,1)                         -- tercer dígito del RUN
                || (EXTRACT(YEAR FROM v_fecha_nac)+2)           -- año nacimiento +2
                || LPAD(SUBSTR(TO_CHAR(v_sueldo-1),-3),3,'0')   -- sueldo-1 y últimos 3 dígitos
                || v_letras                                     -- letras según estado civil
                || v_id_emp                                     -- identificación empleado
                || TO_CHAR(SYSDATE,'MMYYYY');                   -- mes y año actuales

        -- Construcción del nombre completo con posibilidad de NULL en segundo nombre
        v_nombre_completo := TRIM(v_pnombre     -- primer nombre
                          || ' ' 
                          || NVL(v_snombre,'')  -- segundo nombre
                          || ' ' 
                          || v_appaterno        -- apellido paterno
                          || ' ' 
                          || v_apmaterno);      -- apellido materno

        -- Insertar credenciales en la tabla USUARIO_CLAVE
        INSERT INTO USUARIO_CLAVE (
            id_emp, 
            numrun_emp, 
            dvrun_emp, 
            nombre_empleado, 
            nombre_usuario, 
            clave_usuario
        )
        VALUES (
            v_id_emp, 
            v_numrun, 
            v_dvrun, 
            v_nombre_completo, 
            v_usuario, v_clave
        );

        v_contador := v_contador + 1;
    END LOOP;

    -- Control de transacciones
    IF v_contador = v_total THEN
        COMMIT;   -- Confirmar si se procesaron todos los empleados
    ELSE
        ROLLBACK; -- Revertir si hubo error
    END IF;

END;
/

-- Revision de tabla resultante 
select * from usuario_clave;
