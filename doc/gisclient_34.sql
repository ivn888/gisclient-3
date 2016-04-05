--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: gisclient_34; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA gisclient_34;


ALTER SCHEMA gisclient_34 OWNER TO postgres;

SET search_path = gisclient_34, pg_catalog;

--
-- Name: tree; Type: TYPE; Schema: gisclient_34; Owner: postgres
--

CREATE TYPE tree AS (
	id integer,
	name character varying,
	lvl_id integer,
	lvl_name character varying
);


ALTER TYPE tree OWNER TO postgres;

--
-- Name: check_catalog(); Type: FUNCTION; Schema: gisclient_34; Owner: postgres
--

CREATE FUNCTION check_catalog() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
BEGIN
	if(coalesce(new.catalog_path,'')<>'' and new.connection_type=1) then
		if (not new.catalog_path ~ '^(.+)/$') then
			new.catalog_path:=new.catalog_path||'/';
		end if;
	end if;
	return new;
END
$_$;


ALTER FUNCTION gisclient_34.check_catalog() OWNER TO postgres;

--
-- Name: check_class(); Type: FUNCTION; Schema: gisclient_34; Owner: postgres
--

CREATE FUNCTION check_class() RETURNS trigger
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
	ok boolean;
BEGIN
	if trim(coalesce(new.label_angle,''))<>'' then
		if not((new.label_angle ~ '^([0-9]+)(\.[0-9])?$') or (new.label_angle ~ '^([\[]{1})([A-z0-9]+)([\]]{1})$') or (upper(new.label_angle) = 'AUTO')) then 	--CONTROLLO IL VALORE DEL LABEL_ANGLE
			raise exception 'label_angle @ Il valore deve essere un numero, AUTO oppure un campo di binding (es. [nome_campo])';
		end if;
	end if;
	if trim(coalesce(new.label_size,''))<>'' then
		if not((new.label_size ~ '^([0-9]+)$') or (new.label_size ~ '^([\[]{1})([A-z0-9]+)([\]]{1})$')) then 	--CONTROLLO IL VALORE DEL LABEL_SIZE
			raise exception 'label_size @ Il valore deve essere un numero intero oppure un campo di binding (es. [nome_campo])';
		end if;
	end if;
	return new;
END
$_$;


ALTER FUNCTION gisclient_34.check_class() OWNER TO postgres;

--
-- Name: check_layer(); Type: FUNCTION; Schema: gisclient_34; Owner: postgres
--

CREATE FUNCTION check_layer() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
	pr_name varchar;
	presente integer;
	newindex integer;
	ok boolean;
BEGIN
	--CONTROLLO CHE IL NOME SIA COMPOSTO DA CARATTERI ALFA-NUMERICI
	if(new.layer_name ~* '([ ]+)')	then 	
		raise exception 'layer_name @ Il nome del layer deve essere alfanumerico senza spazi bianchi';
	end if;

	--CONTROLLO IL VALORE DELLA TRASPARENCY
	if(coalesce(new.transparency,'')<>'') then 	
		new.transparency:=upper(new.transparency);
		select into ok (new.transparency='ALPHA' or new.transparency ='100' or new.transparency ~* '^([0-9]{1,2})$');
		if not ok then
			raise exception 'transparency @ Il valore deve essere un intero compreso tra 1-100 oppure ALPHA.';
		end if;
	end if;

	return new;
END
$_$;


ALTER FUNCTION gisclient_34.check_layer() OWNER TO postgres;

--
-- Name: check_layergroup(); Type: FUNCTION; Schema: gisclient_34; Owner: postgres
--

CREATE FUNCTION check_layergroup() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
	pr_name varchar;
	presente integer;
	newindex integer;
	ok boolean;
BEGIN
	--CONTROLLO IL VALORE DELLA TRASPARENCY
	if(coalesce(new.transparency,'')<>'') then 	
		new.transparency:=upper(new.transparency);
		select into ok (new.transparency='ALPHA' or new.transparency ='100' or new.transparency ~* '^([0-9]{1,2})$');
		if not ok then
			raise exception 'transparency @ Il valore deve essere un intero compreso tra 1-100 oppure ALPHA.';
		end if;
	end if;

	return new;
END
$_$;


ALTER FUNCTION gisclient_34.check_layergroup() OWNER TO postgres;

--
-- Name: check_mapset(); Type: FUNCTION; Schema: gisclient_34; Owner: postgres
--

CREATE FUNCTION check_mapset() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
	ext varchar;
	presente integer;
BEGIN

	new.mapset_name:=regexp_replace(trim(new.mapset_name),'([\t ]+)','_','g');
	select coalesce(project_extent,'') into ext from gisclient_34.project where project_name=new.project_name;
	if (coalesce(new.mapset_extent,'')='') then
		new.mapset_extent:=ext;
	else
		new.mapset_extent:=regexp_replace(trim(new.mapset_extent),'([\t ]+)',' ','g');
		if (new.mapset_extent !~* '^([0-9. -]+)$') then
			raise exception 'extent @ I valori di Extent devono essere 4 valori numerici separati da uno spazio essere un percorso valido';
		end if;
	end if;
	if (coalesce(new.refmap_extent,'')='') then
		new.refmap_extent=new.mapset_extent;
	else
		new.refmap_extent:=regexp_replace(trim(new.refmap_extent),'([\t ]+)',' ','g');
		if (new.refmap_extent !~* '^([0-9. -]+)$') then
			raise exception 'extent @ I valori di Extent devono essere 4 valori numerici separati da uno spazio essere un percorso valido';
		end if;
	end if;
	if (coalesce(new.test_extent,'')='') then
		new.test_extent=new.mapset_extent;
	else
		new.test_extent:=regexp_replace(trim(new.test_extent),'([\t ]+)',' ','g');
		if (new.test_extent !~* '^([0-9. -]+)$') then
			raise exception 'extent @ I valori di Extent devono essere 4 valori numerici separati da uno spazio essere un percorso valido';
		end if;
	end if;

	return new;
END
$_$;


ALTER FUNCTION gisclient_34.check_mapset() OWNER TO postgres;

--
-- Name: check_project(); Type: FUNCTION; Schema: gisclient_34; Owner: postgres
--

CREATE FUNCTION check_project() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE 
	ok boolean;
	presente integer;
	sk varchar;
	query text;
	newid integer;
BEGIN
	ok:=false;
	sk:='gisclient_34';	
	-- AGGIUNGO AL BASE URL LO SLASH FINALE (UTILE PER I LINK)
	if(coalesce(new.base_url,'')<>'') then
		if (not new.base_url ~ '^(.+)/$') then
			new.base_url:=new.base_url||'/';
		end if;
	end if;
	if(coalesce(new.base_path,'')<>'') then
		if (not new.base_path ~ '^(.+)/$') then
			new.base_path:=new.base_path||'/';
		end if;
	end if;

	-- CONTROLLO DELL'EXTENT
	if (trim(coalesce(new.project_extent,''))!='') then
		new.project_extent:=regexp_replace(trim(new.project_extent),'([\t ]+)',' ','g');
		if (new.project_extent !~* '^([0-9. -]+)$') then
			raise exception 'extent @ I valori di Extent devono essere 4 valori numerici separati da uno spazio essere un percorso valido';
		end if;
	end if;
	return new;
END
$_$;


ALTER FUNCTION gisclient_34.check_project() OWNER TO postgres;

--
-- Name: delete_qt(); Type: FUNCTION; Schema: gisclient_34; Owner: postgres
--

CREATE FUNCTION delete_qt() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	delete from gisclient_34.qtfield where qt_id=old.qt_id;
	return old;
END
$$;


ALTER FUNCTION gisclient_34.delete_qt() OWNER TO postgres;

--
-- Name: delete_relation(); Type: FUNCTION; Schema: gisclient_34; Owner: postgres
--

CREATE FUNCTION delete_relation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	delete from gisclient_34.field where relation_id=old.relation_id;
	return old;
END
$$;


ALTER FUNCTION gisclient_34.delete_relation() OWNER TO postgres;

--
-- Name: enc_pwd(); Type: FUNCTION; Schema: gisclient_34; Owner: postgres
--

CREATE FUNCTION enc_pwd() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	if (coalesce(new.pwd,'')<>'') then
		new.enc_pwd:=md5(new.pwd);
		new.pwd = null;
	end if;
	return new;
END
$$;


ALTER FUNCTION gisclient_34.enc_pwd() OWNER TO postgres;

--
-- Name: gw_findtree(integer, character varying); Type: FUNCTION; Schema: gisclient_34; Owner: postgres
--

CREATE FUNCTION gw_findtree(id integer, lvl character varying) RETURNS SETOF tree
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
	rec record;
	t gisclient_34.tree;
	i integer;
	d integer;
BEGIN
	select into d coalesce(depth,-1) from gisclient_34.e_level where name=lvl;
	if (d=-1) then
		raise exception 'Livello % non esistente',lvl;
	end if;
	for i in reverse d..1 loop
		return next t;
	end loop;
	
END
$$;


ALTER FUNCTION gisclient_34.gw_findtree(id integer, lvl character varying) OWNER TO postgres;

--
-- Name: move_layergroup(); Type: FUNCTION; Schema: gisclient_34; Owner: postgres
--

CREATE FUNCTION move_layergroup() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	if(new.theme_id<>old.theme_id) then
		update gisclient_34.qt set theme_id=new.theme_id where qt_id in (select distinct qt_id from gisclient_34.qt inner join gisclient_34.layer using(layer_id) inner join gisclient_34.layergroup using(layergroup_id) where layergroup_id=new.layergroup_id);
	end if;
	return new;
END
$$;


ALTER FUNCTION gisclient_34.move_layergroup() OWNER TO postgres;

--
-- Name: new_pkey(character varying, character varying); Type: FUNCTION; Schema: gisclient_34; Owner: postgres
--

