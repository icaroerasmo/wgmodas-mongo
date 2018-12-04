--
-- PostgreSQL database dump
--

-- Dumped from database version 9.5.14
-- Dumped by pg_dump version 9.5.14

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: DATABASE postgres; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON DATABASE postgres IS 'default administrative connection database';


--
-- Name: audit; Type: SCHEMA; Schema: -; Owner: postgres
--

DROP SCHEMA IF EXISTS audit CASCADE;

CREATE SCHEMA audit;

ALTER SCHEMA audit OWNER TO postgres;

--
-- Name: wgm; Type: SCHEMA; Schema: -; Owner: postgres
--

DROP SCHEMA IF EXISTS wgm CASCADE;

CREATE SCHEMA wgm;

ALTER SCHEMA wgm OWNER TO postgres;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: if_modified_func(); Type: FUNCTION; Schema: audit; Owner: postgres
--

CREATE FUNCTION audit.if_modified_func() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'audit'
    AS $$
DECLARE
    v_old_data TEXT;
    v_new_data TEXT;
BEGIN
    /*  If this actually for real auditing (where you need to log EVERY action),
        then you would need to use something like dblink or plperl that could log outside the transaction,
        regardless of whether the transaction committed or rolled back.
    */
 
    /* This dance with casting the NEW and OLD values to a ROW is not necessary in pg 9.0+ */
 
    IF (TG_OP = 'UPDATE') THEN
        v_old_data := ROW(OLD.*);
        v_new_data := ROW(NEW.*);
        INSERT INTO audit.logged_actions (schema_name,table_name,user_name,action,original_data,new_data,query) 
        VALUES (TG_TABLE_SCHEMA::TEXT,TG_TABLE_NAME::TEXT,session_user::TEXT,substring(TG_OP,1,1),v_old_data,v_new_data, current_query());
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        v_old_data := ROW(OLD.*);
        INSERT INTO audit.logged_actions (schema_name,table_name,user_name,action,original_data,query)
        VALUES (TG_TABLE_SCHEMA::TEXT,TG_TABLE_NAME::TEXT,session_user::TEXT,substring(TG_OP,1,1),v_old_data, current_query());
        RETURN OLD;
    ELSIF (TG_OP = 'INSERT') THEN
        v_new_data := ROW(NEW.*);
        INSERT INTO audit.logged_actions (schema_name,table_name,user_name,action,new_data,query)
        VALUES (TG_TABLE_SCHEMA::TEXT,TG_TABLE_NAME::TEXT,session_user::TEXT,substring(TG_OP,1,1),v_new_data, current_query());
        RETURN NEW;
    ELSE
        RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - Other action occurred: %, at %',TG_OP,now();
        RETURN NULL;
    END IF;
 
EXCEPTION
    WHEN data_exception THEN
        RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - UDF ERROR [DATA EXCEPTION] - SQLSTATE: %, SQLERRM: %',SQLSTATE,SQLERRM;
        RETURN NULL;
    WHEN unique_violation THEN
        RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - UDF ERROR [UNIQUE] - SQLSTATE: %, SQLERRM: %',SQLSTATE,SQLERRM;
        RETURN NULL;
    WHEN OTHERS THEN
        RAISE WARNING '[AUDIT.IF_MODIFIED_FUNC] - UDF ERROR [OTHER] - SQLSTATE: %, SQLERRM: %',SQLSTATE,SQLERRM;
        RETURN NULL;
END;
$$;


ALTER FUNCTION audit.if_modified_func() OWNER TO postgres;

--
-- Name: verify_cpf(text); Type: FUNCTION; Schema: wgm; Owner: postgres
--

CREATE FUNCTION wgm.verify_cpf(text) RETURNS boolean
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$
SELECT CASE WHEN LENGTH($1) = 11 THEN
(
  SELECT
      SUBSTR($1, 10, 1) = CAST(digit1 AS text) AND
      SUBSTR($1, 11, 1) = CAST(digit2 AS text)
  FROM
  (
    SELECT
        CASE res2
        WHEN 0 THEN 0
        WHEN 1 THEN 0
        ELSE 11 - res2
        END AS digit2,
        digit1
    FROM
    (
      SELECT
          MOD(SUM(m * CAST(SUBSTR($1, 12 - m, 1) AS INTEGER)) + digit1 * 2, 11) AS res2,
          digit1
      FROM
      generate_series(11, 3, -1) AS m,
      (
        SELECT
            CASE res1
            WHEN 0 THEN 0
            WHEN 1 THEN 0
            ELSE 11 - res1
            END AS digit1
        FROM
        (
          SELECT
              MOD(SUM(n * CAST(SUBSTR($1, 11 - n, 1) AS INTEGER)), 11) AS res1
          FROM generate_series(10, 2, -1) AS n
        ) AS sum1
      ) AS first_digit
      GROUP BY digit1
    ) AS sum2
  ) AS first_sec_digit
)
ELSE FALSE END;
 
$_$;


ALTER FUNCTION wgm.verify_cpf(text) OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: logged_actions; Type: TABLE; Schema: audit; Owner: postgres
--

CREATE TABLE audit.logged_actions (
    schema_name text NOT NULL,
    table_name text NOT NULL,
    user_name text,
    action_tstamp timestamp with time zone DEFAULT now() NOT NULL,
    action text NOT NULL,
    original_data text,
    new_data text,
    query text,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text])))
)
WITH (fillfactor='100');


ALTER TABLE audit.logged_actions OWNER TO postgres;

--
-- Name: cobranca_vendedora; Type: TABLE; Schema: wgm; Owner: postgres
--

CREATE TABLE wgm.cobranca_vendedora (
    id bigint NOT NULL,
    parcela integer NOT NULL,
    data_vencimento timestamp without time zone NOT NULL,
    pedido_id bigint NOT NULL,
    flag_pagamento boolean NOT NULL
);


ALTER TABLE wgm.cobranca_vendedora OWNER TO postgres;

--
-- Name: COBRANCA_VENDEDORA_ID_seq; Type: SEQUENCE; Schema: wgm; Owner: postgres
--

CREATE SEQUENCE wgm."COBRANCA_VENDEDORA_ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE wgm."COBRANCA_VENDEDORA_ID_seq" OWNER TO postgres;

--
-- Name: COBRANCA_VENDEDORA_ID_seq; Type: SEQUENCE OWNED BY; Schema: wgm; Owner: postgres
--

ALTER SEQUENCE wgm."COBRANCA_VENDEDORA_ID_seq" OWNED BY wgm.cobranca_vendedora.id;


--
-- Name: distribuidora; Type: TABLE; Schema: wgm; Owner: postgres
--

CREATE TABLE wgm.distribuidora (
    id bigint NOT NULL,
    usuario_id bigint NOT NULL,
    cnpj character varying(14),
    razao_social character varying(255),
    nome_fantasia character varying(255) NOT NULL,
    telefone character varying(11) NOT NULL,
    endereco character varying(255) NOT NULL
);


ALTER TABLE wgm.distribuidora OWNER TO postgres;

--
-- Name: DISTRIBUIDORA_ID_seq; Type: SEQUENCE; Schema: wgm; Owner: postgres
--

CREATE SEQUENCE wgm."DISTRIBUIDORA_ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE wgm."DISTRIBUIDORA_ID_seq" OWNER TO postgres;

--
-- Name: DISTRIBUIDORA_ID_seq; Type: SEQUENCE OWNED BY; Schema: wgm; Owner: postgres
--

ALTER SEQUENCE wgm."DISTRIBUIDORA_ID_seq" OWNED BY wgm.distribuidora.id;


--
-- Name: fabrica; Type: TABLE; Schema: wgm; Owner: postgres
--

CREATE TABLE wgm.fabrica (
    id bigint NOT NULL,
    nome character varying(255) NOT NULL,
    endereco character varying(255) NOT NULL,
    telefone character varying(20) NOT NULL
);


ALTER TABLE wgm.fabrica OWNER TO postgres;

--
-- Name: FABRICA_ID_seq; Type: SEQUENCE; Schema: wgm; Owner: postgres
--

CREATE SEQUENCE wgm."FABRICA_ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE wgm."FABRICA_ID_seq" OWNER TO postgres;

--
-- Name: FABRICA_ID_seq; Type: SEQUENCE OWNED BY; Schema: wgm; Owner: postgres
--

ALTER SEQUENCE wgm."FABRICA_ID_seq" OWNED BY wgm.fabrica.id;


--
-- Name: imagem; Type: TABLE; Schema: wgm; Owner: postgres
--

CREATE TABLE wgm.imagem (
    id bigint NOT NULL,
    produto_id bigint NOT NULL,
    img bytea NOT NULL
);


ALTER TABLE wgm.imagem OWNER TO postgres;

--
-- Name: IMAGEM_ID_seq; Type: SEQUENCE; Schema: wgm; Owner: postgres
--

CREATE SEQUENCE wgm."IMAGEM_ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE wgm."IMAGEM_ID_seq" OWNER TO postgres;

--
-- Name: IMAGEM_ID_seq; Type: SEQUENCE OWNED BY; Schema: wgm; Owner: postgres
--

ALTER SEQUENCE wgm."IMAGEM_ID_seq" OWNED BY wgm.imagem.id;


--
-- Name: produto; Type: TABLE; Schema: wgm; Owner: postgres
--

CREATE TABLE wgm.produto (
    id bigint NOT NULL,
    fabrica_id bigint NOT NULL,
    ref character varying(20) NOT NULL,
    descricao character varying(255) NOT NULL,
    largura real NOT NULL,
    altura real NOT NULL,
    profundidade real NOT NULL,
    cor character varying(10) NOT NULL,
    preco real NOT NULL,
    tamanho character varying(5),
    distribuidora_id bigint NOT NULL
);


ALTER TABLE wgm.produto OWNER TO postgres;

--
-- Name: PRODUTO_ID_seq; Type: SEQUENCE; Schema: wgm; Owner: postgres
--

CREATE SEQUENCE wgm."PRODUTO_ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE wgm."PRODUTO_ID_seq" OWNER TO postgres;

--
-- Name: PRODUTO_ID_seq; Type: SEQUENCE OWNED BY; Schema: wgm; Owner: postgres
--

ALTER SEQUENCE wgm."PRODUTO_ID_seq" OWNED BY wgm.produto.id;


--
-- Name: usuario; Type: TABLE; Schema: wgm; Owner: postgres
--

CREATE TABLE wgm.usuario (
    id bigint NOT NULL,
    email character varying(255) NOT NULL,
    senha character varying(255) NOT NULL
);


ALTER TABLE wgm.usuario OWNER TO postgres;

--
-- Name: USUARIO_ID_seq; Type: SEQUENCE; Schema: wgm; Owner: postgres
--

CREATE SEQUENCE wgm."USUARIO_ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE wgm."USUARIO_ID_seq" OWNER TO postgres;

--
-- Name: USUARIO_ID_seq; Type: SEQUENCE OWNED BY; Schema: wgm; Owner: postgres
--

ALTER SEQUENCE wgm."USUARIO_ID_seq" OWNED BY wgm.usuario.id;


--
-- Name: vendedora; Type: TABLE; Schema: wgm; Owner: postgres
--

CREATE TABLE wgm.vendedora (
    id bigint NOT NULL,
    usuario_id bigint NOT NULL,
    distribuidora_id bigint NOT NULL,
    nome character varying(255) NOT NULL,
    cpf character varying(11) NOT NULL,
    endereco character varying(255) NOT NULL,
    telefone character varying(11)
);


ALTER TABLE wgm.vendedora OWNER TO postgres;

--
-- Name: VENDEDORA_ID_seq; Type: SEQUENCE; Schema: wgm; Owner: postgres
--

CREATE SEQUENCE wgm."VENDEDORA_ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE wgm."VENDEDORA_ID_seq" OWNER TO postgres;

--
-- Name: VENDEDORA_ID_seq; Type: SEQUENCE OWNED BY; Schema: wgm; Owner: postgres
--

ALTER SEQUENCE wgm."VENDEDORA_ID_seq" OWNED BY wgm.vendedora.id;


--
-- Name: cliente; Type: TABLE; Schema: wgm; Owner: postgres
--

CREATE TABLE wgm.cliente (
    id bigint NOT NULL,
    telefone character varying(11) NOT NULL,
    endereco character varying(255) NOT NULL,
    cpf_cnpj character varying(255) NOT NULL,
    nome character varying(255) NOT NULL
);


ALTER TABLE wgm.cliente OWNER TO postgres;

--
-- Name: estoque_distribuidora; Type: TABLE; Schema: wgm; Owner: postgres
--

CREATE TABLE wgm.estoque_distribuidora (
    distribuidora_id bigint NOT NULL,
    produto_id bigint NOT NULL,
    quantidade integer NOT NULL
);


ALTER TABLE wgm.estoque_distribuidora OWNER TO postgres;

--
-- Name: estoque_vendedora; Type: TABLE; Schema: wgm; Owner: postgres
--

CREATE TABLE wgm.estoque_vendedora (
    produto_id bigint NOT NULL,
    vendedora_id bigint NOT NULL,
    quantidade integer NOT NULL
);


ALTER TABLE wgm.estoque_vendedora OWNER TO postgres;

--
-- Name: hibernate_sequence; Type: SEQUENCE; Schema: wgm; Owner: postgres
--

CREATE SEQUENCE wgm.hibernate_sequence
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE wgm.hibernate_sequence OWNER TO postgres;

--
-- Name: pedido; Type: TABLE; Schema: wgm; Owner: postgres
--

CREATE TABLE wgm.pedido (
    id bigint NOT NULL,
    vendedora_id bigint NOT NULL,
    produto_id bigint NOT NULL,
    cliente_id bigint NOT NULL,
    quantidade integer NOT NULL,
    desconto real NOT NULL,
    preco_venda real NOT NULL
);


ALTER TABLE wgm.pedido OWNER TO postgres;

--
-- Name: pedido_produto; Type: TABLE; Schema: wgm; Owner: postgres
--

CREATE TABLE wgm.pedido_produto (
    produto_id bigint NOT NULL,
    pedido_id bigint NOT NULL
);


ALTER TABLE wgm.pedido_produto OWNER TO postgres;

--
-- Name: view_qtd_pedidos_by_vendedora; Type: VIEW; Schema: wgm; Owner: postgres
--

CREATE VIEW wgm.view_qtd_pedidos_by_vendedora AS
 SELECT dis.id AS "ID_DISTRIBUIDORA",
    dis.cnpj AS "CNPJ_DISTRIBUIDORA",
    dis.nome_fantasia AS "NOME_FANTASIA_DISTRIBUIDORA",
    vend.id AS "ID_VENDEDORA",
    vend.cpf AS "CPF_VENDEDORA",
    vend.nome AS "NOME_VENDEDORA",
    count(ped.id) AS "QTD_PRODUTO"
   FROM ((((wgm.pedido ped
     JOIN wgm.vendedora vend ON ((vend.id = ped.vendedora_id)))
     JOIN wgm.produto prod ON ((prod.id = ped.produto_id)))
     JOIN wgm.cliente cli ON ((cli.id = ped.cliente_id)))
     JOIN wgm.distribuidora dis ON ((dis.id = vend.distribuidora_id)))
  GROUP BY dis.id, dis.cnpj, dis.nome_fantasia, vend.cpf, vend.nome, vend.id
  ORDER BY vend.nome;


ALTER TABLE wgm.view_qtd_pedidos_by_vendedora OWNER TO postgres;

