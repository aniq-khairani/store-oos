WITH 
-- add grn latest
store AS (
    SELECT * FROM (
        SELECT str_no, str_na,
               ROW_NUMBER() OVER (PARTITION BY str_no ORDER BY extracted_date DESC) AS RN
        FROM source.mkfstrmi
    ) WHERE RN = 1
),
datefilter AS (
    SELECT DATE_TRUNC('month', ADD_MONTHS(CURRENT_DATE, -1))::date dt
),
daterange AS (
    SELECT dt start_date,
           DATEADD(DAY, -1, DATE_TRUNC('month', ADD_MONTHS(dt, 1)))::date AS end_date
    FROM datefilter
),
category AS (
    SELECT dps_no, category
    FROM (
        SELECT dps_no, dps_na,
               dps_no || ' - ' || dps_na category,
               ROW_NUMBER() OVER (PARTITION BY dps_no ORDER BY extracted_date DESC) AS RN
        FROM source.mkfdpsmi
        WHERE length(dps_no) = 8
    )
    WHERE RN = 1
),
pnc AS (
    SELECT * FROM (
        SELECT goo_no1, goo_no2, qty1, qty2,
               ROW_NUMBER() OVER (PARTITION BY goo_no1, goo_no2 ORDER BY extracted_date DESC) AS RN
        FROM source.mkfgntmi
    )
    WHERE RN = 1
),
item AS (
    SELECT * FROM (
        SELECT m.goo_no, m.goo_na, m.dps_no, c.category,
               ROW_NUMBER() OVER (PARTITION BY goo_no ORDER BY extracted_date DESC) AS RN
        FROM source.mkfgoomi M
        JOIN category c USING (dps_no)
    )
    WHERE RN = 1
),
tto_data1 AS (
  	SELECT str_no,
           idate AS last_grn_date,
           goo_no AS grn_item,
           SUM(qty) AS grn_qty,
           ROW_NUMBER() OVER(PARTITION BY str_no, goo_no ORDER BY idate DESC) AS rn
    FROM (
        SELECT M.str_no, M.goo_no, M.tto_code, M.qty, M.amt, M.idate,
               COALESCE(p.goo_no2, m.goo_no) goo_no_PNC,
               m.qty * COALESCE(p.qty2, 1)::numeric(10,2) qty_PNC
        FROM (
            SELECT H.str_no, D.goo_no, H.tto_code, SUM(D.qty) qty,
                   SUM(D.amt) amt, MAX(H.idate) AS idate
            FROM (
                SELECT * FROM (
                    SELECT m.kdate, m.str_no, m.seq_no, m.idate, m.tto_code, m.cnl_yn,
                           ROW_NUMBER() OVER (PARTITION BY m.kdate, m.str_no, m.seq_no ORDER BY m.extracted_date DESC) AS RN
                    FROM source.mkftto01 m
                    JOIN store str ON str.str_no = m.str_no
                    WHERE tto_code = '2F'
                )
                WHERE RN = 1
                  AND idate BETWEEN (SELECT start_date FROM daterange) AND (SELECT end_date FROM daterange)
                  AND COALESCE(cnl_yn,'N') <> 'Y'
            ) H
            JOIN (
                SELECT * FROM (
                    SELECT m.kdate, m.str_no, m.seq_no, m.goo_no, m.item_no, m.qty, m.amt,
                           ROW_NUMBER() OVER (PARTITION BY m.kdate, m.str_no, m.seq_no, m.goo_no, m.item_no ORDER BY m.extracted_date DESC) AS RN
                    FROM source.mkfttoti m
                    JOIN store str ON str.str_no = m.str_no
                )
                WHERE RN = 1
            ) D USING (str_no, seq_no, kdate)
            GROUP BY H.str_no, D.goo_no, H.tto_code
        ) M
        LEFT JOIN pnc p ON m.goo_no = p.goo_no1
        JOIN item i ON COALESCE(p.goo_no2, m.goo_no) = i.goo_no
    ) m
    GROUP BY str_no, idate, goo_no
)
-- from origin
, CTE_MKFSTOBAL_KKDC AS (
    SELECT dc.sup_no, dc.goo_no, SUM(d.qty - COALESCE(b.qty,0)) AS qty
    FROM source_current.dcfstomi d
    JOIN source_current.mkfgosmi dc ON d.goo_no = dc.goo_no and dc.str_no = 'KKDC'
    LEFT JOIN source_current.dcfplddt b ON b.goo_no = d.goo_no AND b.pld_no = 'BAD0001'
    WHERE d.sto_date = current_date - 1
    GROUP BY dc.sup_no, dc.goo_no
),
CTE_MKFDCOTI AS (
    SELECT str_no, goo_no, kdate, qty,
           ROW_NUMBER() OVER(PARTITION BY str_no, goo_no ORDER BY kdate DESC) AS rn
    FROM (
        SELECT str_no, goo_no, dps_no, dstr_no, kdate, qty,
               ROW_NUMBER() OVER(PARTITION BY str_no, goo_no, dps_no, dstr_no, kdate ORDER BY extracted_date DESC) AS rn
        FROM source.MKFDCOTI
        WHERE dps_no = 'A'
          AND kdate >= DATEADD(MONTH, -2, DATE_TRUNC('month', current_date))
    )
    WHERE rn = 1
),
CTE_V_EOSAU AS ( 
    SELECT DISTINCT GS.str_no, O.goo_no, 'Y' AS auto_order_flag
    FROM source_current.MKFGOOMI O
    JOIN source_current.MKFGOSMI GS ON GS.goo_no = O.goo_no and gs.str_no = 'KKDC'
    JOIN source_current.MKFSTRMI T  ON GS.str_no = T.str_no
    WHERE COALESCE(T.ao_yn,'N') = 'Y'
      AND T.close_date IS NULL
      AND T.ecr_path_d IS NOT NULL
      AND T.open_date <= current_date
      AND O.osunt_na NOT IN ('CTN','OTR') 
      AND COALESCE(O.stop_pur,'N') <> 'Y'
      AND O.goo_status <> '9'
      AND O.dps_no NOT IN ('25250601') 
      AND GS.ord_send = '0'
      AND GS.dstr_no = 'KKDC'
      AND COALESCE(GS.stop_pur,'N') <> 'Y'
      AND COALESCE(GS.stop_sal,'N') <> 'Y' 
      AND COALESCE(GS.opl_type,'3') <> '4'
)
-- final
SELECT
    s.str_no , --Store
    s.goo_no , --Item Code
    o.goo_na , --Item Name
    o.dps_no AS cla_no, --Category
    c.dps_na AS cla_na, --Category_Name
    COALESCE(dc.sup_no, '-') AS dcsup_no,
    COALESCE(p_dc.sup_na, '-') AS dcsup_na,
    COALESCE(gs.sup_no, '-') AS sup_no,
    COALESCE(p_gs.sup_na, '-') AS sup_na,
    s.sto_date , 
    s.qty AS sto_qty,
    dco.kdate AS l_ord_date,
    dco.qty AS ord_qty,
    COALESCE(v.auto_order_flag, 'N') AS auto_ord,
    o.popgoo_pro1 AS first_ord,
    gs.bas_pur AS ord_factor,
    DECODE(COALESCE(gs.stop_pur, 'N'),'N','Y','Y','N') AS orderable,
    DECODE(COALESCE(gs.stop_sal, 'N'),'N','Y','Y','N') AS sellable,
    gs.opl_type AS roq,
    DECODE(gs.ord_send, '0', 'DC', '3', 'DD', '') AS dist_type,
    gs.dstr_no AS dist_ctr,
    COALESCE(dc.qty, 0) AS dc_stobal,
    tto.last_grn_date,
    tto.grn_qty,
    TO_CHAR(current_timestamp AT TIME ZONE 'Asia/Kuala_Lumpur', 'YYYY-MM-DD HH24:MI') AS last_updated