CREATE FUNCTION new_pkey(tab character varying, id_fld character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare
    newid integer;
	sk varchar;
	query varchar;
begin
	sk:='gisclient_34';
	query:='select '||sk||'.new_pkey('''||tab||''','''||id_fld||''',0)';
	execute query into newid;
	return newid;
end
$$;


ALTER FUNCTION gisclient_34.new_pkey(tab character varying, id_fld character varying) OWNER TO postgres;

--
-- Name: new_pkey(character varying, character varying, integer); Type: FUNCTION; Schema: gisclient_34; Owner: postgres
--

CREATE FUNCTION new_pkey(tab character varying, id_fld character varying, st integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare
    str varchar;
start_value integer;
    newid record;
    sk varchar;
begin
	sk:='gisclient_34';
	if (st=0) then
		start_value:=0;
	else
		start_value:=st-1;
	end if;
	str:='select '||id_fld||' as id from '||sk||'.'||tab||' where '||id_fld||' ='||start_value||'+1';
	execute str into newid;
	if (coalesce(newid.id,0)=0) then
		return (start_value+1);
	end if;
	str:='SELECT coalesce(min('||id_fld||'),0)+1 as id FROM '||sk||'.'||tab||' f1
    WHERE NOT EXISTS (SELECT 1 FROM '||sk||'.'||tab||' f2 WHERE f2.'||id_fld||' = (f1.'||id_fld||'+1)) and '||id_fld||' > '||start_value||';';
	--raise notice '%',str;
	execute str into newid;
	return newid.id;

 
end
$$;


ALTER FUNCTION gisclient_34.new_pkey(tab character varying, id_fld character varying, st integer) OWNER TO postgres;

--
-- Name: new_pkey(character varying, character varying, character varying); Type: FUNCTION; Schema: gisclient_34; Owner: postgres
--

CREATE FUNCTION new_pkey(sk character varying, tab character varying, id_fld character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare
    newid integer;
begin
	select gisclient_34.new_pkey(sk ,tab,id_fld,0) into newid; 
	return newid;
end
$$;


ALTER FUNCTION gisclient_34.new_pkey(sk character varying, tab character varying, id_fld character varying) OWNER TO postgres;

--
-- Name: new_pkey(character varying, character varying, character varying, integer); Type: FUNCTION; Schema: gisclient_34; Owner: postgres
--

CREATE FUNCTION new_pkey(sk character varying, tab character varying, id_fld character varying, st integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare
    str varchar;
start_value integer;
    newid record;
begin
	if (st=0) then
		start_value:=0;
	else
		start_value:=st-1;
	end if;
	str:='select '||id_fld||' as id from '||sk||'.'||tab||' where '||id_fld||' ='||start_value||'+1';
	execute str into newid;
	if (coalesce(newid.id,0)=0) then
		return (start_value+1);
	end if;
	str:='SELECT coalesce(min('||id_fld||'),0)+1 as id FROM '||sk||'.'||tab||' f1
    WHERE NOT EXISTS (SELECT 1 FROM '||sk||'.'||tab||' f2 WHERE f2.'||id_fld||' = (f1.'||id_fld||'+1)) and '||id_fld||' > '||start_value||';';
	execute str into newid;
	return newid.id;

 
end
$$;


ALTER FUNCTION gisclient_34.new_pkey(sk character varying, tab character varying, id_fld character varying, st integer) OWNER TO postgres;

--
-- Name: new_pkey_varchar(character varying, character varying, character varying); Type: FUNCTION; Schema: gisclient_34; Owner: postgres
--

CREATE FUNCTION new_pkey_varchar(tb character varying, fld character varying, val character varying) RETURNS character varying
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
	query text;
	presente integer;
	newval varchar;
BEGIN
query:='select count(*) from gisclient_34.'||tb||' where '||fld||'='''||val||''';';
execute query into presente;
if(presente>0) then
	query:='select map||(max(newindex)+1)::varchar from (select regexp_replace('||fld||',''([0-9]+)$'','''') as map,case when(regexp_replace('||fld||',''^([A-z_]+)'','''')='''') then 0 else regexp_replace('||fld||',''^([A-z_]+)'','''')::integer end as newindex from gisclient_34.'||tb||' where '''||val||''' ~* regexp_replace('||fld||',''([0-9]+)$'','''')) X group by map;';
	execute query into newval;
	return newval;
else
	return val;
end if;
END
$_$;


ALTER FUNCTION gisclient_34.new_pkey_varchar(tb character varying, fld character varying, val character varying) OWNER TO postgres;

--
-- Name: rm_project_groups(); Type: FUNCTION; Schema: gisclient_34; Owner: postgres
--

CREATE FUNCTION rm_project_groups() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE

BEGIN
	delete from gisclient_34.mapset_groups where mapset_name in (select distinct mapset_name from gisclient_34.mapset where project_name=old.project_name) and group_name=old.group_name;
	return old;
END
$$;


ALTER FUNCTION gisclient_34.rm_project_groups() OWNER TO postgres;

--
-- Name: set_depth(); Type: FUNCTION; Schema: gisclient_34; Owner: postgres
--

CREATE FUNCTION set_depth() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	if (TG_OP='INSERT') then
		update gisclient_34.e_level set depth=(select coalesce(depth+1,0) from gisclient_34.e_level where id=new.parent_id) where id=new.id;
	elseif(new.parent_id<>coalesce(old.parent_id,-1)) then
		update gisclient_34.e_level set depth=(select coalesce(depth+1,0) from gisclient_34.e_level where id=new.parent_id) where id=new.id;
	end if;
	return new;
END
$$;


ALTER FUNCTION gisclient_34.set_depth() OWNER TO postgres;

--
-- Name: set_layer_name(); Type: FUNCTION; Schema: gisclient_34; Owner: postgres
--

CREATE FUNCTION set_layer_name() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	SELECT INTO NEW.layer_name layer_name FROM gisclient_34.layer WHERE layer_id=NEW.layer_id;
	RETURN NEW;
END
$$;


ALTER FUNCTION gisclient_34.set_layer_name() OWNER TO postgres;

--
-- Name: set_leaf(); Type: FUNCTION; Schema: gisclient_34; Owner: postgres
--

CREATE FUNCTION set_leaf() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	if(TG_OP='INSERT') then
		update gisclient_34.e_level X set leaf=(select case when (count(parent_id)>0) then 0 else 1 end from gisclient_34.e_level where parent_id=X.id);
	elsif (new.parent_id<> coalesce(old.parent_id,-1)) then
		update gisclient_34.e_level X set leaf=(select case when (count(parent_id)>0) then 0 else 1 end from gisclient_34.e_level where parent_id=X.id);
	end if;
	return new;
END
$$;


ALTER FUNCTION gisclient_34.set_leaf() OWNER TO postgres;

--
-- Name: set_map_extent(); Type: FUNCTION; Schema: gisclient_34; Owner: postgres
--

CREATE FUNCTION set_map_extent() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
	ext varchar;
BEGIN

	new.mapset_name:=regexp_replace(trim(new.mapset_name),'([\t ]+)','_','g');
	select coalesce(project_extent,'') into ext from gisclient_34.project where project_name=new.project_name;
	if (coalesce(new.mapset_extent,'')='') then
		new.mapset_extent:=ext;
	else
		new.mapset_extent:=regexp_replace(trim(new.mapset_extent),'([\t ]+)',' ','g');
		if (new.mapset_extent !~* '^([0-9. -]+)$') then
			raise exception 'extent @ I valori di Extent devono essere 4 valori numerici separati da uno spazio essere un percorso valido';
		end if;
	end if;
	if (coalesce(new.refmap_extent,'')='') then
		new.refmap_extent=new.mapset_extent;
	else
		new.refmap_extent:=regexp_replace(trim(new.refmap_extent),'([\t ]+)',' ','g');
		if (new.refmap_extent !~* '^([0-9. -]+)$') then
			raise exception 'extent @ I valori di Extent devono essere 4 valori numerici separati da uno spazio essere un percorso valido';
		end if;
	end if;
	if (coalesce(new.test_extent,'')='') then
		new.test_extent=new.mapset_extent;
	else
		new.test_extent:=regexp_replace(trim(new.test_extent),'([\t ]+)',' ','g');
		if (new.test_extent !~* '^([0-9. -]+)$') then
			raise exception 'extent @ I valori di Extent devono essere 4 valori numerici separati da uno spazio essere un percorso valido';
		end if;
	end if;

	return new;
END
$_$;


ALTER FUNCTION gisclient_34.set_map_extent() OWNER TO postgres;

--
-- Name: style_name(); Type: FUNCTION; Schema: gisclient_34; Owner: postgres
--

CREATE FUNCTION style_name() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
	num integer;
	rec record;
	check_hatch smallint;
BEGIN
	if ((coalesce(new.symbol_name,'')<>'') and (coalesce(new.size,0)=0)) then
		select into rec * from gisclient_34.symbol where symbol_name=new.symbol_name;
		if rec.style_def='TYPE HATCH' then
			raise exception 'size @ Per questo tipo di Simbolo ?ecessario definire il campo size';
		end if;
	end if;
	if trim(coalesce(new.angle,''))<>'' then
		if not((new.angle ~ '^([0-9]+)(\.[0-9])?$') or (new.angle ~ '^([\[]{1})([A-z0-9]+)([\]]{1})$') or (upper(new.angle) = 'AUTO')) then 	--CONTROLLO IL VALORE DEL LABEL_ANGLE
			raise exception 'angle @ Il valore deve essere un numero, AUTO oppure un campo di binding (es. [nome_campo])';
		end if;
	end if;
	
	if coalesce(new.style_name,'')='' then
		if new.style_order > 0 then 
			num:=new.style_order;
		else
			SELECT INTO num count(*)+1 FROM gisclient_34.style WHERE class_id=new.class_id and style_name ~* 'Stile ([0-9]+)';
		end if;
		new.style_name:='Stile '||num::varchar;
	end if;
	return new;
END
$_$;


ALTER FUNCTION gisclient_34.style_name() OWNER TO postgres;

--
-- Name: theme_version_tr(); Type: FUNCTION; Schema: gisclient_34; Owner: postgres
--

CREATE FUNCTION theme_version_tr() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  /* New function body */
  RAISE NOTICE 'Trigger "%" called on "%" for table %.%', TG_NAME, TG_OP, TG_TABLE_SCHEMA, TG_TABLE_NAME;
  IF TG_OP='INSERT' THEN
     INSERT INTO gisclient_34.theme_version(theme_id, theme_version) VALUES (NEW.theme_id, nextval('gisclient_34.theme_version_id_seq'));
  ELSIF TG_OP='UPDATE' THEN
     UPDATE gisclient_34.theme_version SET theme_version=nextval('gisclient_34.theme_version_id_seq') WHERE theme_id=NEW.theme_id;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION gisclient_34.theme_version_tr() OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: access_log; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE access_log (
    al_id integer NOT NULL,
    al_ip character(15),
    al_date timestamp without time zone,
    al_referer character varying,
    al_page character varying,
    al_useragent character varying
);


ALTER TABLE access_log OWNER TO postgres;

--
-- Name: access_log_al_id_seq; Type: SEQUENCE; Schema: gisclient_34; Owner: postgres
--

CREATE SEQUENCE access_log_al_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE access_log_al_id_seq OWNER TO postgres;

--
-- Name: access_log_al_id_seq; Type: SEQUENCE OWNED BY; Schema: gisclient_34; Owner: postgres
--

ALTER SEQUENCE access_log_al_id_seq OWNED BY access_log.al_id;


--
-- Name: catalog; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE catalog (
    catalog_id integer NOT NULL,
    catalog_name character varying NOT NULL,
    project_name character varying NOT NULL,
    connection_type smallint NOT NULL,
    catalog_path character varying NOT NULL,
    catalog_url character varying,
    catalog_description text,
    files_path character varying,
    set_extent smallint DEFAULT 1
);


ALTER TABLE catalog OWNER TO postgres;

--
-- Name: catalog_import; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE catalog_import (
    catalog_import_id integer NOT NULL,
    project_name character varying NOT NULL,
    catalog_import_name text,
    catalog_from integer NOT NULL,
    catalog_to integer NOT NULL,
    catalog_import_description text
);


ALTER TABLE catalog_import OWNER TO postgres;

--
-- Name: class; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE class (
    class_id integer NOT NULL,
    layer_id integer,
    class_name character varying NOT NULL,
    class_title character varying,
    class_text character varying,
    expression character varying,
    maxscale character varying,
    minscale character varying,
    class_template character varying,
    class_order integer,
    legendtype_id smallint DEFAULT 1,
    symbol_ttf_name character varying,
    label_font character varying,
    label_angle character varying,
    label_color character varying,
    label_outlinecolor character varying,
    label_bgcolor character varying,
    label_size character varying,
    label_minsize smallint,
    label_maxsize smallint,
    label_position character varying,
    label_antialias smallint DEFAULT 0,
    label_free smallint DEFAULT 0,
    label_priority smallint,
    label_wrap character(1),
    label_buffer integer DEFAULT 0,
    label_force smallint DEFAULT 0,
    label_def text,
    locked integer DEFAULT 0,
    class_image bytea,
    keyimage character varying
);


ALTER TABLE class OWNER TO postgres;

--
-- Name: e_charset_encodings; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE e_charset_encodings (
    charset_encodings_id integer NOT NULL,
    charset_encodings_name character varying NOT NULL,
    charset_encodings_order smallint
);


ALTER TABLE e_charset_encodings OWNER TO postgres;

--
-- Name: e_conntype; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE e_conntype (
    conntype_id smallint NOT NULL,
    conntype_name character varying NOT NULL,
    conntype_order smallint
);


ALTER TABLE e_conntype OWNER TO postgres;

--
-- Name: TABLE e_conntype; Type: COMMENT; Schema: gisclient_34; Owner: postgres
--

COMMENT ON TABLE e_conntype IS 'Il tipo File Shape deve essere sempre uguale a 1!';


--
-- Name: e_datatype; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE e_datatype (
    datatype_id smallint NOT NULL,
    datatype_name character varying NOT NULL,
    datatype_order smallint
);


ALTER TABLE e_datatype OWNER TO postgres;

--
-- Name: e_fieldformat; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE e_fieldformat (
    fieldformat_id integer NOT NULL,
    fieldformat_name character varying NOT NULL,
    fieldformat_format character varying NOT NULL,
    fieldformat_order smallint
);


ALTER TABLE e_fieldformat OWNER TO postgres;

--
-- Name: e_fieldtype; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE e_fieldtype (
    fieldtype_id smallint NOT NULL,
    fieldtype_name character varying NOT NULL,
    fieldtype_order smallint
);


ALTER TABLE e_fieldtype OWNER TO postgres;

--
-- Name: e_filetype; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE e_filetype (
    filetype_id smallint NOT NULL,
    filetype_name character varying NOT NULL,
    filetype_order smallint
);


ALTER TABLE e_filetype OWNER TO postgres;

--
-- Name: e_form; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE e_form (
    id integer NOT NULL,
    name character varying,
    config_file character varying,
    tab_type integer,
    level_destination integer,
    form_destination character varying,
    save_data character varying,
    parent_level integer,
    js text,
    table_name character varying,
    order_by character varying
);


ALTER TABLE e_form OWNER TO postgres;

--
-- Name: e_language; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE e_language (
    language_id character(2) NOT NULL,
    language_name character varying NOT NULL,
    language_order integer
);


ALTER TABLE e_language OWNER TO postgres;

--
-- Name: e_layertype; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE e_layertype (
    layertype_id smallint NOT NULL,
    layertype_name character varying NOT NULL,
    layertype_ms smallint,
    layertype_order smallint
);


ALTER TABLE e_layertype OWNER TO postgres;

--
-- Name: e_lblposition; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE e_lblposition (
    lblposition_id integer NOT NULL,
    lblposition_name character varying NOT NULL,
    lblposition_order smallint
);


ALTER TABLE e_lblposition OWNER TO postgres;

--
-- Name: e_legendtype; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE e_legendtype (
    legendtype_id smallint NOT NULL,
    legendtype_name character varying NOT NULL,
    legendtype_order smallint
);


ALTER TABLE e_legendtype OWNER TO postgres;

--
-- Name: e_level; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE e_level (
    id integer NOT NULL,
    name character varying,
    parent_name character varying,
    "order" smallint,
    parent_id smallint,
    depth smallint,
    leaf smallint,
    export integer DEFAULT 1,
    struct_parent_id integer,
    "table" character varying,
    admintype_id integer DEFAULT 2
);


ALTER TABLE e_level OWNER TO postgres;

--
-- Name: e_orderby; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE e_orderby (
    orderby_id smallint NOT NULL,
    orderby_name character varying NOT NULL,
    orderby_order smallint
);


ALTER TABLE e_orderby OWNER TO postgres;

--
-- Name: e_outputformat; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE e_outputformat (
    outputformat_id smallint NOT NULL,
    outputformat_name character varying NOT NULL,
    outputformat_driver character varying NOT NULL,
    outputformat_mimetype character varying NOT NULL,
    outputformat_imagemode character varying NOT NULL,
    outputformat_extension character varying NOT NULL,
    outputformat_option character varying,
    outputformat_order smallint
);


ALTER TABLE e_outputformat OWNER TO postgres;

--
-- Name: e_owstype; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE e_owstype (
    owstype_id smallint NOT NULL,
    owstype_name character varying NOT NULL,
    owstype_order smallint
);


ALTER TABLE e_owstype OWNER TO postgres;

--
-- Name: e_papersize; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE e_papersize (
    papersize_id integer NOT NULL,
    papersize_name character varying NOT NULL,
    papersize_size character varying NOT NULL,
    papersize_orientation character varying,
    papaersize_order smallint
);


ALTER TABLE e_papersize OWNER TO postgres;

--
-- Name: e_pattern; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE e_pattern (
    pattern_id integer NOT NULL,
    pattern_name character varying NOT NULL,
    pattern_def character varying NOT NULL,
    pattern_order smallint
);


ALTER TABLE e_pattern OWNER TO postgres;

--
-- Name: e_pattern_pattern_id_seq; Type: SEQUENCE; Schema: gisclient_34; Owner: postgres
--

CREATE SEQUENCE e_pattern_pattern_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE e_pattern_pattern_id_seq OWNER TO postgres;

--
-- Name: e_pattern_pattern_id_seq; Type: SEQUENCE OWNED BY; Schema: gisclient_34; Owner: postgres
--

ALTER SEQUENCE e_pattern_pattern_id_seq OWNED BY e_pattern.pattern_id;


--
-- Name: e_relationtype; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE e_relationtype (
    relationtype_id integer NOT NULL,
    relationtype_name character varying NOT NULL,
    relationtype_order smallint
);


ALTER TABLE e_relationtype OWNER TO postgres;

--
-- Name: e_resultype; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE e_resultype (
    resultype_id smallint NOT NULL,
    resultype_name character varying NOT NULL,
    resultype_order smallint
);


ALTER TABLE e_resultype OWNER TO postgres;

--
-- Name: e_searchable; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE e_searchable (
    searchable_id smallint NOT NULL,
    searchable_name character varying NOT NULL,
    searchable_order smallint
);


ALTER TABLE e_searchable OWNER TO postgres;

--
-- Name: e_searchtype; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE e_searchtype (
    searchtype_id smallint NOT NULL,
    searchtype_name character varying NOT NULL,
    searchtype_order smallint
);


ALTER TABLE e_searchtype OWNER TO postgres;

--
-- Name: e_sizeunits; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE e_sizeunits (
    sizeunits_id smallint NOT NULL,
    sizeunits_name character varying NOT NULL,
    sizeunits_order smallint
);


ALTER TABLE e_sizeunits OWNER TO postgres;

--
-- Name: e_symbolcategory; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE e_symbolcategory (
    symbolcategory_id smallint NOT NULL,
    symbolcategory_name character varying NOT NULL,
    symbolcategory_order smallint
);


ALTER TABLE e_symbolcategory OWNER TO postgres;

--
-- Name: form_level; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE form_level (
    id integer NOT NULL,
    level integer,
    mode integer,
    form integer,
    order_fld integer,
    visible smallint DEFAULT 1
);


ALTER TABLE form_level OWNER TO postgres;

--
-- Name: elenco_form; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW elenco_form AS
SELECT form_level.id AS "ID", form_level.mode, CASE WHEN (form_level.mode = 2) THEN 'New'::text WHEN (form_level.mode = 3) THEN 'Elenco'::text WHEN (form_level.mode = 0) THEN 'View'::text WHEN (form_level.mode = 1) THEN 'Edit'::text ELSE 'Non definito'::text END AS "Modo Visualizzazione Pagina", e_form.id AS "Form ID", e_form.name AS "Nome Form", e_form.tab_type AS "Tipo Tabella", x.name AS "Livello Destinazione", e_level.name AS "Livello Visualizzazione", CASE WHEN (COALESCE((e_level.depth)::integer, (-1)) = (-1)) THEN 0 ELSE (e_level.depth + 1) END AS "Profondita Albero", form_level.order_fld AS "Ordine Visualizzazione", CASE WHEN (form_level.visible = 1) THEN 'SI'::text ELSE 'NO'::text END AS "Visibile" FROM (((form_level JOIN e_level ON ((form_level.level = e_level.id))) JOIN e_form ON ((e_form.id = form_level.form))) JOIN e_level x ON ((x.id = e_form.level_destination))) ORDER BY CASE WHEN (COALESCE((e_level.depth)::integer, (-1)) = (-1)) THEN 0 ELSE (e_level.depth + 1) END, form_level.level, CASE WHEN (form_level.mode = 2) THEN 'Nuovo'::text WHEN ((form_level.mode = 0) OR (form_level.mode = 3)) THEN 'Elenco'::text WHEN (form_level.mode = 1) THEN 'View'::text ELSE 'Edit'::text END, form_level.order_fld;


ALTER TABLE elenco_form OWNER TO postgres;

--
-- Name: export_i18n; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE export_i18n (
    exporti18n_id integer NOT NULL,
    table_name character varying,
    field_name character varying,
    project_name character varying,
    pkey_id character varying,
    language_id character varying,
    value text,
    original_value text
);


ALTER TABLE export_i18n OWNER TO postgres;

--
-- Name: export_i18n_exporti18n_id_seq; Type: SEQUENCE; Schema: gisclient_34; Owner: postgres
--

CREATE SEQUENCE export_i18n_exporti18n_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE export_i18n_exporti18n_id_seq OWNER TO postgres;

--
-- Name: export_i18n_exporti18n_id_seq; Type: SEQUENCE OWNED BY; Schema: gisclient_34; Owner: postgres
--

ALTER SEQUENCE export_i18n_exporti18n_id_seq OWNED BY export_i18n.exporti18n_id;


--
-- Name: field; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE field (
    field_id integer NOT NULL,
    relation_id integer DEFAULT 0 NOT NULL,
    field_name character varying NOT NULL,
    field_header character varying NOT NULL,
    fieldtype_id smallint DEFAULT 1 NOT NULL,
    searchtype_id smallint DEFAULT 1 NOT NULL,
    resultype_id smallint DEFAULT 3 NOT NULL,
    field_format character varying,
    column_width integer,
    orderby_id integer DEFAULT 0 NOT NULL,
    field_filter integer DEFAULT 0 NOT NULL,
    datatype_id smallint DEFAULT 1 NOT NULL,
    field_order smallint DEFAULT 0 NOT NULL,
    default_op character varying,
    layer_id integer,
    editable numeric(1,0) DEFAULT 0,
    formula character varying,
    lookup_table character varying,
    lookup_id character varying,
    lookup_name character varying,
    filter_field_name character varying,
    CONSTRAINT field_relation_id_check CHECK ((relation_id >= 0))
);


ALTER TABLE field OWNER TO postgres;

--
-- Name: field_groups; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE field_groups (
    field_id integer NOT NULL,
    groupname character varying NOT NULL,
    editable numeric(1,0) DEFAULT 0
);


ALTER TABLE field_groups OWNER TO postgres;

--
-- Name: font; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE font (
    font_name character varying NOT NULL,
    file_name character varying NOT NULL
);


ALTER TABLE font OWNER TO postgres;

--
-- Name: groups; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE groups (
    groupname character varying NOT NULL,
    description character varying
);


ALTER TABLE groups OWNER TO postgres;

--
-- Name: i18n_field; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE i18n_field (
    i18nf_id integer NOT NULL,
    table_name character varying(255),
    field_name character varying(255)
);


ALTER TABLE i18n_field OWNER TO postgres;

--
-- Name: i18n_field_i18nf_id_seq; Type: SEQUENCE; Schema: gisclient_34; Owner: postgres
--

CREATE SEQUENCE i18n_field_i18nf_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE i18n_field_i18nf_id_seq OWNER TO postgres;

--
-- Name: i18n_field_i18nf_id_seq; Type: SEQUENCE OWNED BY; Schema: gisclient_34; Owner: postgres
--

ALTER SEQUENCE i18n_field_i18nf_id_seq OWNED BY i18n_field.i18nf_id;


--
-- Name: layer; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE layer (
    layer_id integer NOT NULL,
    layergroup_id integer NOT NULL,
    layer_name character varying NOT NULL,
    layertype_id smallint NOT NULL,
    catalog_id integer NOT NULL,
    data character varying,
    data_geom character varying,
    data_unique character varying,
    data_srid integer,
    data_filter character varying,
    classitem character varying,
    labelitem character varying,
    labelsizeitem character varying,
    labelminscale character varying,
    labelmaxscale character varying,
    maxscale character varying,
    minscale character varying,
    symbolscale integer,
    opacity character varying,
    maxfeatures integer,
    sizeunits_id numeric(1,0) DEFAULT 1,
    layer_def text,
    metadata text,
    template character varying,
    header character varying,
    footer character varying,
    tolerance integer,
    layer_order integer DEFAULT 0,
    queryable numeric(1,0) DEFAULT 0,
    layer_title character varying,
    zoom_buffer numeric,
    group_object numeric(1,0),
    selection_color character varying,
    papersize_id numeric,
    toleranceunits_id numeric(1,0),
    selection_width numeric(2,0),
    selection_info numeric(1,0) DEFAULT 1,
    hidden numeric(1,0) DEFAULT 0,
    private numeric(1,0) DEFAULT 0,
    postlabelcache numeric(1,0) DEFAULT 0,
    maxvectfeatures integer,
    data_type character varying,
    last_update character varying,
    data_extent character varying,
    searchable_id numeric(1,0) DEFAULT 0,
    hide_vector_geom numeric(1,0) DEFAULT 0,
    CONSTRAINT layer_layertype_id_check CHECK ((layertype_id > 0))
);


ALTER TABLE layer OWNER TO postgres;

--
-- Name: layer_groups_seq; Type: SEQUENCE; Schema: gisclient_34; Owner: postgres
--

CREATE SEQUENCE layer_groups_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE layer_groups_seq OWNER TO postgres;

--
-- Name: layer_groups; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE layer_groups (
    layer_id integer NOT NULL,
    groupname character varying NOT NULL,
    wms integer DEFAULT 0,
    wfs integer DEFAULT 0,
    wfst integer DEFAULT 0,
    layer_name character varying,
    layer_groups_id integer DEFAULT nextval('layer_groups_seq'::regclass) NOT NULL
);


ALTER TABLE layer_groups OWNER TO postgres;

--
-- Name: layer_link; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE layer_link (
    link_id integer NOT NULL,
    resultype_id smallint,
    layer_id integer NOT NULL
);


ALTER TABLE layer_link OWNER TO postgres;

--
-- Name: layergroup; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE layergroup (
    layergroup_id integer NOT NULL,
    theme_id integer NOT NULL,
    layergroup_name character varying NOT NULL,
    layergroup_title character varying,
    layergroup_maxscale integer,
    layergroup_minscale integer,
    layergroup_smbscale integer,
    layergroup_order integer,
    locked smallint DEFAULT 0,
    multi smallint DEFAULT 0,
    hidden integer DEFAULT 0,
    isbaselayer smallint DEFAULT 0,
    tiletype_id numeric(1,0) DEFAULT 1,
    sld character varying,
    style character varying,
    url character varying,
    owstype_id smallint DEFAULT 1,
    outputformat_id smallint DEFAULT 1,
    layers character varying,
    parameters character varying,
    gutter smallint DEFAULT 0,
    transition numeric(1,0),
    tree_group character varying,
    layergroup_description character varying,
    buffer numeric(1,0),
    tiles_extent character varying,
    tiles_extent_srid integer,
    layergroup_single numeric(1,0) DEFAULT 1,
    metadata_url character varying,
    opacity character varying DEFAULT 100,
    tile_origin text,
    tile_resolutions text,
    tile_matrix_set character varying,
    CONSTRAINT layergroup_name_lower_case CHECK (((layergroup_name)::text = lower((layergroup_name)::text)))
);


ALTER TABLE layergroup OWNER TO postgres;

--
-- Name: link; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE link (
    link_id integer NOT NULL,
    project_name character varying NOT NULL,
    link_name character varying NOT NULL,
    link_def character varying NOT NULL,
    link_order smallint DEFAULT 0,
    winw smallint DEFAULT 800,
    winh smallint DEFAULT 600
);


ALTER TABLE link OWNER TO postgres;

--
-- Name: localization; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE localization (
    localization_id integer NOT NULL,
    project_name character varying NOT NULL,
    i18nf_id integer,
    pkey_id character varying NOT NULL,
    language_id character(2),
    value text
);


ALTER TABLE localization OWNER TO postgres;

--
-- Name: localization_localization_id_seq; Type: SEQUENCE; Schema: gisclient_34; Owner: postgres
--

CREATE SEQUENCE localization_localization_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE localization_localization_id_seq OWNER TO postgres;

--
-- Name: localization_localization_id_seq; Type: SEQUENCE OWNED BY; Schema: gisclient_34; Owner: postgres
--

ALTER SEQUENCE localization_localization_id_seq OWNED BY localization.localization_id;


--
-- Name: mapset; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE mapset (
    mapset_name character varying NOT NULL,
    project_name character varying NOT NULL,
    mapset_title character varying,
    mapset_description text,
    template character varying,
    mapset_extent character varying,
    page_size character varying,
    filter_data character varying,
    dl_image_res character varying,
    imagelabel smallint DEFAULT 0,
    bg_color character varying DEFAULT '255 255 255'::character varying,
    refmap_extent character varying,
    test_extent character varying,
    mapset_srid integer DEFAULT (-1),
    mapset_def character varying,
    mapset_group character varying,
    private integer DEFAULT 0,
    sizeunits_id smallint DEFAULT 5,
    static_reference integer DEFAULT 0,
    metadata text,
    mapset_note text,
    mask character varying,
    maxscale integer,
    minscale integer,
    mapset_scales character varying,
    displayprojection integer,
    mapset_scale_type smallint DEFAULT 0,
    mapset_order smallint DEFAULT 0,
    mapset_tiles integer DEFAULT 0
);


ALTER TABLE mapset OWNER TO postgres;

--
-- Name: COLUMN mapset.mapset_scales; Type: COMMENT; Schema: gisclient_34; Owner: postgres
--

COMMENT ON COLUMN mapset.mapset_scales IS 'Possible scale list separated with comma';


--
-- Name: mapset_layergroup; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE mapset_layergroup (
    mapset_name character varying NOT NULL,
    layergroup_id integer NOT NULL,
    status smallint DEFAULT 0,
    refmap smallint DEFAULT 0,
    hide smallint DEFAULT 0
);


ALTER TABLE mapset_layergroup OWNER TO postgres;

--
-- Name: project; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE project (
    project_name character varying NOT NULL,
    project_title character varying,
    project_description text,
    base_path character varying,
    base_url character varying,
    project_extent character varying,
    sel_user_color character varying,
    sel_transparency integer DEFAULT 50,
    imagelabel_font character varying,
    imagelabel_text character varying,
    imagelabel_offset_x integer DEFAULT 5,
    imagelabel_offset_y integer DEFAULT 5,
    imagelabel_position character(2) DEFAULT 'LR'::bpchar,
    icon_w smallint DEFAULT 36,
    icon_h smallint DEFAULT 24,
    history smallint DEFAULT 4,
    project_srid integer NOT NULL,
    imagelabel_size integer DEFAULT 18,
    imagelabel_color character varying DEFAULT '0 0 0'::character varying,
    login_page character varying,
    project_note text,
    include_outputformats character varying,
    include_legend character varying,
    include_metadata character varying,
    xc numeric,
    yc numeric,
    max_extent_scale numeric,
    default_language_id character(2) DEFAULT 'it'::bpchar NOT NULL,
    charset_encodings_id integer,
    legend_font_size integer DEFAULT 8
);


ALTER TABLE project OWNER TO postgres;

--
-- Name: project_admin; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE project_admin (
    project_name character varying NOT NULL,
    username character varying NOT NULL
);


ALTER TABLE project_admin OWNER TO postgres;

--
-- Name: project_languages; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE project_languages (
    project_name character varying NOT NULL,
    language_id character(2) NOT NULL
);


ALTER TABLE project_languages OWNER TO postgres;

--
-- Name: project_srs; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE project_srs (
    project_name character varying NOT NULL,
    srid integer NOT NULL,
    projparam character varying,
    max_extent character varying,
    resolutions character varying
);


ALTER TABLE project_srs OWNER TO postgres;

--
-- Name: qt; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE qt (
    qt_id integer NOT NULL,
    theme_id integer NOT NULL,
    layer_id integer NOT NULL,
    qt_name character varying NOT NULL,
    max_rows smallint DEFAULT 25,
    papersize_id integer,
    edit_url character varying,
    groupobject integer DEFAULT 0,
    selection_color character varying,
    qt_order smallint DEFAULT 0,
    qtresultype_id integer,
    qt_filter character varying,
    zoom_buffer integer,
    qt_title character varying
);


ALTER TABLE qt OWNER TO postgres;

--
-- Name: qt_field; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE qt_field (
    qtfield_id integer NOT NULL,
    qt_id integer NOT NULL,
    qtrelation_id integer DEFAULT 0 NOT NULL,
    qtfield_name character varying NOT NULL,
    field_header character varying NOT NULL,
    fieldtype_id smallint DEFAULT 1 NOT NULL,
    searchtype_id smallint DEFAULT 1 NOT NULL,
    resultype_id smallint DEFAULT 3 NOT NULL,
    field_format character varying,
    column_width integer,
    orderby_id integer DEFAULT 0 NOT NULL,
    field_filter integer DEFAULT 0 NOT NULL,
    datatype_id smallint DEFAULT 1 NOT NULL,
    qtfield_order smallint DEFAULT 0 NOT NULL,
    default_op character varying,
    editable numeric(1,0) DEFAULT 0,
    formula character varying,
    lookup_table character varying,
    lookup_id character varying,
    lookup_name character varying,
    filter_field_name character varying,
    CONSTRAINT qtfield_qtrelation_id_check CHECK ((qtrelation_id >= 0))
);


ALTER TABLE qt_field OWNER TO postgres;

--
-- Name: qt_link; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE qt_link (
    qt_id integer NOT NULL,
    link_id integer NOT NULL,
    resultype_id smallint
);


ALTER TABLE qt_link OWNER TO postgres;

--
-- Name: qt_relation; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE qt_relation (
    qtrelation_id integer NOT NULL,
    qt_id integer NOT NULL,
    catalog_id integer NOT NULL,
    qtrelation_name character varying NOT NULL,
    qtrelationtype_id integer DEFAULT 1 NOT NULL,
    data_field_1 character varying NOT NULL,
    data_field_2 character varying,
    data_field_3 character varying,
    table_name character varying NOT NULL,
    table_field_1 character varying NOT NULL,
    table_field_2 character varying,
    table_field_3 character varying,
    language_id character varying(2)
);


ALTER TABLE qt_relation OWNER TO postgres;

--
-- Name: relation; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE relation (
    relation_id integer NOT NULL,
    catalog_id integer NOT NULL,
    relation_name character varying NOT NULL,
    relationtype_id integer DEFAULT 1 NOT NULL,
    data_field_1 character varying NOT NULL,
    data_field_2 character varying,
    data_field_3 character varying,
    table_name character varying NOT NULL,
    table_field_1 character varying NOT NULL,
    table_field_2 character varying,
    table_field_3 character varying,
    language_id character varying(2),
    layer_id integer,
    relation_title character varying,
    CONSTRAINT relation_name_lower_case CHECK (((relation_name)::text = lower((relation_name)::text))),
    CONSTRAINT relation_table_name_lower_case CHECK (((table_name)::text = lower((table_name)::text)))
);


ALTER TABLE relation OWNER TO postgres;

--
-- Name: seldb_catalog; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_catalog AS
SELECT (-1) AS id, 'Seleziona ====>'::character varying AS opzione, '0'::character varying AS project_name UNION ALL SELECT foo.id, foo.opzione, foo.project_name FROM (SELECT catalog.catalog_id AS id, catalog.catalog_name AS opzione, catalog.project_name FROM catalog ORDER BY catalog.catalog_name) foo;


ALTER TABLE seldb_catalog OWNER TO postgres;

--
-- Name: seldb_catalog_wms; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_catalog_wms AS
SELECT catalog.catalog_id AS id, catalog.catalog_name AS opzione, catalog.project_name FROM catalog WHERE (catalog.connection_type = 7);


ALTER TABLE seldb_catalog_wms OWNER TO postgres;

--
-- Name: seldb_charset_encodings; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_charset_encodings AS
SELECT foo.id, foo.opzione, foo.option_order FROM (SELECT (-1) AS id, 'Seleziona ====>'::character varying AS opzione, (0)::smallint AS option_order UNION SELECT e_charset_encodings.charset_encodings_id AS id, e_charset_encodings.charset_encodings_name AS opzione, e_charset_encodings.charset_encodings_order AS option_order FROM e_charset_encodings) foo ORDER BY foo.id;


ALTER TABLE seldb_charset_encodings OWNER TO postgres;

--
-- Name: seldb_conntype; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_conntype AS
SELECT NULL::integer AS id, 'Seleziona ====>'::character varying AS opzione UNION ALL SELECT foo.id, foo.opzione FROM (SELECT e_conntype.conntype_id AS id, e_conntype.conntype_name AS opzione FROM e_conntype ORDER BY e_conntype.conntype_order) foo;


ALTER TABLE seldb_conntype OWNER TO postgres;

--
-- Name: seldb_datatype; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_datatype AS
SELECT e_datatype.datatype_id AS id, e_datatype.datatype_name AS opzione FROM e_datatype;


ALTER TABLE seldb_datatype OWNER TO postgres;

--
-- Name: seldb_field_filter; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_field_filter AS
SELECT (-1) AS id, 'Nessuno'::character varying AS opzione, 0 AS qtfield_id, 0 AS qt_id UNION (SELECT x.field_id AS id, x.field_header AS opzione, y.field_id AS qtfield_id, x.layer_id AS qt_id FROM (field x JOIN field y USING (layer_id)) WHERE (x.field_id <> y.field_id) ORDER BY x.field_id, x.field_order);


ALTER TABLE seldb_field_filter OWNER TO postgres;

--
-- Name: seldb_fieldtype; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_fieldtype AS
SELECT e_fieldtype.fieldtype_id AS id, e_fieldtype.fieldtype_name AS opzione FROM e_fieldtype;


ALTER TABLE seldb_fieldtype OWNER TO postgres;

--
-- Name: seldb_filetype; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_filetype AS
SELECT (-1) AS id, 'Seleziona ====>'::character varying AS opzione UNION SELECT e_filetype.filetype_id AS id, e_filetype.filetype_name AS opzione FROM e_filetype;


ALTER TABLE seldb_filetype OWNER TO postgres;

--
-- Name: seldb_font; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_font AS
SELECT foo.id, foo.opzione FROM (SELECT ''::character varying AS id, 'Seleziona ====>'::character varying AS opzione UNION SELECT font.font_name AS id, font.font_name AS opzione FROM font) foo ORDER BY foo.id;


ALTER TABLE seldb_font OWNER TO postgres;

--
-- Name: seldb_language; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_language AS
SELECT foo.id, foo.opzione FROM (SELECT ''::text AS id, 'Seleziona ====>'::character varying AS opzione UNION SELECT e_language.language_id AS id, e_language.language_name AS opzione FROM e_language) foo ORDER BY foo.id;


ALTER TABLE seldb_language OWNER TO postgres;

--
-- Name: seldb_layer_layergroup; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_layer_layergroup AS
SELECT (-1) AS id, 'Seleziona ====>'::character varying AS opzione, NULL::integer AS layergroup_id UNION (SELECT DISTINCT layer.layer_id AS id, layer.layer_name AS opzione, layer.layergroup_id FROM layer WHERE (layer.queryable = (1)::numeric) ORDER BY layer.layer_name, layer.layer_id, layer.layergroup_id);


ALTER TABLE seldb_layer_layergroup OWNER TO postgres;

--
-- Name: seldb_layertype; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_layertype AS
SELECT foo.id, foo.opzione FROM (SELECT (-1) AS id, 'Seleziona ====>'::character varying AS opzione UNION SELECT e_layertype.layertype_id AS id, e_layertype.layertype_name AS opzione FROM e_layertype) foo ORDER BY foo.id;


ALTER TABLE seldb_layertype OWNER TO postgres;

--
-- Name: seldb_lblposition; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_lblposition AS
(SELECT ''::character varying AS id, 'Seleziona ====>'::character varying AS opzione UNION ALL SELECT e_lblposition.lblposition_name AS id, e_lblposition.lblposition_name AS opzione FROM e_lblposition WHERE ((e_lblposition.lblposition_name)::text = 'AUTO'::text)) UNION ALL SELECT foo.id, foo.opzione FROM (SELECT e_lblposition.lblposition_name AS id, e_lblposition.lblposition_name AS opzione FROM e_lblposition WHERE ((e_lblposition.lblposition_name)::text <> 'AUTO'::text) ORDER BY e_lblposition.lblposition_order) foo;


ALTER TABLE seldb_lblposition OWNER TO postgres;

--
-- Name: seldb_legendtype; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_legendtype AS
SELECT e_legendtype.legendtype_id AS id, e_legendtype.legendtype_name AS opzione FROM e_legendtype ORDER BY e_legendtype.legendtype_order;


ALTER TABLE seldb_legendtype OWNER TO postgres;

--
-- Name: seldb_link; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_link AS
SELECT (-1) AS id, 'Seleziona ====>'::character varying AS opzione, ''::character varying AS project_name UNION SELECT link.link_id AS id, link.link_name AS opzione, link.project_name FROM link;


ALTER TABLE seldb_link OWNER TO postgres;

--
-- Name: seldb_mapset_srid; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_mapset_srid AS
SELECT 3857 AS id, 3857 AS opzione, project.project_name, NULL::character varying AS max_extent, NULL::character varying AS resolutions FROM project UNION ALL (SELECT project_srs.srid AS id, project_srs.srid AS opzione, project_srs.project_name, project_srs.max_extent, project_srs.resolutions FROM project_srs ORDER BY project_srs.srid);


ALTER TABLE seldb_mapset_srid OWNER TO postgres;

--
-- Name: seldb_mapset_tiles; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_mapset_tiles AS
SELECT 0 AS id, 'NO TILES'::character varying AS opzione UNION ALL SELECT e_owstype.owstype_id AS id, e_owstype.owstype_name AS opzione FROM e_owstype WHERE (e_owstype.owstype_id = ANY (ARRAY[2, 3]));


ALTER TABLE seldb_mapset_tiles OWNER TO postgres;

--
-- Name: seldb_orderby; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_orderby AS
SELECT e_orderby.orderby_id AS id, e_orderby.orderby_name AS opzione FROM e_orderby;


ALTER TABLE seldb_orderby OWNER TO postgres;

--
-- Name: seldb_outputformat; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_outputformat AS
SELECT foo.id, foo.opzione FROM ((((SELECT e_outputformat.outputformat_id AS id, e_outputformat.outputformat_name AS opzione FROM e_outputformat WHERE (e_outputformat.outputformat_id = 7) UNION ALL SELECT e_outputformat.outputformat_id AS id, e_outputformat.outputformat_name AS opzione FROM e_outputformat WHERE (e_outputformat.outputformat_id = 1)) UNION ALL SELECT e_outputformat.outputformat_id AS id, e_outputformat.outputformat_name AS opzione FROM e_outputformat WHERE (e_outputformat.outputformat_id = 9)) UNION ALL SELECT e_outputformat.outputformat_id AS id, e_outputformat.outputformat_name AS opzione FROM e_outputformat WHERE (e_outputformat.outputformat_id = 3)) UNION ALL SELECT e_outputformat.outputformat_id AS id, e_outputformat.outputformat_name AS opzione FROM e_outputformat WHERE (e_outputformat.outputformat_id <> ALL (ARRAY[1, 3, 7, 9]))) foo;


ALTER TABLE seldb_outputformat OWNER TO postgres;

--
-- Name: seldb_owstype; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_owstype AS
SELECT e_owstype.owstype_id AS id, e_owstype.owstype_name AS opzione FROM e_owstype;


ALTER TABLE seldb_owstype OWNER TO postgres;

--
-- Name: seldb_papersize; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_papersize AS
SELECT (-1) AS id, 'Seleziona ====>'::character varying AS opzione UNION SELECT e_papersize.papersize_id AS id, e_papersize.papersize_name AS opzione FROM e_papersize;


ALTER TABLE seldb_papersize OWNER TO postgres;

--
-- Name: seldb_pattern; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_pattern AS
SELECT e_pattern.pattern_id AS id, e_pattern.pattern_name AS opzione FROM e_pattern;


ALTER TABLE seldb_pattern OWNER TO postgres;

--
-- Name: seldb_project; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_project AS
SELECT ''::character varying AS id, 'Seleziona ====>'::character varying AS opzione UNION (SELECT DISTINCT project.project_name AS id, project.project_name AS opzione FROM project ORDER BY project.project_name);


ALTER TABLE seldb_project OWNER TO postgres;

--
-- Name: seldb_qt; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_qt AS
SELECT (-1) AS id, 'Seleziona ====>'::character varying AS opzione, ''::character varying AS mapset_name UNION ALL SELECT qt.qt_id AS id, qt.qt_name AS opzione, mapset_layergroup.mapset_name FROM ((qt qt LEFT JOIN layer USING (layer_id)) LEFT JOIN mapset_layergroup USING (layergroup_id));


ALTER TABLE seldb_qt OWNER TO postgres;

--
-- Name: seldb_qt_relation; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_qt_relation AS
SELECT 0 AS id, 'layer'::character varying AS opzione, 0 AS qt_id UNION ALL SELECT qt_relation.qtrelation_id AS id, qt_relation.qtrelation_name AS opzione, qt_relation.qt_id FROM qt_relation;


ALTER TABLE seldb_qt_relation OWNER TO postgres;

--
-- Name: seldb_qt_relationtype; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_qt_relationtype AS
SELECT e_relationtype.relationtype_id AS id, e_relationtype.relationtype_name AS opzione FROM e_relationtype;


ALTER TABLE seldb_qt_relationtype OWNER TO postgres;

--
-- Name: seldb_relation; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_relation AS
SELECT 0 AS id, 'layer'::character varying AS opzione, 0 AS layer_id UNION SELECT relation.relation_id AS id, relation.relation_name AS opzione, relation.layer_id FROM relation;


ALTER TABLE seldb_relation OWNER TO postgres;

--
-- Name: seldb_relationtype; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_relationtype AS
SELECT e_relationtype.relationtype_id AS id, e_relationtype.relationtype_name AS opzione FROM e_relationtype;


ALTER TABLE seldb_relationtype OWNER TO postgres;

--
-- Name: seldb_resultype; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_resultype AS
SELECT e_resultype.resultype_id AS id, e_resultype.resultype_name AS opzione FROM e_resultype ORDER BY e_resultype.resultype_order;


ALTER TABLE seldb_resultype OWNER TO postgres;

--
-- Name: seldb_searchable; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_searchable AS
SELECT e_searchable.searchable_id AS id, e_searchable.searchable_name AS opzione FROM e_searchable;


ALTER TABLE seldb_searchable OWNER TO postgres;

--
-- Name: seldb_searchtype; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_searchtype AS
SELECT e_searchtype.searchtype_id AS id, e_searchtype.searchtype_name AS opzione FROM e_searchtype;


ALTER TABLE seldb_searchtype OWNER TO postgres;

--
-- Name: seldb_sizeunits; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_sizeunits AS
SELECT foo.id, foo.opzione FROM (SELECT ((-1))::smallint AS id, 'Seleziona ====>'::character varying AS opzione UNION SELECT e_sizeunits.sizeunits_id AS id, e_sizeunits.sizeunits_name AS opzione FROM e_sizeunits) foo ORDER BY foo.id;


ALTER TABLE seldb_sizeunits OWNER TO postgres;

--
-- Name: theme; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE theme (
    theme_id integer NOT NULL,
    project_name character varying,
    theme_name character varying NOT NULL,
    theme_title character varying,
    theme_order integer,
    locked smallint DEFAULT 0,
    theme_single numeric(1,0) DEFAULT 0,
    radio numeric(1,0) DEFAULT 0,
    copyright_string character varying,
    CONSTRAINT theme_name_lower_case CHECK (((theme_name)::text = lower((theme_name)::text)))
);


ALTER TABLE theme OWNER TO postgres;

--
-- Name: seldb_theme; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW seldb_theme AS
SELECT (-1) AS id, 'Seleziona ====>'::character varying AS opzione, ''::character varying AS project_name UNION SELECT theme.theme_id AS id, theme.theme_name AS opzione, theme.project_name FROM theme;


ALTER TABLE seldb_theme OWNER TO postgres;

--
-- Name: selgroup; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE selgroup (
    selgroup_id integer NOT NULL,
    project_name character varying NOT NULL,
    selgroup_name character varying NOT NULL,
    selgroup_title character varying,
    selgroup_order smallint DEFAULT 1
);


ALTER TABLE selgroup OWNER TO postgres;

--
-- Name: selgroup_layer; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE selgroup_layer (
    selgroup_id integer NOT NULL,
    layer_id integer NOT NULL
);


ALTER TABLE selgroup_layer OWNER TO postgres;

--
-- Name: style; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE style (
    style_id integer NOT NULL,
    class_id integer NOT NULL,
    style_name character varying NOT NULL,
    symbol_name character varying,
    color character varying,
    outlinecolor character varying,
    bgcolor character varying,
    angle character varying,
    size character varying,
    minsize smallint,
    maxsize smallint,
    width real,
    maxwidth real,
    minwidth real,
    locked smallint DEFAULT 0,
    style_def text,
    style_order integer,
    pattern_id integer
);


ALTER TABLE style OWNER TO postgres;

--
-- Name: symbol; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE symbol (
    symbol_name character varying NOT NULL,
    symbolcategory_id integer DEFAULT 1 NOT NULL,
    icontype integer DEFAULT 0 NOT NULL,
    symbol_image bytea,
    symbol_def text,
    symbol_type character varying,
    font_name character varying,
    ascii_code integer,
    filled numeric(1,0) DEFAULT 0,
    points character varying,
    image character varying
);


ALTER TABLE symbol OWNER TO postgres;

--
-- Name: theme_version; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE theme_version (
    theme_id integer NOT NULL,
    theme_version integer NOT NULL
);


ALTER TABLE theme_version OWNER TO postgres;

--
-- Name: theme_version_id_seq; Type: SEQUENCE; Schema: gisclient_34; Owner: postgres
--

CREATE SEQUENCE theme_version_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE theme_version_id_seq OWNER TO postgres;

--
-- Name: user_group; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE user_group (
    username character varying NOT NULL,
    groupname character varying NOT NULL
);


ALTER TABLE user_group OWNER TO postgres;

--
-- Name: usercontext; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE usercontext (
    usercontext_id integer NOT NULL,
    username character varying NOT NULL,
    mapset_name character varying NOT NULL,
    title character varying NOT NULL,
    context text
);


ALTER TABLE usercontext OWNER TO postgres;

--
-- Name: usercontext_usercontext_id_seq; Type: SEQUENCE; Schema: gisclient_34; Owner: postgres
--

CREATE SEQUENCE usercontext_usercontext_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE usercontext_usercontext_id_seq OWNER TO postgres;

--
-- Name: usercontext_usercontext_id_seq; Type: SEQUENCE OWNED BY; Schema: gisclient_34; Owner: postgres
--

ALTER SEQUENCE usercontext_usercontext_id_seq OWNED BY usercontext.usercontext_id;


--
-- Name: users; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE users (
    username character varying NOT NULL,
    pwd character varying,
    enc_pwd character varying,
    data_creazione date,
    data_scadenza date,
    data_modifica date,
    attivato smallint DEFAULT 1 NOT NULL,
    ultimo_accesso timestamp without time zone,
    cognome character varying,
    nome character varying,
    macaddress character varying,
    ip character varying,
    host character varying,
    controllo character varying,
    userdata character varying,
    email character varying
);


ALTER TABLE users OWNER TO postgres;

--
-- Name: users_options; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE users_options (
    users_options_id integer NOT NULL,
    username character varying NOT NULL,
    option_key character varying NOT NULL,
    option_value character varying NOT NULL
);


ALTER TABLE users_options OWNER TO postgres;

--
-- Name: users_options_users_options_id_seq; Type: SEQUENCE; Schema: gisclient_34; Owner: postgres
--

CREATE SEQUENCE users_options_users_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE users_options_users_options_id_seq OWNER TO postgres;

--
-- Name: users_options_users_options_id_seq; Type: SEQUENCE OWNED BY; Schema: gisclient_34; Owner: postgres
--

ALTER SEQUENCE users_options_users_options_id_seq OWNED BY users_options.users_options_id;


--
-- Name: version; Type: TABLE; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE TABLE version (
    version_id integer NOT NULL,
    version_name character varying NOT NULL,
    version_date date NOT NULL,
    version_key character varying NOT NULL
);


ALTER TABLE version OWNER TO postgres;

--
-- Name: version_version_id_seq; Type: SEQUENCE; Schema: gisclient_34; Owner: postgres
--

CREATE SEQUENCE version_version_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE version_version_id_seq OWNER TO postgres;

--
-- Name: version_version_id_seq; Type: SEQUENCE OWNED BY; Schema: gisclient_34; Owner: postgres
--

ALTER SEQUENCE version_version_id_seq OWNED BY version.version_id;


--
-- Name: vista_catalog; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW vista_catalog AS
SELECT c.catalog_id, c.catalog_name, c.project_name, c.connection_type, c.catalog_path, c.catalog_url, c.catalog_description, c.files_path, CASE WHEN (c.connection_type <> 6) THEN '(i) Controllo non possibile: connessione non PostGIS'::text WHEN ("substring"((c.catalog_path)::text, 0, "position"((c.catalog_path)::text, '/'::text)) <> (current_database())::text) THEN '(i) Controllo non possibile: DB diverso'::text WHEN (NOT ("substring"((c.catalog_path)::text, ("position"((c.catalog_path)::text, '/'::text) + 1), length((c.catalog_path)::text)) IN (SELECT tables.table_schema FROM information_schema.tables))) THEN '(!) Lo schema configurato non esiste'::text ELSE 'OK'::text END AS catalog_control FROM catalog c;


ALTER TABLE vista_catalog OWNER TO postgres;

--
-- Name: vista_class; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW vista_class AS
SELECT c.class_id, c.layer_id, c.class_name, c.class_title, c.class_text, c.expression, c.maxscale, c.minscale, c.class_template, c.class_order, c.legendtype_id, c.symbol_ttf_name, c.label_font, c.label_angle, c.label_color, c.label_outlinecolor, c.label_bgcolor, c.label_size, c.label_minsize, c.label_maxsize, c.label_position, c.label_antialias, c.label_free, c.label_priority, c.label_wrap, c.label_buffer, c.label_force, c.label_def, c.locked, c.class_image, c.keyimage, CASE WHEN ((c.expression IS NULL) AND (c.class_order <= (SELECT max(class.class_order) AS max FROM class WHERE (((class.layer_id = c.layer_id) AND (class.class_id <> c.class_id)) AND (class.expression IS NOT NULL))))) THEN '(!) Classe con espressione vuota, spostare in fondo'::text WHEN ((c.legendtype_id = 1) AND (NOT (c.class_id IN (SELECT style.class_id FROM style)))) THEN '(!) Mostra in legenda ma nessuno stile presente'::text WHEN (((((c.label_font IS NOT NULL) AND (c.label_color IS NOT NULL)) AND (c.label_size IS NOT NULL)) AND (c.label_position IS NOT NULL)) AND (l.labelitem IS NULL)) THEN '(!) Etichetta configurata correttamente, ma nessun campo etichetta configurato sul layer'::text WHEN (((((c.label_font IS NOT NULL) AND (c.label_color IS NOT NULL)) AND (c.label_size IS NOT NULL)) AND (c.label_position IS NOT NULL)) AND (l.labelitem IS NOT NULL)) THEN 'OK. (i) Con etichetta'::text ELSE 'OK'::text END AS class_control FROM (class c JOIN layer l USING (layer_id));


ALTER TABLE vista_class OWNER TO postgres;

--
-- Name: vista_field; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW vista_field AS
SELECT field.field_id, field.layer_id, field.fieldtype_id, x.relation_id, field.field_name, field.resultype_id, field.field_header, field.field_order, COALESCE(field.column_width, 0) AS column_width, x.name AS relation_name, x.relationtype_id, x.relationtype_name, field.editable, CASE WHEN (field.relation_id = 0) THEN CASE WHEN (c.connection_type <> 6) THEN '(i) Controllo non possibile: connessione non PostGIS'::text WHEN ("substring"((c.catalog_path)::text, 0, "position"((c.catalog_path)::text, '/'::text)) <> (current_database())::text) THEN '(i) Controllo non possibile: DB diverso'::text WHEN (NOT ((field.field_name)::text IN (SELECT columns.column_name FROM information_schema.columns WHERE (("substring"((c.catalog_path)::text, ("position"((c.catalog_path)::text, '/'::text) + 1), length((c.catalog_path)::text)) = (i.table_schema)::text) AND ((l.data)::text = (i.table_name)::text))))) THEN '(!) Il campo non esiste nella tabella'::text ELSE 'OK'::text END ELSE CASE WHEN (cr.connection_type <> 6) THEN '(i) Controllo non possibile: connessione non PostGIS'::text WHEN ("substring"((cr.catalog_path)::text, 0, "position"((cr.catalog_path)::text, '/'::text)) <> (current_database())::text) THEN '(i) Controllo non possibile: DB diverso'::text WHEN (NOT ((field.field_name)::text IN (SELECT columns.column_name FROM information_schema.columns WHERE (("substring"((cr.catalog_path)::text, ("position"((cr.catalog_path)::text, '/'::text) + 1), length((cr.catalog_path)::text)) = (i.table_schema)::text) AND ((r.table_name)::text = (i.table_name)::text))))) THEN ('(!) Il campo non esiste nella tabella di relazione: '::text || (r.relation_name)::text) ELSE 'OK'::text END END AS field_control FROM (((((((field JOIN e_fieldtype USING (fieldtype_id)) JOIN (SELECT y.relationtype_id, y.relation_id, y.name, z.relationtype_name FROM ((SELECT 0 AS relation_id, 'Data Layer'::character varying AS name, 0 AS relationtype_id UNION SELECT relation.relation_id, COALESCE(relation.relation_name, 'Nessuna Relazione'::character varying) AS name, relation.relationtype_id FROM relation) y JOIN (SELECT 0 AS relationtype_id, ''::character varying AS relationtype_name UNION SELECT e_relationtype.relationtype_id, e_relationtype.relationtype_name FROM e_relationtype) z USING (relationtype_id))) x USING (relation_id)) JOIN layer l USING (layer_id)) JOIN catalog c USING (catalog_id)) LEFT JOIN relation r USING (relation_id)) LEFT JOIN catalog cr ON ((cr.catalog_id = r.catalog_id))) LEFT JOIN information_schema.columns i ON (((((field.field_name)::text = (i.column_name)::text) AND ("substring"((c.catalog_path)::text, ("position"((c.catalog_path)::text, '/'::text) + 1), length((c.catalog_path)::text)) = (i.table_schema)::text)) AND (((l.data)::text = (i.table_name)::text) OR ((r.table_name)::text = (i.table_name)::text))))) ORDER BY field.field_id, x.relation_id, x.relationtype_id;


ALTER TABLE vista_field OWNER TO postgres;

--
-- Name: vista_layer; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW vista_layer AS
SELECT l.layer_id, l.layergroup_id, l.layer_name, l.layertype_id, l.catalog_id, l.data, l.data_geom, l.data_unique, l.data_srid, l.data_filter, l.classitem, l.labelitem, l.labelsizeitem, l.labelminscale, l.labelmaxscale, l.maxscale, l.minscale, l.symbolscale, l.opacity, l.maxfeatures, l.sizeunits_id, l.layer_def, l.metadata, l.template, l.header, l.footer, l.tolerance, l.layer_order, l.queryable, l.layer_title, l.zoom_buffer, l.group_object, l.selection_color, l.papersize_id, l.toleranceunits_id, l.selection_width, l.selection_info, l.hidden, l.private, l.postlabelcache, l.maxvectfeatures, l.data_type, l.last_update, l.data_extent, l.searchable_id, l.hide_vector_geom, CASE WHEN (((l.queryable = (1)::numeric) AND (l.hidden = (0)::numeric)) AND (l.layer_id IN (SELECT field.layer_id FROM field WHERE (field.resultype_id <> 4)))) THEN 'SI. Config. OK'::text WHEN (((l.queryable = (1)::numeric) AND (l.hidden = (1)::numeric)) AND (l.layer_id IN (SELECT field.layer_id FROM field WHERE (field.resultype_id <> 4)))) THEN 'SI. Ma è nascosto'::text WHEN ((l.queryable = (1)::numeric) AND (l.layer_id IN (SELECT field.layer_id FROM field WHERE (field.resultype_id = 4)))) THEN 'NO. Nessun campo nei risultati'::text ELSE 'NO. WFS non abilitato'::text END AS is_queryable, CASE WHEN ((l.queryable = (1)::numeric) AND (l.layer_id IN (SELECT field.layer_id FROM field WHERE (field.editable = (1)::numeric)))) THEN 'SI. Config. OK'::text WHEN ((l.queryable = (1)::numeric) AND (l.layer_id IN (SELECT field.layer_id FROM field WHERE (field.editable = (0)::numeric)))) THEN 'NO. Nessun campo è editabile'::text WHEN ((l.queryable = (0)::numeric) AND (l.layer_id IN (SELECT field.layer_id FROM field WHERE (field.editable = (1)::numeric)))) THEN 'NO. Esiste un campo editabile ma il WFS non è attivo'::text ELSE 'NO.'::text END AS is_editable, CASE WHEN (c.connection_type <> 6) THEN '(i) Controllo non possibile: connessione non PostGIS'::text WHEN ("substring"((c.catalog_path)::text, 0, "position"((c.catalog_path)::text, '/'::text)) <> (current_database())::text) THEN '(i) Controllo non possibile: DB diverso'::text WHEN (NOT ((l.data)::text IN (SELECT tables.table_name FROM information_schema.tables WHERE ((tables.table_schema)::text = "substring"((c.catalog_path)::text, ("position"((c.catalog_path)::text, '/'::text) + 1), length((c.catalog_path)::text)))))) THEN '(!) La tabella non esiste nel DB'::text WHEN (NOT ((l.data_geom)::text IN (SELECT columns.column_name FROM information_schema.columns WHERE ((((columns.table_schema)::text = "substring"((c.catalog_path)::text, ("position"((c.catalog_path)::text, '/'::text) + 1), length((c.catalog_path)::text))) AND ((columns.table_name)::text = (l.data)::text)) AND ((columns.data_type)::text = 'USER-DEFINED'::text))))) THEN '(!) Il campo geometrico del layer non esiste'::text WHEN (NOT ((l.data_unique)::text IN (SELECT columns.column_name FROM information_schema.columns WHERE (((columns.table_schema)::text = "substring"((c.catalog_path)::text, ("position"((c.catalog_path)::text, '/'::text) + 1), length((c.catalog_path)::text))) AND ((columns.table_name)::text = (l.data)::text))))) THEN '(!) Il campo chiave del layer non esiste'::text WHEN (NOT (l.data_srid IN (SELECT geometry_columns.srid FROM public.geometry_columns WHERE (((geometry_columns.f_table_schema)::text = "substring"((c.catalog_path)::text, ("position"((c.catalog_path)::text, '/'::text) + 1), length((c.catalog_path)::text))) AND ((geometry_columns.f_table_name)::text = (l.data)::text))))) THEN '(!) Lo SRID configurato non è quello corretto'::text WHEN (NOT (upper((l.data_type)::text) IN (SELECT geometry_columns.type FROM public.geometry_columns WHERE (((geometry_columns.f_table_schema)::text = "substring"((c.catalog_path)::text, ("position"((c.catalog_path)::text, '/'::text) + 1), length((c.catalog_path)::text))) AND ((geometry_columns.f_table_name)::text = (l.data)::text))))) THEN '(!) Geometrytype non corretto'::text WHEN (NOT ((l.labelitem)::text IN (SELECT columns.column_name FROM information_schema.columns WHERE (((columns.table_schema)::text = "substring"((c.catalog_path)::text, ("position"((c.catalog_path)::text, '/'::text) + 1), length((c.catalog_path)::text))) AND ((columns.table_name)::text = (l.data)::text))))) THEN '(!) Il campo etichetta del layer non esiste'::text WHEN (NOT ((l.labelitem)::text IN (SELECT field.field_name FROM field WHERE (field.layer_id = l.layer_id)))) THEN '(!) Campo etichetta non presente nei campi del layer'::text WHEN (NOT ((l.labelsizeitem)::text IN (SELECT columns.column_name FROM information_schema.columns WHERE (((columns.table_schema)::text = "substring"((c.catalog_path)::text, ("position"((c.catalog_path)::text, '/'::text) + 1), length((c.catalog_path)::text))) AND ((columns.table_name)::text = (l.data)::text))))) THEN '(!) Il campo altezza etichetta del layer non esiste'::text WHEN (NOT ((l.labelsizeitem)::text IN (SELECT field.field_name FROM field WHERE (field.layer_id = l.layer_id)))) THEN '(!) Campo altezza etichetta non presente nei campi del layer'::text WHEN ((((((t.project_name)::text || '.'::text) || (lg.layergroup_name)::text) || '.'::text) || (l.layer_name)::text) IN (SELECT (((((t2.project_name)::text || '.'::text) || (lg2.layergroup_name)::text) || '.'::text) || (l2.layer_name)::text) FROM ((layer l2 JOIN layergroup lg2 USING (layergroup_id)) JOIN theme t2 USING (theme_id)) GROUP BY (((((t2.project_name)::text || '.'::text) || (lg2.layergroup_name)::text) || '.'::text) || (l2.layer_name)::text) HAVING (count((((((t2.project_name)::text || '.'::text) || (lg2.layergroup_name)::text) || '.'::text) || (l2.layer_name)::text)) > 1))) THEN '(!) Combinazione nome layergroup + nome layer non univoca. Cambiare nome al layer o al layergroup'::text WHEN (NOT (l.layer_id IN (SELECT class.layer_id FROM class))) THEN 'OK (i) Non ci sono classi configurate in questo layer'::text ELSE 'OK'::text END AS layer_control FROM ((((layer l JOIN catalog c USING (catalog_id)) JOIN e_layertype USING (layertype_id)) JOIN layergroup lg USING (layergroup_id)) JOIN theme t USING (theme_id));


ALTER TABLE vista_layer OWNER TO postgres;

--
-- Name: vista_layergroup; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW vista_layergroup AS
SELECT lg.layergroup_id, lg.theme_id, lg.layergroup_name, lg.layergroup_title, lg.layergroup_maxscale, lg.layergroup_minscale, lg.layergroup_smbscale, lg.layergroup_order, lg.locked, lg.multi, lg.hidden, lg.isbaselayer, lg.tiletype_id, lg.sld, lg.style, lg.url, lg.owstype_id, lg.outputformat_id, lg.layers, lg.parameters, lg.gutter, lg.transition, lg.tree_group, lg.layergroup_description, lg.buffer, lg.tiles_extent, lg.tiles_extent_srid, lg.layergroup_single, lg.metadata_url, lg.opacity, lg.tile_origin, lg.tile_resolutions, lg.tile_matrix_set, CASE WHEN ((lg.tiles_extent_srid IS NOT NULL) AND (NOT (lg.tiles_extent_srid IN (SELECT project_srs.srid FROM project_srs WHERE ((project_srs.project_name)::text = (t.project_name)::text))))) THEN '(!) SRID estensione tiles non presente nei sistemi di riferimento del progetto'::text WHEN ((lg.owstype_id = 6) AND (lg.url IS NULL)) THEN '(!) Nessuna URL configurata per la chiamata TMS'::text WHEN ((lg.owstype_id = 6) AND (lg.layers IS NULL)) THEN '(!) Nessun layer configurato per la chiamata TMS'::text WHEN ((lg.owstype_id = 9) AND (lg.url IS NULL)) THEN '(!) Nessuna URL configurata per la chiamata WMTS'::text WHEN ((lg.owstype_id = 9) AND (lg.layers IS NULL)) THEN '(!) Nessun layer configurato per la chiamata WMTS'::text WHEN ((lg.owstype_id = 9) AND (lg.tile_matrix_set IS NULL)) THEN '(!) Nessun Tile Matrix configurato per la chiamata WMTS'::text WHEN ((lg.owstype_id = 9) AND (lg.style IS NULL)) THEN '(!) Nessuno stile configurato per la chiamata WMTS'::text WHEN ((lg.owstype_id = 9) AND (lg.tile_origin IS NULL)) THEN '(!) Nessuna origine configurata per la chiamata WMTS'::text WHEN ((lg.opacity IS NULL) OR ((lg.opacity)::text = '0'::text)) THEN '(i) Attenzione: trasparenza totale'::text ELSE 'OK'::text END AS layergroup_control FROM (layergroup lg JOIN theme t USING (theme_id));


ALTER TABLE vista_layergroup OWNER TO postgres;

--
-- Name: vista_link; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW vista_link AS
SELECT l.link_id, l.project_name, l.link_name, l.link_def, l.link_order, l.winw, l.winh, CASE WHEN ((l.link_def)::text !~~ 'http%://%@%@'::text) THEN '(!) Definizione del link non corretta. La sintassi deve essere: http://url@campo@'::text WHEN (NOT (l.link_id IN (SELECT link.link_id FROM layer_link link))) THEN 'OK. Non utilizzato'::text WHEN (NOT (replace("substring"((l.link_def)::text, '%#"@%@#"%'::text, '#'::text), '@'::text, ''::text) IN (SELECT qtfield.field_name AS qtfield_name FROM field qtfield WHERE (qtfield.layer_id IN (SELECT link.layer_id FROM layer_link link WHERE (link.link_id = l.link_id)))))) THEN '(!) Campo non presente nel layer'::text ELSE 'OK. In uso'::text END AS link_control FROM link l;


ALTER TABLE vista_link OWNER TO postgres;

--
-- Name: vista_mapset; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW vista_mapset AS
SELECT m.mapset_name, m.project_name, m.mapset_title, m.mapset_description, m.template, m.mapset_extent, m.page_size, m.filter_data, m.dl_image_res, m.imagelabel, m.bg_color, m.refmap_extent, m.test_extent, m.mapset_srid, m.mapset_def, m.mapset_group, m.private, m.sizeunits_id, m.static_reference, m.metadata, m.mapset_note, m.mask, m.maxscale, m.minscale, m.mapset_scales, m.displayprojection, m.mapset_scale_type, m.mapset_order, m.mapset_tiles, CASE WHEN (NOT ((m.mapset_name)::text IN (SELECT mapset_layergroup.mapset_name FROM mapset_layergroup))) THEN '(!) Nessun layergroup presente'::text WHEN (75 <= (SELECT count(mapset_layergroup.layergroup_id) AS count FROM mapset_layergroup WHERE ((mapset_layergroup.mapset_name)::text = (m.mapset_name)::text) GROUP BY mapset_layergroup.mapset_name)) THEN '(!) Openlayers non consente di rappresentare più di 75 layergroup alla volta'::text WHEN (m.mapset_scales IS NULL) THEN '(!) Nessun elenco di scale configurato'::text WHEN (m.mapset_srid <> m.displayprojection) THEN '(i) Coordinate visualizzate diverse da quelle di mappa'::text WHEN (0 = (SELECT max(mapset_layergroup.refmap) AS max FROM mapset_layergroup WHERE ((mapset_layergroup.mapset_name)::text = (m.mapset_name)::text) GROUP BY mapset_layergroup.mapset_name)) THEN '(i) Nessuna reference map'::text ELSE 'OK'::text END AS mapset_control FROM mapset m;


ALTER TABLE vista_mapset OWNER TO postgres;

--
-- Name: vista_project_languages; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW vista_project_languages AS
SELECT project_languages.project_name, project_languages.language_id, e_language.language_name, e_language.language_order FROM (project_languages JOIN e_language ON ((project_languages.language_id = e_language.language_id))) ORDER BY e_language.language_order;


ALTER TABLE vista_project_languages OWNER TO postgres;

--
-- Name: vista_relation; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW vista_relation AS
SELECT r.relation_id, r.catalog_id, r.relation_name, r.relationtype_id, r.data_field_1, r.data_field_2, r.data_field_3, r.table_name, r.table_field_1, r.table_field_2, r.table_field_3, r.language_id, r.layer_id, CASE WHEN (c.connection_type <> 6) THEN '(i) Controllo non possibile: connessione non PostGIS'::text WHEN ("substring"((c.catalog_path)::text, 0, "position"((c.catalog_path)::text, '/'::text)) <> (current_database())::text) THEN '(i) Controllo non possibile: DB diverso'::text WHEN (NOT ((l.layer_name)::text IN (SELECT tables.table_name FROM information_schema.tables WHERE ((tables.table_schema)::text = "substring"((c.catalog_path)::text, ("position"((c.catalog_path)::text, '/'::text) + 1), length((c.catalog_path)::text)))))) THEN '(!) La tabella DB del layer non esiste'::text WHEN (NOT ((r.table_name)::text IN (SELECT tables.table_name FROM information_schema.tables WHERE ((tables.table_schema)::text = "substring"((c.catalog_path)::text, ("position"((c.catalog_path)::text, '/'::text) + 1), length((c.catalog_path)::text)))))) THEN '(!) tabella DB di JOIN non esiste'::text WHEN ((r.data_field_1 IS NULL) OR (r.table_field_1 IS NULL)) THEN '(!) Uno dei campi della JOIN 1 è vuoto'::text WHEN (NOT ((r.data_field_1)::text IN (SELECT columns.column_name FROM information_schema.columns WHERE (((columns.table_schema)::text = "substring"((c.catalog_path)::text, ("position"((c.catalog_path)::text, '/'::text) + 1), length((c.catalog_path)::text))) AND ((columns.table_name)::text = (l.layer_name)::text))))) THEN '(!) Il campo chiave layer non esiste'::text WHEN (NOT ((r.table_field_1)::text IN (SELECT columns.column_name FROM information_schema.columns WHERE (((columns.table_schema)::text = "substring"((c.catalog_path)::text, ("position"((c.catalog_path)::text, '/'::text) + 1), length((c.catalog_path)::text))) AND ((columns.table_name)::text = (r.table_name)::text))))) THEN '(!) Il campo chiave della relazione non esiste'::text WHEN ((r.data_field_2 IS NULL) AND (r.table_field_2 IS NULL)) THEN 'OK'::text WHEN ((r.data_field_2 IS NULL) OR (r.table_field_2 IS NULL)) THEN '(!) Uno dei campi della JOIN 2 è vuoto'::text WHEN (NOT ((r.data_field_2)::text IN (SELECT columns.column_name FROM information_schema.columns WHERE (((columns.table_schema)::text = "substring"((c.catalog_path)::text, ("position"((c.catalog_path)::text, '/'::text) + 1), length((c.catalog_path)::text))) AND ((columns.table_name)::text = (l.layer_name)::text))))) THEN '(!) Il campo chiave layer della JOIN 2 non esiste'::text WHEN (NOT ((r.table_field_2)::text IN (SELECT columns.column_name FROM information_schema.columns WHERE (((columns.table_schema)::text = "substring"((c.catalog_path)::text, ("position"((c.catalog_path)::text, '/'::text) + 1), length((c.catalog_path)::text))) AND ((columns.table_name)::text = (r.table_name)::text))))) THEN '(!) Il campo chiave relazione della JOIN 2 non esiste'::text WHEN ((r.data_field_3 IS NULL) AND (r.table_field_3 IS NULL)) THEN 'OK'::text WHEN ((r.data_field_3 IS NULL) OR (r.table_field_3 IS NULL)) THEN '(!) Uno dei campi della JOIN 3 è vuoto'::text WHEN (NOT ((r.data_field_3)::text IN (SELECT columns.column_name FROM information_schema.columns WHERE (((columns.table_schema)::text = "substring"((c.catalog_path)::text, ("position"((c.catalog_path)::text, '/'::text) + 1), length((c.catalog_path)::text))) AND ((columns.table_name)::text = (l.layer_name)::text))))) THEN '(!) Il campo chiave layer della JOIN 3 non esiste'::text WHEN (NOT ((r.table_field_3)::text IN (SELECT columns.column_name FROM information_schema.columns WHERE (((columns.table_schema)::text = "substring"((c.catalog_path)::text, ("position"((c.catalog_path)::text, '/'::text) + 1), length((c.catalog_path)::text))) AND ((columns.table_name)::text = (r.table_name)::text))))) THEN '(!) Il campo chiave relazione della JOIN 3 non esiste'::text ELSE 'OK'::text END AS relation_control FROM (((relation r JOIN catalog c USING (catalog_id)) JOIN layer l USING (layer_id)) JOIN e_relationtype rt USING (relationtype_id));


ALTER TABLE vista_relation OWNER TO postgres;

--
-- Name: vista_style; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW vista_style AS
SELECT s.style_id, s.class_id, s.style_name, s.symbol_name, s.color, s.outlinecolor, s.bgcolor, s.angle, s.size, s.minsize, s.maxsize, s.width, s.maxwidth, s.minwidth, s.locked, s.style_def, s.style_order, s.pattern_id, CASE WHEN (NOT ((s.symbol_name)::text IN (SELECT symbol.symbol_name FROM symbol))) THEN '(!) Il simbolo non esiste'::text WHEN (s.style_order = (SELECT style.style_order FROM style WHERE ((style.style_id <> s.style_id) AND (style.class_id = s.class_id)))) THEN '(!) Due stili con lo stesso ordine'::text WHEN (((s.color IS NULL) AND (s.outlinecolor IS NULL)) AND (s.bgcolor IS NULL)) THEN '(!) Stile senza colore'::text WHEN ((s.symbol_name IS NOT NULL) AND (s.size IS NULL)) THEN '(!) Stile senza dimensione'::text ELSE 'OK'::text END AS style_control FROM (style s LEFT JOIN symbol USING (symbol_name)) ORDER BY s.style_order;


ALTER TABLE vista_style OWNER TO postgres;

--
-- Name: vista_version; Type: VIEW; Schema: gisclient_34; Owner: postgres
--

CREATE VIEW vista_version AS
SELECT version.version_id, version.version_name, version.version_date FROM version WHERE ((version.version_key)::text = 'author'::text) ORDER BY version.version_id DESC LIMIT 1;


ALTER TABLE vista_version OWNER TO postgres;

--
-- Name: al_id; Type: DEFAULT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY access_log ALTER COLUMN al_id SET DEFAULT nextval('access_log_al_id_seq'::regclass);


--
-- Name: pattern_id; Type: DEFAULT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY e_pattern ALTER COLUMN pattern_id SET DEFAULT nextval('e_pattern_pattern_id_seq'::regclass);


--
-- Name: exporti18n_id; Type: DEFAULT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY export_i18n ALTER COLUMN exporti18n_id SET DEFAULT nextval('export_i18n_exporti18n_id_seq'::regclass);


--
-- Name: i18nf_id; Type: DEFAULT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY i18n_field ALTER COLUMN i18nf_id SET DEFAULT nextval('i18n_field_i18nf_id_seq'::regclass);


--
-- Name: localization_id; Type: DEFAULT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY localization ALTER COLUMN localization_id SET DEFAULT nextval('localization_localization_id_seq'::regclass);


--
-- Name: usercontext_id; Type: DEFAULT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY usercontext ALTER COLUMN usercontext_id SET DEFAULT nextval('usercontext_usercontext_id_seq'::regclass);


--
-- Name: users_options_id; Type: DEFAULT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY users_options ALTER COLUMN users_options_id SET DEFAULT nextval('users_options_users_options_id_seq'::regclass);


--
-- Name: version_id; Type: DEFAULT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY version ALTER COLUMN version_id SET DEFAULT nextval('version_version_id_seq'::regclass);


--
-- Data for Name: access_log; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY access_log (al_id, al_ip, al_date, al_referer, al_page, al_useragent) FROM stdin;
\.


--
-- Name: access_log_al_id_seq; Type: SEQUENCE SET; Schema: gisclient_34; Owner: postgres
--

SELECT pg_catalog.setval('access_log_al_id_seq', 1, false);


--
-- Data for Name: catalog; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY catalog (catalog_id, catalog_name, project_name, connection_type, catalog_path, catalog_url, catalog_description, files_path, set_extent) FROM stdin;
\.


--
-- Data for Name: catalog_import; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY catalog_import (catalog_import_id, project_name, catalog_import_name, catalog_from, catalog_to, catalog_import_description) FROM stdin;
\.


--
-- Data for Name: class; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY class (class_id, layer_id, class_name, class_title, class_text, expression, maxscale, minscale, class_template, class_order, legendtype_id, symbol_ttf_name, label_font, label_angle, label_color, label_outlinecolor, label_bgcolor, label_size, label_minsize, label_maxsize, label_position, label_antialias, label_free, label_priority, label_wrap, label_buffer, label_force, label_def, locked, class_image, keyimage) FROM stdin;
\.


--
-- Data for Name: e_charset_encodings; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY e_charset_encodings (charset_encodings_id, charset_encodings_name, charset_encodings_order) FROM stdin;
1	ISO-8859-1	1
2	UTF-8	2
\.


--
-- Data for Name: e_conntype; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY e_conntype (conntype_id, conntype_name, conntype_order) FROM stdin;
7	WMS	4
3	SDE	7
6	Postgis	2
8	Oracle Spatial	3
1	Local Folder	1
9	WFS	5
4	OGR	5
\.


--
-- Data for Name: e_datatype; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY e_datatype (datatype_id, datatype_name, datatype_order) FROM stdin;
10	Immagine	\N
15	File	\N
1	Stringa di testo	\N
2	Numero	\N
3	Data	\N
\.


--
-- Data for Name: e_fieldformat; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY e_fieldformat (fieldformat_id, fieldformat_name, fieldformat_format, fieldformat_order) FROM stdin;
1	intero	%d	10
2	decimale (1 cifra)	%01.1f	20
3	decimale (2 cifre)	%01.2f	30
4	stringa	%s	40
\.


--
-- Data for Name: e_fieldtype; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY e_fieldtype (fieldtype_id, fieldtype_name, fieldtype_order) FROM stdin;
1	Standard	\N
2	Collegamento	\N
3	E-mail	\N
10	Intestazione di gruppo	\N
8	Immagine	\N
107	Varianza	\N
106	Deviazione  St	\N
105	Conteggio	\N
104	Max	\N
103	Min	\N
102	Media	\N
101	Somma	\N
\.


--
-- Data for Name: e_filetype; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY e_filetype (filetype_id, filetype_name, filetype_order) FROM stdin;
1	File SQL	1
2	File CSV	2
3	File Shape	3
\.


--
-- Data for Name: e_form; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY e_form (id, name, config_file, tab_type, level_destination, form_destination, save_data, parent_level, js, table_name, order_by) FROM stdin;
213	selgroup_layer	selgroup_layer	4	28	\N	selgroup_layer	27	\N	\N	\N
214	selgroup_layer	selgroup_layer	5	28	\N	selgroup_layer	27	\N	\N	\N
16	user	user	0	4	\N	user	2	\N	user	\N
2	progetto	project	0	2	\N	\N	\N	\N	\N	project_name
3	progetto	project	1	2		\N	\N	\N	\N	\N
5	mapset	mapset	0	8	\N	\N	\N	\N	\N	title
6	progetto	project	2	2		project	\N	\N	\N	\N
7	progetto	project	1	2	\N	project	\N	\N	\N	\N
8	temi	theme	0	5	\N	\N	\N	\N	\N	theme_order,theme_title
9	temi	theme	1	5	\N	\N	\N	\N	\N	\N
10	temi	theme	1	5	\N	\N	2	\N	\N	\N
11	temi	theme	2	5	\N	\N	2	\N	\N	\N
12	project_srs	project_srs	0	6	\N	\N	2	\N	\N	\N
13	project_srs	project_srs	1	6	\N	\N	2	\N	\N	\N
14	project_srs	project_srs	2	6	\N	\N	2	\N	\N	\N
23	group	group	50	3	\N	group	2	\N	group	\N
26	mapset	mapset	1	8		\N	2	\N	\N	\N
27	mapset	mapset	1	8	\N	mapset	2	\N	\N	\N
28	mapset	mapset	2	2	\N	mapset	2	\N	\N	\N
34	layer	layer	0	11	\N	\N	10	\N	\N	layer_order,layer_name
35	layer	layer	1	11	\N	layer	10	\N	\N	\N
36	layer	layer	1	11	\N	layer	10	\N	\N	\N
37	layer	layer	2	11	\N	layer	10	\N	\N	\N
38	classi	class	0	12	\N	\N	11	\N	\N	class_order
39	classi	class	1	12	\N	\N	11	\N	\N	\N
40	classi	class	1	12	\N	class	11	\N	\N	\N
41	classi	class	2	12	\N	class	11	\N	\N	\N
42	stili	style	0	14	\N	\N	12	\N	\N	style_order
43	stili	style	1	14	\N	\N	12	\N	\N	\N
44	stili	style	1	14	\N	style	12	\N	\N	\N
45	stili	style	2	14	\N	style	12	\N	\N	\N
50	catalog	catalog	0	7	\N	\N	2	\N	\N	catalog_name
51	catalog	catalog	1	7	\N	\N	2	\N	\N	\N
52	catalog	catalog	1	7	\N	catalog	2	\N	\N	\N
53	catalog	catalog	2	7	\N	catalog	2	\N	\N	\N
70	links	link	0	9		\N	2	\N	\N	link_order,link_name
72	links	link	1	9		\N	2	\N	\N	\N
73	links	link	1	9		\N	2	\N	\N	\N
74	links	link	2	9		\N	2	\N	\N	\N
105	selgroup	selgroup	0	27	\N	\N	2	\N	\N	\N
106	selgroup	selgroup	1	27	\N	\N	2	\N	\N	\N
107	selgroup	selgroup	1	27	\N	\N	2	\N	\N	\N
133	project_admin	admin_project	2	33	\N	\N	2	\N	\N	\N
134	project_admin	admin_project	5	33	\N	admin_project	6	\N	\N	\N
151	user_groups	user_groups	4	46	\N	user_groups	4	\N	\N	\N
152	user_groups	user_groups	5	46	\N	user_groups	4	\N	\N	\N
75	relation	relation_addnew	0	16	\N	\N	13	\N	\N	\N
30	layergroup	layergroup	0	10	\N	layergroup	5	\N	\N	layergroup_order,layergroup_title
31	layergroup	layergroup	1	10	\N	layergroup	5	\N	\N	\N
32	layergroup	layergroup	1	10	\N	layergroup	5	\N	\N	\N
33	layergroup	layergroup	2	10	\N	layergroup	5	\N	\N	\N
84	map_layer	mapset_layergroup	4	22	\N	mapset_layergroup	8	\N	\N	\N
85	map_layer	mapset_layergroup	5	22	\N	mapset_layergroup	8	\N	\N	\N
86	map_layer	mapset_layergroup	0	22	\N	mapset_layergroup	8	\N	\N	\N
170	layer_groups	layer_groups	4	47	\N	layer_groups	11	\N	\N	\N
171	layer_groups	layer_groups	5	47	\N	layer_groups	11	\N	\N	\N
202	project_languages	project_languages	0	48	\N	\N	2	\N	\N	\N
203	project_languages	project_languages	1	48	\N	\N	2	\N	\N	\N
204	authfilter	authfilter	0	49	\N	\N	2	\N	\N	\N
205	authfilter	authfilter	1	49	\N	\N	2	\N	\N	\N
206	layer_authfilter	layer_authfilter	4	50	\N	layer_authfilter	11	\N	\N	\N
207	layer_authfilter	layer_authfilter	5	50	\N	layer_authfilter	11	\N	\N	\N
208	group_authfilter	group_authfilter	0	51	\N	\N	3	\N	\N	\N
209	group_authfilter	group_authfilter	1	51	\N	\N	3	\N	\N	\N
20	group	group	0	3	\N	group	2	\N	group	\N
18	user	user	50	4	\N	user	2	\N	user	\N
58	relation	relation	0	16	\N	\N	11	\N	\N	\N
59	relation	relation	1	16	\N	\N	11	\N	\N	\N
60	relation	relation	1	16	\N	\N	11	\N	\N	\N
61	relation	relation	2	16	\N	\N	11	\N	\N	\N
63	fields	field	1	17	\N	\N	11	\N	\N	\N
64	fields	field	1	17	\N	\N	11	\N	\N	\N
65	fields	field	2	17	\N	\N	11	\N	\N	\N
62	fields	field	0	17	\N	\N	11	\N	\N	relationtype_id,relation_name,field_header,field_name
210	field_groups	field_groups	4	52	\N	field_groups	17	\N	\N	\N
211	field_groups	field_groups	5	52	\N	field_groups	17	\N	\N	\N
212	field_groups	field_groups	0	52	\N	field_groups	17	\N	\N	\N
66	layer_link	layer_link	2	19	\N	\N	11	\N	\N	\N
69	layer_link	layer_link	110	19	\N	\N	11	\N	\N	\N
68	layer_link	layer_link	1	19	\N	\N	11	\N	\N	\N
67	layer_link	layer_link	0	19	\N	\N	11	\N	\N	\N
\.


--
-- Data for Name: e_language; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY e_language (language_id, language_name, language_order) FROM stdin;
en	English	1
fr	Francais	2
de	Deutsch	3
es	Espanol	4
\.


--
-- Data for Name: e_layertype; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY e_layertype (layertype_id, layertype_name, layertype_ms, layertype_order) FROM stdin;
5	annotation          	4	\N
1	point               	0	\N
2	line                	1	\N
3	polygon             	2	\N
4	raster              	3	\N
10	tileraster	100	\N
\.


--
-- Data for Name: e_lblposition; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY e_lblposition (lblposition_id, lblposition_name, lblposition_order) FROM stdin;
1	UL	\N
2	UC	\N
3	UR	\N
4	CL	\N
5	CC	\N
6	CR	\N
7	LL	\N
8	LC	\N
9	LR	\N
10	AUTO	\N
\.


--
-- Data for Name: e_legendtype; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY e_legendtype (legendtype_id, legendtype_name, legendtype_order) FROM stdin;
1	auto	1
0	nessuna	2
\.


--
-- Data for Name: e_level; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY e_level (id, name, parent_name, "order", parent_id, depth, leaf, export, struct_parent_id, "table", admintype_id) FROM stdin;
1	root	\N	1	\N	\N	0	0	\N	\N	2
2	project	project	2	1	0	0	1	1	project	2
3	groups	groups	7	1	0	0	0	1	groups	1
4	users	users	6	1	0	0	0	1	users	1
5	theme	theme	3	2	1	0	5	2	theme	2
6	project_srs	project_srs	4	2	1	1	1	2	project_srs	2
7	catalog	catalog	13	2	1	1	2	2	catalog	2
8	mapset	mapset	15	2	1	0	6	2	mapset	2
9	link	link	15	2	1	1	4	2	link	2
10	layergroup	layergroup	4	5	2	0	1	5	layergroup	2
11	layer	layer	5	10	3	0	1	10	layer	2
12	class	class	6	11	4	0	1	11	class	2
14	style	style	7	12	5	1	1	12	style	2
22	mapset_layergroup	mapset_layergroup	17	8	2	1	1	8	mapset_layergroup	2
27	selgroup	selgroup	\N	2	1	0	8	2	selgroup	2
33	project_admin	project_admin	15	2	1	1	0	2	project_admin	2
45	group_users	user_groups	\N	4	2	1	0	4	user_group	1
46	user_groups	group_users	\N	3	2	1	0	3	user_group	1
32	user_project	project	8	2	1	1	0	2	user_project	2
47	layer_groups	layer_groups	\N	11	4	1	0	11	layer_groups	2
48	project_languages	project	\N	2	1	1	1	2	project_languages	2
49	authfilter	authfilter	8	1	0	1	0	1	authfilter	2
51	group_authfilter	groups	1	3	1	1	0	3	group_authfilter	2
28	selgroup_layer	selgroup_layer	\N	27	2	1	1	27	selgroup_layer	2
16	relation	relation	10	11	4	1	1	11	relation	2
17	field	field	11	11	4	1	2	11	field	2
52	field_groups	field	1	17	5	1	0	17	field_groups	2
50	layer_authfilter	layer	15	11	4	1	0	11	layer_authfilter	2
19	layer_link	layer	12	11	4	1	0	11	layer_link	2
\.


--
-- Data for Name: e_orderby; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY e_orderby (orderby_id, orderby_name, orderby_order) FROM stdin;
0	Nessuno	\N
1	Crescente	\N
2	Decresente	\N
\.


--
-- Data for Name: e_outputformat; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY e_outputformat (outputformat_id, outputformat_name, outputformat_driver, outputformat_mimetype, outputformat_imagemode, outputformat_extension, outputformat_option, outputformat_order) FROM stdin;
1	AGG PNG	AGG/PNG	image/png	RGBA	png	\N	\N
3	AGG JPG	AGG/JPG	image/jpeg	RGBA	jpg	\N	\N
4	PNG 8 bit	GD/PNG	image/png	PC256	png	\N	\N
5	PNG 24 bit	GD/PNG	image/png	RGBA	png	\N	\N
6	PNG 32 bit Trasp	GD/PNG	image/png	RGBA	png	\N	\N
7	AGG Q	AGG/PNG	image/png; mode=8bit	RGBA	png	    FORMATOPTION "QUANTIZE_FORCE=ON"\n    FORMATOPTION "QUANTIZE_DITHER=OFF"\n    FORMATOPTION "QUANTIZE_COLORS=256"	\N
\.


--
-- Data for Name: e_owstype; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY e_owstype (owstype_id, owstype_name, owstype_order) FROM stdin;
1	WMS	1
2	WMTS	2
3	WMS (tiles in cache)	3
4	Mappe Yahoo	9
5	OpenStreetMap	5
6	TMS	4
7	Mappe Google	7
8	Mappe Bing	8
\.


--
-- Data for Name: e_papersize; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY e_papersize (papersize_id, papersize_name, papersize_size, papersize_orientation, papaersize_order) FROM stdin;
1	A4 Verticale	A4	P	\N
2	A4 Orizzontale	A4	L	\N
3	A3 Verticale	A3	P	\N
4	A3 Orizzontale	A3	L	\N
5	A2 Verticale	A2	P	\N
6	A2 Orizzontale	A2	L	\N
\.


--
-- Data for Name: e_pattern; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY e_pattern (pattern_id, pattern_name, pattern_def, pattern_order) FROM stdin;
3	CONT_TETTONICI	PATTERN 1 10 END	\N
\.


--
-- Name: e_pattern_pattern_id_seq; Type: SEQUENCE SET; Schema: gisclient_34; Owner: postgres
--

SELECT pg_catalog.setval('e_pattern_pattern_id_seq', 3, true);


--
-- Data for Name: e_relationtype; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY e_relationtype (relationtype_id, relationtype_name, relationtype_order) FROM stdin;
1	Dettaglio (1 a 1)	\N
2	Secondaria (Info 1 a molti)	\N
100	Secondaria + grafico	\N
\.


--
-- Data for Name: e_resultype; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY e_resultype (resultype_id, resultype_name, resultype_order) FROM stdin;
3	Singolo oggetto e tabella	1
4	Non visualizzato	4
2	Tabella	3
1	Singolo oggetto	2
\.


--
-- Data for Name: e_searchable; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY e_searchable (searchable_id, searchable_name, searchable_order) FROM stdin;
0	Non ricercabile	0
1	Visualizzato in ricerca	1
2	Solo ricerca veloce	2
\.


--
-- Data for Name: e_searchtype; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY e_searchtype (searchtype_id, searchtype_name, searchtype_order) FROM stdin;
4	Numerico	\N
5	Data	\N
1	Testo	\N
2	Parte di testo	\N
3	Lista di valori	\N
0	Nessuno	\N
\.


--
-- Data for Name: e_sizeunits; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY e_sizeunits (sizeunits_id, sizeunits_name, sizeunits_order) FROM stdin;
2	feet	\N
3	inches	\N
1	pixels	\N
4	kilometers	\N
5	meters	\N
6	miles	\N
7	dd	\N
\.


--
-- Data for Name: e_symbolcategory; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY e_symbolcategory (symbolcategory_id, symbolcategory_name, symbolcategory_order) FROM stdin;
1	Tutti	\N
\.


--
-- Data for Name: export_i18n; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY export_i18n (exporti18n_id, table_name, field_name, project_name, pkey_id, language_id, value, original_value) FROM stdin;
\.


--
-- Name: export_i18n_exporti18n_id_seq; Type: SEQUENCE SET; Schema: gisclient_34; Owner: postgres
--

SELECT pg_catalog.setval('export_i18n_exporti18n_id_seq', 1, false);


--
-- Data for Name: field; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY field (field_id, relation_id, field_name, field_header, fieldtype_id, searchtype_id, resultype_id, field_format, column_width, orderby_id, field_filter, datatype_id, field_order, default_op, layer_id, editable, formula, lookup_table, lookup_id, lookup_name, filter_field_name) FROM stdin;
\.


--
-- Data for Name: field_groups; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY field_groups (field_id, groupname, editable) FROM stdin;
\.


--
-- Data for Name: font; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY font (font_name, file_name) FROM stdin;
\.


--
-- Data for Name: form_level; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY form_level (id, level, mode, form, order_fld, visible) FROM stdin;
520	27	3	213	1	1
521	28	1	214	1	1
1	1	3	2	1	1
2	2	0	3	1	1
5	2	3	5	8	1
7	2	1	7	1	1
8	2	2	6	1	1
14	2	3	12	3	1
15	6	1	13	1	1
16	6	2	13	1	1
17	6	0	13	1	1
19	8	0	26	1	1
20	8	1	27	1	1
21	8	2	28	1	1
22	5	0	9	1	1
23	5	1	10	1	1
24	5	2	11	1	1
25	5	3	30	3	1
26	10	0	31	1	1
27	10	1	32	1	1
28	10	2	33	1	1
29	10	3	34	3	1
30	11	0	35	1	1
31	11	1	36	1	1
32	11	2	37	1	1
34	12	0	39	1	1
35	12	1	40	1	1
36	12	2	41	2	1
37	12	3	42	3	1
38	14	0	43	1	1
39	14	1	44	1	1
40	14	2	45	1	1
46	7	0	51	1	1
47	7	1	52	1	1
48	7	2	53	1	1
54	16	0	59	1	1
55	16	1	60	1	1
56	16	2	61	1	1
57	17	0	63	1	1
58	17	1	64	1	1
59	17	2	65	1	1
63	2	3	70	7	1
64	9	0	72	1	1
65	9	1	73	1	1
66	9	2	74	1	1
77	8	3	84	6	1
78	22	1	85	1	1
98	2	3	105	6	1
99	27	1	106	1	1
101	27	0	107	1	1
127	33	1	134	15	1
131	2	3	133	15	1
132	27	2	106	1	1
164	1	3	16	3	1
165	4	0	18	1	1
166	4	1	18	1	1
167	4	2	18	1	1
168	1	3	20	2	1
169	3	0	23	1	1
170	3	1	23	1	1
171	3	2	23	1	1
176	46	1	152	1	1
79	22	-1	86	2	1
69	16	1	75	2	0
100	27	2	105	2	0
33	11	3	38	3	1
51	11	3	58	4	1
52	11	3	62	5	1
200	11	0	170	7	1
201	47	1	171	1	1
202	47	3	171	1	1
203	47	2	171	1	1
504	48	0	203	1	1
505	48	1	203	1	1
506	48	2	203	1	1
507	2	3	202	1	1
508	49	0	205	1	1
509	49	1	205	1	1
510	49	2	205	1	1
513	50	1	207	1	1
515	51	0	209	1	1
516	51	1	209	1	1
517	51	2	209	1	1
518	17	0	210	1	1
519	52	1	211	1	1
53	11	3	66	6	1
60	19	0	67	1	1
61	19	1	68	1	1
62	19	1	69	2	1
175	4	3	151	2	1
163	27	3	151	1	0
511	1	3	204	4	0
512	11	3	206	8	0
514	3	3	208	3	0
4	2	3	8	4	1
45	2	3	50	5	1
\.


--
-- Data for Name: groups; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY groups (groupname, description) FROM stdin;
\.


--
-- Data for Name: i18n_field; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY i18n_field (i18nf_id, table_name, field_name) FROM stdin;
22	layer	template
23	layer	header
24	layer	footer
\.


--
-- Name: i18n_field_i18nf_id_seq; Type: SEQUENCE SET; Schema: gisclient_34; Owner: postgres
--

SELECT pg_catalog.setval('i18n_field_i18nf_id_seq', 1, false);


--
-- Data for Name: layer; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY layer (layer_id, layergroup_id, layer_name, layertype_id, catalog_id, data, data_geom, data_unique, data_srid, data_filter, classitem, labelitem, labelsizeitem, labelminscale, labelmaxscale, maxscale, minscale, symbolscale, opacity, maxfeatures, sizeunits_id, layer_def, metadata, template, header, footer, tolerance, layer_order, queryable, layer_title, zoom_buffer, group_object, selection_color, papersize_id, toleranceunits_id, selection_width, selection_info, hidden, private, postlabelcache, maxvectfeatures, data_type, last_update, data_extent, searchable_id, hide_vector_geom) FROM stdin;
\.


--
-- Data for Name: layer_groups; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY layer_groups (layer_id, groupname, wms, wfs, wfst, layer_name, layer_groups_id) FROM stdin;
\.


--
-- Name: layer_groups_seq; Type: SEQUENCE SET; Schema: gisclient_34; Owner: postgres
--

SELECT pg_catalog.setval('layer_groups_seq', 1, false);


--
-- Data for Name: layer_link; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY layer_link (link_id, resultype_id, layer_id) FROM stdin;
\.


--
-- Data for Name: layergroup; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY layergroup (layergroup_id, theme_id, layergroup_name, layergroup_title, layergroup_maxscale, layergroup_minscale, layergroup_smbscale, layergroup_order, locked, multi, hidden, isbaselayer, tiletype_id, sld, style, url, owstype_id, outputformat_id, layers, parameters, gutter, transition, tree_group, layergroup_description, buffer, tiles_extent, tiles_extent_srid, layergroup_single, metadata_url, opacity, tile_origin, tile_resolutions, tile_matrix_set) FROM stdin;
\.


--
-- Data for Name: link; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY link (link_id, project_name, link_name, link_def, link_order, winw, winh) FROM stdin;
\.


--
-- Data for Name: localization; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY localization (localization_id, project_name, i18nf_id, pkey_id, language_id, value) FROM stdin;
\.


--
-- Name: localization_localization_id_seq; Type: SEQUENCE SET; Schema: gisclient_34; Owner: postgres
--

SELECT pg_catalog.setval('localization_localization_id_seq', 1, false);


--
-- Data for Name: mapset; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY mapset (mapset_name, project_name, mapset_title, mapset_description, template, mapset_extent, page_size, filter_data, dl_image_res, imagelabel, bg_color, refmap_extent, test_extent, mapset_srid, mapset_def, mapset_group, private, sizeunits_id, static_reference, metadata, mapset_note, mask, maxscale, minscale, mapset_scales, displayprojection, mapset_scale_type, mapset_order, mapset_tiles) FROM stdin;
\.


--
-- Data for Name: mapset_layergroup; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY mapset_layergroup (mapset_name, layergroup_id, status, refmap, hide) FROM stdin;
\.


--
-- Data for Name: project; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY project (project_name, project_title, project_description, base_path, base_url, project_extent, sel_user_color, sel_transparency, imagelabel_font, imagelabel_text, imagelabel_offset_x, imagelabel_offset_y, imagelabel_position, icon_w, icon_h, history, project_srid, imagelabel_size, imagelabel_color, login_page, project_note, include_outputformats, include_legend, include_metadata, xc, yc, max_extent_scale, default_language_id, charset_encodings_id, legend_font_size) FROM stdin;
\.


--
-- Data for Name: project_admin; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY project_admin (project_name, username) FROM stdin;
\.


--
-- Data for Name: project_languages; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY project_languages (project_name, language_id) FROM stdin;
\.


--
-- Data for Name: project_srs; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY project_srs (project_name, srid, projparam, max_extent, resolutions) FROM stdin;
\.


--
-- Data for Name: qt; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY qt (qt_id, theme_id, layer_id, qt_name, max_rows, papersize_id, edit_url, groupobject, selection_color, qt_order, qtresultype_id, qt_filter, zoom_buffer, qt_title) FROM stdin;
\.


--
-- Data for Name: qt_field; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY qt_field (qtfield_id, qt_id, qtrelation_id, qtfield_name, field_header, fieldtype_id, searchtype_id, resultype_id, field_format, column_width, orderby_id, field_filter, datatype_id, qtfield_order, default_op, editable, formula, lookup_table, lookup_id, lookup_name, filter_field_name) FROM stdin;
\.


--
-- Data for Name: qt_link; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY qt_link (qt_id, link_id, resultype_id) FROM stdin;
\.


--
-- Data for Name: qt_relation; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY qt_relation (qtrelation_id, qt_id, catalog_id, qtrelation_name, qtrelationtype_id, data_field_1, data_field_2, data_field_3, table_name, table_field_1, table_field_2, table_field_3, language_id) FROM stdin;
\.


--
-- Data for Name: relation; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY relation (relation_id, catalog_id, relation_name, relationtype_id, data_field_1, data_field_2, data_field_3, table_name, table_field_1, table_field_2, table_field_3, language_id, layer_id, relation_title) FROM stdin;
\.


--
-- Data for Name: selgroup; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY selgroup (selgroup_id, project_name, selgroup_name, selgroup_title, selgroup_order) FROM stdin;
\.


--
-- Data for Name: selgroup_layer; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY selgroup_layer (selgroup_id, layer_id) FROM stdin;
\.


--
-- Data for Name: style; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY style (style_id, class_id, style_name, symbol_name, color, outlinecolor, bgcolor, angle, size, minsize, maxsize, width, maxwidth, minwidth, locked, style_def, style_order, pattern_id) FROM stdin;
\.


--
-- Data for Name: symbol; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY symbol (symbol_name, symbolcategory_id, icontype, symbol_image, symbol_def, symbol_type, font_name, ascii_code, filled, points, image) FROM stdin;
\.


--
-- Data for Name: theme; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY theme (theme_id, project_name, theme_name, theme_title, theme_order, locked, theme_single, radio, copyright_string) FROM stdin;
\.


--
-- Data for Name: theme_version; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY theme_version (theme_id, theme_version) FROM stdin;
\.


--
-- Name: theme_version_id_seq; Type: SEQUENCE SET; Schema: gisclient_34; Owner: postgres
--

SELECT pg_catalog.setval('theme_version_id_seq', 5, true);


--
-- Data for Name: user_group; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY user_group (username, groupname) FROM stdin;
\.


--
-- Data for Name: usercontext; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY usercontext (usercontext_id, username, mapset_name, title, context) FROM stdin;
\.


--
-- Name: usercontext_usercontext_id_seq; Type: SEQUENCE SET; Schema: gisclient_34; Owner: postgres
--

SELECT pg_catalog.setval('usercontext_usercontext_id_seq', 1, false);


--
-- Data for Name: users; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY users (username, pwd, enc_pwd, data_creazione, data_scadenza, data_modifica, attivato, ultimo_accesso, cognome, nome, macaddress, ip, host, controllo, userdata, email) FROM stdin;
admin	\N	21232f297a57a5a743894a0e4a801fc3	\N	\N	\N	1	\N	\N	\N	\N	\N	\N	\N	\N	\N
\.


--
-- Data for Name: users_options; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY users_options (users_options_id, username, option_key, option_value) FROM stdin;
\.


--
-- Name: users_options_users_options_id_seq; Type: SEQUENCE SET; Schema: gisclient_34; Owner: postgres
--

SELECT pg_catalog.setval('users_options_users_options_id_seq', 1, false);


--
-- Data for Name: version; Type: TABLE DATA; Schema: gisclient_34; Owner: postgres
--

COPY version (version_id, version_name, version_date, version_key) FROM stdin;
1	3.4.0	2015-06-15	author
2	3.4.1	2015-10-09	author
3	3.4.2	2016-01-25	author
4	3.4.3	2016-03-08	author
\.


--
-- Name: version_version_id_seq; Type: SEQUENCE SET; Schema: gisclient_34; Owner: postgres
--

SELECT pg_catalog.setval('version_version_id_seq', 4, true);


--
-- Name: 18n_field_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY i18n_field
    ADD CONSTRAINT "18n_field_pkey" PRIMARY KEY (i18nf_id);


--
-- Name: access_log_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY access_log
    ADD CONSTRAINT access_log_pkey PRIMARY KEY (al_id);


--
-- Name: catalog_catalog_name_key; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY catalog
    ADD CONSTRAINT catalog_catalog_name_key UNIQUE (catalog_name, project_name);


--
-- Name: catalog_import_catalog_import_name_key; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY catalog_import
    ADD CONSTRAINT catalog_import_catalog_import_name_key UNIQUE (catalog_import_name, project_name);


--
-- Name: catalog_import_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY catalog_import
    ADD CONSTRAINT catalog_import_pkey PRIMARY KEY (catalog_import_id);


--
-- Name: catalog_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY catalog
    ADD CONSTRAINT catalog_pkey PRIMARY KEY (catalog_id);


--
-- Name: class_layer_id_key; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY class
    ADD CONSTRAINT class_layer_id_key UNIQUE (layer_id, class_name);


--
-- Name: class_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY class
    ADD CONSTRAINT class_pkey PRIMARY KEY (class_id);


--
-- Name: e_charset_encodings_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_charset_encodings
    ADD CONSTRAINT e_charset_encodings_pkey PRIMARY KEY (charset_encodings_id);


--
-- Name: e_conntype_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_conntype
    ADD CONSTRAINT e_conntype_pkey PRIMARY KEY (conntype_id);


--
-- Name: e_datatype_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_datatype
    ADD CONSTRAINT e_datatype_pkey PRIMARY KEY (datatype_id);


--
-- Name: e_fieldformat_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_fieldformat
    ADD CONSTRAINT e_fieldformat_pkey PRIMARY KEY (fieldformat_id);


--
-- Name: e_fieldtype_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_fieldtype
    ADD CONSTRAINT e_fieldtype_pkey PRIMARY KEY (fieldtype_id);


--
-- Name: e_filetype_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_filetype
    ADD CONSTRAINT e_filetype_pkey PRIMARY KEY (filetype_id);


--
-- Name: e_form_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_form
    ADD CONSTRAINT e_form_pkey PRIMARY KEY (id);


--
-- Name: e_language_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_language
    ADD CONSTRAINT e_language_pkey PRIMARY KEY (language_id);


--
-- Name: e_layertype_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_layertype
    ADD CONSTRAINT e_layertype_pkey PRIMARY KEY (layertype_id);


--
-- Name: e_lblposition_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_lblposition
    ADD CONSTRAINT e_lblposition_pkey PRIMARY KEY (lblposition_id);


--
-- Name: e_legendtype_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_legendtype
    ADD CONSTRAINT e_legendtype_pkey PRIMARY KEY (legendtype_id);


--
-- Name: e_level_name_key; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_level
    ADD CONSTRAINT e_level_name_key UNIQUE (name);


--
-- Name: e_livelli_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_level
    ADD CONSTRAINT e_livelli_pkey PRIMARY KEY (id);


--
-- Name: e_orderby_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_orderby
    ADD CONSTRAINT e_orderby_pkey PRIMARY KEY (orderby_id);


--
-- Name: e_outputformat_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_outputformat
    ADD CONSTRAINT e_outputformat_pkey PRIMARY KEY (outputformat_id);


--
-- Name: e_owstype_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_owstype
    ADD CONSTRAINT e_owstype_pkey PRIMARY KEY (owstype_id);


--
-- Name: e_papersize_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_papersize
    ADD CONSTRAINT e_papersize_pkey PRIMARY KEY (papersize_id);


--
-- Name: e_pattern_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_pattern
    ADD CONSTRAINT e_pattern_pkey PRIMARY KEY (pattern_id);


--
-- Name: e_relationtype_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_relationtype
    ADD CONSTRAINT e_relationtype_pkey PRIMARY KEY (relationtype_id);


--
-- Name: e_resultype_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_resultype
    ADD CONSTRAINT e_resultype_pkey PRIMARY KEY (resultype_id);


--
-- Name: e_searchable_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_searchable
    ADD CONSTRAINT e_searchable_pkey PRIMARY KEY (searchable_id);


--
-- Name: e_searchtype_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_searchtype
    ADD CONSTRAINT e_searchtype_pkey PRIMARY KEY (searchtype_id);


--
-- Name: e_sizeunits_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_sizeunits
    ADD CONSTRAINT e_sizeunits_pkey PRIMARY KEY (sizeunits_id);


--
-- Name: e_symbolcategory_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_symbolcategory
    ADD CONSTRAINT e_symbolcategory_pkey PRIMARY KEY (symbolcategory_id);


--
-- Name: export_i18n_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY export_i18n
    ADD CONSTRAINT export_i18n_pkey PRIMARY KEY (exporti18n_id);


--
-- Name: field_field_name_layer_id_key; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY field
    ADD CONSTRAINT field_field_name_layer_id_key UNIQUE (field_name, relation_id, layer_id);


--
-- Name: field_groups_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY field_groups
    ADD CONSTRAINT field_groups_pkey PRIMARY KEY (field_id, groupname);


--
-- Name: field_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY field
    ADD CONSTRAINT field_pkey PRIMARY KEY (field_id);


--
-- Name: font_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY font
    ADD CONSTRAINT font_pkey PRIMARY KEY (font_name);


--
-- Name: groups_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (groupname);


--
-- Name: layer_groups_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY layer_groups
    ADD CONSTRAINT layer_groups_pkey PRIMARY KEY (layer_groups_id);


--
-- Name: layer_layergroup_id_key; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY layer
    ADD CONSTRAINT layer_layergroup_id_key UNIQUE (layergroup_id, layer_name);


--
-- Name: layer_link_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY layer_link
    ADD CONSTRAINT layer_link_pkey PRIMARY KEY (layer_id, link_id);


--
-- Name: layer_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY layer
    ADD CONSTRAINT layer_pkey PRIMARY KEY (layer_id);


--
-- Name: layergroup_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY layergroup
    ADD CONSTRAINT layergroup_pkey PRIMARY KEY (layergroup_id);


--
-- Name: layergroup_theme_key; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY layergroup
    ADD CONSTRAINT layergroup_theme_key UNIQUE (theme_id, layergroup_name);


--
-- Name: link_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY link
    ADD CONSTRAINT link_pkey PRIMARY KEY (link_id);


--
-- Name: livelli_form_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY form_level
    ADD CONSTRAINT livelli_form_pkey PRIMARY KEY (id);


--
-- Name: localization_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY localization
    ADD CONSTRAINT localization_pkey PRIMARY KEY (localization_id);


--
-- Name: mapset_layergroup_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY mapset_layergroup
    ADD CONSTRAINT mapset_layergroup_pkey PRIMARY KEY (mapset_name, layergroup_id);


--
-- Name: mapset_mapset_name_key; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY mapset
    ADD CONSTRAINT mapset_mapset_name_key UNIQUE (mapset_name);


--
-- Name: mapset_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY mapset
    ADD CONSTRAINT mapset_pkey PRIMARY KEY (mapset_name);


--
-- Name: project_admin_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY project_admin
    ADD CONSTRAINT project_admin_pkey PRIMARY KEY (project_name, username);


--
-- Name: project_languages_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY project_languages
    ADD CONSTRAINT project_languages_pkey PRIMARY KEY (project_name, language_id);


--
-- Name: project_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY project
    ADD CONSTRAINT project_pkey PRIMARY KEY (project_name);


--
-- Name: project_srs_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY project_srs
    ADD CONSTRAINT project_srs_pkey PRIMARY KEY (project_name, srid);


--
-- Name: project_theme_id_key; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY theme
    ADD CONSTRAINT project_theme_id_key UNIQUE (project_name, theme_name);


--
-- Name: qt_link_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY qt_link
    ADD CONSTRAINT qt_link_pkey PRIMARY KEY (qt_id, link_id);


--
-- Name: qt_link_qt_id_key; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY qt_link
    ADD CONSTRAINT qt_link_qt_id_key UNIQUE (qt_id, link_id, resultype_id);


--
-- Name: qt_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY qt
    ADD CONSTRAINT qt_pkey PRIMARY KEY (qt_id);


--
-- Name: qtfield_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY qt_field
    ADD CONSTRAINT qtfield_pkey PRIMARY KEY (qtfield_id);


--
-- Name: qtfield_qt_id_key; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY qt_field
    ADD CONSTRAINT qtfield_qt_id_key UNIQUE (qt_id, field_header);


--
-- Name: qtfield_unique_key; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY field
    ADD CONSTRAINT qtfield_unique_key UNIQUE (layer_id, field_header);


--
-- Name: qtrelation_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY qt_relation
    ADD CONSTRAINT qtrelation_pkey PRIMARY KEY (qtrelation_id);


--
-- Name: relation_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY relation
    ADD CONSTRAINT relation_pkey PRIMARY KEY (relation_id);


--
-- Name: selgroup_layer_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY selgroup_layer
    ADD CONSTRAINT selgroup_layer_pkey PRIMARY KEY (layer_id, selgroup_id);


--
-- Name: selgroup_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY selgroup
    ADD CONSTRAINT selgroup_pkey PRIMARY KEY (selgroup_id);


--
-- Name: selgroup_selgroup_name_key; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY selgroup
    ADD CONSTRAINT selgroup_selgroup_name_key UNIQUE (selgroup_name, project_name);


--
-- Name: style_class_id_key; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY style
    ADD CONSTRAINT style_class_id_key UNIQUE (class_id, style_name);


--
-- Name: style_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY style
    ADD CONSTRAINT style_pkey PRIMARY KEY (style_id);


--
-- Name: symbol_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY symbol
    ADD CONSTRAINT symbol_pkey PRIMARY KEY (symbol_name);


--
-- Name: theme_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY theme
    ADD CONSTRAINT theme_pkey PRIMARY KEY (theme_id);


--
-- Name: theme_version_idx; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY theme_version
    ADD CONSTRAINT theme_version_idx PRIMARY KEY (theme_id);


--
-- Name: user_group_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY user_group
    ADD CONSTRAINT user_group_pkey PRIMARY KEY (username, groupname);


--
-- Name: user_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT user_pkey PRIMARY KEY (username);


--
-- Name: usercontext_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY usercontext
    ADD CONSTRAINT usercontext_pkey PRIMARY KEY (usercontext_id);


--
-- Name: users_options_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY users_options
    ADD CONSTRAINT users_options_pkey PRIMARY KEY (users_options_id);


--
-- Name: version_pkey; Type: CONSTRAINT; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY version
    ADD CONSTRAINT version_pkey PRIMARY KEY (version_id);


--
-- Name: fki_; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_ ON relation USING btree (layer_id);


--
-- Name: fki_catalog_conntype_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_catalog_conntype_fkey ON catalog USING btree (connection_type);


--
-- Name: fki_catalog_import_from_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_catalog_import_from_fkey ON catalog_import USING btree (catalog_from);


--
-- Name: fki_catalog_import_project_name_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_catalog_import_project_name_fkey ON catalog_import USING btree (project_name);


--
-- Name: fki_catalog_import_to_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_catalog_import_to_fkey ON catalog_import USING btree (catalog_to);


--
-- Name: fki_catalog_project_name_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_catalog_project_name_fkey ON catalog USING btree (project_name);


--
-- Name: fki_class_layer_id_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_class_layer_id_fkey ON class USING btree (layer_id);


--
-- Name: fki_field_fieldtype_id_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_field_fieldtype_id_fkey ON field USING btree (fieldtype_id);


--
-- Name: fki_layer_id; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_layer_id ON layer_groups USING btree (layer_id);


--
-- Name: fki_layer_layergroup_id; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_layer_layergroup_id ON layer USING btree (layergroup_id);


--
-- Name: fki_layer_link_link_id_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_layer_link_link_id_fkey ON layer_link USING btree (link_id);


--
-- Name: fki_layergroup_theme_id; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_layergroup_theme_id ON layergroup USING btree (theme_id);


--
-- Name: fki_link_project_name_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_link_project_name_fkey ON link USING btree (project_name);


--
-- Name: fki_mapset_layergroup_layergroup_id_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_mapset_layergroup_layergroup_id_fkey ON mapset_layergroup USING btree (layergroup_id);


--
-- Name: fki_mapset_layergroup_mapset_name_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_mapset_layergroup_mapset_name_fkey ON mapset_layergroup USING btree (mapset_name);


--
-- Name: fki_mapset_project_name_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_mapset_project_name_fkey ON mapset USING btree (project_name);


--
-- Name: fki_pattern_id_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_pattern_id_fkey ON style USING btree (pattern_id);


--
-- Name: fki_project_theme_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_project_theme_fkey ON theme USING btree (project_name);


--
-- Name: fki_qt_layer_id_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_qt_layer_id_fkey ON qt USING btree (layer_id);


--
-- Name: fki_qt_link_link_id_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_qt_link_link_id_fkey ON qt_link USING btree (link_id);


--
-- Name: fki_qt_link_qt_id_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_qt_link_qt_id_fkey ON qt_link USING btree (qt_id);


--
-- Name: fki_qtfield_fieldtype_id_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_qtfield_fieldtype_id_fkey ON qt_field USING btree (fieldtype_id);


--
-- Name: fki_qtfields_layer; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_qtfields_layer ON field USING btree (layer_id);


--
-- Name: fki_qtrelation_catalog_id_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_qtrelation_catalog_id_fkey ON qt_relation USING btree (catalog_id);


--
-- Name: fki_qtrelation_qt_id_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_qtrelation_qt_id_fkey ON qt_relation USING btree (qt_id);


--
-- Name: fki_relation_catalog_id_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_relation_catalog_id_fkey ON relation USING btree (catalog_id);


--
-- Name: fki_selgroup_project_name_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_selgroup_project_name_fkey ON selgroup USING btree (project_name);


--
-- Name: fki_style_class_id_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_style_class_id_fkey ON style USING btree (class_id);


--
-- Name: fki_symbol_icontype_id_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_symbol_icontype_id_fkey ON symbol USING btree (icontype);


--
-- Name: fki_symbol_symbolcategory_id_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_symbol_symbolcategory_id_fkey ON symbol USING btree (symbolcategory_id);


--
-- Name: fki_symbol_ttf_fkey; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE INDEX fki_symbol_ttf_fkey ON class USING btree (symbol_ttf_name, label_font);


--
-- Name: qtfield_name_unique; Type: INDEX; Schema: gisclient_34; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX qtfield_name_unique ON field USING btree (layer_id, field_name);


--
-- Name: chk_catalog; Type: TRIGGER; Schema: gisclient_34; Owner: postgres
--

CREATE TRIGGER chk_catalog BEFORE INSERT OR UPDATE ON catalog FOR EACH ROW EXECUTE PROCEDURE check_catalog();


--
-- Name: chk_class; Type: TRIGGER; Schema: gisclient_34; Owner: postgres
--

CREATE TRIGGER chk_class BEFORE INSERT OR UPDATE ON class FOR EACH ROW EXECUTE PROCEDURE check_class();


--
-- Name: delete_relation; Type: TRIGGER; Schema: gisclient_34; Owner: postgres
--

CREATE TRIGGER delete_relation AFTER DELETE ON relation FOR EACH ROW EXECUTE PROCEDURE delete_relation();


--
-- Name: layername; Type: TRIGGER; Schema: gisclient_34; Owner: postgres
--

CREATE TRIGGER layername BEFORE INSERT OR UPDATE ON layer_groups FOR EACH ROW EXECUTE PROCEDURE set_layer_name();


--
-- Name: move_layergroup; Type: TRIGGER; Schema: gisclient_34; Owner: postgres
--

CREATE TRIGGER move_layergroup AFTER UPDATE ON layergroup FOR EACH ROW EXECUTE PROCEDURE move_layergroup();


--
-- Name: set_encpwd; Type: TRIGGER; Schema: gisclient_34; Owner: postgres
--

CREATE TRIGGER set_encpwd BEFORE INSERT OR UPDATE ON users FOR EACH ROW EXECUTE PROCEDURE enc_pwd();


--
-- Name: theme_tr; Type: TRIGGER; Schema: gisclient_34; Owner: postgres
--

CREATE TRIGGER theme_tr AFTER INSERT OR UPDATE ON theme FOR EACH ROW EXECUTE PROCEDURE theme_version_tr();


--
-- Name: catalog_conntype_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY catalog
    ADD CONSTRAINT catalog_conntype_fkey FOREIGN KEY (connection_type) REFERENCES e_conntype(conntype_id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: catalog_import_project_name_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY catalog_import
    ADD CONSTRAINT catalog_import_project_name_fkey FOREIGN KEY (project_name) REFERENCES project(project_name) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: catalog_project_name_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY catalog
    ADD CONSTRAINT catalog_project_name_fkey FOREIGN KEY (project_name) REFERENCES project(project_name) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: class_layer_id_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY class
    ADD CONSTRAINT class_layer_id_fkey FOREIGN KEY (layer_id) REFERENCES layer(layer_id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: e_form_level_destination_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY e_form
    ADD CONSTRAINT e_form_level_destination_fkey FOREIGN KEY (level_destination) REFERENCES e_level(id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: field_fieldtype_id_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY field
    ADD CONSTRAINT field_fieldtype_id_fkey FOREIGN KEY (fieldtype_id) REFERENCES e_fieldtype(fieldtype_id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: field_groups_field_id_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY field_groups
    ADD CONSTRAINT field_groups_field_id_fkey FOREIGN KEY (field_id) REFERENCES field(field_id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: field_layer_id_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY field
    ADD CONSTRAINT field_layer_id_fkey FOREIGN KEY (layer_id) REFERENCES layer(layer_id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: form_level_form_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY form_level
    ADD CONSTRAINT form_level_form_fkey FOREIGN KEY (form) REFERENCES e_form(id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: form_level_level_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY form_level
    ADD CONSTRAINT form_level_level_fkey FOREIGN KEY (level) REFERENCES e_level(id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: i18nfield_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY localization
    ADD CONSTRAINT i18nfield_fkey FOREIGN KEY (i18nf_id) REFERENCES i18n_field(i18nf_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: language_id_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY localization
    ADD CONSTRAINT language_id_fkey FOREIGN KEY (language_id) REFERENCES e_language(language_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: language_id_project_name_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY project_languages
    ADD CONSTRAINT language_id_project_name_fkey FOREIGN KEY (project_name) REFERENCES project(project_name) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: layer_groups_layer_id_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY layer_groups
    ADD CONSTRAINT layer_groups_layer_id_fkey FOREIGN KEY (layer_id) REFERENCES layer(layer_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: layer_layergroup_id_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY layer
    ADD CONSTRAINT layer_layergroup_id_fkey FOREIGN KEY (layergroup_id) REFERENCES layergroup(layergroup_id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: layergroup_theme_id_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY layergroup
    ADD CONSTRAINT layergroup_theme_id_fkey FOREIGN KEY (theme_id) REFERENCES theme(theme_id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: link_project_name_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY link
    ADD CONSTRAINT link_project_name_fkey FOREIGN KEY (project_name) REFERENCES project(project_name) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: localization_project_name_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY localization
    ADD CONSTRAINT localization_project_name_fkey FOREIGN KEY (project_name) REFERENCES project(project_name) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: mapset_layergroup_layergroup_id_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY mapset_layergroup
    ADD CONSTRAINT mapset_layergroup_layergroup_id_fkey FOREIGN KEY (layergroup_id) REFERENCES layergroup(layergroup_id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: mapset_layergroup_mapset_name_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY mapset_layergroup
    ADD CONSTRAINT mapset_layergroup_mapset_name_fkey FOREIGN KEY (mapset_name) REFERENCES mapset(mapset_name) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: mapset_project_name_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY mapset
    ADD CONSTRAINT mapset_project_name_fkey FOREIGN KEY (project_name) REFERENCES project(project_name) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: pattern_id_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY style
    ADD CONSTRAINT pattern_id_fkey FOREIGN KEY (pattern_id) REFERENCES e_pattern(pattern_id) ON UPDATE CASCADE;


--
-- Name: project_srs_project_name_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY project_srs
    ADD CONSTRAINT project_srs_project_name_fkey FOREIGN KEY (project_name) REFERENCES project(project_name) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: qt_link_link_id_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY qt_link
    ADD CONSTRAINT qt_link_link_id_fkey FOREIGN KEY (link_id) REFERENCES link(link_id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: qt_link_qt_id_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY qt_link
    ADD CONSTRAINT qt_link_qt_id_fkey FOREIGN KEY (qt_id) REFERENCES qt(qt_id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: qtfield_fieldtype_id_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY qt_field
    ADD CONSTRAINT qtfield_fieldtype_id_fkey FOREIGN KEY (fieldtype_id) REFERENCES e_fieldtype(fieldtype_id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: qtfield_qt_id_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY qt_field
    ADD CONSTRAINT qtfield_qt_id_fkey FOREIGN KEY (qt_id) REFERENCES qt(qt_id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: qtrelation_catalog_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY qt_relation
    ADD CONSTRAINT qtrelation_catalog_fkey FOREIGN KEY (catalog_id) REFERENCES catalog(catalog_id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: qtrelation_qt_id_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY qt_relation
    ADD CONSTRAINT qtrelation_qt_id_fkey FOREIGN KEY (qt_id) REFERENCES qt(qt_id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: relation_catalog_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY relation
    ADD CONSTRAINT relation_catalog_fkey FOREIGN KEY (catalog_id) REFERENCES catalog(catalog_id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: relation_layer_id_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY relation
    ADD CONSTRAINT relation_layer_id_fkey FOREIGN KEY (layer_id) REFERENCES layer(layer_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: selgroup_layer_layer_id_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY selgroup_layer
    ADD CONSTRAINT selgroup_layer_layer_id_fkey FOREIGN KEY (layer_id) REFERENCES layer(layer_id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: selgroup_layer_selgroup_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY selgroup_layer
    ADD CONSTRAINT selgroup_layer_selgroup_fkey FOREIGN KEY (selgroup_id) REFERENCES selgroup(selgroup_id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: selgroup_project_name_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY selgroup
    ADD CONSTRAINT selgroup_project_name_fkey FOREIGN KEY (project_name) REFERENCES project(project_name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: style_class_id_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY style
    ADD CONSTRAINT style_class_id_fkey FOREIGN KEY (class_id) REFERENCES class(class_id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: symbol_symbolcategory_id_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY symbol
    ADD CONSTRAINT symbol_symbolcategory_id_fkey FOREIGN KEY (symbolcategory_id) REFERENCES e_symbolcategory(symbolcategory_id) MATCH FULL ON UPDATE CASCADE;


--
-- Name: theme_project_name_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY theme
    ADD CONSTRAINT theme_project_name_fkey FOREIGN KEY (project_name) REFERENCES project(project_name) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: theme_version_fk; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY theme_version
    ADD CONSTRAINT theme_version_fk FOREIGN KEY (theme_id) REFERENCES theme(theme_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: user_group_groupname_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY user_group
    ADD CONSTRAINT user_group_groupname_fkey FOREIGN KEY (groupname) REFERENCES groups(groupname) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: user_group_username_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY user_group
    ADD CONSTRAINT user_group_username_fkey FOREIGN KEY (username) REFERENCES users(username) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: username_project_name_fkey; Type: FK CONSTRAINT; Schema: gisclient_34; Owner: postgres
--

ALTER TABLE ONLY project_admin
    ADD CONSTRAINT username_project_name_fkey FOREIGN KEY (project_name) REFERENCES project(project_name) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

