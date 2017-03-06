--
-- PostgreSQL database dump
--

-- Dumped from database version 9.0.4
-- Dumped by pg_dump version 9.4.8
-- Started on 2017-03-05 22:34:31 MSK

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- TOC entry 13 (class 2615 OID 106636754)
-- Name: nir; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA nir;


SET search_path = nir, pg_catalog;

--
-- TOC entry 801 (class 1247 OID 106636758)
-- Name: atrtype; Type: TYPE; Schema: nir; Owner: -
--

CREATE TYPE atrtype AS (
	atype integer,
	aname text,
	avalue text
);


--
-- TOC entry 804 (class 1247 OID 106636761)
-- Name: change_rights_type; Type: TYPE; Schema: nir; Owner: -
--

CREATE TYPE change_rights_type AS (
	n_parent integer,
	parent_id integer,
	parent_name text,
	parent_type integer,
	o_id integer,
	o_name text,
	o_id_type integer
);


--
-- TOC entry 807 (class 1247 OID 106636764)
-- Name: modulerole; Type: TYPE; Schema: nir; Owner: -
--

CREATE TYPE modulerole AS (
	module_role_id integer,
	module_role_mask character varying,
	module_id integer,
	role_id integer
);


--
-- TOC entry 810 (class 1247 OID 106636767)
-- Name: rightss_of_access; Type: TYPE; Schema: nir; Owner: -
--

CREATE TYPE rightss_of_access AS (
	idobject integer,
	idsubject text,
	mask character varying
);


--
-- TOC entry 813 (class 1247 OID 106636770)
-- Name: rightsss_of_access; Type: TYPE; Schema: nir; Owner: -
--

CREATE TYPE rightsss_of_access AS (
	idobject integer,
	idsubject integer,
	mask bit varying
);


--
-- TOC entry 816 (class 1247 OID 106636773)
-- Name: usertype; Type: TYPE; Schema: nir; Owner: -
--

CREATE TYPE usertype AS (
	id_user integer,
	login_user character varying,
	pass_user character varying,
	user_info character varying,
	user_id_system character varying
);