FROM source_current.MKFSTOMI s
INNER JOIN source_current.MKFSTRMI t ON t.str_no = s.str_no AND t.close_date IS NULL
INNER JOIN source_current.MKFGOOMI o ON s.goo_no = o.goo_no AND COALESCE(o.stop_sal, 'N') = 'N'
INNER JOIN source_current.MKFGOSMI_KK gs ON s.str_no = gs.str_no AND s.goo_no = gs.goo_no AND COALESCE(gs.stop_sal, 'N') = 'N'
LEFT JOIN CTE_MKFSTOBAL_KKDC dc  ON s.goo_no = dc.goo_no
LEFT JOIN source_current.mkfdpsmi c ON o.dps_no = c.dps_no
LEFT JOIN source_current.MKFSUPMI p_dc ON dc.sup_no = p_dc.sup_no
LEFT JOIN source_current.MKFSUPMI p_gs ON gs.sup_no = p_gs.sup_no
LEFT JOIN CTE_MKFDCOTI dco ON dco.str_no = s.str_no AND dco.goo_no = s.goo_no AND dco.rn = 1
LEFT JOIN CTE_V_EOSAU v ON s.str_no = v.str_no AND s.goo_no = v.goo_no
LEFT JOIN tto_data1 tto ON s.str_no = tto.str_no AND s.goo_no = tto.grn_item AND tto.rn = 1
WHERE s.qty <= 0
ORDER BY s.str_no, s.goo_no;