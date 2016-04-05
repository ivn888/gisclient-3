SET search_path = gisclient_3, pg_catalog;

create temp sequence temp_seq;

INSERT INTO qtfield (qtfield_id,qtfield_name,field_header,searchtype_id,resultype_id,layer_id)
SELECT (SELECT max(qtfield_id) FROM qtfield) + nextval('temp_seq')  as qtfield_id,c.column_name as qtfield_name,c.column_name as field_header,0,4,l.layer_id
FROM layer l, information_schema.columns c
WHERE c.table_name=l.data
AND (substring(l.data_filter from c.column_name || E'[ =<>!\\])]') is not null
    OR l.classitem=c.column_name
    OR l.labelitem=c.column_name
    OR l.labelsizeitem=c.column_name
    OR l.labelminscale=c.column_name
    OR l.labelmaxscale=c.column_name)
and  c.column_name || l.layer_id not in (SELECT qtfield_name || layer_id FROM qtfield)
GROUP BY l.layer_id,c.column_name
ORDER BY l.layer_id;

INSERT INTO qtfield (qtfield_id,qtfield_name,field_header,searchtype_id,resultype_id,layer_id)
SELECT (SELECT max(qtfield_id) FROM qtfield) + nextval('temp_seq')  as qtfield_id,c.column_name as qtfield_name,c.column_name as field_header,0,4,l.layer_id
FROM layer l, information_schema.columns c, class s
WHERE c.table_name=l.data
AND s.layer_id=l.layer_id
AND (substring(s.class_text from c.column_name || E'[ =<>!\\])]') is not null
    OR substring(s.expression from c.column_name || E'[ =<>!\\])]') is not null
    OR substring(s.label_angle from c.column_name || E'[ =<>!\\])]') is not null
    OR substring(s.label_size from c.column_name || E'[ =<>!\\])]') is not null)
AND  c.column_name || l.layer_id not in (SELECT qtfield_name || layer_id FROM qtfield)
GROUP BY l.layer_id,c.column_name
ORDER BY l.layer_id;

INSERT INTO qtfield (qtfield_id,qtfield_name,field_header,searchtype_id,resultype_id,layer_id)
SELECT (SELECT max(qtfield_id) FROM qtfield) + nextval('temp_seq') as qtfield_id,c.column_name as qtfield_name,c.column_name as field_header,0,4,l.layer_id
FROM layer l, information_schema.columns c, class s, style t
WHERE c.table_name=l.data
AND s.layer_id=l.layer_id
AND s.class_id=t.class_id
AND substring(t.angle from c.column_name || E'[ =<>!\\])]') is not null
AND  c.column_name || l.layer_id not in (SELECT qtfield_name || layer_id FROM qtfield)
GROUP BY l.layer_id,c.column_name
ORDER BY l.layer_id;

drop sequence temp_seq;

-- Togli __data__ di troppo per sicurezza (evitare i doppi)
update qtfield set formula=regexp_replace(formula, E'(__data__\\.)+', '') where formula like '%__data__%';

-- Aggiungi __data__ alle formule
update qtfield
set formula = _subq.new_formula
from(
select q.qtfield_id as _qtfield_id, regexp_replace(q.formula, column_name, E'__data__\.' || column_name) as new_formula
from qtfield q, information_schema.columns c
where formula is not null
AND qtrelation_id=0
AND (substring(q.formula from '^' || c.column_name || E'[ |:()]') is not null
  OR substring(q.formula from E'[ |().,]' || c.column_name || E'[ |:()]') is not null
  OR substring(q.formula from E'[ |().,]' || c.column_name || '$') is not null
  OR substring(q.formula from '^' || c.column_name || '$') is not null)
AND formula not like E'%__data__.' || c.column_name || '%'
GROUP BY q.formula,c.column_name,q.qtfield_id
ORDER BY q.qtfield_id
) AS _subq
WHERE qtfield_id=_subq._qtfield_id;