--
-- TOC entry 341 (class 1255 OID 106636855)
-- Name: add_alert(character varying, text); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION add_alert(namess character varying, sql text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
	id integer;
	id_link integer;	
BEGIN
	if exists(select o_id, o_name  from nir.all_templates_view where o_id_type=16 and o_name = namess and user_id_system=current_user) then
		return -1;
	else
		insert into nir.Nir_object (o_name,o_id_type) values (namess,16) returning o_id into id;
-- Добавить связть на самаго себя для указания SQL
		if( id is not null) then
			INSERT INTO nir.Nir_links (l_id1, l_id2, l_id_link_type,l_type_attr_id) 
				VALUES (id, id, 11, cast(2 as smallint)) returning l_id into id_link;
			INSERT INTO nir.Nir_object_value_varchar(ovv_value, ovv_link_id)
				VALUES ( sql, id_link);
			perform nir.set_owner( id );
		end if;
		return id;
	end if;		
END;
$$;


--
-- TOC entry 342 (class 1255 OID 106636856)
-- Name: add_atrs_to_obj(integer, atrtype[]); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION add_atrs_to_obj(iddoc integer, atr atrtype[] DEFAULT ARRAY[]::atrtype[]) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE cnt integer;
	i integer;
	attr nir.atrtype;
	--aname text;
	--val text;
	--typ smallint;
begin		
	cnt=0;
	if( array_length(atr,1)>0 ) then
	FOR i IN 1..array_length(atr,1)
	--FOR attr IN SELECT tab.val FROM UNNEST(atr) as tab(val) 
	LOOP
		attr := atr[i];
		case 
		when attr.atype=1 then perform nir.add_attr_to_obj_int(cast(attr.aname as character varying), cast(attr.avalue as integer), idDoc);
		when attr.atype=2 then perform nir.add_attr_to_obj_varchar(attr.aname, attr.avalue, idDoc);
		when attr.atype=3 then perform nir.add_attr_to_obj_datetime(attr.aname, cast(attr.avalue as timestamp), idDoc);  
		end case;  
		cnt = cnt+1;
	END LOOP;
	end if;
	return cnt; 
end;
$$;


--
-- TOC entry 306 (class 1255 OID 106636857)
-- Name: add_attr_to_doc_date(character varying, date, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION add_attr_to_doc_date(name character varying, value date, doc_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
	return nir.add_attr_to_obj_datetime(name,cast(value to timestamp without time zone),doc_id);
END;
$$;


--
-- TOC entry 308 (class 1255 OID 106636858)
-- Name: add_attr_to_doc_int(character varying, integer, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION add_attr_to_doc_int(name character varying, value integer, doc_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
	return nir.add_attr_to_obj_int(name,value,doc_id);
END;
$$;


--
-- TOC entry 343 (class 1255 OID 106636859)
-- Name: add_attr_to_doc_varchar(character varying, character varying, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION add_attr_to_doc_varchar(name character varying, value character varying, doc_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
	return nir.add_attr_to_obj_varchar(name,value,doc_id);
END;
$$;


--
-- TOC entry 344 (class 1255 OID 106636860)
-- Name: add_attr_to_obj_datetime(character varying, timestamp without time zone, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION add_attr_to_obj_datetime(namess character varying, valuess timestamp without time zone, obj_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
	id_attr integer;	
	id_link integer;	
	id_val integer;
BEGIN
	--проверка, нет ли атрибута с таким же именем у документа
	id_attr := nir.addattr(namess,cast(3 as smallint));	
	if not exists( SELECT l_id FROM nir.Nir_links WHERE l_id1=obj_id 
			AND l_id2=id_attr AND l_id_link_type=5) then
		INSERT INTO nir.Nir_links (l_id1, l_id2, l_id_link_type,l_type_attr_id) 
			VALUES (obj_id, id_attr, 5, 3) returning l_id into id_link;
	else
		id_link := (SELECT l_id FROM nir.Nir_links WHERE l_id1=obj_id
			AND l_id2=id_attr AND l_id_link_type=5 limit 1);
	end if;
	id_val := COALESCE( (SELECT ovd_id FROM nir.Nir_object_value_datetime 
			WHERE ovd_link_id=id_link limit 1),0);
  	if id_val>0 then
		UPDATE nir.Nir_object_value_datetime
			SET ovd_value=valuess WHERE ovd_id=id_val;

	else
  		INSERT INTO nir.Nir_object_value_datetime(ovd_value, ovd_link_id)
			VALUES ( valuess, id_link) returning ovd_id into id_val;
	end if;		
	return id_val;
END;
$$;


--
-- TOC entry 345 (class 1255 OID 106636861)
-- Name: add_attr_to_obj_int(character varying, integer, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION add_attr_to_obj_int(namess character varying, valuess integer, obj_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
	id_attr integer;	
	id_link integer;	
	id_val integer;
BEGIN
	--проверка, нет ли атрибута с таким же именем у документа
	id_attr := nir.addattr(namess,cast(1 as smallint));	
	if not exists( SELECT l_id FROM nir.Nir_links WHERE l_id1=obj_id 
			AND l_id2=id_attr AND l_id_link_type=5) then
		INSERT INTO nir.Nir_links (l_id1, l_id2, l_id_link_type,l_type_attr_id) 
			VALUES (obj_id, id_attr, 5, 1) returning l_id into id_link;
	else
		id_link := (SELECT l_id FROM nir.Nir_links WHERE l_id1=obj_id
			AND l_id2=id_attr AND l_id_link_type=5 limit 1);
	end if;
	id_val := COALESCE( (SELECT obi_id FROM nir.Nir_object_value_int 
			WHERE obi_link_id=id_link limit 1),0);
  	if id_val>0 then
		UPDATE nir.Nir_object_value_int
			SET obi_value=valuess WHERE obi_id=id_val;

	else
  		INSERT INTO nir.Nir_object_value_int(obi_value, obi_link_id)
			VALUES ( valuess, id_link) returning obi_id into id_val;
	end if;		
	return id_val;
END;
$$;


--
-- TOC entry 347 (class 1255 OID 106636862)
-- Name: add_attr_to_obj_varchar(character varying, character varying, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION add_attr_to_obj_varchar(namess character varying, valuess character varying, obj_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
	id_attr integer;	
	id_link integer;	
	id_val integer;
BEGIN
	--проверка, нет ли атрибута с таким же именем у документа
	id_attr := nir.addattr(namess,cast(2 as smallint));	
	if not exists( SELECT l_id FROM nir.Nir_links WHERE l_id1=obj_id 
			AND l_id2=id_attr AND l_id_link_type=5) then
		INSERT INTO nir.Nir_links (l_id1, l_id2, l_id_link_type,l_type_attr_id) 
			VALUES (obj_id, id_attr, 5, 2) returning l_id into id_link;
	else
		id_link := (SELECT l_id FROM nir.Nir_links WHERE l_id1=obj_id
			AND l_id2=id_attr AND l_id_link_type=5 limit 1);
	end if;
	id_val := COALESCE( (SELECT ovv_id FROM nir.Nir_object_value_varchar 
			WHERE ovv_link_id=id_link limit 1),0);
  	if id_val>0 then
		UPDATE nir.Nir_object_value_varchar
			SET ovv_value=valuess WHERE ovv_id=id_val;

	else
  		INSERT INTO nir.Nir_object_value_varchar(ovv_value, ovv_link_id)
			VALUES ( valuess, id_link) returning ovv_id into id_val;
	end if;		
	return id_val;
END;

$$;


--
-- TOC entry 511 (class 1255 OID 106678616)
-- Name: add_catalog_template(character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION add_catalog_template(namess character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 DECLARE 
	idTemp integer;
BEGIN
	if exists(select o_id, o_name  from nir.Nir_object where o_id_type=15 and upper(o_name) = upper(namess) ) then
		return -1;
	else
		insert into nir.Nir_object (o_name,o_id_type) values (namess,15) returning o_id into idTemp;			
		perform nir.set_owner(idTemp);
		return idTemp;
	end if;
END;
$$;


--
-- TOC entry 348 (class 1255 OID 106636863)
-- Name: add_group(character varying, character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION add_group(name character varying, description character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
g_id integer;
BEGIN
    if (upper(name) in( SELECT upper(r_name) FROM nir.nir_role)) then
	return -2;
end if;
    if exists(select group_id from nir.nir_group where gr_sys_name = name) then
	return -1;
    end if;
    INSERT INTO nir.nir_object (o_name, o_id_type) VALUES (name, 14) returning o_id into g_id;
    INSERT INTO nir.nir_group (group_id, group_name, id_object, gr_sys_name) 
        VALUES (g_id, description, g_id, name) returning group_id into g_id;
    --execute 'CREATE GROUP ' || quote_ident($1);
    return g_id;
END;
   $_$;


--
-- TOC entry 350 (class 1255 OID 106636865)
-- Name: add_profile(text, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION add_profile(namess text, user_id integer DEFAULT get_id_curuser()) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE 
	id integer;
BEGIN
	if namess='' then
		namess='Профиль пользователя '|| COALESCE( (select o_name from nir.full_users_view WHERE o_id=$2),''); 
	end if;
  	if not exists( SELECT o_id_1 FROM nir.links_view WHERE o_id_2 = user_id and o_type_1=18 and l_id_link_type = 9 ) then
		insert into nir.nir_object (o_name,o_id_type) values (namess,18) returning o_id into id;
		INSERT INTO nir.nir_links (l_id1, l_id2, l_id_link_type ) VALUES (id, user_id, 9);
	end if;
	id = COALESCE( (SELECT o_id_1 FROM nir.links_view WHERE o_id_2 = user_id and o_type_1=18 and l_id_link_type = 9), 0);
	return id;
END;
$_$;


--
-- TOC entry 351 (class 1255 OID 106636866)
-- Name: add_search_template(character varying, text); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION add_search_template(namess character varying, sql text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
	id integer;
	id_link integer;	
BEGIN
	if exists(select o_id, o_name  from nir.Nir_object where o_id_type=9 and o_name = namess) then
		return -1;
	else
		insert into nir.Nir_object (o_name,o_id_type) values (namess,9) returning o_id into id;
-- Добавить связть на самаго себя для указания SQL
		if( id is not null) then
			INSERT INTO nir.Nir_links (l_id1, l_id2, l_id_link_type,l_type_attr_id) 
				VALUES (id, id, 11, cast(2 as smallint)) returning l_id into id_link;
			INSERT INTO nir.Nir_object_value_varchar(ovv_value, ovv_link_id)
				VALUES ( sql, id_link);
			perform nir.set_owner( id );
		end if;
		return id;
	end if;		
END;
$$;


--
-- TOC entry 352 (class 1255 OID 106636867)
-- Name: add_tags_to_obj(integer, text[]); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION add_tags_to_obj(iddoc integer, tag text[] DEFAULT ARRAY[]::text[]) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE idTag integer;
	nameTag text;	
	cnt integer;
begin		
	cnt=0;
	FOR nameTag IN SELECT tab.val FROM UNNEST(tag) as tab(val) 
	LOOP
		idTag := (select nir.addtag(nameTag));	
		if not exists (select l_id from nir.Nir_links 
			where l_id1=idDoc and l_id2=idTag) then
			insert into nir.Nir_links (l_id1,l_id2, l_id_link_type) 
				values (idDoc, idTag, 4);			
			cnt = cnt+1;
		end if;
	END LOOP;
	return cnt; 
end;
$$;


--
-- TOC entry 353 (class 1255 OID 106636868)
-- Name: add_tema(character varying, text); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION add_tema(namess character varying, context text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
	id integer;
	id_link integer;
	i integer;
BEGIN
	if not exists(select o_id, o_name  from nir.nir_object where o_id_type=17 and upper(o_name) = upper(namess) ) then
		insert into nir.nir_object (o_name,o_id_type) values (namess,17) returning o_id into id;
-- Добавить связть на самаго себя для указания описания
		if( id is not null) then
			INSERT INTO nir.nir_links (l_id1, l_id2, l_id_link_type,l_type_attr_id) 
			VALUES (id, id, 8, 2)  returning l_id into id_link;
			INSERT INTO nir.Nir_object_value_varchar(ovv_value, ovv_link_id)
			VALUES ( context, id_link);
		end if;
	end if;
	id = COALESCE( (select o_id from nir.nir_object where o_id_type=17 and upper(o_name) = upper(namess) ) , 0);
	return id;
END;
$$;


--
-- TOC entry 354 (class 1255 OID 106636869)
-- Name: add_template_doc(character varying, text[], atrtype[]); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION add_template_doc(namess character varying, tag text[] DEFAULT ARRAY[]::text[], atr atrtype[] DEFAULT ARRAY[]::atrtype[]) RETURNS integer
    LANGUAGE plpgsql
    AS $$

 DECLARE 
	idTemp integer;

begin

	if not exists(SELECT o_id FROM nir.Nir_object WHERE o_name=namess AND o_id_type=7) then

		INSERT INTO nir.Nir_object (o_name,o_id_type) values (namess,7) returning o_id into idTemp;

		--добавляем связь с родительским		

		perform nir.add_tags_to_obj(idTemp,tag);

		perform nir.add_atrs_to_obj(idTemp,atr);

		perform nir.set_owner( idTemp );				

	else

		idTemp := -1; --означает, что такой doc уже существует

	end if;

	return idTemp; 

end;

$$;


--
-- TOC entry 355 (class 1255 OID 106636870)
-- Name: add_template_kz(character varying, text[], atrtype[]); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION add_template_kz(namess character varying, tag text[] DEFAULT ARRAY[]::text[], atr atrtype[] DEFAULT ARRAY[]::atrtype[]) RETURNS integer
    LANGUAGE plpgsql
    AS $$

 DECLARE 
	idKZ integer;

begin

	if not exists(SELECT o_id FROM nir.Nir_object WHERE o_name=namess AND o_id_type=8) then

		INSERT INTO nir.Nir_object (o_name,o_id_type) values (namess,8) returning o_id into idKZ;

		--добавляем связь с родительским		

		perform nir.add_tags_to_obj(idKZ,tag);

		perform nir.add_atrs_to_obj(idKZ,atr);	

		perform nir.set_owner( idKZ );			

	else

		idKZ := -1; --означает, что такой doc уже существует

	end if;

	return idKZ; 

end;

$$;


--
-- TOC entry 356 (class 1255 OID 106636871)
-- Name: add_user(character varying, character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION add_user(username character varying, userdesc character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
u_id integer;
BEGIN
    if (upper(username) in( SELECT upper(r_name) FROM nir.nir_role) ) then
	return -2;
	end if;
    if exists(select user_id_system from nir.nir_user where user_id_system = username) then
    return -1;
    end if;
    INSERT INTO nir.nir_object (o_name, o_id_type) VALUES (username, 2) returning o_id into u_id;
    INSERT INTO nir.nir_user (user_id, user_name, user_id_system, user_id_object) 
       VALUES ( u_id, userdesc, username, u_id ) returning user_id into u_id;
    --execute 'CREATE USER ' || quote_ident($1);
    return u_id;

END;
   $_$;


--
-- TOC entry 358 (class 1255 OID 106636872)
-- Name: add_user_to_group(character varying, character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION add_user_to_group(groupname character varying, username character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
   gr_name text;
BEGIN
    gr_name = groupname;
    if not exists(select gr_sys_name from nir.nir_group where gr_sys_name = gr_name) then
	return -2;
    end if;
    if not exists(select user_id_system from nir.nir_user where user_id_system = username) then
	return -1;
    end if;
    if exists(select user_id FROM nir.nir_group_user WHERE user_id = (select user_id from nir.nir_user where user_id_system = username)
	and group_id = (select group_id from nir.nir_group where gr_sys_name = gr_name) ) then
	return -3;
    end if;
    --execute 'ALTER GROUP ' || quote_ident($1) ' ADD USER ' || quote_ident($2);

    INSERT INTO nir.nir_group_user (user_id, group_id) VALUES ((SELECT u.user_id FROM nir.nir_user as u  WHERE u.user_id_system = username), (select g.group_id from nir.nir_group as g where g.gr_sys_name = gr_name));
    return 1;
END;
   $_$;


--
-- TOC entry 359 (class 1255 OID 106636873)
-- Name: add_user_to_obj(integer, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION add_user_to_obj(iddoc integer, iduser integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE id integer;
begin		
	 INSERT INTO nir.Nir_links (l_id1,l_id2,l_id_link_type) values (iddoc,iduser,9) returning l_id into id;
	 return id; 
end;
$$;


--
-- TOC entry 360 (class 1255 OID 106636874)
-- Name: addactions(integer, integer, integer, integer, integer, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION addactions(id_user integer, id_obj integer, reads integer, updates integer, deletes integer, accesss integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$

DECLARE 
	id_link integer;
	id_val integer;
	
BEGIN	
	if not exists( SELECT l_id FROM nir.Nir_links WHERE l_id1=id_user 

			AND l_id2=id_obj AND l_id_link_type=9) then

		insert into nir.Nir_links (l_id1,l_id2, l_id_link_type, l_type_attr_id) values (id_user, id_obj, 9, 4)
		 returning l_id into id_link;
		
	else
			id_link := (SELECT l_id FROM nir.Nir_links WHERE l_id1=id_user
			AND l_id2=id_obj AND l_id_link_type=9 limit 1);
	
	end if;
			id_val := COALESCE( (SELECT vam_id FROM nir.Nir_object_value_act_mask

			WHERE vam_link_id=id_link limit 1),0);

			if id_val>0 then

			UPDATE nir.Nir_object_value_act_mask
			SET vam_value=reads WHERE vam_id=id_val;
			
			UPDATE nir.Nir_object_value_act_mask
			SET vam_value2=updates WHERE vam_id=id_val;

			UPDATE nir.Nir_object_value_act_mask
			SET vam_value3=deletes WHERE vam_id=id_val;

			UPDATE nir.Nir_object_value_act_mask
			SET vam_value4=accesss WHERE vam_id=id_val;

	else

			INSERT INTO nir.Nir_object_value_act_mask(vam_value,vam_value2,vam_value3,vam_value4, vam_link_id)
			VALUES ( reads,updates,deletes,accesss, id_link) returning vam_id into id_val;

	end if;		
	return id_val;

END;

$$;


--
-- TOC entry 361 (class 1255 OID 106636875)
-- Name: addattr(character varying, smallint); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION addattr(namess character varying, type_id smallint DEFAULT 2) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
	id_attr integer;
	id_link integer;
	i integer;
BEGIN
	if not exists(select o_id, o_name  from nir.nir_object where o_id_type=6 and upper(o_name) = upper(namess) ) then
		insert into nir.nir_object (o_name,o_id_type) values (namess,6) returning o_id into id_attr;
-- Добавить связть на самаго себя для указания типа aтрибута
		if( id_attr is not null) then
			INSERT INTO nir.nir_links (l_id1, l_id2, l_id_link_type,l_type_attr_id) 
			VALUES (id_attr, id_attr, 8, type_id);
		end if;
	end if;
	id_attr := COALESCE( (select o_id from nir.nir_object where o_id_type=6 and upper(o_name) = upper(namess) ) , 0);
	return id_attr;
END;
$$;


--
-- TOC entry 362 (class 1255 OID 106636876)
-- Name: addcatalog(character varying, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION addcatalog(namess character varying, parent_id integer DEFAULT 0) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 DECLARE 
	idCatalog integer;
BEGIN
	--проверяем, нет ли у родительского каталога дочернего с таким же именем, который хотим создать
	if not exists(SELECT o_id FROM nir.Nir_object JOIN nir.Nir_links ON l_id1=o_id WHERE l_id2=parent_id AND o_name=namess AND l_id_link_type=1) then
		INSERT INTO nir.Nir_object (o_name,o_id_type) values (namess,4) returning o_id into idCatalog;
		--получаем только что созданный каталог
		--idCatalog := (SELECT o_id FROM Nir_object WHERE o_name = namess ORDER BY o_id DESC LIMIT 1);
		--добавляем связь с родительским		
		if parent_id >0 then
			INSERT INTO nir.Nir_links (l_id1, l_id2, l_id_link_type) VALUES (idCatalog, parent_id, 1);
		end if; 
		perform nir.set_owner( idCatalog );
	else
		idCatalog := -1; --означает, что такой каталог уже существует
	end if;
	return idCatalog; 
END;
$$;


--
-- TOC entry 363 (class 1255 OID 106636877)
-- Name: addcatalog_by_template(character varying, integer, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION addcatalog_by_template(namess character varying, parent_id integer, temp_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 DECLARE 
	idCat integer;
BEGIN
	idCat=nir.addcatalog(namess,parent_id);
	perform nir.clone_catalog(temp_id,idCat);
	return idCat;
END;
$$;


--
-- TOC entry 364 (class 1255 OID 106636878)
-- Name: addcatalog_ext(character varying, integer, text[], atrtype[]); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION addcatalog_ext(namess character varying, parent_id integer, tag text[] DEFAULT ARRAY[]::text[], atr atrtype[] DEFAULT ARRAY[]::atrtype[]) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 DECLARE 
	idDoc integer;
	type_object integer;
	--user_id integer;
begin
	--user_id := 53;
	idDoc = nir.addcatalog(namess,parent_id);
	if idDoc>0 then
		perform nir.add_tags_to_obj(idDoc,tag);
		perform nir.add_atrs_to_obj(idDoc,atr);			
	end if;
	return idDoc; 
end;
$$;


--
-- TOC entry 365 (class 1255 OID 106636879)
-- Name: adddoc(character varying, integer, text[], atrtype[]); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION adddoc(namess character varying, parent_id integer, tag text[] DEFAULT ARRAY[]::text[], atr atrtype[] DEFAULT ARRAY[]::atrtype[]) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 DECLARE idDoc integer;
begin
	if not exists(SELECT o_id FROM nir.Nir_object JOIN nir.Nir_links ON l_id2=o_id WHERE l_id1=parent_id AND o_name=namess AND l_id_link_type=1) then
		INSERT INTO nir.Nir_object (o_name,o_id_type) values (namess,5) returning o_id into idDoc;
		--добавляем связь с родительским		
		if parent_id >0 then
			INSERT INTO nir.Nir_links (l_id1, l_id2, l_id_link_type) VALUES (idDoc, parent_id, 1);
		end if; 
		perform nir.add_tags_to_obj(idDoc,tag);
		perform nir.add_atrs_to_obj(idDoc,atr);	
		perform nir.set_owner( idDoc );			
	else
		idDoc := -1; --означает, что такой doc уже существует
	end if;
	return idDoc; 
end;
$$;


--
-- TOC entry 367 (class 1255 OID 106636880)
-- Name: addkz(integer, character varying, integer, text[], atrtype[]); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION addkz(db integer, namess character varying, user_id integer, tag text[] DEFAULT ARRAY[]::text[], atr atrtype[] DEFAULT ARRAY[]::atrtype[]) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 DECLARE 
	idDoc integer;
	type_object integer;
	--user_id integer;
begin
	if db = 1 then
		type_object := 13;
	else
		type_object := 1;
	end if;	
	--user_id := 53;
	user_id = nir.get_id_curuser();
	if not exists( SELECT o_id FROM nir.Nir_object JOIN nir.Nir_links ON l_id1=o_id WHERE 
		( type_object = 1 and o_id_type = 1 and l_id2 = user_id AND upper(o_name)=upper(namess) and l_id_link_type=9 ) or
		( type_object = 13 and o_id_type = 13 and upper(o_name)=upper(namess) ) ) then
		INSERT INTO nir.Nir_object (o_name,o_id_type) values (namess,type_object) returning o_id into idDoc;
		--добавляем связь с родительским(если это кз)		
		--if type_object = 1 then
		--	INSERT INTO nir.Nir_links (l_id1, l_id2, l_id_link_type) VALUES (idDoc, user_id, 9);
		--end if;	
		perform nir.set_owner(idDoc);
		perform nir.set_access(idDoc,user_id,b'11111');
		perform nir.add_tags_to_obj(idDoc,tag);
		perform nir.add_atrs_to_obj(idDoc,atr);	

		--perform nir.add_user_to_obj(idDoc,user_id);			
	else
		idDoc := -1; --означает, что такая КЗ уже существует
	end if;
	return idDoc; 
end;
$$;


--
-- TOC entry 368 (class 1255 OID 106636881)
-- Name: addkzcomment(integer, character varying, character varying, character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION addkzcomment(id_kz integer, com_text character varying, com_user character varying, com_date character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$

DECLARE 
	idc integer;	
	idlink int;
	iduser int;
BEGIN
	--id_type := COALESCE( (SELECT o_id_type FROM nir.nir_object WHERE o_id = id_kz ) , 0);
	--if (id_type = 1) then
	--insert into nir.nir_kzcomment(kc_id_kz, kc_text, kc_user, kc_date) values( id_kz, com_text, com_user, com_date);
	--returning kc_id_comment into id_type;
 	insert into nir.Nir_object (o_name,o_id_type) values (com_text,10) returning o_id into idc;
	--select o_id into iduser from nir.Nir_object where com_user=o_name and o_id_type=2; 
	iduser=nir.get_id_curuser();
	INSERT INTO nir.Nir_links (l_id1, l_id2, l_id_link_type,l_type_attr_id) 
			VALUES (idc, iduser, 9, 3) returning l_id into idlink;
	INSERT INTO nir.Nir_object_value_datetime(ovd_value, ovd_link_id)
		VALUES ( now(), idlink);
	INSERT INTO nir.Nir_links (l_id1, l_id2, l_id_link_type) 
			VALUES (idc, id_kz, 7);
	return idc;
END;
$$;


--
-- TOC entry 369 (class 1255 OID 106636882)
-- Name: addrole(integer, character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION addrole(id_user integer, mask character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$

DECLARE 
	role_id integer;
	id_val integer;
	
BEGIN
	SELECT count(*) FROM nir.Nir_Role WHERE r_user_id=id_user;
	IF count = 0 THEN
			insert into nir.Nir_Role (r_user_id,r_mask) values (id_user, mask)
			returning r_id into role_id;
	else
			UPDATE nir.Nir_Role
			SET r_mask=mask WHERE r_user_id=id_user;
			role_id = -1;
	end if;	
	return role_id;
END;

$$;


--
-- TOC entry 366 (class 1255 OID 106636883)
-- Name: addtag(character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION addtag(namess character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 --DECLARE objec varchar;
DECLARE idtag integer;
begin
if not exists(select o_id, o_name  from nir.Nir_object where o_id_type=11 and upper(o_name) = upper(namess) ) then
	insert into nir.Nir_object (o_name,o_id_type) values (namess,11);
end if;
idtag := COALESCE( (select o_id from nir.Nir_object where o_id_type=11 and upper(o_name) = upper(namess) ) , 0);
return idtag;
end;

$$;


--
-- TOC entry 370 (class 1255 OID 106636884)
-- Name: adduser(character varying, character varying, character varying, character varying, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION adduser(namess character varying, pass character varying, info character varying, id_system character varying, id_object integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$

DECLARE 
	id_user integer;
	
BEGIN

	if not exists(select o_name  from nir.Nir_object where o_id_type=2 and o_name = namess) then

		insert into nir.Nir_object (o_name,o_id_type) values (namess,2)
		returning o_id into id_user;
		insert into nir.nir_user (u_id, u_login, u_pass, u_info, u_id_system, u_id_object) values (id_user, namess, pass, info, id_system, id_object);

	end if;

	id_user := COALESCE( (select o_id from nir.Nir_object where o_id_type=2 and o_name = namess) , 0);

	return id_user;

END;

$$;


--
-- TOC entry 371 (class 1255 OID 106636885)
-- Name: adduserrole(integer, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION adduserrole(user_id integer, role_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$DECLARE 
	mr_id integer;
	
BEGIN

	insert into nir.Nir_user_role (user_id, role_id) values ( user_id, role_id ) returning user_role_id into mr_id;

	mr_id := COALESCE( (select user_role_id from nir.Nir_user_role where user_role_id = mr_id) , 0);

	return mr_id;

END;$$;


--
-- TOC entry 346 (class 1255 OID 106636886)
-- Name: bit_to_boolean(bit varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION bit_to_boolean(rt bit varying) RETURNS TABLE(isreader boolean, isworker boolean, iseditor boolean, isdirector boolean, isadmin boolean)
    LANGUAGE plpgsql
    AS $$
DECLARE 
BEGIN
	isreader = rt>b'0';
	isworker = rt>b'1';
	iseditor = rt>b'11'; 
	isdirector = rt>b'111';
	isadmin = rt>b'1111';
	RETURN NEXT;	
END;
$$;


--
-- TOC entry 372 (class 1255 OID 106636887)
-- Name: boolean_to_bit(boolean, boolean, boolean, boolean, boolean); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION boolean_to_bit(isreader boolean, isworker boolean, iseditor boolean, isdirector boolean, isadmin boolean) RETURNS bit varying
    LANGUAGE plpgsql
    AS $$
DECLARE 
 rt bit varying;
BEGIN
	rt = b'00000';
	if isreader then rt = rt | b'00001'; end if;
	if isworker then rt = rt | b'00010'; end if;
	if iseditor then rt = rt | b'00100'; end if;
	if isdirector then rt = rt | b'01000'; end if;
	if isadmin then rt = rt | b'10000'; end if;
	RETURN rt;	
END;
$$;


--
-- TOC entry 373 (class 1255 OID 106636888)
-- Name: boolean_to_bit_2(boolean, boolean, boolean, boolean, boolean); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION boolean_to_bit_2(isreader boolean, isworker boolean, iseditor boolean, isdirector boolean, isadmin boolean) RETURNS bit varying
    LANGUAGE plpgsql
    AS $$
DECLARE 
 rt bit varying;
BEGIN
	rt = b'0';
	if isreader then rt = b'1'; end if;
	if isworker then rt = b'11'; end if;
	if iseditor  then rt = b'111'; end if;
	if isdirector then rt = b'1111'; end if;
	if isadmin then rt = b'11111'; end if;
	RETURN rt;	
END;
$$;


--
-- TOC entry 357 (class 1255 OID 106636889)
-- Name: change_mask_korn(integer, character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION change_mask_korn(id_role integer, mask character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$DECLARE 
		result_value integer;
BEGIN
		IF EXISTS( SELECT r_id FROM nir.Nir_role WHERE r_id=id_role ) THEN
			UPDATE nir.Nir_role
			SET r_mask=mask WHERE r_id=id_role;
			result_value = -1;
		ELSE 
			result_value = 0;
		END IF;
		RETURN result_value;
END;$$;


--
-- TOC entry 374 (class 1255 OID 106636890)
-- Name: change_parents_rights(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION change_parents_rights(id_obj integer) RETURNS TABLE(parent_id integer)
    LANGUAGE sql
    AS $_$
WITH recursive parents AS
(
select 1 as n_parent, l_id2 as parent_id, l_id1 as obj_id
  FROM nir.nir_links where l_id1 =$1 and 
	l_id_link_type=1
union all
 SELECT (n_parent+1) as n_parent, l_id2 as parent_id, l_id1 as obj_id
  FROM  parents left join nir.nir_links on parent_id = l_id1
	where l_id_link_type=1 
)
select parent_id
from parents left join nir.nir_object o on obj_id = o.o_id 
	left join nir.nir_object p on parent_id = p.o_id
where o.o_id_type=4 or o.o_id_type=5 
order by n_parent desc;
$_$;


--
-- TOC entry 375 (class 1255 OID 106636891)
-- Name: change_parents_rights(integer, rightsss_of_access[]); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION change_parents_rights(id_obj integer, rightsss_of_access[]) RETURNS TABLE(n_parent integer)
    LANGUAGE plpgsql
    AS $_$
declare
id integer;
count integer;
element_str text;
element nir.change_rights_type;
massive nir.change_rights_type[];
massive_of_parents integer[];
begin 

WITH recursive parents AS
(
select 1 as n_parent, l_id2 as parent_id, l_id1 as obj_id
FROM nir.nir_links where l_id1 =$1 and 
l_id_link_type=1
union all
SELECT (n_parent+1) as n_parent, l_id2 as parent_id, l_id1 as obj_id
FROM parents left join nir.nir_links on parent_id = l_id1
where l_id_link_type=1 
)
select array(select  (parent_id) :: integer
from parents left join nir.nir_object o on obj_id = o.o_id 
left join nir.nir_object p on parent_id = p.o_id
where o.o_id_type=4 or o.o_id_type=5 
order by n_parent desc) as massive_of_parents;
FOR i in 1..array_length(massive_of_parents,1)
	LOOP
	id = massive_of_parents[i];
	insert into nir.rights_access(roa_id_object) values(id);
	--count = count+1;
	end LOOP;

		
end;
$_$;


--
-- TOC entry 376 (class 1255 OID 106636892)
-- Name: changename_alert(integer, character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION changename_alert(id integer, namess character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 DECLARE 
	num integer;
begin	
	if exists(SELECT o_id from nir.all_templates_view where o_id_type=16 and o_name = namess and user_id_system=current_user and o_id<>id ) then
		return -1; -- Такая уже есть
	else
		UPDATE nir.Nir_object SET o_name = namess WHERE o_id = id AND o_id_type=16 returning o_id into num;
		return COALESCE(num,0);
	end if;	
end;
$$;


--
-- TOC entry 377 (class 1255 OID 106636893)
-- Name: changename_attr(integer, character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION changename_attr(id integer, namess character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 DECLARE 
	num integer;
begin	
	if exists(SELECT o_id FROM nir.Nir_object WHERE o_name=namess and o_id_type=6 and o_id<>id) then
		return -1; -- Такая БД уже есть
	else
		UPDATE nir.Nir_object SET o_name = namess WHERE o_id = id AND o_id_type=6 returning o_id into num;
		return COALESCE(num,0);
	end if;	
end;
$$;


--
-- TOC entry 378 (class 1255 OID 106636894)
-- Name: changename_cat_template(integer, character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION changename_cat_template(id integer, namess character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 DECLARE 
	num integer;
begin	
	if exists(SELECT o_id FROM nir.Nir_object WHERE o_name=namess and o_id_type=15 and o_id<>id ) then
		return -1; -- Такая уже есть
	else
		UPDATE nir.Nir_object SET o_name = namess WHERE o_id = id AND o_id_type=15 returning o_id into num;
		return COALESCE(num,0);
	end if;	
end;
$$;


--
-- TOC entry 379 (class 1255 OID 106636895)
-- Name: changename_search_template(integer, character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION changename_search_template(id integer, namess character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 DECLARE 
	num integer;
begin	
	if exists(SELECT o_id FROM nir.Nir_object WHERE o_name=namess and o_id_type=9 and o_id<>id ) then
		return -1; -- Такая уже есть
	else
		UPDATE nir.Nir_object SET o_name = namess WHERE o_id = id AND o_id_type=9 returning o_id into num;
		return COALESCE(num,0);
	end if;	
end;
$$;


--
-- TOC entry 380 (class 1255 OID 106636896)
-- Name: changename_tag(integer, character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION changename_tag(id integer, namess character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 DECLARE 
	num integer;
begin	
	if exists(SELECT o_id FROM nir.Nir_object WHERE o_name=namess and o_id_type=11 and o_id<>id ) then
		return -1; -- Такая уже есть
	else
		UPDATE nir.Nir_object SET o_name = namess WHERE o_id = id AND o_id_type=11 returning o_id into num;
		return COALESCE(num,0);
	end if;	
end;
$$;


--
-- TOC entry 381 (class 1255 OID 106636897)
-- Name: changenamecatalog(integer, integer, character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION changenamecatalog(id integer, parent_id integer, namess character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 DECLARE 
	id_check integer;
begin
	--получаем каталоги из Nir_object с таким же именем, которое м\хотим присвоить
	if not exists(SELECT l_id FROM nir.Nir_object join nir.Nir_links 
			on o_id=l_id1
			WHERE l_id2=parent_id 
			AND o_name=namess AND l_id_link_type=1 AND l_id1<>id) then		
		UPDATE nir.Nir_object SET o_name = namess WHERE o_id = id AND o_id_type=4 returning o_id into id_check;
		if id_check is null then
			return 0;
		else
			return 1;
		end if;
	else
		return -1;		
	end if;	
end;
$$;


--
-- TOC entry 383 (class 1255 OID 106636898)
-- Name: changenamedb(integer, character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION changenamedb(id integer, namess character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 DECLARE 
	num integer;
begin	
	if exists(SELECT o_id FROM nir.Nir_object WHERE o_name=namess and o_id_type=13 and o_id<>id) then
		return -1; -- Такая БД уже есть
	else
		UPDATE nir.Nir_object SET o_name = namess WHERE o_id = id AND o_id_type=13 returning o_id into num;
		return COALESCE(num,0);
	end if;	
end;
$$;


--
-- TOC entry 384 (class 1255 OID 106636899)
-- Name: changenamedoc(integer, integer, character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION changenamedoc(id integer, parent_id integer, namess character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
	if not exists(SELECT o_id FROM nir.Nir_object JOIN nir.Nir_links ON l_id1=o_id WHERE l_id2=parent_id AND o_name=namess AND l_id_link_type=1) then
		UPDATE nir.Nir_object SET o_name = namess WHERE o_id = id AND o_id_type=5;
		if exists(SELECT o_id FROM nir.Nir_object JOIN nir.Nir_links ON l_id1=o_id WHERE l_id2=parent_id AND o_name=namess AND l_id_link_type=1) then
			return 1;
		else
			return 0;
		end if;	
	end if;
	return -1;	
END;
$$;


--
-- TOC entry 385 (class 1255 OID 106636900)
-- Name: changenamekz(integer, character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION changenamekz(id integer, namess character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 DECLARE 
	num integer;
	user_id integer;
begin	
	user_id = (select l_id2 from nir.Nir_links WHERE l_id1=id AND l_id_link_type=9 limit 1);
	if exists(SELECT l_id FROM nir.Nir_object JOIN nir.Nir_links ON l_id1=o_id 
		WHERE l_id1<> id AND l_id2=user_id AND o_name=namess AND l_id_link_type=9) then
		return -1;
	else
		UPDATE nir.Nir_object SET o_name = namess WHERE o_id = id AND o_id_type=1 returning o_id into num;
		return COALESCE(num,0);
	end if;	
end;
$$;


--
-- TOC entry 386 (class 1255 OID 106636901)
-- Name: clear_atrs_profile(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION clear_atrs_profile(iduser integer DEFAULT get_id_curuser()) RETURNS integer
    LANGUAGE plpgsql
    AS $$
begin			
	delete from nir.Nir_links WHERE l_id1 in ( select profile_id from nir.user_profile_view where user_id=iduser )  AND l_id2 in 
		(select o_id from nir.Nir_object  where o_id_type=6) ;
	return 1;
end;
$$;


--
-- TOC entry 387 (class 1255 OID 106636902)
-- Name: clone_catalog(integer, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION clone_catalog(src_id integer, dest_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 DECLARE 
	idNew integer;
	cid int;
	cname text;
	sum int;
BEGIN	
	sum=0;
	FOR cid, cname IN SELECT obj_id, obj_name FROM nir.cats_of_cat_view where parent_id=src_id
	LOOP
		idNew = nir.addcatalog(cname,dest_id);	
		perform nir.clone_catalog(cid,idNew);
		sum = sum+1;
	END LOOP;
	return sum;
END;
$$;


--
-- TOC entry 388 (class 1255 OID 106636903)
-- Name: clone_catalog_to_template(character varying, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION clone_catalog_to_template(namess character varying, cat_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 DECLARE 
	idTemp integer;
	cid int;
	cname text;
BEGIN
	if exists(select o_id, o_name  from nir.Nir_object where o_id_type=15 and upper(o_name) = upper(namess) ) then
		return -1;
	else
		insert into nir.Nir_object (o_name,o_id_type) values (namess,15) returning o_id into idTemp;	
		perform nir.clone_catalog(cat_id,idTemp);
		return idTemp;
	end if;
END;
$$;


--
-- TOC entry 389 (class 1255 OID 106636904)
-- Name: copy_alert(integer, text); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION copy_alert(idtemp integer, name1 text DEFAULT NULL::text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
	idnew integer;	
	idtype int;
	namess text;
	--val text;
	--typ smallint;
begin		
	if( name1 is NULL) then
		namess = COALESCE( (select o_name from nir.nir_object where o_id=idtemp),'' );
		namess = 'копия ' || namess;
	else
		namess=name1;
	end if;

	idtype = COALESCE( (select o_id_type from nir.nir_object where o_id=idtemp), 0);
	if( idtype=16 OR idtype=9) then 
		idnew = nir.add_alert(namess, (SELECT sql_txt  FROM nir.all_search_templates_view where o_id=idTemp) );
	end if;  
	return idnew; 
end;
$$;


--
-- TOC entry 390 (class 1255 OID 106636905)
-- Name: copy_catalog(integer, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION copy_catalog(src_id integer, par_id integer) RETURNS TABLE(id_old integer, file_old text, id_new integer)
    LANGUAGE plpgsql
    AS $$
 DECLARE 
	idNew integer;
	cid int;
	cname text;
	ctype int;	
	nameNew text;
	tagWork text[];
	atrWork nir.atrtype[];
BEGIN	
	nameNew = COALESCE( (select o_name from nir.nir_object where o_id = src_id ), 'копия');
	while exists ( SELECT obj_id  FROM nir.nir_parent_view where upper(obj_name) = upper(nameNew) and parent_id=par_id) loop
		nameNew = 'копия ' || nameNew;
	end loop;
	SELECT array_agg(tag_name) into tagWork from nir.get_tags_obj(src_id);
	SELECT array_agg( (atr_type, atr_name, atr_value)::nir.atrtype ) into atrWork from nir.get_atrs_obj(src_id);
	idNew = (select nir.addcatalog_ext(nameNew, par_id, tagWork, atrWork));
	if idNew <=0 then
		id_old=-1;
		id_new=-1;
		file_old='';
		return next;
	else		
		FOR cid, cname, ctype IN SELECT obj_id, obj_name, obj_type FROM nir.nir_parent_view where parent_id=src_id
		LOOP
			if ctype=4 then
				for id_old, file_old, id_new in select * from nir.copy_catalog(cid,idNew) loop
					return next;
				end loop;
			elsif ctype=5 then
				id_old = cid;
				file_old = (SELECT o_name_1 FROM nir.links_view where o_type_1=12 and l_id_link_type=10 and o_id_2=cid); 
				id_new = (select nir.copy_doc(cid,'',idNew) );
				return next;
			end if;
		END LOOP;		
	end if;
END;
$$;


--
-- TOC entry 391 (class 1255 OID 106636906)
-- Name: copy_doc(integer, character varying, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION copy_doc(iddoc integer, namess character varying, par_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
	tagWork text[];
	atrWork nir.atrtype[];
	idNew int;
	nameNew text;
begin	
	if( namess='' ) then
		nameNew = COALESCE( (select o_name from nir.nir_object where o_id = idDoc ), 'копия');
	else
		nameNew = namess;
	end if;
	while exists ( SELECT obj_id  FROM nir.nir_parent_view where upper(obj_name) = upper(nameNew) and parent_id=par_id) loop
		nameNew = 'копия ' || nameNew;
	end loop;
	SELECT array_agg(tag_name) into tagWork from nir.get_tags_obj(iddoc);
	SELECT array_agg( (atr_type, atr_name, atr_value)::nir.atrtype ) into atrWork from nir.get_atrs_obj(iddoc);
	idNew = (select nir.adddoc(nameNew, par_id, tagWork, atrWork));
	return idNew; 
end;
$$;


--
-- TOC entry 393 (class 1255 OID 106636907)
-- Name: copy_template(integer, text); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION copy_template(idtemp integer, name1 text DEFAULT NULL::text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
	idnew integer;	
	idtype int;
	tags text[];
	atrs nir.atrtype[];
	namess text;
	--val text;
	--typ smallint;
begin		
	if( name1 is NULL) then
		namess = COALESCE( (select o_name from nir.nir_object where o_id=idtemp),'' );
		namess = 'копия ' || namess;
	else
		namess=name1;
	end if;

	idtype = COALESCE( (select o_id_type from nir.nir_object where o_id=idtemp), 0);
	tags =  ARRAY( SELECT tag_name  FROM nir.tags_view where obj_id=idTemp)::text[];
	atrs =  ARRAY(SELECT ROW(cast(atr_type as smallint), atr_name, atr_value)::nir.atrtype as atr  FROM nir.atrs_view_2 where obj_id=idTemp)::nir.atrtype[];
	case 
	when idtype=7 then 		
		idnew = nir.add_template_doc(namess, tags, atrs);
	when idtype=8 then 
		idnew = nir.add_template_kz(namess, tags, atrs);		
	when idtype=9 then 
		idnew = nir.add_search_template(namess, (SELECT sql_txt  FROM nir.all_search_templates_view where o_id=idTemp) );
	end case;  
	return idnew; 
end;
$$;


--
-- TOC entry 479 (class 1255 OID 106743678)
-- Name: datafromgetusers(); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION datafromgetusers() RETURNS TABLE(user_id_object integer, user_name character varying)
    LANGUAGE sql
    AS $$
SELECT user_id_object, user_name FROM nir.getusers()
$$;


--
-- TOC entry 394 (class 1255 OID 106636908)
-- Name: del_atrs_from_obj(integer, text[]); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION del_atrs_from_obj(iddoc integer, atr text[]) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin			
	delete from nir.Nir_links WHERE l_id1=iddoc AND l_id2 in 
		(select o_id from nir.Nir_object 
			where o_id_type=6 AND o_name in (select a from UNNEST(atr) a) );
end;
$$;


--
-- TOC entry 395 (class 1255 OID 106636909)
-- Name: del_links_from_obj(integer, integer[]); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION del_links_from_obj(iddoc integer, tag integer[]) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin		
	delete from nir.Nir_links WHERE l_id1=iddoc AND l_id2 in (select a from UNNEST(tag) a);
end;
$$;


--
-- TOC entry 392 (class 1255 OID 106636910)
-- Name: del_tags_from_obj(integer, text[]); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION del_tags_from_obj(iddoc integer, tag text[]) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin			
	delete from nir.Nir_links WHERE l_id1=iddoc AND l_id2 in 
		(select o_id from nir.Nir_object 
			where o_id_type=11 AND o_name in (select a from UNNEST(tag) a) );
end;
$$;


--
-- TOC entry 396 (class 1255 OID 106636911)
-- Name: del_user_from_group(character varying, character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION del_user_from_group(groupname character varying, username character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
   gr_name text;
   u_id integer;
BEGIN
    gr_name = groupname;
    if not exists(select gr_sys_name from nir.nir_group where gr_sys_name = gr_name) then
	return -2;
    end if;
    if not exists(select user_id_system from nir.nir_user where user_id_system = username) then
	return -1;
    end if;
    if not exists(select user_id FROM nir.nir_group_user WHERE user_id = (select user_id from nir.nir_user where user_id_system = username)
	and group_id = (select group_id from nir.nir_group where gr_sys_name = gr_name) ) then
	return -3;
    end if;
      --DELETE FROM nir.Nir_User WHERE user_id_system = username returning user_id into u_id;      
      SELECT user_id INTO u_id FROM nir.nir_user WHERE user_id_system = username;
      DELETE FROM nir.nir_group_user WHERE user_id = u_id and group_id=(select group_id from nir.nir_group where gr_sys_name = gr_name) ;
      --execute 'ALTER GROUP ' || quote_ident($1) ' DROP USER ' || quote_ident($2);
    return 1;    
END;
   $_$;


--
-- TOC entry 397 (class 1255 OID 106636912)
-- Name: delete_right_of_access(integer, integer[]); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION delete_right_of_access(id_object integer, id_users integer[]) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
	count integer;
	id_user integer;
BEGIN
	count = 0;
	FOR i in 1..array_length(id_users,1)
	LOOP
		id_user = id_users[i];
		IF(id_user is not null) THEN
		DELETE FROM nir.rights_access WHERE roa_id_object=id_object AND roa_id_subject = id_user;
		count = count+1;
		ELSE
			count = 0;
		END IF;
	
	END LOOP;
	RETURN count;
END;
$$;


--
-- TOC entry 398 (class 1255 OID 106636913)
-- Name: downloadfile(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION downloadfile(iddoc integer) RETURNS TABLE(id integer, filename character varying)
    LANGUAGE sql
    AS $_$
	SELECT o_id as id, o_name as filename FROM nir.Nir_object 
		JOIN nir.Nir_links ON l_id1=o_id WHERE l_id2=$1 AND l_id_link_type=10;	
$_$;


--
-- TOC entry 399 (class 1255 OID 106636914)
-- Name: drop_alert(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION drop_alert(idcat integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare id int;
begin		
	delete from nir.nir_object where o_id=idCat and o_id_type=16 returning o_id into id; --удаление дока
	return COALESCE(id,-1); 
end;
$$;


--
-- TOC entry 400 (class 1255 OID 106636915)
-- Name: drop_attr(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION drop_attr(id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$ 
DECLARE 
 did integer;
BEGIN
 did=0;
 --if exists(select * from nir.nir_object where o_id=id and o_name like '--%') then
	DELETE FROM nir.Nir_object WHERE o_id = id and o_id_type=6 
		returning o_id into did;
 --end if;
	return COALESCE(did,0);
END;
$$;


--
-- TOC entry 401 (class 1255 OID 106636916)
-- Name: drop_catalog(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION drop_catalog(idcat integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
	--i integer;
	cid int;
	ctype int;
	cname text;
	pid int;
	--obj integer[];
	--objj integer[];
begin		
 --if exists(select * from nir.nir_object where o_id=idcat and ( (o_id_type in (1,13) and o_name like '--%') or o_id_type=4) ) then
 --or exists(select o_id from nir.nir_object where o_id=nir.get_id_top(idcat) and o_name like '--%')  then
--	SELECT array_agg(parent_id, o_id, o_id_type) INTO obj FROM nir.get_objs_in_catalog(idCat);
	FOR  pid,cid,cname,ctype IN SELECT parent_id,o_id,o_name,o_id_type from nir.get_objs_in_catalog( idCat)
	LOOP
		--objj := obj[i];
		
		if ctype=5 then 
			--perform nir.drop_file_by_id_doc(cid); -- удаление ссылки на файл
			perform nir.dropdoc(cid); --удаление дока
		end if;	
		if ctype=4 then 
			--perform nir.dropobj(cid); --удаление рубрики как объекта (с удаление всех связей)
			perform nir.drop_catalog(cid); --удаление рубрики как объекта (с удаление всех связей)
		end if;			
		 
	END LOOP;
	--perform nir.dropdoc(idCat); --удаление дока
	--perform nir.dropobj(cid); --удаление рубрики как объекта (с удаление всех связей)
	return nir.dropobj(idcat); 
--else
--	return 0;
--end if;
end;
$$;


--
-- TOC entry 307 (class 1255 OID 106636917)
-- Name: drop_file(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION drop_file(idfile integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
	DELETE FROM nir.Nir_object WHERE o_id=idfile;
	RETURN 1;
END;			
$$;


--
-- TOC entry 403 (class 1255 OID 106636918)
-- Name: drop_file_by_id_doc(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION drop_file_by_id_doc(iddoc integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
	id_file integer;
BEGIN
	--id_file := (SELECT l_id1 FROM nir.Nir_links WHERE l_id2=iddoc AND l_id_link_type=10); --получение id файла по id документа
	DELETE FROM nir.Nir_object WHERE o_id_type=12 and 
		o_id in (SELECT l_id1 FROM nir.Nir_links WHERE l_id2=iddoc AND l_id_link_type=10) returning o_id into id_file;
	if id_file > 0 then
		RETURN id_file;
	else
		RETURN 0;
	end if;	
END;			
$$;


--
-- TOC entry 402 (class 1255 OID 106636919)
-- Name: drop_group(character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION drop_group(name character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
g_id integer;
BEGIN
    if (upper(name) in( SELECT upper(r_name) FROM nir.nir_role)) then
	return -2;
end if;
    if not exists(select gr_sys_name from nir.nir_group where gr_sys_name = name) then
    return -1;
    end if;
   -- DELETE FROM nir.nir_group_user WHERE group_id = g_id;
    DELETE FROM nir.nir_group WHERE gr_sys_name = name returning group_id into g_id;
    DELETE FROM nir.nir_object WHERE o_id = g_id;
    --execute 'DROP GROUP ' || quote_ident($1);
    return 1;

END;
   $_$;


--
-- TOC entry 382 (class 1255 OID 106636920)
-- Name: drop_search_template(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION drop_search_template(id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$ 
DECLARE 
 did integer;
BEGIN
	DELETE FROM nir.Nir_object WHERE o_id = id AND o_id_type = 9 returning o_id into did;
	return did;
END;
$$;


--
-- TOC entry 405 (class 1255 OID 106636921)
-- Name: drop_tag(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION drop_tag(id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$ 
DECLARE 
 did integer;
BEGIN
 did=0;
 --if exists(select * from nir.nir_object where o_id=id and o_name like '--%') then
	DELETE FROM nir.Nir_object WHERE o_id = id and o_id_type=11 
		returning o_id into did;
 --end if;
	return COALESCE(did,0);
END;
$$;


--
-- TOC entry 406 (class 1255 OID 106636922)
-- Name: drop_template(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION drop_template(id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
BEGIN
	DELETE FROM nir.Nir_object WHERE o_id = id;
	return 1;	
END;
$$;


--
-- TOC entry 404 (class 1255 OID 106636923)
-- Name: drop_user(character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION drop_user(username character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
u_id integer;
BEGIN
    if (upper(username) in( SELECT upper(r_name) FROM nir.nir_role)) then
	return -2;
	end if;
    if not exists(select user_id_system from nir.nir_user where user_id_system = username) then
    return -1;
    end if;
  --  DELETE FROM nir.nir_group_user WHERE user_id = u_id;
    DELETE FROM nir.nir_user WHERE user_id_system = username returning user_id into u_id;
    --DELETE FROM nir.nir_object WHERE o_id = u_id;
    --execute 'DROP USER ' || quote_ident($1);
    return 1;

END;
   $_$;


--
-- TOC entry 407 (class 1255 OID 106636924)
-- Name: dropatr(integer, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION dropatr(id integer, id_parent integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
BEGIN	--удаление связей с атрибутом
	DELETE FROM nir.Nir_links WHERE l_id1 = id AND l_id2 = id_parent AND l_id_link_type = 5;
	if not exists(SELECT l_id FROM nir.Nir_links WHERE l_id2=id_parent AND l_id1=id AND l_id_link_type=5) then
		return 1;
	else
		return 0;	
	end if;	
END;
$$;


--
-- TOC entry 408 (class 1255 OID 106636925)
-- Name: dropcat_template(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION dropcat_template(id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$ 
DECLARE 
 did integer;
BEGIN
 did=0;
 --if exists(select * from nir.nir_object where o_id=id and o_name like '--%') then
	DELETE FROM nir.Nir_object WHERE o_id = id AND o_id_type = 15 returning o_id into did;
 --end if;
	return did;
END;
$$;


--
-- TOC entry 409 (class 1255 OID 106636926)
-- Name: dropcomment(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION dropcomment(id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$ 
DECLARE 
 did integer;
BEGIN
	DELETE FROM nir.Nir_object WHERE o_id = id and o_id_type=10 returning o_id into did;
	return did;
END;
$$;


--
-- TOC entry 410 (class 1255 OID 106636927)
-- Name: dropdoc(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION dropdoc(id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
BEGIN
	--Удаление самого документа из таблицы Nir_object
 --if exists(select * from nir.nir_object where o_id=id and o_name like '--%') 
--or exists(select o_id from nir.nir_object where o_id=nir.get_id_top(id) and o_name like '--%') then
	perform nir.drop_file_by_id_doc(id); -- удаление ссылки на файл
	DELETE FROM nir.Nir_object WHERE o_id = id; 
	return 1;	
 --else
--	return 0;	
 --end if;

END;
$$;


--
-- TOC entry 411 (class 1255 OID 106636928)
-- Name: dropmodule(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION dropmodule(id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$ 

DECLARE 

 did integer;

BEGIN

	DELETE FROM nir.Nir_module WHERE module_id = id returning module_id into did;
	
	return did;

END;

$$;


--
-- TOC entry 412 (class 1255 OID 106636929)
-- Name: dropmodulerole(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION dropmodulerole(id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$ 

DECLARE 

 did integer;

BEGIN

	DELETE FROM nir.Nir_module_role WHERE module_role_id = id returning module_role_id into did;
	
	return did;

END;

$$;


--
-- TOC entry 414 (class 1255 OID 106636930)
-- Name: dropobj(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION dropobj(id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$ 
DECLARE 
 did integer;
BEGIN
	DELETE FROM nir.Nir_object n WHERE n.o_id = id --and 
		--(n.o_name like '--%' or exists(select o.o_id from nir.nir_object o where o.o_id=nir.get_id_top(id) and o.o_name like '--%') ) 
		returning n.o_id into did;
	return did;
END;
$$;


--
-- TOC entry 415 (class 1255 OID 106636931)
-- Name: droprole(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION droprole(id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$ 

DECLARE 

 did integer;

BEGIN

	DELETE FROM nir.Nir_role WHERE r_id = id returning r_id into did;
	
	return did;

END;

$$;


--
-- TOC entry 416 (class 1255 OID 106636932)
-- Name: droptag(integer, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION droptag(id integer, id_parent integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 DECLARE 
BEGIN
	--удаление связей с тегом
	DELETE FROM nir.Nir_links WHERE l_id1 = id AND l_id2 = id_parent AND l_id_link_type = 4;
	--проверка удалился ли объект
	if not exists(SELECT l_id FROM nir.Nir_links WHERE l_id1 = id AND l_id2 = id_parent AND l_id_link_type = 4) then
		return 1;
	else
		return 0;
	end if;		
END;
$$;


--
-- TOC entry 413 (class 1255 OID 106636933)
-- Name: dropuser(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION dropuser(id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$ 

DECLARE 

 did integer;

BEGIN

	DELETE FROM nir.Nir_User WHERE u_id = id returning u_id into did;
	DELETE FROM nir.Nir_object WHERE o_id = id AND o_id_type = 2;

	return did;

END;

$$;


--
-- TOC entry 417 (class 1255 OID 106636934)
-- Name: dropuserrole(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION dropuserrole(id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$ 

DECLARE 

 did integer;

BEGIN

	DELETE FROM nir.Nir_user_role WHERE user_role_id = id returning user_role_id into did;
	
	return did;

END;

$$;


--
-- TOC entry 418 (class 1255 OID 106636935)
-- Name: edit_kzcomment(integer, character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION edit_kzcomment(id integer, namess character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 DECLARE 
	num integer;
begin	
	UPDATE nir.Nir_object SET o_name = namess WHERE o_id = id AND o_id_type=10 returning o_id into num;
	return COALESCE(num,0);	
end;
$$;


--
-- TOC entry 419 (class 1255 OID 106636936)
-- Name: edit_template(integer, character varying, text[], atrtype[]); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION edit_template(id integer, namess character varying, tag text[] DEFAULT ARRAY[]::text[], atr atrtype[] DEFAULT ARRAY[]::atrtype[]) RETURNS integer
    LANGUAGE plpgsql
    AS $$

DECLARE	tagOld text[];
	atrOld text[];	
	tagWork text[];
	atrWork text[];
begin
	UPDATE nir.Nir_object SET o_name = namess WHERE o_id=id; 
	
	SELECT array_agg(tag_name) into tagOld from nir.get_tags_obj(id);

	select array_agg(v.a) into tagWork from 
		( (select a from UNNEST( tagOld) a) except (select a from UNNEST(tag) a) ) v;
	perform nir.del_tags_from_obj(id,tagWork);

	select array_agg(v.a) into tagWork from 
		( (select a from UNNEST( tag) a) except (select a from UNNEST(tagOld) a) ) v;
	perform nir.add_tags_to_obj(id,tagWork);

	SELECT array_agg(atr_name) into atrOld from nir.get_atrs_obj(id);

	select array_agg(v.a) into atrWork from 
		( (select a from UNNEST( atrOld) a) except (select a.aname from UNNEST(atr) a) ) v;
	perform nir.del_atrs_from_obj(id,atrWork);
	
	perform nir.add_atrs_to_obj(id,atr);
	
	return id; 
/*	UPDATE nir.Nir_object SET o_name = namess WHERE o_id=id; 
	SELECT array_agg(tag_name) into tagOld from nir.get_tags_obj(id);
	select array_agg(v.a) into tagWork from 
		( (select a from UNNEST( tagOld) a) except (select a from UNNEST(tag) a) ) v;
	perform nir.del_tags_from_obj(id,tagWork);
	select array_agg(v.a) into tagWork from 
		( (select a from UNNEST( tag) a) except (select a from UNNEST(tagOld) a) ) v;
	perform nir.add_tags_to_obj(id,tagWork);
--	perform nir.add_atrs_to_obj(idDoc,tagWork);
	perform nir.add_atrs_to_obj(id,atr::nir.atrtype[]); 
	return id; */
end;

$$;


--
-- TOC entry 420 (class 1255 OID 106636937)
-- Name: editcatalog(integer, character varying, integer, text[], atrtype[]); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION editcatalog(iddoc integer, namess character varying, parent_id integer, tag text[] DEFAULT ARRAY[]::text[], atr atrtype[] DEFAULT ARRAY[]::atrtype[]) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
	tagOld text[];
	atrOld text[];
	--tagNew text[];
	tagWork text[];
	atrWork text[];
begin
	--UPDATE nir.Nir_object SET o_name = namess WHERE o_id=idDoc;
	perform nir.changenamecatalog(iddoc,parent_id,namess);
	if parent_id >0 then
		UPDATE	nir.Nir_links SET l_id2=parent_id
			WHERE l_id1=idDoc AND l_id_link_type=1;
	end if; 
	
	SELECT array_agg(tag_name) into tagOld from nir.get_tags_obj(iddoc);

	select array_agg(v.a) into tagWork from 
		( (select a from UNNEST( tagOld) a) except (select a from UNNEST(tag) a) ) v;
	perform nir.del_tags_from_obj(idDoc,tagWork);

	select array_agg(v.a) into tagWork from 
		( (select a from UNNEST( tag) a) except (select a from UNNEST(tagOld) a) ) v;
	perform nir.add_tags_to_obj(idDoc,tagWork);

	SELECT array_agg(atr_name) into atrOld from nir.get_atrs_obj(iddoc);

	select array_agg(v.a) into atrWork from 
		( (select a from UNNEST( atrOld) a) except (select a.aname from UNNEST(atr) a) ) v;
	perform nir.del_atrs_from_obj(idDoc,atrWork);
	
	perform nir.add_atrs_to_obj(idDoc,atr);
	
	return idDoc; 
end;
$$;


--
-- TOC entry 421 (class 1255 OID 106636938)
-- Name: editdoc(integer, character varying, integer, text[], atrtype[]); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION editdoc(iddoc integer, namess character varying, parent_id integer, tag text[] DEFAULT ARRAY[]::text[], atr atrtype[] DEFAULT ARRAY[]::atrtype[]) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
	tagOld text[];
	atrOld text[];
	--tagNew text[];
	tagWork text[];
	atrWork text[];
begin
	--UPDATE nir.Nir_object SET o_name = namess WHERE o_id=idDoc;
	perform nir.changenamedoc(iddoc,parent_id,namess);
	if parent_id >0 then
		UPDATE	nir.Nir_links SET l_id2=parent_id
			WHERE l_id1=idDoc AND l_id_link_type=1;
	end if; 
	
	SELECT array_agg(tag_name) into tagOld from nir.get_tags_obj(iddoc);

	select array_agg(v.a) into tagWork from 
		( (select a from UNNEST( tagOld) a) except (select a from UNNEST(tag) a) ) v;
	perform nir.del_tags_from_obj(idDoc,tagWork);

	select array_agg(v.a) into tagWork from 
		( (select a from UNNEST( tag) a) except (select a from UNNEST(tagOld) a) ) v;
	perform nir.add_tags_to_obj(idDoc,tagWork);

	SELECT array_agg(atr_name) into atrOld from nir.get_atrs_obj(iddoc);

	select array_agg(v.a) into atrWork from 
		( (select a from UNNEST( atrOld) a) except (select a.aname from UNNEST(atr) a) ) v;
	perform nir.del_atrs_from_obj(idDoc,atrWork);
	
	perform nir.add_atrs_to_obj(idDoc,atr);
	
	return idDoc; 
end;
$$;


--
-- TOC entry 422 (class 1255 OID 106636939)
-- Name: editkz(integer, integer, character varying, text[], atrtype[]); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION editkz(db integer, idkz integer, namess character varying, tag text[] DEFAULT ARRAY[]::text[], atr atrtype[] DEFAULT ARRAY[]::atrtype[]) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
	tagOld text[];
	atrOld text[];
	tagWork text[];
	atrWork text[];
begin

	--UPDATE nir.Nir_object SET o_name = namess WHERE o_id=idkz;
	if db = 1 then
		perform nir.changenamedb(idkz,namess);
	else	
		perform nir.changenamekz(idkz,namess);
	end if;	

	SELECT array_agg(tag_name) into tagOld from nir.get_tags_obj(idkz);

	select array_agg(v.a) into tagWork from 

		( (select a from UNNEST( tagOld) a) except (select a from UNNEST(tag) a) ) v;

	perform nir.del_tags_from_obj(idkz,tagWork);

	select array_agg(v.a) into tagWork from 

		( (select a from UNNEST( tag) a) except (select a from UNNEST(tagOld) a) ) v;

	perform nir.add_tags_to_obj(idkz,tagWork);

--	perform nir.add_atrs_to_obj(idDoc,tagWork);
--	perform nir.add_atrs_to_obj(idkz,atr);	
	SELECT array_agg(atr_name) into atrOld from nir.get_atrs_obj(idkz);

	select array_agg(v.a) into atrWork from 
		( (select a from UNNEST( atrOld) a) except (select a.aname from UNNEST(atr) a) ) v;
	perform nir.del_atrs_from_obj(idkz,atrWork);
	
	perform nir.add_atrs_to_obj(idkz,atr);			

	return idkz; 

end;

$$;


--
-- TOC entry 423 (class 1255 OID 106636940)
-- Name: find_doc(text[], atrtype[]); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION find_doc(array_tag text[] DEFAULT NULL::text[], array_atr atrtype[] DEFAULT NULL::atrtype[]) RETURNS TABLE(o_id integer, o_name text, path text)
    LANGUAGE sql
    AS $_$
select o_id, o_name, nir.get_parent_path(o_id) as path from nir.all_docs_view as d where
not exists(
(select upper(t) from UNNEST($1) as t)
except
(SELECT upper(t.tag_name)
  FROM nir.tags_view t
 where t.obj_id=o_id)
)
AND
not exists
((
select a.aname,a.avalue from UNNEST( $2) as a
)
except
(
SELECT atr_name as aname,atr_value as avalue
  FROM nir.atrs_view_2
 where obj_id=o_id
))
and
not exists
( 
SELECT obj_id, atr_name, atr_value, a.avalue
  FROM nir.atrs_view_2, UNNEST( $2 ) as a 
where atr_name=a.aname and cast(atr_value as text)<>cast(a.avalue as text)
);
$_$;


--
-- TOC entry 424 (class 1255 OID 106636941)
-- Name: find_doc_by_tag(text[]); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION find_doc_by_tag(array_tag text[] DEFAULT NULL::text[]) RETURNS TABLE(o_id integer, o_name text, path text)
    LANGUAGE sql
    AS $_$
select o_id, o_name, nir.get_parent_path(o_id) as path
	from nir.all_docs_view as d where
not exists(
(select upper(t) from UNNEST($1) as t)
except
(SELECT upper(t.tag_name)
  FROM nir.tags_view t
 where t.obj_id=o_id)
);
$_$;


--
-- TOC entry 425 (class 1255 OID 106636942)
-- Name: find_doc_by_tag(integer, text[]); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION find_doc_by_tag(parent_id integer, array_tag text[] DEFAULT NULL::text[]) RETURNS TABLE(o_id integer, o_name text, path text)
    LANGUAGE sql
    AS $_$
select o_id, o_name, nir.get_parent_path(o_id) as path
 from nir.get_objs_in_catalog($1) as d where
 o_id_type=5 and
not exists(
(select upper(t) from UNNEST($2) as t)
except
(SELECT upper(t.tag_name)
  FROM nir.tags_view t
 where t.obj_id=o_id)
);
$_$;


--
-- TOC entry 426 (class 1255 OID 106636943)
-- Name: get_access(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_access(object_id integer) RETURNS TABLE(isreader boolean, isworker boolean, iseditor boolean, isdirector boolean, isadmin boolean)
    LANGUAGE plpgsql
    AS $_$
DECLARE 
 rt bit varying;
 objid int;
 parid int;
 user_id int;
--isreader boolean;
 --isworker boolean;
 --iseditor boolean; 
 --isdirector boolean;
 --isadmin boolean;
BEGIN
	user_id = COALESCE((select o_id from nir.full_users_view where user_id_system=current_user),0);
	objid=$1;
	rt = COALESCE((SELECT  roa_bit_map from nir.rights_access 
		    where roa_id_object=objid and roa_id_subject = user_id), b'0');
	parid = COALESCE((select l_id2 from nir.nir_links where l_id1=objid and l_id_link_type=1),0);
	WHILE ( rt=b'0' AND parid>0 ) LOOP
		objid=parid; 	
		rt = COALESCE((SELECT  roa_bit_map from nir.rights_access 
		    where roa_id_object=objid and roa_id_subject = user_id),b'0');
		parid = COALESCE((select l_id2 from nir.nir_links where l_id1=objid and l_id_link_type=1),0);	
	END LOOP;
	isreader = rt>b'0';
	isworker = rt>b'1';
	iseditor = rt>b'11'; 
	isdirector = rt>b'111';
	isadmin = rt>b'1111';
	RETURN NEXT;	
END;
$_$;


--
-- TOC entry 427 (class 1255 OID 106636944)
-- Name: get_access(integer, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_access(object_id integer, user_id integer) RETURNS TABLE(isreader boolean, isworker boolean, iseditor boolean, isdirector boolean, isadmin boolean)
    LANGUAGE plpgsql
    AS $_$
DECLARE 
 rt bit varying;
 objid int;
 parid int;
 --user_id int;
--isreader boolean;
 --isworker boolean;
 --iseditor boolean; 
 --isdirector boolean;
 --isadmin boolean;
BEGIN
--	user_id = COALESCE((select o_id from nir.full_users_view where user_id_system=current_user),0);
	objid=$1;
	rt = COALESCE((SELECT  roa_bit_map from nir.rights_access 
		    where roa_id_object=objid and roa_id_subject = user_id), b'0');
	parid = COALESCE((select l_id2 from nir.nir_links where l_id1=objid and l_id_link_type=1),0);
	WHILE ( rt=b'0' AND parid>0 ) LOOP
		objid=parid; 	
		rt = COALESCE((SELECT  roa_bit_map from nir.rights_access 
		    where roa_id_object=objid and roa_id_subject = user_id),b'0');
		parid = COALESCE((select l_id2 from nir.nir_links where l_id1=objid and l_id_link_type=1),0);	
	END LOOP;
	isreader = rt>b'0';
	isworker = rt>b'1';
	iseditor = rt>b'11'; 
	isdirector = rt>b'111';
	isadmin = rt>b'1111';
	RETURN NEXT;	
END;
$_$;


--
-- TOC entry 428 (class 1255 OID 106636945)
-- Name: get_access_group(integer, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_access_group(object_id integer, user_id integer) RETURNS TABLE(isreader boolean, isworker boolean, iseditor boolean, isdirector boolean, isadmin boolean)
    LANGUAGE plpgsql
    AS $_$
DECLARE 
 rt bit varying;
 objid int;
 parid int;
 --user_id int;
--isreader boolean;
 --isworker boolean;
 --iseditor boolean; 
 --isdirector boolean;
 --isadmin boolean;
BEGIN
--	user_id = COALESCE((select o_id from nir.full_users_view where user_id_system=current_user),0);
	objid=$1;
	rt = COALESCE((SELECT  rog_bit_map from nir.rights_of_groups 
		    where rog_id_object=objid and rog_id_subject = user_id), b'0');
	parid = COALESCE((select l_id2 from nir.nir_links where l_id1=objid and l_id_link_type=1),0);
	WHILE ( rt=b'0' AND parid>0 ) LOOP
		objid=parid; 	
		rt = COALESCE((SELECT  rog_bit_map from nir.rights_of_groups 
		    where rog_id_object=objid and rog_id_subject = user_id),b'0');
		parid = COALESCE((select l_id2 from nir.nir_links where l_id1=objid and l_id_link_type=1),0);	
	END LOOP;
	isreader = rt>b'0';
	isworker = rt>b'1';
	iseditor = rt>b'11'; 
	isdirector = rt>b'111';
	isadmin = rt>b'1111';
	RETURN NEXT;	
END;
$_$;


--
-- TOC entry 429 (class 1255 OID 106636946)
-- Name: get_access_mask(integer, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_access_mask(object_id integer, user_id integer) RETURNS bit varying
    LANGUAGE plpgsql
    AS $_$
DECLARE 
 rt bit varying;
 --objid int;
 --parid int;
 --user_id int;
isreader boolean;
 isworker boolean;
 iseditor boolean; 
 isdirector boolean;
 isadmin boolean;
BEGIN
--	user_id = COALESCE((select o_id from nir.full_users_view where user_id_system=current_user),0);
	select * into isreader , isworker , iseditor , isdirector , isadmin  from nir.get_access($1,$2);
	rt = (select nir.boolean_to_bit( isreader , isworker , iseditor , isdirector , isadmin ));
	RETURN rt;	
END;
$_$;


--
-- TOC entry 430 (class 1255 OID 106636947)
-- Name: get_access_mask_2(integer, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_access_mask_2(object_id integer, user_id integer) RETURNS bit varying
    LANGUAGE plpgsql
    AS $_$
DECLARE 
 rt bit varying;
 --objid int;
 --parid int;
 --user_id int;
isreader boolean;
 isworker boolean;
 iseditor boolean; 
 isdirector boolean;
 isadmin boolean;
BEGIN
--	user_id = COALESCE((select o_id from nir.full_users_view where user_id_system=current_user),0);
	select * into isreader , isworker , iseditor , isdirector , isadmin  from nir.get_access($1,$2);
	rt = (select nir.boolean_to_bit_2( isreader , isworker , iseditor , isdirector , isadmin ));
	RETURN rt;	
END;
$_$;


--
-- TOC entry 431 (class 1255 OID 106636948)
-- Name: get_access_mask_2_for_group(integer, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_access_mask_2_for_group(object_id integer, user_id integer) RETURNS bit varying
    LANGUAGE plpgsql
    AS $_$
DECLARE 
 rt bit varying;
 --objid int;
 --parid int;
 --user_id int;
isreader boolean;
 isworker boolean;
 iseditor boolean; 
 isdirector boolean;
 isadmin boolean;
BEGIN
--	user_id = COALESCE((select o_id from nir.full_users_view where user_id_system=current_user),0);
	select * into isreader , isworker , iseditor , isdirector , isadmin  from nir.get_access_group($1,$2);
	rt = (select nir.boolean_to_bit_2( isreader , isworker , iseditor , isdirector , isadmin ));
	RETURN rt;	
END;
$_$;


--
-- TOC entry 432 (class 1255 OID 106636949)
-- Name: get_all_templates_doc(); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_all_templates_doc() RETURNS TABLE(id integer, name text)
    LANGUAGE plpgsql
    AS $$
DECLARE 
	--temp templates;
BEGIN
	FOR id, name IN SELECT o_id, o_name FROM nir.Nir_object WHERE o_id_type = 7 ORDER BY o_name
	LOOP
		RETURN NEXT ;
	END LOOP;
	RETURN;	

	--list := (SELECT ARRAY(SELECT o_name FROM Nir_object WHERE o_id_type=11));	
	--return list;
END;
$$;


--
-- TOC entry 433 (class 1255 OID 106636950)
-- Name: get_all_templates_kz(); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_all_templates_kz() RETURNS TABLE(id integer, name character varying)
    LANGUAGE sql
    AS $$
	SELECT o_id as id, o_name as name FROM nir.Nir_object WHERE o_id_type = 8 ORDER BY o_name	
$$;


--
-- TOC entry 434 (class 1255 OID 106636951)
-- Name: get_atrs_obj(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_atrs_obj(id integer) RETURNS TABLE(atr_id integer, atr_name text, atr_type smallint, atr_value text)
    LANGUAGE sql
    AS $_$
 select atr_id, atr_name, atr_type, atr_value from nir.atrs_view_2 where obj_id=$1 order by atr_name;
$_$;


--
-- TOC entry 435 (class 1255 OID 106636952)
-- Name: get_cat_of_catalog(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_cat_of_catalog(id_parent integer) RETURNS TABLE(id integer, name character varying)
    LANGUAGE sql
    AS $_$
	SELECT o_id as id, o_name as name
	FROM nir.Nir_object JOIN nir.Nir_links ON o_id=l_id1 WHERE l_id2=$1 AND l_id_link_type=1 AND o_id_type=4 ORDER BY o_name;
$_$;


--
-- TOC entry 436 (class 1255 OID 106636953)
-- Name: get_catalog(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_catalog(id integer) RETURNS text
    LANGUAGE sql
    AS $_$
	SELECT o_name FROM nir.Nir_object WHERE o_id=$1 limit 1;
$_$;


--
-- TOC entry 438 (class 1255 OID 106636954)
-- Name: get_children_list(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_children_list(id_obj integer) RETURNS TABLE(n_children integer, children_id integer, parent_name text, parent_type integer, o_id integer, o_name text, o_id_type integer)
    LANGUAGE sql
    AS $_$
WITH recursive childrens AS
(
select 1 as n_children, l_id1 as children_id, l_id2 as obj_id
  FROM nir.nir_links where l_id2 =$1 and 
	l_id_link_type=1
union all
 SELECT (n_children+1) as n_children, l_id1 as children_id, l_id2 as obj_id
  FROM  childrens left join nir.nir_links on children_id = l_id2
	where l_id_link_type=1 
)
select n_children, children_id, c.o_name as children_name, c.o_id_type::int as children_type,
 o.o_id, o.o_name, o.o_id_type::int
from childrens left join nir.nir_object o on obj_id = o.o_id 
	left join nir.nir_object c on children_id = c.o_id
where o.o_id_type=4 or o.o_id_type=5 
order by n_children desc;
$_$;


--
-- TOC entry 439 (class 1255 OID 106636955)
-- Name: get_count_roles_for_api(); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_count_roles_for_api() RETURNS bigint
    LANGUAGE sql
    AS $$ 
	Select count(*) from nir.nir_role
$$;


--
-- TOC entry 440 (class 1255 OID 106636956)
-- Name: get_curuser(); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_curuser() RETURNS text
    LANGUAGE sql
    AS $$ 
	SELECT current_user::text
$$;


--
-- TOC entry 441 (class 1255 OID 106636957)
-- Name: get_db(); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_db() RETURNS TABLE(iddb integer, namedb text)
    LANGUAGE sql
    AS $$
	SELECT o_id as iddb, o_name as namedb FROM nir.Nir_object WHERE o_id_type = 13 ORDER BY o_name 
$$;


--
-- TOC entry 437 (class 1255 OID 106636958)
-- Name: get_doc_name_by_id(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_doc_name_by_id(id_doc integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
	name_doc character varying;
BEGIN	
	name_doc := (SELECT o_name FROM nir.Nir_object WHERE o_id=id_doc AND o_id_type = 5 limit 1);
	return name_doc;
END;	
	
$$;


--
-- TOC entry 442 (class 1255 OID 106636959)
-- Name: get_docs_of_cat(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_docs_of_cat(id_catalog integer) RETURNS TABLE(id integer, name character varying)
    LANGUAGE sql
    AS $_$
	SELECT o_id as id, o_name as name
		FROM nir.Nir_object JOIN nir.Nir_links 
		ON o_id=l_id1 WHERE l_id2=$1 AND l_id_link_type=1 AND o_id_type=5 ORDER BY o_name
$_$;


--
-- TOC entry 443 (class 1255 OID 106636960)
-- Name: get_file_name(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_file_name(id_file integer) RETURNS TABLE(idfile integer, namefile text)
    LANGUAGE sql
    AS $_$
	SELECT o_id as idfile, o_name as namefile FROM nir.Nir_object WHERE o_id=$1 LIMIT 1;
$_$;


--
-- TOC entry 444 (class 1255 OID 106636961)
-- Name: get_group_user_roles(text, text); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_group_user_roles(rolename text, username text DEFAULT "current_user"()) RETURNS TABLE(group_id integer, gr_sys_name character varying)
    LANGUAGE sql
    AS $_$
SELECT group_id, gr_sys_name  FROM nir.group_user_view where user_id_system=$2 and gr_sys_name in 
( select gr_sys_name from nir.group_role_view where r_name=$1);
$_$;


--
-- TOC entry 349 (class 1255 OID 106636864)
-- Name: get_id_curuser(); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_id_curuser() RETURNS integer
    LANGUAGE plpgsql
    AS $$ 
DECLARE 
 did integer;
BEGIN
	SELECT o_id  into did FROM nir.full_users_view where user_id_system=current_user;
	return COALESCE(did,0);
END;
$$;


--
-- TOC entry 486 (class 1255 OID 106744193)
-- Name: get_id_name_group(); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_id_name_group() RETURNS TABLE(id integer, name text)
    LANGUAGE sql
    AS $$
	select group_id, group_name from nir.nir_group
$$;


--
-- TOC entry 445 (class 1255 OID 106636962)
-- Name: get_id_top(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_id_top(id_obj integer) RETURNS integer
    LANGUAGE sql
    AS $_$
WITH recursive parents AS
(

select 1 as n_parent, o_id as parent_id from nir.nir_object 
	where ( o_id=$1 and o_id_type in (13,1) ) or
		( o_id in (select l_id2 FROM nir.nir_links where l_id1 =$1 and	l_id_link_type=1 ) )
union all
 SELECT (n_parent+1) as n_parent, l_id2 as parent_id
  FROM  parents left join nir.nir_links on parent_id = l_id1
	where l_id_link_type=1
)
select parent_id
from parents left join nir.nir_object p on parent_id = p.o_id
order by n_parent desc limit 1;
$_$;


--
-- TOC entry 446 (class 1255 OID 106636963)
-- Name: get_kz(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_kz(user_id integer) RETURNS TABLE(idkz integer, namekz text)
    LANGUAGE sql
    AS $_$
	SELECT o_id as idkz, o_name as namekz FROM nir.Nir_object JOIN nir.nir_links ON l_id1=o_id WHERE l_id2=$1 AND l_id_link_type=9 AND o_id_type = 1
$_$;


--
-- TOC entry 447 (class 1255 OID 106636964)
-- Name: get_my_templates_doc(); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_my_templates_doc() RETURNS TABLE(id integer, name text)
    LANGUAGE plpgsql
    AS $$
DECLARE 
	--temp templates;
BEGIN
	FOR id, name IN SELECT o_id, o_name FROM nir.Nir_object WHERE o_id_type = 7 
		and exists( select l_id from nir.nir_links where l_id1=o_id and l_id2=nir.get_id_curuser() )
		ORDER BY o_name
	LOOP
		RETURN NEXT;
	END LOOP;
	RETURN;	

	--list := (SELECT ARRAY(SELECT o_name FROM Nir_object WHERE o_id_type=11));	
	--return list;
END;
$$;


--
-- TOC entry 448 (class 1255 OID 106636965)
-- Name: get_objs_in_catalog(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_objs_in_catalog(id_catalog integer) RETURNS TABLE(parent_id integer, o_id integer, o_name text, o_id_type smallint)
    LANGUAGE sql
    AS $_$
WITH recursive parents AS
(
select l_id2 as parent_id, l_id1 as obj_id
  FROM nir.nir_links where l_id2 =$1 
	and l_id_link_type=1
union all
 SELECT l_id2 as parent_id, l_id1 as obj_id
  FROM  parents left join nir.nir_links on obj_id = l_id2
	where l_id_link_type=1 
)
select parent_id, o_id, o_name, o_id_type 
from parents left join nir.nir_object on obj_id = o_id
where o_id_type=4 or o_id_type=5; 
$_$;


--
-- TOC entry 449 (class 1255 OID 106636966)
-- Name: get_parent_catalog(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_parent_catalog(id integer) RETURNS TABLE(id integer, name text, type smallint)
    LANGUAGE sql
    AS $_$
	select parent_id as id, parent_name as name, parent_id_type as type from nir.nir_parent_view
	where obj_id=$1
$_$;


--
-- TOC entry 450 (class 1255 OID 106636967)
-- Name: get_parent_catalog_comfortable(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_parent_catalog_comfortable(id integer) RETURNS TABLE(id integer)
    LANGUAGE sql
    AS $_$
		
SELECT obj.l_id2 AS obj_id
   FROM ( SELECT a.o_id, a.o_name, a.o_id_type, b.l_id2
           FROM nir.nir_object a
      JOIN nir.nir_links b ON a.o_id = b.l_id1
     WHERE (a.o_id_type = ANY (ARRAY[4, 5]) AND a.o_id=$1 ) AND b.l_id_link_type = 1::smallint) obj
   JOIN nir.nir_object par ON obj.l_id2 = par.o_id
	
	
$_$;


--
-- TOC entry 451 (class 1255 OID 106636968)
-- Name: get_parent_path(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_parent_path(id integer) RETURNS text
    LANGUAGE sql
    AS $_$
 select array_to_string( ARRAY(
	SELECT (parent_id::text || ':'|| parent_type::text || ':' || parent_name) from nir.get_parents_list( $1 )),
 ';;'::text);
$_$;


--
-- TOC entry 452 (class 1255 OID 106636969)
-- Name: get_parents_list(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_parents_list(id_obj integer) RETURNS TABLE(n_parent integer, parent_id integer, parent_name text, parent_type integer, o_id integer, o_name text, o_id_type integer)
    LANGUAGE sql
    AS $_$
WITH recursive parents AS
(
select 1 as n_parent, l_id2 as parent_id, l_id1 as obj_id
  FROM nir.nir_links where l_id1 =$1 and 
	l_id_link_type=1
union all
 SELECT (n_parent+1) as n_parent, l_id2 as parent_id, l_id1 as obj_id
  FROM  parents left join nir.nir_links on parent_id = l_id1
	where l_id_link_type=1 
)
select n_parent, parent_id, p.o_name as parent_name, p.o_id_type::int as parent_type,
 o.o_id, o.o_name, o.o_id_type::int
from parents left join nir.nir_object o on obj_id = o.o_id 
	left join nir.nir_object p on parent_id = p.o_id
where o.o_id_type=4 or o.o_id_type=5 
order by n_parent desc;
$_$;


--
-- TOC entry 453 (class 1255 OID 106636970)
-- Name: get_rigths(integer, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_rigths(object_id integer, subject_id integer) RETURNS TABLE(isadmin boolean, iseditor boolean, isworker boolean, isreader boolean)
    LANGUAGE plpgsql
    AS $_$
begin
	return query SELECT u.isadmin, u.iseditor, u.isworker, u.isreader  FROM nir.full_users_view u where o_id=$2;
end;
$_$;


--
-- TOC entry 454 (class 1255 OID 106636971)
-- Name: get_role_list_for_api(); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_role_list_for_api() RETURNS TABLE(r_name character varying, r_info character varying, r_desc character varying, r_parent character varying)
    LANGUAGE sql
    AS $$
 SELECT r.r_name, r.r_info, r.r_desc, p.r_name
  FROM nir.nir_role r left join nir.nir_role p on r.r_parent = p.r_id;

$$;


--
-- TOC entry 455 (class 1255 OID 106636972)
-- Name: get_roles_by_user_list_for_api(); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_roles_by_user_list_for_api() RETURNS TABLE(r_name character varying)
    LANGUAGE sql
    AS $$
 select r_name from nir.user_role_view where user_id_system='xgb_nir';
$$;


--
-- TOC entry 456 (class 1255 OID 106636973)
-- Name: get_roles_by_user_list_for_api(character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_roles_by_user_list_for_api(name_of_user character varying) RETURNS TABLE(r_id integer, r_name character varying)
    LANGUAGE sql
    AS $_$
 select nir.nir_user_role.role_id, nir.nir_role.r_name 
 from nir.nir_user_role, nir.nir_user, nir.nir_role 
 where nir.nir_user.user_name=$1 AND nir.nir_user.user_id = nir.nir_user_role.user_id AND nir.nir_role.r_id = nir.nir_user_role.role_id;
$_$;


--
-- TOC entry 457 (class 1255 OID 106636974)
-- Name: get_tags_obj(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_tags_obj(id integer) RETURNS TABLE(tag_id integer, tag_name character varying)
    LANGUAGE sql
    AS $_$
 select tag_id, tag_name from nir.tags_view where obj_id=$1 order by tag_name;
$_$;


--
-- TOC entry 458 (class 1255 OID 106636975)
-- Name: get_teg_by_id(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_teg_by_id(idd integer) RETURNS character varying
    LANGUAGE sql
    AS $$
	SELECT o_name FROM nir.Nir_object WHERE o_id = idd limit 1;
$$;


--
-- TOC entry 481 (class 1255 OID 114291727)
-- Name: get_top_type(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_top_type(id_obj integer) RETURNS smallint
    LANGUAGE sql
    AS $_$
	select o_id_type as id_type from nir.nir_object where o_id=nir.get_id_top($1) limit 1;
$_$;


--
-- TOC entry 459 (class 1255 OID 106636976)
-- Name: get_user_kz(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_user_kz(user_id integer) RETURNS TABLE(id integer, name character varying)
    LANGUAGE sql
    AS $_$
 SELECT o_id as id, o_name as name 
	FROM nir.Nir_object JOIN nir.Nir_links ON o_id=l_id1 WHERE l_id2=$1 AND l_id_link_type=9 ORDER BY o_name
$_$;


--
-- TOC entry 460 (class 1255 OID 106636977)
-- Name: get_user_roles(text); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_user_roles(username text) RETURNS TABLE(r_id integer, r_name character varying, own boolean)
    LANGUAGE sql
    AS $_$
select r_id, r_name, (exists(select * from nir.nir_user_role where role_id=r_id and user_id = (select user_id from nir.nir_user where user_id_system = $1))) as own
 from nir.nir_role where ( r_id in (select role_id from nir.nir_user_role where user_id = (select user_id from nir.nir_user where user_id_system = $1) ) )
 or ( r_id in (select role_id from nir.nir_group_role where group_id in (SELECT group_id FROM nir.group_user_view where user_id_system=$1 ) ) )
$_$;


--
-- TOC entry 462 (class 1255 OID 106636978)
-- Name: get_users_role_list_for_api(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION get_users_role_list_for_api(id integer) RETURNS TABLE(user_id integer, user_name character varying, r_name character varying, r_info character varying, r_desc character varying)
    LANGUAGE sql
    AS $_$
 SELECT nir.nir_user.user_id, nir.nir_user.user_name, r_name, r_info, r_desc
	FROM nir.Nir_role, nir.Nir_user, nir.Nir_user_role
	WHERE nir.Nir_user_role.user_id = $1 AND nir.Nir_role.r_id =  nir.Nir_user_role.role_id AND nir.Nir_user.user_id = nir.Nir_user_role.user_id 
$_$;


--
-- TOC entry 463 (class 1255 OID 106636979)
-- Name: getattrlist(); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION getattrlist() RETURNS TABLE(id integer, name character varying, type smallint)
    LANGUAGE sql
    AS $$
 SELECT o_id as id, o_name as name, l_type_attr_id as type 
	FROM nir.Nir_object JOIN nir.Nir_links ON o_id=l_id1 WHERE o_id_type = 6 AND l_id_link_type=8 ORDER BY o_name
$$;


--
-- TOC entry 480 (class 1255 OID 106741908)
-- Name: getgroupbyid(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION getgroupbyid(group_id integer) RETURNS character varying
    LANGUAGE sql
    AS $$
select group_name FROM nir.Nir_group where group_id = group_id;
$$;


--
-- TOC entry 464 (class 1255 OID 106636980)
-- Name: getmodules(); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION getmodules() RETURNS SETOF xgb_nir.moduletype
    LANGUAGE plpgsql
    AS $$
DECLARE 
	module moduletype;
BEGIN
	FOR module.module_id, module.module_name, module.module_address, module.module_info IN SELECT module_id,module_name,module_address,module_info FROM nir.nir_module
	LOOP
		RETURN NEXT module;
	END LOOP;
	RETURN;	

END;
$$;


--
-- TOC entry 461 (class 1255 OID 106636981)
-- Name: getroles(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION getroles(object_id integer) RETURNS SETOF xgb_nir.roletype
    LANGUAGE plpgsql
    AS $_$
DECLARE 
	role roletype;
BEGIN
	FOR role.r_id, role.r_name, role.r_info, role.r_code 
		IN SELECT  role_access_id, role_access_name, role_access_desc, role_access_mask from nir.role_access 
		where role_access_id_object_type = (select o_id_type from nir.nir_object where o_id=$1)
	LOOP
		RETURN NEXT role;
	END LOOP;
	RETURN;	

END;
$_$;


--
-- TOC entry 465 (class 1255 OID 106636982)
-- Name: getroles_access(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION getroles_access(object_id integer) RETURNS TABLE(r_id integer, r_name text, r_info text, r_code bit varying)
    LANGUAGE plpgsql
    AS $_$
DECLARE 
	--role roletype;
BEGIN
	FOR r_id, r_name, r_info, r_code 
		IN SELECT  role_access_id, role_access_name, role_access_desc, role_access_mask from nir.role_access_real 
		where role_access_id_object_type = (select o_id_type from nir.nir_object where o_id=$1)
	LOOP
		RETURN NEXT ;
	END LOOP;
	RETURN;	

END;
$_$;


--
-- TOC entry 466 (class 1255 OID 106636983)
-- Name: gettaglist(); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION gettaglist() RETURNS TABLE(id integer, name character varying)
    LANGUAGE sql
    AS $$
select o_id as id, o_name as name FROM nir.Nir_object WHERE o_id_type = 11 order by o_name
$$;


--
-- TOC entry 513 (class 1255 OID 106740098)
-- Name: getuserrole(); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION getuserrole() RETURNS TABLE(user_role_id character varying, user_id integer, role_id bit varying)
    LANGUAGE sql
    AS $$


 SELECT r_info, user_id_object, r_code
FROM nir.nir_user_role, nir.nir_user, nir.nir_role 
where nir.nir_user.user_id = nir.nir_user_role.user_id and nir.nir_role.r_id = nir.nir_user_role.role_id
	
$$;


--
-- TOC entry 467 (class 1255 OID 106636985)
-- Name: getusers(); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION getusers() RETURNS TABLE(user_id integer, user_name character varying, user_id_system character varying, user_id_object integer)
    LANGUAGE sql
    AS $$
select user_id,user_name,user_id_system,user_id_object FROM nir.Nir_User;
$$;


--
-- TOC entry 468 (class 1255 OID 106636986)
-- Name: getusers_access(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION getusers_access(object_id integer) RETURNS SETOF xgb_nir.usertype
    LANGUAGE plpgsql
    AS $_$
DECLARE 
	user usertype;
BEGIN
	FOR user.id_user, user.login_user, user.user_id_system  
	IN SELECT  user_id_object, user_name, user_id_system from nir.nir_user 
		   where user_id_object IN (select roa_id_subject from nir.rights_access where roa_id_object=$1)
	LOOP
		RETURN NEXT user;
	END LOOP;
	RETURN;	

END;
$_$;


--
-- TOC entry 469 (class 1255 OID 106636987)
-- Name: getusersbyid(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION getusersbyid(us_id_obj integer) RETURNS TABLE(user_id integer, user_name character varying, user_id_system character varying, user_id_object integer)
    LANGUAGE sql
    AS $_$
select user_id,user_name,user_id_system,user_id_object FROM nir.Nir_User where user_id_object=$1;
$_$;


--
-- TOC entry 470 (class 1255 OID 106636988)
-- Name: getusersrole_access(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION getusersrole_access(object_id integer) RETURNS SETOF xgb_nir.userroletype
    LANGUAGE plpgsql
    AS $_$
DECLARE 
	userrole userroletype;
BEGIN
	FOR userrole.id_obj, userrole.id_subj, userrole.bit_map  
	IN SELECT  roa_id_object, roa_id_subject, roa_bit_map from nir.rights_access 
		    where roa_id_object=$1
	LOOP
		RETURN NEXT userrole;
	END LOOP;
	RETURN;	

END;
$_$;


--
-- TOC entry 471 (class 1255 OID 106636989)
-- Name: great_then(smallint, text, text); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION great_then(atype smallint, aval text, val text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE  r boolean;
begin		
	case 
	when atype=1 then r = ( cast(aval as int) > cast(val as int) );
	when atype=2 then r = ( upper(aval) > upper(val) );
	when atype=3 then 
		if( upper(val) = 'NOW' ) then
			r = ( cast(aval as timestamp) > now() );  
		else	
			r = ( cast(aval as timestamp) > cast(val as timestamp) );  
		end if;
	end case;  
	return r; 
end;
$$;


--
-- TOC entry 472 (class 1255 OID 106636990)
-- Name: is_between_value(smallint, text, text, text); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION is_between_value(atype smallint, aval text, val1 text, val2 text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE  r boolean;
begin		
	case 
	when atype=1 then r = ( cast(aval as int) between cast(val1 as int) and cast(val2 as int) ) ;
	when atype=2 then r = ( upper(aval) between upper(val1) and upper(val2) ) ;
	when atype=3 then r = ( cast(aval as timestamp) between  cast(val1 as timestamp) and cast(val2 as timestamp) );  
	end case;  
	return r; 
end;
$$;


--
-- TOC entry 473 (class 1255 OID 106636991)
-- Name: is_equal_value(smallint, text, text); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION is_equal_value(atype smallint, aval text, val text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE  r boolean;
begin		
	case 
	when atype=1 then r = ( cast(aval as int) = cast(val as int) );
	when atype=2 then r = ( upper(aval) = upper(val) );
	when atype=3 then r = ( cast(aval as timestamp) = cast(val as timestamp) );  
	end case;  
	return r; 
end;
$$;


--
-- TOC entry 474 (class 1255 OID 106636992)
-- Name: isowner(integer, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION isowner(obj integer, own integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE  r boolean;
begin
	return (SELECT exists ( select l_id from nir.nir_links where l_id1=obj and l_id2=own and l_id_link_type=9));
end;
$$;


--
-- TOC entry 475 (class 1255 OID 106636993)
-- Name: just_for_test(); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION just_for_test() RETURNS integer
    LANGUAGE plpgsql
    AS $$DECLARE 
	id_module integer;
	
BEGIN
	id_module = 0;
	return id_module;
END;$$;


--
-- TOC entry 476 (class 1255 OID 106636994)
-- Name: less_then(smallint, text, text); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION less_then(atype smallint, aval text, val text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE  r boolean;
begin		
	case 
	when atype=1 then r = ( cast(aval as int) < cast(val as int) );
	when atype=2 then r = ( upper(aval) < upper(val) );
	when atype=3 then 
		if( upper(val) = 'NOW' ) then
			r = ( cast(aval as timestamp) < now() );  
		else	
			r = ( cast(aval as timestamp) < cast(val as timestamp) );  
		end if;
	end case;  
	return r; 
end;
$$;


--
-- TOC entry 478 (class 1255 OID 106636995)
-- Name: link_group_to_role(character varying, character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION link_group_to_role(groupname character varying, rolename character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$

BEGIN
    if not exists(select r_id from nir.nir_role where r_name = rolename) then
    return -1;    
    end if;
    if not exists (select group_id from nir.nir_group where gr_sys_name = groupname ) then
    return -2;
    end if;
    if exists (select group_id from nir.nir_group_role where role_id = (select r_id from nir.nir_role where r_name = rolename)
	and group_id=(select group_id from nir.nir_group where gr_sys_name = groupname ) ) then
    return -3;
    end if;
    

--execute 'GRANT '|| quote_ident($2) || ' TO ' || quote_ident($1);
    INSERT INTO nir.nir_group_role (group_id, role_id) 
    VALUES ((SELECT group_id FROM nir.nir_group WHERE gr_sys_name = groupname), (SELECT r_id FROM nir.nir_role WHERE r_name = rolename));

    return 1;
END;
   $_$;


--
-- TOC entry 483 (class 1255 OID 106636996)
-- Name: link_user_to_role(character varying, character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION link_user_to_role(username character varying, rolename character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$

BEGIN	
    if not exists(select r_id from nir.nir_role where r_name = rolename) then
    return -1;
    end if;
    if not exists(select user_id from nir.nir_user where user_id_system = username) then
    return -2;
    end if;
    if exists (select user_id from nir.nir_user_role where user_id = (SELECT user_id FROM nir.nir_user WHERE user_id_system = username)
	and role_id = (SELECT r_id FROM nir.nir_role WHERE r_name = rolename)) then
    return -3;
    end if;
    
    --execute 'GRANT '|| $2 || ' TO ' || $1;
    INSERT INTO nir.nir_user_role (user_id, role_id) 
    VALUES ((SELECT user_id FROM nir.nir_user WHERE user_id_system = username), (SELECT r_id FROM nir.nir_role WHERE r_name = rolename));

    return 1;
END;
   $_$;


--
-- TOC entry 488 (class 1255 OID 106636997)
-- Name: loadfile(character varying, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION loadfile(namess character varying, iddoc integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
	idfile int;
begin
	if not exists(SELECT o_id FROM nir.Nir_object JOIN nir.Nir_links 
		ON l_id1=o_id WHERE l_id2=iddoc AND o_id_type=12 AND o_name = namess AND l_id_link_type=10) then

		INSERT INTO nir.Nir_object (o_name, o_id_type) VALUES (namess, 12) returning o_id into idfile;
		if idfile is not null then
			INSERT INTO nir.Nir_links (l_id2, l_id1, l_id_link_type) VALUES (iddoc, idfile, 10);
			return idfile; --добавление прошло успешно
		else
			return 0; --не удалось создать файл	
		end if;
	else
		return -1; --у дока уже есть связь с файлом такого имени
	end if;
end;
$$;


--
-- TOC entry 489 (class 1255 OID 106636998)
-- Name: nir_kz_tags(integer, text[]); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION nir_kz_tags(id_o integer, tags text[]) RETURNS TABLE(cat_id integer, obj_name character varying, obj_type_id smallint, obj_tags text)
    LANGUAGE plpgsql
    AS $$
	DECLARE
		tag text; 
		arr_len integer;
		n integer;
		i integer;
		obj_arr integer[];
		obj_len integer;
		counter integer;
		fl integer;
		arr varchar[];
	BEGIN
	n:=1;
arr_len:=array_length(tags, 1);

  CREATE TEMP TABLE temp_table  AS(SELECT ct.obj_id as obj_id FROM (SELECT COUNT(a.tag_name) as count, a.obj_id FROM (SELECT 
    t.o_name AS tag_name,
    o.o_id AS obj_id
    FROM nir.Nir_object o,
    nir.Nir_links,
    nir.Nir_object t
  WHERE Nir_links.l_id1 = o.o_id AND Nir_links.l_id2 = t.o_id AND Nir_links.l_id_link_type = 4 ) as a
  GROUP BY a.obj_id) as ct WHERE ct.count >= "arr_len") ;
	
  CREATE TEMP TABLE temp_table1  AS(SELECT 
    t.o_name AS tag_name,
    o.o_id AS obj_id
    FROM nir.Nir_object o,
    nir.Nir_links,
    nir.Nir_object t
  WHERE Nir_links.l_id1 = o.o_id AND Nir_links.l_id2 = t.o_id AND Nir_links.l_id_link_type = 4 AND o.o_id IN (SELECT c.obj_id FROM temp_table as C));
      CREATE TEMP TABLE tmp as TABLE temp_table1 ;
  WHILE (n <= arr_len) LOOP
  tag:=tags[n];
        if (tag IN (SELECT c.tag_name FROM temp_table1 as C))
        THEN INSERT INTO tmp SELECT DISTINCT tmp1.tag_name, tmp1.obj_id  FROM temp_table1 as tmp1 WHERE tmp1.tag_name = tag;
         END IF;
         n:=n+1;
         END LOOP;
       obj_arr:=ARRAY(SELECT DISTINCT tmp.obj_id FROM tmp);
       i:=0;
        CREATE TEMP TABLE result(obj_id integer);
    for i IN 1..coalesce(array_length(obj_arr, 1))
    LOOP
    counter:=0;
		for counter IN 1..coalesce(array_length(tags, 1)) 
		LOOP
		if (tags[counter] NOT IN (SELECT c.tag_name FROM temp_table1 as c WHERE c.obj_id=obj_arr[i]))
		      THEN fl:=0; 
		      ELSE fl:=1;
		END IF ;
		exit when fl=0;
		END LOOP;
		if (fl=1) THEN INSERT INTO result VALUES(obj_arr[i]);
		END IF;      
		
    END LOOP;
   return QUERY  SELECT PAR.o_id as cat_id, OBJ.o_name as obj_name, OBJ.o_id_type as obj_type, string_agg(tag.name, ',') FROM
    
     (SELECT o_id, o_name, o_id_type, l_id2 FROM nir.Nir_object AS A JOIN nir.Nir_links as B ON A.o_id=B.l_id1 
                WHERE o_id_type IN (4,5) AND l_id_link_type = '1' AND l_id2=id_o AND o_id IN(SELECT * FROM result)) as OBJ JOIN nir.Nir_object as PAR ON OBJ.l_id2=PAR.o_id JOIN (SELECT 
    t.o_name AS name,
    o.o_id AS obj_id
    FROM nir.Nir_object o,
    nir.Nir_links,
    nir.Nir_object t
  WHERE Nir_links.l_id1 = o.o_id AND Nir_links.l_id2 = t.o_id AND Nir_links.l_id_link_type = 4) as tag ON tag.obj_id=obj.o_id 
  GROUP BY PAR.o_id, OBJ.o_name, OBJ.o_id_type;
     
     DROP TABLE temp_table1, temp_table, tmp, result;
   END;
$$;


--
-- TOC entry 490 (class 1255 OID 106636999)
-- Name: rename_group(character varying, character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION rename_group(oldname character varying, newname character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
BEGIN
    if (upper(oldname) in( SELECT upper(r_name) FROM nir.nir_role)) then
	return -2;
    end if;	
    if (upper(newname) in( SELECT upper(r_name) FROM nir.nir_role) ) then
	return -3;
	end if;
    if not exists(select gr_sys_name from nir.nir_group where gr_sys_name = oldname) then
	return -1;
    end if;

    UPDATE nir.nir_group SET gr_sys_name = newname WHERE gr_sys_name = oldname; 
    UPDATE nir.nir_object SET o_name = newname WHERE o_name = oldname AND o_id_type = 14;
    --execute 'ALTER GROUP ' || quote_ident($1) ' RENAME GROUP ' || quote_ident($2);
    return 1;
    
END;
   $_$;


--
-- TOC entry 493 (class 1255 OID 106637000)
-- Name: rename_user(character varying, character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION rename_user(oldname character varying, newname character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$

BEGIN
    if (upper(oldname) in( SELECT upper(r_name) FROM nir.nir_role)) then
	return -2;
end if;
    if (upper(newname) in( SELECT upper(r_name) FROM nir.nir_role)) then
	return -3;    
end if;
    if not exists(select user_id_system from nir.nir_user where user_id_system = oldname) then
    return -1;
    end if;
   -- execute 'ALTER USER ' || quote_ident($1) ' RENAME TO ' || quote_ident($2);
    UPDATE nir.nir_user SET user_id_system = newname WHERE user_id_system = oldname; 
    UPDATE nir.nir_object SET o_name = newname WHERE o_name = oldname AND o_id_type = 2;
    return 1;

END;
   $_$;


--
-- TOC entry 494 (class 1255 OID 106637001)
-- Name: search_tags_by_name(character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION search_tags_by_name(search_name character varying) RETURNS TABLE(id integer, name character varying)
    LANGUAGE sql
    AS $_$
	select o_id as id, o_name as name FROM nir.Nir_object WHERE o_id_type = 11 AND UPPER(o_name) LIKE UPPER('%'||$1||'%') order by o_name
$_$;


--
-- TOC entry 495 (class 1255 OID 106637002)
-- Name: searchdocbyname(character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION searchdocbyname(namess character varying) RETURNS character
    LANGUAGE plpgsql
    AS $$
 --DECLARE objec varchar;
DECLARE 
	id_doc integer;
	tagMass character varying[];
	--atrMass character[];
	--atrValues character[]; 

begin
	id_doc :=(SELECT o_id FROM nir.Nir_object WHERE o_name = namess);
	tagMass :=(SELECT ARRAY(SELECT o_name FROM nir.Nir_object JOIN nir.Nir_links ON o_id = l_id2 WHERE l_id1 = id_doc AND l_id_link_type = 4));
	return tagMass;
end;
$$;


--
-- TOC entry 496 (class 1255 OID 106637003)
-- Name: set_access(integer, integer, bit varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION set_access(object_id integer, user_id integer, mask bit varying) RETURNS bit varying
    LANGUAGE plpgsql
    AS $_$
DECLARE 
 rt bit varying; 
BEGIN
--	user_id = COALESCE((select o_id from nir.full_users_view where user_id_system=current_user),0);
	rt = (select nir.get_access_mask($1,$2));
	if( rt=mask) then
		return mask;
	else
		if not exists(SELECT roa_id_subject, roa_id_object from nir.rights_access where roa_id_object = $1 AND roa_id_subject = $2) then	
			insert into nir.rights_access(roa_id_object, roa_id_subject, roa_bit_map) values($1,$2,$3);
		ELSE 
			UPDATE nir.rights_access set roa_bit_map =$3 where roa_id_object = $1 AND roa_id_subject = $2; 
		END IF;		
	end if;
	RETURN mask;	
END;
$_$;


--
-- TOC entry 497 (class 1255 OID 106637004)
-- Name: set_atrs_profile(atrtype[], integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION set_atrs_profile(atr atrtype[] DEFAULT ARRAY[]::atrtype[], user_id integer DEFAULT get_id_curuser()) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
	pid integer;	
	atrOld text[];
	atrWork text[];
begin		
	pid = nir.add_profile('',user_id);
	
	SELECT array_agg(atr_name) into atrOld from nir.get_atrs_obj(pid);

	select array_agg(v.a) into atrWork from 
		( (select a from UNNEST( atrOld) a) except (select a.aname from UNNEST(atr) a) ) v;
	perform nir.del_atrs_from_obj(pid,atrWork);
	
	perform nir.add_atrs_to_obj(pid,atr);
	return pid;
end;
$$;


--
-- TOC entry 499 (class 1255 OID 106637005)
-- Name: set_owner(integer, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION set_owner(obj_id integer, user_id integer DEFAULT get_id_curuser()) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 DECLARE 
	lid int;
begin
	if( exists( select l_id from nir.nir_links where l_id1=obj_id and l_id_link_type=9) ) then
		update nir.Nir_links set l_id2 =user_id where l_id1=obj_id and l_id_link_type=9 returning l_id into lid;
	else
		INSERT INTO nir.Nir_links (l_id1, l_id2, l_id_link_type) VALUES (obj_id, user_id, 9) returning l_id into lid;
	end if;
	return COALESCE(lid,0);
end;
$$;


--
-- TOC entry 500 (class 1255 OID 106637006)
-- Name: set_tema(integer, integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION set_tema(obj_id integer, user_id integer DEFAULT get_id_curuser()) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 DECLARE 
	pid int;
	lid int;
begin
	pid = nir.add_profile('', user_id);
	if( exists(select o_id from nir.nir_object where o_id=obj_id and o_id_type=17) ) then
		lid = COALESCE( (SELECT o_id_1 FROM nir.links_view WHERE o_id_2 = pid and o_type_2=18 and o_id_1=17), 0 );
		if( lid>0 ) then
			update nir.Nir_links set l_id1 =obj_id where l_id =lid;
		else
			INSERT INTO nir.Nir_links (l_id1, l_id2, l_id_link_type) VALUES (obj_id, pid, 6) returning l_id into lid;
		end if;
		return COALESCE(lid,0);
	else
		return -1;
	end if;
end;
$$;


--
-- TOC entry 504 (class 1255 OID 106637007)
-- Name: setrightsofgrouptoobj(rightsss_of_access[]); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION setrightsofgrouptoobj(mass rightsss_of_access[]) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
	--id_parent integer;
	count integer;
	massive nir.rightsss_of_access;
	old_mask bit varying;
begin	
	count = 0;
	FOR i in 1..array_length(mass,1)
	LOOP
		massive := mass[i]; 
		old_mask = (SELECT nir.get_access_mask_2_for_group(massive.idobject,massive.idsubject));
		if( old_mask <> massive.mask) then
			if not exists(SELECT rog_id_subject, rog_id_object from nir.rights_of_groups where rog_id_object = massive.idobject AND rog_id_subject = massive.idsubject) then	
			insert into nir.rights_of_groups(rog_id_object, rog_id_subject, rog_bit_map) values(massive.idobject, massive.idsubject , massive.mask);
			ELSE 
			UPDATE nir.rights_of_groups set rog_bit_map =massive.mask where rog_id_object = massive.idobject AND rog_id_subject = massive.idsubject; 
			END IF;
		end if;
		count = count+1;
	END LOOP;
	return count; 
end;
$$;


--
-- TOC entry 506 (class 1255 OID 106637008)
-- Name: setrightsofusertoobj(rightsss_of_access[]); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION setrightsofusertoobj(mass rightsss_of_access[]) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
	--id_parent integer;
	count integer;
	massive nir.rightsss_of_access;
	old_mask bit varying;
begin	
	count = 0;
	FOR i in 1..array_length(mass,1)
	LOOP
		massive := mass[i]; 
		old_mask = (SELECT nir.get_access_mask_2(massive.idobject,massive.idsubject));
		if( old_mask <> massive.mask) then
			if not exists(SELECT roa_id_subject, roa_id_object from nir.rights_access where roa_id_object = massive.idobject AND roa_id_subject = massive.idsubject) then	
			insert into nir.rights_access(roa_id_object, roa_id_subject, roa_bit_map) values(massive.idobject, massive.idsubject , massive.mask);
			ELSE 
			UPDATE nir.rights_access set roa_bit_map =massive.mask where roa_id_object = massive.idobject AND roa_id_subject = massive.idsubject; 
			END IF;
		end if;
		count = count+1;
	END LOOP;
	return count; 
end;
$$;


--
-- TOC entry 507 (class 1255 OID 106637009)
-- Name: showrights(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION showrights(object_id integer) RETURNS TABLE(l_id integer)
    LANGUAGE sql
    AS $_$

	select l_id1 from nir.Nir_links where l_id2 = $1;

$_$;


--
-- TOC entry 508 (class 1255 OID 106637010)
-- Name: tree_view(integer); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION tree_view(obj_id integer) RETURNS TABLE(object_id integer, par_id integer, name character varying, level integer)
    LANGUAGE plpgsql
    AS $$
  begin
  RETURN QUERY WITH RECURSIVE tree AS(
	SELECT par_list.o_id, par_list.l_id2 as parent_id, par_list.o_name, 1 as level
	FROM (SELECT a.o_id as o_id, a.o_name, a.o_id_type, b.l_id2 FROM nir.Nir_object AS A JOIN nir.Nir_links as B 
	ON A.o_id=B.l_id1 
                WHERE l_id_link_type = '1' ) as par_list
	WHERE par_list.o_id = obj_id

	UNION ALL

	SELECT o.o_id, o.l_id2, o.o_name, tree.level + 1 AS level
	FROM (SELECT a.o_id, a.o_name, a.o_id_type, b.l_id2 FROM nir.Nir_object AS A JOIN nir.Nir_links as B
	 ON A.o_id=B.l_id1 
                WHERE  l_id_link_type = '1' ) as O
			JOIN tree ON o.l_id2 = tree.o_id)
  SELECT * FROm tree;
			


 END;
 $$;


--
-- TOC entry 512 (class 1255 OID 106637011)
-- Name: unlink_group_from_role(character varying, character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION unlink_group_from_role(groupname character varying, rolename character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
BEGIN
    if not exists(select r_id from nir.nir_role where r_name = rolename) then
    return -1;    
    end if;
    if not exists(select gr_sys_name from nir.nir_group where gr_sys_name = groupname) then
    return -2;
    end if;
    if not exists (select group_id from nir.nir_group_role where role_id = (SELECT r_id FROM nir.nir_role WHERE r_name = rolename)
	and group_id=(select group_id from nir.nir_group where gr_sys_name = groupname )) then
    return -3;
    end if;
    --execute 'REVOKE ' || quote_ident(groupname)|| ' FROM ' || quote_ident(rolename);
    DELETE FROM nir.nir_group_role WHERE role_id = (SELECT r_id FROM nir.nir_role WHERE r_name = rolename) and group_id=(select group_id from nir.nir_group where gr_sys_name = groupname );
    return 1;
END;
   $$;


--
-- TOC entry 510 (class 1255 OID 106637012)
-- Name: unlink_user_from_role(character varying, character varying); Type: FUNCTION; Schema: nir; Owner: -
--

CREATE FUNCTION unlink_user_from_role(username character varying, rolename character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
BEGIN
	if not exists(select r_id from nir.nir_role where r_name = rolename) then
    return -1;
    end if;    
    if not exists(select user_id from nir.nir_user where user_id_system = username) then
    return -2;
    end if;
    if not exists (select user_id from nir.nir_user_role where user_id = (SELECT user_id FROM nir.nir_user WHERE user_id_system = username)
	and role_id = (SELECT r_id FROM nir.nir_role WHERE r_name = rolename)) then
    return -3;
    end if;
    --execute 'REVOKE ' || quote_ident(rolename)|| ' FROM ' || quote_ident(username);
    DELETE FROM nir.nir_user_role WHERE user_id = (SELECT user_id FROM nir.nir_user WHERE user_id_system = username) 
	and role_id = (SELECT r_id FROM nir.nir_role WHERE r_name = rolename);
    return 1;
END;
   $$;


SET search_path = public, pg_catalog;

--
-- TOC entry 309 (class 1255 OID 106637013)
-- Name: add_attr_to_doc_date(character varying, date, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION add_attr_to_doc_date(name character varying, value date, doc_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
	id_attr integer;
	id_attr_mass integer[];
	id_link integer;
	i integer;
	namess character varying;
BEGIN
	--проверка, нет ли атрибута с таким же именем у документа
	id_attr_mass := (SELECT ARRAY(SELECT l_id2 FROM "Nir_links" WHERE l_id1 = doc_id AND l_id_link_type=5));
	i := 1;
	while id_attr_mass[i] IS NOT NULL LOOP
		namess := (SELECT o_name FROM "Nir_object" WHERE o_id = id_attr_mass[i]);
		if (namess = name) then
			return -1;
		end if;	
		i := i + 1;
	END LOOP;
	--добавление объекта
	INSERT INTO "Nir_object" (o_name, o_id_type) VALUES (name, 6);
	if exists(SELECT o_id FROM "Nir_object" WHERE o_name=name ORDER BY o_id DESC LIMIT 1) then
		--добавление связи
		id_attr := (SELECT o_id FROM "Nir_object" WHERE o_name=name ORDER BY o_id DESC LIMIT 1);
		INSERT INTO "Nir_links" (l_id1, l_id2, l_id_link_type, l_type_attr_id) VALUES (doc_id, id_attr, 5, 3);
		if exists(SELECT l_id FROM "Nir_links" WHERE l_id1=doc_id AND l_id2 = id_attr AND l_id_link_type=5 AND l_type_attr_id=3) then
			--добавление значения
			id_link = (SELECT l_id FROM "Nir_links" WHERE l_id1=doc_id AND l_id2 = id_attr AND l_id_link_type=5 AND l_type_attr_id=3);
			INSERT INTO "Nir_object_value_date" (ovd_value, ovd_link_id) VALUES (value, id_link);
			if exists(SELECT ovd_id FROM "Nir_object_value_date" WHERE ovd_link_id=id_link) then
				return 1;
			else
				return -1;
			end if;		
		else
			return -1;
		end if;		
	else
		return -1;
	end if;		
END;
$$;


--
-- TOC entry 310 (class 1255 OID 106637014)
-- Name: add_attr_to_doc_int(character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION add_attr_to_doc_int(name character varying, value integer, doc_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
	id_attr integer;
	id_attr_mass integer[];
	id_link integer;
	i integer;
	namess character varying;
BEGIN
	--проверка, нет ли атрибута с таким же именем у документа
	id_attr_mass := (SELECT ARRAY(SELECT l_id2 FROM "Nir_links" WHERE l_id1 = doc_id AND l_id_link_type=5));
	i := 1;
	while id_attr_mass[i] IS NOT NULL LOOP
		namess := (SELECT o_name FROM "Nir_object" WHERE o_id = id_attr_mass[i]);
		if (namess = name) then
			return -1;
		end if;	
		i := i + 1;
	END LOOP;
	--добавление объекта
	INSERT INTO "Nir_object" (o_name, o_id_type) VALUES (name, 6);
	if exists(SELECT o_id FROM "Nir_object" WHERE o_name=name ORDER BY o_id DESC LIMIT 1) then
		--добавление связи
		id_attr := (SELECT o_id FROM "Nir_object" WHERE o_name=name ORDER BY o_id DESC LIMIT 1);
		INSERT INTO "Nir_links" (l_id1, l_id2, l_id_link_type, l_type_attr_id) VALUES (doc_id, id_attr, 5, 1);
		if exists(SELECT l_id FROM "Nir_links" WHERE l_id1=doc_id AND l_id2 = id_attr AND l_id_link_type=5 AND l_type_attr_id=1) then
			--добавление значения
			id_link = (SELECT l_id FROM "Nir_links" WHERE l_id1=doc_id AND l_id2 = id_attr AND l_id_link_type=5 AND l_type_attr_id=1);
			INSERT INTO "Nir_object_value_int" (obi_value, obi_link_id) VALUES (value, id_link);
			if exists(SELECT obi_id FROM "Nir_object_value_int" WHERE obi_link_id=id_link) then
				return 1;
			else
				return -1;
			end if;		
		else
			return -1;
		end if;		
	else
		return -1;
	end if;		
END;
$$;


--
-- TOC entry 313 (class 1255 OID 106637015)
-- Name: add_attr_to_doc_varchar(character varying, character varying, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION add_attr_to_doc_varchar(name character varying, value character varying, doc_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
	id_attr integer;
	id_attr_mass integer[];
	id_link integer;
	i integer;
	namess character varying;
BEGIN
	--проверка, нет ли атрибута с таким же именем у документа
	id_attr_mass := (SELECT ARRAY(SELECT l_id2 FROM "Nir_links" WHERE l_id1 = doc_id AND l_id_link_type=5));
	i := 1;
	while id_attr_mass[i] IS NOT NULL LOOP
		namess := (SELECT o_name FROM "Nir_object" WHERE o_id = id_attr_mass[i]);
		if (namess = name) then
			return -1;
		end if;	
		i := i + 1;
	END LOOP;
	--добавление объекта
	INSERT INTO "Nir_object" (o_name, o_id_type) VALUES (name, 6);
	if exists(SELECT o_id FROM "Nir_object" WHERE o_name=name ORDER BY o_id DESC LIMIT 1) then
		--добавление связи
		id_attr := (SELECT o_id FROM "Nir_object" WHERE o_name=name ORDER BY o_id DESC LIMIT 1);
		INSERT INTO "Nir_links" (l_id1, l_id2, l_id_link_type, l_type_attr_id) VALUES (doc_id, id_attr, 5, 2);
		if exists(SELECT l_id FROM "Nir_links" WHERE l_id1=doc_id AND l_id2 = id_attr AND l_id_link_type=5 AND l_type_attr_id=2) then
			--добавление значения
			id_link = (SELECT l_id FROM "Nir_links" WHERE l_id1=doc_id AND l_id2 = id_attr AND l_id_link_type=5 AND l_type_attr_id=2);
			INSERT INTO "Nir_object_value_varchar" (ovv_value, ovv_link_id) VALUES (value, id_link);
			if exists(SELECT ovv_id FROM "Nir_object_value_varchar" WHERE ovv_link_id=id_link) then
				return 1;
			else
				return -1;
			end if;		
		else
			return -1;
		end if;		
	else
		return -1;
	end if;		
END;
$$;


--
-- TOC entry 314 (class 1255 OID 106637016)
-- Name: add_tag_to_obj(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION add_tag_to_obj(id_tag integer, id_object integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$

begin
	if not exists(SELECT l_id FROM "Nir_links" WHERE l_id1=id_object AND l_id2=id_tag AND l_id_link_type=4) then
		INSERT INTO "Nir_links" (l_id1, l_id2, l_id_link_type) VALUES (id_object, id_tag, 4);
		if exists(SELECT l_id FROM "Nir_links" WHERE l_id1=id_object AND l_id2=id_tag AND l_id_link_type=4) then
			return 1;
		else
			return 0;
		end if;
	end if;	
	return -1;		
end;
$$;


--
-- TOC entry 315 (class 1255 OID 106637017)
-- Name: addcatalog(character varying, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION addcatalog(namess character varying, parent_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 DECLARE 
	idCatalog integer;
BEGIN
	--проверяем, нет ли у родительского каталога дочернего с таким же именем, который хотим создать
	if not exists(SELECT o_id FROM "Nir_object" JOIN "Nir_links" ON l_id2=o_id WHERE l_id1=parent_id AND o_name=namess AND l_id_link_type=1) then
		INSERT INTO "Nir_object" (o_name,o_id_type) values (namess,'4');
		--получаем только что созданный каталог
		idCatalog := (SELECT o_id FROM "Nir_object" WHERE o_name = namess ORDER BY o_id DESC LIMIT 1);
		--добавляем связь с родительским
		INSERT INTO "Nir_links" (l_id1, l_id2, l_id_link_type) VALUES (parent_id, idCatalog, 1);
		if exists (SELECT l_id FROM "Nir_links" WHERE l_id1 = parent_id AND l_id2 = idCatalog AND l_id_link_type=1) then
			return idCatalog; -- после того как добавилась сязь возвращаем id каталога, который создали
		else
			return -0; --означает, что связь не добавилась
		end if;
	end if;
	return -1; --означает, что такой каталог уже существует
END;
$$;


--
-- TOC entry 316 (class 1255 OID 106637018)
-- Name: adddoc(character varying, text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION adddoc(namedoc character varying, tag text[] DEFAULT NULL::text[]) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 --DECLARE objec varchar;
DECLARE idDoc int;
idTag int;
nameTag text;
begin
if not exists(select o_id, o_name  from "Nir_object" where o_id_type=5 and o_name = nameDoc) then
insert into "Nir_object" (o_name,o_id_type) values (nameDoc,'5');
end if;
idDoc := (select o_id from "Nir_object" where o_id_type=5 and o_name = nameDoc);
FOR nameTag IN SELECT unnest("tag")
LOOP
idTag:=( select * FROM addtag(nameTag));
 --idTag :=(select o_id from "Nir_object" where o_id_type=11 and o_name = nameTag )
 if not exists(select l_id from "Nir_links" where l_id1 = idDoc and l_id2 = idTag) then
 insert into "Nir_links" (l_id1,l_id2, l_id_link_type) values (idDoc, idTag,'4');
 end if;
END LOOP;
return idDoc;

end;

$$;


--
-- TOC entry 317 (class 1255 OID 106637019)
-- Name: adddoc(character varying, text[], xgb_nir.atrtype[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION adddoc(namedoc character varying, tag text[] DEFAULT NULL::text[], atr xgb_nir.atrtype[] DEFAULT NULL::xgb_nir.atrtype[]) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 --DECLARE objec varchar;
DECLARE idDoc int;
idTag int;
nameTag text;
begin
if not exists(select o_id, o_name  from "Nir_object" where o_id_type=5 and o_name = nameDoc) then
insert into "Nir_object" (o_name,o_id_type) values (nameDoc,'5');
end if;
idDoc := (select o_id from "Nir_object" where o_id_type=5 and o_name = nameDoc);
FOR nameTag IN SELECT unnest("tag")
LOOP
idTag:=( select * FROM addtag(nameTag));
 --idTag :=(select o_id from "Nir_object" where o_id_type=11 and o_name = nameTag )
 if not exists(select l_id from "Nir_links" where l_id1 = idDoc and l_id2 = idTag) then
 insert into "Nir_links" (l_id1,l_id2, l_id_link_type) values (idDoc, idTag,'4');
 end if;
END LOOP;
return idDoc;

end;

$$;


--
-- TOC entry 318 (class 1255 OID 106637020)
-- Name: addkz(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION addkz(namess character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 DECLARE 
	idKZ integer;
begin
	if not exists(select o_id, o_name  from "Nir_object" where o_id_type=1 and o_name = namess) then
	insert into "Nir_object" (o_name,o_id_type) values (namess,'1');
	end if;
	idKZ := (select o_id from "Nir_object" where o_id_type=1 and o_name = namess);
	return idKZ;
end;
$$;


--
-- TOC entry 319 (class 1255 OID 106637021)
-- Name: addtag(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION addtag(namess character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 --DECLARE objec varchar;
DECLARE idtag int;
begin
if not exists(select o_id, o_name  from "Nir_object" where o_id_type=11 and o_name = namess) then
insert into "Nir_object" (o_name,o_id_type) values (namess,'11');
end if;
idtag := (select o_id from "Nir_object" where o_id_type=11 and o_name = namess);
return idtag;
end;
$$;


--
-- TOC entry 320 (class 1255 OID 106637022)
-- Name: array_id_atr(text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION array_id_atr(array_atr text[] DEFAULT NULL::text[]) RETURNS SETOF xgb_nir.arraydoc
    LANGUAGE plpgsql
    AS $$
DECLARE 
	nameAtr text;
	elemArray arrayDoc;
BEGIN
	FOR nameAtr IN SELECT unnest("array_atr")
	LOOP
	
	FOR elemArray.id IN select o_id  from "Nir_object" where o_name=nameAtr and o_id_type=6
	LOOP
	RETURN NEXT elemArray;
	END LOOP;
	
	END LOOP;
	RETURN;				
END;
$$;


--
-- TOC entry 311 (class 1255 OID 106637023)
-- Name: array_id_atr(xgb_nir.arratr[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION array_id_atr(array_atr xgb_nir.arratr[] DEFAULT NULL::xgb_nir.arratr[]) RETURNS SETOF xgb_nir.arraydoc
    LANGUAGE plpgsql
    AS $$
DECLARE 
	nameAtr text;
	elemArray arrayDoc;
BEGIN
	FOR nameAtr IN SELECT unnest("array_atr")
	LOOP
	
	FOR elemArray.id IN select o_id from "Nir_object" where o_name=nameAtr and o_id_type=6
	LOOP
	RETURN NEXT elemArray;
	END LOOP;
	
	END LOOP;
	RETURN;				
END;
$$;


--
-- TOC entry 312 (class 1255 OID 106637024)
-- Name: changenamecatalog(integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION changenamecatalog(id integer, parent_id integer, namess character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 DECLARE 
	--id_check integer;
begin
	--получаем каталоги из Nir_object с таким же именем, которое м\хотим присвоить
	if not exists(SELECT o_id FROM "Nir_object" JOIN "Nir_links" ON l_id2=o_id WHERE l_id1=parent_id AND o_name=namess AND l_id_link_type=1) then
		UPDATE "Nir_object" SET o_name = namess WHERE o_id = id AND o_id_type=4;
		if exists(SELECT o_id FROM "Nir_object" WHERE o_id = id AND o_name = namess AND o_id_type=4) then
			return 1;
		else
			return 0;
		end if;	
	end if;
	return -1;	
	
	
end;
$$;


--
-- TOC entry 321 (class 1255 OID 106637025)
-- Name: changenamedoc(integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION changenamedoc(id integer, parent_id integer, namess character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$

BEGIN
	if not exists(SELECT o_id FROM "Nir_object" JOIN "Nir_links" ON l_id2=o_id WHERE l_id1=parent_id AND o_name=namess AND l_id_link_type=1) then
		UPDATE "Nir_object" SET o_name = namess WHERE o_id = id AND o_id_type=5;
		if exists(SELECT o_id FROM "Nir_object" JOIN "Nir_links" ON l_id2=o_id WHERE l_id1=parent_id AND o_name=namess AND l_id_link_type=1) then
			return 1;
		else
			return 0;
		end if;	
	end if;
	return -1;	
END;
$$;


--
-- TOC entry 322 (class 1255 OID 106637026)
-- Name: changenamekz(integer, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION changenamekz(id integer, namess character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 DECLARE 
	--num_rows integer;
begin
	UPDATE "Nir_object" SET o_name = namess WHERE o_id = id AND o_id_type=1;
	if exists(SELECT o_id FROM "Nir_object" WHERE o_id = id AND o_name = namess) then
		return 1;
	else
		return 0;
	end if;	
end;
$$;


--
-- TOC entry 323 (class 1255 OID 106637027)
-- Name: dropatr(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION dropatr(id integer, id_parent integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 --DECLARE objec varchar;
DECLARE 
	link_id integer;
	type_attr integer;
BEGIN
	--удаление значения
	type_attr := (SELECT l_type_attr_id FROM "Nir_links" WHERE l_id1 = id_parent AND l_id2=id AND l_id_link_type=5);
	link_id := (SELECT l_id FROM "Nir_links" WHERE l_id1 = id_parent AND l_id2=id AND l_id_link_type=5);
	if (type_attr = 1)then
		DELETE FROM "Nir_object_value_int" WHERE obi_link_id=link_id;
	end if;	
	if(type_attr = 2)then
		DELETE FROM "Nir_object_value_varchar" WHERE ovv_link_id=link_id;
	end if;	
	if(type_attr = 3)then
		DELETE FROM "Nir_object_value_date" WHERE ovd_link_id=link_id;	
	end if;

	
	--удаление связей с атрибутом
	DELETE FROM "Nir_links" WHERE l_id2 = id AND l_id1 = id_parent AND l_id_link_type = 5;
	if not exists(SELECT l_id FROM "Nir_links" WHERE l_id1=id_parent AND l_id2=id AND l_id_link_type=5) then
		DELETE FROM "Nir_object" WHERE o_id = id;
		--проверка удалился ли объект
		if not exists(SELECT o_name FROM "Nir_object" WHERE o_id=id) then
			return 1;
		else
			return 0;
		end if;	
	end if;	
END;
$$;


--
-- TOC entry 324 (class 1255 OID 106637028)
-- Name: dropdoc(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION dropdoc(id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE 
	link_id_attr integer[];
	id_attr integer[];
	i integer;
	j integer;
BEGIN
	--Удаление связи с тегами
	DELETE FROM "Nir_links" WHERE l_id1 = id AND l_id_link_type = 4;
	--Удаление связи с родительским каталогом
	DELETE FROM "Nir_links" WHERE l_id2 = id AND l_id_link_type = 1;
	--Удаление значений атрибутов, связей с атрибутами и самих атрибутов
	link_id_attr := (SELECT ARRAY(SELECT l_id FROM "Nir_links" WHERE l_id1=id AND l_id_link_type = 5)); --получил все связи дока с атрибутами
	i := 1;
	while link_id_attr[i] IS NOT NULL LOOP
		if exists(SELECT ovv_id FROM "Nir_object_value_varchar" WHERE ovv_link_id=link_id_attr[i]) then
			DELETE FROM "Nir_object_value_varchar" WHERE ovv_link_id=link_id_attr[i];
			DELETE FROM "Nir_links" WHERE l_id=link_id_attr[i];
		end if;
		if exists(SELECT obi_id FROM "Nir_object_value_int" WHERE obi_link_id=link_id_attr[i]) then
			DELETE FROM "Nir_object_value_int" WHERE obi_link_id=link_id_attr[i];
			DELETE FROM "Nir_links" WHERE l_id=link_id_attr[i];
		end if;
		if exists(SELECT ovv_id FROM "Nir_object_value_date" WHERE ovd_link_id=link_id_attr[i]) then
			DELETE FROM "Nir_object_value_date" WHERE ovd_link_id=link_id_attr[i];
			DELETE FROM "Nir_links" WHERE l_id=link_id_attr[i];
		end if;
		i := i+1;
	END LOOP; 

	id_attr := (SELECT ARRAY(SELECT l_id2 FROM "Nir_links" WHERE l_id1 = id AND l_id_link_type = 5));
	
	j := 1;
	while id_attr[j] IS NOT NULL LOOP
		DELETE FROM "Nir_object" WHERE o_id = id_attr[j];
	END LOOP;
	--Удаление самого документа из таблицы Nir_object
	DELETE FROM "Nir_object" WHERE o_id = id;
	return 1;	
END;
$$;


--
-- TOC entry 325 (class 1255 OID 106637029)
-- Name: droptag(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION droptag(id integer, id_parent integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
 --DECLARE objec varchar;
DECLARE 
	--idtag int;
BEGIN
	--удаление связей с тегом
	DELETE FROM "Nir_links" WHERE l_id2 = id AND l_id1 = id_parent AND l_id_link_type = 4;
	--проверка удалился ли объект
	if not exists(SELECT l_id FROM "Nir_links" WHERE l_id2 = id AND l_id1 = id_parent AND l_id_link_type = 4) then
		return 1;
	else
		return 0;
	end if;		
END;
$$;


--
-- TOC entry 326 (class 1255 OID 106637030)
-- Name: find_doc(text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION find_doc(array_tag text[] DEFAULT NULL::text[]) RETURNS SETOF xgb_nir.cnt_and_id
    LANGUAGE plpgsql
    AS $$
DECLARE 
	elemArray cnt_and_id;
	leng integer;
BEGIN
	leng := (array_length(array_tag,1));
	FOR elemArray.id, elemArray.count IN select distinct l_id1, count(l_id1) from "Nir_links" where l_id2 in (select id from array_id_tags(array_tag)) group by l_id1
		LOOP
			if (leng - elemArray.count = 0) then
				RETURN NEXT elemArray;
			end if;
		END LOOP;
	RETURN;				
END;
$$;


--
-- TOC entry 327 (class 1255 OID 106637031)
-- Name: get_attr_of_doc(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_attr_of_doc(id_parent integer) RETURNS SETOF xgb_nir.attrib
    LANGUAGE plpgsql
    AS $$
DECLARE 
	_attribute attrib;
	name_type int;
	link_id int;
BEGIN
	FOR _attribute.id, _attribute.name, name_type, link_id IN SELECT o_id, o_name, l_type_attr_id, l_id FROM "Nir_object" JOIN "Nir_links" ON o_id=l_id2 WHERE l_id1=id_parent AND l_id_link_type=5 AND o_id_type=6
	LOOP 
	if(name_type = 2) then
	_attribute.value := (Select ovv_value from "Nir_object_value_varchar" where ovv_link_id=link_id);
	end if;
	
	if (name_type = 1) then
	_attribute.value := (Select obi_value from "Nir_object_value_int" where obi_link_id=link_id);
	end if;
	
	if (name_type = 3) then
	_attribute.value := (Select ovd_value from "Nir_object_value_date" where ovd_link_id=link_id);
	end if;
	
		RETURN NEXT _attribute;
	END LOOP;
	RETURN;	
END;
$$;


--
-- TOC entry 328 (class 1255 OID 106637032)
-- Name: get_cat_of_catalog(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_cat_of_catalog(id_parent integer) RETURNS SETOF xgb_nir.catalogs
    LANGUAGE plpgsql
    AS $$
DECLARE 
	_catalog catalogs;
BEGIN
	FOR _catalog.id, _catalog.name IN SELECT o_id, o_name FROM "Nir_object" JOIN "Nir_links" ON o_id=l_id2 WHERE l_id1=id_parent AND l_id_link_type=1 AND o_id_type=4
	LOOP 
		RETURN NEXT _catalog;
	END LOOP;
	RETURN;	
END;
$$;


--
-- TOC entry 329 (class 1255 OID 106637033)
-- Name: get_docs_of_cat(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_docs_of_cat(id_catalog integer) RETURNS SETOF xgb_nir.documents
    LANGUAGE plpgsql
    AS $$
DECLARE 
	_document documents;
BEGIN
	FOR _document.id, _document.name IN SELECT o_id, o_name FROM "Nir_object" JOIN "Nir_links" ON o_id=l_id2 WHERE l_id1=id_catalog AND l_id_link_type=1 AND o_id_type=5
	LOOP 
		RETURN NEXT _document;
	END LOOP;
	RETURN;	
END;
$$;


--
-- TOC entry 330 (class 1255 OID 106637034)
-- Name: get_kz(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_kz() RETURNS SETOF xgb_nir.kzs
    LANGUAGE plpgsql
    AS $$
DECLARE 
	kz kzs;
BEGIN
	FOR kz.idkz, kz.namekz IN SELECT o_id, o_name FROM "Nir_object" WHERE o_id_type = 1
	LOOP
		RETURN NEXT kz;
	END LOOP;
	RETURN;	

	--list := (SELECT ARRAY(SELECT o_name FROM "Nir_object" WHERE o_id_type=11));	
	--return list;
END;
$$;


--
-- TOC entry 331 (class 1255 OID 106637035)
-- Name: get_parent_catalog(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_parent_catalog(id integer) RETURNS xgb_nir.parent_cat
    LANGUAGE plpgsql
    AS $$
DECLARE
	result parent_cat;
BEGIN
	result.id := (SELECT l_id1 FROM "Nir_links" WHERE l_id2 = id AND l_id_link_type = 1);
	result.name := (SELECT o_name FROM "Nir_object" WHERE o_id=result.id);
	RETURN result;
	--parent_id := (SELECT l_id1 FROM "Nir_links" WHERE l_id2 = id AND l_id_link_type = 1);	
END;
$$;


--
-- TOC entry 332 (class 1255 OID 106637036)
-- Name: get_tags_obj(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_tags_obj(id integer) RETURNS SETOF xgb_nir.tags
    LANGUAGE plpgsql
    AS $$
DECLARE 
	tag tags;
BEGIN
	FOR tag.id, tag.name IN SELECT o_id, o_name FROM "Nir_object" JOIN "Nir_links" ON l_id2 = o_id WHERE l_id1 = id AND l_id_link_type = 4
	LOOP
		RETURN NEXT tag;
	END LOOP;
	RETURN;				
END;
$$;


--
-- TOC entry 333 (class 1255 OID 106637037)
-- Name: get_teg_by_id(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_teg_by_id(idd integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE 
	name character varying;
begin
	name := (SELECT o_name FROM "Nir_object" WHERE o_id = idd);
	return name;
end;
$$;


--
-- TOC entry 334 (class 1255 OID 106637038)
-- Name: getobjectbytag(character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION getobjectbytag(tag character varying, namess character varying) RETURNS TABLE(v character varying)
    LANGUAGE sql
    AS $$
 --DECLARE objec varchar;
--begin
	select o_name from "Nir_object", "Nir_links" where o_id=l_id1 and 
	l_id2 in (select o_id from "Nir_object", "Nir_object_type" where o_id_type=ot_id and ot_name=tag and o_name=namess);
--	RETURN objec;
--end
$$;


--
-- TOC entry 335 (class 1255 OID 106637039)
-- Name: getroleactionsonobject(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION getroleactionsonobject(iduser integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE 
	list character varying[];
BEGIN
	list := (SELECT ARRAY(SELECT ra_action_id FROM "Nir_object", "Nir_role_action", "Nir_Role", "Nir_user_role", "Nir_User"
WHERE ur_user_id = idUser AND ur_role_id = r_role_id AND r_role_id = ra_role_id AND ra_object_id = o_id));	
	return list;
END;
$$;


--
-- TOC entry 336 (class 1255 OID 106637040)
-- Name: gettaglist(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION gettaglist() RETURNS SETOF xgb_nir.tegs
    LANGUAGE plpgsql
    AS $$
DECLARE 
	teg tegs;
BEGIN
	FOR teg.id, teg.name IN SELECT o_id, o_name FROM "Nir_object" WHERE o_id_type = 11
	LOOP
		RETURN NEXT teg;
	END LOOP;
	RETURN;	

	--list := (SELECT ARRAY(SELECT o_name FROM "Nir_object" WHERE o_id_type=11));	
	--return list;
END;
$$;


--
-- TOC entry 337 (class 1255 OID 106637041)
-- Name: getusersobject(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION getusersobject(iduser integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE 
	list character varying[];
BEGIN
	list := (SELECT ARRAY(SELECT o_name FROM "Nir_object", "Nir_role_action", "Nir_Role", "Nir_user_role", "Nir_User"
WHERE ur_user_id = idUser AND ur_role_id = r_role_id AND r_role_id = ra_role_id AND ra_object_id = o_id));	
	return list;
END;
$$;


--
-- TOC entry 338 (class 1255 OID 106637042)
-- Name: searchdocbyname(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION searchdocbyname(namess character varying) RETURNS character
    LANGUAGE plpgsql
    AS $$
 --DECLARE objec varchar;
DECLARE 
	id_doc integer;
	tagMass character varying[];
	--atrMass character[];
	--atrValues character[]; 

begin
	id_doc :=(SELECT o_id FROM "Nir_object" WHERE o_name = namess);
	tagMass :=(SELECT ARRAY(SELECT o_name FROM "Nir_object" JOIN "Nir_links" ON o_id = l_id2 WHERE l_id1 = id_doc AND l_id_link_type = 4));
	return tagMass;
end;
$$;


SET search_path = nir, pg_catalog;

--
-- TOC entry 182 (class 1259 OID 106637045)
-- Name: a_action_id_seq; Type: SEQUENCE; Schema: nir; Owner: -
--

CREATE SEQUENCE a_action_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 183 (class 1259 OID 106637047)
-- Name: o_id_seq; Type: SEQUENCE; Schema: nir; Owner: -
--

CREATE SEQUENCE o_id_seq
    START WITH 18
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 184 (class 1259 OID 106637049)
-- Name: nir_object; Type: TABLE; Schema: nir; Owner: -; Tablespace: 
--

CREATE TABLE nir_object (
    o_id integer DEFAULT nextval('o_id_seq'::regclass) NOT NULL,
    o_name character varying NOT NULL,
    o_id_type smallint NOT NULL
);


--
-- TOC entry 185 (class 1259 OID 106637056)
-- Name: nir_user; Type: TABLE; Schema: nir; Owner: -; Tablespace: 
--

CREATE TABLE nir_user (
    user_id integer NOT NULL,
    user_name character varying NOT NULL,
    user_id_system character varying,
    user_id_object integer
);


--
-- TOC entry 186 (class 1259 OID 106637062)
-- Name: nir_user_role; Type: TABLE; Schema: nir; Owner: -; Tablespace: 
--

CREATE TABLE nir_user_role (
    user_id integer NOT NULL,
    role_id integer NOT NULL
);


--
-- TOC entry 187 (class 1259 OID 106637065)
-- Name: full_users_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW full_users_view AS
SELECT nir_object.o_id, nir_object.o_name, nir_object.o_id_type, nir_user.user_id, nir_user.user_name, nir_user.user_id_system, (EXISTS (SELECT nir_user_role.user_id, nir_user_role.role_id FROM nir_user_role WHERE ((nir_user_role.user_id = nir_user.user_id) AND (nir_user_role.role_id = 1)))) AS isadmin, (EXISTS (SELECT nir_user_role.user_id, nir_user_role.role_id FROM nir_user_role WHERE ((nir_user_role.user_id = nir_user.user_id) AND (nir_user_role.role_id <= 2)))) AS iseditor, (EXISTS (SELECT nir_user_role.user_id, nir_user_role.role_id FROM nir_user_role WHERE ((nir_user_role.user_id = nir_user.user_id) AND (nir_user_role.role_id <= 3)))) AS isworker, (EXISTS (SELECT nir_user_role.user_id, nir_user_role.role_id FROM nir_user_role WHERE ((nir_user_role.user_id = nir_user.user_id) AND (nir_user_role.role_id <= 4)))) AS isreader, (EXISTS (SELECT nir_user_role.user_id, nir_user_role.role_id FROM nir_user_role WHERE ((nir_user_role.user_id = nir_user.user_id) AND (nir_user_role.role_id <= 5)))) AS isdirector FROM (nir_user JOIN nir_object ON ((nir_object.o_id = nir_user.user_id_object)));


--
-- TOC entry 188 (class 1259 OID 106637070)
-- Name: l_id_seq; Type: SEQUENCE; Schema: nir; Owner: -
--

CREATE SEQUENCE l_id_seq
    START WITH 18
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


--
-- TOC entry 189 (class 1259 OID 106637072)
-- Name: nir_links; Type: TABLE; Schema: nir; Owner: -; Tablespace: 
--

CREATE TABLE nir_links (
    l_id integer DEFAULT nextval('l_id_seq'::regclass) NOT NULL,
    l_id1 integer NOT NULL,
    l_id2 integer NOT NULL,
    l_id_link_type smallint NOT NULL,
    l_type_attr_id smallint
);


--
-- TOC entry 190 (class 1259 OID 106637076)
-- Name: ovv_id_seq; Type: SEQUENCE; Schema: nir; Owner: -
--

CREATE SEQUENCE ovv_id_seq
    START WITH 18
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


--
-- TOC entry 191 (class 1259 OID 106637078)
-- Name: nir_object_value_varchar; Type: TABLE; Schema: nir; Owner: -; Tablespace: 
--

CREATE TABLE nir_object_value_varchar (
    ovv_id integer DEFAULT nextval('ovv_id_seq'::regclass) NOT NULL,
    ovv_value character varying NOT NULL,
    ovv_link_id integer NOT NULL
);


--
-- TOC entry 192 (class 1259 OID 106637085)
-- Name: all_alerts_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW all_alerts_view AS
SELECT nir_object.o_id, nir_object.o_name, nir_object_value_varchar.ovv_value AS sql_txt, full_users_view.o_id AS user_id, full_users_view.user_id_system FROM ((((nir_object JOIN nir_links v ON ((nir_object.o_id = v.l_id1))) JOIN nir_object_value_varchar ON ((v.l_id = nir_object_value_varchar.ovv_link_id))) LEFT JOIN nir_links u ON ((nir_object.o_id = u.l_id1))) LEFT JOIN full_users_view ON ((u.l_id2 = full_users_view.o_id))) WHERE (((nir_object.o_id_type = 16) AND (v.l_id_link_type = 11)) AND ((u.l_id_link_type = 9) OR (u.l_id_link_type IS NULL)));


--
-- TOC entry 193 (class 1259 OID 106637090)
-- Name: all_atrs_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW all_atrs_view AS
SELECT nir_object.o_id, nir_object.o_name, nir_links.l_type_attr_id FROM nir_object, nir_links WHERE ((((nir_object.o_id_type = 6) AND (nir_object.o_id = nir_links.l_id1)) AND (nir_object.o_id = nir_links.l_id2)) AND (nir_links.l_id_link_type = 8));


--
-- TOC entry 194 (class 1259 OID 106637094)
-- Name: all_catalog_templates_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW all_catalog_templates_view AS
SELECT nir_object.o_id, nir_object.o_name FROM nir_object WHERE (nir_object.o_id_type = 15);


--
-- TOC entry 195 (class 1259 OID 106637098)
-- Name: all_catalogs_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW all_catalogs_view AS
SELECT nir_object.o_id, nir_object.o_name FROM nir_object WHERE (nir_object.o_id_type = 4);


--
-- TOC entry 196 (class 1259 OID 106637102)
-- Name: all_dbs_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW all_dbs_view AS
SELECT nir_object.o_id, nir_object.o_name FROM nir_object WHERE (nir_object.o_id_type = 13);


--
-- TOC entry 197 (class 1259 OID 106637106)
-- Name: all_docs_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW all_docs_view AS
SELECT nir_object.o_id, nir_object.o_name FROM nir_object WHERE (nir_object.o_id_type = 5);


--
-- TOC entry 198 (class 1259 OID 106637110)
-- Name: ovd_id_seq; Type: SEQUENCE; Schema: nir; Owner: -
--

CREATE SEQUENCE ovd_id_seq
    START WITH 18
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


--
-- TOC entry 199 (class 1259 OID 106637112)
-- Name: nir_object_value_datetime; Type: TABLE; Schema: nir; Owner: -; Tablespace: 
--

CREATE TABLE nir_object_value_datetime (
    ovd_id integer DEFAULT nextval('ovd_id_seq'::regclass) NOT NULL,
    ovd_value timestamp without time zone NOT NULL,
    ovd_link_id integer NOT NULL
);


--
-- TOC entry 200 (class 1259 OID 106637116)
-- Name: all_kzcomments_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW all_kzcomments_view AS
SELECT com.o_id, kz.o_id AS kz_id, com.o_name AS txt, u.o_id AS user_id, u.o_name AS user_name, val.ovd_value AS td FROM (((((nir_object com LEFT JOIN nir_links l1 ON ((com.o_id = l1.l_id1))) LEFT JOIN nir_object kz ON ((kz.o_id = l1.l_id2))) LEFT JOIN nir_links l2 ON ((com.o_id = l2.l_id1))) LEFT JOIN nir_object u ON ((u.o_id = l2.l_id2))) LEFT JOIN nir_object_value_datetime val ON ((l2.l_id = val.ovd_link_id))) WHERE (((((com.o_id_type = 10) AND (l1.l_id_link_type = 7)) AND (kz.o_id_type = 1)) AND (u.o_id_type = 2)) AND (l2.l_id_link_type = 9));


--
-- TOC entry 201 (class 1259 OID 106637121)
-- Name: all_kzs_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW all_kzs_view AS
SELECT nir_object.o_id, nir_object.o_name, ((full_users_view.user_id_system)::name = "current_user"()) AS isowner, nir_links.l_id2 AS user_id, full_users_view.user_name FROM ((nir_object JOIN nir_links ON ((nir_links.l_id1 = nir_object.o_id))) LEFT JOIN full_users_view ON ((full_users_view.o_id = nir_links.l_id2))) WHERE ((nir_links.l_id_link_type = 9) AND (nir_object.o_id_type = 1));


--
-- TOC entry 202 (class 1259 OID 106637125)
-- Name: all_search_templates_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW all_search_templates_view AS
SELECT nir_object.o_id, nir_object.o_name, nir_object_value_varchar.ovv_value AS sql_txt, full_users_view.o_id AS user_id, full_users_view.user_id_system FROM ((((nir_object JOIN nir_links v ON ((nir_object.o_id = v.l_id1))) JOIN nir_object_value_varchar ON ((v.l_id = nir_object_value_varchar.ovv_link_id))) LEFT JOIN nir_links u ON ((nir_object.o_id = u.l_id1))) LEFT JOIN full_users_view ON ((u.l_id2 = full_users_view.o_id))) WHERE (((nir_object.o_id_type = 9) AND (v.l_id_link_type = 11)) AND ((u.l_id_link_type = 9) OR (u.l_id_link_type IS NULL)));


--
-- TOC entry 203 (class 1259 OID 106637130)
-- Name: all_tags_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW all_tags_view AS
SELECT nir_object.o_id, nir_object.o_name FROM nir_object WHERE (nir_object.o_id_type = 11);


--
-- TOC entry 204 (class 1259 OID 106637134)
-- Name: all_temas_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW all_temas_view AS
SELECT nir_object.o_id, nir_object.o_name, nir_object_value_varchar.ovv_value FROM ((nir_object LEFT JOIN nir_links ON ((nir_links.l_id1 = nir_object.o_id))) LEFT JOIN nir_object_value_varchar ON ((nir_links.l_id = nir_object_value_varchar.ovv_link_id))) WHERE ((nir_object.o_id_type = 17) AND (nir_links.l_id_link_type = 8));


--
-- TOC entry 205 (class 1259 OID 106637138)
-- Name: all_templates_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW all_templates_view AS
SELECT nir_object.o_id, nir_object.o_name, nir_object.o_id_type, (SELECT fu.o_id FROM full_users_view fu WHERE (EXISTS (SELECT u.l_id, u.l_id1, u.l_id2, u.l_id_link_type, u.l_type_attr_id FROM nir_links u WHERE (((fu.o_id = u.l_id2) AND (nir_object.o_id = u.l_id1)) AND (u.l_id_link_type = 9)))) LIMIT 1) AS user_id, (SELECT fu.user_id_system FROM full_users_view fu WHERE (EXISTS (SELECT u.l_id, u.l_id1, u.l_id2, u.l_id_link_type, u.l_type_attr_id FROM nir_links u WHERE (((fu.o_id = u.l_id2) AND (nir_object.o_id = u.l_id1)) AND (u.l_id_link_type = 9)))) LIMIT 1) AS user_id_system FROM nir_object WHERE (nir_object.o_id_type = ANY (ARRAY[7, 8, 9, 15, 16]));


--
-- TOC entry 206 (class 1259 OID 106637143)
-- Name: obi_id_seq; Type: SEQUENCE; Schema: nir; Owner: -
--

CREATE SEQUENCE obi_id_seq
    START WITH 18
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


--
-- TOC entry 207 (class 1259 OID 106637145)
-- Name: nir_object_value_int; Type: TABLE; Schema: nir; Owner: -; Tablespace: 
--

CREATE TABLE nir_object_value_int (
    obi_id integer DEFAULT nextval('obi_id_seq'::regclass) NOT NULL,
    obi_value integer NOT NULL,
    obi_link_id integer NOT NULL
);


--
-- TOC entry 208 (class 1259 OID 106637149)
-- Name: atrs_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW atrs_view AS
SELECT t.o_id AS atr_id, t.o_name AS atr_name, t.o_id_type AS atr_type, nir_links.l_type_attr_id AS atr_typr, nir_object_value_int.obi_value AS intval, nir_object_value_varchar.ovv_value AS charval, nir_object_value_datetime.ovd_value AS dtval, o.o_id AS obj_id, o.o_name AS obj_name, o.o_id_type AS obj_type FROM nir_object o, nir_object t, (((nir_links LEFT JOIN nir_object_value_int ON ((nir_links.l_id = nir_object_value_int.obi_link_id))) LEFT JOIN nir_object_value_varchar ON ((nir_links.l_id = nir_object_value_varchar.ovv_link_id))) LEFT JOIN nir_object_value_datetime ON ((nir_links.l_id = nir_object_value_datetime.ovd_link_id))) WHERE (((nir_links.l_id1 = o.o_id) AND (nir_links.l_id2 = t.o_id)) AND (nir_links.l_id_link_type = 5));


--
-- TOC entry 209 (class 1259 OID 106637154)
-- Name: links_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW links_view AS
SELECT o.o_id AS o_id_1, o.o_name AS o_name_1, o.o_id_type AS o_type_1, t.o_id AS o_id_2, t.o_name AS o_name_2, t.o_id_type AS o_type_2, nir_links.l_id, nir_links.l_id_link_type, nir_links.l_type_attr_id FROM nir_object o, nir_object t, nir_links WHERE ((nir_links.l_id1 = o.o_id) AND (nir_links.l_id2 = t.o_id));


--
-- TOC entry 210 (class 1259 OID 106637158)
-- Name: atrs_view_2; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW atrs_view_2 AS
(SELECT links_view.o_id_1 AS obj_id, links_view.o_name_1 AS obj_name, links_view.o_type_1 AS obj_type, links_view.o_id_2 AS atr_id, links_view.o_name_2 AS atr_name, links_view.l_type_attr_id AS atr_type, (nir_object_value_int.obi_value)::text AS atr_value FROM (links_view LEFT JOIN nir_object_value_int ON ((links_view.l_id = nir_object_value_int.obi_link_id))) WHERE ((links_view.l_type_attr_id = 1) AND (links_view.l_id_link_type = 5)) UNION SELECT links_view.o_id_1 AS obj_id, links_view.o_name_1 AS obj_name, links_view.o_type_1 AS obj_type, links_view.o_id_2 AS atr_id, links_view.o_name_2 AS atr_name, links_view.l_type_attr_id AS atr_type, nir_object_value_varchar.ovv_value AS atr_value FROM (links_view LEFT JOIN nir_object_value_varchar ON ((links_view.l_id = nir_object_value_varchar.ovv_link_id))) WHERE ((links_view.l_type_attr_id = 2) AND (links_view.l_id_link_type = 5))) UNION SELECT links_view.o_id_1 AS obj_id, links_view.o_name_1 AS obj_name, links_view.o_type_1 AS obj_type, links_view.o_id_2 AS atr_id, links_view.o_name_2 AS atr_name, links_view.l_type_attr_id AS atr_type, (nir_object_value_datetime.ovd_value)::text AS atr_value FROM (links_view LEFT JOIN nir_object_value_datetime ON ((links_view.l_id = nir_object_value_datetime.ovd_link_id))) WHERE ((links_view.l_type_attr_id = 3) AND (links_view.l_id_link_type = 5));


--
-- TOC entry 211 (class 1259 OID 106637163)
-- Name: nir_parent_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW nir_parent_view AS
SELECT obj.o_id AS obj_id, obj.o_name AS obj_name, obj.o_id_type AS obj_type, par.o_id AS parent_id, par.o_name AS parent_name, par.o_id_type AS parent_id_type FROM ((SELECT a.o_id, a.o_name, a.o_id_type, b.l_id2 FROM (nir_object a JOIN nir_links b ON ((a.o_id = b.l_id1))) WHERE ((a.o_id_type = ANY (ARRAY[4, 5])) AND (b.l_id_link_type = (1)::smallint))) obj JOIN nir_object par ON ((obj.l_id2 = par.o_id)));


--
-- TOC entry 212 (class 1259 OID 106637167)
-- Name: cats_of_cat_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW cats_of_cat_view AS
SELECT nir_parent_view.parent_id, nir_parent_view.parent_name, nir_parent_view.parent_id_type, nir_parent_view.obj_id, nir_parent_view.obj_name FROM nir_parent_view WHERE (nir_parent_view.obj_type = 4);


--
-- TOC entry 213 (class 1259 OID 106637171)
-- Name: docs_of_cat_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW docs_of_cat_view AS
SELECT nir_parent_view.parent_id, nir_parent_view.parent_name, nir_parent_view.parent_id_type, nir_parent_view.obj_id, nir_parent_view.obj_name FROM nir_parent_view WHERE (nir_parent_view.obj_type = 5);


--
-- TOC entry 214 (class 1259 OID 106637175)
-- Name: nir_group; Type: TABLE; Schema: nir; Owner: -; Tablespace: 
--

CREATE TABLE nir_group (
    group_id integer NOT NULL,
    group_name character varying NOT NULL,
    id_object integer,
    gr_sys_name text
);


--
-- TOC entry 215 (class 1259 OID 106637181)
-- Name: nir_group_role; Type: TABLE; Schema: nir; Owner: -; Tablespace: 
--

CREATE TABLE nir_group_role (
    group_id integer NOT NULL,
    role_id integer NOT NULL
);


--
-- TOC entry 216 (class 1259 OID 106637184)
-- Name: full_groups_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW full_groups_view AS
SELECT nir_object.o_id, nir_object.o_name, nir_object.o_id_type, nir_group.group_id, nir_group.group_name, nir_group.gr_sys_name, (EXISTS (SELECT nir_group_role.group_id, nir_group_role.role_id FROM nir_group_role WHERE ((nir_group_role.group_id = nir_group.group_id) AND (nir_group_role.role_id = 1)))) AS isadmin, (EXISTS (SELECT nir_group_role.group_id, nir_group_role.role_id FROM nir_group_role WHERE ((nir_group_role.group_id = nir_group.group_id) AND (nir_group_role.role_id <= 2)))) AS iseditor, (EXISTS (SELECT nir_group_role.group_id, nir_group_role.role_id FROM nir_group_role WHERE ((nir_group_role.group_id = nir_group.group_id) AND (nir_group_role.role_id <= 3)))) AS isworker, (EXISTS (SELECT nir_group_role.group_id, nir_group_role.role_id FROM nir_group_role WHERE ((nir_group_role.group_id = nir_group.group_id) AND (nir_group_role.role_id <= 4)))) AS isreader, (EXISTS (SELECT nir_group_role.group_id, nir_group_role.role_id FROM nir_group_role WHERE ((nir_group_role.group_id = nir_group.group_id) AND (nir_group_role.role_id <= 5)))) AS isdirector FROM (nir_group JOIN nir_object ON ((nir_object.o_id = nir_group.id_object)));


--
-- TOC entry 217 (class 1259 OID 106637189)
-- Name: role_id_seq; Type: SEQUENCE; Schema: nir; Owner: -
--

CREATE SEQUENCE role_id_seq
    START WITH 23
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 32767
    CACHE 1;


--
-- TOC entry 218 (class 1259 OID 106637191)
-- Name: nir_role; Type: TABLE; Schema: nir; Owner: -; Tablespace: 
--

CREATE TABLE nir_role (
    r_id integer DEFAULT nextval('role_id_seq'::regclass) NOT NULL,
    r_name character varying NOT NULL,
    r_info character varying NOT NULL,
    r_desc character varying,
    r_parent integer,
    r_code bit varying DEFAULT B'0'::"bit"
);


--
-- TOC entry 219 (class 1259 OID 106637199)
-- Name: group_role_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW group_role_view AS
SELECT u.group_name, u.gr_sys_name, r.r_name, r.r_info, r.r_desc FROM ((nir_group_role ur JOIN nir_group u ON ((ur.group_id = u.group_id))) JOIN nir_role r ON ((r.r_id = ur.role_id)));


--
-- TOC entry 220 (class 1259 OID 106637203)
-- Name: nir_group_user; Type: TABLE; Schema: nir; Owner: -; Tablespace: 
--

CREATE TABLE nir_group_user (
    user_id integer NOT NULL,
    group_id integer NOT NULL
);


--
-- TOC entry 221 (class 1259 OID 106637206)
-- Name: group_user_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW group_user_view AS
SELECT u.user_id, u.user_id_object AS obj_user_id, u.user_name, u.user_id_system, g.group_id, g.id_object AS obj_group_id, g.group_name, g.gr_sys_name FROM ((nir_group_user gu JOIN nir_user u ON ((u.user_id = gu.user_id))) JOIN nir_group g ON ((g.group_id = gu.group_id)));


--
-- TOC entry 222 (class 1259 OID 106637210)
-- Name: kzcomment_id_seq; Type: SEQUENCE; Schema: nir; Owner: -
--

CREATE SEQUENCE kzcomment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 223 (class 1259 OID 106637212)
-- Name: lt_id_seq; Type: SEQUENCE; Schema: nir; Owner: -
--

CREATE SEQUENCE lt_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 32767
    CACHE 1;


--
-- TOC entry 224 (class 1259 OID 106637214)
-- Name: module_id_seq; Type: SEQUENCE; Schema: nir; Owner: -
--

CREATE SEQUENCE module_id_seq
    START WITH 23
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 32767
    CACHE 1;


--
-- TOC entry 225 (class 1259 OID 106637216)
-- Name: module_role_id_seq; Type: SEQUENCE; Schema: nir; Owner: -
--

CREATE SEQUENCE module_role_id_seq
    START WITH 23
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 32767
    CACHE 1;


--
-- TOC entry 226 (class 1259 OID 106637218)
-- Name: nir_kz_parent_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW nir_kz_parent_view AS
SELECT obj.o_id AS doc_id, obj.o_name AS doc_name, obj.o_id_type AS doc_id_type, par.o_id AS parent_id FROM ((SELECT a.o_id, a.o_name, a.o_id_type, b.l_id2 FROM (nir_object a JOIN nir_links b ON ((a.o_id = b.l_id1))) WHERE ((a.o_id_type = ANY (ARRAY[1, 5])) AND (b.l_id_link_type = (1)::smallint))) obj JOIN nir_object par ON ((obj.l_id2 = par.o_id))) WHERE (par.o_id_type = (1)::smallint);


--
-- TOC entry 227 (class 1259 OID 106637222)
-- Name: nir_link_type; Type: TABLE; Schema: nir; Owner: -; Tablespace: 
--

CREATE TABLE nir_link_type (
    lt_id integer DEFAULT nextval('lt_id_seq'::regclass) NOT NULL,
    lt_name character varying NOT NULL
);


--
-- TOC entry 228 (class 1259 OID 106637229)
-- Name: object_role_id_seq; Type: SEQUENCE; Schema: nir; Owner: -
--

CREATE SEQUENCE object_role_id_seq
    START WITH 25
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 32767
    CACHE 1;


--
-- TOC entry 229 (class 1259 OID 106637231)
-- Name: nir_object_role; Type: TABLE; Schema: nir; Owner: -; Tablespace: 
--

CREATE TABLE nir_object_role (
    object_role_id integer DEFAULT nextval('object_role_id_seq'::regclass) NOT NULL,
    object_id integer NOT NULL,
    role_id integer NOT NULL
);


--
-- TOC entry 230 (class 1259 OID 106637235)
-- Name: ot_id_seq; Type: SEQUENCE; Schema: nir; Owner: -
--

CREATE SEQUENCE ot_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 32767
    CACHE 1;


--
-- TOC entry 231 (class 1259 OID 106637237)
-- Name: nir_object_type; Type: TABLE; Schema: nir; Owner: -; Tablespace: 
--

CREATE TABLE nir_object_type (
    ot_id smallint DEFAULT nextval('ot_id_seq'::regclass) NOT NULL,
    ot_name character varying NOT NULL
);


--
-- TOC entry 232 (class 1259 OID 106637244)
-- Name: vam_id_seq; Type: SEQUENCE; Schema: nir; Owner: -
--

CREATE SEQUENCE vam_id_seq
    START WITH 155
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 233 (class 1259 OID 106637246)
-- Name: nir_object_value_act_mask; Type: TABLE; Schema: nir; Owner: -; Tablespace: 
--

CREATE TABLE nir_object_value_act_mask (
    vam_id integer DEFAULT nextval('vam_id_seq'::regclass) NOT NULL,
    vam_value integer NOT NULL,
    vam_link_id integer NOT NULL,
    vam_value2 integer,
    vam_value3 integer,
    vam_value4 integer DEFAULT 0
);


--
-- TOC entry 234 (class 1259 OID 106637251)
-- Name: ta_id_seq; Type: SEQUENCE; Schema: nir; Owner: -
--

CREATE SEQUENCE ta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 32767
    CACHE 1;


--
-- TOC entry 235 (class 1259 OID 106637253)
-- Name: nir_type_attr; Type: TABLE; Schema: nir; Owner: -; Tablespace: 
--

CREATE TABLE nir_type_attr (
    ta_id smallint DEFAULT nextval('ta_id_seq'::regclass) NOT NULL,
    ta_name text NOT NULL
);


--
-- TOC entry 236 (class 1259 OID 106637260)
-- Name: nir_user_ald; Type: TABLE; Schema: nir; Owner: -; Tablespace: 
--

CREATE TABLE nir_user_ald (
    id integer NOT NULL,
    full_name character varying,
    number character varying,
    birthday date,
    username text
);


--
-- TOC entry 237 (class 1259 OID 106637266)
-- Name: ra_id_seq; Type: SEQUENCE; Schema: nir; Owner: -
--

CREATE SEQUENCE ra_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 238 (class 1259 OID 106637268)
-- Name: rights_access; Type: TABLE; Schema: nir; Owner: -; Tablespace: 
--

CREATE TABLE rights_access (
    roa_id integer NOT NULL,
    roa_id_object integer,
    roa_id_subject integer,
    roa_bit_map bit varying DEFAULT B'0'::"bit" NOT NULL
);


--
-- TOC entry 239 (class 1259 OID 106637275)
-- Name: rights_access_roa_id_seq; Type: SEQUENCE; Schema: nir; Owner: -
--

CREATE SEQUENCE rights_access_roa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2658 (class 0 OID 0)
-- Dependencies: 239
-- Name: rights_access_roa_id_seq; Type: SEQUENCE OWNED BY; Schema: nir; Owner: -
--

ALTER SEQUENCE rights_access_roa_id_seq OWNED BY rights_access.roa_id;


--
-- TOC entry 240 (class 1259 OID 106637277)
-- Name: rights_of_access_id_seq; Type: SEQUENCE; Schema: nir; Owner: -
--

CREATE SEQUENCE rights_of_access_id_seq
    START WITH 26
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 32767
    CACHE 1;


--
-- TOC entry 241 (class 1259 OID 106637279)
-- Name: rights_of_groups; Type: TABLE; Schema: nir; Owner: -; Tablespace: 
--

CREATE TABLE rights_of_groups (
    rog_id integer NOT NULL,
    rog_id_object integer,
    rog_id_subject integer,
    rog_bit_map bit varying DEFAULT B'0'::"bit" NOT NULL
);


--
-- TOC entry 242 (class 1259 OID 106637286)
-- Name: rights_of_groups_rog_id_seq; Type: SEQUENCE; Schema: nir; Owner: -
--

CREATE SEQUENCE rights_of_groups_rog_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2659 (class 0 OID 0)
-- Dependencies: 242
-- Name: rights_of_groups_rog_id_seq; Type: SEQUENCE OWNED BY; Schema: nir; Owner: -
--

ALTER SEQUENCE rights_of_groups_rog_id_seq OWNED BY rights_of_groups.rog_id;


--
-- TOC entry 243 (class 1259 OID 106637288)
-- Name: role_obj_type; Type: TABLE; Schema: nir; Owner: -; Tablespace: 
--

CREATE TABLE role_obj_type (
    role_access_id integer NOT NULL,
    role_id integer,
    role_access_id_object_type integer
);


--
-- TOC entry 244 (class 1259 OID 106637291)
-- Name: role_access_real; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW role_access_real AS
SELECT role_obj_type.role_access_id, nir_role.r_info AS role_access_name, nir_role.r_desc AS role_access_desc, role_obj_type.role_access_id_object_type, nir_role.r_code AS role_access_mask FROM (role_obj_type LEFT JOIN nir_role ON ((nir_role.r_id = role_obj_type.role_id)));


--
-- TOC entry 245 (class 1259 OID 106637295)
-- Name: role_access_seq; Type: SEQUENCE; Schema: nir; Owner: -
--

CREATE SEQUENCE role_access_seq
    START WITH 26
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 32767
    CACHE 1;


--
-- TOC entry 246 (class 1259 OID 106637297)
-- Name: role_obj_type_role_access_id_seq; Type: SEQUENCE; Schema: nir; Owner: -
--

CREATE SEQUENCE role_obj_type_role_access_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2660 (class 0 OID 0)
-- Dependencies: 246
-- Name: role_obj_type_role_access_id_seq; Type: SEQUENCE OWNED BY; Schema: nir; Owner: -
--

ALTER SEQUENCE role_obj_type_role_access_id_seq OWNED BY role_obj_type.role_access_id;


--
-- TOC entry 247 (class 1259 OID 106637299)
-- Name: tags_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW tags_view AS
SELECT t.o_id AS tag_id, t.o_name AS tag_name, t.o_id_type AS tag_type, o.o_id AS obj_id, o.o_name AS obj_name, o.o_id_type AS obj_type FROM nir_object o, nir_links, nir_object t WHERE (((nir_links.l_id1 = o.o_id) AND (nir_links.l_id2 = t.o_id)) AND (nir_links.l_id_link_type = 4));


--
-- TOC entry 248 (class 1259 OID 106637303)
-- Name: user_groiup_id_seq; Type: SEQUENCE; Schema: nir; Owner: -
--

CREATE SEQUENCE user_groiup_id_seq
    START WITH 26
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 32767
    CACHE 1;


--
-- TOC entry 249 (class 1259 OID 106637305)
-- Name: user_id_seq; Type: SEQUENCE; Schema: nir; Owner: -
--

CREATE SEQUENCE user_id_seq
    START WITH 23
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 32767
    CACHE 1;


--
-- TOC entry 294 (class 1259 OID 139061279)
-- Name: user_profile_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW user_profile_view AS
SELECT ttt.o_id_1 AS profile_id, ttt.o_name_1 AS profile_name, uuu.o_id AS user_id FROM (nir_object uuu LEFT JOIN (SELECT t.o_id_2 AS uid, t.o_id_1, t.o_name_1 FROM links_view t WHERE ((t.o_type_1 = 18) AND (t.o_type_2 = 2))) ttt ON ((ttt.uid = uuu.o_id))) WHERE (uuu.o_id_type = 2);


--
-- TOC entry 250 (class 1259 OID 106637311)
-- Name: user_role_id_seq; Type: SEQUENCE; Schema: nir; Owner: -
--

CREATE SEQUENCE user_role_id_seq
    START WITH 23
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 32767
    CACHE 1;


--
-- TOC entry 251 (class 1259 OID 106637313)
-- Name: user_role_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW user_role_view AS
SELECT u.user_id_system, u.user_name, r.r_name, r.r_info, r.r_desc FROM ((nir_user_role ur JOIN nir_user u ON ((ur.user_id = u.user_id))) JOIN nir_role r ON ((r.r_id = ur.role_id)));


--
-- TOC entry 252 (class 1259 OID 106637317)
-- Name: user_tema_view; Type: VIEW; Schema: nir; Owner: -
--

CREATE VIEW user_tema_view AS
SELECT ttt.o_id, ttt.o_name, ttt.ovv_value, uuu.o_id AS user_id FROM (nir_object uuu LEFT JOIN (SELECT all_temas_view.o_id, all_temas_view.o_name, all_temas_view.ovv_value, u.o_id_2 AS uid FROM ((links_view t LEFT JOIN links_view u ON ((t.o_id_2 = u.o_id_1))) LEFT JOIN all_temas_view ON ((t.o_id_1 = all_temas_view.o_id))) WHERE (((t.o_type_1 = 17) AND (t.o_type_2 = 18)) AND (u.o_type_2 = 2))) ttt ON ((ttt.uid = uuu.o_id))) WHERE (uuu.o_id_type = 2);


SET search_path = public, pg_catalog;

--
-- TOC entry 253 (class 1259 OID 106637322)
-- Name: a_action_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE a_action_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 254 (class 1259 OID 106637324)
-- Name: Nir_Action; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "Nir_Action" (
    a_action_id integer DEFAULT nextval('a_action_id_seq'::regclass) NOT NULL,
    a_add_object boolean NOT NULL,
    a_browse_object boolean NOT NULL,
    a_edit_object boolean NOT NULL,
    a_delete_object boolean NOT NULL,
    "a_addComment_object" boolean NOT NULL,
    "a_deleteComment_object" boolean NOT NULL
);


--
-- TOC entry 255 (class 1259 OID 106637328)
-- Name: r_role_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE r_role_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 256 (class 1259 OID 106637330)
-- Name: Nir_Role; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "Nir_Role" (
    r_role_id integer DEFAULT nextval('r_role_id_seq'::regclass) NOT NULL,
    "r_roleName" character varying NOT NULL,
    r_information character varying NOT NULL
);


--
-- TOC entry 257 (class 1259 OID 106637337)
-- Name: u_userid_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE u_userid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 258 (class 1259 OID 106637339)
-- Name: Nir_User; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "Nir_User" (
    "u_userId" integer DEFAULT nextval('u_userid_seq'::regclass) NOT NULL,
    u_username character varying NOT NULL,
    u_password character varying NOT NULL,
    u_info character varying NOT NULL,
    u_id_object integer
);


--
-- TOC entry 259 (class 1259 OID 106637346)
-- Name: lt_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE lt_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 260 (class 1259 OID 106637348)
-- Name: Nir_link_type; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "Nir_link_type" (
    lt_id integer DEFAULT nextval('lt_id_seq'::regclass) NOT NULL,
    lt_name character varying NOT NULL
);


--
-- TOC entry 261 (class 1259 OID 106637355)
-- Name: l_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE l_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 262 (class 1259 OID 106637357)
-- Name: Nir_links; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "Nir_links" (
    l_id integer DEFAULT nextval('l_id_seq'::regclass) NOT NULL,
    l_id1 integer NOT NULL,
    l_id2 integer NOT NULL,
    l_id_link_type integer NOT NULL,
    l_type_attr_id integer
);


--
-- TOC entry 263 (class 1259 OID 106637361)
-- Name: o_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE o_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 264 (class 1259 OID 106637363)
-- Name: Nir_object; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "Nir_object" (
    o_id integer DEFAULT nextval('o_id_seq'::regclass) NOT NULL,
    o_name character varying(255) NOT NULL,
    o_id_type integer NOT NULL
);


--
-- TOC entry 265 (class 1259 OID 106637367)
-- Name: ot_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE ot_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 266 (class 1259 OID 106637369)
-- Name: Nir_object_type; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "Nir_object_type" (
    ot_id integer DEFAULT nextval('ot_id_seq'::regclass) NOT NULL,
    ot_name character varying NOT NULL
);


--
-- TOC entry 267 (class 1259 OID 106637376)
-- Name: ovd_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE ovd_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 268 (class 1259 OID 106637378)
-- Name: Nir_object_value_date; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "Nir_object_value_date" (
    ovd_id integer DEFAULT nextval('ovd_id_seq'::regclass) NOT NULL,
    ovd_value date NOT NULL,
    ovd_link_id integer NOT NULL
);


--
-- TOC entry 269 (class 1259 OID 106637382)
-- Name: obi_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE obi_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 270 (class 1259 OID 106637384)
-- Name: Nir_object_value_int; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "Nir_object_value_int" (
    obi_id integer DEFAULT nextval('obi_id_seq'::regclass) NOT NULL,
    obi_value integer NOT NULL,
    obi_link_id integer NOT NULL
);


--
-- TOC entry 271 (class 1259 OID 106637388)
-- Name: ovv_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE ovv_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 272 (class 1259 OID 106637390)
-- Name: Nir_object_value_varchar; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "Nir_object_value_varchar" (
    ovv_id integer DEFAULT nextval('ovv_id_seq'::regclass) NOT NULL,
    ovv_value character varying NOT NULL,
    ovv_link_id integer NOT NULL
);


--
-- TOC entry 273 (class 1259 OID 106637397)
-- Name: ra_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE ra_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 274 (class 1259 OID 106637399)
-- Name: Nir_role_action; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "Nir_role_action" (
    ra_id integer DEFAULT nextval('ra_id_seq'::regclass) NOT NULL,
    ra_role_id integer NOT NULL,
    ra_action_id integer NOT NULL,
    ra_object_id integer NOT NULL
);


--
-- TOC entry 275 (class 1259 OID 106637403)
-- Name: ta_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE ta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 276 (class 1259 OID 106637405)
-- Name: Nir_type_attr; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "Nir_type_attr" (
    ta_id integer DEFAULT nextval('ta_id_seq'::regclass) NOT NULL,
    ta_name text
);


--
-- TOC entry 277 (class 1259 OID 106637412)
-- Name: ur_usertorole_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE ur_usertorole_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 278 (class 1259 OID 106637414)
-- Name: Nir_user_role; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE "Nir_user_role" (
    "ur_userToRole" integer DEFAULT nextval('ur_usertorole_seq'::regclass) NOT NULL,
    ur_role_id integer NOT NULL,
    ur_user_id integer NOT NULL
);


--
-- TOC entry 279 (class 1259 OID 106637418)
-- Name: objec; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE objec (
    o_name character varying(255)
);


SET search_path = nir, pg_catalog;

--
-- TOC entry 2407 (class 2604 OID 106637421)
-- Name: roa_id; Type: DEFAULT; Schema: nir; Owner: -
--

ALTER TABLE ONLY rights_access ALTER COLUMN roa_id SET DEFAULT nextval('rights_access_roa_id_seq'::regclass);


--
-- TOC entry 2409 (class 2604 OID 106637422)
-- Name: rog_id; Type: DEFAULT; Schema: nir; Owner: -
--

ALTER TABLE ONLY rights_of_groups ALTER COLUMN rog_id SET DEFAULT nextval('rights_of_groups_rog_id_seq'::regclass);


--
-- TOC entry 2410 (class 2604 OID 106637423)
-- Name: role_access_id; Type: DEFAULT; Schema: nir; Owner: -
--

ALTER TABLE ONLY role_obj_type ALTER COLUMN role_access_id SET DEFAULT nextval('role_obj_type_role_access_id_seq'::regclass);


--
-- TOC entry 2444 (class 2606 OID 106637425)
-- Name: Nir_Role_id; Type: CONSTRAINT; Schema: nir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nir_role
    ADD CONSTRAINT "Nir_Role_id" PRIMARY KEY (r_id);


--
-- TOC entry 2430 (class 2606 OID 106637427)
-- Name: Nir_User_Role_id; Type: CONSTRAINT; Schema: nir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nir_user_role
    ADD CONSTRAINT "Nir_User_Role_id" PRIMARY KEY (user_id, role_id);


--
-- TOC entry 2442 (class 2606 OID 106637429)
-- Name: Nir_User_group_id; Type: CONSTRAINT; Schema: nir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nir_group_role
    ADD CONSTRAINT "Nir_User_group_id" PRIMARY KEY (group_id, role_id);


--
-- TOC entry 2427 (class 2606 OID 106637431)
-- Name: Nir_User_pk; Type: CONSTRAINT; Schema: nir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nir_user
    ADD CONSTRAINT "Nir_User_pk" PRIMARY KEY (user_id);


--
-- TOC entry 2462 (class 2606 OID 106637433)
-- Name: Nir_User_pk2; Type: CONSTRAINT; Schema: nir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nir_user_ald
    ADD CONSTRAINT "Nir_User_pk2" PRIMARY KEY (id);


--
-- TOC entry 2440 (class 2606 OID 106637435)
-- Name: Nir_group_pk; Type: CONSTRAINT; Schema: nir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nir_group
    ADD CONSTRAINT "Nir_group_pk" PRIMARY KEY (group_id);


--
-- TOC entry 2464 (class 2606 OID 106637437)
-- Name: Nir_rights_access; Type: CONSTRAINT; Schema: nir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY rights_access
    ADD CONSTRAINT "Nir_rights_access" PRIMARY KEY (roa_id);


--
-- TOC entry 2466 (class 2606 OID 106637439)
-- Name: Nir_rights_of_groups; Type: CONSTRAINT; Schema: nir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY rights_of_groups
    ADD CONSTRAINT "Nir_rights_of_groups" PRIMARY KEY (rog_id);


--
-- TOC entry 2446 (class 2606 OID 106637441)
-- Name: Nir_user_group_pk; Type: CONSTRAINT; Schema: nir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nir_group_user
    ADD CONSTRAINT "Nir_user_group_pk" PRIMARY KEY (user_id, group_id);


--
-- TOC entry 2448 (class 2606 OID 106637443)
-- Name: nir_link_type_lt_name_key; Type: CONSTRAINT; Schema: nir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nir_link_type
    ADD CONSTRAINT nir_link_type_lt_name_key UNIQUE (lt_name);


--
-- TOC entry 2450 (class 2606 OID 106637445)
-- Name: nir_link_type_pk; Type: CONSTRAINT; Schema: nir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nir_link_type
    ADD CONSTRAINT nir_link_type_pk PRIMARY KEY (lt_id);


--
-- TOC entry 2432 (class 2606 OID 106637447)
-- Name: nir_links_pk; Type: CONSTRAINT; Schema: nir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nir_links
    ADD CONSTRAINT nir_links_pk PRIMARY KEY (l_id);


--
-- TOC entry 2425 (class 2606 OID 106637449)
-- Name: nir_object_pk; Type: CONSTRAINT; Schema: nir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nir_object
    ADD CONSTRAINT nir_object_pk PRIMARY KEY (o_id);


--
-- TOC entry 2452 (class 2606 OID 106637451)
-- Name: nir_object_role_id; Type: CONSTRAINT; Schema: nir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nir_object_role
    ADD CONSTRAINT nir_object_role_id PRIMARY KEY (object_role_id);


--
-- TOC entry 2454 (class 2606 OID 106637453)
-- Name: nir_object_type_ot_name_key; Type: CONSTRAINT; Schema: nir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nir_object_type
    ADD CONSTRAINT nir_object_type_ot_name_key UNIQUE (ot_name);


--
-- TOC entry 2456 (class 2606 OID 106637455)
-- Name: nir_object_type_pk; Type: CONSTRAINT; Schema: nir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nir_object_type
    ADD CONSTRAINT nir_object_type_pk PRIMARY KEY (ot_id);


--
-- TOC entry 2436 (class 2606 OID 106637457)
-- Name: nir_object_value_datetime_pk; Type: CONSTRAINT; Schema: nir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nir_object_value_datetime
    ADD CONSTRAINT nir_object_value_datetime_pk PRIMARY KEY (ovd_id);


--
-- TOC entry 2438 (class 2606 OID 106637459)
-- Name: nir_object_value_int_pk; Type: CONSTRAINT; Schema: nir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nir_object_value_int
    ADD CONSTRAINT nir_object_value_int_pk PRIMARY KEY (obi_id);


--
-- TOC entry 2434 (class 2606 OID 106637461)
-- Name: nir_object_value_varchar_pk; Type: CONSTRAINT; Schema: nir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nir_object_value_varchar
    ADD CONSTRAINT nir_object_value_varchar_pk PRIMARY KEY (ovv_id);


--
-- TOC entry 2468 (class 2606 OID 106637463)
-- Name: nir_role_obj_type_pk; Type: CONSTRAINT; Schema: nir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY role_obj_type
    ADD CONSTRAINT nir_role_obj_type_pk PRIMARY KEY (role_access_id);


--
-- TOC entry 2458 (class 2606 OID 106637465)
-- Name: nir_type_attr_ta_name_key; Type: CONSTRAINT; Schema: nir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nir_type_attr
    ADD CONSTRAINT nir_type_attr_ta_name_key UNIQUE (ta_name);


--
-- TOC entry 2460 (class 2606 OID 106637467)
-- Name: pk_type_attr; Type: CONSTRAINT; Schema: nir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY nir_type_attr
    ADD CONSTRAINT pk_type_attr PRIMARY KEY (ta_id);


SET search_path = public, pg_catalog;

--
-- TOC entry 2470 (class 2606 OID 106637469)
-- Name: nir_action_pk; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "Nir_Action"
    ADD CONSTRAINT nir_action_pk PRIMARY KEY (a_action_id);


--
-- TOC entry 2477 (class 2606 OID 106637471)
-- Name: nir_link_type_pk; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "Nir_link_type"
    ADD CONSTRAINT nir_link_type_pk PRIMARY KEY (lt_id);


--
-- TOC entry 2479 (class 2606 OID 106637473)
-- Name: nir_links_pk; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "Nir_links"
    ADD CONSTRAINT nir_links_pk PRIMARY KEY (l_id);


--
-- TOC entry 2481 (class 2606 OID 106637475)
-- Name: nir_object_pk; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "Nir_object"
    ADD CONSTRAINT nir_object_pk PRIMARY KEY (o_id);


--
-- TOC entry 2483 (class 2606 OID 106637477)
-- Name: nir_object_type_pk; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "Nir_object_type"
    ADD CONSTRAINT nir_object_type_pk PRIMARY KEY (ot_id);


--
-- TOC entry 2485 (class 2606 OID 106637479)
-- Name: nir_object_value_date_pk; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "Nir_object_value_date"
    ADD CONSTRAINT nir_object_value_date_pk PRIMARY KEY (ovd_id);


--
-- TOC entry 2487 (class 2606 OID 106637481)
-- Name: nir_object_value_int_pk; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "Nir_object_value_int"
    ADD CONSTRAINT nir_object_value_int_pk PRIMARY KEY (obi_id);


--
-- TOC entry 2489 (class 2606 OID 106637483)
-- Name: nir_object_value_varchar_pk; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "Nir_object_value_varchar"
    ADD CONSTRAINT nir_object_value_varchar_pk PRIMARY KEY (ovv_id);


--
-- TOC entry 2491 (class 2606 OID 106637485)
-- Name: nir_role_action_pk; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "Nir_role_action"
    ADD CONSTRAINT nir_role_action_pk PRIMARY KEY (ra_id);


--
-- TOC entry 2472 (class 2606 OID 106637487)
-- Name: nir_role_pk; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "Nir_Role"
    ADD CONSTRAINT nir_role_pk PRIMARY KEY (r_role_id);


--
-- TOC entry 2475 (class 2606 OID 106637489)
-- Name: nir_user_pk; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "Nir_User"
    ADD CONSTRAINT nir_user_pk PRIMARY KEY ("u_userId");


--
-- TOC entry 2495 (class 2606 OID 106637491)
-- Name: nir_user_role_pk; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "Nir_user_role"
    ADD CONSTRAINT nir_user_role_pk PRIMARY KEY ("ur_userToRole");


--
-- TOC entry 2493 (class 2606 OID 106637493)
-- Name: pk_type_attr; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY "Nir_type_attr"
    ADD CONSTRAINT pk_type_attr PRIMARY KEY (ta_id);


SET search_path = nir, pg_catalog;

--
-- TOC entry 2428 (class 1259 OID 106637494)
-- Name: fki_user_id_object; Type: INDEX; Schema: nir; Owner: -; Tablespace: 
--

CREATE INDEX fki_user_id_object ON nir_user USING btree (user_id_object);


SET search_path = public, pg_catalog;

--
-- TOC entry 2473 (class 1259 OID 106637495)
-- Name: fki_user_id_object; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX fki_user_id_object ON "Nir_User" USING btree (u_id_object);


SET search_path = nir, pg_catalog;

--
-- TOC entry 2515 (class 2606 OID 106637496)
-- Name: CASCADE_DELETE_UPADTE__act_mask; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY nir_object_value_act_mask
    ADD CONSTRAINT "CASCADE_DELETE_UPADTE__act_mask" FOREIGN KEY (vam_link_id) REFERENCES nir_links(l_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2508 (class 2606 OID 106637501)
-- Name: CASCADE_DELETE_UPDATE_group_role1; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY nir_group_role
    ADD CONSTRAINT "CASCADE_DELETE_UPDATE_group_role1" FOREIGN KEY (group_id) REFERENCES nir_group(group_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2507 (class 2606 OID 106637506)
-- Name: CASCADE_DELETE_UPDATE_group_role2; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY nir_group_role
    ADD CONSTRAINT "CASCADE_DELETE_UPDATE_group_role2" FOREIGN KEY (role_id) REFERENCES nir_role(r_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2513 (class 2606 OID 106637511)
-- Name: CASCADE_DELETE_UPDATE_object_role1; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY nir_object_role
    ADD CONSTRAINT "CASCADE_DELETE_UPDATE_object_role1" FOREIGN KEY (object_id) REFERENCES nir_object(o_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2512 (class 2606 OID 106637516)
-- Name: CASCADE_DELETE_UPDATE_object_role2; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY nir_object_role
    ADD CONSTRAINT "CASCADE_DELETE_UPDATE_object_role2" FOREIGN KEY (role_id) REFERENCES nir_role(r_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2498 (class 2606 OID 106637521)
-- Name: CASCADE_DELETE_UPDATE_user_role1; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY nir_user_role
    ADD CONSTRAINT "CASCADE_DELETE_UPDATE_user_role1" FOREIGN KEY (user_id) REFERENCES nir_user(user_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2497 (class 2606 OID 106637526)
-- Name: CASCADE_DELETE_UPDATE_user_role2; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY nir_user_role
    ADD CONSTRAINT "CASCADE_DELETE_UPDATE_user_role2" FOREIGN KEY (role_id) REFERENCES nir_role(r_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2514 (class 2606 OID 106637531)
-- Name: Nir_object_value_act_mask_fk0; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY nir_object_value_act_mask
    ADD CONSTRAINT "Nir_object_value_act_mask_fk0" FOREIGN KEY (vam_link_id) REFERENCES nir_links(l_id);


--
-- TOC entry 2504 (class 2606 OID 106637536)
-- Name: cascade_delete_upadte__valuedate; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY nir_object_value_datetime
    ADD CONSTRAINT cascade_delete_upadte__valuedate FOREIGN KEY (ovd_link_id) REFERENCES nir_links(l_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2505 (class 2606 OID 106637541)
-- Name: cascade_delete_upadte__valueint; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY nir_object_value_int
    ADD CONSTRAINT cascade_delete_upadte__valueint FOREIGN KEY (obi_link_id) REFERENCES nir_links(l_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2503 (class 2606 OID 106637546)
-- Name: cascade_delete_upadte__valuevarchar; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY nir_object_value_varchar
    ADD CONSTRAINT cascade_delete_upadte__valuevarchar FOREIGN KEY (ovv_link_id) REFERENCES nir_links(l_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2506 (class 2606 OID 106637551)
-- Name: nir_group_fk0; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY nir_group
    ADD CONSTRAINT nir_group_fk0 FOREIGN KEY (id_object) REFERENCES nir_object(o_id);


--
-- TOC entry 2511 (class 2606 OID 106637556)
-- Name: nir_group_user_fk0; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY nir_group_user
    ADD CONSTRAINT nir_group_user_fk0 FOREIGN KEY (user_id) REFERENCES nir_user(user_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2510 (class 2606 OID 106637561)
-- Name: nir_group_user_fk1; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY nir_group_user
    ADD CONSTRAINT nir_group_user_fk1 FOREIGN KEY (group_id) REFERENCES nir_group(group_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2502 (class 2606 OID 106637566)
-- Name: nir_links_fk0; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY nir_links
    ADD CONSTRAINT nir_links_fk0 FOREIGN KEY (l_id1) REFERENCES nir_object(o_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2501 (class 2606 OID 106637571)
-- Name: nir_links_fk1; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY nir_links
    ADD CONSTRAINT nir_links_fk1 FOREIGN KEY (l_id2) REFERENCES nir_object(o_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2500 (class 2606 OID 106637576)
-- Name: nir_links_fk2; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY nir_links
    ADD CONSTRAINT nir_links_fk2 FOREIGN KEY (l_id_link_type) REFERENCES nir_link_type(lt_id);


--
-- TOC entry 2499 (class 2606 OID 106637581)
-- Name: nir_links_fk3; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY nir_links
    ADD CONSTRAINT nir_links_fk3 FOREIGN KEY (l_type_attr_id) REFERENCES nir_type_attr(ta_id);


--
-- TOC entry 2517 (class 2606 OID 106637586)
-- Name: nir_links_fk3; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY rights_access
    ADD CONSTRAINT nir_links_fk3 FOREIGN KEY (roa_id_subject) REFERENCES nir_object(o_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2519 (class 2606 OID 106637591)
-- Name: nir_links_fk3; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY rights_of_groups
    ADD CONSTRAINT nir_links_fk3 FOREIGN KEY (rog_id_subject) REFERENCES nir_object(o_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2496 (class 2606 OID 106637596)
-- Name: nir_object_fk0; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY nir_object
    ADD CONSTRAINT nir_object_fk0 FOREIGN KEY (o_id_type) REFERENCES nir_object_type(ot_id);


--
-- TOC entry 2516 (class 2606 OID 106637601)
-- Name: nir_rights_of_access_fk3; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY rights_access
    ADD CONSTRAINT nir_rights_of_access_fk3 FOREIGN KEY (roa_id_object) REFERENCES nir_object(o_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2518 (class 2606 OID 106637606)
-- Name: nir_rights_of_groups_fk3; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY rights_of_groups
    ADD CONSTRAINT nir_rights_of_groups_fk3 FOREIGN KEY (rog_id_object) REFERENCES nir_object(o_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2521 (class 2606 OID 106637611)
-- Name: nir_role_access_real_fk1; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY role_obj_type
    ADD CONSTRAINT nir_role_access_real_fk1 FOREIGN KEY (role_access_id_object_type) REFERENCES nir_object_type(ot_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2520 (class 2606 OID 106637616)
-- Name: nir_role_access_real_fk2; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY role_obj_type
    ADD CONSTRAINT nir_role_access_real_fk2 FOREIGN KEY (role_id) REFERENCES nir_role(r_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2509 (class 2606 OID 106637621)
-- Name: nir_role_r_parent_fkey; Type: FK CONSTRAINT; Schema: nir; Owner: -
--

ALTER TABLE ONLY nir_role
    ADD CONSTRAINT nir_role_r_parent_fkey FOREIGN KEY (r_parent) REFERENCES nir_role(r_id);


SET search_path = public, pg_catalog;

--
-- TOC entry 2528 (class 2606 OID 106637626)
-- Name: CASCADE_DELETE_UPADTE__valueDate; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "Nir_object_value_date"
    ADD CONSTRAINT "CASCADE_DELETE_UPADTE__valueDate" FOREIGN KEY (ovd_link_id) REFERENCES "Nir_links"(l_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2530 (class 2606 OID 106637631)
-- Name: CASCADE_DELETE_UPADTE__valueInt; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "Nir_object_value_int"
    ADD CONSTRAINT "CASCADE_DELETE_UPADTE__valueInt" FOREIGN KEY (obi_link_id) REFERENCES "Nir_links"(l_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2532 (class 2606 OID 106637636)
-- Name: CASCADE_DELETE_UPADTE__valueVarchar; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "Nir_object_value_varchar"
    ADD CONSTRAINT "CASCADE_DELETE_UPADTE__valueVarchar" FOREIGN KEY (ovv_link_id) REFERENCES "Nir_links"(l_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2525 (class 2606 OID 106637641)
-- Name: Nir_links_fk0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "Nir_links"
    ADD CONSTRAINT "Nir_links_fk0" FOREIGN KEY (l_id1) REFERENCES "Nir_object"(o_id);


--
-- TOC entry 2524 (class 2606 OID 106637646)
-- Name: Nir_links_fk1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "Nir_links"
    ADD CONSTRAINT "Nir_links_fk1" FOREIGN KEY (l_id2) REFERENCES "Nir_object"(o_id);


--
-- TOC entry 2523 (class 2606 OID 106637651)
-- Name: Nir_links_fk2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "Nir_links"
    ADD CONSTRAINT "Nir_links_fk2" FOREIGN KEY (l_id_link_type) REFERENCES "Nir_link_type"(lt_id);


--
-- TOC entry 2526 (class 2606 OID 106637656)
-- Name: Nir_object_fk0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "Nir_object"
    ADD CONSTRAINT "Nir_object_fk0" FOREIGN KEY (o_id_type) REFERENCES "Nir_object_type"(ot_id);


--
-- TOC entry 2527 (class 2606 OID 106637661)
-- Name: Nir_object_value_date_fk0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "Nir_object_value_date"
    ADD CONSTRAINT "Nir_object_value_date_fk0" FOREIGN KEY (ovd_link_id) REFERENCES "Nir_links"(l_id);


--
-- TOC entry 2529 (class 2606 OID 106637666)
-- Name: Nir_object_value_int_fk0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "Nir_object_value_int"
    ADD CONSTRAINT "Nir_object_value_int_fk0" FOREIGN KEY (obi_link_id) REFERENCES "Nir_links"(l_id);


--
-- TOC entry 2531 (class 2606 OID 106637671)
-- Name: Nir_object_value_varchar_fk0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "Nir_object_value_varchar"
    ADD CONSTRAINT "Nir_object_value_varchar_fk0" FOREIGN KEY (ovv_link_id) REFERENCES "Nir_links"(l_id);


--
-- TOC entry 2535 (class 2606 OID 106637676)
-- Name: Nir_role_action_fk0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "Nir_role_action"
    ADD CONSTRAINT "Nir_role_action_fk0" FOREIGN KEY (ra_role_id) REFERENCES "Nir_Role"(r_role_id);


--
-- TOC entry 2534 (class 2606 OID 106637681)
-- Name: Nir_role_action_fk1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "Nir_role_action"
    ADD CONSTRAINT "Nir_role_action_fk1" FOREIGN KEY (ra_action_id) REFERENCES "Nir_Action"(a_action_id);


--
-- TOC entry 2533 (class 2606 OID 106637686)
-- Name: Nir_role_action_fk2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "Nir_role_action"
    ADD CONSTRAINT "Nir_role_action_fk2" FOREIGN KEY (ra_object_id) REFERENCES "Nir_object"(o_id);


--
-- TOC entry 2537 (class 2606 OID 106637691)
-- Name: Nir_user_role_fk0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "Nir_user_role"
    ADD CONSTRAINT "Nir_user_role_fk0" FOREIGN KEY (ur_role_id) REFERENCES "Nir_Role"(r_role_id);


--
-- TOC entry 2536 (class 2606 OID 106637696)
-- Name: Nir_user_role_fk1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "Nir_user_role"
    ADD CONSTRAINT "Nir_user_role_fk1" FOREIGN KEY (ur_user_id) REFERENCES "Nir_User"("u_userId");


--
-- TOC entry 2522 (class 2606 OID 106637701)
-- Name: user_id_object; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY "Nir_User"
    ADD CONSTRAINT user_id_object FOREIGN KEY (u_id_object) REFERENCES "Nir_object"(o_id);


-- Completed on 2017-03-05 22:34:36 MSK

--
-- PostgreSQL database dump complete
--