--
-- Name: id; Type: DEFAULT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.cobranca_vendedora ALTER COLUMN id SET DEFAULT nextval('wgm."COBRANCA_VENDEDORA_ID_seq"'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.distribuidora ALTER COLUMN id SET DEFAULT nextval('wgm."DISTRIBUIDORA_ID_seq"'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.fabrica ALTER COLUMN id SET DEFAULT nextval('wgm."FABRICA_ID_seq"'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.imagem ALTER COLUMN id SET DEFAULT nextval('wgm."IMAGEM_ID_seq"'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.produto ALTER COLUMN id SET DEFAULT nextval('wgm."PRODUTO_ID_seq"'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.usuario ALTER COLUMN id SET DEFAULT nextval('wgm."USUARIO_ID_seq"'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.vendedora ALTER COLUMN id SET DEFAULT nextval('wgm."VENDEDORA_ID_seq"'::regclass);


--
-- Data for Name: logged_actions; Type: TABLE DATA; Schema: audit; Owner: postgres
--

COPY audit.logged_actions (schema_name, table_name, user_name, action_tstamp, action, original_data, new_data, query) FROM stdin;
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(1," incididunt ut labore",1,"on ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in repre",1)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(2," fugiat nulla pariatur. Excepteur sint o",2,"uis nostrud exercitation ullamco laboris nisi ut aliquip e",2)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(3,". Excepteur sint occaecat cupidatat non proident, sunt in culpa qui offi",3,"fugiat nulla p",3)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(4,"mod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis no",4,"liqua. Ut enim ad minim veniam, quis nostrud exerci",4)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(5,"it amet, consectetur adipiscing elit, sed ",5,"sectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore ",5)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(6,"aliquip ex ea commodo consequat. Duis aute irure ",6,"xercitation ullamco laboris nisi ut",6)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(7,"exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in",7,"e velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proide",7)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(8,"voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat ",8,"consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore ",8)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(9,"tate velit esse cillum dolore eu fugiat nulla pa",9,"ulpa qui offic",9)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(10,"sequat. Duis aute irure dolor in repreh",10," proident, sunt in culpa qui officia deser",10)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(11,"didunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco",11,", sunt i",11)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(12,"n reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla",12,"qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor s",12)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(13,"t occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit an",13,"u fugiat null",13)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(14,"it esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt",14,"u fugi",14)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(15,"iat nulla pariatur. Excepteur sint occaecat cupidatat non proident,",15,"teur sint occaecat cupidatat non proident, sunt in culpa qui officia ",15)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(16,"ud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor",16,"elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. ",16)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(17," amet, consectetur adipiscing elit, sed d",17,"esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaeca",17)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(18,"enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut a",18,"re magna aliqua. Ut enim ad minim veniam, qui",18)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(19,"t laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor i",19,"ore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat",19)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(20,". Ut enim ad minim v",20,"d do eiusmod tempor incididunt ut labore",20)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(21,"int occaecat cupidatat non proident, ",21,"iquip ex ea commodo consequat. Duis aute irure dolor in reprehenderi",21)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(22,"pariatur. Excepteur ",22,"or ",22)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(23,"modo consequat. Duis aute irure dolor in reprehenderit in vol",23," ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis",23)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(24,"ipiscing elit, sed do eius",24,"anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod",24)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(25,"olore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proi",25,"ariatur. Excepteur s",25)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(26," qui officia deserunt mollit anim ",26," nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit i",26)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(27,"psum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt",27,"lum dolore eu fug",27)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(28,"aboris nisi ut aliquip ex ea commodo c",28,"ccaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.Lore",28)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(29,"sunt in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet",29,"o consequat. Duis aute irure dolor in",29)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(30,"iscing elit, sed do eiusmod t",30," consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum do",30)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(31,"int occaecat cupidatat non proident, sunt in culpa qui offi",31,"nim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut a",31)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(32,"olore magna aliqua. Ut enim ad mini",32,"lit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut ",32)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(33,"ecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum",33,"didunt ut labore et dolore magna aliqua. Ut en",33)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(34,"uat. Duis aute irure dolor in rep",34,ommodo,34)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(35,"am, quis nostr",35,"ccaecat cupidatat non proident, su",35)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(36,"m veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commo",36,"sequat. Duis aute ",36)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(37,"ea commodo consequat. Duis aute ir",37," et dolore magna aliqua. Ut enim ad m",37)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(38,"re et dolore magna aliq",38,"ficia deserunt m",38)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(39,"dent, sunt in culpa qui officia deserunt mollit anim id es",39,"se cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proi",39)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(40,"m.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididu",40,"dolore eu fugiat nul",40)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(41," laboris nisi ut aliquip ex ea commodo conse",41,"ficia deserunt mollit a",41)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(42,"xercitation ullamco laboris nisi ut aliqu",42,"ip e",42)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(43,"m dolore eu fugiat nulla pariatur. Excepteur sint occaec",43,"piscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. U",43)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(44,", consectetu",44,"t mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do e",44)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(45,"qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing",45,"eserunt mollit anim id est laborum.Lorem ipsum dolor",45)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(46,"a commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore ",46,"t aliquip ex ea commodo consequat. ",46)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(47,"caecat cupidatat non proident, sunt in culpa q",47,"olore magna aliqua. Ut enim ad minim veniam, qui",47)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(48,"t dolore magna aliqua.",48,"m ad minim veniam, quis nostrud exercitation ullamco laboris ",48)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(49,"is nisi ut aliquip ex ea commodo consequat. ",49,"mco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehe",49)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(50,"nderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excep",50,"ia deserunt mollit anim id est laborum.Lorem ipsum dolor sit am",50)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(51,"itation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dol",51," qui officia deserunt mollit anim id est labor",51)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(52," velit esse cillum dolore eu fugiat nulla par",52,"a. Ut enim ",52)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(53,"oris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in repreh",53,"la pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culp",53)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(54,"prehenderit in voluptate velit esse cillum do",54," enim ad minim ve",54)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(55,"tion ullamco laboris nisi ut aliquip e",55,"lor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint",55)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(56,"lor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore m",56,"giat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui o",56)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(57,"ercitation ullamco laboris nisi ut aliquip ex ea com",57,"non proident, sunt ",57)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(58,"ut aliquip e",58," irure dolor in reprehenderit in voluptate velit esse ",58)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(59,"ipsum dolor sit am",59,"n proident, sunt in",59)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(60,"it amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut l",60,"e et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi",60)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(61,"ation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehen",61,"officia deserunt mollit anim id est laborum.Lorem ipsum",61)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(62,"lore magna aliqua. Ut enim ad minim veniam, quis nostrud e",62," Ut enim ",62)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(63,ua.,63,"t in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor",63)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(64," consequat. Duis aute irure dolor i",64,"t dolore",64)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(65,"te velit esse cillum dol",65,"re magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco",65)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(66,"eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad mi",66,"nt, sunt in culpa qui officia ",66)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(67,"i officia deserunt mollit anim id est laborum.Lo",67,"nt, sunt in culpa qui officia deserunt ",67)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(68,"dunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitat",68," minim veniam, quis nos",68)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(69,"dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proi",69,"cat cupidatat ",69)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(70,"se cillum dolore eu fugiat nulla pariatur. Excepteur s",70," amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolor",70)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(71,"eserunt mollit anim id est l",71,"dunt ut labore et dolore magna ",71)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(72,"tur. Excepteur sint occaecat cupidatat non proident, sunt in",72," commodo consequat. Duis aute",72)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(73,". Ut enim ad min",73,"si ut aliquip ex ea commodo consequat. Duis aute",73)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(74,"t esse cillum dolore eu fugiat nulla",74,"liqua. ",74)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(75,"enim ad minim veniam, qu",75," nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserun",75)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(115,"te irure dolor in reprehe",115,"aliqua. ",115)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(76,"exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute iru",76,"t mollit anim id ",76)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(77,"x ea commodo consequat. Duis aute irure dolor in reprehenderit",77,"consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua",77)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(78," in voluptate velit esse c",78,"ipsum dolor sit ",78)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(79,"or incidi",79,"pteur sint occaecat cupidatat non",79)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(80,"t. Duis aute irure dol",80,"te irure dolor in reprehenderit in voluptate velit ",80)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(81,"nderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Except",81,"laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed d",81)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(82,"ulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt",82,"odo consequat. Duis aute irure dolor in re",82)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(83,"x ea commodo consequa",83,"t, sunt in culpa qui officia deserunt mollit anim id est laborum.L",83)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(84,"rehenderit in voluptate velit esse cillum dolore eu fugiat",84," do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam,",84)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(85,.Lorem,85,am,85)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(86,"e cillum dolore eu fugiat nulla pariatur. Excepteur sin",86,nis,86)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(87,"t laborum.Lorem ipsum dolor sit am",87," dolore magna aliqua. Ut enim ad minim veniam",87)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(88,"niam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commod",88,ip,88)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(89,"ui ",89,"nderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur",89)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(90," nost",90,"dunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco l",90)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(91,"a commodo consequat. D",91,"uip ex ea commodo consequat. Duis aute ir",91)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(92,"ur sint occaecat cupidatat non proident, sun",92,"erunt mollit anim id est laborum.Lorem ips",92)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(93," adipiscing elit,",93,"t cupidatat non proident, sunt in culpa qui offici",93)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(94,"occaecat cupidatat non proide",94,"sum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididu",94)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(95,"tation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure",95,"atat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor",95)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(96,"tat non proident, sunt in culpa qui officia deserunt mollit anim id est lab",96,"at. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugi",96)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(97,"s nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo conseq",97,"s nisi ut aliquip ex ea commodo consequ",97)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(98,"pidatat non proident, sunt in culpa qui officia deserunt mollit anim",98,"proident, sunt in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsu",98)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(99,"ation ullamco labori",99,"iam, quis nost",99)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(100,"eiusmod tempor incididunt ut labor",100,"unt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco",100)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(101,"a. Ut enim ad minim veniam, quis nostrud exercitation ullamco",101,"lor sit amet, consectetur adipiscing elit, sed do eiusmod tempor in",101)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(102,"agna aliqua. Ut enim ad minim veniam, qu",102,"r. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt ",102)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(103,"nsectetur adipiscing elit,",103,"am, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute i",103)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(104,"magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip",104," non pro",104)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(105,"ent, sunt in culpa qui officia deserunt molli",105," ex ea commodo consequat. Duis a",105)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(106,"liqua. Ut enim ad minim veniam, quis n",106,"ipsum dolor sit amet, consectetur adipisci",106)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(107," ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse c",107,"m, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo c",107)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(108,"t mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmo",108,", consectetur adipiscing elit, sed do eiusmod ",108)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(109," ipsum dolor sit amet, consectetur adipi",109,"officia deserunt mollit anim id est lab",109)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(110,"pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia d",110,"icia deserunt mollit anim id est laborum.Lorem",110)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(111,or,111,"enderit in voluptate velit esse cillum dolore eu fugiat nul",111)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(112,"or inc",112," aliquip ex ea commodo c",112)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(113,"officia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectet",113,E,113)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(114,"m id est laborum.Lorem ipsum dolor sit amet, consectetur",114," do ei",114)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(116,"rud exercitation ullamco laboris nisi ut aliquip",116,"tate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint ",116)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(117,"g elit, sed do eiusmod tempor incididunt ut labore et dol",117,"um dolore eu fugiat",117)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(118,"st laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempo",118,"d exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis au",118)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(119,"sse cillum do",119,"icia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing e",119)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(120,"trud exercitation ullamco laboris nisi ut aliquip ex ea commodo",120,"consequat. Duis aute irure dolor in reprehender",120)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(121,"dipiscing elit, sed do eiusmod temp",121,"exercitation ullamco laboris nisi ut aliquip ex ea comm",121)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(122,"rcitation ullamco laboris nisi ut aliquip ex ea comm",122,"giat nulla pariatur. Excepteur sint occaecat cupidatat no",122)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(123,"la pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui offici",123,"im veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo",123)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(124,"t ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ull",124,"m, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo ",124)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(125," sunt in culpa qui officia deserunt mollit anim",125,"in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consec",125)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(126,"r sint occaecat cupidatat non proident, sunt in culpa qui officia ",126,"o eiusmod tempor incididunt ut labore et dolore magna ",126)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(127,"nt in culpa qu",127,"r in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pari",127)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(128,"m i",128,"onsequat. Duis aute ir",128)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(129," occaecat cupidatat non proident, sunt in culpa qui officia",129,"olor sit amet, consectetur adipiscing elit, sed do eius",129)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(130," quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequ",130,"sum dolor sit amet, c",130)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(131,"tetur adipiscing eli",131,"ugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui",131)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(132,"et dolore magna aliqua. U",132," ad minim veniam, quis nostrud exercitation ullamco lab",132)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(133,"luptate velit esse cillum dolore",133,"t aliquip ex ea com",133)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(134,"aliquip ex e",134,"ididunt ut labore et dolore magna aliqua. Ut ",134)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(135,"irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pari",135,"t nulla pariatur. Excepteur sint occaecat cupidatat non proident, ",135)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(136," enim ad minim veniam, quis nostrud",136,"t enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo co",136)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(137," in voluptate velit esse cillum dolore eu fugiat nulla pariatur.",137," ex",137)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(138,"nt, sunt in culpa qui officia deserunt mollit ",138,"esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proiden",138)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(139,"ectetur adipis",139,"ris nisi ut aliquip ex ea c",139)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(140," aliqua. Ut enim ad minim veniam, quis nostrud",140,"i ut aliquip ex ea commodo consequat. Dui",140)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(141,"pa qui officia deserunt mollit anim id est laborum.Lor",141,"mod tempor incididunt ut labore et dolore magna a",141)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(142,"mmodo con",142," veniam, quis nostrud exercitation ullamco laboris ni",142)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(143,"lor sit amet, c",143," veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Dui",143)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(144," fugiat nulla pariatur",144,"ris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate",144)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(145,", sunt in culpa qui o",145,"cing elit, sed do eiusmod tempor incididunt ut labore e",145)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(146," eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui offic",146,"borum.Lorem ip",146)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(147,"t nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia ",147," pariatur. Excepteur sin",147)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(148,"tation ullamco laboris nisi ut aliquip ex ea commodo ",148,"ua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea ",148)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(149,"ficia deserunt mo",149,"in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum do",149)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(150,"onsectetur adipiscing elit, sed do eiusmod tempor incididunt ut",150,"reprehenderit in voluptate velit esse cillum dolore eu ",150)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(151,"lit esse cillum dolore eu fugiat nulla pariatur. Ex",151,"m, quis nostrud exercitation ullamco laboris nisi ",151)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(152,". Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris n",152,st,152)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(153," in culpa qui officia deserunt molli",153,"boris nisi ut aliqui",153)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(154,"equat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu f",154," proident, sunt in culpa qui officia deserunt mollit anim id es",154)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(155,"rum.Lorem ipsum dolor sit amet, consectetur adipiscing elit",155,"et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ",155)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(156,"ore magna aliqua. U",156,"ris nisi u",156)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(157,"d est laborum.Lorem ipsum",157,"Ut e",157)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(158,"t in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occa",158,"ute irure dolor in reprehenderit in voluptate velit e",158)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(159,"boris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehen",159,"ur sint occaecat cupidatat non pro",159)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(160," dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididu",160,"cia deserunt mo",160)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(161," commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit es",161,"giat nulla",161)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(162,"olore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non ",162,"pariatur. Excepteur sint occaecat cupidatat non proident, su",162)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(163,"r. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt ",163,"s ",163)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(164," nulla pariatur. Excepteur sint occaecat cupidatat non proide",164,"nim id est laborum.Lorem ips",164)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(165,"inim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo",165,"sequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cill",165)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(166," aliqua. Ut enim ad mi",166," o",166)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(167,"ariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserun",167,"ulpa qui officia deserunt mollit anim id est labo",167)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(226," laboris nisi ut aliquip ex ea co",226,"ad minim veniam, q",226)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(168,"eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat no",168,"n reprehenderit in",168)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(169,"aborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eius",169,"in culpa qui officia deserunt mollit anim id e",169)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(170,"at cupidatat non proident, sunt in culpa qui officia des",170,"Duis aute irure dolor in repreh",170)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(171,"oident,",171,"oluptate velit esse cillum dolore eu fugiat nulla pariat",171)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(172," deserunt mollit anim id est labor",172,"piscing elit, s",172)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(173,"epteur sint occaec",173,"enderit in voluptate velit ess",173)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(174,"e cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt ",174,"e dolor in reprehenderit in voluptate velit esse",174)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(175,"ua. Ut enim ad min",175," dolo",175)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(176,"ncididunt ut labore et dolore magna aliqua. Ut enim ad minim ve",176,"re dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariat",176)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(177,"s aute irure dolor in reprehenderit in voluptate velit es",177," sed do eiusmod tempor incididun",177)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(178,"ididunt ut labore et dolore magna aliqua. Ut enim",178,"e cillum dolore",178)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(179,"nisi ut aliquip ex ea commodo consequat. Duis ",179,"id est laborum.Lorem ipsum dolor sit amet",179)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(180,"ia deserunt mollit anim id est ",180,"tion ullamco laboris nisi ut aliquip ex ea commodo con",180)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(181,"ullamco laboris nisi ut aliquip ex",181,odo,181)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(182,"m ad minim veniam, quis nostrud exercitation",182,"rcitation ullamco laboris nisi ut aliquip e",182)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(183,"um.Lorem ipsum dolor sit amet, consectetur adipiscing elit,",183,m,183)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(184,"unt in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum d",184,"consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum",184)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(185,"dunt ut labore et dolore magna aliqua. Ut enim ad minim ve",185,"s aute ir",185)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(186,"eprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur",186,"sum dolor sit amet, consectetur adipiscing eli",186)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(187,"nt occaecat cupidatat no",187,"llit anim id es",187)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(188,"elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim",188,"fficia deserunt mollit anim id ",188)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(189,"ng elit, sed d",189,"sequat. Duis aute irure dolor in reprehenderit in voluptate velit ess",189)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(190,"is aute irure dolor in reprehenderit in voluptate velit esse ci",190,"is nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute i",190)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(230,"ur adipiscing elit, sed do eiusmod tempor incididunt ut labore et do",230,"ficia deserunt mollit anim id es",230)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(191," consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore ",191,"deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed",191)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(192,"ectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolor",192,"in reprehenderit in vol",192)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(193,unt,193,"cing elit, sed do",193)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(194,"commodo consequat. Duis aute irure dolor in reprehenderit in voluptate veli",194,"co laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dol",194)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(195,"consectetur adipiscing e",195,"luptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat n",195)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(196,"it in voluptate velit esse cillum dolore eu fugiat nulla pariatu",196,"ipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore ",196)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(197,"et dolore magna aliqua. Ut enim ad minim venia",197,"d t",197)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(198," dolor sit amet, consectetur adipiscing elit, sed do eiusm",198,". Ut enim ad minim ",198)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(199,"ollit anim id",199,"n proident, sunt in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum dol",199)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(200,"ullamco laboris nisi ut al",200,"sectetur adipiscing elit, sed do eiusmod tempor incididunt ut labo",200)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(201,"n proident, sunt in culpa qui offici",201,"e irure dolor in reprehenderit in voluptate v",201)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(202,"st laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod t",202,"atur. Excepteur ",202)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(203,"t aliquip ex ea commodo consequat. Duis ",203,"incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercit",203)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(204,"oris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehende",204,"t cupidatat non proident, sunt in culpa ",204)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(205,"nim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo conse",205,"o laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in repreh",205)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(206,"iusmod tempor incididunt ut labore et dolore",206,"rem ipsum dolor sit amet, consectetur ad",206)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(207," sit amet, consec",207," eu fugiat nulla pariatur. Excepteur",207)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(208,"t. Duis aute irure dolor in reprehenderit in voluptate velit esse c",208," incidi",208)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(209,"ariatur. Excepteur sin",209,"sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut la",209)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(210,"agna aliqua. Ut enim ad minim veniam, quis nostrud exer",210,"xercitation ullamco laboris nisi ut aliquip ex ea commodo conseq",210)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(211,"t amet, consectetur ",211,"et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitati",211)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(212,"empor incididunt ut labore et dolore ",212,"liqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut ",212)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(213,"non proident, sunt in culpa qui officia deserunt mollit anim id ",213,"e dolor in reprehenderit in voluptate velit esse cillum do",213)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(214,"e irure dolor in reprehenderit in voluptate velit e",214,"iusmod tempor incididunt ut labore et dolore magna aliqua. Ut en",214)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(215,"r sit amet, consectetur adipiscing elit, sed do eiusmod t",215,"a deserunt mollit anim",215)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(216,"caecat cupidatat non proident, su",216,"ui officia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipi",216)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(217,"co laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in",217," nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate veli",217)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(218,"ariatur. Excepteur sint o",218,"eiusmod tempor incididunt",218)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(219,"modo con",219,"in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sin",219)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(220,"non proident, sunt in culpa qui officia deserunt mollit anim id",220,"magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco labori",220)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(221,"mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipisc",221,"is no",221)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(222," officia deserunt mollit anim id est laboru",222," elit, sed do eiusmod tempor incididu",222)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(223,"et, consectetur adipiscing elit, s",223,"lore eu fugiat nulla pariatur",223)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(224,"rcitation ullamco laboris",224,"ptate velit esse cill",224)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(225,"on ullamco laboris nisi ut aliquip ",225,"n proident, sunt in culpa qu",225)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(227," eu fugiat nulla pariatur. Excepteur sint",227,"id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor",227)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(228,ostr,228,"e cillum dolore eu fugiat nulla pariatu",228)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(229,"cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupi",229,"adipiscing elit, sed do ei",229)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(231,"tate velit esse cillum dolore eu fu",231,"ostrud exe",231)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(232,"dent, sunt in culpa qui officia deserunt mollit anim ",232,"lore magna aliqua. Ut enim ad minim veniam, quis nostrud",232)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(233,"in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaeca",233,"ptate velit esse cillum ",233)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(234,"ulla pariatur. Excepteur sint occaecat cupidatat non proid",234,"eu fugiat nulla pariatur. Excepteur sint occaecat ",234)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(235,"tat non proident, sunt i",235,"Ut enim ad",235)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(236,"t dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris",236,"Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt molli",236)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(237," nisi ut aliquip ex ",237,"mollit ",237)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(238,"ficia deserunt mollit anim id est laborum.Lorem ips",238,"psum dolor sit amet, cons",238)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(239," sunt in cu",239,t,239)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(240,"ute irure dolor in r",240,"um.Lorem ipsum dolor sit amet, consectetur adipisc",240)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(241,"amco laboris nisi ut aliquip",241,"r sint occaecat c",241)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(242," sunt in culpa qui officia deserunt mollit anim id est labo",242,"didunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercit",242)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(243," reprehenderit in voluptate velit esse cillu",243,"t dolore magna aliqua. Ut enim ad minim ",243)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(244,"elit esse cillum dolore eu fugiat nulla pariatur. Excep",244,"do consequat. Duis aute irure dolor in r",244)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(245,"mco laboris nisi ut aliquip ex ea commodo consequat. Duis a",245," consequat. Duis aute irure dolor in reprehenderit",245)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(246,"ing elit, sed do eiusmod tempor incididunt u",246,"is nostrud exercitation ullamco laboris nisi ut aliquip ex",246)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(247,"ehenderit in voluptate velit esse cillum dolore eu fugiat nul",247,", consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore",247)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(248,". Ut enim ad minim ve",248,"Excepteur sint occaecat cupidatat non proid",248)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(249," eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim a",249,"olore magna aliqua. Ut enim ad minim veniam, quis nostrud ",249)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(250,"or incididunt ut labore et dolore ma",250,"it amet, consectetur adipisci",250)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(251,"t in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat c",251,"quat. Duis aute",251)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(252,"iusmod tempor incididunt ut labor",252,"datat ",252)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(253,"por incididunt ut labore et dolor",253," ea commodo consequat. Duis aute irure dolor in reprehenderit",253)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(254,"p ex ea commodo consequat. Duis ",254,"on proident, sunt in culpa qui officia deserunt mollit",254)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(255," dolore magna aliqua. Ut enim ad minim veniam, quis n",255,"orum.Lorem ipsum dolor sit amet, consectetu",255)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(256,"st laborum.Lorem ipsu",256,"m, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo",256)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(257,"ulpa qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, co",257,"ipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ",257)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(258,"tur. Excepteur sint occaecat cupidatat non pro",258,"oluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepte",258)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(259,"r sit amet, consectetur adipiscing elit, ",259,"esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non",259)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(260,"lore magna aliqua. Ut enim ad minim veniam, quis nos",260,"tur adipiscing e",260)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(261,"e eu fugiat nulla pariatur. Exce",261,"ccaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit ani",261)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(262,"t enim ad minim veniam, quis nostrud exercit",262,"ng elit, sed do eiusmod tempor incididunt ut labore et",262)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(263,"a. Ut",263,"iatur. Excepteur sint occaeca",263)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(264,"mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmo",264,"est ",264)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(265,"t ut labore et dolore magna aliqua. Ut enim ad minim veniam, ",265,"m, quis nostrud exerci",265)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(266,"olor in reprehenderit in voluptate velit esse cillum dolore eu",266,"amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magn",266)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(267,"ipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna a",267,"rit in voluptate velit esse cillum dolore eu fugiat ",267)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(268,"voluptate velit esse cillum dolore eu fugiat nulla pariatur. ",268,qu,268)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(269,"gna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ulla",269,"psum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor in",269)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(270,"a. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut al",270,"itation ullamco laboris nisi ut aliquip ex ea commodo consequa",270)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(271,"trud exercitatio",271,"cididunt ut labore et dolore magna aliqua. Ut en",271)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(272,"rem ipsum",272,"e magna aliqua. Ut enim ad minim veniam, quis nostrud ex",272)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(273,"rit in voluptate velit esse cillum dolore eu fugiat nulla pa",273," consequat. Duis aute irure d",273)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(274,"do eiusmod tempor in",274,"ed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad ",274)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(275," sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore mag",275,"rum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed d",275)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(276,"rit in voluptate veli",276,"aecat cupidatat non p",276)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(277," magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco l",277,ercitati,277)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(278," in rep",278,"eur sint occaecat cupidatat n",278)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(279," Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex e",279,"trud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irur",279)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(280,"mco laboris nisi ut aliquip ex ea commodo consequat. Duis aut",280,"t, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et",280)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(281,"uis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore",281,"ptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaec",281)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(282,"erit in voluptate",282,"dunt ut labore et dolore m",282)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(283,", quis nostrud exercitation ullamco laboris nisi u",283,"la pariatur. Excepteur sint occaecat cupidatat non proident,",283)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(341,"t aliquip ex ea commodo consequat. Duis aute irure dolor in reprehender",341,"equat. Duis aute irure dolor ",341)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(284,"in culpa qui officia deserunt mollit anim id est la",284,", sunt in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consect",284)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(285,"it amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut",285,"se cillum dolore ",285)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(286,"t aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in",286,", sunt in culpa qui officia deserunt mollit",286)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(287,"officia ",287,ul,287)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(288,"officia deserunt mollit an",288,"ididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exerc",288)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(289,"mco laboris nisi ",289,"esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in",289)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(290,"upidatat non proident, sunt in culpa qui officia deserunt mollit ",290,"s nisi ut aliquip ex ea commodo consequat. Duis aute",290)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(291,"abore et dolore magna aliqua",291,"adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad mini",291)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(292," ut labore et dolore magna aliqua. U",292,"nderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupid",292)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(293,"rum.Lorem ipsum dolor sit amet, consectetur adipiscin",293,"t anim id est laborum.Lorem ipsum dolor sit amet, consectetur a",293)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(294,"ugiat nulla pariat",294," tempor incididunt ut lab",294)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(295," commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse ci",295,"at non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum",295)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(296,"non proident, sunt in culpa qui officia deserunt mollit anim id est l",296,"fficia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit,",296)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(297,"te velit ",297," consectetur adipiscing elit, sed do eiusmod tempor ",297)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(298,"ectetur adipiscing elit, sed do eiusmod tempo",298,"sequat. Duis aute irure dolor in reprehenderit in voluptate vel",298)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(299,"inim veniam, quis nostrud exercitation ullamco laboris nisi ut al",299,"iam, quis n",299)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(300," in culpa qui officia deserunt mollit ani",300,"e cill",300)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(301,"re magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip",301,"id est lab",301)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(302,"luptate velit esse cillum ",302,"rcitation ullamco laboris nisi ut aliquip ex ea ",302)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(303,"laboris nisi ut aliquip ex ea commodo consequat. Duis au",303,"atat non proident, sunt in culpa qui officia deserunt mollit",303)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(304,"nim id est lab",304,"ididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostr",304)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(305,"ctetur adipiscing elit, sed do eiusmod tempor in",305,"t dolore magna aliqua. Ut enim ad",305)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(644,"ui offici",644,"o eiusmod tempor i",644)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(306,ulla,306," pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mo",306)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(307,"a aliqua. Ut enim ad minim veniam, quis nostrud exercitation ul",307,"uis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo con",307)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(308,"Ut enim ad minim veniam, quis nostrud exercitation ullamco labo",308,"nulla pariatur. Exce",308)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(309,"quis nostrud exercitation ullamco laboris nisi u",309,"s nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in",309)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(310,dipiscing,310,"at. Duis aute irure dolor in rep",310)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(311,"re eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt",311," magna aliqua. Ut enim ad minim ve",311)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(312,"erunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit,",312,"magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliqu",312)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(313,"ion ullamc",313,"illum dolore eu fugiat nulla paria",313)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(314,"iscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut en",314," tempor incididunt ut labore et dolore magna aliqua. Ut ",314)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(315,"elit, sed do eiusmod tempor",315,"t in volup",315)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(316,"t laborum.Lorem i",316,"aute irure dolor in reprehenderit in voluptate velit esse cillum do",316)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(317,"derit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.",317,"ion ullamco laboris nisi ut aliquip ",317)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(318,"tempor incididunt ut labore et dolore ",318,"piscing elit, sed do eiusmod tempor incididunt ut labore et dolore ma",318)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(319,"amco ",319,"proident, sunt in culpa qui officia deserun",319)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(320,"henderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occ",320,"teur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id es",320)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(321,"olore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in ",321,"ion ullamco laboris nisi ut aliqu",321)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(322,"citation ullamco laboris nisi ut a",322,"o consequat. Duis aute irure dolor in reprehenderit in vo",322)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(323," voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaec",323,"cillum dolore eu fugiat nulla pari",323)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(324,"dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor i",324,"unt mollit anim id est laborum.",324)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(325,"e irure dolor ",325," v",325)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(326,"at. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum d",326,"st labor",326)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(327,"n culpa qui officia deserunt mollit anim ",327," occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est l",327)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(328,"irure dolor in reprehenderit in voluptate velit esse cillum dolor",328,labor,328)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(329,"dipiscing elit",329,"erit in voluptate velit esse cillum dolore eu fugiat null",329)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(330," pari",330,"riatur. Excepteur sint occaecat cupidatat non proident, sunt in cul",330)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(331,"sum dolor sit amet, consectetur adipiscing",331,"piscing elit, sed do eiu",331)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(332,"atat non proident, sunt in culpa qui officia deserunt mollit anim ",332,"sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt m",332)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(333,"d tempor incididunt ut labor",333,"eserunt mollit anim id est laboru",333)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(334,"re eu fugiat nulla paria",334,"o laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure ",334)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(335,"rum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, se",335,"t occa",335)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(336,"a pariatur. Excepteur sint occa",336," consectetur adipiscing elit, sed do eiusmod tempor incididunt u",336)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(337,"dipiscing elit, sed do eiusmod tempor incididunt ut l",337,"iqua. Ut enim ad minim veniam, quis nost",337)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(338,"deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing el",338,"t esse cillum dolore eu ",338)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(339,"nim ad minim veniam, quis",339,"n proident, sunt in culpa qui officia deserunt ",339)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(340,"sum d",340,"iam, quis nostrud exercitation ullamco laboris nisi ut",340)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(342," velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint o",342,"consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore",342)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(343,"dent, sunt in culpa",343,"ulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui offic",343)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(344,"co laboris nisi ut aliquip ex ea commodo consequat. Duis aute iru",344,"olore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat",344)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(419,"ostrud exercitati",419,"iam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",419)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(345,"iusmod tempor incididunt ut labore et ",345,"proident, sunt in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor si",345)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(346,"gna aliqua. Ut enim ad minim veniam, quis nostrud exercita",346,"onsequat. Duis aute irure dolor in reprehender",346)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(347,"orem ipsum dolor",347," esse cillum dolore eu fugiat nulla pariatur. Excepteur si",347)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(348,"dipiscing elit, sed do eiusmod tempor i",348,"scing elit, sed do eiu",348)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(349," cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est ",349,"in culpa qui officia deserunt mollit anim id est laborum.Lo",349)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(350,iu,350,"icia deserunt mollit anim id est laborum.Lorem ipsum dolor sit a",350)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(351,"nt occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est ",351,"Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia ",351)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(352,"cididunt ut labore et dolore magna aliqua. Ut enim a",352,"id est laborum.Lorem ipsum dolor sit am",352)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(353," incididunt ut labore et dol",353,"mco laboris ni",353)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(354,"qua. Ut e",354," laboris nisi u",354)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(355," consectetur adipiscing elit, sed do eiu",355,"erunt mollit anim id est l",355)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(356,"i ut aliquip ex ea co",356,"is nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehe",356)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(357," labore et dolore magna aliqua. Ut enim ad minim veniam, ",357,", quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irur",357)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(358,"rud exercitation ullam",358,"dipiscing elit, sed do eiusmod tempor incididunt ut labore e",358)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(359,"n ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit i",359,"ostrud exercitation ullamco laboris nisi ut a",359)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(360,"xcepteur sint occaecat cupidatat ",360,a,360)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(361,". Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt moll",361,"tur adipiscing elit, sed do eiusmod te",361)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(362,"est laborum.Lorem i",362,"ectetur adipiscing elit, se",362)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(363,"ng elit, sed do eiusmod te",363,"xcepteur sint occaecat cupidatat no",363)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(364,"ing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqu",364," labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco labor",364)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(365,"Ut enim ad minim venia",365,"luptate velit esse c",365)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(366,"t. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore",366,"runt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing eli",366)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(367,"cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est labo",367,"t ut labore et",367)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(368,"im id est laborum.Lorem ipsum dolor",368,"quat. Duis aute ir",368)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(369,"iscing elit, sed do eiusmod tempor incididunt ut labore et d",369,"t mollit anim id est laborum.Lo",369)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(370,"llit anim id est laborum.Lorem ipsu",370,"eprehenderit in voluptate velit esse cillum dolore eu fu",370)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(371,"iscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut eni",371,"atur. Excepteur sint occaecat cupidatat non proident, sunt in ",371)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(372," elit, sed do eiusmod tempor incidi",372," sint occaecat cupidatat n",372)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(373," ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore",373,"iatur. Excepteur sint occaecat cupidatat n",373)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(374,"tate velit esse cillum dolore ",374,"ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris",374)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(375,"ut labore et dolore mag",375,bor,375)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(376,"it, s",376,"aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fug",376)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(377,"ncididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis n",377,"dent, sunt in culpa qui officia deserunt mollit anim id est labo",377)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(378,"iam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute ",378,"t in culpa qui o",378)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(379,"lpa qui officia deserunt mollit anim id est ",379,"llit anim id est laborum.Lorem ipsu",379)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(380,"ng elit, sed do eiusmod tempor incididunt ut labore et dol",380,"at ",380)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(381,"tur adipiscing elit, sed do ei",381,"sse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non ",381)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(382,"d exercitation ul",382,"lit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad m",382)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(383," minim",383,"id est laborum.Lorem ipsum dolor sit amet, consectetur adi",383)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(384,"didunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitati",384,"se cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt",384)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(385," enim ad minim veniam, quis nostrud e",385,"dolor in reprehenderit in voluptate",385)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(386,"t occaecat cupi",386,hender,386)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(387,"llamco laboris nisi ut aliquip ex ea ",387,"et dolore magna aliqua. Ut enim ad minim veniam, quis nostru",387)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(388,"g elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut eni",388,"iatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserun",388)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(389,"boris nisi ut aliquip ex ea commo",389,"uat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillu",389)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(390,"por incididunt ut labore e",390,"t in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidat",390)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(391,"eserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur ad",391," voluptate velit esse cillum dolore eu fugiat nulla",391)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(392,"giat nulla pariatur. Excepteur sint occaecat cupidatat no",392,"ptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur s",392)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(393," aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugi",393,"mmodo consequat. Duis aute irure dolor in r",393)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(394,"derit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat",394,"n reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Exce",394)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(395," quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute",395,"laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor ",395)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(396,"m ipsum dolor sit amet, consec",396,"ecat cupidatat n",396)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(776,"e cillum dolore eu fugiat nulla pariat",776,"est labor",776)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(397,"dipiscing elit, sed do eiusmod tempor incididunt ut la",397,"la pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa",397)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(398,"ute irure dolor in reprehenderit in volu",398," deserunt mollit anim id est labor",398)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(399," volupt",399,"ation ullamco laboris nisi ut aliquip e",399)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(400,"unt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed d",400,"roident, sunt in culpa qui officia dese",400)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(401,"in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint o",401,"teur sint occa",401)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(402,"bore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco labor",402,"t anim id est lab",402)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(403,"ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incid",403,"liqua. Ut enim ad m",403)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(404,"d exercitation ullamco lab",404,"empor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exerc",404)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(405," aliqua. Ut enim ad minim venia",405,"xcepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deseru",405)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(406,"enim ad minim veniam, quis nostrud exercitation ullamco la",406,"labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ull",406)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(407,"dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi u",407,"amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et ",407)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(408,"iscing elit, sed do eiusm",408,"sectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magn",408)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(409,c,409,"te velit esse cillum dolore eu fugiat nulla pariatur. Excepteur si",409)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(410,"ris nisi",410,"tur adipiscing ",410)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(411,"is aute irure dolor in reprehenderi",411,"serunt mol",411)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(412," amet, consectet",412,"ing elit, sed do eiusmod tempor",412)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(413," irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pa",413,"t, sunt in culpa qui officia deserunt mollit anim id est lab",413)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(414,"esse cillum dolore eu fug",414,"ostrud exercitation ullamco labo",414)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(415,"minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo",415,"on ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in rep",415)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(416,"r in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur si",416," elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam",416)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(417,".Lorem i",417,"ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in repre",417)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(418," amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolo",418,"ipiscing elit, sed do eiusmod tem",418)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(420," in vo",420," do eiusmod tempor incididunt ut labore et dolo",420)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(421,"elit, sed do eiusmod tempor incididunt ut labore et dolore ",421,"um dolore eu fugiat nulla pariatur. Excepteur sint occaeca",421)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(422,"sint occaecat",422,"unt mollit anim id est laborum.Lorem ipsum dolor sit a",422)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(423,"ur. Ex",423,"sunt i",423)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(424,"giat null",424,ectetu,424)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(425,"ut labore et dolore magna aliqua.",425,"trud exercitation ullamco laboris nisi ut aliquip ex ea commodo",425)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(426,"usmod tempor incididunt ",426,"ptate ",426)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(427," magna aliqua. Ut enim ad minim veniam, quis nostrud",427,"od tempor incididunt ut l",427)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(428,"m, quis nostrud exercit",428,"teur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id es",428)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(429,"i officia deserunt mollit anim id est laborum.Lorem ipsum",429,"cat cupidatat non proident, sunt in culpa qui officia de",429)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(430,"ud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Du",430,"o eiusmod temp",430)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(431,data,431,"olore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proi",431)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(432," in voluptate velit esse cillum do",432,"r inci",432)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(433,"la pariatur. Excepteur si",433,"equat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugia",433)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(434," ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis au",434,"am, quis nostrud exercitation u",434)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(435,"in reprehenderit in volup",435,"ulpa qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur",435)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(436,"unt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ",436,"etur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dol",436)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(437,". Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deser",437,"citation ullamco laboris nisi ut aliquip ex ",437)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(438," qui officia deserunt mollit anim id est",438,"ollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipisci",438)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(439,"uis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure do",439,"i ut aliquip ex ea commodo consequat. Duis aute irure dolor i",439)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(440,"t ut labore et dolore magna aliqua. Ut eni",440," esse cillum dolore eu fugiat nulla pariatur. Excepteu",440)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(441,"lore magna aliqua. Ut enim ad mi",441,"piscing elit, sed do eiusmod tempor incididunt ut labore et dolore ma",441)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(442,"a aliqua. Ut enim ad minim veniam, quis nostrud exercitation",442,"Ut enim ad minim veniam, quis nostrud exercitation ullamco ",442)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(443,"aboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor",443," mollit",443)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(444,"e velit esse cillum dolore eu fugiat nulla pariatur. Except",444,"it esse cillum dolore eu fugiat nulla pariatur. Excep",444)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(445,"or incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, qu",445,"onsequat. Duis aute ir",445)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(446,"unt in culpa qui officia deserunt molli",446," aliq",446)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(447,"giat nulla pariatur. Excepteur sint occa",447,"enderit in voluptate velit esse cillum dolore eu fug",447)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(448," et dolore m",448,"te velit esse cillum dolore eu fugiat nulla pariatur. Exce",448)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(449,"rud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure d",449,"tat non pro",449)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(450,"pariatur. Excep",450,"giat nulla pariatur. Excepteur sint occaecat cupid",450)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(451,"t. Duis aute irure dolor in reprehenderit in volupt",451,"u fugiat nul",451)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(452,"teur sint occaecat cupidatat non proident, sunt",452,"qui officia deserunt mollit anim id est laborum.Lore",452)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(453,"ia deseru",453,"elit esse cillum dolore eu fugiat n",453)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(454," in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur",454,"in culpa",454)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(778," ut aliquip ex e",778,"t in cul",778)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(455,"cing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ",455,"teur sint occaecat cupidatat non proident, sunt in culp",455)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(456,"do eiu",456,"tur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna al",456)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(457,"icia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, co",457,"o consequat. Duis aute irure dolor in reprehend",457)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(458,". Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi",458,"laborum.Lorem ipsum dolor sit amet, consectetur adi",458)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(459,proide,459,"im id est laborum.Lorem ipsum dolor sit amet, co",459)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(460," commodo consequat. Duis aute irure dolor in rep",460,"aliquip ex ea commodo consequat. Duis aute irure dolor in rep",460)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(461,"t enim ad minim veniam, quis nostrud",461,"t in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint o",461)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(462,"e et dolore magna aliqua. Ut enim ad minim veniam, quis n",462," exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. ",462)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(463,"is nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehe",463," ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo ",463)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(464,"cat cupidatat non proident, sunt in culpa qu",464,"tur. Excepteur sint occaecat cupidatat non proident, sun",464)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(465," eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, q",465,"am, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo conseq",465)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(466,"atat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor s",466,"tur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qu",466)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(467,"aecat cupidatat non proident, sunt in culpa qui officia deserunt mol",467,"m dolore eu fugiat nulla pariatur. Excepteur sint occaeca",467)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(468,"amco la",468,"iquip ex ea commodo consequat. Duis ",468)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(469,"ur sint ",469,"erunt mollit anim id ",469)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(470,"t. Duis aute irure dolor in reprehenderit in volupta",470,"dunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis",470)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(471," dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nu",471,"nt in culpa qui officia deserunt mollit ani",471)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(472," ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore",472,"piscing elit, sed do eiusmod tempor incididunt ut labore et dolore ",472)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(473,"ncididunt ut labore et dolore magna aliqua. Ut enim ad minim",473,"quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea co",473)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(474,"nulla pariatur. Ex",474,"sit amet, consectetur adipis",474)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(475,"dolor in reprehend",475," non proident, sunt in culpa qui offi",475)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(476,"iscing elit, sed do eiusmod tempor incididunt ",476,"e magna aliqua. Ut enim ad ",476)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(477,"tation ullamco la",477,"onsectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. ",477)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(478,"e magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliqu",478,"nt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exe",478)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(479,"luptate v",479,"unt in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum",479)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(480,"itation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis ",480,"xcepteur sint occaecat cupida",480)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(481,"pidatat non proident, sunt in culpa qui ",481,mod,481)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(482,"lamco laboris nisi ut aliquip ex ea commodo consequat. Duis",482,"pariatur. Excepteur sint occaecat cupidatat non proident, ",482)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(483," do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim a",483,"eniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. D",483)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(484,"ommodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit ess",484,"ulpa qui officia deserunt mollit anim id est",484)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(485,"Ut enim ad minim veniam, quis nostrud exercit",485," voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint oc",485)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(486,"qua. Ut enim ad minim veniam, quis nostru",486,"derit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excep",486)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(487,"ur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit",487,"qua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea ",487)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(488,"id est laborum.Lorem ipsum dolor sit am",488,"on proident, sunt in culpa qui officia de",488)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(489,"d exercitation ullamco laboris ni",489,"nt occaecat cupidatat non proident, sunt in culpa qui officia deserunt mol",489)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(490,"anim id est laborum.Lorem ipsum dolor sit amet, consecte",490,"t aliquip ex ea com",490)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(491,"ur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",491,"a deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, con",491)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(492," minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commod",492," labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris",492)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(493,"elit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaec",493,"met, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et",493)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(494,"tur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qu",494,"ore eu fugiat nul",494)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(495,"mollit anim id ",495,"magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation",495)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(496,"mpor incididunt u",496,"g elit, sed do eiusmod tempor inc",496)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(497,"r in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.",497," ea commodo consequat. Duis aute irure dolor in reprehenderit in vo",497)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(498,"ate velit esse cillum dolore eu fugiat nulla pariatur",498,"it esse cillum dolore eu fugiat null",498)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(499,"m dolor sit amet, consectetur adipiscing elit, sed do",499,"itation ullamco laboris nisi ut aliquip ex",499)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(500," dolore eu fugiat nulla pariat",500,"llit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, s",500)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(501,"tat non proident, sunt in culpa qui officia ",501," id est l",501)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(502,"st laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor inci",502,"tetur adipiscing elit, sed do eiusmod tempor incididunt ut ",502)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(503,"t aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate ",503,"eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim v",503)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(504,"eserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consecte",504," nostrud exercitation ullamco labor",504)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(505,"ercitation ullamco laboris nisi ut ali",505," magna aliqua. Ut enim ad minim veniam, quis nostrud exercit",505)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(506,"voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaec",506,"citation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in re",506)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(507,"anim id est laborum.Lorem ipsu",507," culpa qui officia deserunt molli",507)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(508,"r sint occaecat cupidatat non proident, sunt in culpa qui",508,"e et dolore magna aliqua. Ut enim ad m",508)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(509,"runt mollit anim id est laborum.",509," cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in",509)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(510,"nt occaecat cupidatat non proident, sunt in culpa q",510,"n proident, sunt in culpa qui officia deserunt mollit anim id est laborum.Lo",510)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(511,"ore et dolore magna aliqua. Ut enim ad mi",511," enim ad min",511)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(512,"m ipsum dolor sit amet, consectetur adipiscing elit",512,"usmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad mi",512)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(513,", sunt in culp",513,"e dolor in reprehenderit in voluptate veli",513)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(514,"aecat cupidatat non proident, sunt in culpa qui offic",514,"a aliqua. Ut enim ad minim veniam, quis nostrud exercitation",514)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(515,"illum dolore eu fugiat ",515,"sunt in culpa qui officia deserunt mollit anim id est laborum.Lorem ip",515)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(516," anim id",516," sunt in culpa qui officia deserunt mollit anim id est lab",516)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(517,"qui officia d",517,"eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat",517)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(518,"llamco laboris nisi ut ",518,"o eius",518)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(519,"tation ullamco laboris nisi ut aliquip ex ea co",519,"qua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris ni",519)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(520," pr",520,"psum dolor",520)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(521,"Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat",521,"ris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in volupta",521)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(522,", sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim ven",522,"occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id",522)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(523," officia deser",523,"uip ex e",523)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(524,"dipiscing elit, sed do eiusmod tempor incididunt ut labore et dolo",524,"Ut enim ad minim ",524)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(525,"qui officia deserunt mollit anim id est laborum.Lorem i",525,". Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo c",525)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(526,"onsectetur ",526,"non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.Lo",526)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(527,"liquip ex ea commodo cons",527,"unt ",527)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(528,"voluptate velit esse cillum dolore eu fugiat nulla pariatur. Except",528,"ure dolor in reprehenderit in voluptate veli",528)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(529,"ulpa q",529,"t nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui offi",529)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(530,"em ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod",530,"uis nostrud exercitation ullamco laboris nisi ut ali",530)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(531,"bore et dolore magna aliqua. Ut enim a",531,"nt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, se",531)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(532,"erunt mollit anim",532,"erunt mollit anim id est laborum.Lorem ipsum dolor sit amet,",532)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(533,"est laborum.Lorem ipsum dolor sit amet, c",533,"is nostrud exercitation ullamco laboris nisi ut aliqu",533)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(534,"tur. Excepteur sint occaecat cupidatat non proident, sunt in culpa ",534,"magna aliqua. Ut enim ad minim veniam, quis nostrud exercit",534)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(535,"ommodo consequat. ",535,"eur sint occaecat cupidatat non proident, sunt in culpa qui",535)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(536,"lor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magn",536,"cididunt ut labore et dolore magna aliqua. Ut enim ad ",536)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(537,"sit ",537,"olore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui",537)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(538,"mollit anim id est laborum.Lorem ipsum dolor sit ame",538,"nt in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet,",538)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(539,"non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor",539,"ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod ",539)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(540,"at cupidatat non proident, sunt ",540,", consectetur adipiscing elit, sed do eiusmod tempor incididu",540)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(541,"ur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est la",541,"m veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo",541)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(542,"gna ",542,"lamco laboris nisi ut aliquip ex ea co",542)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(543,"tempor incidi",543,"n proident, sunt in culpa qui officia deserunt mollit anim id est laboru",543)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(544,"r adipiscing elit, sed do eiusmod tempor incididunt ut labore",544,"it esse",544)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(545,"s aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu",545,"unt ut labore et ",545)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(546,"epteur si",546,"in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor s",546)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(547,"lit, sed do eiusmod tempor incididunt ut labore et ",547," Duis aute irure dolor in reprehe",547)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(548,"is aute irure dolor in reprehenderit in voluptate velit esse cillum d",548,"r sit amet, consectetur adipiscing ",548)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(549,"aute irure dolor in reprehe",549,"nt in culpa qui officia deserunt mollit anim id est laboru",549)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(550,"piscing elit, sed do eiusmod tempor incididunt ut ",550,i,550)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(551,"iusmod tempor incididunt ut labore et dolore magn",551,"lor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dol",551)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(552,"ostrud exercitation ullamco laboris nisi ut aliquip ",552,"m ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labor",552)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(553,". Duis aute irure dolor in ",553,"scing elit, sed do eiusm",553)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(554,uptat,554,"sse cillum dolore eu fugiat nulla pariatur. Excepteur ",554)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(555," in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint ",555,"erunt mollit ani",555)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(556," aute irure dolor in reprehenderit in voluptate velit esse cill",556,"t enim ad minim veniam, qu",556)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(557,"upidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.Lorem i",557,"dent, sunt in culpa qui officia deserunt mollit anim id est laborum.Lore",557)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(558,"a pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui ",558,"quis nostrud exercitation ullamco laboris nisi ut ",558)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(559,"mpor incididunt ut labore et dolore magna aliqua. Ut enim ad minim ven",559,"um dolor sit amet, consectetur adipiscing",559)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(560,"t, consectetur adipiscing elit, sed do eiusmod tempor inc",560,"um dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt u",560)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(561,"si ut aliquip ex ea commodo consequat. Duis aute irure dolor",561,"gna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco la",561)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(562,"citation ullamco laboris nisi ut aliquip ex ea commodo consequat.",562," ut labore et dolore magna aliqua. Ut enim ad minim ",562)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(563,ab,563,"at. Duis aute irure dolor in reprehenderit",563)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(564,"it esse c",564," sit amet, consectetu",564)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(565," quis nostrud exercitation ullamco laboris ",565,"gna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliqu",565)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(566," amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magn",566,"sectetur adipiscing elit, sed do eiusmod tempor inc",566)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(567,"t aliquip ex ea commodo consequat. Duis aute irure do",567,"teur sint occaecat cupidatat n",567)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(568,"d minim veniam, quis nostrud exercitation ullamco laboris nis",568,"at nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt",568)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(569,"sum dolor sit amet, consectetur adipiscing e",569,"ore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco labo",569)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(570,"cat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est lab",570,"ccaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.Lor",570)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(571,"aliqua. Ut enim ad minim veniam, quis nostru",571,"sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est l",571)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(572," proident, sunt in ",572,"i officia deserunt mollit anim id est laborum.",572)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(573," fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proi",573," cillum dolore eu fugiat nulla pariatur. Excepteur sint occae",573)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(574,"atat non proident, sunt in culpa qu",574,"quip ex ea commodo consequat. Duis aute irure dolor in reprehender",574)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(575,"abore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ull",575,"nim veniam, quis nostrud e",575)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(576,mod,576,"iqua. Ut e",576)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(577,"r. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mo",577,"eprehenderit in voluptate ve",577)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(578," tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercita",578,"e eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qu",578)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(579,"ip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse",579,l,579)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(580,"d t",580,"quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aut",580)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(581,"irure dolor in reprehe",581," ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit ess",581)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(582,"m dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, s",582,"xcepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit a",582)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(583,"quip ex ea commodo consequat.",583,"e eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proid",583)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(584,"iam, ",584,"consequat. Du",584)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(585,"odo consequat. Duis aute ",585," aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco",585)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(586,"anim id est laboru",586,"minim veniam, q",586)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(587,proiden,587,"ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor i",587)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(588,"is aute irure dolor in reprehenderit in volu",588,"a commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse",588)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(589,"pidatat non proident, sunt in culpa qu",589,"lit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipisci",589)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(590,"est laborum.Lorem ipsum dolor sit amet, consectetur adip",590,"t mollit anim id est laborum.Lorem ipsum dolor sit amet, c",590)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(591," esse cillum d",591," voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaeca",591)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(592,"anim id est laborum.Lorem ipsum",592,"occaecat cupidatat non proident, sunt in culpa qui officia des",592)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(593,"dipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore m",593,"pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt moll",593)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(594," reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaec",594,"at nulla pariatur. Excepteur sint occaecat cupidatat ",594)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(595,"it in voluptate v",595,"m id est lab",595)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(596,"etur adipiscing elit, sed do eiusmod tempor incididunt u",596,"m.Lorem ipsum dolor sit amet, consectetur adipiscing eli",596)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(597,"laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor ",597,"mpor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veni",597)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(598,"ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip",598,"u fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui offi",598)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(599,"t in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sin",599,"at. Du",599)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(600,"te irure dolor in reprehenderit in volupta",600,"r incididunt ut labore et dolore magna aliqua. Ut e",600)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(601,"riatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia",601,"t enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commo",601)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(602,"erunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipisc",602,"d do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim",602)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(603," Excepteur sint occaecat cupidatat non proident, sunt ",603,". Excepteur sint occaecat cupidatat non proident, sunt",603)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(604,"ur sint occaec",604,"re magna aliqua. Ut enim ad minim veniam, quis nostrud exercitati",604)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(605,"abore et dolore m",605," in culpa qui officia deserun",605)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(606,", consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna al",606,"ute irure ",606)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(607,"sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim venia",607,"cepteur sint occaecat cupidatat non proident, sunt in ",607)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(608,"liquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in volupta",608,"por incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostr",608)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(609,"Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt",609,"dolor sit amet, consectetur adipiscing elit, s",609)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(610,"id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit",610," exercitation ullamco l",610)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(611," reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint",611,au,611)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(612,"rum.Lorem ipsum dolor sit amet, consectetur",612,"ur ad",612)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(613,"Excepteur sint",613,"t, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore mag",613)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(614,"lamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit i",614,"m dolor sit amet, c",614)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(615," ",615,"uptate velit esse ci",615)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(616,"or incididunt ut l",616,"t. Dui",616)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(617,"s aute irure dolor in reprehenderit in voluptate velit e",617," elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut ",617)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(618,"d exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Du",618,"on ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolo",618)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(619,"dunt ut labore et dolore ",619,"sunt in culpa qui officia deserunt mollit anim id ",619)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(620,"m ad minim veniam, quis n",620,"idunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nost",620)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(621," dolore magna aliqua. Ut enim ad mini",621," dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut ali",621)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(622,"it in vol",622," occaecat cupidatat non proident, sunt in culp",622)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(623," aliquip ex ea commodo consequat. Duis",623,"te velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proi",623)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(624,"ectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore mag",624,"a. Ut enim ad minim veniam, quis nostrud exercitation ullamco",624)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(625,"caecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.L",625,"mpor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud e",625)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(626," nostrud exercita",626,"oident, sunt in culpa qui officia deserunt mollit anim id est laborum.Lorem ip",626)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(627,"smod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud ",627,"int ",627)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(628,"eu fugiat n",628," deserunt mollit anim id est l",628)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(629,"t occaecat cupidatat non proident, sunt in culpa qui officia deseru",629,"e eu fugiat nu",629)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(630,"re eu fugiat null",630,"e magna aliqua. Ut enim ad minim veniam, quis nostrud",630)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(631,"ui officia deserunt mollit anim id est laborum.Lorem ipsu",631,"ut labore et",631)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(632,"ua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut ",632,"is nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo cons",632)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(633,"m, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea comm",633,"se cillum",633)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(634,"ing elit, sed do eiu",634,"non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.Lore",634)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(635,"am, quis nostrud exercitation ullamco laboris nisi ut aliquip e",635,"amco laboris nisi ut aliquip ex ea commodo consequat",635)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(636,om,636,"cididunt ut labore et dolore magna aliqua. Ut enim ad minim veni",636)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(637,"te irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla par",637," laboris nisi ut aliquip ex ea commodo co",637)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(638,"si ut aliquip ex ea commodo consequat. Duis aute ir",638,"r sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id ",638)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(639,"adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore ",639," consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna al",639)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(640,"dolore ",640,"epteur sint occaecat cup",640)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(641," cillum dolore eu fugiat nulla pariatur.",641,"um dolore eu fugiat nulla p",641)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(642,"dipiscing elit, s",642,nse,642)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(643,"od tempor incididunt ut labore et dolore magna aliqua. Ut enim ad mini",643,"t esse cillum dolore",643)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(645,"sunt in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor sit ame",645,"d do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad",645)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(646,"scing elit, sed do eiusmod tempor incididunt ",646,"iqua. Ut enim ad minim veniam, quis nostrud exercita",646)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(647,"oident, sunt in culpa qui officia d",647,"it anim id est laborum.Lorem ipsum",647)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(648,"nt in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor s",648,"onsectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut ",648)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(649," exercita",649,"m ipsum dolor sit amet, consectetur adipiscing elit, s",649)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(650,"im ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea comm",650,"lit, sed do eiusmo",650)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(651,"nt mollit anim id",651,"nt in culpa qui off",651)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(652," ut labore et dolore magna aliqua. Ut enim ad minim ven",652,"culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur",652)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(653,"labore et dolore magna aliqua",653,"ididunt ut labore et dolore magna aliqu",653)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(654,"nsectetur adipiscing elit, sed do eiusmod tempor incidi",654," occaecat cupi",654)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(655,"ad minim",655,"at non proident, sunt in culpa qui officia deserunt mollit anim id",655)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(656," officia deserunt mollit anim id est laborum",656,"u fugiat nulla pariatur. Excepteur sint",656)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(657,"is aute irure dolor in reprehenderit in voluptate velit esse cillum dol",657,"im ad minim veniam, quis ",657)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(658,"d tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nost",658," ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ull",658)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(659,"olore eu fugiat nulla pariatur. Exce",659,"n proident",659)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(660," veniam, quis nostrud exerc",660,"or in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint",660)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(661,"m dolor sit amet, consectetur adipiscing elit, sed do",661,"sunt in ",661)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(662,"is nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. ",662,sectet,662)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(663,"uis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis au",663,"idatat non proident, sun",663)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(664,"ur sint occaecat cupidatat non proident, sun",664," aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris",664)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(665,"it anim id est laborum.Lorem ipsum dolor sit amet, consect",665,"pa qui officia de",665)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(666,"sectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magn",666," in voluptate velit esse cillum dolore eu fu",666)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(667,"on ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in repreh",667,"aliquip ",667)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(668,"niam, quis nostrud exercitation ullamco laboris nisi ut aliquip e",668,"t aliquip ex ea commodo consequat. D",668)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(669,"sum dolor sit amet, consectetur adipiscing elit, s",669,"olor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut ",669)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(670,"amco laboris nisi ut aliquip ex ea co",670,"nsectetur adipiscing elit, sed do eiusmod tempor incididunt ut ",670)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(671,"modo consequat. Duis aute irure dolor in repreh",671,"ure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.",671)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(672,"lpa qui officia de",672," ea commodo consequat. Duis aute irure dolor in reprehenderit in volupt",672)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(673,"ore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui off",673,"sum dolor sit",673)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(674," ut aliquip ex ea commodo consequat. Duis aute irure d",674,"strud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Dui",674)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(675,"illum dolore eu fugiat nulla pariatur. Excepteu",675,"o laboris nisi ut aliquip ex ea commodo consequat. Duis aute ",675)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(676,"ectetur adipisc",676,"reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur s",676)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(677," commodo consequat. Duis aute irure dolor in reprehenderit in volupta",677,"icia deserunt mollit anim id est laborum.Lorem ipsum dolor si",677)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(678,"olore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, s",678," consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna al",678)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(679,"ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequa",679,"ulpa qui officia deserunt mollit anim id est la",679)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(680,"nderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaeca",680,"ris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in vo",680)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(681," ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum do",681,"iam, quis nostrud exercitation ullamco labor",681)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(682,voluptat,682,"oluptate velit esse cillum dolore eu fugiat n",682)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(683," esse cillum dolore e",683,"t nulla pariatur. Excepteur sint occaecat cupidatat no",683)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(684,"non proident, sunt in culpa qui officia deserunt ",684," Excepteur sint occaeca",684)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(685,"a deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, c",685,"dolor sit amet, consectetur adipiscing elit, s",685)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(686,"n ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in ",686,"pteur sint occaecat cupi",686)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(687,"henderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. E",687,"um dolore eu fugiat nulla pariatur. Excepteur sint occ",687)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(688,"olor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Exce",688,"nt, sunt in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor sit ame",688)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(689,"um dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt ",689," ad minim veniam, quis nostrud exercitation ulla",689)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(690," non proident, sunt in culpa qui officia d",690,"a aliqua. Ut enim ad minim veniam, quis nos",690)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(691,"m dolor sit amet, consectetur adipiscing",691," eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis no",691)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(692,"cupidatat non proident",692,"e irure dolor in reprehenderit in voluptate velit esse ci",692)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(693,"pariatur. Excepteur sint occaecat cupidatat non proi",693,ce,693)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(694,"fficia deserunt mollit anim id est l",694,"olore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proiden",694)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(695,"e et dolore magna aliqua",695," commodo consequat. Duis aute irure dolor in reprehenderit in voluptate v",695)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(696,", quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute iru",696," ipsum dolor sit amet, consectetur adipiscing elit, sed do ",696)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(697,"irure dolor in reprehenderit in voluptate velit esse cillu",697,"t in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectet",697)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(698,"at non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor sit",698,"trud exercitation ullamco laboris",698)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(699," c",699,"ia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adi",699)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(700,"um dolor sit amet, consectetur adipiscing elit, s",700,"olor in reprehenderit in voluptate velit esse cillum dol",700)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(701,"veniam, quis nostrud",701,"a commodo consequat. Duis aute irure dolor in reprehenderi",701)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(702,"i of",702,"veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip",702)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(703,"rud exercitation u",703,"onsequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugia",703)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(704,"inim veniam, quis nostrud exercitation ullamco laboris nisi ",704,"sum dolor sit amet, consectetur adipiscing elit, sed do eiusm",704)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(705,"ulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui of",705,"psum d",705)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(706,"st laborum.Lorem ipsum dolor",706,"ididunt ut labore et dolore magna aliqua. Ut enim ad min",706)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(707,"at nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia de",707,"irure dolor in reprehenderit in vol",707)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(708,"e cillum dolore eu fugiat nulla pariatur. Excepte",708,"t laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do ei",708)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(709,"aliquip ex ea commodo consequat. Duis aute irure",709,"t in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet,",709)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(710,"mpor incididunt ut labore et dolore magna aliqua. U",710,"nim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commo",710)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(711,"dipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim",711,"ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cill",711)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(712,"olor i",712,". Duis aute irure dolor in reprehender",712)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(713,"fugiat nulla pariatur. Excepteur sint occ",713,"rum.Lorem ipsum dolor sit amet, consectetur a",713)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(714,"veniam, quis nostrud exercitation ullamco laboris ",714," dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut ali",714)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(715,"rem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore e",715,"sunt in culpa qui officia deserunt mollit anim id est laborum.Lorem ip",715)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(716," Excepteur sint occaecat cupidatat",716,"nulla pariatur. Excepteur sint occaecat cupidatat non ",716)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(717,"minim veniam, quis nostrud exercitation ullam",717," dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore ",717)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(718," ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolor",718,"nim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing",718)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(719,"r sint",719,"or sit amet, consectetur adipiscing elit, s",719)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(720,"incididunt ut labore et dolore magna aliqua. Ut enim",720,"deserunt mollit anim id est laborum.Lorem ipsum d",720)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(777,"unt mollit ani",777," ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis ",777)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(721,"unt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud ",721,"tempor incididunt ut labore et dolore magna ali",721)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(722,"m, quis nostrud exercitat",722,"it ",722)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(723,"t ut labore et dolore magna aliqua.",723,"rure dolor in reprehenderi",723)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(724,"dent, sunt in culpa qui officia deserunt mollit anim id est laborum.Lo",724,"od tempor incididunt ut labore et dolore m",724)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(725,"r in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla",725,"oident, sunt in cul",725)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(726,"rem ipsum dolor s",726,"ut labor",726)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(727,"quat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla ",727,"olor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pari",727)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(728,"culpa qui officia deserunt mollit anim id est laborum.Lore",728,".Lorem ipsum dolor sit amet, c",728)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(729,"xercitation ullamco laboris nisi ut",729,orum.L,729)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(730,"d exercitation ullamco laboris nisi ut aliquip ",730,aborum,730)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(731,"cia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adip",731,"aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea ",731)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(732," ut labore et dolore magna aliqua. Ut enim ad min",732,"at. Duis aute irure do",732)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(733,"erunt m",733,"Duis aute irure dolor in reprehenderit in voluptate velit",733)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(734," commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit ",734," sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna ",734)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(735,"trud exercitation ullamco laboris nisi ut aliquip ex ea comm",735,"roident, sunt in culpa qui officia deserunt mollit anim id est laborum.Lorem",735)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(736,"n ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in rep",736,"d do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim",736)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(737," elit, sed do eiusmod tem",737,"rure dolor in reprehenderit in voluptate velit",737)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(738,"aboris nisi ut aliquip ex ea commodo consequat. Duis aute irure d",738,"laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempo",738)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(739,"co laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in volu",739,"por in",739)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(740,"tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exerc",740,"t laboru",740)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(741,"pteur sint occaecat cupid",741,"n proident, sunt in culpa qui officia deserunt mollit anim id es",741)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(742,"ccaecat cupidatat non proid",742,"ommodo consequat. Duis aute irure dolor in reprehenderit ",742)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(743," consequat. Du",743,"oluptate velit es",743)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(744,"r. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui off",744,"nim ad minim veniam, q",744)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(745,"tion ullamco laboris nisi ut aliquip ex ea commodo conseq",745,"re et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco",745)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(746,"itation ullamco la",746,"um dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut ",746)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(747,"ris nisi ut aliquip ex ea commodo",747,"or sit amet, consectetur adipiscing ",747)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(748," in voluptate velit esse",748,"idunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullam",748)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(749,"nderit in voluptate velit esse cillum dolore eu f",749,"citation ul",749)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(750,"ident, sunt in ",750,"st laborum.Lorem ipsum dolor sit amet, consectetu",750)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(751,"ur sint occaecat cupidatat non proident, sunt in culpa qui officia des",751," sed do eiusmo",751)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(752,"sse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident,",752,"abore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercit",752)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(753,"iscing elit, sed do eiusmod temp",753,"ation ullamco laboris nisi ut aliquip ex ",753)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(754,"Duis aute irure",754,", consectetur adipiscing elit, sed do eiusmod tempor incididunt",754)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(755,"ud exercitation ul",755,"it in voluptate velit esse cillum dolore",755)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(756," occaecat cupidatat no",756,"gna aliqua. Ut enim ad minim veniam, quis nost",756)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(757,"lla pariatur. Excepteur sint occaecat cupidatat n",757,"ea commodo consequat. Duis aute ",757)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(758,"mmodo consequat. Duis aute irure dolor in reprehenderit in vo",758," enim ad minim veniam, quis nostrud exercitation ullamco",758)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(759,"dent, sunt in culpa qui officia deserunt mollit anim ",759,", consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labor",759)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(760,"ore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco la",760,"ia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, cons",760)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(761,"ur. Excepteur sint occaecat cupidatat non proi",761,"r. Excepteur sint occaecat cupidatat non proident, sunt i",761)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(762,"exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis au",762," pariatur. Excepteur sint occaecat cupida",762)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(763,"it, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim v",763,"llamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in repre",763)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(764,"im veniam, quis nostrud exercitation ullamco ",764,"ris nisi ut aliquip ex ea commodo consequat. Duis aute irur",764)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(765,"iscing e",765,"e velit esse cillum dolore eu fugiat nulla pari",765)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(766,"lore eu fugiat nulla ",766,"nt in culpa qui officia deserunt mollit anim id est laborum.Lo",766)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(767,on,767,"tate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat c",767)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(768," consequat. Duis aute irure dolor in reprehenderit in volupta",768,"proident, sunt in culpa qui officia deserunt mollit anim id ",768)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(769,"t anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor",769,"oluptate velit esse cillum ",769)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(770,"reprehenderit in voluptate velit esse cillum dol",770,"o consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse ",770)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(771,"in culpa",771," aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse",771)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(772,"dunt ut labore et dolore magna aliqua. Ut",772,"n voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non",772)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(773," amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliq",773,"na aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip",773)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(774,"uis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis",774,"n ullamco laboris nisi ut aliquip ex ea commodo conse",774)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(775,"t mollit anim id est laborum.Lorem",775,"deserunt molli",775)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(779,"sunt in culpa qui officia ",779,"onsequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat",779)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(780," ipsum dolor sit amet, consect",780,occa,780)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(781,"culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adip",781,"ehenderit in voluptate velit esse cillum dolore e",781)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(782,"erunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipi",782,"laboris nisi ut ",782)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(783,"d minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo conse",783,"d minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip e",783)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(784," minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequ",784,"aecat cupidatat non proident, sunt in culpa qui officia des",784)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(785,"a. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commo",785," ad minim veniam, quis nostrud exercita",785)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(786,"t cupidatat non proident, sunt in culpa qui",786,"onsectetur adipiscing elit, sed",786)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(787,"non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor s",787,"abore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ulla",787)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(788,"s aute irure dolor in repr",788,r,788)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(789," irure dolor in reprehenderit in voluptate velit esse c",789,"onsequat. Duis aute irure dolor in reprehende",789)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(790,"ia deserunt mollit anim id est laborum.Lorem i",790,"ostrud exerc",790)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(791,"iscing elit, sed do eiusmod tempor incididunt ut labore et dolore",791,"exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in",791)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(792,"olor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididun",792,"piscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim v",792)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(793,"s nisi ut aliquip ex ea commodo consequat. Duis aute irure do",793," eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut",793)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(794,"ure dolor in reprehenderit in vo",794,oru,794)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(795," ad minim veniam, quis nostrud exercitatio",795," tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis no",795)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(796,"t, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut l",796,"m ipsum dolor sit amet, consectetur adipiscing",796)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(797,"ptate velit esse cillum dolore eu fugiat nulla pariatur. Exce",797,"psum dolor sit amet, consectetur adipiscing elit, sed do eius",797)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(798," ut labore et dolore magna aliqua. Ut enim ",798,"elit, sed do eiusmod tempor incididunt ut labore et do",798)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(799,"t anim id est laborum.Lorem ipsum dolor sit amet,",799,"erit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat c",799)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(800,"ollit anim id est laborum.Lorem",800," ad minim veniam, quis nostrud exercitation ullam",800)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(801,"nt, sunt in ",801,"in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla par",801)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(802,"lor sit amet, consectetur adipiscing elit, s",802,"e eu fugiat nulla pariatur. Excepteur sint occaecat cup",802)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(803,"a. Ut enim ad minim veniam, quis nostrud exercita",803,"rem ipsum dolor sit amet, consectetur adipiscing el",803)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(804,"id est laborum.Lorem ipsum dolor si",804,"ur sint occaecat cupidatat non proident, sunt ",804)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(805,"olor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur s",805,"im veniam, quis n",805)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(806,ipisci,806,"t dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut ",806)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(807,"ea commodo consequat",807,"nt, sunt in culpa qui officia deserunt mollit anim id est laborum.Lor",807)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(808,"rem ipsum dolor sit amet, consectetur adipi",808,"re eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, s",808)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(809,"i officia deserunt mollit anim id est laborum.Lo",809,p,809)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(810," dolor s",810,"t, consectetur adipiscing elit, sed do ei",810)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(811,"aute irure dolor in reprehenderit in voluptate vel",811,r,811)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(812,"ip ex ea",812,"re magna aliqua. Ut enim a",812)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(813,"illum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non",813,"a aliqua. ",813)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(814,"datat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.Lorem",814,"upidatat non proident, sunt in c",814)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(815,"llamco laboris nisi ut aliquip ex ea commodo con",815,"officia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing e",815)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(816,"liquip ex ea commodo consequat. Duis aute irure dolor in reprehen",816,"xercitation ullamco laboris nisi ut aliquip ex ea ",816)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(817,"mod tempor incididunt ut labore et dolore magna aliqua. Ut ",817,o,817)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(818,"officia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adip",818,"ugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui offi",818)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(819,"a aliqua. Ut eni",819,"lor in reprehenderit in voluptate velit esse cillum dolore eu fugi",819)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(820," enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea",820,"Lorem ipsum do",820)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(821,"riatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui offi",821,"ugiat nulla pariatur. Excepteur sint o",821)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(822,"rem ipsum dolor sit amet, consectetur adipisc",822,it,822)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(823,"uat. Duis aute irure dolor in reprehe",823,"abore ",823)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(824,"on proident, sunt in culpa qui offic",824,"co laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor",824)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(825," dolor in reprehenderit in",825," dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt u",825)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(826,"tate veli",826," occaecat cupidatat non proident, sunt in c",826)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(827,"uis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla paria",827,"orem ipsum do",827)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(828,"iam, quis nostrud exercitation ullamco laboris nisi ut aliqui",828,"sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis",828)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(829,"cat cupidatat non proident, sunt in ",829,"s nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis a",829)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(830,"t aliquip ex ea commodo consequat. ",830,"ut labore et dolore ma",830)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(905,"nisi ut aliquip ex ea commodo con",905," sed do eiusmod tempor",905)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(831,"ptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat",831,"roident, sunt in ",831)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(832,"ugiat nulla",832,"voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint oc",832)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(833,"aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea ",833," nulla pariatur. Excepteur sint occaecat cupidatat non",833)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(834,"magna aliqua. Ut enim ad minim veniam, quis nostrud exe",834,"erunt m",834)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(835,"aboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in vol",835,"nsequat. Duis aute irure do",835)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(836,u,836," esse cillum dolore eu fugiat nulla pariatur. Excepteu",836)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(837,"amco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in v",837,"o consequat. D",837)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(838,"a. Ut enim ad minim veniam, quis nost",838,"od tempor i",838)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(839," reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occ",839,"ercitation ullamco la",839)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(840,"t in voluptate velit esse cillum dolo",840,"fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, su",840)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(841,"datat non proident, sunt in culpa q",841,"laborum.Lorem ipsum dolor sit amet, cons",841)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(842,"olor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut lab",842,"is nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate vel",842)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(843," ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in vo",843,"sunt in culpa qui officia deserunt mollit anim id est laborum.L",843)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(844,"d minim veniam, quis nostrud exercitation ullamco laboris n",844," labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud ex",844)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(845,"inim veniam, quis nostrud exercitation ullamco labo",845,"x ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate",845)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(846,"prehenderit in voluptate v",846,"Ut enim ad minim veniam, qui",846)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(847,"t in voluptat",847," deserunt mollit anim id ",847)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(848,"est laborum.Lorem ipsum dolor sit amet, consectetur",848,"a deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing",848)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(849,"ute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Ex",849," incididunt ut lab",849)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(850,"t esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat ",850,"et, co",850)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(851,"t in voluptate velit esse ci",851,"eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat no",851)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(852,"eniam, quis nostrud exercitation ul",852,"nostrud exercitation ullam",852)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(853,"t, sunt in culpa qui officia deserunt m",853,"adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut eni",853)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(854,"lit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam",854,"at nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui offici",854)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(855,"mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eius",855,"rum.Lorem ipsum dolor sit amet, consectetur adipiscing elit",855)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(856,"ficia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit,",856,"n reprehenderit in vol",856)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(857,"nt, sunt in culpa qui officia deserunt mollit anim i",857,"or in reprehenderit in voluptate velit esse cillum do",857)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(858,"odo consequat. Duis aute irure dolor in repre",858,"quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aut",858)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(859,"usmod tempor incididunt ut labore et",859,"llum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt ",859)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(860,"uptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur s",860,"mmodo consequat. Duis aute irure dolor in reprehe",860)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(861,"sunt in culpa qui officia deserunt mollit anim id est l",861,"enderit in ",861)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(862,"amco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure",862,"odo con",862)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(863,"borum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tem",863,"itation ullamco laboris nisi ut aliquip ex",863)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(864,"at. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolo",864,"tation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aut",864)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(865,"etur adipiscing elit, sed do ei",865,"dipiscing elit, s",865)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(866,"irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat null",866," cupidatat non proident, sunt in culpa qui officia deserunt mollit ",866)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(867,"ent, sunt in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum do",867,"Lorem ipsum dolor sit amet, conse",867)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(868,"ore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in c",868," et dolore magna aliqua. Ut enim a",868)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(869,pariat,869,"ation ullamco laboris nis",869)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(870,"unt in cu",870,"ore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in cul",870)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(871,"re et dolore magna aliqua. Ut enim ad ",871,"lore magna aliqua. Ut enim ad minim veniam, quis nostru",871)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(872,"est laborum.Lorem ipsum dolor sit amet,",872,tate,872)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(873,"it amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna",873,"in culpa qui officia deserunt m",873)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(874,iden,874,"occaecat cupidatat non proident, sunt in culpa qui officia des",874)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(875,"m veniam, quis nostrud exercita",875,"a pariatur. ",875)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(876," nulla pariatur. Excepteur si",876,"ollit anim id est laborum.Lorem ipsum d",876)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(877,"r sint occaecat cupidatat no",877,"riatur. ",877)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(878,"usmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veni",878," ea commodo consequat. Duis aute irure dolor ",878)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(879,"ptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occae",879,"elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim venia",879)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(880,"adipiscing elit, sed do eiusmod tempor incididunt ut labore",880,"it esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt",880)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(881,"lore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ul",881,"on proident, sunt in culpa qui officia deserunt mollit ",881)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(882,"uat. Duis a",882,"aboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in vol",882)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(883,"o laboris nisi ut aliquip e",883,"rcitation ullamco laboris nisi ut aliquip ex ea com",883)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(884,"t laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempo",884,"ficia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur",884)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(885,"non proident, sunt in culpa qui officia deserunt mol",885," pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia dese",885)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(886,"t enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut a",886,"olor sit amet, consectetur adipiscing elit, sed do eiusmod",886)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(887,"cididunt ut lab",887,"nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa ",887)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(888,"commodo consequat. Duis aute irure dolor in reprehenderit in voluptat",888,"t, consectetur adipiscing ",888)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(889,"idatat non proident, sunt in culpa qui officia deserunt mol",889,"voluptate veli",889)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(890,eiu,890,"eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in c",890)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(891,"n reprehenderit in voluptate velit ess",891,"dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt ",891)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(892," sit amet, consect",892,"qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, cons",892)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(893,"ut labore et dolore magna aliqua. Ut enim ad min",893,"ollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusm",893)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(894," u",894,"ut labore et dolore magna aliqua. Ut enim ad minim venia",894)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(895,"citation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor",895,"re dolor in repr",895)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(896,"ute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu",896,"nsectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et d",896)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(897,"aborum.Lorem ipsum",897,"ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo",897)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(898,"dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididun",898,"m dolor sit amet, consec",898)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(899,"commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit",899,"cepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit a",899)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(900," incididunt ut labore et dolore magna aliqua. ",900,"ure dolor in reprehenderit i",900)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(901,"t in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor sit",901,"dolore magna aliqua. Ut e",901)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(902,"psum dolor sit amet, consectetur",902,"m ipsum dolo",902)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(903,iatur.,903,"epteur sint occaecat cupidatat non proident, sunt in culpa qui officia ",903)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(904,"m veniam, quis nostrud exercitation ullamc",904," adipiscing elit, sed do eiusmod tempor incididunt ut labore et d",904)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(906,"m.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labo",906,"ud exercitation ullamco laboris nisi",906)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(907,"ipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad ",907," eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non pr",907)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(908,"e velit esse cillum dolore eu fugiat nulla pariatur",908,"trud exercitation ullamco laboris nisi ut aliquip ",908)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(909,"fficia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing",909,"sed do eiusm",909)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(910,"si ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit ",910,"nsectetur adipiscing elit, sed do eiusmod tempor incididunt ut labo",910)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(911,"o consequat. Duis aute irure dolor in reprehenderit in voluptate veli",911,"t. Duis aute irure dolor in reprehenderit in voluptate velit e",911)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(912,"t mollit anim id est laborum.Lorem ipsum dolor sit",912,"tion ullam",912)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(913," ipsum dolor sit ",913,"prehenderit in voluptate velit esse cillum dolo",913)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(914,"ommodo consequa",914," Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris ",914)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(915," pariatur.",915,"t cupidatat non proident, sunt in culpa qui offic",915)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(916,"iam, quis nostrud exercitation ",916," Excepteur sint occaecat cupidatat non proiden",916)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(917,", quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo conse",917,"at non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.L",917)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(918,"e et dolore magna aliqua. Ut enim ad minim ve",918," fugiat nulla pariatur. Exce",918)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(919,"s nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis",919,"it in voluptate velit esse cillum dolore eu fugiat nulla pa",919)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(920,"is aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu f",920,"si ut aliquip ex ea comm",920)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(921,"voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat ",921,"im veniam, quis nostrud exercitation ullamco laboris ni",921)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(922,", consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et do",922,"o laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehend",922)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(923,"im veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis ",923,"ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis",923)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(924,"sse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident",924,"e magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ull",924)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(925,"eur sint occaecat cupidatat non proident, sunt in culpa qui offici",925,"qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur ad",925)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(926,"t mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do",926,"sint occaecat cupidatat non proident, sunt",926)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(927,"sse cillum dolore eu fugiat nulla pariatur. ",927,"ulpa qui officia deserunt mollit anim id est",927)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(928,"mco laboris nisi ut aliquip ex ea",928,"laboris nisi ut aliquip ex ea commodo con",928)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(929," eiusmod tempor incididunt ut labore et dolore magna aliqu",929,"d exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute ",929)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(930,r,930," esse cillum dolore eu fugiat nulla paria",930)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(931,"dolor in reprehen",931,"tation ullamco laboris nisi ut aliquip ex ",931)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(932,"llamco laboris nisi ut aliquip ex ea commodo consequat. ",932,"t aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate v",932)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(933,"r in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pa",933,"m id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit",933)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(934,"ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitat",934," ea com",934)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(935,"idunt ut labore et do",935,"Excepteur sin",935)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(936,"anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eius",936,"d est laboru",936)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(937," eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat",937,"ulla pariatur. Excepteur sint occaecat cupid",937)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(938," incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nos",938,"icia deserunt mollit anim id est laborum.Lorem ipsum dol",938)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(939,"lpa q",939,"cat cupidatat non proident, sunt in culpa qui officia deserunt mollit ",939)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(940,"n reprehenderit in volupta",940," irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excep",940)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(941,"exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure d",941,"nsequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum d",941)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(942,"olore magna aliqua. Ut enim ad minim veniam,",942,"ollit anim id est laborum.Lore",942)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(943,"didunt ut labore et dolore magna aliqua",943,"nderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupi",943)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(944,"didunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitatio",944,occaeca,944)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(945,"it amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolo",945,"pa qui officia deser",945)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(946,"int occaecat cupidatat non proident, sunt in culpa qui off",946,"met, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore m",946)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(947,"or incididunt ut labore et dolo",947," in voluptate velit esse cillum dolore eu fugiat nulla pa",947)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(948,"ia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed",948,"iquip ex ea commodo consequat. Duis aute irure dolor in repreh",948)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(949,"sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam,",949,"elit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, s",949)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(950,"e et dolore magna aliqua. Ut enim ad minim veniam",950," ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis",950)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(951,sint,951,"id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, s",951)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(952,"or sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore ",952," laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dol",952)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(953,"is nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute i",953,"aliqua. Ut enim ad minim veniam, quis nostrud exercitation ",953)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(954,"ipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna",954,".Lorem ipsum dolor sit amet",954)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(955,"scing elit, sed do eiusmod tempor incididun",955,"p ex ea c",955)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(956,"illum dolore eu fugiat ",956,"se cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non p",956)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(957,"ore magna aliqua. Ut enim ad minim veniam, quis n",957," ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse c",957)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(958,"am, quis nostrud exercitation ull",958,"re dolor in reprehenderit in voluptate velit esse cillum ",958)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(959,"s nisi ut aliqui",959,"nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in ",959)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(960," ipsum dolor",960,"t ut labore et dolore magna aliqua. Ut enim ",960)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(961,"is aute irure dolor in reprehenderit in voluptate velit esse cillum ",961,"aliquip ex ea commod",961)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(962,"ent, sunt in culpa qui officia deserunt mollit anim i",962,". Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mo",962)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(963,"ation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehende",963,"pariatur. Excepteur sint occaecat cupidatat non proid",963)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(964,"adipiscing elit, sed do eiusmod tempor ",964,"re dolor in reprehenderit in voluptate velit es",964)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(965,"ipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut",965,"henderit in voluptate velit esse cillum dolore eu f",965)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(966,"abore et dolore magna aliqua. Ut enim ad minim veniam, quis nost",966,"ing elit, sed do eiusmod te",966)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(967,"Lorem ipsum dol",967,"reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint oc",967)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(968,"tion ul",968,"illum dolore eu",968)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(969," voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur ",969,"ehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occae",969)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(970,"r sint occaecat cupidatat non proident, sunt in culpa ",970," magna aliqua. Ut enim ad minim veniam, quis nostrud exe",970)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(971,"aliquip ex ea commodo con",971," ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labo",971)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(972,"nt occaecat cupidatat non proident, sunt in culpa qui officia des",972,"laborum.Lorem ipsum do",972)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(973,"idatat non proident, sunt in culpa qui ",973,"modo consequat. Duis aut",973)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(974," commod",974,"p ex ea commodo consequat. Duis aute irur",974)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(975,"aecat cupidat",975,"atur. Excepteur sint occaecat cupidatat non p",975)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(976,"ure dolor in ",976,"eprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Ex",976)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(977,"it anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipi",977,"ip ex ea commodo consequat. Duis aute irure dolor in reprehenderit ",977)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(978,"ptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat",978,"t esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaec",978)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(979,"re magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris",979,", consectetur adipiscing elit, ",979)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(980,e,980,"occaecat cupidatat non proident, sunt in",980)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(981,"prehenderit in ",981,"ure dolor in reprehenderit in voluptate velit esse",981)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(982,"nt in culpa qui officia deserunt mollit anim id est laborum.Lorem ipsum dolor sit amet,",982,"t occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit ani",982)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(983,"datat non proident, sunt in culpa qui offici",983," aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pari",983)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(984,"um dolore eu fugiat nulla pariatur. Excepteu",984,"ent, sunt in culpa qui officia deserunt mollit anim id es",984)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(985,"agna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamc",985,"um dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et ",985)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(986,"se cillum dolore eu f",986," in reprehenderit in voluptate velit esse cillum dolore eu fugiat nul",986)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(987," consequat. Duis aute irure dolor in reprehenderit in ",987,at,987)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(988," consequat. ",988,"tion ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis au",988)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(989," in reprehenderit in ",989,"t mollit anim id est laborum.Lorem ipsum dolor sit",989)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(990,"proident, sunt in culpa qui officia deserunt mollit ani",990,"sectetur adipiscing elit, sed do eiusmod tempor inci",990)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(991,"lit, sed do eiusmod tempor incididunt ut labore",991,"on ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in ",991)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(992,"s nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in vol",992," consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse ci",992)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(993,"ommodo consequat. Duis aute irure dolor in reprehenderit in voluptate veli",993," pariatur. Excepte",993)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(994,"idunt ut labore et dolore magna al",994,"modo consequat. Duis aute irure do",994)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(995,"rud exercitation ullamco laboris n",995,"tetur adipiscing elit, sed do eiusmod ",995)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(996,"nt mollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do",996," et dolore magna aliqua. Ut enim ad minim",996)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(997,"t aliquip ex ea commodo consequat. Duis aute irure dolor in r",997,"m, quis n",997)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(998,"t. Duis aute irure dolor in reprehenderit",998,"llum dolore eu fugiat nulla pariatur. Ex",998)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(999,"m ad minim veniam, quis nostrud exercita",999,"ollit anim id est laborum.Lorem ipsum dolor sit amet, consectetur adipiscing eli",999)	\N	delete from wgm."CLIENTE"
wgm	CLIENTE	postgres	2018-10-21 19:21:41.334543-03	D	(1000," sunt in culp",1000,"iat nulla pariatur. Excepteur sint occaecat cupidatat n",1000)	\N	delete from wgm."CLIENTE"
wgm	USUARIO	postgres	2018-10-21 22:18:36.66059-03	I	\N	(1,erasmo.iesb@gmail.com,123456,periperi,23123123123)	INSERT INTO wgm."USUARIO" ("ID","EMAIL","SENHA","ENDERECO","TELEFONE")\nVALUES ($1,$2,$3,$4,$5)
wgm	DISTRIBUIDORA	postgres	2018-10-21 22:19:08.314276-03	I	\N	(1,1,1,1,1)	INSERT INTO wgm."DISTRIBUIDORA" ("ID","FK_USUARIO","CNPJ","RAZAO_SOCIAL","NOME_FANTASIA")\nVALUES ($1,$2,$3,$4,$5)
wgm	VENDEDORA	postgres	2018-10-21 22:19:38.622073-03	I	\N	(1,1,1,1,06656019560)	INSERT INTO wgm."VENDEDORA" ("ID","FK_USUARIO","FK_DISTRIBUIDORA","NOME","CPF")\nVALUES ($1,$2,$3,$4,$5)
wgm	fabrica	postgres	2018-12-03 22:29:19.370119-03	I	\N	(1,"Fabrica Normal",Normal,4234234)	insert into wgm.fabrica (telefone, endereco, nome, id) values ($1, $2, $3, $4)
\.


--
-- Name: COBRANCA_VENDEDORA_ID_seq; Type: SEQUENCE SET; Schema: wgm; Owner: postgres
--

SELECT pg_catalog.setval('wgm."COBRANCA_VENDEDORA_ID_seq"', 1, false);


--
-- Name: DISTRIBUIDORA_ID_seq; Type: SEQUENCE SET; Schema: wgm; Owner: postgres
--

SELECT pg_catalog.setval('wgm."DISTRIBUIDORA_ID_seq"', 1, false);


--
-- Name: FABRICA_ID_seq; Type: SEQUENCE SET; Schema: wgm; Owner: postgres
--

SELECT pg_catalog.setval('wgm."FABRICA_ID_seq"', 1, false);


--
-- Name: IMAGEM_ID_seq; Type: SEQUENCE SET; Schema: wgm; Owner: postgres
--

SELECT pg_catalog.setval('wgm."IMAGEM_ID_seq"', 1, false);


--
-- Name: PRODUTO_ID_seq; Type: SEQUENCE SET; Schema: wgm; Owner: postgres
--

SELECT pg_catalog.setval('wgm."PRODUTO_ID_seq"', 1, false);


--
-- Name: USUARIO_ID_seq; Type: SEQUENCE SET; Schema: wgm; Owner: postgres
--

SELECT pg_catalog.setval('wgm."USUARIO_ID_seq"', 1, false);


--
-- Name: VENDEDORA_ID_seq; Type: SEQUENCE SET; Schema: wgm; Owner: postgres
--

SELECT pg_catalog.setval('wgm."VENDEDORA_ID_seq"', 1, false);


--
-- Data for Name: cliente; Type: TABLE DATA; Schema: wgm; Owner: postgres
--

COPY wgm.cliente (id, telefone, endereco, cpf_cnpj, nome) FROM stdin;
3	werwer	werwer	werwer	erwer
\.


--
-- Data for Name: cobranca_vendedora; Type: TABLE DATA; Schema: wgm; Owner: postgres
--

COPY wgm.cobranca_vendedora (id, parcela, data_vencimento, pedido_id, flag_pagamento) FROM stdin;
\.


--
-- Data for Name: distribuidora; Type: TABLE DATA; Schema: wgm; Owner: postgres
--

COPY wgm.distribuidora (id, usuario_id, cnpj, razao_social, nome_fantasia, telefone, endereco) FROM stdin;
\.


--
-- Data for Name: estoque_distribuidora; Type: TABLE DATA; Schema: wgm; Owner: postgres
--

COPY wgm.estoque_distribuidora (distribuidora_id, produto_id, quantidade) FROM stdin;
\.


--
-- Data for Name: estoque_vendedora; Type: TABLE DATA; Schema: wgm; Owner: postgres
--

COPY wgm.estoque_vendedora (produto_id, vendedora_id, quantidade) FROM stdin;
\.


--
-- Data for Name: fabrica; Type: TABLE DATA; Schema: wgm; Owner: postgres
--

COPY wgm.fabrica (id, nome, endereco, telefone) FROM stdin;
1	Fabrica Normal	Normal	4234234
\.


--
-- Name: hibernate_sequence; Type: SEQUENCE SET; Schema: wgm; Owner: postgres
--

SELECT pg_catalog.setval('wgm.hibernate_sequence', 3, true);


--
-- Data for Name: imagem; Type: TABLE DATA; Schema: wgm; Owner: postgres
--

COPY wgm.imagem (id, produto_id, img) FROM stdin;
\.


--
-- Data for Name: pedido; Type: TABLE DATA; Schema: wgm; Owner: postgres
--

COPY wgm.pedido (id, vendedora_id, produto_id, cliente_id, quantidade, desconto, preco_venda) FROM stdin;
\.


--
-- Data for Name: pedido_produto; Type: TABLE DATA; Schema: wgm; Owner: postgres
--

COPY wgm.pedido_produto (produto_id, pedido_id) FROM stdin;
\.


--
-- Data for Name: produto; Type: TABLE DATA; Schema: wgm; Owner: postgres
--

COPY wgm.produto (id, fabrica_id, ref, descricao, largura, altura, profundidade, cor, preco, tamanho, distribuidora_id) FROM stdin;
\.


--
-- Data for Name: usuario; Type: TABLE DATA; Schema: wgm; Owner: postgres
--

COPY wgm.usuario (id, email, senha) FROM stdin;
1	erasmo.iesb@gmail.com	123456
\.


--
-- Data for Name: vendedora; Type: TABLE DATA; Schema: wgm; Owner: postgres
--

COPY wgm.vendedora (id, usuario_id, distribuidora_id, nome, cpf, endereco, telefone) FROM stdin;
\.


--
-- Name: DISTRIBUIDORA_CNPJ_key; Type: CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.distribuidora
    ADD CONSTRAINT "DISTRIBUIDORA_CNPJ_key" UNIQUE (cnpj);


--
-- Name: DISTRIBUIDORA_NOME_FANTASIA_key; Type: CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.distribuidora
    ADD CONSTRAINT "DISTRIBUIDORA_NOME_FANTASIA_key" UNIQUE (nome_fantasia);


--
-- Name: DISTRIBUIDORA_RAZAO_SOCIAL_key; Type: CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.distribuidora
    ADD CONSTRAINT "DISTRIBUIDORA_RAZAO_SOCIAL_key" UNIQUE (razao_social);


--
-- Name: PRODUTO_DESCRICAO_key; Type: CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.produto
    ADD CONSTRAINT "PRODUTO_DESCRICAO_key" UNIQUE (descricao);


--
-- Name: PRODUTO_REF_key; Type: CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.produto
    ADD CONSTRAINT "PRODUTO_REF_key" UNIQUE (ref);


--
-- Name: USUARIO_EMAIL_key; Type: CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.usuario
    ADD CONSTRAINT "USUARIO_EMAIL_key" UNIQUE (email);


--
-- Name: VENDEDORA_CPF_key; Type: CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.vendedora
    ADD CONSTRAINT "VENDEDORA_CPF_key" UNIQUE (cpf);


--
-- Name: cliente_pkey; Type: CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.cliente
    ADD CONSTRAINT cliente_pkey PRIMARY KEY (id);


--
-- Name: cobranca_vendedora_pk; Type: CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.cobranca_vendedora
    ADD CONSTRAINT cobranca_vendedora_pk PRIMARY KEY (id);


--
-- Name: distribuidora_pk; Type: CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.distribuidora
    ADD CONSTRAINT distribuidora_pk PRIMARY KEY (id);


--
-- Name: distribuidora_un; Type: CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.distribuidora
    ADD CONSTRAINT distribuidora_un UNIQUE (usuario_id);


--
-- Name: estoque_distribuidora_pk; Type: CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.estoque_distribuidora
    ADD CONSTRAINT estoque_distribuidora_pk PRIMARY KEY (distribuidora_id, produto_id);


--
-- Name: estoque_vendedora_pk; Type: CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.estoque_vendedora
    ADD CONSTRAINT estoque_vendedora_pk PRIMARY KEY (vendedora_id, produto_id);


--
-- Name: fabrica_pk; Type: CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.fabrica
    ADD CONSTRAINT fabrica_pk PRIMARY KEY (id);


--
-- Name: imagem_pk; Type: CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.imagem
    ADD CONSTRAINT imagem_pk PRIMARY KEY (id);


--
-- Name: pedido_pk; Type: CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.pedido
    ADD CONSTRAINT pedido_pk PRIMARY KEY (id);


--
-- Name: pedido_produto_pk; Type: CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.pedido_produto
    ADD CONSTRAINT pedido_produto_pk PRIMARY KEY (produto_id, pedido_id);


--
-- Name: produto_pk; Type: CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.produto
    ADD CONSTRAINT produto_pk PRIMARY KEY (id);


--
-- Name: usuario_pk; Type: CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.usuario
    ADD CONSTRAINT usuario_pk PRIMARY KEY (id);


--
-- Name: vendedora_pk; Type: CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.vendedora
    ADD CONSTRAINT vendedora_pk PRIMARY KEY (id);


--
-- Name: vendedora_un; Type: CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.vendedora
    ADD CONSTRAINT vendedora_un UNIQUE (usuario_id);


--
-- Name: logged_actions_action_idx; Type: INDEX; Schema: audit; Owner: postgres
--

CREATE INDEX logged_actions_action_idx ON audit.logged_actions USING btree (action);


--
-- Name: logged_actions_action_tstamp_idx; Type: INDEX; Schema: audit; Owner: postgres
--

CREATE INDEX logged_actions_action_tstamp_idx ON audit.logged_actions USING btree (action_tstamp);


--
-- Name: logged_actions_schema_table_idx; Type: INDEX; Schema: audit; Owner: postgres
--

CREATE INDEX logged_actions_schema_table_idx ON audit.logged_actions USING btree ((((schema_name || '.'::text) || table_name)));


--
-- Name: PEDIDO_CLIENTE; Type: INDEX; Schema: wgm; Owner: postgres
--

CREATE INDEX "PEDIDO_CLIENTE" ON wgm.pedido USING btree (cliente_id);


--
-- Name: PEDIDO_DISTRIBUIDORA_PRODUTO_FAB; Type: INDEX; Schema: wgm; Owner: postgres
--

CREATE INDEX "PEDIDO_DISTRIBUIDORA_PRODUTO_FAB" ON wgm.pedido_produto USING btree (pedido_id);


--
-- Name: PEDIDO_DISTRIBUIDORA_PRODUTO_PROD; Type: INDEX; Schema: wgm; Owner: postgres
--

CREATE INDEX "PEDIDO_DISTRIBUIDORA_PRODUTO_PROD" ON wgm.pedido_produto USING btree (produto_id);


--
-- Name: PEDIDO_PRODUTO; Type: INDEX; Schema: wgm; Owner: postgres
--

CREATE INDEX "PEDIDO_PRODUTO" ON wgm.pedido USING btree (produto_id);


--
-- Name: PEDIDO_VENDEDORA; Type: INDEX; Schema: wgm; Owner: postgres
--

CREATE INDEX "PEDIDO_VENDEDORA" ON wgm.pedido USING btree (vendedora_id);


--
-- Name: tablename_audit; Type: TRIGGER; Schema: wgm; Owner: postgres
--

CREATE TRIGGER tablename_audit AFTER INSERT OR DELETE OR UPDATE ON wgm.pedido_produto FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func();


--
-- Name: tablename_audit; Type: TRIGGER; Schema: wgm; Owner: postgres
--

CREATE TRIGGER tablename_audit AFTER INSERT OR DELETE OR UPDATE ON wgm.cobranca_vendedora FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func();


--
-- Name: tablename_audit; Type: TRIGGER; Schema: wgm; Owner: postgres
--

CREATE TRIGGER tablename_audit AFTER INSERT OR DELETE OR UPDATE ON wgm.distribuidora FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func();


--
-- Name: tablename_audit; Type: TRIGGER; Schema: wgm; Owner: postgres
--

CREATE TRIGGER tablename_audit AFTER INSERT OR DELETE OR UPDATE ON wgm.estoque_distribuidora FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func();


--
-- Name: tablename_audit; Type: TRIGGER; Schema: wgm; Owner: postgres
--

CREATE TRIGGER tablename_audit AFTER INSERT OR DELETE OR UPDATE ON wgm.estoque_vendedora FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func();


--
-- Name: tablename_audit; Type: TRIGGER; Schema: wgm; Owner: postgres
--

CREATE TRIGGER tablename_audit AFTER INSERT OR DELETE OR UPDATE ON wgm.fabrica FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func();


--
-- Name: tablename_audit; Type: TRIGGER; Schema: wgm; Owner: postgres
--

CREATE TRIGGER tablename_audit AFTER INSERT OR DELETE OR UPDATE ON wgm.imagem FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func();


--
-- Name: tablename_audit; Type: TRIGGER; Schema: wgm; Owner: postgres
--

CREATE TRIGGER tablename_audit AFTER INSERT OR DELETE OR UPDATE ON wgm.pedido FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func();


--
-- Name: tablename_audit; Type: TRIGGER; Schema: wgm; Owner: postgres
--

CREATE TRIGGER tablename_audit AFTER INSERT OR DELETE OR UPDATE ON wgm.produto FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func();


--
-- Name: tablename_audit; Type: TRIGGER; Schema: wgm; Owner: postgres
--

CREATE TRIGGER tablename_audit AFTER INSERT OR DELETE OR UPDATE ON wgm.usuario FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func();


--
-- Name: tablename_audit; Type: TRIGGER; Schema: wgm; Owner: postgres
--

CREATE TRIGGER tablename_audit AFTER INSERT OR DELETE OR UPDATE ON wgm.vendedora FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func();


--
-- Name: COBRANCA_VENDEDORA_fk0; Type: FK CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.cobranca_vendedora
    ADD CONSTRAINT "COBRANCA_VENDEDORA_fk0" FOREIGN KEY (pedido_id) REFERENCES wgm.pedido(id);


--
-- Name: DISTRIBUIDORA_fk0; Type: FK CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.distribuidora
    ADD CONSTRAINT "DISTRIBUIDORA_fk0" FOREIGN KEY (usuario_id) REFERENCES wgm.usuario(id);


--
-- Name: ESTOQUE_DISTRIBUIDORA_fk0; Type: FK CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.estoque_distribuidora
    ADD CONSTRAINT "ESTOQUE_DISTRIBUIDORA_fk0" FOREIGN KEY (distribuidora_id) REFERENCES wgm.distribuidora(id);


--
-- Name: ESTOQUE_DISTRIBUIDORA_fk1; Type: FK CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.estoque_distribuidora
    ADD CONSTRAINT "ESTOQUE_DISTRIBUIDORA_fk1" FOREIGN KEY (produto_id) REFERENCES wgm.produto(id);


--
-- Name: ESTOQUE_VENDEDORA_fk0; Type: FK CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.estoque_vendedora
    ADD CONSTRAINT "ESTOQUE_VENDEDORA_fk0" FOREIGN KEY (produto_id) REFERENCES wgm.produto(id);


--
-- Name: ESTOQUE_VENDEDORA_fk1; Type: FK CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.estoque_vendedora
    ADD CONSTRAINT "ESTOQUE_VENDEDORA_fk1" FOREIGN KEY (vendedora_id) REFERENCES wgm.vendedora(id);


--
-- Name: IMAGEM_fk0; Type: FK CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.imagem
    ADD CONSTRAINT "IMAGEM_fk0" FOREIGN KEY (produto_id) REFERENCES wgm.produto(id);


--
-- Name: PEDIDO_fk0; Type: FK CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.pedido
    ADD CONSTRAINT "PEDIDO_fk0" FOREIGN KEY (vendedora_id) REFERENCES wgm.vendedora(id);


--
-- Name: PEDIDO_fk1; Type: FK CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.pedido
    ADD CONSTRAINT "PEDIDO_fk1" FOREIGN KEY (produto_id) REFERENCES wgm.produto(id);


--
-- Name: PRODUTO_fk0; Type: FK CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.produto
    ADD CONSTRAINT "PRODUTO_fk0" FOREIGN KEY (fabrica_id) REFERENCES wgm.fabrica(id);


--
-- Name: VENDEDORA_fk0; Type: FK CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.vendedora
    ADD CONSTRAINT "VENDEDORA_fk0" FOREIGN KEY (usuario_id) REFERENCES wgm.usuario(id);


--
-- Name: VENDEDORA_fk1; Type: FK CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.vendedora
    ADD CONSTRAINT "VENDEDORA_fk1" FOREIGN KEY (distribuidora_id) REFERENCES wgm.distribuidora(id);


--
-- Name: pedido_produto_pedido_fk; Type: FK CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.pedido_produto
    ADD CONSTRAINT pedido_produto_pedido_fk FOREIGN KEY (pedido_id) REFERENCES wgm.pedido(id);


--
-- Name: pedido_produto_produto_fk; Type: FK CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.pedido_produto
    ADD CONSTRAINT pedido_produto_produto_fk FOREIGN KEY (produto_id) REFERENCES wgm.produto(id);


--
-- Name: produto_fk1; Type: FK CONSTRAINT; Schema: wgm; Owner: postgres
--

ALTER TABLE ONLY wgm.produto
    ADD CONSTRAINT produto_fk1 FOREIGN KEY (distribuidora_id) REFERENCES wgm.distribuidora(id);


--
-- Name: SCHEMA audit; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA audit FROM PUBLIC;
REVOKE ALL ON SCHEMA audit FROM postgres;
GRANT ALL ON SCHEMA audit TO postgres;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- Name: SCHEMA wgm; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA wgm FROM PUBLIC;
REVOKE ALL ON SCHEMA wgm FROM postgres;
GRANT ALL ON SCHEMA wgm TO postgres;


--
-- Name: TABLE logged_actions; Type: ACL; Schema: audit; Owner: postgres
--

REVOKE ALL ON TABLE audit.logged_actions FROM PUBLIC;
REVOKE ALL ON TABLE audit.logged_actions FROM postgres;
GRANT ALL ON TABLE audit.logged_actions TO postgres;
GRANT SELECT ON TABLE audit.logged_actions TO PUBLIC;


--
-- Name: TABLE cobranca_vendedora; Type: ACL; Schema: wgm; Owner: postgres
--

REVOKE ALL ON TABLE wgm.cobranca_vendedora FROM PUBLIC;
REVOKE ALL ON TABLE wgm.cobranca_vendedora FROM postgres;
GRANT ALL ON TABLE wgm.cobranca_vendedora TO postgres;


--
-- Name: TABLE distribuidora; Type: ACL; Schema: wgm; Owner: postgres
--

REVOKE ALL ON TABLE wgm.distribuidora FROM PUBLIC;
REVOKE ALL ON TABLE wgm.distribuidora FROM postgres;
GRANT ALL ON TABLE wgm.distribuidora TO postgres;


--
-- Name: TABLE fabrica; Type: ACL; Schema: wgm; Owner: postgres
--

REVOKE ALL ON TABLE wgm.fabrica FROM PUBLIC;
REVOKE ALL ON TABLE wgm.fabrica FROM postgres;
GRANT ALL ON TABLE wgm.fabrica TO postgres;


--
-- Name: TABLE imagem; Type: ACL; Schema: wgm; Owner: postgres
--

REVOKE ALL ON TABLE wgm.imagem FROM PUBLIC;
REVOKE ALL ON TABLE wgm.imagem FROM postgres;
GRANT ALL ON TABLE wgm.imagem TO postgres;


--
-- Name: TABLE produto; Type: ACL; Schema: wgm; Owner: postgres
--

REVOKE ALL ON TABLE wgm.produto FROM PUBLIC;
REVOKE ALL ON TABLE wgm.produto FROM postgres;
GRANT ALL ON TABLE wgm.produto TO postgres;


--
-- Name: TABLE usuario; Type: ACL; Schema: wgm; Owner: postgres
--

REVOKE ALL ON TABLE wgm.usuario FROM PUBLIC;
REVOKE ALL ON TABLE wgm.usuario FROM postgres;
GRANT ALL ON TABLE wgm.usuario TO postgres;


--
-- Name: TABLE vendedora; Type: ACL; Schema: wgm; Owner: postgres
--

REVOKE ALL ON TABLE wgm.vendedora FROM PUBLIC;
REVOKE ALL ON TABLE wgm.vendedora FROM postgres;
GRANT ALL ON TABLE wgm.vendedora TO postgres;


--
-- Name: TABLE estoque_distribuidora; Type: ACL; Schema: wgm; Owner: postgres
--

REVOKE ALL ON TABLE wgm.estoque_distribuidora FROM PUBLIC;
REVOKE ALL ON TABLE wgm.estoque_distribuidora FROM postgres;
GRANT ALL ON TABLE wgm.estoque_distribuidora TO postgres;


--
-- Name: TABLE estoque_vendedora; Type: ACL; Schema: wgm; Owner: postgres
--

REVOKE ALL ON TABLE wgm.estoque_vendedora FROM PUBLIC;
REVOKE ALL ON TABLE wgm.estoque_vendedora FROM postgres;
GRANT ALL ON TABLE wgm.estoque_vendedora TO postgres;


--
-- Name: TABLE pedido; Type: ACL; Schema: wgm; Owner: postgres
--

REVOKE ALL ON TABLE wgm.pedido FROM PUBLIC;
REVOKE ALL ON TABLE wgm.pedido FROM postgres;
GRANT ALL ON TABLE wgm.pedido TO postgres;


--
-- Name: TABLE pedido_produto; Type: ACL; Schema: wgm; Owner: postgres
--

REVOKE ALL ON TABLE wgm.pedido_produto FROM PUBLIC;
REVOKE ALL ON TABLE wgm.pedido_produto FROM postgres;
GRANT ALL ON TABLE wgm.pedido_produto TO postgres;


--
-- PostgreSQL database dump complete
--