-- Ripeti che è meglio...
update qtfield
set formula = _subq.new_formula
from(
select q.qtfield_id as _qtfield_id, regexp_replace(q.formula, column_name, E'__data__\.' || column_name) as new_formula
from qtfield q, information_schema.columns c
where formula is not null
AND qtrelation_id=0
AND (substring(q.formula from '^' || c.column_name || E'[ |:()]') is not null
  OR substring(q.formula from E'[ |().]' || c.column_name || E'[ |:()]') is not null
  OR substring(q.formula from E'[ |().]' || c.column_name || '$') is not null
  OR substring(q.formula from E'^' || c.column_name || '$') is not null)
AND formula not like E'%__data__.' || c.column_name || '%'
GROUP BY q.formula,c.column_name,q.qtfield_id
ORDER BY q.qtfield_id
) AS _subq
WHERE qtfield_id=_subq._qtfield_id;

-- Aggiungi la tabella secondaria alle formule
update qtfield
set formula = _subq.new_formula
from(
select q.qtfield_id as _qtfield_id, regexp_replace(q.formula, column_name, r.qtrelation_name || '.' || column_name) as new_formula
from qtfield q, information_schema.columns c, qtrelation r
where formula is not null
AND q.qtrelation_id!=0
AND q.qtrelation_id=r.qtrelation_id
AND (substring(q.formula from '^' || c.column_name || E'[ |:()]') is not null
  OR substring(q.formula from E'[ |(),]' || c.column_name || E'[ |:()]') is not null
  OR substring(q.formula from E'[ |(),]' || c.column_name || '$') is not null
  OR substring(q.formula from '^' || c.column_name || '$') is not null)
AND formula not like E'%\\%%'
GROUP BY q.formula,c.column_name,q.qtfield_id, r.qtrelation_name
ORDER BY q.qtfield_id
) AS _subq
WHERE qtfield_id=_subq._qtfield_id;

-- Ripeti che è meglio...
update qtfield
set formula = _subq.new_formula
from(
select q.qtfield_id as _qtfield_id, regexp_replace(q.formula, column_name, r.qtrelation_name || '.' || column_name) as new_formula
from qtfield q, information_schema.columns c, qtrelation r
where formula is not null
AND q.qtrelation_id!=0
AND q.qtrelation_id=r.qtrelation_id
AND (substring(q.formula from '^' || c.column_name || E'[ |:()]') is not null
  OR substring(q.formula from E'[ |(),]' || c.column_name || E'[ |:()]') is not null
  OR substring(q.formula from E'[ |(),]' || c.column_name || '$') is not null
  OR substring(q.formula from '^' || c.column_name || '$') is not null)
AND formula not like E'%\\%%'
GROUP BY q.formula,c.column_name,q.qtfield_id, r.qtrelation_name
ORDER BY q.qtfield_id
) AS _subq
WHERE qtfield_id=_subq._qtfield_id;


-- Cancella campi non esistenti
DELETE FROM qtfield q WHERE qtfield_id NOT IN
(
SELECT q.qtfield_id
FROM qtfield q, layer l, information_schema.columns c
WHERE q.layer_id=l.layer_id
AND c.table_name=l.data
AND c.column_name = q.qtfield_name
)
AND formula IS NULL
AND qtrelation_id=0;

-- Correggi sintassi delle labels
UPDATE class 
SET class_text=regexp_replace(regexp_replace(regexp_replace(class_text, E'\\] \\[', E'\]\+\['), E'\\[', E'''\[', 'g'), E'\\]', E'\]''', 'g') 
WHERE class_text is not null;

-- Correzioni grafiche sugli style per resa simile a geoweb 2.1
-- Outlinecolor importato da class a style
update style set outlinecolor=c.label_outlinecolor, width=0.25, maxwidth=0.25, minwidth=0.25 
from (select class_id as _class_id, label_outlinecolor from class where label_outlinecolor is not null) as c
where c._class_id=class_id;

-- Crea sfondo per classi con label_bgcolor e simboli, usando il quadrato pieno
create temp sequence temp_seq;

insert into style (style_id,class_id,style_name,symbol_name,color,style_order)
SELECT (SELECT max(style_id) FROM style) + nextval('temp_seq')  as style_id, class_id, class_name || '_BG' as style_name, 'QUADRATO_PIENO', label_bgcolor, -1 FROM class where label_bgcolor is not null;

drop sequence temp_seq;

