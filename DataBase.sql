--
-- PostgreSQL database dump
--

-- Dumped from database version 15.2 (Debian 15.2-1.pgdg110+1)
-- Dumped by pg_dump version 15.1

-- Started on 2023-07-28 08:56:41 UTC

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 3633 (class 1262 OID 16384)
-- Name: test_db; Type: DATABASE; Schema: -; Owner: root
--

CREATE DATABASE test_db WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'en_US.utf8';


ALTER DATABASE test_db OWNER TO root;

\connect test_db

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 12 (class 2615 OID 18531)
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO pg_database_owner;

--
-- TOC entry 3634 (class 0 OID 0)
-- Dependencies: 12
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- TOC entry 275 (class 1255 OID 18532)
-- Name: aggiorna_Assicurazione(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION public."aggiorna_Assicurazione"() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        IF EXISTS (
            SELECT 1
            FROM "Assicurazione" JOIN "Spedizione_Premium" SP ON SP.tracking = "Assicurazione".tracking
            WHERE "Assicurazione".tracking = NEW.tracking
        ) THEN
            UPDATE public."Spedizione_Premium"
            SET costo = 7 + 7 * (SELECT percentuale_assicurata FROM "Assicurazione" WHERE tracking = NEW.tracking) * 0.01
            WHERE tracking = NEW.tracking;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public."aggiorna_Assicurazione"() OWNER TO root;

--
-- TOC entry 287 (class 1255 OID 18533)
-- Name: aggiorna_costo_spedizione_premium_servizi(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION public.aggiorna_costo_spedizione_premium_servizi() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        -- Preleva il tracking dell'elemento aggiunto o modificato in "Assicurazione"
        DECLARE
            tracking_val integer;
        BEGIN
            IF TG_OP = 'INSERT' THEN
                tracking_val := NEW.tracking;
            ELSEIF TG_OP = 'UPDATE' THEN
                tracking_val := OLD.tracking;
            END IF;

            -- Calcola il costo dei servizi in "Spedizione_Premium_Servizi"
            UPDATE public."Spedizione_Premium"
            SET costo = TRUNC((costo + COALESCE((
                SELECT SUM(costo)
                FROM public."Spedizione_Premium_Servizi"
                WHERE tracking = tracking_val
            ), 0))::numeric, 2)
            WHERE tracking = tracking_val;
        END;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.aggiorna_costo_spedizione_premium_servizi() OWNER TO root;

--
-- TOC entry 288 (class 1255 OID 18534)
-- Name: check_data_stato_spedizione_economica(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION public.check_data_stato_spedizione_economica() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM public."Stato_Spedizione_Economica"
        WHERE tracking = NEW.tracking
        AND data > NEW.data
        AND (OLD IS NULL OR (tracking, data) <> (OLD.tracking, OLD.data))
        --mi serve per evitare che se sbaglio
        -- a inserire una data ad esempio metto 18 ma in realtà era 17
        -- (il valore più grande rispetto a quella spedizione deve essere minore o uguale a 17)
        -- allora posso mettere 17, nell'update
    ) THEN
        RAISE EXCEPTION 'La nuova data deve essere maggiore della data precedente per lo stesso tracking';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_data_stato_spedizione_economica() OWNER TO root;

--
-- TOC entry 289 (class 1255 OID 18535)
-- Name: check_data_stato_spedizione_premium(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION public.check_data_stato_spedizione_premium() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM public."Stato_Spedizione_Premium"
        WHERE tracking = NEW.tracking
        AND data > NEW.data
        AND (OLD IS NULL OR (tracking, data) <> (OLD.tracking, OLD.data))
        --mi serve per evitare che se sbaglio
        -- a inserire una data ad esempio metto 18 ma in realtà era 17
        -- (il valore più grande rispetto a quella spedizione deve essere minore o uguale a 17)
        -- allora posso mettere 17, nell'update
    ) THEN
        RAISE EXCEPTION 'La nuova data deve essere maggiore o uguale alla data precedente per lo stesso tracking.';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_data_stato_spedizione_premium() OWNER TO root;

--
-- TOC entry 290 (class 1255 OID 18536)
-- Name: check_percentuale_assicurata(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION public.check_percentuale_assicurata() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.totale = true AND (NEW.percentuale_assicurata < 50 OR NEW.percentuale_assicurata > 100)  THEN
        RAISE EXCEPTION 'La percentuale assicurata deve essere maggiore di 50 e minore di 100 per l assicurazione totale.';
    ELSIF NEW.parziale = true AND (NEW.percentuale_assicurata > 30 OR NEW.percentuale_assicurata <= 0)THEN
        RAISE EXCEPTION 'La percentuale assicurata deve essere minore di 30 e maggiore di 0 per l assicurazione parziale';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_percentuale_assicurata() OWNER TO root;

--
-- TOC entry 291 (class 1255 OID 18537)
-- Name: spedizioneEconomica_servizi_costo(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION public."spedizioneEconomica_servizi_costo"() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (SELECT servizi_aggiuntivi FROM public."Spedizione_Economica" WHERE tracking = NEW.tracking) <> TRUE THEN
        RAISE EXCEPTION 'Non è possibile inserire elementi con servizi_aggiuntivi quando il flag in Spedizione_Economica non è impostato a TRUE';
    END IF;

    IF TG_OP = 'INSERT' THEN
        UPDATE public."Spedizione_Economica"
        SET costo = TRUNC((costo + NEW.costo)::numeric, 2)
        WHERE tracking = NEW.tracking AND servizi_aggiuntivi = TRUE;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public."Spedizione_Economica"
        SET costo = TRUNC((costo - OLD.costo)::numeric, 2)
        WHERE tracking = OLD.tracking;
    ELSIF TG_OP = 'UPDATE' THEN
        IF EXISTS (
            SELECT 1
            FROM public."Spedizione_Economica"
            WHERE tracking = NEW.tracking AND servizi_aggiuntivi = TRUE
        ) THEN
            UPDATE public."Spedizione_Economica"
            SET costo = TRUNC((costo - OLD.costo + NEW.costo)::numeric, 2)
            WHERE tracking = NEW.tracking;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public."spedizioneEconomica_servizi_costo"() OWNER TO root;

--
-- TOC entry 292 (class 1255 OID 18538)
-- Name: spedizionePremium_servizi_costo(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION public."spedizionePremium_servizi_costo"() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
    IF (SELECT servizi_aggiuntivi FROM public."Spedizione_Premium" WHERE tracking = NEW.tracking) <> TRUE THEN
            RAISE EXCEPTION 'Non è possibile inserire elementi con servizi_aggiuntivi quando il flag in Spedizione_Premium non è impostato a TRUE';
    END IF;
    IF TG_OP = 'INSERT' THEN
        UPDATE public."Spedizione_Premium"
        SET costo = TRUNC(("Spedizione_Premium".costo + NEW.costo)::numeric, 2)
        WHERE tracking = NEW.tracking AND servizi_aggiuntivi = TRUE;
     ELSIF TG_OP = 'DELETE' THEN
        UPDATE public."Spedizione_Premium"
        SET costo = TRUNC(("Spedizione_Premium".costo - OLD.costo)::numeric, 2)
        WHERE tracking = OLD.tracking;
    ELSIF TG_OP = 'UPDATE' THEN
        IF EXISTS (
            SELECT 1
            FROM public."Spedizione_Premium"
            WHERE tracking = NEW.tracking AND servizi_aggiuntivi = TRUE
        ) THEN
            UPDATE public."Spedizione_Premium"
            SET costo = TRUNC(("Spedizione_Premium".costo - OLD.costo + NEW.costo)::numeric, 2)
            WHERE tracking = NEW.tracking;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public."spedizionePremium_servizi_costo"() OWNER TO root;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 253 (class 1259 OID 18539)
-- Name: Assicurazione; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public."Assicurazione" (
    id integer NOT NULL,
    tracking integer NOT NULL,
    percentuale_assicurata integer,
    totale boolean,
    parziale boolean,
    CONSTRAINT check_assicurazione CHECK ((((totale = true) AND (parziale = false)) OR ((totale = false) AND (parziale = true))))
);


ALTER TABLE public."Assicurazione" OWNER TO root;

--
-- TOC entry 254 (class 1259 OID 18543)
-- Name: Dipendente; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public."Dipendente" (
    id integer NOT NULL,
    stipendio_annuale integer,
    filiale integer,
    reparto character varying,
    nome character varying,
    cognome character varying
);


ALTER TABLE public."Dipendente" OWNER TO root;

--
-- TOC entry 255 (class 1259 OID 18548)
-- Name: Filiale; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public."Filiale" (
    id integer NOT NULL,
    regione character varying,
    "città" character varying,
    via character varying,
    provincia character varying,
    numero_civico integer
);


ALTER TABLE public."Filiale" OWNER TO root;

--
-- TOC entry 256 (class 1259 OID 18553)
-- Name: Indirizzo_Utente; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public."Indirizzo_Utente" (
    regione character varying NOT NULL,
    "città" character varying NOT NULL,
    via character varying NOT NULL,
    provincia character varying NOT NULL,
    numero_civico integer NOT NULL,
    "User" character varying(16)
);


ALTER TABLE public."Indirizzo_Utente" OWNER TO root;

--
-- TOC entry 257 (class 1259 OID 18558)
-- Name: Orario; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public."Orario" (
    apertura time without time zone,
    chiusura time without time zone,
    giorno character varying NOT NULL,
    filiali integer NOT NULL,
    CONSTRAINT "Orario_giorno_check" CHECK (((giorno)::text = ANY (ARRAY[('lunedì'::character varying)::text, ('martedì'::character varying)::text, ('mercoledì'::character varying)::text, ('giovedì'::character varying)::text, ('venerdì'::character varying)::text, ('sabato'::character varying)::text, ('domenica'::character varying)::text])))
);


ALTER TABLE public."Orario" OWNER TO root;

--
-- TOC entry 258 (class 1259 OID 18564)
-- Name: Pacco_Economico; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public."Pacco_Economico" (
    id integer NOT NULL,
    valore double precision NOT NULL,
    volume double precision NOT NULL,
    peso double precision NOT NULL,
    spedizione integer NOT NULL
);


ALTER TABLE public."Pacco_Economico" OWNER TO root;

--
-- TOC entry 259 (class 1259 OID 18567)
-- Name: Pacco_Premium; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public."Pacco_Premium" (
    id integer NOT NULL,
    valore double precision NOT NULL,
    volume double precision NOT NULL,
    peso double precision NOT NULL,
    spedizione integer NOT NULL
);


ALTER TABLE public."Pacco_Premium" OWNER TO root;

--
-- TOC entry 260 (class 1259 OID 18570)
-- Name: Reparto; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public."Reparto" (
    nome character varying NOT NULL
);


ALTER TABLE public."Reparto" OWNER TO root;

--
-- TOC entry 261 (class 1259 OID 18575)
-- Name: Servizi; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public."Servizi" (
    id integer NOT NULL,
    nome character varying NOT NULL,
    costo double precision NOT NULL,
    descrizione character varying
);


ALTER TABLE public."Servizi" OWNER TO root;

--
-- TOC entry 262 (class 1259 OID 18580)
-- Name: Spedizione_Economica; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public."Spedizione_Economica" (
    tracking integer NOT NULL,
    mittente character varying(16),
    destinatario character varying(16),
    costo double precision DEFAULT 3.0 NOT NULL,
    servizi_aggiuntivi boolean DEFAULT false
);


ALTER TABLE public."Spedizione_Economica" OWNER TO root;

--
-- TOC entry 263 (class 1259 OID 18585)
-- Name: Spedizione_Economica_Servizi; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public."Spedizione_Economica_Servizi" (
    tracking integer NOT NULL,
    "Servizio" integer NOT NULL,
    nome_servizio character varying NOT NULL,
    costo double precision NOT NULL
);


ALTER TABLE public."Spedizione_Economica_Servizi" OWNER TO root;

--
-- TOC entry 264 (class 1259 OID 18590)
-- Name: Spedizione_Premium; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public."Spedizione_Premium" (
    tracking integer NOT NULL,
    mittente character varying(16) NOT NULL,
    destinatario character varying(16),
    costo double precision DEFAULT 7.0,
    servizi_aggiuntivi boolean,
    CONSTRAINT mittente_destinatario_check CHECK (((mittente)::text <> (destinatario)::text))
);


ALTER TABLE public."Spedizione_Premium" OWNER TO root;

--
-- TOC entry 265 (class 1259 OID 18595)
-- Name: Spedizione_Premium_Servizi; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public."Spedizione_Premium_Servizi" (
    tracking integer NOT NULL,
    "Servizio" integer NOT NULL,
    nome_servizio character varying NOT NULL,
    costo double precision NOT NULL
);


ALTER TABLE public."Spedizione_Premium_Servizi" OWNER TO root;

--
-- TOC entry 266 (class 1259 OID 18600)
-- Name: Stato_Spedizione_Economica; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public."Stato_Spedizione_Economica" (
    tracking integer NOT NULL,
    filiale integer NOT NULL,
    data date DEFAULT CURRENT_DATE NOT NULL
);


ALTER TABLE public."Stato_Spedizione_Economica" OWNER TO root;

--
-- TOC entry 267 (class 1259 OID 18604)
-- Name: Stato_Spedizione_Premium; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public."Stato_Spedizione_Premium" (
    tracking integer NOT NULL,
    filiale integer NOT NULL,
    data date DEFAULT CURRENT_DATE NOT NULL
);


ALTER TABLE public."Stato_Spedizione_Premium" OWNER TO root;

--
-- TOC entry 268 (class 1259 OID 18608)
-- Name: User; Type: TABLE; Schema: public; Owner: root
--

CREATE TABLE public."User" (
    codice_fiscale character varying(16) NOT NULL,
    email character varying NOT NULL,
    nome character varying NOT NULL,
    cognome character varying NOT NULL,
    numero_telefono character varying(10) NOT NULL,
    CONSTRAINT check_codice_fiscale CHECK (((codice_fiscale)::text ~* '^[A-Za-z]{6}\d{2}[A-Za-z]\d{2}[A-Za-z]\d{3}[A-Za-z]$'::text))
);


ALTER TABLE public."User" OWNER TO root;

--
-- TOC entry 269 (class 1259 OID 18614)
-- Name: numerodipendentireparto; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW public.numerodipendentireparto AS
 SELECT count(*) AS numero_di_dipendenti,
    sum("Dipendente".stipendio_annuale) AS stipendi,
    "Dipendente".reparto,
    "Dipendente".filiale
   FROM public."Dipendente"
  GROUP BY "Dipendente".filiale, "Dipendente".reparto;


ALTER TABLE public.numerodipendentireparto OWNER TO root;

--
-- TOC entry 270 (class 1259 OID 18618)
-- Name: numeromaxdipendentireparto; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW public.numeromaxdipendentireparto AS
 SELECT max(numeromaxdipendentireparto.cn) AS numero_di_dipendenti,
    numeromaxdipendentireparto.reparto,
    numeromaxdipendentireparto.filiale
   FROM ( SELECT count(*) AS cn,
            "Dipendente".reparto,
            "Dipendente".filiale
           FROM public."Dipendente"
          GROUP BY "Dipendente".filiale, "Dipendente".reparto) numeromaxdipendentireparto
  GROUP BY numeromaxdipendentireparto.filiale, numeromaxdipendentireparto.reparto;


ALTER TABLE public.numeromaxdipendentireparto OWNER TO root;

--
-- TOC entry 271 (class 1259 OID 18622)
-- Name: numeroserviziperognitracking; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW public.numeroserviziperognitracking AS
 SELECT count(*) AS numerodiservizi,
    "Spedizione_Premium_Servizi".tracking
   FROM public."Spedizione_Premium_Servizi"
  GROUP BY "Spedizione_Premium_Servizi".tracking;


ALTER TABLE public.numeroserviziperognitracking OWNER TO root;

--
-- TOC entry 272 (class 1259 OID 18626)
-- Name: statospedizione_economica_costo; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW public.statospedizione_economica_costo AS
 SELECT trunc((avg(se.costo))::numeric, 2) AS costomedio,
    "Stato_Spedizione_Economica".filiale
   FROM (public."Stato_Spedizione_Economica"
     JOIN public."Spedizione_Economica" se ON ((se.tracking = "Stato_Spedizione_Economica".tracking)))
  GROUP BY "Stato_Spedizione_Economica".filiale;


ALTER TABLE public.statospedizione_economica_costo OWNER TO root;

--
-- TOC entry 273 (class 1259 OID 18630)
-- Name: statospedizione_premium_costo; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW public.statospedizione_premium_costo AS
 SELECT trunc((avg(sp.costo))::numeric, 2) AS costomedio,
    ssp.filiale
   FROM (public."Stato_Spedizione_Premium" ssp
     JOIN public."Spedizione_Premium" sp ON ((sp.tracking = ssp.tracking)))
  GROUP BY ssp.filiale;


ALTER TABLE public.statospedizione_premium_costo OWNER TO root;

--
-- TOC entry 274 (class 1259 OID 18794)
-- Name: usermax; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW public.usermax AS
 SELECT max(GREATEST("Pacco_Economico".valore, "Pacco_Premium".valore)) AS m,
    "User".codice_fiscale
   FROM ((((public."User"
     JOIN public."Spedizione_Economica" ON ((("User".codice_fiscale)::text = ("Spedizione_Economica".mittente)::text)))
     JOIN public."Spedizione_Premium" ON ((("User".codice_fiscale)::text = ("Spedizione_Premium".mittente)::text)))
     JOIN public."Pacco_Economico" ON (("Spedizione_Economica".tracking = "Pacco_Economico".spedizione)))
     JOIN public."Pacco_Premium" ON (("Spedizione_Premium".tracking = "Pacco_Premium".spedizione)))
  GROUP BY "User".codice_fiscale;


ALTER TABLE public.usermax OWNER TO root;

--
-- TOC entry 3612 (class 0 OID 18539)
-- Dependencies: 253
-- Data for Name: Assicurazione; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO public."Assicurazione" VALUES (4, 4, 92, true, false);
INSERT INTO public."Assicurazione" VALUES (21, 21, 30, false, true);
INSERT INTO public."Assicurazione" VALUES (8, 8, 85, true, false);
INSERT INTO public."Assicurazione" VALUES (20, 20, 10, false, true);
INSERT INTO public."Assicurazione" VALUES (16, 16, 18, false, true);
INSERT INTO public."Assicurazione" VALUES (17, 17, 3, false, true);
INSERT INTO public."Assicurazione" VALUES (22, 22, 60, true, false);
INSERT INTO public."Assicurazione" VALUES (7, 7, 72, true, false);
INSERT INTO public."Assicurazione" VALUES (2, 2, 54, true, false);
INSERT INTO public."Assicurazione" VALUES (13, 13, 14, false, true);
INSERT INTO public."Assicurazione" VALUES (18, 18, 1, false, true);
INSERT INTO public."Assicurazione" VALUES (23, 23, 80, true, false);
INSERT INTO public."Assicurazione" VALUES (5, 5, 100, true, false);
INSERT INTO public."Assicurazione" VALUES (10, 10, 6, false, true);
INSERT INTO public."Assicurazione" VALUES (6, 6, 78, true, false);
INSERT INTO public."Assicurazione" VALUES (12, 12, 1, false, true);
INSERT INTO public."Assicurazione" VALUES (11, 11, 23, false, true);
INSERT INTO public."Assicurazione" VALUES (3, 3, 86, true, false);
INSERT INTO public."Assicurazione" VALUES (9, 9, 29, false, true);
INSERT INTO public."Assicurazione" VALUES (19, 19, 20, false, true);
INSERT INTO public."Assicurazione" VALUES (14, 14, 9, false, true);
INSERT INTO public."Assicurazione" VALUES (100, 100, 84, true, false);
INSERT INTO public."Assicurazione" VALUES (46, 46, 68, true, false);
INSERT INTO public."Assicurazione" VALUES (591, 591, 5, false, true);
INSERT INTO public."Assicurazione" VALUES (651, 651, 28, false, true);
INSERT INTO public."Assicurazione" VALUES (629, 629, 23, false, true);
INSERT INTO public."Assicurazione" VALUES (475, 475, 26, false, true);
INSERT INTO public."Assicurazione" VALUES (665, 665, 7, false, true);
INSERT INTO public."Assicurazione" VALUES (675, 675, 3, false, true);
INSERT INTO public."Assicurazione" VALUES (660, 660, 28, false, true);
INSERT INTO public."Assicurazione" VALUES (509, 509, 6, false, true);
INSERT INTO public."Assicurazione" VALUES (536, 536, 23, false, true);
INSERT INTO public."Assicurazione" VALUES (510, 510, 20, false, true);
INSERT INTO public."Assicurazione" VALUES (491, 491, 15, false, true);
INSERT INTO public."Assicurazione" VALUES (490, 490, 15, false, true);
INSERT INTO public."Assicurazione" VALUES (601, 601, 27, false, true);
INSERT INTO public."Assicurazione" VALUES (604, 604, 8, false, true);
INSERT INTO public."Assicurazione" VALUES (619, 619, 25, false, true);
INSERT INTO public."Assicurazione" VALUES (656, 656, 24, false, true);
INSERT INTO public."Assicurazione" VALUES (588, 588, 1, false, true);
INSERT INTO public."Assicurazione" VALUES (544, 544, 30, false, true);
INSERT INTO public."Assicurazione" VALUES (643, 643, 12, false, true);
INSERT INTO public."Assicurazione" VALUES (537, 537, 21, false, true);
INSERT INTO public."Assicurazione" VALUES (247, 247, 92, true, false);
INSERT INTO public."Assicurazione" VALUES (310, 310, 54, true, false);
INSERT INTO public."Assicurazione" VALUES (451, 451, 82, true, false);
INSERT INTO public."Assicurazione" VALUES (418, 418, 68, true, false);
INSERT INTO public."Assicurazione" VALUES (221, 221, 83, true, false);
INSERT INTO public."Assicurazione" VALUES (237, 237, 78, true, false);
INSERT INTO public."Assicurazione" VALUES (83, 83, 62, true, false);
INSERT INTO public."Assicurazione" VALUES (402, 402, 100, true, false);
INSERT INTO public."Assicurazione" VALUES (353, 353, 88, true, false);
INSERT INTO public."Assicurazione" VALUES (330, 330, 91, true, false);
INSERT INTO public."Assicurazione" VALUES (205, 205, 64, true, false);
INSERT INTO public."Assicurazione" VALUES (254, 254, 89, true, false);
INSERT INTO public."Assicurazione" VALUES (352, 352, 98, true, false);
INSERT INTO public."Assicurazione" VALUES (124, 124, 60, true, false);
INSERT INTO public."Assicurazione" VALUES (110, 110, 68, true, false);
INSERT INTO public."Assicurazione" VALUES (311, 311, 53, true, false);
INSERT INTO public."Assicurazione" VALUES (389, 389, 79, true, false);
INSERT INTO public."Assicurazione" VALUES (444, 444, 85, true, false);
INSERT INTO public."Assicurazione" VALUES (329, 329, 70, true, false);
INSERT INTO public."Assicurazione" VALUES (305, 305, 94, true, false);
INSERT INTO public."Assicurazione" VALUES (351, 351, 72, true, false);
INSERT INTO public."Assicurazione" VALUES (80, 80, 73, true, false);
INSERT INTO public."Assicurazione" VALUES (278, 278, 91, true, false);
INSERT INTO public."Assicurazione" VALUES (420, 420, 52, true, false);
INSERT INTO public."Assicurazione" VALUES (296, 296, 69, true, false);
INSERT INTO public."Assicurazione" VALUES (29, 29, 80, true, false);
INSERT INTO public."Assicurazione" VALUES (189, 189, 72, true, false);
INSERT INTO public."Assicurazione" VALUES (325, 325, 63, true, false);
INSERT INTO public."Assicurazione" VALUES (172, 172, 78, true, false);
INSERT INTO public."Assicurazione" VALUES (357, 357, 74, true, false);
INSERT INTO public."Assicurazione" VALUES (285, 285, 60, true, false);
INSERT INTO public."Assicurazione" VALUES (218, 218, 52, true, false);
INSERT INTO public."Assicurazione" VALUES (26, 26, 84, true, false);
INSERT INTO public."Assicurazione" VALUES (364, 364, 62, true, false);
INSERT INTO public."Assicurazione" VALUES (446, 446, 79, true, false);
INSERT INTO public."Assicurazione" VALUES (225, 225, 77, true, false);
INSERT INTO public."Assicurazione" VALUES (250, 250, 58, true, false);
INSERT INTO public."Assicurazione" VALUES (121, 121, 72, true, false);
INSERT INTO public."Assicurazione" VALUES (103, 103, 64, true, false);
INSERT INTO public."Assicurazione" VALUES (324, 324, 85, true, false);
INSERT INTO public."Assicurazione" VALUES (249, 249, 87, true, false);
INSERT INTO public."Assicurazione" VALUES (168, 168, 93, true, false);
INSERT INTO public."Assicurazione" VALUES (111, 111, 53, true, false);
INSERT INTO public."Assicurazione" VALUES (313, 313, 55, true, false);
INSERT INTO public."Assicurazione" VALUES (217, 217, 100, true, false);
INSERT INTO public."Assicurazione" VALUES (438, 438, 53, true, false);
INSERT INTO public."Assicurazione" VALUES (417, 417, 54, true, false);
INSERT INTO public."Assicurazione" VALUES (92, 92, 76, true, false);
INSERT INTO public."Assicurazione" VALUES (345, 345, 90, true, false);
INSERT INTO public."Assicurazione" VALUES (317, 317, 85, true, false);
INSERT INTO public."Assicurazione" VALUES (363, 363, 52, true, false);
INSERT INTO public."Assicurazione" VALUES (467, 467, 73, true, false);
INSERT INTO public."Assicurazione" VALUES (318, 318, 65, true, false);
INSERT INTO public."Assicurazione" VALUES (39, 39, 91, true, false);
INSERT INTO public."Assicurazione" VALUES (146, 146, 63, true, false);
INSERT INTO public."Assicurazione" VALUES (140, 140, 71, true, false);
INSERT INTO public."Assicurazione" VALUES (361, 361, 61, true, false);
INSERT INTO public."Assicurazione" VALUES (37, 37, 62, true, false);
INSERT INTO public."Assicurazione" VALUES (196, 196, 96, true, false);
INSERT INTO public."Assicurazione" VALUES (282, 282, 52, true, false);
INSERT INTO public."Assicurazione" VALUES (130, 130, 71, true, false);
INSERT INTO public."Assicurazione" VALUES (315, 315, 55, true, false);
INSERT INTO public."Assicurazione" VALUES (109, 109, 55, true, false);
INSERT INTO public."Assicurazione" VALUES (270, 270, 90, true, false);
INSERT INTO public."Assicurazione" VALUES (443, 443, 98, true, false);
INSERT INTO public."Assicurazione" VALUES (239, 239, 92, true, false);
INSERT INTO public."Assicurazione" VALUES (91, 91, 51, true, false);
INSERT INTO public."Assicurazione" VALUES (27, 27, 83, true, false);
INSERT INTO public."Assicurazione" VALUES (223, 223, 85, true, false);
INSERT INTO public."Assicurazione" VALUES (234, 234, 56, true, false);
INSERT INTO public."Assicurazione" VALUES (316, 316, 63, true, false);
INSERT INTO public."Assicurazione" VALUES (339, 339, 94, true, false);
INSERT INTO public."Assicurazione" VALUES (449, 449, 88, true, false);
INSERT INTO public."Assicurazione" VALUES (70, 70, 85, true, false);
INSERT INTO public."Assicurazione" VALUES (358, 358, 64, true, false);
INSERT INTO public."Assicurazione" VALUES (69, 69, 90, true, false);
INSERT INTO public."Assicurazione" VALUES (432, 432, 75, true, false);
INSERT INTO public."Assicurazione" VALUES (383, 383, 50, true, false);
INSERT INTO public."Assicurazione" VALUES (252, 252, 96, true, false);
INSERT INTO public."Assicurazione" VALUES (131, 131, 53, true, false);
INSERT INTO public."Assicurazione" VALUES (380, 380, 50, true, false);
INSERT INTO public."Assicurazione" VALUES (462, 462, 91, true, false);
INSERT INTO public."Assicurazione" VALUES (440, 440, 98, true, false);
INSERT INTO public."Assicurazione" VALUES (123, 123, 59, true, false);
INSERT INTO public."Assicurazione" VALUES (51, 51, 66, true, false);
INSERT INTO public."Assicurazione" VALUES (167, 167, 79, true, false);
INSERT INTO public."Assicurazione" VALUES (141, 141, 81, true, false);
INSERT INTO public."Assicurazione" VALUES (362, 362, 72, true, false);
INSERT INTO public."Assicurazione" VALUES (171, 171, 72, true, false);
INSERT INTO public."Assicurazione" VALUES (312, 312, 63, true, false);
INSERT INTO public."Assicurazione" VALUES (289, 289, 78, true, false);
INSERT INTO public."Assicurazione" VALUES (346, 346, 84, true, false);
INSERT INTO public."Assicurazione" VALUES (265, 265, 73, true, false);
INSERT INTO public."Assicurazione" VALUES (290, 290, 84, true, false);
INSERT INTO public."Assicurazione" VALUES (429, 429, 53, true, false);
INSERT INTO public."Assicurazione" VALUES (448, 448, 95, true, false);
INSERT INTO public."Assicurazione" VALUES (413, 413, 51, true, false);
INSERT INTO public."Assicurazione" VALUES (213, 213, 71, true, false);
INSERT INTO public."Assicurazione" VALUES (307, 307, 75, true, false);
INSERT INTO public."Assicurazione" VALUES (387, 387, 54, true, false);
INSERT INTO public."Assicurazione" VALUES (456, 456, 75, true, false);
INSERT INTO public."Assicurazione" VALUES (274, 274, 96, true, false);
INSERT INTO public."Assicurazione" VALUES (108, 108, 62, true, false);
INSERT INTO public."Assicurazione" VALUES (216, 216, 81, true, false);
INSERT INTO public."Assicurazione" VALUES (436, 436, 87, true, false);
INSERT INTO public."Assicurazione" VALUES (211, 211, 95, true, false);
INSERT INTO public."Assicurazione" VALUES (406, 406, 58, true, false);
INSERT INTO public."Assicurazione" VALUES (45, 45, 85, true, false);
INSERT INTO public."Assicurazione" VALUES (367, 367, 92, true, false);
INSERT INTO public."Assicurazione" VALUES (360, 360, 97, true, false);
INSERT INTO public."Assicurazione" VALUES (122, 122, 89, true, false);
INSERT INTO public."Assicurazione" VALUES (191, 191, 52, true, false);
INSERT INTO public."Assicurazione" VALUES (242, 242, 64, true, false);
INSERT INTO public."Assicurazione" VALUES (157, 157, 68, true, false);
INSERT INTO public."Assicurazione" VALUES (405, 405, 82, true, false);
INSERT INTO public."Assicurazione" VALUES (61, 61, 98, true, false);
INSERT INTO public."Assicurazione" VALUES (384, 384, 56, true, false);
INSERT INTO public."Assicurazione" VALUES (41, 41, 56, true, false);
INSERT INTO public."Assicurazione" VALUES (396, 396, 56, true, false);
INSERT INTO public."Assicurazione" VALUES (144, 144, 76, true, false);
INSERT INTO public."Assicurazione" VALUES (376, 376, 83, true, false);
INSERT INTO public."Assicurazione" VALUES (410, 410, 54, true, false);
INSERT INTO public."Assicurazione" VALUES (169, 169, 78, true, false);
INSERT INTO public."Assicurazione" VALUES (382, 382, 76, true, false);
INSERT INTO public."Assicurazione" VALUES (473, 473, 58, true, false);
INSERT INTO public."Assicurazione" VALUES (138, 138, 77, true, false);
INSERT INTO public."Assicurazione" VALUES (170, 170, 59, true, false);
INSERT INTO public."Assicurazione" VALUES (165, 165, 68, true, false);
INSERT INTO public."Assicurazione" VALUES (404, 404, 83, true, false);
INSERT INTO public."Assicurazione" VALUES (190, 190, 59, true, false);
INSERT INTO public."Assicurazione" VALUES (291, 291, 66, true, false);
INSERT INTO public."Assicurazione" VALUES (321, 321, 65, true, false);
INSERT INTO public."Assicurazione" VALUES (132, 132, 82, true, false);
INSERT INTO public."Assicurazione" VALUES (34, 34, 73, true, false);
INSERT INTO public."Assicurazione" VALUES (474, 474, 53, true, false);
INSERT INTO public."Assicurazione" VALUES (96, 96, 61, true, false);
INSERT INTO public."Assicurazione" VALUES (151, 151, 54, true, false);
INSERT INTO public."Assicurazione" VALUES (64, 64, 73, true, false);
INSERT INTO public."Assicurazione" VALUES (178, 178, 92, true, false);
INSERT INTO public."Assicurazione" VALUES (272, 272, 54, true, false);
INSERT INTO public."Assicurazione" VALUES (336, 336, 92, true, false);
INSERT INTO public."Assicurazione" VALUES (466, 466, 86, true, false);
INSERT INTO public."Assicurazione" VALUES (143, 143, 61, true, false);
INSERT INTO public."Assicurazione" VALUES (201, 201, 93, true, false);
INSERT INTO public."Assicurazione" VALUES (331, 331, 80, true, false);
INSERT INTO public."Assicurazione" VALUES (293, 293, 68, true, false);
INSERT INTO public."Assicurazione" VALUES (240, 240, 88, true, false);
INSERT INTO public."Assicurazione" VALUES (460, 460, 57, true, false);
INSERT INTO public."Assicurazione" VALUES (295, 295, 53, true, false);
INSERT INTO public."Assicurazione" VALUES (368, 368, 92, true, false);
INSERT INTO public."Assicurazione" VALUES (359, 359, 78, true, false);
INSERT INTO public."Assicurazione" VALUES (428, 428, 50, true, false);
INSERT INTO public."Assicurazione" VALUES (106, 106, 84, true, false);
INSERT INTO public."Assicurazione" VALUES (90, 90, 87, true, false);
INSERT INTO public."Assicurazione" VALUES (309, 309, 50, true, false);
INSERT INTO public."Assicurazione" VALUES (375, 375, 85, true, false);
INSERT INTO public."Assicurazione" VALUES (372, 372, 51, true, false);
INSERT INTO public."Assicurazione" VALUES (427, 427, 62, true, false);
INSERT INTO public."Assicurazione" VALUES (38, 38, 96, true, false);
INSERT INTO public."Assicurazione" VALUES (119, 119, 93, true, false);
INSERT INTO public."Assicurazione" VALUES (284, 284, 93, true, false);
INSERT INTO public."Assicurazione" VALUES (160, 160, 99, true, false);
INSERT INTO public."Assicurazione" VALUES (327, 327, 55, true, false);
INSERT INTO public."Assicurazione" VALUES (268, 268, 87, true, false);
INSERT INTO public."Assicurazione" VALUES (248, 248, 59, true, false);
INSERT INTO public."Assicurazione" VALUES (236, 236, 72, true, false);
INSERT INTO public."Assicurazione" VALUES (85, 85, 61, true, false);
INSERT INTO public."Assicurazione" VALUES (25, 25, 90, true, false);
INSERT INTO public."Assicurazione" VALUES (74, 74, 68, true, false);
INSERT INTO public."Assicurazione" VALUES (35, 35, 94, true, false);
INSERT INTO public."Assicurazione" VALUES (439, 439, 94, true, false);
INSERT INTO public."Assicurazione" VALUES (385, 385, 81, true, false);
INSERT INTO public."Assicurazione" VALUES (235, 235, 99, true, false);
INSERT INTO public."Assicurazione" VALUES (426, 426, 100, true, false);
INSERT INTO public."Assicurazione" VALUES (87, 87, 52, true, false);
INSERT INTO public."Assicurazione" VALUES (343, 343, 95, true, false);
INSERT INTO public."Assicurazione" VALUES (79, 79, 97, true, false);
INSERT INTO public."Assicurazione" VALUES (390, 390, 58, true, false);
INSERT INTO public."Assicurazione" VALUES (332, 332, 57, true, false);
INSERT INTO public."Assicurazione" VALUES (342, 342, 96, true, false);
INSERT INTO public."Assicurazione" VALUES (94, 94, 95, true, false);
INSERT INTO public."Assicurazione" VALUES (36, 36, 73, true, false);
INSERT INTO public."Assicurazione" VALUES (105, 105, 96, true, false);
INSERT INTO public."Assicurazione" VALUES (258, 258, 99, true, false);
INSERT INTO public."Assicurazione" VALUES (48, 48, 98, true, false);
INSERT INTO public."Assicurazione" VALUES (129, 129, 85, true, false);
INSERT INTO public."Assicurazione" VALUES (31, 31, 71, true, false);
INSERT INTO public."Assicurazione" VALUES (319, 319, 84, true, false);
INSERT INTO public."Assicurazione" VALUES (337, 337, 75, true, false);
INSERT INTO public."Assicurazione" VALUES (371, 371, 76, true, false);
INSERT INTO public."Assicurazione" VALUES (210, 210, 66, true, false);
INSERT INTO public."Assicurazione" VALUES (461, 461, 70, true, false);
INSERT INTO public."Assicurazione" VALUES (423, 423, 74, true, false);
INSERT INTO public."Assicurazione" VALUES (431, 431, 69, true, false);
INSERT INTO public."Assicurazione" VALUES (215, 215, 100, true, false);
INSERT INTO public."Assicurazione" VALUES (366, 366, 90, true, false);
INSERT INTO public."Assicurazione" VALUES (53, 53, 50, true, false);
INSERT INTO public."Assicurazione" VALUES (115, 115, 57, true, false);
INSERT INTO public."Assicurazione" VALUES (259, 259, 72, true, false);
INSERT INTO public."Assicurazione" VALUES (411, 411, 86, true, false);
INSERT INTO public."Assicurazione" VALUES (356, 356, 93, true, false);
INSERT INTO public."Assicurazione" VALUES (454, 454, 57, true, false);
INSERT INTO public."Assicurazione" VALUES (176, 176, 63, true, false);
INSERT INTO public."Assicurazione" VALUES (116, 116, 54, true, false);
INSERT INTO public."Assicurazione" VALUES (59, 59, 86, true, false);
INSERT INTO public."Assicurazione" VALUES (377, 377, 92, true, false);
INSERT INTO public."Assicurazione" VALUES (378, 378, 83, true, false);
INSERT INTO public."Assicurazione" VALUES (301, 301, 81, true, false);
INSERT INTO public."Assicurazione" VALUES (433, 433, 57, true, false);
INSERT INTO public."Assicurazione" VALUES (464, 464, 67, true, false);
INSERT INTO public."Assicurazione" VALUES (118, 118, 80, true, false);
INSERT INTO public."Assicurazione" VALUES (104, 104, 92, true, false);
INSERT INTO public."Assicurazione" VALUES (56, 56, 92, true, false);
INSERT INTO public."Assicurazione" VALUES (226, 226, 51, true, false);
INSERT INTO public."Assicurazione" VALUES (243, 243, 59, true, false);
INSERT INTO public."Assicurazione" VALUES (280, 280, 96, true, false);
INSERT INTO public."Assicurazione" VALUES (260, 260, 78, true, false);
INSERT INTO public."Assicurazione" VALUES (50, 50, 68, true, false);
INSERT INTO public."Assicurazione" VALUES (114, 114, 73, true, false);
INSERT INTO public."Assicurazione" VALUES (421, 421, 80, true, false);
INSERT INTO public."Assicurazione" VALUES (44, 44, 72, true, false);
INSERT INTO public."Assicurazione" VALUES (397, 397, 97, true, false);
INSERT INTO public."Assicurazione" VALUES (400, 400, 58, true, false);
INSERT INTO public."Assicurazione" VALUES (416, 416, 54, true, false);
INSERT INTO public."Assicurazione" VALUES (392, 392, 58, true, false);
INSERT INTO public."Assicurazione" VALUES (78, 78, 78, true, false);
INSERT INTO public."Assicurazione" VALUES (194, 194, 66, true, false);
INSERT INTO public."Assicurazione" VALUES (186, 186, 66, true, false);
INSERT INTO public."Assicurazione" VALUES (434, 434, 83, true, false);
INSERT INTO public."Assicurazione" VALUES (40, 40, 52, true, false);
INSERT INTO public."Assicurazione" VALUES (273, 273, 62, true, false);
INSERT INTO public."Assicurazione" VALUES (370, 370, 92, true, false);
INSERT INTO public."Assicurazione" VALUES (447, 447, 96, true, false);
INSERT INTO public."Assicurazione" VALUES (112, 112, 73, true, false);
INSERT INTO public."Assicurazione" VALUES (435, 435, 90, true, false);
INSERT INTO public."Assicurazione" VALUES (182, 182, 69, true, false);
INSERT INTO public."Assicurazione" VALUES (88, 88, 98, true, false);
INSERT INTO public."Assicurazione" VALUES (89, 89, 60, true, false);
INSERT INTO public."Assicurazione" VALUES (198, 198, 84, true, false);
INSERT INTO public."Assicurazione" VALUES (233, 233, 90, true, false);
INSERT INTO public."Assicurazione" VALUES (469, 469, 97, true, false);
INSERT INTO public."Assicurazione" VALUES (67, 67, 86, true, false);
INSERT INTO public."Assicurazione" VALUES (322, 322, 74, true, false);
INSERT INTO public."Assicurazione" VALUES (180, 180, 57, true, false);
INSERT INTO public."Assicurazione" VALUES (66, 66, 77, true, false);
INSERT INTO public."Assicurazione" VALUES (471, 471, 68, true, false);
INSERT INTO public."Assicurazione" VALUES (229, 229, 86, true, false);
INSERT INTO public."Assicurazione" VALUES (77, 77, 59, true, false);
INSERT INTO public."Assicurazione" VALUES (232, 232, 65, true, false);
INSERT INTO public."Assicurazione" VALUES (261, 261, 73, true, false);
INSERT INTO public."Assicurazione" VALUES (412, 412, 98, true, false);
INSERT INTO public."Assicurazione" VALUES (93, 93, 94, true, false);
INSERT INTO public."Assicurazione" VALUES (347, 347, 76, true, false);
INSERT INTO public."Assicurazione" VALUES (281, 281, 79, true, false);
INSERT INTO public."Assicurazione" VALUES (68, 68, 55, true, false);
INSERT INTO public."Assicurazione" VALUES (187, 187, 84, true, false);
INSERT INTO public."Assicurazione" VALUES (148, 148, 100, true, false);
INSERT INTO public."Assicurazione" VALUES (349, 349, 99, true, false);
INSERT INTO public."Assicurazione" VALUES (266, 266, 98, true, false);
INSERT INTO public."Assicurazione" VALUES (323, 323, 72, true, false);
INSERT INTO public."Assicurazione" VALUES (147, 147, 93, true, false);
INSERT INTO public."Assicurazione" VALUES (188, 188, 50, true, false);
INSERT INTO public."Assicurazione" VALUES (300, 300, 56, true, false);
INSERT INTO public."Assicurazione" VALUES (54, 54, 80, true, false);
INSERT INTO public."Assicurazione" VALUES (207, 207, 77, true, false);
INSERT INTO public."Assicurazione" VALUES (173, 173, 88, true, false);
INSERT INTO public."Assicurazione" VALUES (137, 137, 62, true, false);
INSERT INTO public."Assicurazione" VALUES (320, 320, 78, true, false);
INSERT INTO public."Assicurazione" VALUES (422, 422, 57, true, false);
INSERT INTO public."Assicurazione" VALUES (195, 195, 51, true, false);
INSERT INTO public."Assicurazione" VALUES (369, 369, 67, true, false);
INSERT INTO public."Assicurazione" VALUES (470, 470, 79, true, false);
INSERT INTO public."Assicurazione" VALUES (334, 334, 97, true, false);
INSERT INTO public."Assicurazione" VALUES (208, 208, 93, true, false);
INSERT INTO public."Assicurazione" VALUES (156, 156, 100, true, false);
INSERT INTO public."Assicurazione" VALUES (292, 292, 56, true, false);
INSERT INTO public."Assicurazione" VALUES (463, 463, 62, true, false);
INSERT INTO public."Assicurazione" VALUES (287, 287, 86, true, false);
INSERT INTO public."Assicurazione" VALUES (398, 398, 76, true, false);
INSERT INTO public."Assicurazione" VALUES (245, 245, 97, true, false);
INSERT INTO public."Assicurazione" VALUES (55, 55, 54, true, false);
INSERT INTO public."Assicurazione" VALUES (275, 275, 56, true, false);
INSERT INTO public."Assicurazione" VALUES (212, 212, 93, true, false);
INSERT INTO public."Assicurazione" VALUES (379, 379, 89, true, false);
INSERT INTO public."Assicurazione" VALUES (394, 394, 82, true, false);
INSERT INTO public."Assicurazione" VALUES (125, 125, 66, true, false);
INSERT INTO public."Assicurazione" VALUES (175, 175, 65, true, false);
INSERT INTO public."Assicurazione" VALUES (209, 209, 71, true, false);
INSERT INTO public."Assicurazione" VALUES (264, 264, 94, true, false);
INSERT INTO public."Assicurazione" VALUES (155, 155, 65, true, false);
INSERT INTO public."Assicurazione" VALUES (76, 76, 96, true, false);
INSERT INTO public."Assicurazione" VALUES (214, 214, 78, true, false);
INSERT INTO public."Assicurazione" VALUES (199, 199, 62, true, false);
INSERT INTO public."Assicurazione" VALUES (335, 335, 92, true, false);
INSERT INTO public."Assicurazione" VALUES (134, 134, 59, true, false);
INSERT INTO public."Assicurazione" VALUES (409, 409, 63, true, false);
INSERT INTO public."Assicurazione" VALUES (86, 86, 98, true, false);
INSERT INTO public."Assicurazione" VALUES (98, 98, 72, true, false);
INSERT INTO public."Assicurazione" VALUES (139, 139, 92, true, false);
INSERT INTO public."Assicurazione" VALUES (57, 57, 70, true, false);
INSERT INTO public."Assicurazione" VALUES (386, 386, 67, true, false);
INSERT INTO public."Assicurazione" VALUES (163, 163, 98, true, false);
INSERT INTO public."Assicurazione" VALUES (82, 82, 66, true, false);
INSERT INTO public."Assicurazione" VALUES (271, 271, 56, true, false);
INSERT INTO public."Assicurazione" VALUES (297, 297, 61, true, false);
INSERT INTO public."Assicurazione" VALUES (399, 399, 78, true, false);
INSERT INTO public."Assicurazione" VALUES (238, 238, 95, true, false);
INSERT INTO public."Assicurazione" VALUES (453, 453, 88, true, false);
INSERT INTO public."Assicurazione" VALUES (120, 120, 77, true, false);
INSERT INTO public."Assicurazione" VALUES (302, 302, 76, true, false);
INSERT INTO public."Assicurazione" VALUES (126, 126, 66, true, false);
INSERT INTO public."Assicurazione" VALUES (244, 244, 71, true, false);
INSERT INTO public."Assicurazione" VALUES (299, 299, 75, true, false);
INSERT INTO public."Assicurazione" VALUES (128, 128, 76, true, false);
INSERT INTO public."Assicurazione" VALUES (28, 28, 54, true, false);
INSERT INTO public."Assicurazione" VALUES (49, 49, 95, true, false);
INSERT INTO public."Assicurazione" VALUES (32, 32, 71, true, false);
INSERT INTO public."Assicurazione" VALUES (441, 441, 91, true, false);
INSERT INTO public."Assicurazione" VALUES (348, 348, 69, true, false);
INSERT INTO public."Assicurazione" VALUES (149, 149, 68, true, false);
INSERT INTO public."Assicurazione" VALUES (200, 200, 61, true, false);
INSERT INTO public."Assicurazione" VALUES (153, 153, 54, true, false);
INSERT INTO public."Assicurazione" VALUES (228, 228, 54, true, false);
INSERT INTO public."Assicurazione" VALUES (303, 303, 55, true, false);
INSERT INTO public."Assicurazione" VALUES (391, 391, 68, true, false);
INSERT INTO public."Assicurazione" VALUES (468, 468, 85, true, false);
INSERT INTO public."Assicurazione" VALUES (326, 326, 98, true, false);
INSERT INTO public."Assicurazione" VALUES (442, 442, 99, true, false);
INSERT INTO public."Assicurazione" VALUES (415, 415, 60, true, false);
INSERT INTO public."Assicurazione" VALUES (113, 113, 55, true, false);
INSERT INTO public."Assicurazione" VALUES (33, 33, 87, true, false);
INSERT INTO public."Assicurazione" VALUES (133, 133, 60, true, false);
INSERT INTO public."Assicurazione" VALUES (181, 181, 86, true, false);
INSERT INTO public."Assicurazione" VALUES (162, 162, 93, true, false);
INSERT INTO public."Assicurazione" VALUES (99, 99, 91, true, false);
INSERT INTO public."Assicurazione" VALUES (185, 185, 53, true, false);
INSERT INTO public."Assicurazione" VALUES (279, 279, 100, true, false);
INSERT INTO public."Assicurazione" VALUES (102, 102, 81, true, false);
INSERT INTO public."Assicurazione" VALUES (457, 457, 89, true, false);
INSERT INTO public."Assicurazione" VALUES (73, 73, 50, true, false);
INSERT INTO public."Assicurazione" VALUES (127, 127, 86, true, false);
INSERT INTO public."Assicurazione" VALUES (202, 202, 55, true, false);
INSERT INTO public."Assicurazione" VALUES (328, 328, 80, true, false);
INSERT INTO public."Assicurazione" VALUES (224, 224, 58, true, false);
INSERT INTO public."Assicurazione" VALUES (430, 430, 94, true, false);
INSERT INTO public."Assicurazione" VALUES (308, 308, 60, true, false);
INSERT INTO public."Assicurazione" VALUES (403, 403, 98, true, false);
INSERT INTO public."Assicurazione" VALUES (58, 58, 69, true, false);
INSERT INTO public."Assicurazione" VALUES (450, 450, 60, true, false);
INSERT INTO public."Assicurazione" VALUES (197, 197, 74, true, false);
INSERT INTO public."Assicurazione" VALUES (161, 161, 58, true, false);
INSERT INTO public."Assicurazione" VALUES (395, 395, 52, true, false);
INSERT INTO public."Assicurazione" VALUES (257, 257, 91, true, false);
INSERT INTO public."Assicurazione" VALUES (288, 288, 52, true, false);
INSERT INTO public."Assicurazione" VALUES (304, 304, 75, true, false);
INSERT INTO public."Assicurazione" VALUES (256, 256, 81, true, false);
INSERT INTO public."Assicurazione" VALUES (142, 142, 66, true, false);
INSERT INTO public."Assicurazione" VALUES (227, 227, 73, true, false);
INSERT INTO public."Assicurazione" VALUES (294, 294, 56, true, false);
INSERT INTO public."Assicurazione" VALUES (374, 374, 69, true, false);
INSERT INTO public."Assicurazione" VALUES (445, 445, 54, true, false);
INSERT INTO public."Assicurazione" VALUES (75, 75, 80, true, false);
INSERT INTO public."Assicurazione" VALUES (314, 314, 68, true, false);
INSERT INTO public."Assicurazione" VALUES (183, 183, 86, true, false);
INSERT INTO public."Assicurazione" VALUES (373, 373, 63, true, false);
INSERT INTO public."Assicurazione" VALUES (42, 42, 57, true, false);
INSERT INTO public."Assicurazione" VALUES (340, 340, 79, true, false);
INSERT INTO public."Assicurazione" VALUES (381, 381, 55, true, false);
INSERT INTO public."Assicurazione" VALUES (174, 174, 97, true, false);
INSERT INTO public."Assicurazione" VALUES (338, 338, 50, true, false);
INSERT INTO public."Assicurazione" VALUES (388, 388, 73, true, false);
INSERT INTO public."Assicurazione" VALUES (193, 193, 89, true, false);
INSERT INTO public."Assicurazione" VALUES (135, 135, 63, true, false);
INSERT INTO public."Assicurazione" VALUES (452, 452, 59, true, false);
INSERT INTO public."Assicurazione" VALUES (424, 424, 91, true, false);
INSERT INTO public."Assicurazione" VALUES (344, 344, 67, true, false);
INSERT INTO public."Assicurazione" VALUES (231, 231, 70, true, false);
INSERT INTO public."Assicurazione" VALUES (458, 458, 98, true, false);
INSERT INTO public."Assicurazione" VALUES (253, 253, 52, true, false);
INSERT INTO public."Assicurazione" VALUES (414, 414, 73, true, false);
INSERT INTO public."Assicurazione" VALUES (220, 220, 60, true, false);
INSERT INTO public."Assicurazione" VALUES (166, 166, 62, true, false);
INSERT INTO public."Assicurazione" VALUES (455, 455, 85, true, false);
INSERT INTO public."Assicurazione" VALUES (283, 283, 74, true, false);
INSERT INTO public."Assicurazione" VALUES (277, 277, 85, true, false);
INSERT INTO public."Assicurazione" VALUES (425, 425, 61, true, false);
INSERT INTO public."Assicurazione" VALUES (107, 107, 53, true, false);
INSERT INTO public."Assicurazione" VALUES (145, 145, 53, true, false);
INSERT INTO public."Assicurazione" VALUES (81, 81, 60, true, false);
INSERT INTO public."Assicurazione" VALUES (72, 72, 76, true, false);
INSERT INTO public."Assicurazione" VALUES (269, 269, 93, true, false);
INSERT INTO public."Assicurazione" VALUES (63, 63, 70, true, false);
INSERT INTO public."Assicurazione" VALUES (60, 60, 52, true, false);
INSERT INTO public."Assicurazione" VALUES (276, 276, 84, true, false);
INSERT INTO public."Assicurazione" VALUES (152, 152, 69, true, false);
INSERT INTO public."Assicurazione" VALUES (117, 117, 59, true, false);
INSERT INTO public."Assicurazione" VALUES (43, 43, 93, true, false);
INSERT INTO public."Assicurazione" VALUES (159, 159, 99, true, false);
INSERT INTO public."Assicurazione" VALUES (95, 95, 56, true, false);
INSERT INTO public."Assicurazione" VALUES (251, 251, 67, true, false);
INSERT INTO public."Assicurazione" VALUES (158, 158, 86, true, false);
INSERT INTO public."Assicurazione" VALUES (184, 184, 93, true, false);
INSERT INTO public."Assicurazione" VALUES (472, 472, 78, true, false);
INSERT INTO public."Assicurazione" VALUES (267, 267, 84, true, false);
INSERT INTO public."Assicurazione" VALUES (437, 437, 95, true, false);
INSERT INTO public."Assicurazione" VALUES (354, 354, 54, true, false);
INSERT INTO public."Assicurazione" VALUES (286, 286, 81, true, false);
INSERT INTO public."Assicurazione" VALUES (306, 306, 63, true, false);
INSERT INTO public."Assicurazione" VALUES (62, 62, 67, true, false);
INSERT INTO public."Assicurazione" VALUES (136, 136, 89, true, false);
INSERT INTO public."Assicurazione" VALUES (219, 219, 69, true, false);
INSERT INTO public."Assicurazione" VALUES (407, 407, 95, true, false);
INSERT INTO public."Assicurazione" VALUES (150, 150, 51, true, false);
INSERT INTO public."Assicurazione" VALUES (350, 350, 100, true, false);
INSERT INTO public."Assicurazione" VALUES (419, 419, 88, true, false);
INSERT INTO public."Assicurazione" VALUES (298, 298, 54, true, false);
INSERT INTO public."Assicurazione" VALUES (154, 154, 56, true, false);
INSERT INTO public."Assicurazione" VALUES (241, 241, 81, true, false);
INSERT INTO public."Assicurazione" VALUES (365, 365, 99, true, false);
INSERT INTO public."Assicurazione" VALUES (192, 192, 80, true, false);
INSERT INTO public."Assicurazione" VALUES (255, 255, 77, true, false);
INSERT INTO public."Assicurazione" VALUES (262, 262, 82, true, false);
INSERT INTO public."Assicurazione" VALUES (341, 341, 66, true, false);
INSERT INTO public."Assicurazione" VALUES (177, 177, 64, true, false);
INSERT INTO public."Assicurazione" VALUES (65, 65, 61, true, false);
INSERT INTO public."Assicurazione" VALUES (30, 30, 89, true, false);
INSERT INTO public."Assicurazione" VALUES (246, 246, 67, true, false);
INSERT INTO public."Assicurazione" VALUES (355, 355, 62, true, false);
INSERT INTO public."Assicurazione" VALUES (222, 222, 61, true, false);
INSERT INTO public."Assicurazione" VALUES (206, 206, 66, true, false);
INSERT INTO public."Assicurazione" VALUES (203, 203, 89, true, false);
INSERT INTO public."Assicurazione" VALUES (263, 263, 63, true, false);
INSERT INTO public."Assicurazione" VALUES (408, 408, 97, true, false);
INSERT INTO public."Assicurazione" VALUES (204, 204, 98, true, false);
INSERT INTO public."Assicurazione" VALUES (84, 84, 51, true, false);
INSERT INTO public."Assicurazione" VALUES (459, 459, 52, true, false);
INSERT INTO public."Assicurazione" VALUES (97, 97, 50, true, false);
INSERT INTO public."Assicurazione" VALUES (393, 393, 54, true, false);
INSERT INTO public."Assicurazione" VALUES (71, 71, 62, true, false);
INSERT INTO public."Assicurazione" VALUES (333, 333, 93, true, false);
INSERT INTO public."Assicurazione" VALUES (164, 164, 96, true, false);
INSERT INTO public."Assicurazione" VALUES (47, 47, 62, true, false);
INSERT INTO public."Assicurazione" VALUES (401, 401, 60, true, false);
INSERT INTO public."Assicurazione" VALUES (101, 101, 59, true, false);
INSERT INTO public."Assicurazione" VALUES (465, 465, 65, true, false);
INSERT INTO public."Assicurazione" VALUES (179, 179, 61, true, false);
INSERT INTO public."Assicurazione" VALUES (230, 230, 91, true, false);
INSERT INTO public."Assicurazione" VALUES (775, 775, 9, false, true);
INSERT INTO public."Assicurazione" VALUES (785, 785, 25, false, true);
INSERT INTO public."Assicurazione" VALUES (788, 788, 1, false, true);
INSERT INTO public."Assicurazione" VALUES (751, 751, 29, false, true);
INSERT INTO public."Assicurazione" VALUES (676, 676, 24, false, true);
INSERT INTO public."Assicurazione" VALUES (778, 778, 29, false, true);
INSERT INTO public."Assicurazione" VALUES (681, 681, 15, false, true);
INSERT INTO public."Assicurazione" VALUES (719, 719, 14, false, true);
INSERT INTO public."Assicurazione" VALUES (703, 703, 9, false, true);
INSERT INTO public."Assicurazione" VALUES (701, 701, 17, false, true);
INSERT INTO public."Assicurazione" VALUES (677, 677, 24, false, true);
INSERT INTO public."Assicurazione" VALUES (759, 759, 11, false, true);
INSERT INTO public."Assicurazione" VALUES (745, 745, 17, false, true);
INSERT INTO public."Assicurazione" VALUES (694, 694, 2, false, true);
INSERT INTO public."Assicurazione" VALUES (784, 784, 21, false, true);
INSERT INTO public."Assicurazione" VALUES (732, 732, 15, false, true);
INSERT INTO public."Assicurazione" VALUES (711, 711, 6, false, true);
INSERT INTO public."Assicurazione" VALUES (724, 724, 4, false, true);
INSERT INTO public."Assicurazione" VALUES (739, 739, 14, false, true);
INSERT INTO public."Assicurazione" VALUES (729, 729, 16, false, true);
INSERT INTO public."Assicurazione" VALUES (534, 534, 30, false, true);
INSERT INTO public."Assicurazione" VALUES (647, 647, 19, false, true);
INSERT INTO public."Assicurazione" VALUES (484, 484, 17, false, true);
INSERT INTO public."Assicurazione" VALUES (568, 568, 4, false, true);
INSERT INTO public."Assicurazione" VALUES (592, 592, 2, false, true);
INSERT INTO public."Assicurazione" VALUES (715, 715, 3, false, true);
INSERT INTO public."Assicurazione" VALUES (543, 543, 11, false, true);
INSERT INTO public."Assicurazione" VALUES (584, 584, 25, false, true);
INSERT INTO public."Assicurazione" VALUES (685, 685, 18, false, true);
INSERT INTO public."Assicurazione" VALUES (497, 497, 2, false, true);
INSERT INTO public."Assicurazione" VALUES (794, 794, 25, false, true);
INSERT INTO public."Assicurazione" VALUES (741, 741, 24, false, true);
INSERT INTO public."Assicurazione" VALUES (585, 585, 1, false, true);
INSERT INTO public."Assicurazione" VALUES (593, 593, 12, false, true);
INSERT INTO public."Assicurazione" VALUES (557, 557, 28, false, true);
INSERT INTO public."Assicurazione" VALUES (538, 538, 5, false, true);
INSERT INTO public."Assicurazione" VALUES (579, 579, 5, false, true);
INSERT INTO public."Assicurazione" VALUES (750, 750, 25, false, true);
INSERT INTO public."Assicurazione" VALUES (552, 552, 18, false, true);
INSERT INTO public."Assicurazione" VALUES (569, 569, 27, false, true);
INSERT INTO public."Assicurazione" VALUES (500, 500, 4, false, true);
INSERT INTO public."Assicurazione" VALUES (495, 495, 21, false, true);
INSERT INTO public."Assicurazione" VALUES (746, 746, 22, false, true);
INSERT INTO public."Assicurazione" VALUES (559, 559, 6, false, true);
INSERT INTO public."Assicurazione" VALUES (659, 659, 11, false, true);
INSERT INTO public."Assicurazione" VALUES (606, 606, 16, false, true);
INSERT INTO public."Assicurazione" VALUES (476, 476, 3, false, true);
INSERT INTO public."Assicurazione" VALUES (482, 482, 27, false, true);
INSERT INTO public."Assicurazione" VALUES (605, 605, 4, false, true);
INSERT INTO public."Assicurazione" VALUES (503, 503, 1, false, true);
INSERT INTO public."Assicurazione" VALUES (764, 764, 16, false, true);
INSERT INTO public."Assicurazione" VALUES (756, 756, 2, false, true);
INSERT INTO public."Assicurazione" VALUES (752, 752, 2, false, true);
INSERT INTO public."Assicurazione" VALUES (733, 733, 10, false, true);
INSERT INTO public."Assicurazione" VALUES (546, 546, 23, false, true);
INSERT INTO public."Assicurazione" VALUES (691, 691, 5, false, true);
INSERT INTO public."Assicurazione" VALUES (668, 668, 10, false, true);
INSERT INTO public."Assicurazione" VALUES (549, 549, 6, false, true);
INSERT INTO public."Assicurazione" VALUES (781, 781, 15, false, true);
INSERT INTO public."Assicurazione" VALUES (518, 518, 10, false, true);
INSERT INTO public."Assicurazione" VALUES (595, 595, 6, false, true);
INSERT INTO public."Assicurazione" VALUES (658, 658, 27, false, true);
INSERT INTO public."Assicurazione" VALUES (779, 779, 14, false, true);
INSERT INTO public."Assicurazione" VALUES (758, 758, 23, false, true);
INSERT INTO public."Assicurazione" VALUES (523, 523, 22, false, true);
INSERT INTO public."Assicurazione" VALUES (777, 777, 19, false, true);
INSERT INTO public."Assicurazione" VALUES (649, 649, 8, false, true);
INSERT INTO public."Assicurazione" VALUES (645, 645, 16, false, true);
INSERT INTO public."Assicurazione" VALUES (702, 702, 24, false, true);
INSERT INTO public."Assicurazione" VALUES (608, 608, 14, false, true);
INSERT INTO public."Assicurazione" VALUES (710, 710, 14, false, true);
INSERT INTO public."Assicurazione" VALUES (692, 692, 21, false, true);
INSERT INTO public."Assicurazione" VALUES (511, 511, 13, false, true);
INSERT INTO public."Assicurazione" VALUES (524, 524, 22, false, true);
INSERT INTO public."Assicurazione" VALUES (494, 494, 28, false, true);
INSERT INTO public."Assicurazione" VALUES (582, 582, 18, false, true);
INSERT INTO public."Assicurazione" VALUES (706, 706, 18, false, true);
INSERT INTO public."Assicurazione" VALUES (735, 735, 30, false, true);
INSERT INTO public."Assicurazione" VALUES (723, 723, 4, false, true);
INSERT INTO public."Assicurazione" VALUES (565, 565, 8, false, true);
INSERT INTO public."Assicurazione" VALUES (630, 630, 19, false, true);
INSERT INTO public."Assicurazione" VALUES (673, 673, 28, false, true);
INSERT INTO public."Assicurazione" VALUES (502, 502, 30, false, true);
INSERT INTO public."Assicurazione" VALUES (522, 522, 13, false, true);
INSERT INTO public."Assicurazione" VALUES (770, 770, 2, false, true);
INSERT INTO public."Assicurazione" VALUES (570, 570, 9, false, true);
INSERT INTO public."Assicurazione" VALUES (652, 652, 4, false, true);
INSERT INTO public."Assicurazione" VALUES (722, 722, 3, false, true);
INSERT INTO public."Assicurazione" VALUES (679, 679, 15, false, true);
INSERT INTO public."Assicurazione" VALUES (671, 671, 25, false, true);
INSERT INTO public."Assicurazione" VALUES (505, 505, 22, false, true);
INSERT INTO public."Assicurazione" VALUES (492, 492, 14, false, true);
INSERT INTO public."Assicurazione" VALUES (765, 765, 12, false, true);
INSERT INTO public."Assicurazione" VALUES (655, 655, 3, false, true);
INSERT INTO public."Assicurazione" VALUES (498, 498, 9, false, true);
INSERT INTO public."Assicurazione" VALUES (587, 587, 17, false, true);
INSERT INTO public."Assicurazione" VALUES (737, 737, 18, false, true);
INSERT INTO public."Assicurazione" VALUES (753, 753, 7, false, true);
INSERT INTO public."Assicurazione" VALUES (749, 749, 12, false, true);
INSERT INTO public."Assicurazione" VALUES (718, 718, 20, false, true);
INSERT INTO public."Assicurazione" VALUES (515, 515, 11, false, true);
INSERT INTO public."Assicurazione" VALUES (744, 744, 6, false, true);
INSERT INTO public."Assicurazione" VALUES (642, 642, 28, false, true);
INSERT INTO public."Assicurazione" VALUES (780, 780, 19, false, true);
INSERT INTO public."Assicurazione" VALUES (709, 709, 6, false, true);
INSERT INTO public."Assicurazione" VALUES (713, 713, 1, false, true);
INSERT INTO public."Assicurazione" VALUES (586, 586, 26, false, true);
INSERT INTO public."Assicurazione" VALUES (612, 612, 27, false, true);
INSERT INTO public."Assicurazione" VALUES (481, 481, 3, false, true);
INSERT INTO public."Assicurazione" VALUES (602, 602, 25, false, true);
INSERT INTO public."Assicurazione" VALUES (615, 615, 28, false, true);
INSERT INTO public."Assicurazione" VALUES (616, 616, 29, false, true);
INSERT INTO public."Assicurazione" VALUES (688, 688, 19, false, true);
INSERT INTO public."Assicurazione" VALUES (609, 609, 27, false, true);
INSERT INTO public."Assicurazione" VALUES (485, 485, 12, false, true);
INSERT INTO public."Assicurazione" VALUES (577, 577, 2, false, true);
INSERT INTO public."Assicurazione" VALUES (693, 693, 17, false, true);
INSERT INTO public."Assicurazione" VALUES (664, 664, 11, false, true);
INSERT INTO public."Assicurazione" VALUES (576, 576, 6, false, true);
INSERT INTO public."Assicurazione" VALUES (790, 790, 3, false, true);
INSERT INTO public."Assicurazione" VALUES (786, 786, 27, false, true);
INSERT INTO public."Assicurazione" VALUES (648, 648, 11, false, true);
INSERT INTO public."Assicurazione" VALUES (696, 696, 17, false, true);
INSERT INTO public."Assicurazione" VALUES (682, 682, 22, false, true);
INSERT INTO public."Assicurazione" VALUES (499, 499, 6, false, true);
INSERT INTO public."Assicurazione" VALUES (622, 622, 30, false, true);
INSERT INTO public."Assicurazione" VALUES (793, 793, 7, false, true);
INSERT INTO public."Assicurazione" VALUES (782, 782, 27, false, true);
INSERT INTO public."Assicurazione" VALUES (633, 633, 18, false, true);
INSERT INTO public."Assicurazione" VALUES (734, 734, 2, false, true);
INSERT INTO public."Assicurazione" VALUES (674, 674, 20, false, true);
INSERT INTO public."Assicurazione" VALUES (517, 517, 27, false, true);
INSERT INTO public."Assicurazione" VALUES (548, 548, 22, false, true);
INSERT INTO public."Assicurazione" VALUES (670, 670, 29, false, true);
INSERT INTO public."Assicurazione" VALUES (532, 532, 17, false, true);
INSERT INTO public."Assicurazione" VALUES (571, 571, 17, false, true);
INSERT INTO public."Assicurazione" VALUES (513, 513, 14, false, true);
INSERT INTO public."Assicurazione" VALUES (529, 529, 12, false, true);
INSERT INTO public."Assicurazione" VALUES (493, 493, 16, false, true);
INSERT INTO public."Assicurazione" VALUES (624, 624, 24, false, true);
INSERT INTO public."Assicurazione" VALUES (567, 567, 17, false, true);
INSERT INTO public."Assicurazione" VALUES (562, 562, 26, false, true);
INSERT INTO public."Assicurazione" VALUES (566, 566, 25, false, true);
INSERT INTO public."Assicurazione" VALUES (496, 496, 2, false, true);
INSERT INTO public."Assicurazione" VALUES (541, 541, 3, false, true);
INSERT INTO public."Assicurazione" VALUES (721, 721, 19, false, true);
INSERT INTO public."Assicurazione" VALUES (479, 479, 30, false, true);
INSERT INTO public."Assicurazione" VALUES (504, 504, 15, false, true);
INSERT INTO public."Assicurazione" VALUES (773, 773, 14, false, true);
INSERT INTO public."Assicurazione" VALUES (766, 766, 25, false, true);
INSERT INTO public."Assicurazione" VALUES (683, 683, 27, false, true);
INSERT INTO public."Assicurazione" VALUES (556, 556, 26, false, true);
INSERT INTO public."Assicurazione" VALUES (480, 480, 10, false, true);
INSERT INTO public."Assicurazione" VALUES (506, 506, 27, false, true);
INSERT INTO public."Assicurazione" VALUES (787, 787, 11, false, true);
INSERT INTO public."Assicurazione" VALUES (791, 791, 27, false, true);
INSERT INTO public."Assicurazione" VALUES (620, 620, 4, false, true);
INSERT INTO public."Assicurazione" VALUES (748, 748, 10, false, true);
INSERT INTO public."Assicurazione" VALUES (768, 768, 18, false, true);
INSERT INTO public."Assicurazione" VALUES (754, 754, 1, false, true);
INSERT INTO public."Assicurazione" VALUES (520, 520, 4, false, true);
INSERT INTO public."Assicurazione" VALUES (795, 795, 26, false, true);
INSERT INTO public."Assicurazione" VALUES (533, 533, 6, false, true);
INSERT INTO public."Assicurazione" VALUES (646, 646, 22, false, true);
INSERT INTO public."Assicurazione" VALUES (545, 545, 12, false, true);
INSERT INTO public."Assicurazione" VALUES (698, 698, 28, false, true);
INSERT INTO public."Assicurazione" VALUES (774, 774, 8, false, true);
INSERT INTO public."Assicurazione" VALUES (583, 583, 2, false, true);
INSERT INTO public."Assicurazione" VALUES (631, 631, 10, false, true);
INSERT INTO public."Assicurazione" VALUES (772, 772, 30, false, true);
INSERT INTO public."Assicurazione" VALUES (747, 747, 6, false, true);
INSERT INTO public."Assicurazione" VALUES (596, 596, 28, false, true);
INSERT INTO public."Assicurazione" VALUES (623, 623, 16, false, true);
INSERT INTO public."Assicurazione" VALUES (594, 594, 26, false, true);
INSERT INTO public."Assicurazione" VALUES (707, 707, 20, false, true);
INSERT INTO public."Assicurazione" VALUES (720, 720, 9, false, true);
INSERT INTO public."Assicurazione" VALUES (547, 547, 15, false, true);
INSERT INTO public."Assicurazione" VALUES (550, 550, 15, false, true);
INSERT INTO public."Assicurazione" VALUES (653, 653, 20, false, true);
INSERT INTO public."Assicurazione" VALUES (639, 639, 13, false, true);
INSERT INTO public."Assicurazione" VALUES (783, 783, 16, false, true);
INSERT INTO public."Assicurazione" VALUES (564, 564, 16, false, true);
INSERT INTO public."Assicurazione" VALUES (553, 553, 6, false, true);
INSERT INTO public."Assicurazione" VALUES (561, 561, 23, false, true);
INSERT INTO public."Assicurazione" VALUES (661, 661, 24, false, true);
INSERT INTO public."Assicurazione" VALUES (558, 558, 10, false, true);
INSERT INTO public."Assicurazione" VALUES (686, 686, 9, false, true);
INSERT INTO public."Assicurazione" VALUES (792, 792, 23, false, true);
INSERT INTO public."Assicurazione" VALUES (666, 666, 18, false, true);
INSERT INTO public."Assicurazione" VALUES (680, 680, 7, false, true);
INSERT INTO public."Assicurazione" VALUES (581, 581, 23, false, true);
INSERT INTO public."Assicurazione" VALUES (514, 514, 16, false, true);
INSERT INTO public."Assicurazione" VALUES (512, 512, 1, false, true);
INSERT INTO public."Assicurazione" VALUES (638, 638, 1, false, true);
INSERT INTO public."Assicurazione" VALUES (507, 507, 11, false, true);
INSERT INTO public."Assicurazione" VALUES (725, 725, 19, false, true);
INSERT INTO public."Assicurazione" VALUES (554, 554, 5, false, true);
INSERT INTO public."Assicurazione" VALUES (603, 603, 23, false, true);
INSERT INTO public."Assicurazione" VALUES (699, 699, 19, false, true);
INSERT INTO public."Assicurazione" VALUES (539, 539, 8, false, true);
INSERT INTO public."Assicurazione" VALUES (632, 632, 18, false, true);
INSERT INTO public."Assicurazione" VALUES (578, 578, 2, false, true);
INSERT INTO public."Assicurazione" VALUES (657, 657, 22, false, true);
INSERT INTO public."Assicurazione" VALUES (757, 757, 3, false, true);
INSERT INTO public."Assicurazione" VALUES (636, 636, 6, false, true);
INSERT INTO public."Assicurazione" VALUES (742, 742, 22, false, true);
INSERT INTO public."Assicurazione" VALUES (625, 625, 30, false, true);
INSERT INTO public."Assicurazione" VALUES (617, 617, 9, false, true);
INSERT INTO public."Assicurazione" VALUES (599, 599, 9, false, true);
INSERT INTO public."Assicurazione" VALUES (672, 672, 17, false, true);
INSERT INTO public."Assicurazione" VALUES (627, 627, 28, false, true);
INSERT INTO public."Assicurazione" VALUES (705, 705, 17, false, true);
INSERT INTO public."Assicurazione" VALUES (489, 489, 26, false, true);
INSERT INTO public."Assicurazione" VALUES (628, 628, 6, false, true);
INSERT INTO public."Assicurazione" VALUES (789, 789, 1, false, true);
INSERT INTO public."Assicurazione" VALUES (650, 650, 7, false, true);
INSERT INTO public."Assicurazione" VALUES (575, 575, 7, false, true);
INSERT INTO public."Assicurazione" VALUES (635, 635, 30, false, true);
INSERT INTO public."Assicurazione" VALUES (551, 551, 17, false, true);
INSERT INTO public."Assicurazione" VALUES (738, 738, 25, false, true);
INSERT INTO public."Assicurazione" VALUES (730, 730, 11, false, true);
INSERT INTO public."Assicurazione" VALUES (610, 610, 22, false, true);
INSERT INTO public."Assicurazione" VALUES (714, 714, 5, false, true);
INSERT INTO public."Assicurazione" VALUES (597, 597, 6, false, true);
INSERT INTO public."Assicurazione" VALUES (572, 572, 25, false, true);
INSERT INTO public."Assicurazione" VALUES (644, 644, 2, false, true);
INSERT INTO public."Assicurazione" VALUES (573, 573, 16, false, true);
INSERT INTO public."Assicurazione" VALUES (519, 519, 28, false, true);
INSERT INTO public."Assicurazione" VALUES (477, 477, 22, false, true);
INSERT INTO public."Assicurazione" VALUES (530, 530, 3, false, true);
INSERT INTO public."Assicurazione" VALUES (528, 528, 20, false, true);
INSERT INTO public."Assicurazione" VALUES (684, 684, 16, false, true);
INSERT INTO public."Assicurazione" VALUES (769, 769, 2, false, true);
INSERT INTO public."Assicurazione" VALUES (563, 563, 28, false, true);
INSERT INTO public."Assicurazione" VALUES (690, 690, 28, false, true);
INSERT INTO public."Assicurazione" VALUES (580, 580, 26, false, true);
INSERT INTO public."Assicurazione" VALUES (626, 626, 12, false, true);
INSERT INTO public."Assicurazione" VALUES (486, 486, 2, false, true);
INSERT INTO public."Assicurazione" VALUES (641, 641, 27, false, true);
INSERT INTO public."Assicurazione" VALUES (762, 762, 9, false, true);
INSERT INTO public."Assicurazione" VALUES (687, 687, 5, false, true);
INSERT INTO public."Assicurazione" VALUES (487, 487, 11, false, true);
INSERT INTO public."Assicurazione" VALUES (501, 501, 19, false, true);
INSERT INTO public."Assicurazione" VALUES (555, 555, 29, false, true);
INSERT INTO public."Assicurazione" VALUES (736, 736, 24, false, true);
INSERT INTO public."Assicurazione" VALUES (689, 689, 26, false, true);
INSERT INTO public."Assicurazione" VALUES (600, 600, 26, false, true);
INSERT INTO public."Assicurazione" VALUES (767, 767, 6, false, true);
INSERT INTO public."Assicurazione" VALUES (695, 695, 9, false, true);
INSERT INTO public."Assicurazione" VALUES (640, 640, 23, false, true);
INSERT INTO public."Assicurazione" VALUES (731, 731, 15, false, true);
INSERT INTO public."Assicurazione" VALUES (708, 708, 6, false, true);
INSERT INTO public."Assicurazione" VALUES (560, 560, 21, false, true);
INSERT INTO public."Assicurazione" VALUES (727, 727, 15, false, true);
INSERT INTO public."Assicurazione" VALUES (611, 611, 25, false, true);
INSERT INTO public."Assicurazione" VALUES (618, 618, 8, false, true);
INSERT INTO public."Assicurazione" VALUES (607, 607, 2, false, true);
INSERT INTO public."Assicurazione" VALUES (704, 704, 14, false, true);
INSERT INTO public."Assicurazione" VALUES (531, 531, 25, false, true);
INSERT INTO public."Assicurazione" VALUES (590, 590, 12, false, true);
INSERT INTO public."Assicurazione" VALUES (728, 728, 13, false, true);
INSERT INTO public."Assicurazione" VALUES (771, 771, 17, false, true);
INSERT INTO public."Assicurazione" VALUES (743, 743, 15, false, true);
INSERT INTO public."Assicurazione" VALUES (740, 740, 15, false, true);
INSERT INTO public."Assicurazione" VALUES (614, 614, 10, false, true);
INSERT INTO public."Assicurazione" VALUES (669, 669, 18, false, true);
INSERT INTO public."Assicurazione" VALUES (716, 716, 25, false, true);
INSERT INTO public."Assicurazione" VALUES (634, 634, 15, false, true);
INSERT INTO public."Assicurazione" VALUES (663, 663, 19, false, true);
INSERT INTO public."Assicurazione" VALUES (637, 637, 10, false, true);
INSERT INTO public."Assicurazione" VALUES (697, 697, 25, false, true);
INSERT INTO public."Assicurazione" VALUES (478, 478, 29, false, true);
INSERT INTO public."Assicurazione" VALUES (761, 761, 19, false, true);
INSERT INTO public."Assicurazione" VALUES (542, 542, 7, false, true);
INSERT INTO public."Assicurazione" VALUES (521, 521, 26, false, true);
INSERT INTO public."Assicurazione" VALUES (776, 776, 27, false, true);
INSERT INTO public."Assicurazione" VALUES (540, 540, 25, false, true);
INSERT INTO public."Assicurazione" VALUES (760, 760, 24, false, true);
INSERT INTO public."Assicurazione" VALUES (589, 589, 29, false, true);
INSERT INTO public."Assicurazione" VALUES (717, 717, 13, false, true);
INSERT INTO public."Assicurazione" VALUES (726, 726, 30, false, true);
INSERT INTO public."Assicurazione" VALUES (516, 516, 25, false, true);
INSERT INTO public."Assicurazione" VALUES (700, 700, 23, false, true);
INSERT INTO public."Assicurazione" VALUES (483, 483, 24, false, true);
INSERT INTO public."Assicurazione" VALUES (654, 654, 8, false, true);
INSERT INTO public."Assicurazione" VALUES (621, 621, 22, false, true);
INSERT INTO public."Assicurazione" VALUES (712, 712, 23, false, true);
INSERT INTO public."Assicurazione" VALUES (662, 662, 8, false, true);
INSERT INTO public."Assicurazione" VALUES (755, 755, 2, false, true);
INSERT INTO public."Assicurazione" VALUES (574, 574, 12, false, true);
INSERT INTO public."Assicurazione" VALUES (488, 488, 30, false, true);
INSERT INTO public."Assicurazione" VALUES (613, 613, 6, false, true);
INSERT INTO public."Assicurazione" VALUES (678, 678, 30, false, true);
INSERT INTO public."Assicurazione" VALUES (527, 527, 12, false, true);
INSERT INTO public."Assicurazione" VALUES (535, 535, 1, false, true);
INSERT INTO public."Assicurazione" VALUES (667, 667, 19, false, true);
INSERT INTO public."Assicurazione" VALUES (508, 508, 13, false, true);
INSERT INTO public."Assicurazione" VALUES (598, 598, 15, false, true);
INSERT INTO public."Assicurazione" VALUES (763, 763, 27, false, true);
INSERT INTO public."Assicurazione" VALUES (1, 1, 80, true, false);


--
-- TOC entry 3613 (class 0 OID 18543)
-- Dependencies: 254
-- Data for Name: Dipendente; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO public."Dipendente" VALUES (497, 20000, 12, 'magazzino', 'Véronique', 'Sillito');
INSERT INTO public."Dipendente" VALUES (240, 28000, 9, 'ufficio', 'Billie', 'Wherrett');
INSERT INTO public."Dipendente" VALUES (448, 17000, 15, 'ufficio', 'Séréna', 'Cornelisse');
INSERT INTO public."Dipendente" VALUES (404, 18000, 8, 'magazzino', 'Illustrée', 'Woodberry');
INSERT INTO public."Dipendente" VALUES (386, 15000, 3, 'magazzino', 'Annotés', 'Breach');
INSERT INTO public."Dipendente" VALUES (200, 22000, 6, 'magazzino', 'Renae', 'Philippe');
INSERT INTO public."Dipendente" VALUES (299, 17000, 27, 'magazzino', 'Séréna', 'Diaper');
INSERT INTO public."Dipendente" VALUES (446, 15000, 21, 'magazzino', 'Léandre', 'Deering');
INSERT INTO public."Dipendente" VALUES (402, 15000, 23, 'segreteria', 'Océanne', 'Pinsent');
INSERT INTO public."Dipendente" VALUES (204, 28000, 6, 'magazzino', 'Ulberto', 'Chesterman');
INSERT INTO public."Dipendente" VALUES (259, 21000, 8, 'ufficio', 'Crééz', 'Orteu');
INSERT INTO public."Dipendente" VALUES (316, 22000, 20, 'magazzino', 'Maëly', 'Copley');
INSERT INTO public."Dipendente" VALUES (349, 20000, 1, 'magazzino', 'Adélaïde', 'Shickle');
INSERT INTO public."Dipendente" VALUES (419, 22000, 15, 'ufficio', 'Valérie', 'Fieldsend');
INSERT INTO public."Dipendente" VALUES (334, 17000, 25, 'magazzino', 'Zhì', 'Penfold');
INSERT INTO public."Dipendente" VALUES (192, 20000, 27, 'magazzino', 'Stephine', 'Barnish');
INSERT INTO public."Dipendente" VALUES (233, 28000, 16, 'segreteria', 'Flore', 'Tunnoch');
INSERT INTO public."Dipendente" VALUES (255, 15000, 22, 'ufficio', 'Loïc', 'Ashby');
INSERT INTO public."Dipendente" VALUES (474, 28000, 11, 'segreteria', 'Cécilia', 'McMarquis');
INSERT INTO public."Dipendente" VALUES (280, 22000, 2, 'magazzino', 'Ophélie', 'Catt');
INSERT INTO public."Dipendente" VALUES (310, 28000, 1, 'magazzino', 'Åslög', 'MacWhan');
INSERT INTO public."Dipendente" VALUES (429, 21000, 22, 'ufficio', 'Eléa', 'McAllister');
INSERT INTO public."Dipendente" VALUES (477, 18000, 19, 'segreteria', 'Uò', 'Cino');
INSERT INTO public."Dipendente" VALUES (475, 15000, 27, 'ufficio', 'Célestine', 'Andreuzzi');
INSERT INTO public."Dipendente" VALUES (398, 17000, 7, 'magazzino', 'Nadège', 'Biggs');
INSERT INTO public."Dipendente" VALUES (354, 20000, 17, 'ufficio', 'Marie-hélène', 'Waistall');
INSERT INTO public."Dipendente" VALUES (282, 20000, 16, 'ufficio', 'Bénédicte', 'Diemer');
INSERT INTO public."Dipendente" VALUES (372, 18000, 16, 'magazzino', 'Åsa', 'Godin');
INSERT INTO public."Dipendente" VALUES (362, 22000, 18, 'magazzino', 'Maï', 'Bamford');
INSERT INTO public."Dipendente" VALUES (304, 17000, 18, 'magazzino', 'Mégane', 'Chicchelli');
INSERT INTO public."Dipendente" VALUES (245, 21000, 25, 'ufficio', 'Séréna', 'Pratty');
INSERT INTO public."Dipendente" VALUES (291, 15000, 24, 'segreteria', 'Anaïs', 'Ceschelli');
INSERT INTO public."Dipendente" VALUES (473, 17000, 8, 'magazzino', 'Garçon', 'Evetts');
INSERT INTO public."Dipendente" VALUES (447, 20000, 11, 'segreteria', 'Rébecca', 'Smallcombe');
INSERT INTO public."Dipendente" VALUES (494, 17000, 27, 'magazzino', 'Aloïs', 'Gillhespy');
INSERT INTO public."Dipendente" VALUES (432, 20000, 10, 'segreteria', 'Maï', 'O''Sherrin');
INSERT INTO public."Dipendente" VALUES (401, 15000, 3, 'magazzino', 'Yú', 'Wilde');
INSERT INTO public."Dipendente" VALUES (215, 20000, 13, 'segreteria', 'Maxie', 'Moutray Read');
INSERT INTO public."Dipendente" VALUES (412, 17000, 2, 'ufficio', 'Aloïs', 'Beddoe');
INSERT INTO public."Dipendente" VALUES (508, 20000, 21, 'ufficio', 'Börje', 'Schruyer');
INSERT INTO public."Dipendente" VALUES (589, 28000, 25, 'magazzino', 'Yáo', 'Philpin');
INSERT INTO public."Dipendente" VALUES (455, 21000, 5, 'magazzino', 'Mårten', 'Ansley');
INSERT INTO public."Dipendente" VALUES (298, 20000, 4, 'ufficio', 'Bérengère', 'Noye');
INSERT INTO public."Dipendente" VALUES (385, 22000, 5, 'magazzino', 'Dorothée', 'Arbuckel');
INSERT INTO public."Dipendente" VALUES (565, 17000, 11, 'ufficio', 'Vénus', 'Werny');
INSERT INTO public."Dipendente" VALUES (232, 17000, 1, 'magazzino', 'Samson', 'Highway');
INSERT INTO public."Dipendente" VALUES (389, 21000, 12, 'magazzino', 'Pål', 'Wigglesworth');
INSERT INTO public."Dipendente" VALUES (221, 20000, 7, 'segreteria', 'Benedict', 'Batters');
INSERT INTO public."Dipendente" VALUES (198, 17000, 3, 'magazzino', 'Pamella', 'Carthew');
INSERT INTO public."Dipendente" VALUES (223, 21000, 13, 'magazzino', 'Tarrah', 'Baynes');
INSERT INTO public."Dipendente" VALUES (628, 15000, 12, 'ufficio', 'Mégane', 'Josefs');
INSERT INTO public."Dipendente" VALUES (405, 20000, 23, 'segreteria', 'Hélèna', 'Rubinlicht');
INSERT INTO public."Dipendente" VALUES (251, 17000, 20, 'ufficio', 'Eliès', 'Fillan');
INSERT INTO public."Dipendente" VALUES (238, 17000, 23, 'magazzino', 'Cassandry', 'Yepiskov');
INSERT INTO public."Dipendente" VALUES (554, 20000, 4, 'magazzino', 'Bénédicte', 'Wheldon');
INSERT INTO public."Dipendente" VALUES (226, 20000, 2, 'magazzino', 'Shel', 'Glanville');
INSERT INTO public."Dipendente" VALUES (254, 22000, 27, 'ufficio', 'Josée', 'Glasard');
INSERT INTO public."Dipendente" VALUES (489, 17000, 20, 'segreteria', 'André', 'Maddinon');
INSERT INTO public."Dipendente" VALUES (396, 20000, 24, 'magazzino', 'Dafnée', 'Hickeringill');
INSERT INTO public."Dipendente" VALUES (301, 22000, 13, 'ufficio', 'Mélia', 'Ginty');
INSERT INTO public."Dipendente" VALUES (308, 17000, 26, 'segreteria', 'Åsa', 'Lorant');
INSERT INTO public."Dipendente" VALUES (195, 22000, 26, 'magazzino', 'Magdaia', 'Goodbarr');
INSERT INTO public."Dipendente" VALUES (500, 28000, 11, 'magazzino', 'Örjan', 'Bumphrey');
INSERT INTO public."Dipendente" VALUES (207, 17000, 3, 'magazzino', 'Linn', 'Clarke');
INSERT INTO public."Dipendente" VALUES (248, 17000, 2, 'ufficio', 'Anaïs', 'Rolph');
INSERT INTO public."Dipendente" VALUES (194, 21000, 9, 'magazzino', 'Ashton', 'Hairon');
INSERT INTO public."Dipendente" VALUES (515, 28000, 10, 'magazzino', 'Måns', 'Vagg');
INSERT INTO public."Dipendente" VALUES (451, 18000, 24, 'ufficio', 'Illustrée', 'Codlin');
INSERT INTO public."Dipendente" VALUES (454, 17000, 19, 'magazzino', 'Dorothée', 'Simnell');
INSERT INTO public."Dipendente" VALUES (436, 15000, 10, 'ufficio', 'Rébecca', 'Eighteen');
INSERT INTO public."Dipendente" VALUES (196, 15000, 23, 'magazzino', 'Lira', 'Maffeo');
INSERT INTO public."Dipendente" VALUES (218, 15000, 8, 'segreteria', 'Cristabel', 'Didsbury');
INSERT INTO public."Dipendente" VALUES (281, 18000, 25, 'segreteria', 'Kévina', 'Witherden');
INSERT INTO public."Dipendente" VALUES (481, 15000, 20, 'ufficio', 'Lauréna', 'Crownshaw');
INSERT INTO public."Dipendente" VALUES (371, 22000, 26, 'magazzino', 'Pélagie', 'Olech');
INSERT INTO public."Dipendente" VALUES (615, 17000, 3, 'segreteria', 'Valérie', 'Wilkisson');
INSERT INTO public."Dipendente" VALUES (437, 20000, 19, 'magazzino', 'Esbjörn', 'Hubbart');
INSERT INTO public."Dipendente" VALUES (418, 21000, 24, 'ufficio', 'Publicité', 'Poate');
INSERT INTO public."Dipendente" VALUES (484, 17000, 4, 'ufficio', 'Lauréna', 'Caddens');
INSERT INTO public."Dipendente" VALUES (261, 18000, 19, 'ufficio', 'Thérèsa', 'Densun');
INSERT INTO public."Dipendente" VALUES (341, 21000, 15, 'segreteria', 'Ruò', 'Windaybank');
INSERT INTO public."Dipendente" VALUES (307, 20000, 18, 'magazzino', 'Cécile', 'Ciccottio');
INSERT INTO public."Dipendente" VALUES (592, 17000, 16, 'ufficio', 'Méthode', 'Gronou');
INSERT INTO public."Dipendente" VALUES (457, 15000, 18, 'magazzino', 'Adélaïde', 'Mitskevich');
INSERT INTO public."Dipendente" VALUES (313, 20000, 15, 'magazzino', 'Östen', 'Shurlock');
INSERT INTO public."Dipendente" VALUES (487, 15000, 15, 'ufficio', 'Lài', 'Kybert');
INSERT INTO public."Dipendente" VALUES (230, 18000, 13, 'segreteria', 'Nicolas', 'Creech');
INSERT INTO public."Dipendente" VALUES (380, 17000, 16, 'ufficio', 'Örjan', 'Walkington');
INSERT INTO public."Dipendente" VALUES (264, 17000, 22, 'ufficio', 'Åke', 'Bruton');
INSERT INTO public."Dipendente" VALUES (335, 21000, 2, 'segreteria', 'Bérénice', 'Patley');
INSERT INTO public."Dipendente" VALUES (217, 28000, 7, 'magazzino', 'Tedmund', 'Shawel');
INSERT INTO public."Dipendente" VALUES (317, 15000, 16, 'segreteria', 'Agnès', 'Domerque');
INSERT INTO public."Dipendente" VALUES (375, 28000, 1, 'magazzino', 'Solène', 'Litherland');
INSERT INTO public."Dipendente" VALUES (325, 28000, 1, 'magazzino', 'Pénélope', 'Arne');
INSERT INTO public."Dipendente" VALUES (303, 20000, 26, 'ufficio', 'Laurène', 'Soldi');
INSERT INTO public."Dipendente" VALUES (585, 20000, 3, 'magazzino', 'Anaïs', 'Vercruysse');
INSERT INTO public."Dipendente" VALUES (202, 20000, 4, 'magazzino', 'Mariquilla', 'Urlich');
INSERT INTO public."Dipendente" VALUES (336, 22000, 24, 'ufficio', 'Vérane', 'Anthonsen');
INSERT INTO public."Dipendente" VALUES (328, 22000, 11, 'magazzino', 'Marie-josée', 'Ambrosoli');
INSERT INTO public."Dipendente" VALUES (302, 18000, 3, 'segreteria', 'Maï', 'Knotte');
INSERT INTO public."Dipendente" VALUES (392, 20000, 2, 'magazzino', 'Wá', 'Bayle');
INSERT INTO public."Dipendente" VALUES (340, 17000, 20, 'magazzino', 'Eléa', 'Taysbil');
INSERT INTO public."Dipendente" VALUES (453, 20000, 19, 'magazzino', 'Personnalisée', 'Noyes');
INSERT INTO public."Dipendente" VALUES (422, 17000, 12, 'ufficio', 'Publicité', 'Dackombe');
INSERT INTO public."Dipendente" VALUES (321, 22000, 10, 'ufficio', 'Bénédicte', 'Sherwill');
INSERT INTO public."Dipendente" VALUES (622, 21000, 1, 'ufficio', 'Miléna', 'Auden');
INSERT INTO public."Dipendente" VALUES (363, 20000, 3, 'magazzino', 'Aurélie', 'Lowles');
INSERT INTO public."Dipendente" VALUES (620, 17000, 20, 'magazzino', 'Michèle', 'Jakubczyk');
INSERT INTO public."Dipendente" VALUES (461, 17000, 20, 'magazzino', 'Fèi', 'Goold');
INSERT INTO public."Dipendente" VALUES (462, 21000, 7, 'magazzino', 'Aí', 'Jencey');
INSERT INTO public."Dipendente" VALUES (428, 17000, 15, 'ufficio', 'Camélia', 'Syer');
INSERT INTO public."Dipendente" VALUES (416, 20000, 21, 'ufficio', 'Åslög', 'Sacco');
INSERT INTO public."Dipendente" VALUES (265, 21000, 2, 'magazzino', 'Lyséa', 'Trythall');
INSERT INTO public."Dipendente" VALUES (384, 21000, 4, 'magazzino', 'Yáo', 'Zecchini');
INSERT INTO public."Dipendente" VALUES (469, 21000, 22, 'magazzino', 'Börje', 'Giraldon');
INSERT INTO public."Dipendente" VALUES (225, 15000, 9, 'ufficio', 'Cyndie', 'Hatherley');
INSERT INTO public."Dipendente" VALUES (552, 22000, 21, 'segreteria', 'Camélia', 'Enbury');
INSERT INTO public."Dipendente" VALUES (351, 28000, 26, 'ufficio', 'Kù', 'Antonat');
INSERT INTO public."Dipendente" VALUES (410, 17000, 18, 'magazzino', 'Dafnée', 'Grayne');
INSERT INTO public."Dipendente" VALUES (482, 20000, 9, 'magazzino', 'Maïté', 'Giannassi');
INSERT INTO public."Dipendente" VALUES (557, 28000, 25, 'magazzino', 'Méline', 'Pretswell');
INSERT INTO public."Dipendente" VALUES (319, 17000, 13, 'magazzino', 'Thérèse', 'McSporon');
INSERT INTO public."Dipendente" VALUES (295, 21000, 1, 'ufficio', 'Cléopatre', 'Ricardou');
INSERT INTO public."Dipendente" VALUES (468, 17000, 9, 'magazzino', 'Marie-josée', 'Bimson');
INSERT INTO public."Dipendente" VALUES (272, 21000, 6, 'segreteria', 'Intéressant', 'Tomkin');
INSERT INTO public."Dipendente" VALUES (492, 18000, 8, 'segreteria', 'Illustrée', 'Muckersie');
INSERT INTO public."Dipendente" VALUES (627, 15000, 16, 'segreteria', 'Lucrèce', 'Orrick');
INSERT INTO public."Dipendente" VALUES (290, 28000, 23, 'magazzino', 'Marie-françoise', 'Dilworth');
INSERT INTO public."Dipendente" VALUES (512, 18000, 17, 'magazzino', 'Béatrice', 'Kelberman');
INSERT INTO public."Dipendente" VALUES (559, 20000, 16, 'ufficio', 'Crééz', 'Hartless');
INSERT INTO public."Dipendente" VALUES (327, 20000, 24, 'ufficio', 'Pénélope', 'Biddell');
INSERT INTO public."Dipendente" VALUES (114, 17000, 12, 'magazzino', 'Lyda', 'Doonican');
INSERT INTO public."Dipendente" VALUES (111, 22000, 9, 'ufficio', 'Lazarus', 'Voas');
INSERT INTO public."Dipendente" VALUES (54, 17000, 3, 'ufficio', 'Worden', 'Tukely');
INSERT INTO public."Dipendente" VALUES (145, 21000, 9, 'segreteria', 'Elaine', 'Chue');
INSERT INTO public."Dipendente" VALUES (154, 20000, 1, 'segreteria', 'Martainn', 'Watkiss');
INSERT INTO public."Dipendente" VALUES (92, 20000, 7, 'ufficio', 'Mitch', 'Signoret');
INSERT INTO public."Dipendente" VALUES (24, 18000, 7, 'magazzino', 'Raf', 'Heasley');
INSERT INTO public."Dipendente" VALUES (172, 22000, 2, 'segreteria', 'Pryce', 'Marshalleck');
INSERT INTO public."Dipendente" VALUES (3, 17000, 3, 'magazzino', 'Dorise', 'Mowsley');
INSERT INTO public."Dipendente" VALUES (190, 17000, 3, 'magazzino', 'Pryce', 'Gaitley');
INSERT INTO public."Dipendente" VALUES (100, 28000, 15, 'magazzino', 'Velvet', 'Barrim');
INSERT INTO public."Dipendente" VALUES (187, 20000, 17, 'segreteria', 'Scarface', 'Burchard');
INSERT INTO public."Dipendente" VALUES (169, 20000, 16, 'segreteria', 'Boris', 'Parratt');
INSERT INTO public."Dipendente" VALUES (183, 20000, 13, 'magazzino', 'Korney', 'Yakunikov');
INSERT INTO public."Dipendente" VALUES (16, 20000, 16, 'magazzino', 'Arabelle', 'Pimlock');
INSERT INTO public."Dipendente" VALUES (131, 22000, 12, 'ufficio', 'Bobbe', 'Otson');
INSERT INTO public."Dipendente" VALUES (11, 18000, 11, 'magazzino', 'Aeriela', 'Masson');
INSERT INTO public."Dipendente" VALUES (82, 21000, 14, 'segreteria', 'Octavia', 'Ranshaw');
INSERT INTO public."Dipendente" VALUES (89, 21000, 4, 'ufficio', 'Oralia', 'Cragell');
INSERT INTO public."Dipendente" VALUES (71, 18000, 3, 'ufficio', 'Scarface', 'Hourston');
INSERT INTO public."Dipendente" VALUES (69, 21000, 1, 'ufficio', 'Irene', 'Dunnan');
INSERT INTO public."Dipendente" VALUES (106, 22000, 4, 'magazzino', 'Liz', 'Joanic');
INSERT INTO public."Dipendente" VALUES (163, 20000, 10, 'segreteria', 'Jeremiah', 'Swain');
INSERT INTO public."Dipendente" VALUES (119, 21000, 17, 'ufficio', 'Jillayne', 'Eaton');
INSERT INTO public."Dipendente" VALUES (141, 17000, 5, 'magazzino', 'Eustace', 'Compson');
INSERT INTO public."Dipendente" VALUES (79, 21000, 11, 'segreteria', 'Toiboid', 'Perrat');
INSERT INTO public."Dipendente" VALUES (19, 21000, 2, 'magazzino', 'Trenna', 'Kingstne');
INSERT INTO public."Dipendente" VALUES (86, 20000, 1, 'ufficio', 'Sara-ann', 'Harrap');
INSERT INTO public."Dipendente" VALUES (105, 21000, 3, 'ufficio', 'Shauna', 'Brito');
INSERT INTO public."Dipendente" VALUES (153, 15000, 17, 'magazzino', 'Broderick', 'Harrisson');
INSERT INTO public."Dipendente" VALUES (125, 21000, 6, 'ufficio', 'Muffin', 'Graben');
INSERT INTO public."Dipendente" VALUES (9, 21000, 9, 'magazzino', 'Teressa', 'Coppenhall');
INSERT INTO public."Dipendente" VALUES (63, 21000, 12, 'ufficio', 'Glen', 'Lindwall');
INSERT INTO public."Dipendente" VALUES (93, 17000, 8, 'magazzino', 'Dennet', 'Beton');
INSERT INTO public."Dipendente" VALUES (49, 21000, 15, 'segreteria', 'Mame', 'Rutigliano');
INSERT INTO public."Dipendente" VALUES (2, 20000, 2, 'magazzino', 'Harbert', 'MacLice');
INSERT INTO public."Dipendente" VALUES (38, 21000, 4, 'ufficio', 'Shea', 'Knagges');
INSERT INTO public."Dipendente" VALUES (22, 15000, 5, 'magazzino', 'Kelwin', 'Windybank');
INSERT INTO public."Dipendente" VALUES (25, 20000, 8, 'segreteria', 'Sheffie', 'Adamson');
INSERT INTO public."Dipendente" VALUES (88, 17000, 3, 'segreteria', 'Jermayne', 'Feuell');
INSERT INTO public."Dipendente" VALUES (186, 15000, 16, 'magazzino', 'Lila', 'Dugall');
INSERT INTO public."Dipendente" VALUES (147, 15000, 11, 'magazzino', 'Janek', 'August');
INSERT INTO public."Dipendente" VALUES (182, 18000, 12, 'ufficio', 'Gabriell', 'Mathie');
INSERT INTO public."Dipendente" VALUES (80, 20000, 12, 'ufficio', 'Franny', 'Spyer');
INSERT INTO public."Dipendente" VALUES (159, 20000, 6, 'magazzino', 'Port', 'Denerley');
INSERT INTO public."Dipendente" VALUES (124, 17000, 5, 'segreteria', 'Pepita', 'Cuell');
INSERT INTO public."Dipendente" VALUES (113, 20000, 11, 'ufficio', 'Erina', 'Goley');
INSERT INTO public."Dipendente" VALUES (21, 15000, 4, 'ufficio', 'Dana', 'Dedrick');
INSERT INTO public."Dipendente" VALUES (40, 18000, 6, 'segreteria', 'Ara', 'Godwyn');
INSERT INTO public."Dipendente" VALUES (39, 22000, 5, 'magazzino', 'Faydra', 'Grut');
INSERT INTO public."Dipendente" VALUES (23, 20000, 6, 'segreteria', 'Mikkel', 'Zold');
INSERT INTO public."Dipendente" VALUES (94, 28000, 9, 'magazzino', 'Ardis', 'Thursfield');
INSERT INTO public."Dipendente" VALUES (155, 28000, 2, 'ufficio', 'Jory', 'Eseler');
INSERT INTO public."Dipendente" VALUES (110, 21000, 8, 'segreteria', 'Delly', 'Spratley');
INSERT INTO public."Dipendente" VALUES (65, 15000, 14, 'ufficio', 'Willy', 'Pigrome');
INSERT INTO public."Dipendente" VALUES (115, 28000, 13, 'segreteria', 'Moyra', 'Harewood');
INSERT INTO public."Dipendente" VALUES (104, 17000, 2, 'segreteria', 'Byram', 'Tongue');
INSERT INTO public."Dipendente" VALUES (30, 17000, 13, 'magazzino', 'Rosco', 'Drysdall');
INSERT INTO public."Dipendente" VALUES (90, 22000, 5, 'magazzino', 'Dinah', 'Daville');
INSERT INTO public."Dipendente" VALUES (102, 20000, 17, 'ufficio', 'Sheeree', 'Holme');
INSERT INTO public."Dipendente" VALUES (91, 18000, 6, 'segreteria', 'Antonina', 'Piddock');
INSERT INTO public."Dipendente" VALUES (70, 22000, 2, 'ufficio', 'Corrie', 'Murtell');
INSERT INTO public."Dipendente" VALUES (174, 20000, 4, 'magazzino', 'Davis', 'Edgin');
INSERT INTO public."Dipendente" VALUES (7, 20000, 7, 'magazzino', 'Neel', 'Beautyman');
INSERT INTO public."Dipendente" VALUES (143, 20000, 7, 'ufficio', 'Olimpia', 'De Bellis');
INSERT INTO public."Dipendente" VALUES (56, 15000, 5, 'ufficio', 'Edita', 'Ruggen');
INSERT INTO public."Dipendente" VALUES (33, 21000, 16, 'magazzino', 'Brod', 'Horney');
INSERT INTO public."Dipendente" VALUES (170, 17000, 17, 'ufficio', 'Ginger', 'Gadsden');
INSERT INTO public."Dipendente" VALUES (85, 20000, 17, 'segreteria', 'Meriel', 'Blunsen');
INSERT INTO public."Dipendente" VALUES (138, 22000, 2, 'magazzino', 'Jethro', 'Jirieck');
INSERT INTO public."Dipendente" VALUES (97, 18000, 12, 'magazzino', 'Gert', 'Waycot');
INSERT INTO public."Dipendente" VALUES (121, 15000, 2, 'segreteria', 'Ernesto', 'Esmond');
INSERT INTO public."Dipendente" VALUES (173, 20000, 3, 'ufficio', 'Emogene', 'Metts');
INSERT INTO public."Dipendente" VALUES (136, 15000, 17, 'segreteria', 'Ulberto', 'Skahill');
INSERT INTO public."Dipendente" VALUES (128, 20000, 9, 'ufficio', 'Dinnie', 'Rockall');
INSERT INTO public."Dipendente" VALUES (161, 28000, 8, 'ufficio', 'Damaris', 'Wisniewski');
INSERT INTO public."Dipendente" VALUES (168, 15000, 15, 'magazzino', 'Bale', 'Shotboult');
INSERT INTO public."Dipendente" VALUES (42, 17000, 8, 'magazzino', 'Christel', 'Codd');
INSERT INTO public."Dipendente" VALUES (180, 20000, 10, 'magazzino', 'Joy', 'Tante');
INSERT INTO public."Dipendente" VALUES (179, 20000, 9, 'ufficio', 'Chrysler', 'O''Fallon');
INSERT INTO public."Dipendente" VALUES (60, 21000, 9, 'ufficio', 'Ruthy', 'Geelan');
INSERT INTO public."Dipendente" VALUES (66, 15000, 15, 'ufficio', 'Candie', 'Jaye');
INSERT INTO public."Dipendente" VALUES (133, 20000, 14, 'segreteria', 'Demetra', 'Soggee');
INSERT INTO public."Dipendente" VALUES (75, 21000, 7, 'magazzino', 'Viki', 'Hayland');
INSERT INTO public."Dipendente" VALUES (120, 28000, 1, 'magazzino', 'Hyatt', 'Venour');
INSERT INTO public."Dipendente" VALUES (188, 18000, 1, 'ufficio', 'Lyndy', 'Kowal');
INSERT INTO public."Dipendente" VALUES (130, 21000, 11, 'segreteria', 'Aubrette', 'Knighton');
INSERT INTO public."Dipendente" VALUES (176, 21000, 6, 'ufficio', 'Rosemonde', 'Bradnock');
INSERT INTO public."Dipendente" VALUES (44, 15000, 10, 'ufficio', 'Julianne', 'Troake');
INSERT INTO public."Dipendente" VALUES (134, 17000, 15, 'ufficio', 'Corbett', 'Crutch');
INSERT INTO public."Dipendente" VALUES (61, 17000, 10, 'ufficio', 'Sybil', 'McCosh');
INSERT INTO public."Dipendente" VALUES (149, 20000, 13, 'ufficio', 'Bennie', 'Ridgway');
INSERT INTO public."Dipendente" VALUES (67, 20000, 16, 'ufficio', 'Mayne', 'Froud');
INSERT INTO public."Dipendente" VALUES (96, 20000, 11, 'ufficio', 'Stefanie', 'Lynock');
INSERT INTO public."Dipendente" VALUES (137, 20000, 1, 'ufficio', 'Godiva', 'Jamison');
INSERT INTO public."Dipendente" VALUES (249, 17000, 17, 'ufficio', 'Marie-françoise', 'D''Adda');
INSERT INTO public."Dipendente" VALUES (626, 22000, 5, 'magazzino', 'Aimée', 'Magovern');
INSERT INTO public."Dipendente" VALUES (485, 21000, 15, 'magazzino', 'Méline', 'Larwell');
INSERT INTO public."Dipendente" VALUES (478, 20000, 2, 'ufficio', 'Gaïa', 'Eustace');
INSERT INTO public."Dipendente" VALUES (499, 21000, 12, 'ufficio', 'Dafnée', 'McCreedy');
INSERT INTO public."Dipendente" VALUES (220, 17000, 20, 'magazzino', 'Valdemar', 'Barnewille');
INSERT INTO public."Dipendente" VALUES (243, 17000, 9, 'ufficio', 'Licha', 'Corselles');
INSERT INTO public."Dipendente" VALUES (276, 20000, 21, 'ufficio', 'Lài', 'Cattrell');
INSERT INTO public."Dipendente" VALUES (142, 28000, 6, 'segreteria', 'Blinny', 'Whittaker');
INSERT INTO public."Dipendente" VALUES (81, 17000, 13, 'magazzino', 'Mikel', 'Millier');
INSERT INTO public."Dipendente" VALUES (84, 15000, 16, 'magazzino', 'Candida', 'Douthwaite');
INSERT INTO public."Dipendente" VALUES (53, 17000, 2, 'ufficio', 'Matthaeus', 'Hewlings');
INSERT INTO public."Dipendente" VALUES (122, 20000, 3, 'ufficio', 'Estella', 'Hullyer');
INSERT INTO public."Dipendente" VALUES (117, 20000, 15, 'magazzino', 'Aubrie', 'Karim');
INSERT INTO public."Dipendente" VALUES (146, 22000, 10, 'ufficio', 'Emilio', 'Sayton');
INSERT INTO public."Dipendente" VALUES (77, 15000, 9, 'ufficio', 'Hort', 'Meneghi');
INSERT INTO public."Dipendente" VALUES (178, 15000, 8, 'segreteria', 'Engelbert', 'Glashby');
INSERT INTO public."Dipendente" VALUES (167, 22000, 14, 'ufficio', 'Jade', 'Conant');
INSERT INTO public."Dipendente" VALUES (150, 17000, 14, 'magazzino', 'Jeffrey', 'Comiskey');
INSERT INTO public."Dipendente" VALUES (144, 17000, 8, 'magazzino', 'Garret', 'McGurn');
INSERT INTO public."Dipendente" VALUES (27, 28000, 10, 'magazzino', 'Maryanna', 'Jados');
INSERT INTO public."Dipendente" VALUES (36, 20000, 2, 'magazzino', 'Clementine', 'Catto');
INSERT INTO public."Dipendente" VALUES (126, 22000, 7, 'magazzino', 'Fanny', 'De Bruijn');
INSERT INTO public."Dipendente" VALUES (62, 17000, 11, 'ufficio', 'Clement', 'Ransom');
INSERT INTO public."Dipendente" VALUES (175, 17000, 5, 'segreteria', 'Gauthier', 'Loweth');
INSERT INTO public."Dipendente" VALUES (127, 15000, 8, 'segreteria', 'Cookie', 'Canada');
INSERT INTO public."Dipendente" VALUES (181, 22000, 11, 'segreteria', 'Coleman', 'Luciano');
INSERT INTO public."Dipendente" VALUES (156, 15000, 3, 'magazzino', 'Torie', 'Francecione');
INSERT INTO public."Dipendente" VALUES (152, 28000, 16, 'ufficio', 'Cordy', 'Aylward');
INSERT INTO public."Dipendente" VALUES (129, 17000, 10, 'magazzino', 'Austin', 'Klimt');
INSERT INTO public."Dipendente" VALUES (101, 15000, 16, 'segreteria', 'Maribeth', 'Dear');
INSERT INTO public."Dipendente" VALUES (32, 17000, 15, 'ufficio', 'Marilin', 'Ghiroldi');
INSERT INTO public."Dipendente" VALUES (68, 17000, 17, 'ufficio', 'Wandis', 'Schaben');
INSERT INTO public."Dipendente" VALUES (108, 20000, 6, 'ufficio', 'Marcelle', 'Fardo');
INSERT INTO public."Dipendente" VALUES (43, 28000, 9, 'segreteria', 'Clayborn', 'McGaughey');
INSERT INTO public."Dipendente" VALUES (35, 15000, 1, 'ufficio', 'Rab', 'Zanolli');
INSERT INTO public."Dipendente" VALUES (64, 22000, 13, 'ufficio', 'Brigitte', 'Basile');
INSERT INTO public."Dipendente" VALUES (162, 15000, 9, 'magazzino', 'Olvan', 'MacCosto');
INSERT INTO public."Dipendente" VALUES (132, 18000, 13, 'magazzino', 'Edyth', 'Peskin');
INSERT INTO public."Dipendente" VALUES (13, 17000, 13, 'magazzino', 'Clarance', 'Gosling');
INSERT INTO public."Dipendente" VALUES (26, 17000, 9, 'ufficio', 'Reginauld', 'Pontain');
INSERT INTO public."Dipendente" VALUES (177, 28000, 7, 'magazzino', 'Tanitansy', 'Birchner');
INSERT INTO public."Dipendente" VALUES (78, 20000, 10, 'magazzino', 'Glory', 'Kermannes');
INSERT INTO public."Dipendente" VALUES (166, 21000, 13, 'segreteria', 'Timofei', 'Wordley');
INSERT INTO public."Dipendente" VALUES (28, 15000, 11, 'segreteria', 'Bank', 'Winter');
INSERT INTO public."Dipendente" VALUES (45, 20000, 11, 'magazzino', 'Dianne', 'Gotcliffe');
INSERT INTO public."Dipendente" VALUES (15, 15000, 15, 'magazzino', 'Emlyn', 'Witul');
INSERT INTO public."Dipendente" VALUES (83, 28000, 15, 'ufficio', 'Nikkie', 'Birks');
INSERT INTO public."Dipendente" VALUES (59, 17000, 8, 'ufficio', 'Jereme', 'Gaymer');
INSERT INTO public."Dipendente" VALUES (87, 20000, 2, 'magazzino', 'Tisha', 'Kubu');
INSERT INTO public."Dipendente" VALUES (95, 15000, 10, 'segreteria', 'Chryste', 'Dudhill');
INSERT INTO public."Dipendente" VALUES (139, 18000, 3, 'segreteria', 'Janna', 'Treble');
INSERT INTO public."Dipendente" VALUES (29, 20000, 12, 'ufficio', 'Antonietta', 'Marian');
INSERT INTO public."Dipendente" VALUES (17, 17000, 17, 'magazzino', 'Lyda', 'Silkstone');
INSERT INTO public."Dipendente" VALUES (47, 20000, 13, 'ufficio', 'Gretna', 'Bolland');
INSERT INTO public."Dipendente" VALUES (160, 17000, 7, 'segreteria', 'Olly', 'Doveston');
INSERT INTO public."Dipendente" VALUES (99, 17000, 14, 'ufficio', 'Griffy', 'Greenroa');
INSERT INTO public."Dipendente" VALUES (6, 15000, 6, 'magazzino', 'Lezlie', 'Fishpool');
INSERT INTO public."Dipendente" VALUES (103, 20000, 1, 'magazzino', 'Lyell', 'Lowrance');
INSERT INTO public."Dipendente" VALUES (165, 17000, 12, 'magazzino', 'Packston', 'Firman');
INSERT INTO public."Dipendente" VALUES (148, 20000, 12, 'segreteria', 'Kathrine', 'Coleson');
INSERT INTO public."Dipendente" VALUES (46, 22000, 12, 'segreteria', 'Kellina', 'Bradly');
INSERT INTO public."Dipendente" VALUES (14, 28000, 14, 'magazzino', 'Dede', 'Avison');
INSERT INTO public."Dipendente" VALUES (140, 20000, 4, 'ufficio', 'Arvie', 'Abramsky');
INSERT INTO public."Dipendente" VALUES (31, 20000, 14, 'segreteria', 'Ruperta', 'Simmill');
INSERT INTO public."Dipendente" VALUES (123, 20000, 4, 'magazzino', 'Audre', 'Matterdace');
INSERT INTO public."Dipendente" VALUES (12, 20000, 12, 'magazzino', 'Oneida', 'Slimings');
INSERT INTO public."Dipendente" VALUES (109, 17000, 7, 'magazzino', 'Cleo', 'Crutch');
INSERT INTO public."Dipendente" VALUES (8, 17000, 8, 'magazzino', 'Meriel', 'Eliassen');
INSERT INTO public."Dipendente" VALUES (157, 20000, 4, 'segreteria', 'Dreddy', 'Aiken');
INSERT INTO public."Dipendente" VALUES (164, 20000, 11, 'ufficio', 'Taite', 'Beeden');
INSERT INTO public."Dipendente" VALUES (151, 21000, 15, 'segreteria', 'Dale', 'Huband');
INSERT INTO public."Dipendente" VALUES (20, 22000, 3, 'magazzino', 'Valerye', 'Curado');
INSERT INTO public."Dipendente" VALUES (112, 18000, 10, 'segreteria', 'Lurette', 'Orpen');
INSERT INTO public."Dipendente" VALUES (50, 28000, 16, 'ufficio', 'Clerkclaude', 'Eastabrook');
INSERT INTO public."Dipendente" VALUES (57, 20000, 6, 'ufficio', 'Amby', 'Segrott');
INSERT INTO public."Dipendente" VALUES (74, 17000, 6, 'ufficio', 'Caddric', 'Langstaff');
INSERT INTO public."Dipendente" VALUES (171, 21000, 1, 'magazzino', 'Mannie', 'Collet');
INSERT INTO public."Dipendente" VALUES (98, 20000, 13, 'segreteria', 'Alleyn', 'Bourne');
INSERT INTO public."Dipendente" VALUES (107, 15000, 5, 'segreteria', 'Candace', 'Lishmund');
INSERT INTO public."Dipendente" VALUES (52, 20000, 1, 'segreteria', 'Web', 'Boskell');
INSERT INTO public."Dipendente" VALUES (189, 20000, 2, 'magazzino', 'Dottie', 'Bales');
INSERT INTO public."Dipendente" VALUES (184, 17000, 14, 'segreteria', 'Germain', 'Croutear');
INSERT INTO public."Dipendente" VALUES (4, 21000, 4, 'magazzino', 'Amaleta', 'Speere');
INSERT INTO public."Dipendente" VALUES (18, 17000, 1, 'magazzino', 'Murvyn', 'Olanda');
INSERT INTO public."Dipendente" VALUES (58, 17000, 7, 'ufficio', 'Cirilo', 'Fieldgate');
INSERT INTO public."Dipendente" VALUES (118, 17000, 16, 'segreteria', 'Bert', 'Deetlefs');
INSERT INTO public."Dipendente" VALUES (48, 17000, 14, 'magazzino', 'Marilyn', 'Bernt');
INSERT INTO public."Dipendente" VALUES (37, 17000, 3, 'segreteria', 'Harley', 'Vercruysse');
INSERT INTO public."Dipendente" VALUES (72, 20000, 4, 'magazzino', 'Keeley', 'Mackrell');
INSERT INTO public."Dipendente" VALUES (116, 15000, 14, 'ufficio', 'Fin', 'Bontoft');
INSERT INTO public."Dipendente" VALUES (55, 21000, 4, 'ufficio', 'Ferdinand', 'Hewell');
INSERT INTO public."Dipendente" VALUES (5, 22000, 5, 'magazzino', 'Ulysses', 'Barabisch');
INSERT INTO public."Dipendente" VALUES (73, 20000, 5, 'segreteria', 'Bartolomeo', 'Jennison');
INSERT INTO public."Dipendente" VALUES (158, 18000, 5, 'ufficio', 'Anet', 'Brougham');
INSERT INTO public."Dipendente" VALUES (1, 15000, 1, 'magazzino', 'Melodee', 'Usmar');
INSERT INTO public."Dipendente" VALUES (34, 28000, 17, 'segreteria', 'Juanita', 'Brosi');
INSERT INTO public."Dipendente" VALUES (76, 28000, 8, 'segreteria', 'Willdon', 'Darter');
INSERT INTO public."Dipendente" VALUES (185, 28000, 15, 'ufficio', 'Georgine', 'Tollemache');
INSERT INTO public."Dipendente" VALUES (41, 20000, 7, 'ufficio', 'Flynn', 'Hansford');
INSERT INTO public."Dipendente" VALUES (51, 15000, 17, 'magazzino', 'Axel', 'Scrange');
INSERT INTO public."Dipendente" VALUES (135, 28000, 16, 'magazzino', 'Verne', 'Woodman');
INSERT INTO public."Dipendente" VALUES (10, 22000, 10, 'magazzino', 'Henrieta', 'Berkowitz');
INSERT INTO public."Dipendente" VALUES (535, 28000, 11, 'ufficio', 'Maëlys', 'Bycraft');
INSERT INTO public."Dipendente" VALUES (211, 15000, 17, 'ufficio', 'Mirelle', 'Lorenc');
INSERT INTO public."Dipendente" VALUES (324, 17000, 5, 'ufficio', 'Håkan', 'Roslen');
INSERT INTO public."Dipendente" VALUES (287, 18000, 18, 'magazzino', 'Mélia', 'Haworth');
INSERT INTO public."Dipendente" VALUES (550, 17000, 6, 'ufficio', 'Gaëlle', 'Folder');
INSERT INTO public."Dipendente" VALUES (263, 20000, 9, 'segreteria', 'Åsa', 'Pedden');
INSERT INTO public."Dipendente" VALUES (458, 20000, 11, 'magazzino', 'Joséphine', 'Lazell');
INSERT INTO public."Dipendente" VALUES (599, 17000, 8, 'magazzino', 'Adélaïde', 'Angear');
INSERT INTO public."Dipendente" VALUES (420, 18000, 20, 'ufficio', 'Mélanie', 'Flobert');
INSERT INTO public."Dipendente" VALUES (212, 15000, 17, 'magazzino', 'Ned', 'Leggatt');
INSERT INTO public."Dipendente" VALUES (431, 15000, 26, 'magazzino', 'Göran', 'Hawkeridge');
INSERT INTO public."Dipendente" VALUES (598, 20000, 18, 'ufficio', 'Athéna', 'Tythacott');
INSERT INTO public."Dipendente" VALUES (382, 20000, 27, 'magazzino', 'Andrée', 'Grewer');
INSERT INTO public."Dipendente" VALUES (443, 21000, 15, 'magazzino', 'Géraldine', 'Creeghan');
INSERT INTO public."Dipendente" VALUES (425, 20000, 14, 'ufficio', 'Kallisté', 'Farnan');
INSERT INTO public."Dipendente" VALUES (519, 18000, 27, 'segreteria', 'Vénus', 'Strongman');
INSERT INTO public."Dipendente" VALUES (573, 18000, 3, 'segreteria', 'Hélène', 'Benstead');
INSERT INTO public."Dipendente" VALUES (357, 22000, 15, 'ufficio', 'Cléopatre', 'Braunston');
INSERT INTO public."Dipendente" VALUES (358, 15000, 12, 'magazzino', 'Hélène', 'Flood');
INSERT INTO public."Dipendente" VALUES (224, 28000, 9, 'segreteria', 'Cathy', 'Edgley');
INSERT INTO public."Dipendente" VALUES (516, 15000, 7, 'segreteria', 'Andrée', 'Pleuman');
INSERT INTO public."Dipendente" VALUES (438, 17000, 18, 'segreteria', 'Annotée', 'Iacobetto');
INSERT INTO public."Dipendente" VALUES (503, 20000, 12, 'magazzino', 'Alizée', 'Tonnesen');
INSERT INTO public."Dipendente" VALUES (575, 17000, 14, 'magazzino', 'Dorothée', 'McElory');
INSERT INTO public."Dipendente" VALUES (619, 20000, 25, 'ufficio', 'Méryl', 'Roy');
INSERT INTO public."Dipendente" VALUES (625, 21000, 4, 'ufficio', 'Annotés', 'MacAllaster');
INSERT INTO public."Dipendente" VALUES (596, 28000, 2, 'magazzino', 'Alizée', 'Grinley');
INSERT INTO public."Dipendente" VALUES (544, 20000, 17, 'ufficio', 'Yáo', 'Couves');
INSERT INTO public."Dipendente" VALUES (579, 17000, 15, 'magazzino', 'Agnès', 'Costley');
INSERT INTO public."Dipendente" VALUES (518, 22000, 26, 'magazzino', 'Zhì', 'Bell');
INSERT INTO public."Dipendente" VALUES (564, 20000, 21, 'segreteria', 'Marie-thérèse', 'Mangeot');
INSERT INTO public."Dipendente" VALUES (569, 20000, 8, 'magazzino', 'Lorène', 'Wrintmore');
INSERT INTO public."Dipendente" VALUES (566, 21000, 24, 'magazzino', 'Annotés', 'Botley');
INSERT INTO public."Dipendente" VALUES (591, 20000, 6, 'segreteria', 'Lén', 'Temperley');
INSERT INTO public."Dipendente" VALUES (529, 20000, 4, 'ufficio', 'Clémentine', 'Nickoles');
INSERT INTO public."Dipendente" VALUES (629, 20000, 13, 'magazzino', 'Léandre', 'Josephson');
INSERT INTO public."Dipendente" VALUES (578, 20000, 18, 'magazzino', 'Ophélie', 'Heinonen');
INSERT INTO public."Dipendente" VALUES (593, 20000, 7, 'magazzino', 'Maéna', 'Peare');
INSERT INTO public."Dipendente" VALUES (561, 22000, 24, 'segreteria', 'Mélinda', 'Cundy');
INSERT INTO public."Dipendente" VALUES (522, 28000, 20, 'segreteria', 'Cécilia', 'Savile');
INSERT INTO public."Dipendente" VALUES (558, 15000, 24, 'segreteria', 'Personnalisée', 'Matashkin');
INSERT INTO public."Dipendente" VALUES (283, 17000, 23, 'magazzino', 'Valérie', 'Stanyland');
INSERT INTO public."Dipendente" VALUES (539, 20000, 19, 'magazzino', 'Méline', 'Crackett');
INSERT INTO public."Dipendente" VALUES (275, 20000, 11, 'segreteria', 'Gaïa', 'Iacoviello');
INSERT INTO public."Dipendente" VALUES (536, 15000, 9, 'magazzino', 'Åslög', 'Breydin');
INSERT INTO public."Dipendente" VALUES (513, 20000, 1, 'segreteria', 'Håkan', 'Spriggen');
INSERT INTO public."Dipendente" VALUES (562, 18000, 3, 'ufficio', 'Östen', 'Zavattiero');
INSERT INTO public."Dipendente" VALUES (267, 15000, 17, 'ufficio', 'Clémentine', 'Dennert');
INSERT INTO public."Dipendente" VALUES (326, 15000, 9, 'segreteria', 'Maëlys', 'Zorzini');
INSERT INTO public."Dipendente" VALUES (347, 20000, 5, 'segreteria', 'Björn', 'Wingate');
INSERT INTO public."Dipendente" VALUES (603, 20000, 2, 'segreteria', 'Lauréna', 'Haynesford');
INSERT INTO public."Dipendente" VALUES (526, 22000, 6, 'ufficio', 'Agnès', 'Ditch');
INSERT INTO public."Dipendente" VALUES (568, 15000, 9, 'ufficio', 'Gaétane', 'Gleaves');
INSERT INTO public."Dipendente" VALUES (288, 20000, 2, 'segreteria', 'Styrbjörn', 'Mattielli');
INSERT INTO public."Dipendente" VALUES (423, 28000, 2, 'ufficio', 'Estée', 'Deeman');
INSERT INTO public."Dipendente" VALUES (464, 15000, 17, 'magazzino', 'Pål', 'Caiger');
INSERT INTO public."Dipendente" VALUES (525, 21000, 1, 'segreteria', 'Mén', 'Lowson');
INSERT INTO public."Dipendente" VALUES (517, 20000, 26, 'ufficio', 'Mélia', 'Comolli');
INSERT INTO public."Dipendente" VALUES (460, 20000, 19, 'magazzino', 'Béatrice', 'Antony');
INSERT INTO public."Dipendente" VALUES (197, 20000, 25, 'magazzino', 'Nikkie', 'Vigneron');
INSERT INTO public."Dipendente" VALUES (262, 20000, 4, 'magazzino', 'Táng', 'Loton');
INSERT INTO public."Dipendente" VALUES (285, 15000, 25, 'segreteria', 'Estée', 'Staries');
INSERT INTO public."Dipendente" VALUES (229, 22000, 23, 'magazzino', 'Warner', 'Ewers');
INSERT INTO public."Dipendente" VALUES (377, 20000, 5, 'magazzino', 'Eugénie', 'Vanacci');
INSERT INTO public."Dipendente" VALUES (430, 28000, 17, 'ufficio', 'Gaïa', 'Ivimy');
INSERT INTO public."Dipendente" VALUES (379, 20000, 9, 'magazzino', 'Agnès', 'Ropkes');
INSERT INTO public."Dipendente" VALUES (273, 28000, 18, 'ufficio', 'Célestine', 'Oblein');
INSERT INTO public."Dipendente" VALUES (344, 20000, 3, 'segreteria', 'Thérèsa', 'Krop');
INSERT INTO public."Dipendente" VALUES (467, 20000, 26, 'magazzino', 'Almérinda', 'Gartsyde');
INSERT INTO public."Dipendente" VALUES (309, 21000, 14, 'ufficio', 'Yénora', 'Colhoun');
INSERT INTO public."Dipendente" VALUES (274, 15000, 5, 'magazzino', 'Néhémie', 'Goscomb');
INSERT INTO public."Dipendente" VALUES (490, 21000, 19, 'ufficio', 'Andréa', 'Penner');
INSERT INTO public."Dipendente" VALUES (239, 21000, 18, 'segreteria', 'Rab', 'Lunn');
INSERT INTO public."Dipendente" VALUES (330, 20000, 13, 'ufficio', 'Loïs', 'Hatchman');
INSERT INTO public."Dipendente" VALUES (342, 28000, 2, 'ufficio', 'Yáo', 'MacSwayde');
INSERT INTO public."Dipendente" VALUES (343, 15000, 8, 'magazzino', 'Réjane', 'Overill');
INSERT INTO public."Dipendente" VALUES (514, 17000, 8, 'ufficio', 'Josée', 'Laugharne');
INSERT INTO public."Dipendente" VALUES (486, 22000, 11, 'segreteria', 'Anaëlle', 'Winskill');
INSERT INTO public."Dipendente" VALUES (409, 20000, 12, 'ufficio', 'Torbjörn', 'Skehens');
INSERT INTO public."Dipendente" VALUES (590, 15000, 4, 'magazzino', 'Clélia', 'Scolding');
INSERT INTO public."Dipendente" VALUES (581, 21000, 23, 'magazzino', 'Desirée', 'Fielders');
INSERT INTO public."Dipendente" VALUES (534, 20000, 4, 'segreteria', 'Pål', 'Weine');
INSERT INTO public."Dipendente" VALUES (551, 21000, 27, 'magazzino', 'Josée', 'Puddicombe');
INSERT INTO public."Dipendente" VALUES (208, 17000, 14, 'magazzino', 'Susann', 'Twidell');
INSERT INTO public."Dipendente" VALUES (269, 21000, 15, 'segreteria', 'Aurélie', 'Audiss');
INSERT INTO public."Dipendente" VALUES (444, 22000, 16, 'segreteria', 'Gisèle', 'Guiraud');
INSERT INTO public."Dipendente" VALUES (537, 20000, 1, 'segreteria', 'Gwenaëlle', 'Huffey');
INSERT INTO public."Dipendente" VALUES (567, 22000, 21, 'segreteria', 'Garçon', 'Moss');
INSERT INTO public."Dipendente" VALUES (501, 15000, 9, 'segreteria', 'Lóng', 'Hurdis');
INSERT INTO public."Dipendente" VALUES (618, 15000, 13, 'segreteria', 'Cécilia', 'Girth');
INSERT INTO public."Dipendente" VALUES (465, 20000, 19, 'magazzino', 'Gisèle', 'Gagg');
INSERT INTO public."Dipendente" VALUES (531, 21000, 6, 'segreteria', 'Marlène', 'Maydwell');
INSERT INTO public."Dipendente" VALUES (572, 22000, 18, 'magazzino', 'Léonie', 'Dispencer');
INSERT INTO public."Dipendente" VALUES (277, 20000, 10, 'magazzino', 'Aurélie', 'Stavers');
INSERT INTO public."Dipendente" VALUES (361, 21000, 12, 'magazzino', 'Régine', 'Larimer');
INSERT INTO public."Dipendente" VALUES (289, 17000, 19, 'ufficio', 'Pélagie', 'Asbrey');
INSERT INTO public."Dipendente" VALUES (353, 20000, 1, 'segreteria', 'Intéressant', 'Wallege');
INSERT INTO public."Dipendente" VALUES (608, 22000, 19, 'magazzino', 'Salomé', 'Goldie');
INSERT INTO public."Dipendente" VALUES (360, 17000, 24, 'magazzino', 'Lén', 'Peotz');
INSERT INTO public."Dipendente" VALUES (203, 17000, 19, 'magazzino', 'Jayme', 'Bernardes');
INSERT INTO public."Dipendente" VALUES (214, 18000, 13, 'magazzino', 'Leif', 'Rosenqvist');
INSERT INTO public."Dipendente" VALUES (331, 17000, 2, 'magazzino', 'Mélodie', 'Southwick');
INSERT INTO public."Dipendente" VALUES (305, 28000, 3, 'segreteria', 'Erwéi', 'Rosengart');
INSERT INTO public."Dipendente" VALUES (266, 28000, 19, 'segreteria', 'Faîtes', 'Taggart');
INSERT INTO public."Dipendente" VALUES (293, 20000, 4, 'magazzino', 'Léonore', 'Fairlie');
INSERT INTO public."Dipendente" VALUES (376, 15000, 13, 'magazzino', 'Esbjörn', 'Northcote');
INSERT INTO public."Dipendente" VALUES (614, 20000, 21, 'magazzino', 'Clémence', 'Grelak');
INSERT INTO public."Dipendente" VALUES (634, 20000, 17, 'ufficio', 'Stéphanie', 'Golborne');
INSERT INTO public."Dipendente" VALUES (411, 20000, 24, 'segreteria', 'Médiamass', 'Beckers');
INSERT INTO public."Dipendente" VALUES (297, 15000, 27, 'segreteria', 'Yè', 'Cleugh');
INSERT INTO public."Dipendente" VALUES (417, 17000, 9, 'ufficio', 'Personnalisée', 'Knevet');
INSERT INTO public."Dipendente" VALUES (456, 28000, 21, 'magazzino', 'Andréanne', 'Ibbison');
INSERT INTO public."Dipendente" VALUES (383, 17000, 6, 'magazzino', 'Naéva', 'Cauley');
INSERT INTO public."Dipendente" VALUES (433, 17000, 1, 'ufficio', 'Geneviève', 'Goodbody');
INSERT INTO public."Dipendente" VALUES (322, 18000, 27, 'magazzino', 'Gaétane', 'Harris');
INSERT INTO public."Dipendente" VALUES (244, 17000, 10, 'ufficio', 'Léana', 'Poole');
INSERT INTO public."Dipendente" VALUES (434, 17000, 6, 'magazzino', 'Maëline', 'Clorley');
INSERT INTO public."Dipendente" VALUES (479, 17000, 4, 'magazzino', 'Daphnée', 'Bisiker');
INSERT INTO public."Dipendente" VALUES (476, 20000, 18, 'magazzino', 'Méghane', 'Van Der Hoog');
INSERT INTO public."Dipendente" VALUES (373, 20000, 3, 'magazzino', 'Françoise', 'Kenset');
INSERT INTO public."Dipendente" VALUES (213, 20000, 1, 'segreteria', 'Elisa', 'Kave');
INSERT INTO public."Dipendente" VALUES (191, 15000, 6, 'magazzino', 'Dreddy', 'Tweddle');
INSERT INTO public."Dipendente" VALUES (427, 20000, 21, 'ufficio', 'Thérèsa', 'Pilkington');
INSERT INTO public."Dipendente" VALUES (359, 20000, 15, 'segreteria', 'Laurélie', 'McShee');
INSERT INTO public."Dipendente" VALUES (320, 21000, 9, 'segreteria', 'Lyséa', 'Evitt');
INSERT INTO public."Dipendente" VALUES (493, 20000, 6, 'ufficio', 'Bénédicte', 'Sazio');
INSERT INTO public."Dipendente" VALUES (329, 18000, 14, 'segreteria', 'Régine', 'Torrent');
INSERT INTO public."Dipendente" VALUES (227, 17000, 18, 'segreteria', 'Grissel', 'Meneghelli');
INSERT INTO public."Dipendente" VALUES (640, 20000, 17, 'magazzino', 'Gaëlle', 'Lakenton');
INSERT INTO public."Dipendente" VALUES (556, 21000, 14, 'ufficio', 'Lorène', 'Pentycross');
INSERT INTO public."Dipendente" VALUES (553, 20000, 5, 'ufficio', 'Laurène', 'Sapseed');
INSERT INTO public."Dipendente" VALUES (607, 20000, 27, 'ufficio', 'Geneviève', 'Aikenhead');
INSERT INTO public."Dipendente" VALUES (391, 18000, 9, 'magazzino', 'Loïca', 'Verchambre');
INSERT INTO public."Dipendente" VALUES (583, 15000, 21, 'magazzino', 'Kù', 'Godthaab');
INSERT INTO public."Dipendente" VALUES (533, 15000, 27, 'magazzino', 'Eléonore', 'Clatworthy');
INSERT INTO public."Dipendente" VALUES (623, 17000, 25, 'magazzino', 'Mahélie', 'Pund');
INSERT INTO public."Dipendente" VALUES (616, 17000, 11, 'ufficio', 'Wá', 'Eldrid');
INSERT INTO public."Dipendente" VALUES (527, 15000, 22, 'magazzino', 'Maëline', 'Testro');
INSERT INTO public."Dipendente" VALUES (530, 17000, 23, 'magazzino', 'Cléopatre', 'Sagar');
INSERT INTO public."Dipendente" VALUES (617, 21000, 6, 'magazzino', 'Ruò', 'Wooff');
INSERT INTO public."Dipendente" VALUES (397, 17000, 2, 'magazzino', 'Annotée', 'Verring');
INSERT INTO public."Dipendente" VALUES (595, 21000, 1, 'ufficio', 'Maëline', 'Bennison');
INSERT INTO public."Dipendente" VALUES (472, 20000, 10, 'magazzino', 'Cinéma', 'Guidelli');
INSERT INTO public."Dipendente" VALUES (463, 28000, 20, 'magazzino', 'Thérèsa', 'Jouandet');
INSERT INTO public."Dipendente" VALUES (612, 28000, 20, 'segreteria', 'Aí', 'Salisbury');
INSERT INTO public."Dipendente" VALUES (504, 17000, 9, 'segreteria', 'Intéressant', 'Mattioni');
INSERT INTO public."Dipendente" VALUES (470, 22000, 12, 'magazzino', 'Léane', 'Nind');
INSERT INTO public."Dipendente" VALUES (541, 28000, 27, 'ufficio', 'Cécile', 'Stiffkins');
INSERT INTO public."Dipendente" VALUES (511, 22000, 17, 'ufficio', 'Séréna', 'Ivatt');
INSERT INTO public."Dipendente" VALUES (584, 15000, 10, 'magazzino', 'Yénora', 'MacGettigen');
INSERT INTO public."Dipendente" VALUES (509, 17000, 7, 'magazzino', 'Vérane', 'Mattocks');
INSERT INTO public."Dipendente" VALUES (604, 17000, 11, 'ufficio', 'Marie-ève', 'Rucklesse');
INSERT INTO public."Dipendente" VALUES (633, 18000, 15, 'segreteria', 'Östen', 'Wink');
INSERT INTO public."Dipendente" VALUES (637, 21000, 8, 'magazzino', 'Léane', 'McGonagle');
INSERT INTO public."Dipendente" VALUES (630, 17000, 19, 'segreteria', 'Lén', 'Milland');
INSERT INTO public."Dipendente" VALUES (638, 28000, 19, 'magazzino', 'Intéressant', 'Skellington');
INSERT INTO public."Dipendente" VALUES (636, 17000, 12, 'magazzino', 'Mélinda', 'Hazlehurst');
INSERT INTO public."Dipendente" VALUES (631, 21000, 15, 'ufficio', 'Mélina', 'Ludlom');
INSERT INTO public."Dipendente" VALUES (635, 20000, 9, 'magazzino', 'Mélys', 'Skeel');
INSERT INTO public."Dipendente" VALUES (639, 15000, 6, 'magazzino', 'Intéressant', 'Niess');
INSERT INTO public."Dipendente" VALUES (632, 22000, 26, 'magazzino', 'Danièle', 'Treagus');
INSERT INTO public."Dipendente" VALUES (600, 21000, 13, 'segreteria', 'Clémentine', 'Teresia');
INSERT INTO public."Dipendente" VALUES (284, 28000, 16, 'magazzino', 'Personnalisée', 'Petyakov');
INSERT INTO public."Dipendente" VALUES (314, 17000, 11, 'segreteria', 'Maëlyss', 'Bellinger');
INSERT INTO public."Dipendente" VALUES (222, 17000, 15, 'ufficio', 'Daryl', 'St Leger');
INSERT INTO public."Dipendente" VALUES (247, 20000, 21, 'ufficio', 'Hélèna', 'Pahl');
INSERT INTO public."Dipendente" VALUES (570, 17000, 26, 'segreteria', 'Kù', 'Willoughley');
INSERT INTO public."Dipendente" VALUES (543, 20000, 19, 'segreteria', 'Ruò', 'Wildbore');
INSERT INTO public."Dipendente" VALUES (234, 15000, 27, 'ufficio', 'Evyn', 'Sains');
INSERT INTO public."Dipendente" VALUES (257, 20000, 8, 'ufficio', 'Personnalisée', 'Picker');
INSERT INTO public."Dipendente" VALUES (415, 15000, 4, 'ufficio', 'Bérangère', 'Dykes');
INSERT INTO public."Dipendente" VALUES (300, 21000, 14, 'segreteria', 'Kallisté', 'De Roberto');
INSERT INTO public."Dipendente" VALUES (393, 17000, 10, 'magazzino', 'Gérald', 'Hodjetts');
INSERT INTO public."Dipendente" VALUES (312, 20000, 18, 'ufficio', 'Dà', 'Moyer');
INSERT INTO public."Dipendente" VALUES (524, 17000, 10, 'magazzino', 'Maïlys', 'Broggelli');
INSERT INTO public."Dipendente" VALUES (260, 22000, 11, 'ufficio', 'Magdalène', 'Hegarty');
INSERT INTO public."Dipendente" VALUES (452, 20000, 24, 'magazzino', 'Åke', 'Jori');
INSERT INTO public."Dipendente" VALUES (252, 17000, 15, 'ufficio', 'Laurélie', 'Beresfore');
INSERT INTO public."Dipendente" VALUES (445, 15000, 27, 'ufficio', 'Aí', 'Gussin');
INSERT INTO public."Dipendente" VALUES (339, 20000, 10, 'ufficio', 'Liè', 'Bjorkan');
INSERT INTO public."Dipendente" VALUES (586, 18000, 26, 'magazzino', 'Véronique', 'Tawton');
INSERT INTO public."Dipendente" VALUES (296, 22000, 20, 'magazzino', 'Camélia', 'Beveredge');
INSERT INTO public."Dipendente" VALUES (246, 15000, 26, 'ufficio', 'Océane', 'Kertess');
INSERT INTO public."Dipendente" VALUES (571, 21000, 27, 'ufficio', 'Lyséa', 'Baudinot');
INSERT INTO public."Dipendente" VALUES (588, 17000, 11, 'magazzino', 'Maïlys', 'Gudgion');
INSERT INTO public."Dipendente" VALUES (315, 21000, 3, 'ufficio', 'Bérangère', 'Beagan');
INSERT INTO public."Dipendente" VALUES (442, 17000, 13, 'ufficio', 'Maïwenn', 'Dumphy');
INSERT INTO public."Dipendente" VALUES (521, 17000, 9, 'magazzino', 'Mélys', 'Tatam');
INSERT INTO public."Dipendente" VALUES (440, 21000, 9, 'magazzino', 'Adèle', 'Cherrison');
INSERT INTO public."Dipendente" VALUES (199, 21000, 26, 'magazzino', 'Lissy', 'Burgum');
INSERT INTO public."Dipendente" VALUES (582, 22000, 16, 'magazzino', 'Yú', 'Bonifazio');
INSERT INTO public."Dipendente" VALUES (193, 17000, 23, 'magazzino', 'Rosalia', 'Lorne');
INSERT INTO public."Dipendente" VALUES (205, 15000, 19, 'magazzino', 'Kip', 'Shrimpton');
INSERT INTO public."Dipendente" VALUES (231, 20000, 4, 'ufficio', 'Raine', 'Cutriss');
INSERT INTO public."Dipendente" VALUES (201, 18000, 2, 'magazzino', 'Ruthann', 'Stradling');
INSERT INTO public."Dipendente" VALUES (488, 20000, 8, 'magazzino', 'Clémence', 'Baumann');
INSERT INTO public."Dipendente" VALUES (424, 15000, 2, 'ufficio', 'Adélie', 'Congram');
INSERT INTO public."Dipendente" VALUES (253, 21000, 23, 'ufficio', 'Anaé', 'Simonin');
INSERT INTO public."Dipendente" VALUES (292, 20000, 17, 'ufficio', 'Maëlle', 'Billo');
INSERT INTO public."Dipendente" VALUES (555, 17000, 12, 'segreteria', 'Maëlann', 'McAlees');
INSERT INTO public."Dipendente" VALUES (605, 28000, 4, 'magazzino', 'Véronique', 'Ledwich');
INSERT INTO public."Dipendente" VALUES (624, 17000, 9, 'segreteria', 'Clélia', 'Fallens');
INSERT INTO public."Dipendente" VALUES (381, 15000, 14, 'magazzino', 'Aloïs', 'Ure');
INSERT INTO public."Dipendente" VALUES (270, 20000, 12, 'ufficio', 'Clémence', 'Rapinett');
INSERT INTO public."Dipendente" VALUES (258, 17000, 5, 'ufficio', 'Cinéma', 'Caton');
INSERT INTO public."Dipendente" VALUES (294, 17000, 26, 'segreteria', 'Judicaël', 'Lovelace');
INSERT INTO public."Dipendente" VALUES (560, 20000, 11, 'magazzino', 'Eloïse', 'Di Carli');
INSERT INTO public."Dipendente" VALUES (368, 15000, 21, 'magazzino', 'Marie-hélène', 'Moakler');
INSERT INTO public."Dipendente" VALUES (279, 21000, 7, 'ufficio', 'Régine', 'Bestwick');
INSERT INTO public."Dipendente" VALUES (505, 21000, 4, 'ufficio', 'Gaïa', 'Lantaff');
INSERT INTO public."Dipendente" VALUES (609, 20000, 10, 'segreteria', 'Léone', 'Rayhill');
INSERT INTO public."Dipendente" VALUES (480, 28000, 13, 'segreteria', 'Lorène', 'Angliss');
INSERT INTO public."Dipendente" VALUES (528, 20000, 1, 'segreteria', 'Sòng', 'Crowdson');
INSERT INTO public."Dipendente" VALUES (374, 17000, 13, 'magazzino', 'Åke', 'Boal');
INSERT INTO public."Dipendente" VALUES (256, 15000, 16, 'ufficio', 'Gisèle', 'Tathacott');
INSERT INTO public."Dipendente" VALUES (241, 15000, 16, 'magazzino', 'Rina', 'Croome');
INSERT INTO public."Dipendente" VALUES (426, 22000, 13, 'ufficio', 'Annotée', 'Sposito');
INSERT INTO public."Dipendente" VALUES (332, 28000, 26, 'segreteria', 'Laurélie', 'Darlington');
INSERT INTO public."Dipendente" VALUES (390, 22000, 25, 'magazzino', 'Lén', 'Triner');
INSERT INTO public."Dipendente" VALUES (483, 20000, 27, 'segreteria', 'Yè', 'Caiger');
INSERT INTO public."Dipendente" VALUES (388, 17000, 22, 'magazzino', 'Zhì', 'Garstang');
INSERT INTO public."Dipendente" VALUES (510, 21000, 20, 'segreteria', 'Desirée', 'Andrusov');
INSERT INTO public."Dipendente" VALUES (394, 28000, 22, 'magazzino', 'Andréa', 'Craker');
INSERT INTO public."Dipendente" VALUES (502, 20000, 19, 'ufficio', 'Yè', 'Peet');
INSERT INTO public."Dipendente" VALUES (459, 21000, 25, 'magazzino', 'Mélina', 'Birrell');
INSERT INTO public."Dipendente" VALUES (278, 17000, 12, 'segreteria', 'Maëlyss', 'Carling');
INSERT INTO public."Dipendente" VALUES (621, 17000, 6, 'segreteria', 'Renée', 'Chaplain');
INSERT INTO public."Dipendente" VALUES (216, 17000, 9, 'ufficio', 'Xymenes', 'Mostyn');
INSERT INTO public."Dipendente" VALUES (348, 18000, 5, 'ufficio', 'Yóu', 'Willacot');
INSERT INTO public."Dipendente" VALUES (337, 15000, 5, 'magazzino', 'Björn', 'Ruppel');
INSERT INTO public."Dipendente" VALUES (378, 18000, 8, 'magazzino', 'Andrée', 'Strongman');
INSERT INTO public."Dipendente" VALUES (219, 20000, 1, 'ufficio', 'Inge', 'Koop');
INSERT INTO public."Dipendente" VALUES (408, 15000, 11, 'segreteria', 'Mélinda', 'Firmager');
INSERT INTO public."Dipendente" VALUES (450, 22000, 16, 'segreteria', 'Maïwenn', 'Cowdery');
INSERT INTO public."Dipendente" VALUES (610, 17000, 24, 'ufficio', 'Danièle', 'Chattoe');
INSERT INTO public."Dipendente" VALUES (597, 15000, 19, 'segreteria', 'Jú', 'Huxley');
INSERT INTO public."Dipendente" VALUES (471, 18000, 16, 'magazzino', 'Gaïa', 'Galilee');
INSERT INTO public."Dipendente" VALUES (576, 28000, 5, 'magazzino', 'Laïla', 'Milmore');
INSERT INTO public."Dipendente" VALUES (548, 15000, 12, 'magazzino', 'Magdalène', 'Dotson');
INSERT INTO public."Dipendente" VALUES (441, 17000, 23, 'segreteria', 'Dorothée', 'Buckerfield');
INSERT INTO public."Dipendente" VALUES (355, 17000, 25, 'magazzino', 'Bécassine', 'Olsson');
INSERT INTO public."Dipendente" VALUES (311, 15000, 8, 'segreteria', 'Yáo', 'McKeighen');
INSERT INTO public."Dipendente" VALUES (306, 15000, 21, 'ufficio', 'Sòng', 'O''Farris');
INSERT INTO public."Dipendente" VALUES (549, 20000, 11, 'segreteria', 'Marlène', 'Peschka');
INSERT INTO public."Dipendente" VALUES (366, 21000, 19, 'magazzino', 'Cunégonde', 'Isherwood');
INSERT INTO public."Dipendente" VALUES (333, 20000, 27, 'ufficio', 'Desirée', 'Arnall');
INSERT INTO public."Dipendente" VALUES (323, 20000, 5, 'segreteria', 'Joséphine', 'Iianon');
INSERT INTO public."Dipendente" VALUES (235, 20000, 10, 'magazzino', 'Lloyd', 'O Connell');
INSERT INTO public."Dipendente" VALUES (542, 15000, 22, 'magazzino', 'Aí', 'Claypoole');
INSERT INTO public."Dipendente" VALUES (346, 15000, 27, 'magazzino', 'Pò', 'Drever');
INSERT INTO public."Dipendente" VALUES (413, 21000, 21, 'ufficio', 'Loïca', 'Coleby');
INSERT INTO public."Dipendente" VALUES (365, 17000, 18, 'magazzino', 'Sélène', 'Gyorgy');
INSERT INTO public."Dipendente" VALUES (435, 21000, 14, 'segreteria', 'Laurène', 'Broadfoot');
INSERT INTO public."Dipendente" VALUES (601, 22000, 7, 'ufficio', 'Lucrèce', 'Searl');
INSERT INTO public."Dipendente" VALUES (367, 28000, 5, 'magazzino', 'Garçon', 'Dilawey');
INSERT INTO public."Dipendente" VALUES (356, 21000, 25, 'segreteria', 'Marie-françoise', 'Milch');
INSERT INTO public."Dipendente" VALUES (350, 17000, 23, 'segreteria', 'Méghane', 'Carwithim');
INSERT INTO public."Dipendente" VALUES (210, 22000, 2, 'magazzino', 'Mirabella', 'Dobkin');
INSERT INTO public."Dipendente" VALUES (209, 21000, 2, 'magazzino', 'Giulia', 'Crampton');
INSERT INTO public."Dipendente" VALUES (523, 20000, 5, 'ufficio', 'Estève', 'Samson');
INSERT INTO public."Dipendente" VALUES (587, 20000, 14, 'magazzino', 'Börje', 'Dubber');
INSERT INTO public."Dipendente" VALUES (580, 17000, 16, 'magazzino', 'Josée', 'Gludor');
INSERT INTO public."Dipendente" VALUES (563, 15000, 11, 'magazzino', 'Aloïs', 'Kingswood');
INSERT INTO public."Dipendente" VALUES (395, 15000, 15, 'magazzino', 'Loïs', 'Spurdens');
INSERT INTO public."Dipendente" VALUES (399, 21000, 26, 'segreteria', 'Marie-noël', 'Cawsy');
INSERT INTO public."Dipendente" VALUES (449, 21000, 26, 'magazzino', 'Naëlle', 'Drillingcourt');
INSERT INTO public."Dipendente" VALUES (466, 20000, 15, 'magazzino', 'Ráo', 'Dysert');
INSERT INTO public."Dipendente" VALUES (352, 15000, 22, 'magazzino', 'Pò', 'Blazeby');
INSERT INTO public."Dipendente" VALUES (414, 28000, 25, 'ufficio', 'Célestine', 'Carrington');
INSERT INTO public."Dipendente" VALUES (370, 20000, 26, 'magazzino', 'Jú', 'Kloisner');
INSERT INTO public."Dipendente" VALUES (228, 21000, 19, 'ufficio', 'Kaela', 'Joiner');
INSERT INTO public."Dipendente" VALUES (268, 20000, 27, 'magazzino', 'Célia', 'Moretto');
INSERT INTO public."Dipendente" VALUES (496, 15000, 14, 'ufficio', 'Maëline', 'Tranckle');
INSERT INTO public."Dipendente" VALUES (498, 17000, 12, 'segreteria', 'Wá', 'Deverill');
INSERT INTO public."Dipendente" VALUES (369, 20000, 18, 'magazzino', 'Gaëlle', 'Ashman');
INSERT INTO public."Dipendente" VALUES (532, 28000, 13, 'ufficio', 'Bérénice', 'Fuchs');
INSERT INTO public."Dipendente" VALUES (318, 20000, 13, 'ufficio', 'Maëlyss', 'Tigwell');
INSERT INTO public."Dipendente" VALUES (271, 17000, 19, 'magazzino', 'Sélène', 'Penticost');
INSERT INTO public."Dipendente" VALUES (506, 22000, 19, 'magazzino', 'Börje', 'Marquet');
INSERT INTO public."Dipendente" VALUES (613, 15000, 24, 'ufficio', 'Célestine', 'O''Donnell');
INSERT INTO public."Dipendente" VALUES (547, 22000, 24, 'ufficio', 'Mårten', 'Semechik');
INSERT INTO public."Dipendente" VALUES (400, 22000, 1, 'ufficio', 'Clélia', 'Oliveti');
INSERT INTO public."Dipendente" VALUES (403, 20000, 13, 'ufficio', 'Loïca', 'Pawelek');
INSERT INTO public."Dipendente" VALUES (520, 20000, 18, 'ufficio', 'Mårten', 'Jurkowski');
INSERT INTO public."Dipendente" VALUES (421, 20000, 3, 'ufficio', 'Kévina', 'Brunt');
INSERT INTO public."Dipendente" VALUES (606, 15000, 26, 'segreteria', 'Gisèle', 'Laffling');
INSERT INTO public."Dipendente" VALUES (577, 15000, 23, 'magazzino', 'Sòng', 'Carratt');
INSERT INTO public."Dipendente" VALUES (594, 17000, 16, 'segreteria', 'Judicaël', 'Kensall');
INSERT INTO public."Dipendente" VALUES (286, 20000, 8, 'ufficio', 'Stéphanie', 'Wressell');
INSERT INTO public."Dipendente" VALUES (540, 17000, 19, 'segreteria', 'Maëlla', 'Formoy');
INSERT INTO public."Dipendente" VALUES (236, 22000, 18, 'segreteria', 'Mellisent', 'MacBean');
INSERT INTO public."Dipendente" VALUES (407, 28000, 19, 'magazzino', 'Mårten', 'Loughrey');
INSERT INTO public."Dipendente" VALUES (345, 28000, 5, 'ufficio', 'Görel', 'Persicke');
INSERT INTO public."Dipendente" VALUES (250, 21000, 16, 'ufficio', 'Noémie', 'Hartright');
INSERT INTO public."Dipendente" VALUES (491, 22000, 16, 'magazzino', 'Erwéi', 'Messager');
INSERT INTO public."Dipendente" VALUES (364, 20000, 20, 'magazzino', 'Gaétane', 'Cowland');
INSERT INTO public."Dipendente" VALUES (387, 20000, 3, 'magazzino', 'Eléonore', 'Taill');
INSERT INTO public."Dipendente" VALUES (495, 28000, 6, 'segreteria', 'Frédérique', 'Tustin');
INSERT INTO public."Dipendente" VALUES (507, 15000, 25, 'segreteria', 'Liè', 'Keneleyside');
INSERT INTO public."Dipendente" VALUES (338, 20000, 2, 'segreteria', 'Mahélie', 'Braisby');
INSERT INTO public."Dipendente" VALUES (242, 20000, 3, 'segreteria', 'Bjorn', 'Whittick');
INSERT INTO public."Dipendente" VALUES (545, 17000, 27, 'magazzino', 'Mårten', 'Linfield');
INSERT INTO public."Dipendente" VALUES (611, 21000, 12, 'magazzino', 'Médiamass', 'Faulconbridge');
INSERT INTO public."Dipendente" VALUES (206, 20000, 20, 'magazzino', 'Miranda', 'Griffithe');
INSERT INTO public."Dipendente" VALUES (538, 18000, 12, 'ufficio', 'Marlène', 'Gerhartz');
INSERT INTO public."Dipendente" VALUES (574, 20000, 22, 'ufficio', 'Bécassine', 'Shute');
INSERT INTO public."Dipendente" VALUES (546, 21000, 25, 'segreteria', 'Alizée', 'Noblet');
INSERT INTO public."Dipendente" VALUES (237, 20000, 21, 'ufficio', 'Karissa', 'Lough');
INSERT INTO public."Dipendente" VALUES (602, 18000, 3, 'magazzino', 'Athéna', 'Harbach');
INSERT INTO public."Dipendente" VALUES (439, 17000, 4, 'ufficio', 'Félicie', 'Neild');
INSERT INTO public."Dipendente" VALUES (406, 17000, 9, 'ufficio', 'Maéna', 'Junkison');


--
-- TOC entry 3614 (class 0 OID 18548)
-- Dependencies: 255
-- Data for Name: Filiale; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO public."Filiale" VALUES (3, 'Alabama', 'Birmingham', 'Cambridge', '35205', 53);
INSERT INTO public."Filiale" VALUES (17, 'Alabama', 'Birmingham', 'Longview', '35290', 52);
INSERT INTO public."Filiale" VALUES (5, 'Alabama', 'Birmingham', 'Carberry', '35231', 6227);
INSERT INTO public."Filiale" VALUES (18, 'Alabama', 'Montgomery', 'Maple', '36195', 80);
INSERT INTO public."Filiale" VALUES (20, 'Alabama', 'Birmingham', 'Nova', '35263', 634);
INSERT INTO public."Filiale" VALUES (26, 'Alabama', 'Anniston', 'Sundown', '36205', 1);
INSERT INTO public."Filiale" VALUES (19, 'Alabama', 'Anniston', 'Mariners Cove', '36205', 55594);
INSERT INTO public."Filiale" VALUES (23, 'Alabama', 'Mobile', 'Rusk', '36689', 15);
INSERT INTO public."Filiale" VALUES (27, 'Alabama', 'Tuscaloosa', 'Talmadge', '35487', 9);
INSERT INTO public."Filiale" VALUES (7, 'Alabama', 'Birmingham', 'Darwin', '35215', 8);
INSERT INTO public."Filiale" VALUES (25, 'Alabama', 'Montgomery', 'Springs', '36125', 26);
INSERT INTO public."Filiale" VALUES (22, 'Alabama', 'Huntsville', 'Petterle', '35895', 44177);
INSERT INTO public."Filiale" VALUES (24, 'Alabama', 'Anniston', 'Sommers', '36205', 8848);
INSERT INTO public."Filiale" VALUES (2, 'Alabama', 'Mobile', 'Burrows', '36670', 41);
INSERT INTO public."Filiale" VALUES (16, 'Alabama', 'Montgomery', 'Kenwood', '36109', 789);
INSERT INTO public."Filiale" VALUES (13, 'Alabama', 'Birmingham', 'Green', '35254', 6212);
INSERT INTO public."Filiale" VALUES (1, 'Alabama', 'Birmingham', 'Bultman', '35242', 226);
INSERT INTO public."Filiale" VALUES (9, 'Alabama', 'Mobile', 'Derek', '36610', 3208);
INSERT INTO public."Filiale" VALUES (10, 'Alabama', 'Mobile', 'Di Loreto', '36610', 4103);
INSERT INTO public."Filiale" VALUES (12, 'Alabama', 'Mobile', 'Goodland', '36616', 2);
INSERT INTO public."Filiale" VALUES (15, 'Alabama', 'Birmingham', 'Harbort', '35244', 56249);
INSERT INTO public."Filiale" VALUES (6, 'Alabama', 'Birmingham', 'Dapin', '35215', 704);
INSERT INTO public."Filiale" VALUES (8, 'Alabama', 'Huntsville', 'Derek', '35805', 2190);
INSERT INTO public."Filiale" VALUES (11, 'Alabama', 'Montgomery', 'Fairfield', '36119', 4);
INSERT INTO public."Filiale" VALUES (14, 'Alabama', 'Anniston', 'Gulseth', '36205', 936);
INSERT INTO public."Filiale" VALUES (21, 'Alabama', 'Birmingham', 'Pepper Wood', '35242', 83);
INSERT INTO public."Filiale" VALUES (4, 'Alabama', 'Tuscaloosa', 'Cambridge', '35487', 82);


--
-- TOC entry 3615 (class 0 OID 18553)
-- Dependencies: 256
-- Data for Name: Indirizzo_Utente; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Tucson', 'Acker', '85705', 1, 'uajvuh30u29g422t');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Garden Grove', '5th', '92645', 5977, 'abogvl97e41a631n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Mobile', 'Di Loreto', '36610', 4103, 'hmozuk35y60c790g');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Sacramento', 'Butternut', '94230', 4696, 'oobxgl21n86l160z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arkansas', 'Little Rock', 'Brown', '72222', 9374, 'ceecog34d09y094c');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Fresno', 'Mandrake', '93715', 8, 'corzss57a06d644t');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Los Angeles', 'Morningstar', '90045', 0, 'mlnxnc18l24m114u');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Los Angeles', 'Fremont', '90071', 7, 'aunxad02p33x402h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Birmingham', 'Bultman', '35242', 226, 'kqwjjd23e43o622b');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Inglewood', 'Michigan', '90398', 56687, 'moqyaa96b41w621l');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Pomona', 'Sunbrook', '91797', 9745, 'kqupzq92g24n430p');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Fresno', 'Talmadge', '93721', 64123, 'hmozuk35y60c790g');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Ventura', 'Spaight', '93005', 56, 'auaggp09y68t935y');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Los Angeles', 'Schlimgen', '90071', 325, 'vrrrzs98x58u998j');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'North Hollywood', 'Algoma', '91616', 81885, 'ffdwee60s61t235w');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Corona', 'Mayer', '92878', 946, 'pvilho11h32q211g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Mobile', 'Derek', '36610', 3208, 'yiblfs65g56k279q');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Los Angeles', 'Claremont', '90076', 7, 'uajvuh30u29g422t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Tuscaloosa', 'Cambridge', '35487', 82, 'biracl27s20m759i');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Long Beach', 'Eagle Crest', '90840', 4, 'rbxbrf79f09c376r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Montgomery', 'Kenwood', '36109', 789, 'bucims80t97w944z');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Jose', 'Linden', '95155', 1, 'pvilho11h32q211g');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Jose', 'Hazelcrest', '95138', 70, 'pvgfaf41e99l262m');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Sunnyvale', 'Hoepker', '94089', 4, 'magujx74u13t692j');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Anaheim', 'Cottonwood', '92805', 9, 'qabkgx49q61o993x');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Torrance', 'Columbus', '90510', 9276, 'yiblfs65g56k279q');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Fresno', 'Fisk', '93709', 72, 'aunxad02p33x402h');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Santa Clara', 'Oakridge', '95054', 0, 'utoxrt14i21h422h');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Sunnyvale', 'Fisk', '94089', 58, 'arllpa74i66y238j');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Pasadena', 'Bellgrove', '91199', 5, 'spjzpv06b62d022v');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Simi Valley', 'Pierstorff', '93094', 138, 'moqyaa96b41w621l');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Sacramento', 'Wayridge', '95833', 9, 'qmogjf57a26v287q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arkansas', 'North Little Rock', 'Main', '72199', 12, 'qssbjx39t46r976n');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Sacramento', 'Maple', '94207', 0, 'vmrlhf74f78j242r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Mesa', 'Judy', '85205', 862, 'corzss57a06d644t');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Modesto', 'Rutledge', '95397', 9, 'ceecog34d09y094c');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arkansas', 'Fort Smith', 'Ilene', '72905', 1857, 'pvilho11h32q211g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arkansas', 'North Little Rock', 'Rieder', '72118', 982, 'spjzpv06b62d022v');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Van Nuys', 'Sachs', '91406', 0, 'psfiod09k77a681u');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Tucson', 'Elmside', '85754', 32, 'magujx74u13t692j');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Los Angeles', 'Melody', '90087', 36, 'qabkgx49q61o993x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Birmingham', 'Dapin', '35215', 704, 'dvqwpq82d12u044j');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Pasadena', 'Corry', '91186', 350, 'yiblfs65g56k279q');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Newport Beach', 'Clemons', '92662', 7102, 'mlnxnc18l24m114u');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Diego', 'Utah', '92153', 2130, 'dvqwpq82d12u044j');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Van Nuys', 'Lindbergh', '91411', 31444, 'ffdwee60s61t235w');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Pasadena', 'Basil', '91109', 55, 'oobxgl21n86l160z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alaska', 'Anchorage', 'Coleman', '99599', 2, 'rcjgxa50z51h696w');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Sacramento', 'Heath', '95865', 63490, 'bvsues78b56y479m');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Newport Beach', 'Scott', '92662', 4772, 'biracl27s20m759i');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Los Angeles', 'Waywood', '90005', 97, 'magujx74u13t692j');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Bakersfield', 'Dovetail', '93381', 22617, 'mumnbw95f77i705t');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Irvine', 'Roxbury', '92612', 62858, 'pqjbjt76t60z084a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Birmingham', 'Darwin', '35215', 8, 'echxll47x25b400a');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Francisco', 'Prentice', '94147', 3, 'hmozuk35y60c790g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Tempe', 'Arapahoe', '85284', 4792, 'qmogjf57a26v287q');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Huntington Beach', 'Jenifer', '92648', 62, 'qssbjx39t46r976n');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Oakland', 'Fair Oaks', '94605', 8, 'vmrlhf74f78j242r');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Hayward', 'Norway Maple', '94544', 33, 'abogvl97e41a631n');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Inglewood', 'Melby', '90305', 443, 'hhwjqv17k50w410f');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Irvine', 'Declaration', '92619', 85312, 'npyljq01s77p500h');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Irvine', 'Ohio', '92612', 33, 'jqkjfd25s12j468w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Phoenix', 'Village', '85005', 3, 'vrrrzs98x58u998j');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Sacramento', 'Karstens', '94263', 145, 'spjzpv06b62d022v');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Bernardino', 'Knutson', '92405', 94231, 'npyljq01s77p500h');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Chula Vista', 'Independence', '91913', 63983, 'arllpa74i66y238j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Anniston', 'Sommers', '36205', 8848, 'oobxgl21n86l160z');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Jose', 'Main', '95128', 44080, 'kqwjjd23e43o622b');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Modesto', 'Acker', '95354', 2734, 'ceecog34d09y094c');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Diego', 'Veith', '92115', 48, 'mumnbw95f77i705t');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Chula Vista', 'Old Gate', '91913', 44, 'biracl27s20m759i');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Sacramento', 'Cambridge', '94297', 218, 'corzss57a06d644t');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Los Angeles', 'Northport', '90060', 6, 'shnnfp42x22u151r');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Van Nuys', 'Hallows', '91406', 3, 'kqwjjd23e43o622b');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Tuscaloosa', 'Talmadge', '35487', 9, 'kjnlji67m42p786g');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Hayward', 'Talmadge', '94544', 3, 'pqjbjt76t60z084a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Birmingham', 'Green', '35254', 6212, 'npyljq01s77p500h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Montgomery', 'Fairfield', '36119', 4, 'ikwfcz18b86e682q');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Los Angeles', 'Oakridge', '90015', 34, 'ikwfcz18b86e682q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Birmingham', 'Cambridge', '35205', 53, 'fgceut14h98h226r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Anniston', 'Sundown', '36205', 1, 'rbxbrf79f09c376r');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Sacramento', 'Lakewood Gardens', '94230', 29, 'pvgfaf41e99l262m');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Mountain View', 'Texas', '94042', 46, 'jqkjfd25s12j468w');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Whittier', 'School', '90610', 848, 'shnnfp42x22u151r');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Los Angeles', 'Ruskin', '90025', 29573, 'rbxbrf79f09c376r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Anniston', 'Gulseth', '36205', 936, 'mfbslr80u19a742g');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Oakland', '5th', '94622', 929, 'qmogjf57a26v287q');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Santa Barbara', 'Roth', '93106', 21, 'psfiod09k77a681u');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Montgomery', 'Springs', '36125', 26, 'psfiod09k77a681u');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Riverside', 'Veith', '92519', 8, 'dbhyzt20x58r774v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Mobile', 'Goodland', '36616', 2, 'hhwjqv17k50w410f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Phoenix', 'Cody', '85030', 23419, 'mumnbw95f77i705t');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Concord', 'Birchwood', '94522', 5, 'qssbjx39t46r976n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Montgomery', 'Weeping Birch', '36114', 6005, 'jqkjfd25s12j468w');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Bernardino', 'Utah', '92415', 3740, 'mfbslr80u19a742g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Huntsville', 'Derek', '35805', 2190, 'ffdwee60s61t235w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arkansas', 'North Little Rock', 'Di Loreto', '72199', 7, 'mlnxnc18l24m114u');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Sacramento', 'Warner', '94245', 3857, 'rcjgxa50z51h696w');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Sacramento', 'Lerdahl', '94207', 36456, 'awuyzn61c17c890d');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Diego', 'Wayridge', '92145', 42, 'biracl27s20m759i');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Orange', 'Buhler', '92862', 73523, 'tzrppf44x01q376h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Chandler', 'Laurel', '85246', 8812, 'fdzdby16w16j502a');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Diego', 'Fremont', '92153', 84, 'fdzdby16w16j502a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Birmingham', 'Harbort', '35244', 56249, 'moqyaa96b41w621l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Birmingham', 'Nova', '35263', 634, 'auaggp09y68t935y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Anniston', 'Mariners Cove', '36205', 55594, 'aunxad02p33x402h');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Santa Barbara', 'Burrows', '93150', 34971, 'kqupzq92g24n430p');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Modesto', 'Loeprich', '95354', 8791, 'echxll47x25b400a');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Los Angeles', 'Mallory', '90025', 20, 'cvjlwx09n81j993j');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Francisco', 'Northland', '94137', 84, 'ocwhrd88a63g175v');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Fullerton', 'Grover', '92835', 6208, 'dvqwpq82d12u044j');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Newport Beach', 'Del Sol', '92662', 2421, 'fgceut14h98h226r');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Bernardino', 'Blaine', '92410', 74399, 'utoxrt14i21h422h');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Palo Alto', 'Butternut', '94302', 5587, 'cvjlwx09n81j993j');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Irvine', '5th', '92717', 9, 'uajvuh30u29g422t');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Glendale', 'Hovde', '91205', 61, 'ldaacb32t23p035n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arkansas', 'North Little Rock', 'Anniversary', '72118', 90076, 'ocwhrd88a63g175v');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Diego', 'Stuart', '92137', 71, 'bvsues78b56y479m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Phoenix', 'Tomscot', '85040', 556, 'tzrppf44x01q376h');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Jose', 'Ilene', '95113', 87316, 'bucims80t97w944z');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Mountain View', 'Dahle', '94042', 85356, 'tzrppf44x01q376h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Birmingham', 'Pepper Wood', '35242', 83, 'arllpa74i66y238j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alaska', 'Anchorage', 'Sundown', '99599', 12, 'shnnfp42x22u151r');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Orange', 'Kedzie', '92668', 7897, 'awuyzn61c17c890d');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Huntington Beach', 'Burrows', '92648', 8053, 'vrrrzs98x58u998j');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Los Angeles', 'Del Sol', '90055', 8, 'tamsxh39j08d107q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Tucson', 'Comanche', '85705', 0, 'dbhyzt20x58r774v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Tempe', 'Basil', '85284', 29, 'ldaacb32t23p035n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Birmingham', 'Carberry', '35231', 6227, 'qabkgx49q61o993x');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Los Angeles', 'Lyons', '90020', 23, 'mfbslr80u19a742g');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Sacramento', 'Fairview', '94286', 1986, 'dbhyzt20x58r774v');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Bernardino', 'Gulseth', '92405', 87, 'kqwjjd23e43o622b');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Francisco', 'Continental', '94105', 21, 'bucims80t97w944z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Tucson', 'Dapin', '85705', 5314, 'kqupzq92g24n430p');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'South Lake Tahoe', 'Hazelcrest', '96154', 181, 'ldaacb32t23p035n');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Francisco', 'Loeprich', '94116', 5, 'dvqwpq82d12u044j');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Lancaster', 'Express', '93584', 6, 'rcjgxa50z51h696w');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Torrance', 'Moland', '90510', 78, 'trepgg69u19k071g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Phoenix', 'Delladonna', '85045', 4, 'pvgfaf41e99l262m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Huntsville', 'Petterle', '35895', 44177, 'pqjbjt76t60z084a');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Petaluma', 'Lien', '94975', 3588, 'fgceut14h98h226r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arkansas', 'North Little Rock', 'Bayside', '72199', 3511, 'bvsues78b56y479m');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Luis Obispo', 'Warrior', '93407', 71, 'tamsxh39j08d107q');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Orange', 'Garrison', '92668', 2, 'nxrwjy67e78k983a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Mobile', 'Burrows', '36670', 41, 'awuyzn61c17c890d');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Palmdale', 'Anhalt', '93591', 0, 'trepgg69u19k071g');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Long Beach', 'Rusk', '90847', 9483, 'hhwjqv17k50w410f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Mobile', 'Rusk', '36689', 15, 'cvjlwx09n81j993j');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Escondido', 'Hooker', '92030', 65, 'fdzdby16w16j502a');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Orange', 'Eliot', '92867', 81561, 'auaggp09y68t935y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Montgomery', 'Maple', '36195', 80, 'abogvl97e41a631n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Glendale', 'Harbort', '85311', 77688, 'vmrlhf74f78j242r');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Sacramento', 'Anderson', '94263', 29, 'kjnlji67m42p786g');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Sacramento', 'Colorado', '94250', 5687, 'auaggp09y68t935y');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Diego', 'Monument', '92145', 399, 'nxrwjy67e78k983a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Birmingham', 'Longview', '35290', 52, 'tamsxh39j08d107q');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Chula Vista', 'Sutherland', '91913', 6560, 'ikwfcz18b86e682q');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Sacramento', 'Pepper Wood', '94297', 2, 'echxll47x25b400a');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'South Lake Tahoe', 'Monica', '96154', 7, 'ocwhrd88a63g175v');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Francisco', 'Fremont', '94164', 860, 'kjnlji67m42p786g');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Bernardino', 'Oakridge', '92405', 43, 'kjnlji67m42p786g');
INSERT INTO public."Indirizzo_Utente" VALUES ('West Virginia', 'Huntington', 'Logan', '77634', 201, 'zjjzzm30m46g321h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'South Bend', 'American Ash', '99220', 10854, 'noslzw34u00r539t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Dallas', 'Harbort', '58222', 50, 'zwmtwz36l77o282r');
INSERT INTO public."Indirizzo_Utente" VALUES ('North Carolina', 'Charlotte', 'Shelley', '89211', 7, 'suabnl13o74w031i');
INSERT INTO public."Indirizzo_Utente" VALUES ('Tennessee', 'Memphis', 'Mayfield', '04400', 8, 'mcsyrw69k90m893a');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'High Crossing', '44255', 2, 'wmdpat97i44l686t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Nevada', 'Las Vegas', 'Carpenter', '33764', 166, 'fhgmof18s41j295n');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'New York City', 'Westridge', '40911', 3403, 'odpsmt51i34p539x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Tennessee', 'Chattanooga', 'Morningstar', '80000', 639, 'rqjqdp57p76w419r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Nebraska', 'Lincoln', 'Farragut', '89900', 46184, 'pzgpbd57t39d363s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Fort Worth', 'Vidon', '22243', 809, 'fncguy16y09p079o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Wilkes Barre', 'Oxford', '36616', 25, 'knqjht86d51o896p');
INSERT INTO public."Indirizzo_Utente" VALUES ('North Carolina', 'Winston Salem', 'Hauk', '33437', 79884, 'oejkvl89k12w562d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'San Antonio', 'Petterle', '40395', 0, 'ftfagh53w89t084w');
INSERT INTO public."Indirizzo_Utente" VALUES ('New Jersey', 'Trenton', 'Talmadge', '38399', 5, 'uarkyi38f72r573s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Pensacola', 'Victoria', '13146', 97, 'logntb80s01y324k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Austin', 'Bobwhite', '29910', 5975, 'jahmzo24g76s944w');
INSERT INTO public."Indirizzo_Utente" VALUES ('New Mexico', 'Albuquerque', 'Charing Cross', '60344', 908, 'uprujb40t62r387n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Missouri', 'Kansas City', 'Boyd', '48336', 5, 'fqlyin12z06e130g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'El Paso', 'Mosinee', '05463', 70643, 'ppzecn38y37d807s');
INSERT INTO public."Indirizzo_Utente" VALUES ('New Mexico', 'Albuquerque', 'Reinke', '90328', 838, 'atbhyp35z83m686a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Oregon', 'Portland', 'Red Cloud', '11504', 649, 'svcxub51l40q691d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Houston', 'Merrick', '04389', 9, 'cqtajq47a97e127a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Denver', 'Burning Wood', '44324', 1880, 'fojscj13f69h621y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Augusta', 'South', '66118', 52909, 'tefphy68k12v005m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Wisconsin', 'Milwaukee', 'Bartelt', '18342', 48, 'pvowth75p53j283m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Dallas', 'Michigan', '99574', 44761, 'manipu71h58q315q');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Quincy', '96543', 7509, 'nqekjl98o73h568s');
INSERT INTO public."Indirizzo_Utente" VALUES ('New Mexico', 'Albuquerque', 'Londonderry', '08066', 986, 'bmvllg36p94o834q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Nebraska', 'Lincoln', 'Autumn Leaf', '17338', 6, 'fpgfmz62j53v258b');
INSERT INTO public."Indirizzo_Utente" VALUES ('Tennessee', 'Nashville', 'Oxford', '80305', 0, 'edptkz65p01q097k');
INSERT INTO public."Indirizzo_Utente" VALUES ('New Jersey', 'Camden', 'Garrison', '82568', 558, 'rynjfz64s17v995d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Minnesota', 'Saint Paul', 'Raven', '00354', 44685, 'neuxjk34h13z966f');
INSERT INTO public."Indirizzo_Utente" VALUES ('New Jersey', 'Elizabeth', 'Mendota', '90705', 9, 'xztucq61z58m389z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Oklahoma', 'Oklahoma City', 'North', '35079', 6624, 'czywny38u81l971j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Beaumont', 'Dorton', '26930', 3, 'uxzgka81u81f900v');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Diego', 'Annamark', '31323', 5, 'eqikwg97h60x737f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Montgomery', 'Clemons', '19353', 5338, 'vrvbme37u79s356u');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Sacramento', 'Trailsway', '27998', 19714, 'ttmofu93i63l613q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Michigan', 'Lansing', 'Norway Maple', '17681', 1702, 'gdrkbb46q98z701s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Richmond', 'Melrose', '14903', 8612, 'qfszmm89q52l220m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Colorado Springs', 'Pine View', '12187', 61, 'bqczfk28i17g929z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Minnesota', 'Young America', 'Meadow Ridge', '60975', 9, 'bkzoam73g46m558q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Louisiana', 'Alexandria', 'Homewood', '09191', 3, 'stdvsh45d64b133m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Missouri', 'Kansas City', 'Kingsford', '49686', 5, 'luolkp90c45z532q');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Village Green', '64831', 6349, 'oouadv87n09g556b');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Indianapolis', 'Straubel', '66421', 33, 'tiiflh50i08r012k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Hawaii', 'Honolulu', 'Pine View', '97383', 0, 'yxnaif10d79h861s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Pasadena', 'Eggendart', '39311', 37, 'voysgf92c86v824t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Fort Lauderdale', 'Delaware', '10054', 65, 'wzcyxj90a16i606i');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Brooklyn', 'Mifflin', '88737', 7, 'xzkpss69s39o118k');
INSERT INTO public."Indirizzo_Utente" VALUES ('North Carolina', 'Fayetteville', 'Westport', '76796', 9, 'lwlbtz06t04n178k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Fort Worth', 'Mayer', '42161', 8888, 'ffooko46r26z551h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Phoenix', 'Gerald', '88417', 53512, 'yyjqbv01k20u845l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Huntsville', 'Artisan', '65580', 5, 'qrrqti26c27x309a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Miami', 'Columbus', '68958', 428, 'kmqkbq06h76p620e');
INSERT INTO public."Indirizzo_Utente" VALUES ('Oklahoma', 'Oklahoma City', 'Trailsway', '10897', 844, 'rttpav92c88i986c');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Orlando', 'Darwin', '67976', 87592, 'wgqked19i68a969p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Atlanta', 'Stoughton', '51289', 65509, 'sxpitw57x28q806x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Warren', 'Manitowish', '73343', 3, 'wmmzpl91s11i675u');
INSERT INTO public."Indirizzo_Utente" VALUES ('Oklahoma', 'Tulsa', 'Continental', '77106', 56368, 'jliean73w52o867k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'El Paso', 'Elmside', '90921', 188, 'baepct56e87a974t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Lake Worth', 'Coolidge', '43925', 9, 'wlzdfo15l37k921k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Maryland', 'Baltimore', 'Moland', '69065', 33346, 'ubukra69q08t009q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Mobile', 'Russell', '73699', 545, 'bajcrv06p71n608e');
INSERT INTO public."Indirizzo_Utente" VALUES ('Nevada', 'Las Vegas', 'Marquette', '26123', 34026, 'uvrdvu49e76x287b');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Tampa', 'Lighthouse Bay', '48924', 48, 'pqlarh78x95c681u');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Orlando', 'Holmberg', '80414', 619, 'yacktw57o65u160e');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Francisco', 'Larry', '91403', 64, 'bqiccb56b92y499z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Miami', 'Mccormick', '81974', 24, 'kzvgsw10w85d287d');
INSERT INTO public."Indirizzo_Utente" VALUES ('South Carolina', 'Columbia', 'Emmet', '57534', 8, 'lsynvw38u84v911t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Clearwater', 'Morrow', '31313', 5663, 'pfjlhl23k93r751x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Atlanta', 'Muir', '83094', 64, 'cimkuc40b33g393l');
INSERT INTO public."Indirizzo_Utente" VALUES ('New Jersey', 'New Brunswick', 'School', '43404', 20, 'eftbvw91p58g751r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Palm Bay', 'Straubel', '91626', 315, 'glwshl40z75c831r');
INSERT INTO public."Indirizzo_Utente" VALUES ('South Carolina', 'Beaufort', 'Sage', '68774', 29000, 'yiqulp92v74x523w');
INSERT INTO public."Indirizzo_Utente" VALUES ('South Dakota', 'Sioux Falls', 'Kensington', '92606', 4, 'lrmqmu58v72g022o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Cleveland', 'Amoth', '31959', 6, 'fnksxk12z31h894r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Dayton', 'Victoria', '83521', 8369, 'twftbw62l90s058g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Grand Junction', 'Thompson', '25066', 7538, 'luitgk17d02s129y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Louisiana', 'Baton Rouge', 'David', '35243', 82524, 'xsgrxt24x46l839x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Michigan', 'Warren', 'Heffernan', '70362', 8, 'nangdr55z94b355f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Nebraska', 'Omaha', 'Warbler', '02939', 36, 'nhjzcn29m02x592d');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Santa Cruz', 'Schmedeman', '45777', 3, 'ovqwnp69g20s733t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Delaware', 'Wilmington', 'Grim', '27911', 54, 'avixie13a53o156s');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', '4th', '69809', 420, 'pnxpbo53j04q846e');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Pittsburgh', 'Shopko', '45195', 3, 'yxocqm21i97q766s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Norfolk', 'Banding', '68433', 647, 'pxhofa55v38m983t');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Trailsway', '98701', 7415, 'czkdfs79m36y373n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Austin', 'Rieder', '87760', 51, 'oyyiyv60r36v674q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Alexandria', 'Village', '39497', 7689, 'tfebtc60g85i970i');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Norfolk', 'Gale', '92150', 88, 'njpxey61x79k993r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'El Paso', 'Sutteridge', '69522', 19682, 'ldgpvv83x48q902w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Louisiana', 'Shreveport', 'Sutteridge', '68972', 4505, 'prhpun26y68n567z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Illinois', 'Peoria', 'Pearson', '23921', 742, 'ukyykl89k69e756x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'South Bend', '7th', '74874', 52, 'mqjrqc08j12u791o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Michigan', 'Flint', 'Lighthouse Bay', '83374', 69595, 'cupmtj64w01y897u');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Oxnard', '6th', '53483', 984, 'ltrebm84s57p282x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Tennessee', 'Knoxville', 'Jenna', '11320', 99188, 'gklyzl18k69z892d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Crawfordsville', 'Brown', '99983', 9605, 'cpqfoy83x73u061y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Austin', 'Lunder', '13236', 9508, 'wqyrsf81o90i239a');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Los Angeles', 'Badeau', '46606', 38169, 'tyksav29f44e812h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Aurora', 'Clemons', '62564', 254, 'pmxeyj22f79q939a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Houston', 'Holy Cross', '02418', 1487, 'pfbnul72n73x158g');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Carlsbad', 'Harper', '59836', 95, 'tgrgre42c92a215k');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Anaheim', 'Crownhardt', '82874', 7387, 'onfaqd30q64x811d');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Sunnyvale', 'Atwood', '56443', 89, 'hiinuk36j01s143y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Augusta', 'Melrose', '98382', 742, 'qsboqw04w60w823t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Gatesville', 'Melody', '72048', 68046, 'gtylvt32f54w241f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Connecticut', 'Hartford', 'Butterfield', '24576', 347, 'hpduso80y40u629k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Norfolk', 'Haas', '94647', 59, 'ynosng19p33q308s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Columbus', 'Lien', '87174', 69, 'yaclmp50h40v408v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Miami', 'Sullivan', '89595', 1, 'jhpody16d43r836h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Louisiana', 'Shreveport', 'Londonderry', '27636', 89, 'rqcnxn37i62m459v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Tennessee', 'Memphis', 'Elgar', '69726', 26775, 'gjphjf66h01r492f');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Irvine', 'Macpherson', '93474', 3, 'gxpvwa51v91z843a');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Francisco', 'Monument', '24409', 80, 'zfvxsj03z02n196y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Richmond', 'Meadow Ridge', '01958', 537, 'uemrug90i48x328u');
INSERT INTO public."Indirizzo_Utente" VALUES ('West Virginia', 'Huntington', 'Sommers', '05695', 49633, 'hoxjix04w78h052i');
INSERT INTO public."Indirizzo_Utente" VALUES ('Missouri', 'Kansas City', 'Eastwood', '04564', 74961, 'cmtohz05r99b277p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Pueblo', 'Oxford', '32271', 246, 'wkudqr77e45y324r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Connecticut', 'New Haven', 'Pearson', '29759', 4, 'elzydc89l17j043l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'El Paso', 'Kipling', '12712', 8, 'tdsdgt25n85t748h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Oklahoma', 'Tulsa', 'Vermont', '91281', 4, 'hbbdtl71a93o332r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Charlottesville', 'East', '17228', 3652, 'qbdnlf82x70l206u');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alaska', 'Anchorage', 'Vermont', '98371', 59, 'qnhjhl27o60s734b');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'El Paso', 'Gulseth', '42689', 858, 'ubhgqk91a47l249w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Hawaii', 'Honolulu', 'Sycamore', '87557', 46759, 'yfbomx14j01i414q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'York', 'Bluejay', '00280', 7398, 'rhtipe18q96t811w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Scottsdale', 'Kipling', '00657', 1, 'rbmdmz41d86m087i');
INSERT INTO public."Indirizzo_Utente" VALUES ('Connecticut', 'Hartford', 'Susan', '79678', 431, 'inkkug20e93g176d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Dallas', 'Packers', '13552', 338, 'fclxnj72q03i675i');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Philadelphia', 'International', '56776', 5, 'dcfuye94g06f217q');
INSERT INTO public."Indirizzo_Utente" VALUES ('West Virginia', 'Huntington', 'Canary', '25713', 30070, 'sgtzkv15v56p995o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Mobile', 'Derek', '60856', 37, 'uyheqc53x63q262p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Kentucky', 'London', 'Eagan', '27842', 15, 'mtrzyg07g76q856p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Connecticut', 'Fairfield', 'Donald', '57966', 3538, 'fmzpzf28z43j004o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Massachusetts', 'Newton', 'Bultman', '69995', 2472, 'hemeot50m73i573g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Austin', 'Caliangt', '16740', 78861, 'uqzngd89k68o039y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Warren', 'Little Fleur', '99907', 135, 'bjblph06j16d245i');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'El Paso', 'Caliangt', '65752', 56, 'hgbzrh16u63i171y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Arlington', 'Bobwhite', '12109', 9, 'biyovl42e99y464i');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'College Station', 'Clove', '18553', 34, 'mryhnm61j46c350f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Erie', 'Blaine', '29873', 67029, 'vhoywi16t82l695z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Kentucky', 'Lexington', 'Anderson', '63512', 61938, 'ybfysq79y79l393y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arkansas', 'Fort Smith', 'School', '94333', 8, 'dtofbi34p99y365o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'El Paso', 'Butternut', '34603', 334, 'vljdev57g03y090c');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Houston', 'Butternut', '84497', 161, 'sszezk30j07n929w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Minnesota', 'Monticello', 'Vahlen', '99847', 129, 'ktzici06x98f179v');
INSERT INTO public."Indirizzo_Utente" VALUES ('New Mexico', 'Albuquerque', 'Acker', '13286', 5040, 'rhoejr57a02m896n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Oregon', 'Portland', 'Valley Edge', '76561', 7342, 'xxncni20g41k547d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Kentucky', 'Louisville', 'Vernon', '86810', 6001, 'qohrak59c31f972s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Dallas', 'Elmside', '19195', 80571, 'diojtz71g09k482b');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Fort Wayne', 'Esker', '02524', 755, 'twaahz52e36j670l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Washington', 'Tacoma', 'Reinke', '83692', 8, 'pqbyjh71p95u332w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Washington', 'Vancouver', 'Pankratz', '61869', 1141, 'dummes59z00c736a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Hawaii', 'Honolulu', 'Vera', '66495', 26296, 'gkwlxp24b62o116h');
INSERT INTO public."Indirizzo_Utente" VALUES ('New Mexico', 'Albuquerque', 'Morningstar', '27215', 392, 'otsesl75v45y509t');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Service', '55910', 6, 'zjdfwr79p98y382c');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Round Rock', 'Butternut', '10743', 829, 'xqtndg34u63l734v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Panama City', 'Carioca', '33059', 69092, 'mkejzs70t73i858j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Maryland', 'Silver Spring', 'Corben', '43909', 98118, 'vgfuyu57e66b290z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Oklahoma', 'Oklahoma City', 'Independence', '45033', 35, 'qftkaz11f56i050v');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'New York City', 'Lyons', '33117', 6, 'vsovbt06e82k566o');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Prentice', '42015', 2, 'ibzags87y19q846t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Virginia Beach', 'Briar Crest', '58841', 4, 'imccnp09o38x381t');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Fullerton', 'Rieder', '97643', 8, 'qdwjuu36n94c501h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Missouri', 'Kansas City', 'Forest', '19843', 283, 'mqejhb39g21s907j');
INSERT INTO public."Indirizzo_Utente" VALUES ('North Carolina', 'Charlotte', 'Merchant', '12493', 56, 'xwwjzo00v04h752d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Mississippi', 'Jackson', 'Northwestern', '23847', 15, 'vpfjqd29o36m152p');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Irvine', 'Center', '46217', 6980, 'kmzeuu19a52h131r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Phoenix', 'Ilene', '41544', 808, 'vvcybr21z15j371t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Nebraska', 'Lincoln', 'Kennedy', '65184', 7721, 'fymicl07g86g311z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Illinois', 'Carol Stream', 'Killdeer', '09615', 42, 'pedxbe91i75m176m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Tucson', 'Toban', '91584', 2, 'sfhdna30o52a171q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Mobile', 'Summerview', '41166', 88399, 'mkoamp49f47t875o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Utah', 'Salt Lake City', 'Saint Paul', '58638', 919, 'kqegmg32m29k935w');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Staten Island', 'Straubel', '92000', 603, 'xlzrzk74e92m608i');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Tucson', 'Paget', '92670', 7102, 'sonctd56f83b983b');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Colorado Springs', 'Village', '45849', 0, 'dtwigz64e10p083m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'El Paso', 'Summerview', '61419', 150, 'jijwdf38e90k474z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Wisconsin', 'Madison', 'Schurz', '45520', 58, 'vanpud49z85p246z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Kansas', 'Topeka', 'Melvin', '19440', 81994, 'mpucqz16x16h338y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Tampa', 'Springs', '95203', 2688, 'bvjmam04c45s056z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Houston', 'Loftsgordon', '80608', 73340, 'xhyhhr51j99t588v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Evansville', 'Northland', '64076', 219, 'nvjvry06k80y671d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Washington', 'Tacoma', 'Gina', '97580', 5123, 'qgirmu64l92v236a');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Oakland', 'Erie', '02459', 65, 'jjnkrf56p52e998v');
INSERT INTO public."Indirizzo_Utente" VALUES ('West Virginia', 'Huntington', 'Ryan', '42028', 6, 'uvykyg86q63m719o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Birmingham', 'Maryland', '67340', 79583, 'hionfe08j30s838l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Plano', 'Harbort', '46462', 8, 'wnfbnc70h73p291z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Maryland', 'Baltimore', 'Lunder', '92291', 8, 'xwtrps80s90o891n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Pompano Beach', 'Transport', '74242', 66, 'ajidlo43u61p099h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Augusta', 'Arizona', '48415', 83, 'qqlgsj19c62a369o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Amarillo', 'Cherokee', '14619', 9216, 'xdywvp61j99w442z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Mississippi', 'Gulfport', 'Declaration', '92601', 909, 'whoxlw51d31i855p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Tucson', 'Mcbride', '46455', 333, 'jqowvl10i94z886o');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Pasadena', 'Mallory', '99887', 5481, 'nzqznh45k76m471w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Louisiana', 'Shreveport', 'Fordem', '59529', 30594, 'gaflzy22j28d259r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Orlando', 'Armistice', '33087', 4, 'lxeorf85u39l996y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Colorado Springs', 'Pleasure', '81773', 1769, 'iyfais63g07q982h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Colorado Springs', 'Burrows', '43646', 66, 'idurgs16p07z227n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Indianapolis', 'Commercial', '68241', 62, 'nuztap81a26s855n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Richmond', 'Pleasure', '58589', 88, 'pkzhol78p03a056s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Lubbock', 'Anderson', '10559', 64625, 'rwknhd54x94p737d');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Chula Vista', 'Mitchell', '74543', 5, 'bbgcje71p25a045f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Tennessee', 'Memphis', 'American', '43385', 488, 'lxcpuv90t78u605u');
INSERT INTO public."Indirizzo_Utente" VALUES ('Iowa', 'Sioux City', 'Meadow Vale', '10009', 56220, 'xrbejq26q15p312m');
INSERT INTO public."Indirizzo_Utente" VALUES ('New Jersey', 'Trenton', 'Becker', '69846', 14765, 'gbpmca29b68x702b');
INSERT INTO public."Indirizzo_Utente" VALUES ('Oregon', 'Beaverton', 'Stoughton', '77025', 1, 'cykmvq17a37o337t');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Los Angeles', 'Bartelt', '20470', 8592, 'mhoecj38j36w784x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Michigan', 'Saginaw', 'Hovde', '21487', 0, 'wiygan57q71s213z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Chandler', 'Ruskin', '97444', 8, 'biakfr95f91j747v');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Hicksville', 'Menomonie', '11301', 8084, 'zawssc20m93t610i');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Tucson', 'Maryland', '31548', 3, 'vrlbxm76c74p195v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Connecticut', 'Hartford', 'Jay', '96857', 11, 'vydrwa78d74w280l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Kentucky', 'Lexington', 'Cardinal', '50083', 19876, 'juqqvq79q57c343f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Maryland', 'Baltimore', 'Twin Pines', '88236', 26168, 'rwfaqv29l60p314v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Dayton', 'Charing Cross', '43514', 45, 'mrnduz12x16z223d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Amarillo', 'Bluestem', '98741', 358, 'krpijq65x88a203e');
INSERT INTO public."Indirizzo_Utente" VALUES ('Kansas', 'Shawnee Mission', 'Londonderry', '99355', 238, 'djenxl66m93q807q');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Jose', 'Lien', '30455', 0, 'ffivvv85v77v236p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Pinellas Park', 'Westport', '12511', 86, 'ymcvcx20r05m719x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Nebraska', 'Omaha', 'Blackbird', '53398', 81, 'aqlrcu77s93p743t');
INSERT INTO public."Indirizzo_Utente" VALUES ('North Carolina', 'Charlotte', 'Burrows', '61223', 68, 'wfbltk51o88k950q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Hawaii', 'Honolulu', 'Steensland', '21665', 22, 'yzrwhf69b44t534k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Dallas', 'Del Sol', '23957', 20, 'ftvczh65w43l415y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Atlanta', 'Lawn', '60065', 5875, 'xfzwro97m90s944f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Idaho', 'Boise', 'Amoth', '07400', 58854, 'cuskrn57l47e061a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Illinois', 'Springfield', 'Sunnyside', '19918', 49, 'pvesli24i05o628x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Nevada', 'Las Vegas', 'Hazelcrest', '70389', 60819, 'hescfp63d24r371j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Tennessee', 'Nashville', 'Drewry', '53682', 514, 'qkuolt71j22g986z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Minnesota', 'Minneapolis', 'Dorton', '40691', 801, 'tfbepd27f25z456b');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Dallas', 'Bonner', '05593', 786, 'igtgry79x29q919l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Iowa', 'Des Moines', 'Briar Crest', '47640', 7, 'kwhebi32u53k737a');
INSERT INTO public."Indirizzo_Utente" VALUES ('South Carolina', 'Charleston', 'Weeping Birch', '02391', 168, 'hatoqy71b49z740w');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'New York City', 'Del Mar', '05451', 4985, 'dbaiib39k29d734g');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Hayward', 'Forest Run', '88949', 1, 'tlxmtp31i77i820m');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Westport', '37675', 671, 'fcopvg30n16c914c');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Brooklyn', 'Mayfield', '19426', 46, 'hnqwqq55k83w052b');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Kim', '64599', 9461, 'naxcfe43n87k487q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Pompano Beach', 'Hermina', '39432', 2866, 'bdgvho42a00g362s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Atlanta', 'Waubesa', '64009', 76935, 'vfhkee99w33c637c');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Toledo', 'Florence', '54605', 1, 'ehutcz88v97t154b');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Dallas', 'Sauthoff', '16290', 5568, 'ygjdou64c73y262u');
INSERT INTO public."Indirizzo_Utente" VALUES ('Michigan', 'Muskegon', 'Oxford', '43916', 822, 'qkmoru80d64m261f');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Fresno', 'Kings', '18120', 25, 'zwoqwv41d02z602d');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Santa Ana', 'Harbort', '23076', 8058, 'ekasqk57f23p760q');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Albany', 'Valley Edge', '62324', 5659, 'tskzol42h43s526q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Aurora', 'Brown', '25568', 0, 'nxwquf98b90k316c');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Diego', 'Summit', '53348', 6, 'xfddve83g88c486m');
INSERT INTO public."Indirizzo_Utente" VALUES ('North Carolina', 'Asheville', 'Westridge', '67521', 71945, 'awsrho41j56r866f');
INSERT INTO public."Indirizzo_Utente" VALUES ('North Carolina', 'Durham', 'Rockefeller', '12042', 2, 'hznhdf48y67b150x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Virginia Beach', 'Butternut', '31057', 6, 'cywalr05h91d484m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Washington', 'Spokane', 'Cascade', '97729', 2070, 'wqutbg42d49n864u');
INSERT INTO public."Indirizzo_Utente" VALUES ('North Carolina', 'Raleigh', 'Dryden', '77236', 68, 'lvjjgd59d94x491s');
INSERT INTO public."Indirizzo_Utente" VALUES ('North Dakota', 'Bismarck', 'Monterey', '85789', 30572, 'kukbjl22q01s531a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Missouri', 'Springfield', 'Fremont', '15831', 40131, 'niovlv39v26f854w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Fort Worth', 'Algoma', '43607', 5494, 'uatgms19s89r462p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Phoenix', 'Nobel', '53345', 9510, 'khftlv16s49y992m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Tennessee', 'Nashville', 'Lighthouse Bay', '56016', 727, 'aeuvnp64l72c668r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Massachusetts', 'Boston', 'Tennyson', '87674', 1616, 'gdvioy68s73p937c');
INSERT INTO public."Indirizzo_Utente" VALUES ('Oklahoma', 'Oklahoma City', 'Lukken', '40305', 35, 'gcjhcy92g72e134i');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Virginia Beach', 'Riverside', '10290', 31, 'wrtcwb68k39k579d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Fort Lauderdale', 'Morrow', '99899', 5318, 'hqugrl00r46y292v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Naples', 'Kings', '05174', 8566, 'hwvicy98q94a895c');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Arlington', '2nd', '75253', 9575, 'kphrev36h15a238y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Tallahassee', 'Clarendon', '89957', 63, 'greraz77c43v123w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Rhode Island', 'Providence', 'Dayton', '55778', 4, 'qkibkx39w03u789n');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Elmside', '56084', 997, 'uwqdhc51p87l159g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Philadelphia', 'Rutledge', '19364', 7, 'eyenlv61m21t993v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Clearwater', 'Killdeer', '88473', 4, 'ivxmmi14g70a470t');
INSERT INTO public."Indirizzo_Utente" VALUES ('West Virginia', 'Charleston', 'Anniversary', '37344', 213, 'jzbcls28a49q907j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Mobile', 'Elmside', '05134', 2836, 'wuzuqr03m90r746d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Nebraska', 'Omaha', 'Hauk', '10753', 6849, 'lagtql33n53n104g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'San Antonio', 'La Follette', '96657', 440, 'lqnfji78r29w466g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Birmingham', 'Thompson', '55458', 6, 'nykaio89f69v276n');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Francisco', 'Reindahl', '66958', 2586, 'wepwcz48i94b368x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Birmingham', 'Graedel', '37948', 94, 'ezkwii39z32c350a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Miami', 'Holy Cross', '47830', 7750, 'fuvpvc77f80c928n');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Jose', 'Hazelcrest', '34626', 7, 'ncptgj96i29t348q');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Jose', 'Caliangt', '31366', 716, 'ddofvr13t81o964o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Midland', 'Basil', '86185', 8, 'zpkyga71s78b592a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Maryland', 'Rockville', 'Orin', '62660', 93, 'fyesdl93b77q178e');
INSERT INTO public."Indirizzo_Utente" VALUES ('Utah', 'Salt Lake City', 'Fremont', '22348', 852, 'zfydjk68n10u660n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Corpus Christi', 'Oneill', '22409', 8, 'hynsmy79h38a152r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Dallas', 'Upham', '97861', 628, 'aejawf83e52u311t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'York', 'Autumn Leaf', '20040', 6417, 'ltxtuz97v18e713t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Houston', 'Lakewood', '54604', 543, 'xxkotd24d06f724r');
INSERT INTO public."Indirizzo_Utente" VALUES ('South Carolina', 'Charleston', 'Morrow', '18108', 3251, 'xasayf43w42h467x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Illinois', 'Peoria', 'Westend', '35286', 47708, 'jvfulu96x84x763y');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Los Angeles', 'Union', '56988', 4023, 'stsjzy35j70y546p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Boulder', 'Oxford', '66036', 982, 'nqwqhn41z22s088t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Roanoke', 'Comanche', '12561', 8, 'iyhzuq98f66a904e');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Evansville', 'Oak', '29528', 47, 'dpjzqs24p51l454d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Fort Wayne', 'Meadow Vale', '20892', 69209, 'zrosek95l32p208a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Missouri', 'Saint Louis', 'Moulton', '97488', 194, 'ksjjng76l79z938v');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Chula Vista', 'Scoville', '86950', 6, 'tiwuaw40c19x997m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Dallas', 'Crescent Oaks', '75320', 811, 'cdnvpr44a27s464z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Saint Petersburg', 'Talisman', '81360', 19, 'nalblh07s15a394h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Missouri', 'Saint Louis', 'Farwell', '42266', 5, 'bwqsww05c26r955r');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Jamaica', 'Rowland', '77271', 7247, 'porhvy84b09i382t');
INSERT INTO public."Indirizzo_Utente" VALUES ('West Virginia', 'Charleston', 'Kennedy', '06191', 85, 'fegqwm32v83x267h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Gatesville', 'Moulton', '02300', 45, 'izynbo84d65q336r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Atlanta', 'Warner', '78141', 2728, 'vwpxxv78e93p501z');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Buhler', '46770', 7810, 'pibudt78r16a447a');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Port Washington', 'Westport', '82846', 75160, 'tbgjbc08x86e721k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Pueblo', 'Debra', '64477', 34477, 'wpuyfq29e69j026f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Iowa', 'Des Moines', 'Gulseth', '96053', 2, 'iykdnd08g65v463j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arkansas', 'Little Rock', 'Cambridge', '95925', 9432, 'uiklzr48g15x639d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'El Paso', 'Pepper Wood', '44416', 87141, 'bmvjla65g93v445i');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Kropf', '53071', 16093, 'yfordi93z47d950m');
INSERT INTO public."Indirizzo_Utente" VALUES ('North Carolina', 'Raleigh', 'Bartelt', '63505', 3145, 'bvzhtv80u41r537e');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Fullerton', 'Green', '88243', 92349, 'zdmwue93v95e125w');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Jose', 'Westerfield', '92841', 6011, 'grdgnl27o09y843s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Kansas', 'Wichita', 'Cordelia', '73042', 8779, 'cbpecz68u53r533h');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'New York City', 'Jenna', '50069', 1, 'rukqys85i03o655g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'San Antonio', 'Thackeray', '31905', 86883, 'rlagag37v44g548h');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Mcguire', '14171', 4, 'ouqxas01i91i264z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Conroe', 'Vahlen', '00461', 9, 'wgplnz82i26j138e');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Norfolk', 'Bultman', '65369', 6394, 'lwolgv30o68l904b');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Austin', 'Meadow Ridge', '58033', 1, 'apyxwu54a07y455w');
INSERT INTO public."Indirizzo_Utente" VALUES ('North Carolina', 'Charlotte', 'Shopko', '00128', 341, 'eitriv67y12p862u');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Modesto', 'Saint Paul', '26880', 243, 'hkuwbk86w12o138c');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Rochester', 'Springs', '25501', 34399, 'jlvskz98i56n162p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Evansville', 'Caliangt', '39395', 22, 'pttjec03n88j479e');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Riverside', 'Menomonie', '83428', 135, 'iuemjb93v11o917t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Oklahoma', 'Oklahoma City', 'Aberg', '73875', 51, 'esaphh68t77x479l');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Inglewood', 'Steensland', '84821', 4, 'scydrw97y70z667z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Indianapolis', 'Rusk', '99109', 69826, 'aihidc26u00q341f');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'John Wall', '46872', 52, 'fftdia16t21b475s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Indianapolis', 'Ludington', '25235', 8863, 'fvyqbg06s80i819y');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Schenectady', 'Lukken', '58778', 7, 'jnxppz36y70k810k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Houston', 'Ohio', '58483', 77437, 'knwpnh76n28c198c');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Francisco', '7th', '71280', 2, 'nulsti82t25n734q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Kansas', 'Shawnee Mission', 'Mayfield', '10701', 73, 'bncffp20r39h983d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Oklahoma', 'Oklahoma City', 'Claremont', '27134', 1050, 'cvofjy01b89a528k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Sterling', 'Erie', '27519', 64386, 'nwbwze08u69m283a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'San Antonio', 'Pearson', '99298', 88591, 'bxhwvl44a40p487p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Atlanta', 'Florence', '17419', 50033, 'ejovqv21c74z994c');
INSERT INTO public."Indirizzo_Utente" VALUES ('New Jersey', 'Camden', 'Kipling', '37086', 33, 'ppbocq78e39u452k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Minnesota', 'Minneapolis', 'Novick', '46471', 37564, 'zkstsc58d44x407x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Illinois', 'Springfield', 'Bluestem', '58941', 927, 'urgaqd87g05s201o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Utah', 'Salt Lake City', 'Talisman', '03775', 20, 'bkxwen88o85l765g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Phoenix', 'Memorial', '75354', 223, 'jvpiug74z06q590x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Iowa', 'Davenport', 'Lyons', '78735', 2761, 'hzygug04l86s190x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Louisiana', 'Baton Rouge', 'Eagan', '99491', 644, 'ecoami54p21v881e');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Scottsdale', 'Blaine', '02282', 9, 'slmwhe14o82t696q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Pittsburgh', 'Summit', '13875', 8, 'mlqtow03q53i339t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Michigan', 'Flint', 'Dovetail', '25978', 1, 'uxwyyw69y67w105g');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Great Neck', 'Cody', '54977', 83, 'odlgol57t91v394z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Fort Lauderdale', '5th', '11563', 57554, 'mmyxlq78y60c639v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Delaware', 'Newark', 'Rigney', '69531', 89373, 'rgsyok95g15q355j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Iowa', 'Des Moines', 'Jenifer', '68885', 92, 'vvrtat98m61u748i');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'San Angelo', 'Dapin', '88734', 91958, 'hjimqc36e57w169x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Hawaii', 'Honolulu', 'Sundown', '91037', 5832, 'ngucfb23c25o683b');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Arlington', 'Glendale', '39203', 81, 'jcnncy30g29e277m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Maryland', 'Baltimore', 'Glendale', '38989', 60621, 'alemzf73j20z028u');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Anaheim', 'Spenser', '25052', 32404, 'zsorvj58e92g655d');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'New York City', 'Dexter', '56760', 257, 'yeidoq87h04v253n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Bradenton', 'Veith', '14510', 431, 'ssywbs56x65c294e');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Austin', 'Surrey', '90329', 3, 'hiyfze37r31q065s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Orlando', 'Haas', '54629', 658, 'mhnwrf04i20e165m');
INSERT INTO public."Indirizzo_Utente" VALUES ('North Carolina', 'Charlotte', 'Muir', '85448', 3, 'txiquk01l70j007w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Colorado Springs', 'Erie', '42530', 8, 'ubkiiv20t25x511g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Miami', 'Saint Paul', '87712', 5, 'duuvwb62a67u925b');
INSERT INTO public."Indirizzo_Utente" VALUES ('Mississippi', 'Jackson', 'Pawling', '72922', 2, 'iaimcp27v09n390o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Michigan', 'Grand Rapids', 'Pierstorff', '23146', 777, 'tgfcls21b77t413r');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Los Angeles', 'Farwell', '40103', 77, 'caztjb38w06e804g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Illinois', 'Palatine', 'Messerschmidt', '98674', 1, 'sugoqm80w14b879j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Houston', 'Meadow Valley', '11531', 57, 'kchcts01v28p860a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Greeley', 'Prairieview', '35554', 86963, 'zhuwhr15r01h823j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Philadelphia', 'Anniversary', '93611', 748, 'dywuuy04i17o578j');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Pasadena', '2nd', '56899', 79649, 'zxwuth69x56e561d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Fort Lauderdale', 'Mccormick', '64153', 91, 'hzkqjh73f81k762o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Montgomery', 'Graedel', '44576', 2894, 'ngyfvg51u35u829g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Kentucky', 'Louisville', 'Monterey', '26857', 1, 'yjgxng37x23u723a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Louisiana', 'Shreveport', 'Jackson', '17150', 8, 'apfaag54u56a452l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Atlanta', 'Independence', '00446', 88521, 'ulirgg96w70a400m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Utah', 'Salt Lake City', 'Upham', '67089', 3, 'mqamxl68x56b775i');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'New York City', 'Eliot', '76137', 5, 'uvkxaj86z28t312j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Evansville', 'Independence', '35234', 7, 'bmzfjy69f92a623m');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Alhambra', 'Lien', '09950', 2981, 'uilegv36b88z258v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'El Paso', 'Claremont', '64338', 90, 'lzwmkk95z22u505k');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Redwood City', 'Twin Pines', '15329', 5, 'khnvqe72l87q967u');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Diego', 'Lindbergh', '93539', 2, 'itzwyb58k79e957f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Birmingham', 'Rieder', '06499', 63, 'cxbpdi54i67k361m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Sarasota', 'Artisan', '87375', 0, 'kvdahv58k62x642d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Virginia Beach', 'Spaight', '95410', 753, 'rejrzk24v65g139b');
INSERT INTO public."Indirizzo_Utente" VALUES ('Louisiana', 'Baton Rouge', 'Crest Line', '62512', 9167, 'qpivwa87y25e468o');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Berkeley', 'Russell', '51026', 6593, 'owlzke29p19n961a');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Elmside', '18895', 67, 'ynpqod02y80v794g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arkansas', 'North Little Rock', 'Portage', '67360', 6852, 'ygwxvj79h90f093i');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Alhambra', 'Blaine', '24068', 962, 'sycvaz44l40f023m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Scottsdale', 'Oakridge', '68705', 1181, 'gzewaj59c69u483b');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Rochester', 'Barnett', '50030', 53666, 'hbgrck63w31e330g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Connecticut', 'Fairfield', 'Moose', '00809', 6702, 'opablf82b18h419i');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Bradenton', 'Ramsey', '30154', 4, 'ctpcvo16z19t939o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Killeen', 'Darwin', '60586', 600, 'xvucnq61o81u204r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Lubbock', 'Stang', '86412', 75731, 'uqhhnr77c13u853t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Birmingham', 'Twin Pines', '29862', 28, 'olvtnz08k31g479l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Massachusetts', 'Worcester', 'New Castle', '79592', 61183, 'inlkab22y35r523c');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Gary', 'Loomis', '33600', 7134, 'tibkqi57p42w743o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Evansville', 'Upham', '43770', 98, 'wmwuxq55o01z838q');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Brooklyn', 'North', '00319', 22, 'shiorv64i27v474n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Illinois', 'Evanston', 'Continental', '71760', 33, 'zgvtrb42b24y747d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Tampa', 'Anhalt', '32304', 1, 'rlhxip57i49r194d');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Irvine', 'Esch', '28345', 358, 'vyjeea85g55s149m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Hawaii', 'Honolulu', 'Grover', '57851', 9, 'ysrwwy48b48m772c');
INSERT INTO public."Indirizzo_Utente" VALUES ('Wisconsin', 'Milwaukee', 'Mallard', '02899', 6, 'kghtyr25x19w311r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Beaumont', 'Ohio', '14354', 26, 'pznyrv14e65y073o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Oregon', 'Portland', 'Kennedy', '22832', 8443, 'zlqfeu36e42k506v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Indianapolis', 'Brickson Park', '30273', 0, 'horawi15y87t226p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Massachusetts', 'Boston', 'Jay', '45977', 90247, 'whzcvo80i63t341a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Idaho', 'Boise', 'Park Meadow', '63152', 490, 'wgrejt00g44h946h');
INSERT INTO public."Indirizzo_Utente" VALUES ('North Carolina', 'Durham', 'Cardinal', '59787', 4, 'nheeqv31s20m525k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Connecticut', 'New Haven', 'Little Fleur', '40767', 80, 'bwnbxs04b67h331p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Houston', 'Oxford', '65686', 8716, 'izdinq84h61h643s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Virginia Beach', 'Darwin', '89718', 307, 'hfumzf36g22g747h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arkansas', 'Little Rock', 'Lotheville', '39315', 62825, 'rokhme14q44r365l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Miami', 'Ridgeview', '76389', 76, 'ykvblg18j59n847w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Washington', 'Seattle', 'Loftsgordon', '49515', 2377, 'mfrbng21o26k276n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Tennessee', 'Nashville', 'Goodland', '72298', 1, 'bbkshw81f04m459q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Roanoke', 'Atwood', '69979', 19869, 'kudino54j21s645p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Cleveland', 'Anderson', '07831', 693, 'viutox10s69i779f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Pittsburgh', 'Oriole', '84100', 733, 'nfsrws52w24w953b');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Columbus', 'Graedel', '88398', 70, 'nhfusr24m70x610v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Tennessee', 'Memphis', 'Sachtjen', '87622', 760, 'phwaxu31m15b938j');
INSERT INTO public."Indirizzo_Utente" VALUES ('North Carolina', 'Greensboro', 'Marquette', '98244', 563, 'sialkh00d96p920i');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'North Hollywood', 'Basil', '96580', 52319, 'qnapty89i33c049q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Miami', 'Moland', '41115', 40, 'umbayu44q37i955h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Michigan', 'Detroit', 'Butterfield', '43500', 4676, 'riwurq23j31u866w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Nebraska', 'Lincoln', 'Manitowish', '31092', 3, 'jpzeyo97v76g588z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Galveston', 'Donald', '59370', 711, 'ggcmdj63y57b069x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Wisconsin', 'Madison', 'Lotheville', '06758', 7112, 'riaxye47m06p717k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Montana', 'Bozeman', 'Maywood', '34644', 1467, 'ulkeax27i92h915i');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Brooklyn', 'Jana', '90803', 79, 'qlgobk65g81v170g');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Oxnard', '8th', '76620', 8973, 'flindu81q13d275b');
INSERT INTO public."Indirizzo_Utente" VALUES ('North Carolina', 'Raleigh', 'Veith', '09378', 1510, 'fcgrhm71d09a266t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Oklahoma', 'Tulsa', 'Lakewood Gardens', '94499', 12585, 'mbmbqy89h61y240s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Roanoke', 'Claremont', '06121', 46, 'gvncjo16f80e435h');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Fairview', '11215', 32, 'gcinjy85m76o284r');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Corry', '14278', 7, 'qzvsel04w44q253q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Evansville', 'Brown', '16341', 70, 'wmpymc97t25y428q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Massachusetts', 'Brockton', 'Waxwing', '30308', 9179, 'tzonvf81w29d964g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Apache Junction', 'Acker', '12699', 59, 'usuttb14j08o865n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Wisconsin', 'Madison', 'Novick', '40200', 521, 'npymbn76d51e227l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Nevada', 'Reno', 'Becker', '25060', 3, 'uuxnfb50x42p997w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Atlanta', 'Brentwood', '18224', 5899, 'navcdj18y88m194t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Colorado Springs', 'Mcbride', '07936', 974, 'cqvzpk85i23q219m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Pensacola', 'Monica', '97493', 1992, 'musdmi33a08v413b');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Garden Grove', 'Green', '48818', 5692, 'ywwkuo29k57j644j');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Rafael', 'Fair Oaks', '30288', 503, 'brvmpm92v06z950b');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Buffalo', 'High Crossing', '34472', 3464, 'woadai55o12v734m');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'New York City', 'Gale', '78408', 35720, 'ldvolh68z86t839z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Kentucky', 'Louisville', 'Shoshone', '76583', 937, 'vrcbwn53f83h885p');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Oneill', '31040', 41, 'ubhmvs80m63r731s');
INSERT INTO public."Indirizzo_Utente" VALUES ('South Carolina', 'Columbia', 'Fieldstone', '65991', 5, 'pzonfv49l79l250m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Wisconsin', 'Milwaukee', 'Dahle', '30248', 56375, 'cpoilh22e04c436a');
INSERT INTO public."Indirizzo_Utente" VALUES ('South Carolina', 'Charleston', 'Mayer', '96130', 0, 'qfyxgs56y06g132x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Roanoke', 'Walton', '94185', 8408, 'cyccyp23n61c647l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'San Antonio', 'Tennessee', '41669', 4, 'xmtxjt99x07q805l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Midland', 'Carberry', '42518', 2353, 'utejkk23x45s145y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Cleveland', 'Service', '85120', 6, 'wpeunt53q41t289g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Philadelphia', 'Delaware', '63403', 604, 'rfadlz54k36p085m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Dallas', 'Fieldstone', '73730', 9, 'vuntfo60q79j268u');
INSERT INTO public."Indirizzo_Utente" VALUES ('Kentucky', 'Louisville', 'Hudson', '04507', 63, 'iwzazo76c40z173j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Boulder', 'Rockefeller', '34329', 9, 'wjltqm70n02s381l');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Pasadena', 'Clove', '36311', 65577, 'gmpdjg41s85c745x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Illinois', 'Bloomington', 'Westport', '07927', 47, 'wgsdeu45m51x550z');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Glendale', 'Welch', '29450', 592, 'lulhsf09p30x463l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Cincinnati', 'Lakewood Gardens', '72963', 16398, 'ukoqtd42w51b987e');
INSERT INTO public."Indirizzo_Utente" VALUES ('Tennessee', 'Chattanooga', 'Troy', '55131', 7, 'novrai94y62t466f');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Brooklyn', 'Oneill', '74344', 0, 'odbnpx95k95p433r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Norfolk', 'Kinsman', '25690', 0, 'czrdqp51k52n440u');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Syracuse', 'Almo', '21955', 2, 'jlptxn26w04f695l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Oklahoma', 'Oklahoma City', 'Sage', '22963', 6407, 'jmjxlh00n92u300n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Cleveland', 'Gale', '04548', 75, 'eqorej11m60t194q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Washington', 'Seattle', 'Fremont', '95992', 1876, 'hbbeex67w98b398p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Scottsdale', 'Eastlawn', '98038', 921, 'bwgcrg80j60z952d');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Los Angeles', 'Cordelia', '31688', 37136, 'hdzhzn61k44v349x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Hialeah', 'Dunning', '49990', 42, 'egntdi74r39o485c');
INSERT INTO public."Indirizzo_Utente" VALUES ('South Dakota', 'Sioux Falls', 'Sloan', '08109', 50593, 'rvbptx01k67h766t');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Pasadena', 'Valley Edge', '04764', 204, 'arlbqv46e30w307n');
INSERT INTO public."Indirizzo_Utente" VALUES ('New Jersey', 'Newark', 'Drewry', '67995', 83822, 'jvyifm99v90s449y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Houston', 'Hazelcrest', '68874', 7644, 'tqqppd29p61m297o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Dallas', 'Twin Pines', '93989', 67150, 'ssiftj66g31y119z');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Brooklyn', 'Moulton', '78197', 505, 'dmjzqd59p11o659o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Kansas', 'Topeka', 'High Crossing', '17020', 91, 'zxpdvq25f01x297f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Orlando', 'Warner', '94774', 494, 'bhlbze73l66u350d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Houston', 'Goodland', '01943', 94, 'sudvaa64u35a304y');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Blackbird', '53940', 144, 'mkfvlo19m69f141z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Idaho', 'Pocatello', 'Thierer', '40974', 96508, 'cmzzun95i89h633u');
INSERT INTO public."Indirizzo_Utente" VALUES ('Utah', 'Salt Lake City', 'Iowa', '04712', 2279, 'llvxkg42o89c286h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Lynchburg', 'Corben', '69234', 40, 'jpzdyp65t38k965w');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Utica', 'Twin Pines', '65983', 7738, 'ihgqsk40g36m748g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Hialeah', 'Hauk', '57130', 10209, 'yltvxh79l69n942y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Pittsburgh', 'Muir', '06010', 4603, 'nphdhh80r81g345u');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Sacramento', 'Hollow Ridge', '19069', 258, 'tskfgo62n95y356w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Minnesota', 'Minneapolis', 'Gateway', '95927', 251, 'wjiqak87h56e932g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Houston', 'Artisan', '05651', 8, 'gbouok44o32j057t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Norcross', 'Thackeray', '44078', 479, 'zatzch37y47z709a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Hamilton', 'Ridge Oak', '76931', 6392, 'hdshix37s83s495s');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Flushing', 'Grim', '13456', 97441, 'spzxsw68j24x233l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'South Bend', 'Calypso', '53883', 10972, 'tugobv65i01e929x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Missouri', 'Saint Louis', 'Oak Valley', '63559', 445, 'crlzvo43u55v574l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Connecticut', 'New Haven', 'Crest Line', '87799', 9, 'puyeld92x63g173x');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Bakersfield', 'Village', '86874', 57072, 'hmdaox79r82u251l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Montana', 'Missoula', 'Sunbrook', '11326', 4155, 'xneehv18f10w732f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Marietta', 'Waxwing', '08853', 24, 'mphqfa89s08b688e');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Pasadena', 'Glacier Hill', '12550', 44, 'dqnour68u44g210s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Tyler', 'Cordelia', '30856', 7697, 'rhuulw30u78t147w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Corpus Christi', 'American', '45799', 84, 'bptjwu24n05g686j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Jeffersonville', 'Lake View', '52313', 8296, 'barlvi05b93x209w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Orlando', 'Logan', '28279', 8, 'kvxfnu83r92o803j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Atlanta', 'Dayton', '70473', 38212, 'msgzxc65z84l783v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Washington', 'Lakewood', 'Dayton', '37182', 92, 'bojbbg69p36r021b');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Carlsbad', 'Mariners Cove', '57702', 49, 'ufkqrn44n72b177n');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Sacramento', '2nd', '99701', 83882, 'dkdxql92m73y242m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Reading', 'Shasta', '21145', 244, 'zjbrmf42a64e406x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Cincinnati', 'Lukken', '98689', 33, 'lozcaw07a05l577a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Missouri', 'Saint Louis', 'Sheridan', '72836', 3335, 'lhylwe08j80o191j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Denver', 'Debra', '77841', 12293, 'gbrbkr56g87g635a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Philadelphia', 'Kim', '23443', 92957, 'vamjmf47o58j777w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Orlando', 'Old Shore', '94409', 150, 'eiaprm20e01b822l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Minnesota', 'Minneapolis', 'Montana', '72754', 9, 'enqhcw67x77z834h');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'North Hollywood', 'Johnson', '02676', 668, 'wwuzik62p31a377d');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Pasadena', 'Hauk', '03152', 724, 'hmujpg26i93u330r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Tuscaloosa', 'Mendota', '95483', 8, 'oqviwu80s05h035z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Wisconsin', 'Milwaukee', 'Glacier Hill', '61652', 3, 'uehnvf65j77r503u');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Lakeland', 'Golden Leaf', '19258', 68, 'bqeryb85h12e288b');
INSERT INTO public."Indirizzo_Utente" VALUES ('New Jersey', 'Trenton', 'Barby', '13725', 58, 'asykos14a99g005u');
INSERT INTO public."Indirizzo_Utente" VALUES ('Nevada', 'Las Vegas', 'Warrior', '53918', 8490, 'tcpmoo96v73g834i');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Denver', 'Almo', '28319', 171, 'afevdp04e21c505z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Illinois', 'Schaumburg', 'Cordelia', '07093', 262, 'ohdfns51t00g627v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Washington', 'Tacoma', 'Stephen', '01997', 58, 'gveczo21l43e938z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Washington', 'Vancouver', 'Leroy', '70567', 54, 'ukjoxm64i53e143f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Washington', 'Tacoma', 'Moose', '36304', 8, 'mpugjc76l42m611d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Minnesota', 'Minneapolis', 'Aberg', '21687', 7730, 'uhwycg93m35w526y');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Anaheim', 'Service', '54540', 33, 'rdkibo76h59u110y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Pittsburgh', 'Sundown', '91814', 1, 'prjasj98x82r650m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Pensacola', 'Northland', '68999', 63063, 'gkhklj82m85l361x');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'New York City', '5th', '78096', 1766, 'thshsv16v73p624d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Vermont', 'Montpelier', 'Grover', '05292', 7, 'rvpweg37g63x780l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Kansas', 'Topeka', 'Fairview', '83846', 76, 'cyyifu45e41v238s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'El Paso', 'Kim', '26014', 3761, 'lofzmh73m50c278v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Roanoke', 'Sutteridge', '97948', 0, 'jotyjq63b29u396x');
INSERT INTO public."Indirizzo_Utente" VALUES ('West Virginia', 'Charleston', 'Utah', '40020', 2, 'ibtqts02v87v774z');
INSERT INTO public."Indirizzo_Utente" VALUES ('South Carolina', 'Columbia', 'Harper', '19572', 0, 'npvals07a72i269e');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'El Paso', 'Tennessee', '85974', 2019, 'mstusy89h40u467h');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Sacramento', 'Schiller', '24426', 3, 'rpcmio07k15z730z');
INSERT INTO public."Indirizzo_Utente" VALUES ('West Virginia', 'Huntington', 'Coleman', '15352', 43, 'vlypir20b31b592e');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Bakersfield', 'Buhler', '25481', 0, 'aomsdz17v94r468w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Tampa', 'Eastwood', '21230', 38, 'ekdixj40p79r986k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Montana', 'Billings', 'Mayfield', '53449', 4327, 'ohejlz88u45c196l');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Jose', 'Monument', '41041', 38916, 'bnunep49r71w996s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Illinois', 'Springfield', 'Troy', '85579', 11, 'zpddfs28s55o436w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Illinois', 'Evanston', 'Schiller', '28863', 816, 'iqwzzu54e82y074l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Lakeland', 'Lighthouse Bay', '55925', 737, 'xzsvwo58s10x004x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arkansas', 'Fort Smith', 'Bowman', '02862', 68415, 'ffrkdt96a34i688u');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Debra', '65369', 5479, 'qegtmj78x01k882t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Massachusetts', 'New Bedford', 'Autumn Leaf', '19034', 66973, 'xpcddd79t48w361c');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Bethlehem', 'Old Shore', '81576', 720, 'skiwxa78z69t210g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Michigan', 'Kalamazoo', 'Milwaukee', '24375', 739, 'fogxok13p51u595j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Connecticut', 'Hartford', 'Butterfield', '56963', 6, 'alsvgn40t66i741v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Dallas', 'Brentwood', '72350', 33562, 'jtupkh52a44o086z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Fort Myers', 'Cody', '22108', 36520, 'rczdsn39i48i476x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Pensacola', 'Portage', '91222', 640, 'rexwhh02l41h534k');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Maple', '38185', 36588, 'xguxqy59d50k854a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Odessa', 'Moulton', '74545', 63, 'usilzk69c81t096c');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arkansas', 'North Little Rock', 'Johnson', '73465', 23015, 'jjpbfu28v46m598f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Prescott', 'Arizona', '86572', 7, 'xgcdkf00f78o283e');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Tampa', 'Annamark', '38842', 9, 'wbekan72k84k751t');
INSERT INTO public."Indirizzo_Utente" VALUES ('New Mexico', 'Albuquerque', 'Maple', '34078', 612, 'jguvik15v25f237h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Kentucky', 'London', 'Kinsman', '67240', 574, 'yeaolb30q53w012k');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'New York City', 'Pawling', '04711', 5875, 'qbqbdg66p89k390r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Louisiana', 'New Orleans', 'Northridge', '48837', 1485, 'njvypc84o38o790p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Louisiana', 'Baton Rouge', 'Colorado', '34477', 2386, 'voslye64y98a963z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Oklahoma', 'Oklahoma City', 'Nelson', '86918', 55, 'zkqxgz07n36z490p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Nebraska', 'Lincoln', 'Lakewood', '19535', 7924, 'qjcmuu79f39d249a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Montgomery', 'Larry', '02979', 16, 'odfwld70g83z476n');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'New York City', 'Moose', '20912', 83, 'jbmcux55d48d822v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Mississippi', 'Meridian', 'Maryland', '36324', 7277, 'bnynff06n90z005d');
INSERT INTO public."Indirizzo_Utente" VALUES ('North Carolina', 'Winston Salem', 'Kipling', '57480', 819, 'qieing39s21x343v');
INSERT INTO public."Indirizzo_Utente" VALUES ('North Carolina', 'Raleigh', 'Tennyson', '78795', 0, 'jxogzd07p33w688t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Michigan', 'Grand Rapids', 'Myrtle', '35944', 3, 'lngpge76v27g291n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Wisconsin', 'Milwaukee', 'Rieder', '19635', 3, 'pikcfu27s86f073u');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Buffalo', 'Steensland', '32631', 814, 'yarpnl54v88x460c');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Lakeland', 'Shelley', '45354', 76, 'jfhbjt01l66n806y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Missouri', 'Kansas City', 'Jenifer', '24284', 9421, 'oqwmus57k63x804d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Huntsville', 'Gateway', '79988', 9199, 'rfsvkn71a26l304y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Tennessee', 'Memphis', 'Badeau', '37758', 3676, 'macokn00k08m250l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Ocala', 'Scofield', '11493', 3596, 'rhwzay80o42s558w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Houston', 'Messerschmidt', '88061', 3250, 'nbaifh35s94i306d');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'North Hollywood', 'Elmside', '12339', 22730, 'afaelp22b25y237q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Michigan', 'Warren', 'Northwestern', '79959', 9, 'mtyqjs84i40a613b');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Bernardino', 'Grover', '00330', 4382, 'basecz30j50w498g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Virginia Beach', 'Mayfield', '21517', 726, 'cxpehm82s28b201q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Miami', 'Almo', '11875', 42206, 'zvxods62b20v677t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Houston', 'Forster', '81519', 91762, 'lzngve90z13e311z');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'New York City', 'Lakeland', '72281', 41120, 'hqsmlq58i17v471q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Arlington', 'Sauthoff', '61810', 8, 'klanfs50b40q297g');
INSERT INTO public."Indirizzo_Utente" VALUES ('New Mexico', 'Albuquerque', 'Colorado', '50393', 71178, 'bcuydp17x49a157a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Boca Raton', 'Kropf', '89254', 987, 'pjmdlb77f82n198l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Miami', 'Rusk', '12232', 81019, 'xmdgjw84o94h380n');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Brooklyn', 'Carey', '69529', 994, 'hmsgpt01d84g745h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Wisconsin', 'Green Bay', 'Ronald Regan', '47535', 8607, 'zfdloy29u91j706j');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Concord', 'Lien', '54436', 6627, 'zdblid66n51o834b');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Tucson', 'Grover', '01723', 9, 'icyuxc92z94e999o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Pinellas Park', 'Fremont', '89819', 6500, 'kwojjj12m53p793k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Miami Beach', 'Fremont', '19640', 52418, 'djoete11x09k809f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Miami', 'Loomis', '20330', 2, 'howecb81u20i898y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Missouri', 'Saint Louis', 'Pleasure', '08748', 87, 'enlqky34g04n287q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Merrifield', 'Esch', '59192', 26386, 'drvuoj51w00l471z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Dayton', 'Merrick', '89072', 12201, 'lgbsfq57s18w797w');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Buffalo', 'Quincy', '11454', 9, 'kvynid63z16f330t');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Scott', '80513', 816, 'cnjpmm65o70g783m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Colorado Springs', 'Union', '40044', 3820, 'iznhvu37s97b768g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Minnesota', 'Minneapolis', 'Spenser', '45401', 4, 'gittwg92z66d467x');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Diego', 'Elgar', '14090', 110, 'mfbvcv67j27n744m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Massachusetts', 'Boston', 'Oakridge', '15353', 5, 'hweubz49l24o935x');
INSERT INTO public."Indirizzo_Utente" VALUES ('North Carolina', 'Asheville', 'Union', '98420', 4, 'vpzjhh57a31l572a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Houston', 'Arizona', '88271', 2298, 'zipntx83x58r802s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Louisiana', 'Metairie', 'Karstens', '15890', 57, 'nfubre77p83m535l');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Van Nuys', 'Waywood', '20088', 76, 'ecpgzf37z65c854l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'El Paso', 'Hanson', '43367', 85208, 'qqfgsc49a12m071h');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Judy', '15724', 2311, 'wkazon37d86e565m');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Lancaster', 'Pankratz', '64224', 94286, 'fmvyhh44b41f640o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Colorado Springs', 'Forest Dale', '66334', 66, 'vqoktq18k67t847v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Louisiana', 'New Orleans', 'Clarendon', '28849', 688, 'cdqmve04q28n325e');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Canary', '19878', 1382, 'raosmo78h47e378s');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Los Angeles', 'Oakridge', '04022', 416, 'shtfay63q77a356p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Conroe', 'Golf', '62189', 91, 'tohydz28a51e989f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Wisconsin', 'Milwaukee', 'American', '84047', 4, 'elnrhz27j17b779c');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Colorado Springs', 'Clemons', '90023', 42419, 'ghtwsc37j43a961m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Michigan', 'Grand Rapids', 'Truax', '24900', 4959, 'jkvqvi18x34n809x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Hollywood', 'Jenifer', '16330', 6, 'jhlccw43c64k583r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Orlando', 'Anniversary', '64406', 2308, 'uqmgyx68u80y009b');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Bloomington', 'Fisk', '27493', 138, 'wuxraa79f72p982m');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Stockton', 'Birchwood', '93321', 458, 'ydlbgc84q68r799c');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Boulder', 'Havey', '71398', 4616, 'kwjsje79m04i279d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Virginia Beach', 'Spohn', '14685', 29, 'zrdncd83h87c914c');
INSERT INTO public."Indirizzo_Utente" VALUES ('New Jersey', 'Newark', 'Commercial', '13197', 947, 'jkbajd67f27m061r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Houston', 'Pawling', '33267', 9195, 'seuetv47u44n335p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Minnesota', 'Monticello', 'Coleman', '81944', 43, 'wzzcov47j78o537e');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Saint Augustine', 'Burrows', '80847', 224, 'ipafqp15a18h244a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Dallas', 'Troy', '93500', 3, 'hxfyhz76g34c459e');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Colorado Springs', 'Hauk', '65312', 2, 'mqjihf78t38p027v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Tampa', 'Ohio', '64376', 1358, 'bxkoad02s65q361g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arkansas', 'Fort Smith', 'Montana', '80671', 517, 'zaqqfb89l43t744e');
INSERT INTO public."Indirizzo_Utente" VALUES ('Kansas', 'Topeka', 'Pawling', '17602', 751, 'bihrha68t94f578n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Houston', 'Stang', '74790', 222, 'xoldjt13f67k819a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Minnesota', 'Saint Cloud', 'Nova', '34776', 79, 'qrrwvf24s55i034r');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Mountain View', 'Walton', '37683', 47, 'bfsurf19x35y922x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Louisiana', 'New Orleans', 'Pankratz', '00787', 879, 'mjqpkz49g04d758y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Huntsville', 'Quincy', '38031', 15399, 'wvofbb45r59q816j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Macon', 'Warbler', '67434', 534, 'lxbbns09i25h492v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Plano', 'Tomscot', '64608', 13, 'bomjnq25b90q725w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Temple', 'Kensington', '30798', 2, 'apyysh24a26j005e');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Birmingham', 'Westend', '20059', 93868, 'moesxu49c71g977y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Roanoke', 'Continental', '47030', 8850, 'izteil26u86d915e');
INSERT INTO public."Indirizzo_Utente" VALUES ('Illinois', 'Joliet', 'Moose', '63922', 97, 'obfynz32p53w166h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Minnesota', 'Young America', 'Oakridge', '37098', 20, 'jdvcph01b40l237u');
INSERT INTO public."Indirizzo_Utente" VALUES ('Wisconsin', 'Madison', 'Bluestem', '56870', 7310, 'ludmcw24p67j143p');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Los Angeles', 'Dapin', '35222', 46, 'auhpxk29v73u922q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Daytona Beach', 'Aberg', '78675', 4, 'fkictm54k21c357e');
INSERT INTO public."Indirizzo_Utente" VALUES ('West Virginia', 'Charleston', 'Mariners Cove', '24309', 5486, 'ohttye54b04b897u');
INSERT INTO public."Indirizzo_Utente" VALUES ('Missouri', 'Saint Louis', 'Vermont', '59181', 49449, 'uyidwe82n70t137a');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Chico', 'Moulton', '96387', 1734, 'mdctpl49j81y925j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Jacksonville', 'Hanson', '61129', 26409, 'bkijhc32p77m782y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Miami', 'Bunting', '51283', 4, 'uaduog26g70k466x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Oklahoma', 'Oklahoma City', 'Schiller', '77753', 3771, 'iqakur57c83w463l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Oklahoma', 'Tulsa', 'Pepper Wood', '37036', 767, 'xngeyr38m79v548p');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Francisco', 'Rieder', '89185', 1329, 'annecp02r49p479y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Washington', 'Vancouver', 'Warner', '28246', 54, 'ecodwj05p83r038c');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Oakland', 'Norway Maple', '32443', 901, 'llxyjv39q96r417x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Norfolk', 'Nova', '83205', 7, 'uunmbh80e00a440q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Montana', 'Helena', 'Elmside', '90604', 310, 'obtvgk59k30k461l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'El Paso', 'Texas', '90101', 9, 'olsqtg55l98o051j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Hollywood', 'Thackeray', '79109', 615, 'hftajy85d40h677v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'San Antonio', 'Messerschmidt', '84003', 855, 'scsktb20x18x904r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'San Antonio', 'Shelley', '95916', 5702, 'khoajt31w93n563n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Miami', 'Sutherland', '81340', 372, 'llkhwg02z66j440f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Montgomery', 'Truax', '83765', 66, 'quvuxp16g89r663l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Mobile', 'Maple', '21410', 47, 'kozzbn29q60c719k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Wisconsin', 'Madison', 'Rigney', '16000', 82, 'xnfktv82w33f454u');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Ocala', 'Jenifer', '72147', 6, 'zgbpva26u75t620w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Minnesota', 'Maple Plain', 'Gulseth', '69574', 6, 'ugaztl54m29k901u');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Hamilton', 'Trailsway', '59790', 7716, 'tqywah35l92r927k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Fort Wayne', 'Garrison', '06603', 740, 'tqfmrq49q16l282e');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Huntsville', '3rd', '03535', 467, 'bpnyrg47u37p879q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Columbus', 'Northfield', '84939', 3973, 'rzimge24f96j698f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Kentucky', 'Lexington', 'Lighthouse Bay', '68790', 7, 'lkcnpv28m20l624y');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Bernardino', 'Stang', '68032', 9381, 'xvmxtn92n36b382i');
INSERT INTO public."Indirizzo_Utente" VALUES ('Missouri', 'Columbia', 'Carey', '41624', 7, 'qoujvr86k52c518s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Canton', 'Ruskin', '95715', 8, 'xiumjg34l50p485k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Norfolk', 'Fulton', '49027', 82, 'qcqhug04u68p948h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Hawaii', 'Honolulu', 'Arizona', '64013', 6101, 'lqkafs68v35m039d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Massachusetts', 'Boston', 'Tomscot', '15426', 64410, 'xgdlsg09d20j444f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Anderson', 'Starling', '17352', 66, 'jxwrvj41g60x674f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Pueblo', 'Badeau', '81439', 83, 'iaptwh25f49g525c');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Dallas', 'Morningstar', '72046', 321, 'fdmjxt81t90a612m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'El Paso', 'Kingsford', '92722', 522, 'nfhxah90f46a395y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Connecticut', 'Fairfield', 'Shasta', '71856', 3456, 'fsswlb51h22r336m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Cincinnati', 'Talmadge', '62832', 66, 'qxfswq15q34k908d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Louisiana', 'New Orleans', 'Arapahoe', '14261', 68737, 'wrzhwr12v35v469v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arkansas', 'North Little Rock', 'Monument', '63927', 918, 'xqjqsj22s53j343w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Missouri', 'Kansas City', 'Knutson', '46147', 92, 'npaasj13w80e840k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Amarillo', 'Londonderry', '04759', 1, 'lzxfhf46x39c384y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Conroe', 'Aberg', '45852', 8, 'oafbri03z30m987q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Oregon', 'Portland', 'Raven', '55061', 3, 'ubfrzb37q77v680p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Colorado Springs', 'Charing Cross', '52345', 812, 'hhbtpk61e61o291a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Massachusetts', 'Newton', 'Mariners Cove', '46357', 25, 'rlibgl30j46v371y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Toledo', 'Heffernan', '04385', 470, 'kdtfcn79s21p612q');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Albany', 'Service', '78332', 450, 'fristt67s63j409v');
INSERT INTO public."Indirizzo_Utente" VALUES ('South Carolina', 'Greenville', 'Montana', '52620', 359, 'exgomz68k77t912z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Richmond', 'Columbus', '70205', 684, 'xfcicw80r08r100t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Utah', 'Salt Lake City', 'Spenser', '88771', 66522, 'hvndpl50h62o530m');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Sacramento', 'Northridge', '67140', 6860, 'bdjvbi33m53t625z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Roanoke', 'Warbler', '09937', 97, 'ffcpim26n71x325n');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Logan', '81818', 42339, 'zxwbwq99l80l428o');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Bluestem', '72270', 395, 'nudode58l02k544a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Largo', 'Schmedeman', '99793', 8, 'lgeelp21x54t401o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Terre Haute', 'Prentice', '97700', 810, 'lhglnt17c31l069s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Terre Haute', 'Hallows', '43897', 326, 'zzwqfm68z09f054y');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Lancaster', '7th', '68179', 34344, 'dqtpkh21m26b550p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Atlanta', 'Steensland', '06041', 26, 'bfzdxl39q02f128t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Atlanta', 'Scoville', '60717', 57526, 'kuchaa66p97a446f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Nevada', 'Reno', 'Memorial', '05633', 22, 'pihtpy79q85i032p');
INSERT INTO public."Indirizzo_Utente" VALUES ('West Virginia', 'Charleston', 'Dapin', '17235', 234, 'ukoufd29b46x227v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Utah', 'Salt Lake City', 'Jackson', '40057', 32839, 'bpwfja33i96v369r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Pittsburgh', 'Lindbergh', '05068', 3, 'vwmcbc15b97d930f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Missouri', 'Independence', 'Ruskin', '31314', 678, 'ardagt65d29l119c');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Dapin', '89247', 7042, 'mqqqmw89j20h581o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Hollywood', 'Logan', '60616', 28, 'yugnle53c26d088c');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', '1st', '26911', 1236, 'vwkyvm19a40v432p');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Brooklyn', 'Lakeland', '42512', 2, 'ifjogt36j16q247p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Herndon', 'Upham', '42389', 67031, 'dsxund34d42t407c');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Wilkes Barre', 'Cascade', '53862', 3617, 'ctlvfg39x09m076x');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Bernardino', 'Prairie Rose', '62126', 5612, 'mpmeue99o05b674v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Houston', 'Lukken', '13383', 90, 'vfbypt52f96s706s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Cleveland', 'Talisman', '77344', 9, 'xqwlht95h90b044d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Corpus Christi', 'Bartelt', '97643', 8566, 'jqfekx37i88g211s');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Buffalo', 'Derek', '86897', 770, 'duloai47d32u213i');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Mount Vernon', 'Londonderry', '72630', 949, 'bftxht35o53q780i');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Brea', 'Cambridge', '35001', 142, 'zsakvr78s35n450g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Philadelphia', 'Annamark', '99907', 1, 'mwirvs69z57q873k');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Diego', 'Hansons', '63847', 2, 'ponxcc71m36d809c');
INSERT INTO public."Indirizzo_Utente" VALUES ('South Carolina', 'Charleston', 'Old Gate', '08022', 52, 'tbroan15r23a113p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Iowa', 'Davenport', 'Moulton', '31742', 798, 'zciqgj75r12o873c');
INSERT INTO public."Indirizzo_Utente" VALUES ('Idaho', 'Pocatello', 'Burning Wood', '91310', 19300, 'xdanfe96h55v748q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Columbus', 'Lerdahl', '94130', 2, 'trnqnk84e29u913u');
INSERT INTO public."Indirizzo_Utente" VALUES ('Michigan', 'Lansing', 'Clarendon', '51694', 5632, 'hkijft53v60l285u');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Atlanta', 'Crest Line', '95114', 66, 'lzrqne35t22d761j');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Sacramento', 'Linden', '71566', 97283, 'tpzqcs75b55o919j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Akron', 'Eggendart', '40572', 3, 'zeoiwm49h16h840r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Fort Worth', 'Ridgeview', '70260', 529, 'ywosjj61h39i270m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Mississippi', 'Columbus', 'Gulseth', '88915', 8399, 'exgxsi88u90c580g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Wichita Falls', 'Cascade', '77659', 7492, 'gjmrrl51s40t554j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Fort Wayne', 'Tony', '73520', 27622, 'ezlegw36e08f986p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Hawaii', 'Honolulu', 'Bashford', '55832', 47660, 'rewypw84q68f439q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Dallas', 'Macpherson', '76004', 63, 'tiqcnd30c04k211w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Tennessee', 'Johnson City', 'Sutherland', '23157', 4363, 'skhsvx38d57j037y');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'New York City', 'Summerview', '23628', 210, 'opkdmx82q96v497g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Macon', 'Northland', '10397', 26, 'cklkxw52x69z099b');
INSERT INTO public."Indirizzo_Utente" VALUES ('Massachusetts', 'Worcester', 'Hazelcrest', '55749', 8, 'pfcrwp48g10v003x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Augusta', 'Spaight', '33640', 17, 'sblzzg67b93t197x');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Weeping Birch', '40160', 95494, 'xrralw82e08v360o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Utah', 'Ogden', 'Ohio', '15669', 1, 'cmzjnm08o72k409o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Utah', 'Salt Lake City', 'Dapin', '15298', 47, 'gmtjsw06w80t092i');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Long Beach', 'Springs', '42401', 98833, 'scpyja36l85l617n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Illinois', 'Springfield', 'Dahle', '34711', 70077, 'pmidcj71b33m782z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Illinois', 'Springfield', 'Melrose', '10443', 61, 'hdpesk66x89k067c');
INSERT INTO public."Indirizzo_Utente" VALUES ('Missouri', 'Saint Joseph', 'Schlimgen', '04556', 89020, 'ixnpuo27k37o212m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Lubbock', 'Bartelt', '46151', 704, 'uxkikh93r19g758u');
INSERT INTO public."Indirizzo_Utente" VALUES ('West Virginia', 'Charleston', 'Sachtjen', '98400', 1, 'sokctb94p27q463i');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Warren', 'Sherman', '16387', 663, 'jgbiei29e12j485e');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'El Paso', 'Crescent Oaks', '93649', 9, 'ssulwp93d90y984m');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Buffalo', 'Emmet', '64155', 7, 'lohckf18x62b857g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Birmingham', 'Kings', '84884', 32871, 'ktxxnl90r23g348f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Galveston', 'Talisman', '79436', 48042, 'vhrkqt60k00v373o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Jacksonville', '8th', '84307', 49502, 'tbcmfh14n72w698d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Illinois', 'Decatur', 'Onsgard', '31098', 600, 'cbsbxx56k81t090y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Washington', 'Seattle', 'Badeau', '90745', 92, 'kvqago13f81p212u');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Greeley', 'Goodland', '17958', 4903, 'viuddp56j62v130h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Louisiana', 'New Orleans', 'Kings', '63853', 66, 'adxbmd30j19z192r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'San Angelo', 'Welch', '60061', 351, 'hpufhh51a55b097l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Denver', 'Cordelia', '20865', 222, 'pdghjn91g74d623z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Columbus', 'Ohio', '33690', 829, 'hiofmu56s34h169w');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Rafael', 'Bayside', '06896', 40, 'bftfgh93w09r166o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Minnesota', 'Duluth', 'Kings', '63318', 1432, 'jsmpkt16n81s383f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Saint Petersburg', 'Crescent Oaks', '06709', 64, 'wcqfei19b59m823g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Denver', 'Farmco', '37992', 659, 'xngiol60e23a374x');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Fairfield', '67853', 81, 'hzjqaq42a55y521k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Fort Lauderdale', 'Morning', '65766', 28, 'rcjfqb20g23f126v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Maryland', 'Bethesda', 'Maryland', '61998', 230, 'txztth11e79e970t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Tampa', 'Northview', '11530', 230, 'tyytql38d10y799z');
INSERT INTO public."Indirizzo_Utente" VALUES ('South Carolina', 'Charleston', 'Declaration', '58103', 4, 'obnfnr13v91w015v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Pittsburgh', 'Grim', '34502', 1545, 'yasykf87s26b647y');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Albany', 'Pennsylvania', '01821', 8, 'ebdgff96n08s127b');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Hampton', 'Bartelt', '76558', 7511, 'sjiqwc68k85w831d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Missouri', 'Saint Louis', 'Melrose', '62602', 1681, 'clgshe63e17h166k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Nevada', 'Reno', 'Montana', '06025', 0, 'xxqcxc35d90f267z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Montgomery', 'Banding', '98912', 800, 'bmoobe04g61y451e');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Ashburn', 'Holy Cross', '39428', 45, 'ogujsd38d81w417k');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Jose', 'Randy', '82292', 26086, 'equxsr90u02a345z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Washington', 'Lakewood', 'Fuller', '82094', 82661, 'nmvemu08p21v416d');
INSERT INTO public."Indirizzo_Utente" VALUES ('North Carolina', 'Charlotte', 'John Wall', '63726', 1739, 'yuumrk01g62f471r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Terre Haute', 'Morning', '72839', 253, 'kutslw34b66r609b');
INSERT INTO public."Indirizzo_Utente" VALUES ('Missouri', 'Saint Louis', 'Wayridge', '00897', 2875, 'wtoryf43s81x218d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Fort Wayne', 'Badeau', '24224', 1829, 'qaghwm17m80y113z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Houston', 'Transport', '12145', 4921, 'evnadj38f23k500k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Pittsburgh', 'Moose', '76186', 8328, 'eqteoh21u53s314n');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Francisco', 'Hagan', '15459', 9853, 'qlcfhp24s85q780o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Idaho', 'Boise', 'Florence', '30118', 26, 'duhlky74h12q162o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'San Antonio', 'Donald', '25438', 26, 'dzmrbh92i53p453g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Utah', 'Salt Lake City', 'Buena Vista', '64429', 26151, 'ixdqul09x51b555d');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'New York City', 'Saint Paul', '03980', 26743, 'cjtrmh44w40w192a');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Berkeley', 'Blaine', '10734', 2825, 'einhxg53v09c321q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Wisconsin', 'Milwaukee', 'Westend', '42051', 81463, 'pykimr64x12p451h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Atlanta', 'Ilene', '30938', 338, 'mopsaj64h17z948p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Montgomery', 'Pine View', '40874', 9195, 'nlotey53e41r450n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Houston', 'Anniversary', '63434', 83451, 'ykrhgl94k23d143g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Tennessee', 'Knoxville', 'Rieder', '79137', 4373, 'axxoid02y32q285i');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Denver', 'Acker', '40104', 4379, 'qibewz92c69m111l');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Bronx', 'Chinook', '32333', 299, 'bndkoa28e01c208k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Fort Lauderdale', 'Pleasure', '09369', 5584, 'vgrvnb89j59z180k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'El Paso', 'Clove', '82570', 4920, 'dkzjmv15x11i385a');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Inglewood', 'Talmadge', '84716', 9, 'nvczjf95i29t527j');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Schurz', '28112', 8850, 'gvycuq72l12p975j');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Pasadena', 'Bellgrove', '12304', 4, 'shhewd06f05a102t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Beaumont', 'Eliot', '19733', 1577, 'qubzoq79c04p772k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Houston', 'Nobel', '55988', 6900, 'qnsjeq08r56k988k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Utah', 'Salt Lake City', 'Saint Paul', '93007', 83294, 'ucnkzq22m53t597p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Round Rock', 'Scott', '96366', 8, 'jsbudk58y24q088o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Kentucky', 'London', 'Sundown', '15110', 23, 'mfkdog62l63d161s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alaska', 'Fairbanks', 'Lukken', '45342', 535, 'sarvux60f29y158s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Tennessee', 'Memphis', 'Meadow Ridge', '50621', 3442, 'nohriy95k73y200k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Jacksonville', 'Melrose', '31441', 43, 'jqvewh93j68z701g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Maryland', 'Baltimore', 'Norway Maple', '27057', 47339, 'qhttor58x47m066c');
INSERT INTO public."Indirizzo_Utente" VALUES ('Montana', 'Helena', 'Washington', '85035', 19, 'xmocmt89q12t626g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Michigan', 'Lansing', 'Cascade', '93123', 334, 'hucyov34k17v780g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Louisiana', 'Lafayette', 'Thierer', '93891', 30, 'nhwmlw44w30l702h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Houston', 'Talisman', '04423', 7, 'oycydh85e02p955a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Philadelphia', 'Donald', '14928', 80412, 'sxmwzq91u92w214b');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Dallas', 'Butternut', '03254', 77235, 'wemana21i73h832m');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Brooklyn', 'Scoville', '08846', 9008, 'jlrrst14y70t692c');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Colorado Springs', 'International', '99403', 89799, 'butwxl50p41q322s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Dallas', 'Golden Leaf', '81833', 16, 'swrnsz54x61q992o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Mississippi', 'Meridian', 'Amoth', '17988', 89462, 'ucuaeh94x90q850l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Newport News', 'Pleasure', '14847', 53, 'hblxhd02x59b770o');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Flushing', 'Delaware', '93705', 179, 'ruzbys77c77q184a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alaska', 'Fairbanks', 'Randy', '02359', 1556, 'ptocve02t66w367p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arkansas', 'Little Rock', 'Gateway', '07486', 380, 'htvpeo39x14x967q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alabama', 'Birmingham', 'Ohio', '40959', 87735, 'emvuvv46i53d338b');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Phoenix', 'Autumn Leaf', '27072', 68934, 'mepuof28k68t372f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Oklahoma', 'Oklahoma City', 'Cottonwood', '65020', 91, 'vftrdm62o73p533y');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Francisco', 'Golf', '91195', 7409, 'nsmybb45j72k928t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Garland', 'Mccormick', '10059', 79030, 'ydgash45g38e546d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Fort Wayne', 'Talmadge', '73036', 349, 'prmuko49o09l616e');
INSERT INTO public."Indirizzo_Utente" VALUES ('South Carolina', 'Columbia', 'Del Mar', '69175', 756, 'zorjak20b50i009d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Massachusetts', 'Woburn', 'Coleman', '28279', 447, 'rsxbfz39a45f163n');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Jamaica', 'Emmet', '88063', 844, 'dgktbe08n06t179e');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Philadelphia', 'Columbus', '73522', 7987, 'drrelb03s15v059x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Oregon', 'Salem', 'Oak', '89179', 798, 'sbkise26i66t122s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Tennessee', 'Memphis', 'Rowland', '60453', 97007, 'laxngo38j52m700w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Amarillo', 'Arapahoe', '33838', 4, 'kohwcz32d46l460a');
INSERT INTO public."Indirizzo_Utente" VALUES ('West Virginia', 'Huntington', 'Veith', '04552', 0, 'cqcjgg58q24c831r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Minnesota', 'Minneapolis', 'Mccormick', '51519', 43540, 'xmsijg63l12s639z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Kansas', 'Kansas City', '6th', '31913', 96, 'auooaj15j88t161n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Phoenix', 'Scott', '02756', 8, 'fwehbk26j45c940l');
INSERT INTO public."Indirizzo_Utente" VALUES ('South Carolina', 'Charleston', 'Commercial', '61944', 39, 'cgqumv26r82p865s');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Sacramento', 'Red Cloud', '66077', 357, 'awcdpf89m62f096x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Philadelphia', 'Vernon', '55644', 73991, 'aylpth64k71m888d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Kansas', 'Shawnee Mission', 'Kinsman', '68707', 267, 'yczqoq98j82w144n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Miami', 'Kropf', '31890', 5090, 'emdafs40a07u366v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arkansas', 'North Little Rock', 'Michigan', '96663', 5553, 'cjdhlm49k86n410d');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Jamaica', 'Summer Ridge', '13881', 2, 'aiotxz32z96i872v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Augusta', 'Clyde Gallagher', '36773', 1724, 'erytna23g13n127w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Pittsburgh', 'Sage', '50720', 9086, 'xudiov93e56s778y');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Salinas', 'North', '86455', 54645, 'ibbitu67x49g514i');
INSERT INTO public."Indirizzo_Utente" VALUES ('Utah', 'Sandy', 'Monica', '49488', 847, 'vpdqwd67q77b872r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'San Antonio', 'Lighthouse Bay', '20768', 26113, 'crlrhn00l98g560l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Fort Lauderdale', 'Saint Paul', '10149', 88, 'qdunvq89b81w112q');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Rochester', 'Meadow Ridge', '85679', 3, 'qrdfvx26m69v020a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Denver', 'Schmedeman', '94285', 12601, 'gbwlfo28g88g071h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Scottsdale', 'Oneill', '07494', 99837, 'gagpuc02z52s656a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Iowa', 'Des Moines', 'Maple Wood', '10579', 6320, 'lmtmdc41j16j125c');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Diego', 'Red Cloud', '68104', 28, 'opbtsv02u98d897y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Kentucky', 'Lexington', 'Anthes', '53643', 486, 'qxyzjc98z31k064u');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Cincinnati', 'Ohio', '08217', 45671, 'aavycj77e20t882g');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Syracuse', 'Katie', '81532', 892, 'baiobm25k20s846t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Montana', 'Helena', 'Parkside', '18332', 85056, 'foymmb40r90p084x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Columbus', 'Erie', '29485', 26, 'nwxlcb98g56e528g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Tennessee', 'Nashville', 'Bultman', '40415', 83, 'vsuhjm76b27y231s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Nevada', 'Carson City', 'Blue Bill Park', '83425', 34, 'xivxll79q11v923n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Illinois', 'Schaumburg', 'Hauk', '24888', 16, 'xhlfek60f79i314l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Washington', 'Vancouver', 'Eastlawn', '31440', 84274, 'tchwfy71w28u252i');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Cincinnati', 'Columbus', '81936', 95, 'dujejn88c17t587b');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Miami Beach', 'Eliot', '22947', 10, 'nfmdjr50z00f926x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Harrisburg', 'Thierer', '81030', 41, 'zjsdeq11w23x084p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Fort Wayne', 'Corry', '90906', 171, 'luikgu44t38y101b');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Bakersfield', 'Dryden', '09285', 67064, 'wdehow13a10r333m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'New Castle', 'Roth', '73361', 8, 'wfxlwp66q74u047s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Roanoke', 'Green Ridge', '71872', 37, 'xcxwxt17c68m371i');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Colorado Springs', 'Crownhardt', '24523', 3278, 'ouviyt71a39p590d');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Lighthouse Bay', '77959', 7007, 'uxajst00k41c368h');
INSERT INTO public."Indirizzo_Utente" VALUES ('Wisconsin', 'Green Bay', 'Union', '13187', 5, 'hrcawo27o55a913t');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Albany', 'Montana', '34395', 1, 'yqenom98n71d593q');
INSERT INTO public."Indirizzo_Utente" VALUES ('West Virginia', 'Huntington', 'Fordem', '20076', 80343, 'dusbmk05l77w576q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Fort Wayne', 'Crownhardt', '79497', 5085, 'yellrl68r45d215x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Chandler', 'Sutteridge', '58569', 4226, 'tuvgag33j43w087t');
INSERT INTO public."Indirizzo_Utente" VALUES ('North Carolina', 'Charlotte', 'Wayridge', '15604', 9537, 'lncazu41q98k827o');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Modesto', 'Lukken', '27471', 65, 'wrvbbe11l86q313x');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Bakersfield', 'Grim', '42296', 80420, 'xxpevz73k16n159e');
INSERT INTO public."Indirizzo_Utente" VALUES ('Illinois', 'Springfield', 'Linden', '19043', 77, 'zlizkw43s16s121g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Evansville', 'Scofield', '85572', 6482, 'szvzil69f96t834z');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Brooklyn', 'Forster', '43107', 2, 'lzfhbt40w47w627s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Gainesville', 'Dakota', '13239', 80, 'qauyzs35h04u852z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Louisiana', 'Baton Rouge', 'Sachs', '76592', 347, 'kletzv63u76f504g');
INSERT INTO public."Indirizzo_Utente" VALUES ('South Dakota', 'Sioux Falls', 'Portage', '77747', 296, 'cpankf96t90w819c');
INSERT INTO public."Indirizzo_Utente" VALUES ('South Carolina', 'Columbia', 'Vahlen', '45728', 8233, 'olwodi94y50n287g');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'New York City', '4th', '98302', 35585, 'bnchvj62u93c338x');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Stuart', '56328', 4, 'upojhv85v21y657j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Harrisburg', 'Emmet', '26732', 2, 'zcixqi34p90r219c');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Syracuse', 'Hanson', '19089', 59640, 'qfqoer82h27z895c');
INSERT INTO public."Indirizzo_Utente" VALUES ('Maryland', 'Bowie', '5th', '78943', 605, 'stwuym84i21m794p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Savannah', 'Westend', '45499', 3575, 'emhgwp09b21w292o');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Jamaica', 'Florence', '67611', 77217, 'bfopal70y89f721o');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Merry', '74858', 0, 'ywkwmy24d62b364d');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Oakland', 'Dawn', '47711', 4937, 'moakdn93r27i302u');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Fort Wayne', 'Village Green', '85771', 697, 'aqvgpk54j95u014v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Rhode Island', 'Providence', 'Columbus', '75660', 8, 'bjazhh32x77u824s');
INSERT INTO public."Indirizzo_Utente" VALUES ('Washington', 'Spokane', 'Iowa', '89092', 45, 'viqobg96w51c209h');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Rutledge', '21832', 2629, 'uvhxyi95f98q713g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Colorado Springs', 'Schiller', '01886', 4510, 'nkmwvt00z94g910t');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Debra', '73355', 1965, 'ykzpok36z04w358y');
INSERT INTO public."Indirizzo_Utente" VALUES ('Florida', 'Clearwater', 'Russell', '91435', 5064, 'cgclth93h04n356c');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Sacramento', 'Kennedy', '64573', 425, 'kabfgv84w55y983e');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Albany', 'Mcguire', '80076', 3210, 'onzptx90a15x215g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Alaska', 'Anchorage', 'Muir', '26197', 829, 'pndokq85r17q571i');
INSERT INTO public."Indirizzo_Utente" VALUES ('Indiana', 'Gary', 'Forest', '94003', 860, 'ljways94j48y740c');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Diego', 'Oakridge', '93188', 6, 'cvkxuv16t63j691q');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Los Angeles', 'Bay', '74198', 34248, 'vrootv59h13l788d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Tennessee', 'Nashville', 'Logan', '22647', 32286, 'dfqmvw42j35g373o');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'San Francisco', 'Mallard', '87182', 33001, 'wzycdo43f28d433j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Wisconsin', 'Milwaukee', 'New Castle', '59333', 20797, 'aaxsin33h11b155c');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Reston', 'Saint Paul', '49030', 3080, 'etaajl96j32y708o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'El Paso', 'Browning', '87452', 43272, 'rikmtj53b43e406p');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Burbank', 'Moulton', '43380', 5, 'ywteze40q58a111f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Missouri', 'Saint Louis', 'Cherokee', '11017', 8197, 'rgvtyx61d28g732u');
INSERT INTO public."Indirizzo_Utente" VALUES ('South Carolina', 'Spartanburg', 'Lukken', '52333', 4, 'tmptmg26g52i537v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Minnesota', 'Minneapolis', 'Pankratz', '71023', 1209, 'nyhupd23o97o684q');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Simi Valley', 'Declaration', '82914', 4052, 'ozbbym77d46h491n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Laredo', 'John Wall', '41157', 7, 'yiydvq30h23f343w');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'El Paso', 'Straubel', '73656', 4, 'joasbm75r57y197m');
INSERT INTO public."Indirizzo_Utente" VALUES ('Colorado', 'Colorado Springs', 'Talmadge', '52381', 0, 'xojgfy64a46d185d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Oklahoma', 'Tulsa', 'Butternut', '51760', 8443, 'wedshp22l38k746n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Plano', 'Magdeline', '08004', 457, 'mwjkfi43u97k651p');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Phoenix', 'John Wall', '68544', 2, 'cartat98m24h193v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Alexandria', 'Alpine', '26962', 224, 'ddxens63k23j237z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Idaho', 'Boise', 'Anzinger', '61141', 7530, 'fkhndi08i19d412x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'El Paso', 'Monterey', '58528', 808, 'cdnvrs45u23a128z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Illinois', 'Rockford', 'Carioca', '19264', 47825, 'mbnjdj31o81q212l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Duluth', 'Crest Line', '52829', 29, 'iogttg46j54t827r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Pennsylvania', 'Pittsburgh', 'Scofield', '14050', 358, 'adrdkg89t33m427o');
INSERT INTO public."Indirizzo_Utente" VALUES ('Ohio', 'Akron', 'Killdeer', '04901', 1, 'rysyjr72u70l124k');
INSERT INTO public."Indirizzo_Utente" VALUES ('Tennessee', 'Knoxville', 'Mandrake', '65581', 6, 'qwxyuj83d69x421j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Springfield', '8th', '44385', 2, 'ihdnpg74n92b287e');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Atlanta', '3rd', '40288', 68809, 'uikiir22c44k843o');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Los Angeles', 'Eagan', '90818', 90, 'ezoppc54q77u142f');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Irvine', 'Prairie Rose', '47431', 6, 'kqwwdo80j37f487n');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Brooklyn', 'Susan', '53946', 4434, 'mflkhj48c68t573i');
INSERT INTO public."Indirizzo_Utente" VALUES ('Missouri', 'Columbia', 'Schlimgen', '00398', 9379, 'ieaqoj35w04y469o');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'South', '52690', 2, 'zzpdje72f60u334g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Oregon', 'Portland', 'Fulton', '67011', 88, 'kudner99l61l388i');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Norfolk', 'Fremont', '03297', 196, 'awuyzn61c17c890d');
INSERT INTO public."Indirizzo_Utente" VALUES ('Louisiana', 'Alexandria', 'Tony', '16391', 78678, 'echxll47x25b400a');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'New York City', 'Reinke', '32182', 66, 'qabkgx49q61o993x');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Houston', 'Stoughton', '39875', 137, 'psfiod09k77a681u');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Los Angeles', 'Mitchell', '25773', 89573, 'bucims80t97w944z');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Atlanta', 'Oriole', '61777', 3, 'tamsxh39j08d107q');
INSERT INTO public."Indirizzo_Utente" VALUES ('District of Columbia', 'Washington', 'Anthes', '66979', 14, 'hhwjqv17k50w410f');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Norfolk', 'Gateway', '06190', 27055, 'mfbslr80u19a742g');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Roanoke', 'Florence', '25444', 683, 'arllpa74i66y238j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Arizona', 'Tucson', 'Carpenter', '64012', 48931, 'ikwfcz18b86e682q');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'Bryan', 'Ruskin', '76374', 655, 'fgceut14h98h226r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Kansas', 'Wichita', 'Pine View', '80397', 54, 'rbxbrf79f09c376r');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Santa Monica', 'Lunder', '52271', 1, 'moqyaa96b41w621l');
INSERT INTO public."Indirizzo_Utente" VALUES ('Texas', 'El Paso', 'Bayside', '71000', 84993, 'abogvl97e41a631n');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Newport News', 'Bowman', '35708', 5679, 'pqjbjt76t60z084a');
INSERT INTO public."Indirizzo_Utente" VALUES ('Louisiana', 'Lake Charles', 'Brown', '79955', 2, 'rcjgxa50z51h696w');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Rochester', 'Northridge', '20284', 6, 'shnnfp42x22u151r');
INSERT INTO public."Indirizzo_Utente" VALUES ('Virginia', 'Arlington', 'Hauk', '15303', 2, 'magujx74u13t692j');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Atlanta', 'Northland', '00871', 42410, 'dbhyzt20x58r774v');
INSERT INTO public."Indirizzo_Utente" VALUES ('Georgia', 'Atlanta', 'Center', '37358', 846, 'tzrppf44x01q376h');
INSERT INTO public."Indirizzo_Utente" VALUES ('New York', 'Mount Vernon', 'Myrtle', '98135', 3741, 'pvgfaf41e99l262m');
INSERT INTO public."Indirizzo_Utente" VALUES ('California', 'Sacramento', 'Merrick', '99548', 2, 'qmogjf57a26v287q');
INSERT INTO public."Indirizzo_Utente" VALUES ('North Carolina', 'Charlotte', 'Marquette', '51447', 424, 'corzss57a06d644t');
INSERT INTO public."Indirizzo_Utente" VALUES ('Utah', 'Ogden', 'Starling', '50387', 3395, 'kqupzq92g24n430p');


--
-- TOC entry 3616 (class 0 OID 18558)
-- Dependencies: 257
-- Data for Name: Orario; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'lunedì', 1);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'martedì', 1);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'mercoledì', 1);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'giovedì', 1);
INSERT INTO public."Orario" VALUES ('12:00:00', '18:00:00', 'venerdì', 1);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'sabato', 1);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'domenica', 1);
INSERT INTO public."Orario" VALUES ('09:00:00', '12:00:00', 'lunedì', 2);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'martedì', 2);
INSERT INTO public."Orario" VALUES ('09:00:00', '14:00:00', 'mercoledì', 2);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'giovedì', 2);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'venerdì', 2);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'sabato', 2);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'domenica', 2);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'lunedì', 3);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'martedì', 3);
INSERT INTO public."Orario" VALUES ('12:00:00', '18:00:00', 'mercoledì', 3);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'giovedì', 3);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'venerdì', 3);
INSERT INTO public."Orario" VALUES ('09:00:00', '12:00:00', 'sabato', 3);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'domenica', 3);
INSERT INTO public."Orario" VALUES ('09:00:00', '14:00:00', 'lunedì', 4);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'martedì', 4);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'mercoledì', 4);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'giovedì', 4);
INSERT INTO public."Orario" VALUES ('12:00:00', '18:00:00', 'venerdì', 4);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'sabato', 4);
INSERT INTO public."Orario" VALUES ('12:00:00', '18:00:00', 'domenica', 4);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'lunedì', 5);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'martedì', 5);
INSERT INTO public."Orario" VALUES ('09:00:00', '12:00:00', 'mercoledì', 5);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'giovedì', 5);
INSERT INTO public."Orario" VALUES ('09:00:00', '14:00:00', 'venerdì', 5);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'sabato', 5);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'domenica', 5);
INSERT INTO public."Orario" VALUES (NULL, NULL, 'lunedì', 6);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'martedì', 6);
INSERT INTO public."Orario" VALUES ('09:00:00', '12:00:00', 'mercoledì', 6);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'giovedì', 6);
INSERT INTO public."Orario" VALUES ('09:00:00', '14:00:00', 'venerdì', 6);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'sabato', 6);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'domenica', 6);
INSERT INTO public."Orario" VALUES (NULL, NULL, 'lunedì', 7);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'martedì', 7);
INSERT INTO public."Orario" VALUES ('09:00:00', '12:00:00', 'mercoledì', 7);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'giovedì', 7);
INSERT INTO public."Orario" VALUES ('09:00:00', '14:00:00', 'venerdì', 7);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'sabato', 7);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'domenica', 7);
INSERT INTO public."Orario" VALUES (NULL, NULL, 'lunedì', 8);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'martedì', 8);
INSERT INTO public."Orario" VALUES ('09:00:00', '12:00:00', 'mercoledì', 8);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'giovedì', 8);
INSERT INTO public."Orario" VALUES ('09:00:00', '14:00:00', 'venerdì', 8);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'sabato', 8);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'domenica', 8);
INSERT INTO public."Orario" VALUES (NULL, NULL, 'lunedì', 9);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'martedì', 9);
INSERT INTO public."Orario" VALUES ('09:00:00', '12:00:00', 'mercoledì', 9);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'giovedì', 9);
INSERT INTO public."Orario" VALUES ('09:00:00', '14:00:00', 'venerdì', 9);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'sabato', 9);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'domenica', 9);
INSERT INTO public."Orario" VALUES (NULL, NULL, 'lunedì', 10);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'martedì', 10);
INSERT INTO public."Orario" VALUES ('09:00:00', '12:00:00', 'mercoledì', 10);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'giovedì', 10);
INSERT INTO public."Orario" VALUES ('09:00:00', '14:00:00', 'venerdì', 10);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'sabato', 10);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'domenica', 10);
INSERT INTO public."Orario" VALUES (NULL, NULL, 'lunedì', 11);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'martedì', 11);
INSERT INTO public."Orario" VALUES ('09:00:00', '12:00:00', 'mercoledì', 11);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'giovedì', 11);
INSERT INTO public."Orario" VALUES ('09:00:00', '14:00:00', 'venerdì', 11);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'sabato', 11);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'domenica', 11);
INSERT INTO public."Orario" VALUES (NULL, NULL, 'lunedì', 12);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'martedì', 12);
INSERT INTO public."Orario" VALUES ('09:00:00', '12:00:00', 'mercoledì', 12);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'giovedì', 12);
INSERT INTO public."Orario" VALUES ('09:00:00', '14:00:00', 'venerdì', 12);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'sabato', 12);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'domenica', 12);
INSERT INTO public."Orario" VALUES (NULL, NULL, 'lunedì', 13);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'martedì', 13);
INSERT INTO public."Orario" VALUES ('09:00:00', '12:00:00', 'mercoledì', 13);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'giovedì', 13);
INSERT INTO public."Orario" VALUES ('09:00:00', '14:00:00', 'venerdì', 13);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'sabato', 13);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'domenica', 13);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'lunedì', 14);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'martedì', 14);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'mercoledì', 14);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'giovedì', 14);
INSERT INTO public."Orario" VALUES ('12:00:00', '18:00:00', 'venerdì', 14);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'sabato', 14);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'domenica', 14);
INSERT INTO public."Orario" VALUES ('09:00:00', '12:00:00', 'lunedì', 15);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'martedì', 15);
INSERT INTO public."Orario" VALUES ('09:00:00', '14:00:00', 'mercoledì', 15);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'giovedì', 15);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'venerdì', 15);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'sabato', 15);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'domenica', 15);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'lunedì', 16);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'martedì', 16);
INSERT INTO public."Orario" VALUES ('12:00:00', '18:00:00', 'mercoledì', 16);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'giovedì', 16);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'venerdì', 16);
INSERT INTO public."Orario" VALUES ('09:00:00', '12:00:00', 'sabato', 16);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'domenica', 16);
INSERT INTO public."Orario" VALUES ('09:00:00', '14:00:00', 'lunedì', 17);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'martedì', 17);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'mercoledì', 17);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'giovedì', 17);
INSERT INTO public."Orario" VALUES ('12:00:00', '18:00:00', 'venerdì', 17);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'sabato', 17);
INSERT INTO public."Orario" VALUES ('12:00:00', '18:00:00', 'domenica', 17);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'lunedì', 18);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'martedì', 18);
INSERT INTO public."Orario" VALUES ('09:00:00', '12:00:00', 'mercoledì', 18);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'giovedì', 18);
INSERT INTO public."Orario" VALUES ('09:00:00', '14:00:00', 'venerdì', 18);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'sabato', 18);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'domenica', 18);
INSERT INTO public."Orario" VALUES (NULL, NULL, 'lunedì', 19);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'martedì', 19);
INSERT INTO public."Orario" VALUES ('09:00:00', '12:00:00', 'mercoledì', 19);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'giovedì', 19);
INSERT INTO public."Orario" VALUES ('09:00:00', '14:00:00', 'venerdì', 19);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'sabato', 19);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'domenica', 19);
INSERT INTO public."Orario" VALUES (NULL, NULL, 'lunedì', 20);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'martedì', 20);
INSERT INTO public."Orario" VALUES ('09:00:00', '12:00:00', 'mercoledì', 20);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'giovedì', 20);
INSERT INTO public."Orario" VALUES ('09:00:00', '14:00:00', 'venerdì', 20);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'sabato', 20);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'domenica', 20);
INSERT INTO public."Orario" VALUES (NULL, NULL, 'lunedì', 21);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'martedì', 21);
INSERT INTO public."Orario" VALUES ('09:00:00', '12:00:00', 'mercoledì', 21);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'giovedì', 21);
INSERT INTO public."Orario" VALUES ('09:00:00', '14:00:00', 'venerdì', 21);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'sabato', 21);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'domenica', 21);
INSERT INTO public."Orario" VALUES (NULL, NULL, 'lunedì', 22);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'martedì', 22);
INSERT INTO public."Orario" VALUES ('09:00:00', '12:00:00', 'mercoledì', 22);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'giovedì', 22);
INSERT INTO public."Orario" VALUES ('09:00:00', '14:00:00', 'venerdì', 22);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'sabato', 22);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'domenica', 22);
INSERT INTO public."Orario" VALUES (NULL, NULL, 'lunedì', 23);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'martedì', 23);
INSERT INTO public."Orario" VALUES ('09:00:00', '12:00:00', 'mercoledì', 23);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'giovedì', 23);
INSERT INTO public."Orario" VALUES ('09:00:00', '14:00:00', 'venerdì', 23);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'sabato', 23);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'domenica', 23);
INSERT INTO public."Orario" VALUES (NULL, NULL, 'lunedì', 24);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'martedì', 24);
INSERT INTO public."Orario" VALUES ('09:00:00', '12:00:00', 'mercoledì', 24);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'giovedì', 24);
INSERT INTO public."Orario" VALUES ('09:00:00', '14:00:00', 'venerdì', 24);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'sabato', 24);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'domenica', 24);
INSERT INTO public."Orario" VALUES (NULL, NULL, 'lunedì', 25);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'martedì', 25);
INSERT INTO public."Orario" VALUES ('09:00:00', '12:00:00', 'mercoledì', 25);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'giovedì', 25);
INSERT INTO public."Orario" VALUES ('09:00:00', '14:00:00', 'venerdì', 25);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'sabato', 25);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'domenica', 25);
INSERT INTO public."Orario" VALUES (NULL, NULL, 'lunedì', 26);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'martedì', 26);
INSERT INTO public."Orario" VALUES ('09:00:00', '12:00:00', 'mercoledì', 26);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'giovedì', 26);
INSERT INTO public."Orario" VALUES ('09:00:00', '14:00:00', 'venerdì', 26);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'sabato', 26);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'domenica', 26);
INSERT INTO public."Orario" VALUES (NULL, NULL, 'lunedì', 27);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'martedì', 27);
INSERT INTO public."Orario" VALUES ('09:00:00', '12:00:00', 'mercoledì', 27);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'giovedì', 27);
INSERT INTO public."Orario" VALUES ('09:00:00', '14:00:00', 'venerdì', 27);
INSERT INTO public."Orario" VALUES ('09:00:00', '17:00:00', 'sabato', 27);
INSERT INTO public."Orario" VALUES ('09:00:00', '18:00:00', 'domenica', 27);


--
-- TOC entry 3617 (class 0 OID 18564)
-- Dependencies: 258
-- Data for Name: Pacco_Economico; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO public."Pacco_Economico" VALUES (47, 702, 6.8, 10.8, 47);
INSERT INTO public."Pacco_Economico" VALUES (4, 177, 7.7, 9.9, 4);
INSERT INTO public."Pacco_Economico" VALUES (26, 60, 2.6, 19.2, 26);
INSERT INTO public."Pacco_Economico" VALUES (36, 371, 7, 3.8, 36);
INSERT INTO public."Pacco_Economico" VALUES (13, 384, 5.1, 12.5, 13);
INSERT INTO public."Pacco_Economico" VALUES (12, 98, 4.5, 13.9, 12);
INSERT INTO public."Pacco_Economico" VALUES (18, 103, 1.8, 7, 18);
INSERT INTO public."Pacco_Economico" VALUES (27, 143, 5.9, 14.1, 27);
INSERT INTO public."Pacco_Economico" VALUES (33, 79, 3.4, 2.2, 33);
INSERT INTO public."Pacco_Economico" VALUES (9, 168, 5, 5.3, 9);
INSERT INTO public."Pacco_Economico" VALUES (19, 7, 4.2, 16.6, 19);
INSERT INTO public."Pacco_Economico" VALUES (42, 244, 5.6, 18, 42);
INSERT INTO public."Pacco_Economico" VALUES (41, 76, 8, 7.1, 41);
INSERT INTO public."Pacco_Economico" VALUES (24, 139, 8.5, 14.7, 24);
INSERT INTO public."Pacco_Economico" VALUES (48, 171, 5.6, 8.9, 48);
INSERT INTO public."Pacco_Economico" VALUES (6, 961, 2.5, 12.5, 6);
INSERT INTO public."Pacco_Economico" VALUES (45, 850, 4.5, 19.6, 45);
INSERT INTO public."Pacco_Economico" VALUES (20, 974, 3.6, 1.2, 20);
INSERT INTO public."Pacco_Economico" VALUES (5, 253, 7.2, 2.1, 5);
INSERT INTO public."Pacco_Economico" VALUES (14, 767, 1.9, 13.5, 14);
INSERT INTO public."Pacco_Economico" VALUES (38, 192, 9.3, 7.4, 38);
INSERT INTO public."Pacco_Economico" VALUES (46, 974, 8.8, 15.8, 46);
INSERT INTO public."Pacco_Economico" VALUES (51, 947, 9.4, 2.3, 51);
INSERT INTO public."Pacco_Economico" VALUES (37, 950, 3.6, 2.7, 37);
INSERT INTO public."Pacco_Economico" VALUES (54, 227, 3.7, 2.3, 54);
INSERT INTO public."Pacco_Economico" VALUES (17, 646, 4.6, 3.1, 17);
INSERT INTO public."Pacco_Economico" VALUES (39, 986, 5.4, 11.4, 39);
INSERT INTO public."Pacco_Economico" VALUES (7, 417, 4, 2.5, 7);
INSERT INTO public."Pacco_Economico" VALUES (40, 624, 5.4, 19.6, 40);
INSERT INTO public."Pacco_Economico" VALUES (49, 862, 2.6, 6.1, 49);
INSERT INTO public."Pacco_Economico" VALUES (25, 953, 8.6, 5.7, 25);
INSERT INTO public."Pacco_Economico" VALUES (15, 920, 1.5, 5.6, 15);
INSERT INTO public."Pacco_Economico" VALUES (32, 957, 7.2, 5.5, 32);
INSERT INTO public."Pacco_Economico" VALUES (29, 518, 4.9, 7.8, 29);
INSERT INTO public."Pacco_Economico" VALUES (8, 197, 6.1, 19.5, 8);
INSERT INTO public."Pacco_Economico" VALUES (22, 759, 8.5, 7.8, 22);
INSERT INTO public."Pacco_Economico" VALUES (43, 347, 4.3, 2.3, 43);
INSERT INTO public."Pacco_Economico" VALUES (30, 448, 9.9, 13.2, 30);
INSERT INTO public."Pacco_Economico" VALUES (21, 969, 7.3, 16.2, 21);
INSERT INTO public."Pacco_Economico" VALUES (23, 232, 8.6, 16.4, 23);
INSERT INTO public."Pacco_Economico" VALUES (28, 558, 1.3, 13.3, 28);
INSERT INTO public."Pacco_Economico" VALUES (52, 788, 8.6, 14.7, 52);
INSERT INTO public."Pacco_Economico" VALUES (31, 636, 8.7, 4, 31);
INSERT INTO public."Pacco_Economico" VALUES (10, 182, 2.9, 1.3, 10);
INSERT INTO public."Pacco_Economico" VALUES (34, 393, 1.2, 3.2, 34);
INSERT INTO public."Pacco_Economico" VALUES (16, 925, 7.8, 2.3, 16);
INSERT INTO public."Pacco_Economico" VALUES (2, 87, 7.1, 13, 2);
INSERT INTO public."Pacco_Economico" VALUES (44, 578, 4.9, 2.5, 44);
INSERT INTO public."Pacco_Economico" VALUES (35, 59, 5.9, 4.2, 35);
INSERT INTO public."Pacco_Economico" VALUES (11, 906, 9.6, 16.8, 11);
INSERT INTO public."Pacco_Economico" VALUES (50, 192, 8.8, 8.1, 50);
INSERT INTO public."Pacco_Economico" VALUES (3, 456, 7, 16.8, 3);
INSERT INTO public."Pacco_Economico" VALUES (1, 253, 7.2, 2.1, 3);
INSERT INTO public."Pacco_Economico" VALUES (55, 87, 7.1, 13, 55);
INSERT INTO public."Pacco_Economico" VALUES (56, 253, 7.2, 2.1, 56);
INSERT INTO public."Pacco_Economico" VALUES (57, 456, 7, 16.8, 57);
INSERT INTO public."Pacco_Economico" VALUES (58, 177, 7.7, 9.9, 58);
INSERT INTO public."Pacco_Economico" VALUES (59, 253, 7.2, 2.1, 59);
INSERT INTO public."Pacco_Economico" VALUES (60, 961, 2.5, 12.5, 60);
INSERT INTO public."Pacco_Economico" VALUES (61, 417, 4, 2.5, 61);
INSERT INTO public."Pacco_Economico" VALUES (62, 197, 6.1, 19.5, 62);
INSERT INTO public."Pacco_Economico" VALUES (63, 168, 5, 5.3, 63);
INSERT INTO public."Pacco_Economico" VALUES (64, 182, 2.9, 1.3, 64);
INSERT INTO public."Pacco_Economico" VALUES (65, 906, 9.6, 16.8, 65);
INSERT INTO public."Pacco_Economico" VALUES (66, 98, 4.5, 13.9, 66);
INSERT INTO public."Pacco_Economico" VALUES (67, 384, 5.1, 12.5, 67);
INSERT INTO public."Pacco_Economico" VALUES (68, 767, 1.9, 13.5, 68);
INSERT INTO public."Pacco_Economico" VALUES (69, 920, 1.5, 5.6, 69);
INSERT INTO public."Pacco_Economico" VALUES (70, 925, 7.8, 2.3, 70);
INSERT INTO public."Pacco_Economico" VALUES (71, 646, 4.6, 3.1, 71);
INSERT INTO public."Pacco_Economico" VALUES (72, 103, 1.8, 7, 72);
INSERT INTO public."Pacco_Economico" VALUES (73, 7, 4.2, 16.6, 73);
INSERT INTO public."Pacco_Economico" VALUES (74, 974, 3.6, 1.2, 74);
INSERT INTO public."Pacco_Economico" VALUES (75, 969, 7.3, 16.2, 75);
INSERT INTO public."Pacco_Economico" VALUES (76, 759, 8.5, 7.8, 76);
INSERT INTO public."Pacco_Economico" VALUES (77, 232, 8.6, 16.4, 77);
INSERT INTO public."Pacco_Economico" VALUES (78, 139, 8.5, 14.7, 78);
INSERT INTO public."Pacco_Economico" VALUES (79, 953, 8.6, 5.7, 79);
INSERT INTO public."Pacco_Economico" VALUES (80, 60, 2.6, 19.2, 80);
INSERT INTO public."Pacco_Economico" VALUES (81, 143, 5.9, 14.1, 81);
INSERT INTO public."Pacco_Economico" VALUES (82, 558, 1.3, 13.3, 82);
INSERT INTO public."Pacco_Economico" VALUES (83, 518, 4.9, 7.8, 83);
INSERT INTO public."Pacco_Economico" VALUES (84, 448, 9.9, 13.2, 84);
INSERT INTO public."Pacco_Economico" VALUES (85, 636, 8.7, 4, 85);
INSERT INTO public."Pacco_Economico" VALUES (86, 957, 7.2, 5.5, 86);
INSERT INTO public."Pacco_Economico" VALUES (87, 79, 3.4, 2.2, 87);
INSERT INTO public."Pacco_Economico" VALUES (88, 393, 1.2, 3.2, 88);
INSERT INTO public."Pacco_Economico" VALUES (89, 59, 5.9, 4.2, 89);
INSERT INTO public."Pacco_Economico" VALUES (90, 371, 7, 3.8, 90);
INSERT INTO public."Pacco_Economico" VALUES (91, 950, 3.6, 2.7, 91);
INSERT INTO public."Pacco_Economico" VALUES (92, 192, 9.3, 7.4, 92);
INSERT INTO public."Pacco_Economico" VALUES (93, 986, 5.4, 11.4, 93);
INSERT INTO public."Pacco_Economico" VALUES (94, 624, 5.4, 19.6, 94);
INSERT INTO public."Pacco_Economico" VALUES (95, 76, 8, 7.1, 95);
INSERT INTO public."Pacco_Economico" VALUES (96, 244, 5.6, 18, 96);
INSERT INTO public."Pacco_Economico" VALUES (97, 347, 4.3, 2.3, 97);
INSERT INTO public."Pacco_Economico" VALUES (98, 578, 4.9, 2.5, 98);
INSERT INTO public."Pacco_Economico" VALUES (99, 850, 4.5, 19.6, 99);
INSERT INTO public."Pacco_Economico" VALUES (100, 974, 8.8, 15.8, 100);
INSERT INTO public."Pacco_Economico" VALUES (101, 702, 6.8, 10.8, 101);
INSERT INTO public."Pacco_Economico" VALUES (102, 171, 5.6, 8.9, 102);
INSERT INTO public."Pacco_Economico" VALUES (103, 862, 2.6, 6.1, 103);
INSERT INTO public."Pacco_Economico" VALUES (104, 192, 8.8, 8.1, 104);
INSERT INTO public."Pacco_Economico" VALUES (105, 947, 9.4, 2.3, 105);
INSERT INTO public."Pacco_Economico" VALUES (106, 788, 8.6, 14.7, 106);
INSERT INTO public."Pacco_Economico" VALUES (107, 939, 1.7, 19.8, 107);
INSERT INTO public."Pacco_Economico" VALUES (108, 227, 3.7, 2.3, 108);
INSERT INTO public."Pacco_Economico" VALUES (109, 87, 7.1, 13, 109);
INSERT INTO public."Pacco_Economico" VALUES (110, 253, 7.2, 2.1, 110);
INSERT INTO public."Pacco_Economico" VALUES (111, 456, 7, 16.8, 111);
INSERT INTO public."Pacco_Economico" VALUES (112, 177, 7.7, 9.9, 112);
INSERT INTO public."Pacco_Economico" VALUES (113, 253, 7.2, 2.1, 113);
INSERT INTO public."Pacco_Economico" VALUES (114, 961, 2.5, 12.5, 114);
INSERT INTO public."Pacco_Economico" VALUES (115, 417, 4, 2.5, 115);
INSERT INTO public."Pacco_Economico" VALUES (116, 197, 6.1, 19.5, 116);
INSERT INTO public."Pacco_Economico" VALUES (117, 168, 5, 5.3, 117);
INSERT INTO public."Pacco_Economico" VALUES (118, 182, 2.9, 1.3, 118);
INSERT INTO public."Pacco_Economico" VALUES (119, 906, 9.6, 16.8, 119);
INSERT INTO public."Pacco_Economico" VALUES (120, 98, 4.5, 13.9, 120);
INSERT INTO public."Pacco_Economico" VALUES (121, 384, 5.1, 12.5, 121);
INSERT INTO public."Pacco_Economico" VALUES (122, 767, 1.9, 13.5, 122);
INSERT INTO public."Pacco_Economico" VALUES (123, 920, 1.5, 5.6, 123);
INSERT INTO public."Pacco_Economico" VALUES (124, 925, 7.8, 2.3, 124);
INSERT INTO public."Pacco_Economico" VALUES (125, 646, 4.6, 3.1, 125);
INSERT INTO public."Pacco_Economico" VALUES (126, 103, 1.8, 7, 126);
INSERT INTO public."Pacco_Economico" VALUES (127, 7, 4.2, 16.6, 127);
INSERT INTO public."Pacco_Economico" VALUES (128, 974, 3.6, 1.2, 128);
INSERT INTO public."Pacco_Economico" VALUES (129, 969, 7.3, 16.2, 129);
INSERT INTO public."Pacco_Economico" VALUES (130, 759, 8.5, 7.8, 130);
INSERT INTO public."Pacco_Economico" VALUES (131, 232, 8.6, 16.4, 131);
INSERT INTO public."Pacco_Economico" VALUES (132, 139, 8.5, 14.7, 132);
INSERT INTO public."Pacco_Economico" VALUES (133, 953, 8.6, 5.7, 133);
INSERT INTO public."Pacco_Economico" VALUES (134, 60, 2.6, 19.2, 134);
INSERT INTO public."Pacco_Economico" VALUES (135, 143, 5.9, 14.1, 135);
INSERT INTO public."Pacco_Economico" VALUES (136, 558, 1.3, 13.3, 136);
INSERT INTO public."Pacco_Economico" VALUES (137, 518, 4.9, 7.8, 137);
INSERT INTO public."Pacco_Economico" VALUES (138, 448, 9.9, 13.2, 138);
INSERT INTO public."Pacco_Economico" VALUES (139, 636, 8.7, 4, 139);
INSERT INTO public."Pacco_Economico" VALUES (140, 957, 7.2, 5.5, 140);
INSERT INTO public."Pacco_Economico" VALUES (141, 79, 3.4, 2.2, 141);
INSERT INTO public."Pacco_Economico" VALUES (142, 393, 1.2, 3.2, 142);
INSERT INTO public."Pacco_Economico" VALUES (143, 59, 5.9, 4.2, 143);
INSERT INTO public."Pacco_Economico" VALUES (144, 371, 7, 3.8, 144);
INSERT INTO public."Pacco_Economico" VALUES (145, 950, 3.6, 2.7, 145);
INSERT INTO public."Pacco_Economico" VALUES (146, 192, 9.3, 7.4, 146);
INSERT INTO public."Pacco_Economico" VALUES (147, 986, 5.4, 11.4, 147);
INSERT INTO public."Pacco_Economico" VALUES (148, 624, 5.4, 19.6, 148);
INSERT INTO public."Pacco_Economico" VALUES (149, 76, 8, 7.1, 149);
INSERT INTO public."Pacco_Economico" VALUES (150, 244, 5.6, 18, 150);
INSERT INTO public."Pacco_Economico" VALUES (151, 347, 4.3, 2.3, 151);
INSERT INTO public."Pacco_Economico" VALUES (152, 578, 4.9, 2.5, 152);
INSERT INTO public."Pacco_Economico" VALUES (153, 850, 4.5, 19.6, 153);
INSERT INTO public."Pacco_Economico" VALUES (154, 974, 8.8, 15.8, 154);
INSERT INTO public."Pacco_Economico" VALUES (155, 702, 6.8, 10.8, 155);
INSERT INTO public."Pacco_Economico" VALUES (156, 171, 5.6, 8.9, 156);
INSERT INTO public."Pacco_Economico" VALUES (157, 862, 2.6, 6.1, 157);
INSERT INTO public."Pacco_Economico" VALUES (158, 192, 8.8, 8.1, 158);
INSERT INTO public."Pacco_Economico" VALUES (159, 947, 9.4, 2.3, 159);
INSERT INTO public."Pacco_Economico" VALUES (160, 788, 8.6, 14.7, 160);
INSERT INTO public."Pacco_Economico" VALUES (161, 939, 1.7, 19.8, 161);
INSERT INTO public."Pacco_Economico" VALUES (162, 227, 3.7, 2.3, 162);
INSERT INTO public."Pacco_Economico" VALUES (163, 87, 7.1, 13, 163);
INSERT INTO public."Pacco_Economico" VALUES (164, 253, 7.2, 2.1, 164);
INSERT INTO public."Pacco_Economico" VALUES (165, 456, 7, 16.8, 165);
INSERT INTO public."Pacco_Economico" VALUES (166, 177, 7.7, 9.9, 166);
INSERT INTO public."Pacco_Economico" VALUES (167, 253, 7.2, 2.1, 167);
INSERT INTO public."Pacco_Economico" VALUES (168, 961, 2.5, 12.5, 168);
INSERT INTO public."Pacco_Economico" VALUES (169, 417, 4, 2.5, 169);
INSERT INTO public."Pacco_Economico" VALUES (170, 197, 6.1, 19.5, 170);
INSERT INTO public."Pacco_Economico" VALUES (171, 168, 5, 5.3, 171);
INSERT INTO public."Pacco_Economico" VALUES (172, 182, 2.9, 1.3, 172);
INSERT INTO public."Pacco_Economico" VALUES (173, 906, 9.6, 16.8, 173);
INSERT INTO public."Pacco_Economico" VALUES (174, 98, 4.5, 13.9, 174);
INSERT INTO public."Pacco_Economico" VALUES (175, 384, 5.1, 12.5, 175);
INSERT INTO public."Pacco_Economico" VALUES (176, 767, 1.9, 13.5, 176);
INSERT INTO public."Pacco_Economico" VALUES (177, 920, 1.5, 5.6, 177);
INSERT INTO public."Pacco_Economico" VALUES (178, 925, 7.8, 2.3, 178);
INSERT INTO public."Pacco_Economico" VALUES (179, 646, 4.6, 3.1, 179);
INSERT INTO public."Pacco_Economico" VALUES (180, 103, 1.8, 7, 180);
INSERT INTO public."Pacco_Economico" VALUES (181, 7, 4.2, 16.6, 181);
INSERT INTO public."Pacco_Economico" VALUES (182, 974, 3.6, 1.2, 182);
INSERT INTO public."Pacco_Economico" VALUES (183, 969, 7.3, 16.2, 183);
INSERT INTO public."Pacco_Economico" VALUES (184, 759, 8.5, 7.8, 184);
INSERT INTO public."Pacco_Economico" VALUES (185, 232, 8.6, 16.4, 185);
INSERT INTO public."Pacco_Economico" VALUES (186, 139, 8.5, 14.7, 186);
INSERT INTO public."Pacco_Economico" VALUES (187, 953, 8.6, 5.7, 187);
INSERT INTO public."Pacco_Economico" VALUES (188, 60, 2.6, 19.2, 188);
INSERT INTO public."Pacco_Economico" VALUES (189, 143, 5.9, 14.1, 189);
INSERT INTO public."Pacco_Economico" VALUES (190, 558, 1.3, 13.3, 190);
INSERT INTO public."Pacco_Economico" VALUES (191, 518, 4.9, 7.8, 191);
INSERT INTO public."Pacco_Economico" VALUES (192, 448, 9.9, 13.2, 192);
INSERT INTO public."Pacco_Economico" VALUES (193, 636, 8.7, 4, 193);
INSERT INTO public."Pacco_Economico" VALUES (194, 957, 7.2, 5.5, 194);
INSERT INTO public."Pacco_Economico" VALUES (195, 79, 3.4, 2.2, 195);
INSERT INTO public."Pacco_Economico" VALUES (196, 393, 1.2, 3.2, 196);
INSERT INTO public."Pacco_Economico" VALUES (197, 59, 5.9, 4.2, 197);
INSERT INTO public."Pacco_Economico" VALUES (198, 371, 7, 3.8, 198);
INSERT INTO public."Pacco_Economico" VALUES (199, 950, 3.6, 2.7, 199);
INSERT INTO public."Pacco_Economico" VALUES (200, 192, 9.3, 7.4, 200);
INSERT INTO public."Pacco_Economico" VALUES (201, 986, 5.4, 11.4, 201);
INSERT INTO public."Pacco_Economico" VALUES (202, 624, 5.4, 19.6, 202);
INSERT INTO public."Pacco_Economico" VALUES (203, 76, 8, 7.1, 203);
INSERT INTO public."Pacco_Economico" VALUES (204, 244, 5.6, 18, 204);
INSERT INTO public."Pacco_Economico" VALUES (205, 347, 4.3, 2.3, 205);
INSERT INTO public."Pacco_Economico" VALUES (206, 578, 4.9, 2.5, 206);
INSERT INTO public."Pacco_Economico" VALUES (207, 850, 4.5, 19.6, 207);
INSERT INTO public."Pacco_Economico" VALUES (208, 974, 8.8, 15.8, 208);
INSERT INTO public."Pacco_Economico" VALUES (209, 702, 6.8, 10.8, 209);
INSERT INTO public."Pacco_Economico" VALUES (210, 171, 5.6, 8.9, 210);
INSERT INTO public."Pacco_Economico" VALUES (211, 862, 2.6, 6.1, 211);
INSERT INTO public."Pacco_Economico" VALUES (212, 192, 8.8, 8.1, 212);
INSERT INTO public."Pacco_Economico" VALUES (213, 947, 9.4, 2.3, 213);
INSERT INTO public."Pacco_Economico" VALUES (214, 788, 8.6, 14.7, 214);
INSERT INTO public."Pacco_Economico" VALUES (215, 939, 1.7, 19.8, 215);
INSERT INTO public."Pacco_Economico" VALUES (216, 227, 3.7, 2.3, 216);
INSERT INTO public."Pacco_Economico" VALUES (217, 87, 7.1, 13, 217);
INSERT INTO public."Pacco_Economico" VALUES (218, 253, 7.2, 2.1, 218);
INSERT INTO public."Pacco_Economico" VALUES (219, 456, 7, 16.8, 219);
INSERT INTO public."Pacco_Economico" VALUES (220, 177, 7.7, 9.9, 220);
INSERT INTO public."Pacco_Economico" VALUES (221, 253, 7.2, 2.1, 221);
INSERT INTO public."Pacco_Economico" VALUES (222, 961, 2.5, 12.5, 222);
INSERT INTO public."Pacco_Economico" VALUES (223, 87, 7.1, 13, 223);
INSERT INTO public."Pacco_Economico" VALUES (224, 253, 7.2, 2.1, 224);
INSERT INTO public."Pacco_Economico" VALUES (225, 456, 7, 16.8, 225);
INSERT INTO public."Pacco_Economico" VALUES (226, 177, 7.7, 9.9, 226);
INSERT INTO public."Pacco_Economico" VALUES (227, 253, 7.2, 2.1, 227);
INSERT INTO public."Pacco_Economico" VALUES (228, 961, 2.5, 12.5, 228);
INSERT INTO public."Pacco_Economico" VALUES (229, 417, 4, 2.5, 229);
INSERT INTO public."Pacco_Economico" VALUES (230, 197, 6.1, 19.5, 230);
INSERT INTO public."Pacco_Economico" VALUES (231, 168, 5, 5.3, 231);
INSERT INTO public."Pacco_Economico" VALUES (232, 182, 2.9, 1.3, 232);
INSERT INTO public."Pacco_Economico" VALUES (233, 906, 9.6, 16.8, 233);
INSERT INTO public."Pacco_Economico" VALUES (234, 98, 4.5, 13.9, 234);
INSERT INTO public."Pacco_Economico" VALUES (235, 384, 5.1, 12.5, 235);
INSERT INTO public."Pacco_Economico" VALUES (236, 767, 1.9, 13.5, 236);
INSERT INTO public."Pacco_Economico" VALUES (237, 920, 1.5, 5.6, 237);
INSERT INTO public."Pacco_Economico" VALUES (238, 925, 7.8, 2.3, 238);
INSERT INTO public."Pacco_Economico" VALUES (239, 646, 4.6, 3.1, 239);
INSERT INTO public."Pacco_Economico" VALUES (240, 103, 1.8, 7, 240);
INSERT INTO public."Pacco_Economico" VALUES (241, 7, 4.2, 16.6, 241);
INSERT INTO public."Pacco_Economico" VALUES (242, 974, 3.6, 1.2, 242);
INSERT INTO public."Pacco_Economico" VALUES (243, 969, 7.3, 16.2, 243);
INSERT INTO public."Pacco_Economico" VALUES (244, 759, 8.5, 7.8, 244);
INSERT INTO public."Pacco_Economico" VALUES (245, 232, 8.6, 16.4, 245);
INSERT INTO public."Pacco_Economico" VALUES (246, 139, 8.5, 14.7, 246);
INSERT INTO public."Pacco_Economico" VALUES (247, 953, 8.6, 5.7, 247);
INSERT INTO public."Pacco_Economico" VALUES (248, 60, 2.6, 19.2, 248);
INSERT INTO public."Pacco_Economico" VALUES (249, 143, 5.9, 14.1, 249);
INSERT INTO public."Pacco_Economico" VALUES (250, 558, 1.3, 13.3, 250);
INSERT INTO public."Pacco_Economico" VALUES (251, 518, 4.9, 7.8, 251);
INSERT INTO public."Pacco_Economico" VALUES (252, 448, 9.9, 13.2, 252);
INSERT INTO public."Pacco_Economico" VALUES (253, 636, 8.7, 4, 253);
INSERT INTO public."Pacco_Economico" VALUES (254, 957, 7.2, 5.5, 254);
INSERT INTO public."Pacco_Economico" VALUES (255, 79, 3.4, 2.2, 255);
INSERT INTO public."Pacco_Economico" VALUES (256, 393, 1.2, 3.2, 256);
INSERT INTO public."Pacco_Economico" VALUES (257, 59, 5.9, 4.2, 257);
INSERT INTO public."Pacco_Economico" VALUES (258, 371, 7, 3.8, 258);
INSERT INTO public."Pacco_Economico" VALUES (259, 950, 3.6, 2.7, 259);
INSERT INTO public."Pacco_Economico" VALUES (260, 192, 9.3, 7.4, 260);
INSERT INTO public."Pacco_Economico" VALUES (261, 986, 5.4, 11.4, 261);
INSERT INTO public."Pacco_Economico" VALUES (262, 624, 5.4, 19.6, 262);
INSERT INTO public."Pacco_Economico" VALUES (263, 87, 7.1, 13, 263);
INSERT INTO public."Pacco_Economico" VALUES (264, 253, 7.2, 2.1, 264);
INSERT INTO public."Pacco_Economico" VALUES (265, 456, 7, 16.8, 265);
INSERT INTO public."Pacco_Economico" VALUES (266, 177, 7.7, 9.9, 266);
INSERT INTO public."Pacco_Economico" VALUES (267, 253, 7.2, 2.1, 267);
INSERT INTO public."Pacco_Economico" VALUES (268, 961, 2.5, 12.5, 268);
INSERT INTO public."Pacco_Economico" VALUES (269, 417, 4, 2.5, 269);
INSERT INTO public."Pacco_Economico" VALUES (270, 197, 6.1, 19.5, 270);
INSERT INTO public."Pacco_Economico" VALUES (271, 168, 5, 5.3, 271);
INSERT INTO public."Pacco_Economico" VALUES (272, 182, 2.9, 1.3, 272);
INSERT INTO public."Pacco_Economico" VALUES (273, 906, 9.6, 16.8, 273);
INSERT INTO public."Pacco_Economico" VALUES (274, 98, 4.5, 13.9, 274);
INSERT INTO public."Pacco_Economico" VALUES (275, 384, 5.1, 12.5, 275);
INSERT INTO public."Pacco_Economico" VALUES (276, 767, 1.9, 13.5, 276);
INSERT INTO public."Pacco_Economico" VALUES (277, 920, 1.5, 5.6, 277);
INSERT INTO public."Pacco_Economico" VALUES (278, 925, 7.8, 2.3, 278);
INSERT INTO public."Pacco_Economico" VALUES (279, 646, 4.6, 3.1, 279);
INSERT INTO public."Pacco_Economico" VALUES (280, 103, 1.8, 7, 280);
INSERT INTO public."Pacco_Economico" VALUES (281, 7, 4.2, 16.6, 281);
INSERT INTO public."Pacco_Economico" VALUES (282, 974, 3.6, 1.2, 282);
INSERT INTO public."Pacco_Economico" VALUES (283, 969, 7.3, 16.2, 283);
INSERT INTO public."Pacco_Economico" VALUES (284, 759, 8.5, 7.8, 284);
INSERT INTO public."Pacco_Economico" VALUES (285, 232, 8.6, 16.4, 285);
INSERT INTO public."Pacco_Economico" VALUES (286, 139, 8.5, 14.7, 286);
INSERT INTO public."Pacco_Economico" VALUES (287, 953, 8.6, 5.7, 287);
INSERT INTO public."Pacco_Economico" VALUES (288, 60, 2.6, 19.2, 288);
INSERT INTO public."Pacco_Economico" VALUES (289, 143, 5.9, 14.1, 289);
INSERT INTO public."Pacco_Economico" VALUES (290, 558, 1.3, 13.3, 290);
INSERT INTO public."Pacco_Economico" VALUES (291, 518, 4.9, 7.8, 291);
INSERT INTO public."Pacco_Economico" VALUES (292, 448, 9.9, 13.2, 292);
INSERT INTO public."Pacco_Economico" VALUES (293, 636, 8.7, 4, 293);
INSERT INTO public."Pacco_Economico" VALUES (294, 957, 7.2, 5.5, 294);
INSERT INTO public."Pacco_Economico" VALUES (295, 79, 3.4, 2.2, 295);


--
-- TOC entry 3618 (class 0 OID 18567)
-- Dependencies: 259
-- Data for Name: Pacco_Premium; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO public."Pacco_Premium" VALUES (17, 695, 5.1, 8.4, 17);
INSERT INTO public."Pacco_Premium" VALUES (15, 325, 7.1, 8.7, 15);
INSERT INTO public."Pacco_Premium" VALUES (2, 750, 2.8, 19.4, 2);
INSERT INTO public."Pacco_Premium" VALUES (9, 30, 3.7, 4, 9);
INSERT INTO public."Pacco_Premium" VALUES (4, 980, 3.7, 1.7, 4);
INSERT INTO public."Pacco_Premium" VALUES (6, 690, 3.6, 3.7, 6);
INSERT INTO public."Pacco_Premium" VALUES (11, 468, 3.8, 12.1, 11);
INSERT INTO public."Pacco_Premium" VALUES (8, 558, 6.8, 17.3, 8);
INSERT INTO public."Pacco_Premium" VALUES (13, 440, 4.3, 11.6, 13);
INSERT INTO public."Pacco_Premium" VALUES (20, 70, 5.7, 11.5, 20);
INSERT INTO public."Pacco_Premium" VALUES (18, 647, 6.1, 11.2, 18);
INSERT INTO public."Pacco_Premium" VALUES (16, 583, 4.2, 2.6, 16);
INSERT INTO public."Pacco_Premium" VALUES (14, 87, 2.2, 18, 14);
INSERT INTO public."Pacco_Premium" VALUES (10, 324, 4.9, 6.6, 10);
INSERT INTO public."Pacco_Premium" VALUES (5, 27, 3.4, 11.7, 5);
INSERT INTO public."Pacco_Premium" VALUES (1, 796, 2.3, 3.1, 1);
INSERT INTO public."Pacco_Premium" VALUES (7, 920, 3.9, 11.7, 7);
INSERT INTO public."Pacco_Premium" VALUES (3, 770, 5.8, 5.1, 3);
INSERT INTO public."Pacco_Premium" VALUES (12, 706, 3.2, 8.2, 12);
INSERT INTO public."Pacco_Premium" VALUES (19, 491, 6.1, 7.2, 19);
INSERT INTO public."Pacco_Premium" VALUES (21, 796, 2.3, 3.1, 21);
INSERT INTO public."Pacco_Premium" VALUES (22, 750, 2.8, 19.4, 22);
INSERT INTO public."Pacco_Premium" VALUES (23, 770, 5.8, 5.1, 23);
INSERT INTO public."Pacco_Premium" VALUES (24, 980, 3.7, 1.7, 24);
INSERT INTO public."Pacco_Premium" VALUES (25, 27, 3.4, 11.7, 25);
INSERT INTO public."Pacco_Premium" VALUES (26, 690, 3.6, 3.7, 26);
INSERT INTO public."Pacco_Premium" VALUES (27, 920, 3.9, 11.7, 27);
INSERT INTO public."Pacco_Premium" VALUES (28, 558, 6.8, 17.3, 28);
INSERT INTO public."Pacco_Premium" VALUES (29, 30, 3.7, 4, 29);
INSERT INTO public."Pacco_Premium" VALUES (30, 324, 4.9, 6.6, 30);
INSERT INTO public."Pacco_Premium" VALUES (31, 468, 3.8, 12.1, 31);
INSERT INTO public."Pacco_Premium" VALUES (32, 706, 3.2, 8.2, 32);
INSERT INTO public."Pacco_Premium" VALUES (33, 440, 4.3, 11.6, 33);
INSERT INTO public."Pacco_Premium" VALUES (34, 87, 2.2, 18, 34);
INSERT INTO public."Pacco_Premium" VALUES (35, 325, 7.1, 8.7, 35);
INSERT INTO public."Pacco_Premium" VALUES (36, 583, 4.2, 2.6, 36);
INSERT INTO public."Pacco_Premium" VALUES (37, 695, 5.1, 8.4, 37);
INSERT INTO public."Pacco_Premium" VALUES (38, 647, 6.1, 11.2, 38);
INSERT INTO public."Pacco_Premium" VALUES (39, 491, 6.1, 7.2, 39);
INSERT INTO public."Pacco_Premium" VALUES (40, 70, 5.7, 11.5, 40);
INSERT INTO public."Pacco_Premium" VALUES (41, 70, 5.7, 11.5, 41);
INSERT INTO public."Pacco_Premium" VALUES (42, 796, 2.3, 3.1, 42);
INSERT INTO public."Pacco_Premium" VALUES (43, 750, 2.8, 19.4, 43);
INSERT INTO public."Pacco_Premium" VALUES (44, 770, 5.8, 5.1, 44);
INSERT INTO public."Pacco_Premium" VALUES (45, 980, 3.7, 1.7, 45);
INSERT INTO public."Pacco_Premium" VALUES (46, 27, 3.4, 11.7, 46);
INSERT INTO public."Pacco_Premium" VALUES (47, 690, 3.6, 3.7, 47);
INSERT INTO public."Pacco_Premium" VALUES (48, 920, 3.9, 11.7, 48);
INSERT INTO public."Pacco_Premium" VALUES (49, 558, 6.8, 17.3, 49);
INSERT INTO public."Pacco_Premium" VALUES (50, 30, 3.7, 4, 50);
INSERT INTO public."Pacco_Premium" VALUES (51, 324, 4.9, 6.6, 51);
INSERT INTO public."Pacco_Premium" VALUES (53, 706, 3.2, 8.2, 53);
INSERT INTO public."Pacco_Premium" VALUES (54, 440, 4.3, 11.6, 54);
INSERT INTO public."Pacco_Premium" VALUES (55, 87, 2.2, 18, 55);
INSERT INTO public."Pacco_Premium" VALUES (56, 325, 7.1, 8.7, 56);
INSERT INTO public."Pacco_Premium" VALUES (57, 583, 4.2, 2.6, 57);
INSERT INTO public."Pacco_Premium" VALUES (58, 695, 5.1, 8.4, 58);
INSERT INTO public."Pacco_Premium" VALUES (59, 647, 6.1, 11.2, 59);
INSERT INTO public."Pacco_Premium" VALUES (60, 491, 6.1, 7.2, 60);
INSERT INTO public."Pacco_Premium" VALUES (61, 70, 5.7, 11.5, 61);
INSERT INTO public."Pacco_Premium" VALUES (62, 70, 5.7, 11.5, 62);
INSERT INTO public."Pacco_Premium" VALUES (63, 796, 2.3, 3.1, 63);
INSERT INTO public."Pacco_Premium" VALUES (64, 750, 2.8, 19.4, 64);
INSERT INTO public."Pacco_Premium" VALUES (65, 770, 5.8, 5.1, 65);
INSERT INTO public."Pacco_Premium" VALUES (66, 980, 3.7, 1.7, 66);
INSERT INTO public."Pacco_Premium" VALUES (67, 27, 3.4, 11.7, 67);
INSERT INTO public."Pacco_Premium" VALUES (68, 690, 3.6, 3.7, 68);
INSERT INTO public."Pacco_Premium" VALUES (69, 920, 3.9, 11.7, 69);
INSERT INTO public."Pacco_Premium" VALUES (70, 558, 6.8, 17.3, 70);
INSERT INTO public."Pacco_Premium" VALUES (71, 30, 3.7, 4, 71);
INSERT INTO public."Pacco_Premium" VALUES (72, 324, 4.9, 6.6, 72);
INSERT INTO public."Pacco_Premium" VALUES (73, 468, 3.8, 12.1, 73);
INSERT INTO public."Pacco_Premium" VALUES (74, 706, 3.2, 8.2, 74);
INSERT INTO public."Pacco_Premium" VALUES (75, 440, 4.3, 11.6, 75);
INSERT INTO public."Pacco_Premium" VALUES (76, 87, 2.2, 18, 76);
INSERT INTO public."Pacco_Premium" VALUES (77, 325, 7.1, 8.7, 77);
INSERT INTO public."Pacco_Premium" VALUES (78, 583, 4.2, 2.6, 78);
INSERT INTO public."Pacco_Premium" VALUES (79, 695, 5.1, 8.4, 79);
INSERT INTO public."Pacco_Premium" VALUES (80, 647, 6.1, 11.2, 80);
INSERT INTO public."Pacco_Premium" VALUES (81, 491, 6.1, 7.2, 81);
INSERT INTO public."Pacco_Premium" VALUES (82, 70, 5.7, 11.5, 82);
INSERT INTO public."Pacco_Premium" VALUES (83, 70, 5.7, 11.5, 83);
INSERT INTO public."Pacco_Premium" VALUES (84, 796, 2.3, 3.1, 84);
INSERT INTO public."Pacco_Premium" VALUES (85, 750, 2.8, 19.4, 85);
INSERT INTO public."Pacco_Premium" VALUES (86, 770, 5.8, 5.1, 86);
INSERT INTO public."Pacco_Premium" VALUES (87, 980, 3.7, 1.7, 87);
INSERT INTO public."Pacco_Premium" VALUES (88, 27, 3.4, 11.7, 88);
INSERT INTO public."Pacco_Premium" VALUES (89, 690, 3.6, 3.7, 89);
INSERT INTO public."Pacco_Premium" VALUES (90, 920, 3.9, 11.7, 90);
INSERT INTO public."Pacco_Premium" VALUES (91, 558, 6.8, 17.3, 91);
INSERT INTO public."Pacco_Premium" VALUES (92, 30, 3.7, 4, 92);
INSERT INTO public."Pacco_Premium" VALUES (93, 324, 4.9, 6.6, 93);
INSERT INTO public."Pacco_Premium" VALUES (94, 468, 3.8, 12.1, 94);
INSERT INTO public."Pacco_Premium" VALUES (95, 706, 3.2, 8.2, 95);
INSERT INTO public."Pacco_Premium" VALUES (96, 440, 4.3, 11.6, 96);
INSERT INTO public."Pacco_Premium" VALUES (97, 87, 2.2, 18, 97);
INSERT INTO public."Pacco_Premium" VALUES (98, 325, 7.1, 8.7, 98);
INSERT INTO public."Pacco_Premium" VALUES (99, 583, 4.2, 2.6, 99);
INSERT INTO public."Pacco_Premium" VALUES (100, 695, 5.1, 8.4, 100);
INSERT INTO public."Pacco_Premium" VALUES (101, 647, 6.1, 11.2, 101);
INSERT INTO public."Pacco_Premium" VALUES (102, 491, 6.1, 7.2, 102);
INSERT INTO public."Pacco_Premium" VALUES (103, 70, 5.7, 11.5, 103);
INSERT INTO public."Pacco_Premium" VALUES (104, 70, 5.7, 11.5, 104);
INSERT INTO public."Pacco_Premium" VALUES (105, 796, 2.3, 3.1, 105);
INSERT INTO public."Pacco_Premium" VALUES (106, 750, 2.8, 19.4, 106);
INSERT INTO public."Pacco_Premium" VALUES (107, 770, 5.8, 5.1, 107);
INSERT INTO public."Pacco_Premium" VALUES (108, 980, 3.7, 1.7, 108);
INSERT INTO public."Pacco_Premium" VALUES (109, 27, 3.4, 11.7, 109);
INSERT INTO public."Pacco_Premium" VALUES (110, 690, 3.6, 3.7, 110);
INSERT INTO public."Pacco_Premium" VALUES (111, 920, 3.9, 11.7, 111);
INSERT INTO public."Pacco_Premium" VALUES (112, 558, 6.8, 17.3, 112);
INSERT INTO public."Pacco_Premium" VALUES (113, 30, 3.7, 4, 113);
INSERT INTO public."Pacco_Premium" VALUES (114, 324, 4.9, 6.6, 114);
INSERT INTO public."Pacco_Premium" VALUES (115, 468, 3.8, 12.1, 115);
INSERT INTO public."Pacco_Premium" VALUES (116, 706, 3.2, 8.2, 116);
INSERT INTO public."Pacco_Premium" VALUES (117, 440, 4.3, 11.6, 117);
INSERT INTO public."Pacco_Premium" VALUES (118, 87, 2.2, 18, 118);
INSERT INTO public."Pacco_Premium" VALUES (119, 325, 7.1, 8.7, 119);
INSERT INTO public."Pacco_Premium" VALUES (120, 583, 4.2, 2.6, 120);
INSERT INTO public."Pacco_Premium" VALUES (121, 695, 5.1, 8.4, 121);
INSERT INTO public."Pacco_Premium" VALUES (122, 647, 6.1, 11.2, 122);
INSERT INTO public."Pacco_Premium" VALUES (123, 491, 6.1, 7.2, 123);
INSERT INTO public."Pacco_Premium" VALUES (124, 70, 5.7, 11.5, 124);
INSERT INTO public."Pacco_Premium" VALUES (125, 70, 5.7, 11.5, 125);
INSERT INTO public."Pacco_Premium" VALUES (126, 796, 2.3, 3.1, 126);
INSERT INTO public."Pacco_Premium" VALUES (127, 750, 2.8, 19.4, 127);
INSERT INTO public."Pacco_Premium" VALUES (128, 770, 5.8, 5.1, 128);
INSERT INTO public."Pacco_Premium" VALUES (129, 980, 3.7, 1.7, 129);
INSERT INTO public."Pacco_Premium" VALUES (130, 27, 3.4, 11.7, 130);
INSERT INTO public."Pacco_Premium" VALUES (131, 690, 3.6, 3.7, 131);
INSERT INTO public."Pacco_Premium" VALUES (132, 920, 3.9, 11.7, 132);
INSERT INTO public."Pacco_Premium" VALUES (133, 558, 6.8, 17.3, 133);
INSERT INTO public."Pacco_Premium" VALUES (134, 30, 3.7, 4, 134);
INSERT INTO public."Pacco_Premium" VALUES (135, 324, 4.9, 6.6, 135);
INSERT INTO public."Pacco_Premium" VALUES (136, 468, 3.8, 12.1, 136);
INSERT INTO public."Pacco_Premium" VALUES (137, 706, 3.2, 8.2, 137);
INSERT INTO public."Pacco_Premium" VALUES (138, 440, 4.3, 11.6, 138);
INSERT INTO public."Pacco_Premium" VALUES (139, 87, 2.2, 18, 139);
INSERT INTO public."Pacco_Premium" VALUES (140, 325, 7.1, 8.7, 140);
INSERT INTO public."Pacco_Premium" VALUES (141, 583, 4.2, 2.6, 141);
INSERT INTO public."Pacco_Premium" VALUES (142, 695, 5.1, 8.4, 142);
INSERT INTO public."Pacco_Premium" VALUES (143, 647, 6.1, 11.2, 143);
INSERT INTO public."Pacco_Premium" VALUES (144, 491, 6.1, 7.2, 144);
INSERT INTO public."Pacco_Premium" VALUES (145, 70, 5.7, 11.5, 145);
INSERT INTO public."Pacco_Premium" VALUES (146, 70, 5.7, 11.5, 146);
INSERT INTO public."Pacco_Premium" VALUES (147, 796, 2.3, 3.1, 147);
INSERT INTO public."Pacco_Premium" VALUES (148, 750, 2.8, 19.4, 148);
INSERT INTO public."Pacco_Premium" VALUES (149, 770, 5.8, 5.1, 149);
INSERT INTO public."Pacco_Premium" VALUES (150, 980, 3.7, 1.7, 150);
INSERT INTO public."Pacco_Premium" VALUES (151, 27, 3.4, 11.7, 151);
INSERT INTO public."Pacco_Premium" VALUES (152, 690, 3.6, 3.7, 152);
INSERT INTO public."Pacco_Premium" VALUES (153, 920, 3.9, 11.7, 153);
INSERT INTO public."Pacco_Premium" VALUES (154, 558, 6.8, 17.3, 154);
INSERT INTO public."Pacco_Premium" VALUES (155, 30, 3.7, 4, 155);
INSERT INTO public."Pacco_Premium" VALUES (156, 324, 4.9, 6.6, 156);
INSERT INTO public."Pacco_Premium" VALUES (157, 468, 3.8, 12.1, 157);
INSERT INTO public."Pacco_Premium" VALUES (158, 706, 3.2, 8.2, 158);
INSERT INTO public."Pacco_Premium" VALUES (159, 440, 4.3, 11.6, 159);
INSERT INTO public."Pacco_Premium" VALUES (160, 87, 2.2, 18, 160);
INSERT INTO public."Pacco_Premium" VALUES (161, 325, 7.1, 8.7, 161);
INSERT INTO public."Pacco_Premium" VALUES (162, 583, 4.2, 2.6, 162);
INSERT INTO public."Pacco_Premium" VALUES (163, 695, 5.1, 8.4, 163);
INSERT INTO public."Pacco_Premium" VALUES (164, 647, 6.1, 11.2, 164);
INSERT INTO public."Pacco_Premium" VALUES (165, 491, 6.1, 7.2, 165);
INSERT INTO public."Pacco_Premium" VALUES (166, 70, 5.7, 11.5, 166);
INSERT INTO public."Pacco_Premium" VALUES (167, 70, 5.7, 11.5, 167);
INSERT INTO public."Pacco_Premium" VALUES (168, 796, 2.3, 3.1, 168);
INSERT INTO public."Pacco_Premium" VALUES (169, 750, 2.8, 19.4, 169);
INSERT INTO public."Pacco_Premium" VALUES (170, 770, 5.8, 5.1, 170);
INSERT INTO public."Pacco_Premium" VALUES (171, 980, 3.7, 1.7, 171);
INSERT INTO public."Pacco_Premium" VALUES (172, 27, 3.4, 11.7, 172);
INSERT INTO public."Pacco_Premium" VALUES (173, 690, 3.6, 3.7, 173);
INSERT INTO public."Pacco_Premium" VALUES (174, 920, 3.9, 11.7, 174);
INSERT INTO public."Pacco_Premium" VALUES (175, 558, 6.8, 17.3, 175);
INSERT INTO public."Pacco_Premium" VALUES (176, 30, 3.7, 4, 176);
INSERT INTO public."Pacco_Premium" VALUES (177, 324, 4.9, 6.6, 177);
INSERT INTO public."Pacco_Premium" VALUES (178, 468, 3.8, 12.1, 178);
INSERT INTO public."Pacco_Premium" VALUES (179, 706, 3.2, 8.2, 179);
INSERT INTO public."Pacco_Premium" VALUES (180, 440, 4.3, 11.6, 180);
INSERT INTO public."Pacco_Premium" VALUES (181, 87, 2.2, 18, 181);
INSERT INTO public."Pacco_Premium" VALUES (182, 325, 7.1, 8.7, 182);
INSERT INTO public."Pacco_Premium" VALUES (183, 583, 4.2, 2.6, 183);
INSERT INTO public."Pacco_Premium" VALUES (184, 695, 5.1, 8.4, 184);
INSERT INTO public."Pacco_Premium" VALUES (185, 647, 6.1, 11.2, 185);
INSERT INTO public."Pacco_Premium" VALUES (186, 491, 6.1, 7.2, 186);
INSERT INTO public."Pacco_Premium" VALUES (187, 70, 5.7, 11.5, 187);
INSERT INTO public."Pacco_Premium" VALUES (188, 70, 5.7, 11.5, 188);
INSERT INTO public."Pacco_Premium" VALUES (189, 796, 2.3, 3.1, 189);
INSERT INTO public."Pacco_Premium" VALUES (190, 750, 2.8, 19.4, 190);
INSERT INTO public."Pacco_Premium" VALUES (191, 770, 5.8, 5.1, 191);
INSERT INTO public."Pacco_Premium" VALUES (192, 980, 3.7, 1.7, 192);
INSERT INTO public."Pacco_Premium" VALUES (193, 27, 3.4, 11.7, 193);
INSERT INTO public."Pacco_Premium" VALUES (194, 690, 3.6, 3.7, 194);
INSERT INTO public."Pacco_Premium" VALUES (195, 920, 3.9, 11.7, 195);
INSERT INTO public."Pacco_Premium" VALUES (196, 558, 6.8, 17.3, 196);
INSERT INTO public."Pacco_Premium" VALUES (197, 30, 3.7, 4, 197);
INSERT INTO public."Pacco_Premium" VALUES (198, 324, 4.9, 6.6, 198);
INSERT INTO public."Pacco_Premium" VALUES (199, 468, 3.8, 12.1, 199);
INSERT INTO public."Pacco_Premium" VALUES (200, 706, 3.2, 8.2, 200);
INSERT INTO public."Pacco_Premium" VALUES (201, 440, 4.3, 11.6, 201);
INSERT INTO public."Pacco_Premium" VALUES (202, 87, 2.2, 18, 202);
INSERT INTO public."Pacco_Premium" VALUES (203, 325, 7.1, 8.7, 203);
INSERT INTO public."Pacco_Premium" VALUES (204, 583, 4.2, 2.6, 204);
INSERT INTO public."Pacco_Premium" VALUES (205, 695, 5.1, 8.4, 205);
INSERT INTO public."Pacco_Premium" VALUES (206, 647, 6.1, 11.2, 206);
INSERT INTO public."Pacco_Premium" VALUES (207, 491, 6.1, 7.2, 207);
INSERT INTO public."Pacco_Premium" VALUES (208, 70, 5.7, 11.5, 208);
INSERT INTO public."Pacco_Premium" VALUES (209, 70, 5.7, 11.5, 209);
INSERT INTO public."Pacco_Premium" VALUES (210, 796, 2.3, 3.1, 210);
INSERT INTO public."Pacco_Premium" VALUES (211, 750, 2.8, 19.4, 211);
INSERT INTO public."Pacco_Premium" VALUES (212, 770, 5.8, 5.1, 212);
INSERT INTO public."Pacco_Premium" VALUES (213, 980, 3.7, 1.7, 213);
INSERT INTO public."Pacco_Premium" VALUES (214, 27, 3.4, 11.7, 214);
INSERT INTO public."Pacco_Premium" VALUES (215, 690, 3.6, 3.7, 215);
INSERT INTO public."Pacco_Premium" VALUES (216, 920, 3.9, 11.7, 216);
INSERT INTO public."Pacco_Premium" VALUES (217, 558, 6.8, 17.3, 217);
INSERT INTO public."Pacco_Premium" VALUES (218, 30, 3.7, 4, 218);
INSERT INTO public."Pacco_Premium" VALUES (219, 324, 4.9, 6.6, 219);
INSERT INTO public."Pacco_Premium" VALUES (220, 468, 3.8, 12.1, 220);
INSERT INTO public."Pacco_Premium" VALUES (221, 706, 3.2, 8.2, 221);
INSERT INTO public."Pacco_Premium" VALUES (222, 440, 4.3, 11.6, 222);
INSERT INTO public."Pacco_Premium" VALUES (223, 87, 2.2, 18, 223);
INSERT INTO public."Pacco_Premium" VALUES (224, 325, 7.1, 8.7, 224);
INSERT INTO public."Pacco_Premium" VALUES (225, 583, 4.2, 2.6, 225);
INSERT INTO public."Pacco_Premium" VALUES (226, 695, 5.1, 8.4, 226);
INSERT INTO public."Pacco_Premium" VALUES (227, 647, 6.1, 11.2, 227);
INSERT INTO public."Pacco_Premium" VALUES (228, 491, 6.1, 7.2, 228);
INSERT INTO public."Pacco_Premium" VALUES (229, 70, 5.7, 11.5, 229);
INSERT INTO public."Pacco_Premium" VALUES (230, 70, 5.7, 11.5, 230);
INSERT INTO public."Pacco_Premium" VALUES (231, 796, 2.3, 3.1, 231);
INSERT INTO public."Pacco_Premium" VALUES (232, 750, 2.8, 19.4, 232);
INSERT INTO public."Pacco_Premium" VALUES (233, 770, 5.8, 5.1, 233);
INSERT INTO public."Pacco_Premium" VALUES (234, 980, 3.7, 1.7, 234);
INSERT INTO public."Pacco_Premium" VALUES (235, 27, 3.4, 11.7, 235);
INSERT INTO public."Pacco_Premium" VALUES (236, 690, 3.6, 3.7, 236);
INSERT INTO public."Pacco_Premium" VALUES (237, 920, 3.9, 11.7, 237);
INSERT INTO public."Pacco_Premium" VALUES (238, 558, 6.8, 17.3, 238);
INSERT INTO public."Pacco_Premium" VALUES (239, 30, 3.7, 4, 239);
INSERT INTO public."Pacco_Premium" VALUES (240, 324, 4.9, 6.6, 240);
INSERT INTO public."Pacco_Premium" VALUES (241, 468, 3.8, 12.1, 241);
INSERT INTO public."Pacco_Premium" VALUES (242, 706, 3.2, 8.2, 242);
INSERT INTO public."Pacco_Premium" VALUES (243, 440, 4.3, 11.6, 243);
INSERT INTO public."Pacco_Premium" VALUES (244, 87, 2.2, 18, 244);
INSERT INTO public."Pacco_Premium" VALUES (245, 325, 7.1, 8.7, 245);
INSERT INTO public."Pacco_Premium" VALUES (246, 583, 4.2, 2.6, 246);
INSERT INTO public."Pacco_Premium" VALUES (247, 695, 5.1, 8.4, 247);
INSERT INTO public."Pacco_Premium" VALUES (248, 647, 6.1, 11.2, 248);
INSERT INTO public."Pacco_Premium" VALUES (249, 491, 6.1, 7.2, 249);
INSERT INTO public."Pacco_Premium" VALUES (250, 70, 5.7, 11.5, 250);
INSERT INTO public."Pacco_Premium" VALUES (251, 70, 5.7, 11.5, 251);
INSERT INTO public."Pacco_Premium" VALUES (252, 796, 2.3, 3.1, 252);
INSERT INTO public."Pacco_Premium" VALUES (253, 750, 2.8, 19.4, 253);
INSERT INTO public."Pacco_Premium" VALUES (254, 770, 5.8, 5.1, 254);
INSERT INTO public."Pacco_Premium" VALUES (255, 980, 3.7, 1.7, 255);
INSERT INTO public."Pacco_Premium" VALUES (256, 27, 3.4, 11.7, 256);
INSERT INTO public."Pacco_Premium" VALUES (257, 690, 3.6, 3.7, 257);
INSERT INTO public."Pacco_Premium" VALUES (258, 920, 3.9, 11.7, 258);
INSERT INTO public."Pacco_Premium" VALUES (259, 558, 6.8, 17.3, 259);
INSERT INTO public."Pacco_Premium" VALUES (260, 30, 3.7, 4, 260);
INSERT INTO public."Pacco_Premium" VALUES (261, 324, 4.9, 6.6, 261);
INSERT INTO public."Pacco_Premium" VALUES (262, 468, 3.8, 12.1, 262);
INSERT INTO public."Pacco_Premium" VALUES (263, 706, 3.2, 8.2, 263);
INSERT INTO public."Pacco_Premium" VALUES (264, 440, 4.3, 11.6, 264);
INSERT INTO public."Pacco_Premium" VALUES (265, 87, 2.2, 18, 265);
INSERT INTO public."Pacco_Premium" VALUES (266, 325, 7.1, 8.7, 266);
INSERT INTO public."Pacco_Premium" VALUES (267, 583, 4.2, 2.6, 267);
INSERT INTO public."Pacco_Premium" VALUES (268, 695, 5.1, 8.4, 268);
INSERT INTO public."Pacco_Premium" VALUES (269, 647, 6.1, 11.2, 269);
INSERT INTO public."Pacco_Premium" VALUES (270, 491, 6.1, 7.2, 270);
INSERT INTO public."Pacco_Premium" VALUES (271, 70, 5.7, 11.5, 271);
INSERT INTO public."Pacco_Premium" VALUES (272, 70, 5.7, 11.5, 272);
INSERT INTO public."Pacco_Premium" VALUES (273, 796, 2.3, 3.1, 273);
INSERT INTO public."Pacco_Premium" VALUES (274, 750, 2.8, 19.4, 274);
INSERT INTO public."Pacco_Premium" VALUES (275, 770, 5.8, 5.1, 275);
INSERT INTO public."Pacco_Premium" VALUES (276, 980, 3.7, 1.7, 276);
INSERT INTO public."Pacco_Premium" VALUES (277, 27, 3.4, 11.7, 277);
INSERT INTO public."Pacco_Premium" VALUES (278, 690, 3.6, 3.7, 278);
INSERT INTO public."Pacco_Premium" VALUES (279, 920, 3.9, 11.7, 279);
INSERT INTO public."Pacco_Premium" VALUES (280, 558, 6.8, 17.3, 280);
INSERT INTO public."Pacco_Premium" VALUES (281, 30, 3.7, 4, 281);
INSERT INTO public."Pacco_Premium" VALUES (282, 324, 4.9, 6.6, 282);
INSERT INTO public."Pacco_Premium" VALUES (283, 468, 3.8, 12.1, 283);
INSERT INTO public."Pacco_Premium" VALUES (284, 706, 3.2, 8.2, 284);
INSERT INTO public."Pacco_Premium" VALUES (285, 440, 4.3, 11.6, 285);
INSERT INTO public."Pacco_Premium" VALUES (286, 87, 2.2, 18, 286);
INSERT INTO public."Pacco_Premium" VALUES (287, 325, 7.1, 8.7, 287);
INSERT INTO public."Pacco_Premium" VALUES (288, 583, 4.2, 2.6, 288);
INSERT INTO public."Pacco_Premium" VALUES (289, 695, 5.1, 8.4, 289);
INSERT INTO public."Pacco_Premium" VALUES (290, 647, 6.1, 11.2, 290);
INSERT INTO public."Pacco_Premium" VALUES (291, 491, 6.1, 7.2, 291);
INSERT INTO public."Pacco_Premium" VALUES (292, 70, 5.7, 11.5, 292);
INSERT INTO public."Pacco_Premium" VALUES (293, 70, 5.7, 11.5, 293);
INSERT INTO public."Pacco_Premium" VALUES (294, 796, 2.3, 3.1, 294);
INSERT INTO public."Pacco_Premium" VALUES (295, 750, 2.8, 19.4, 295);
INSERT INTO public."Pacco_Premium" VALUES (296, 770, 5.8, 5.1, 296);
INSERT INTO public."Pacco_Premium" VALUES (297, 980, 3.7, 1.7, 297);
INSERT INTO public."Pacco_Premium" VALUES (298, 27, 3.4, 11.7, 298);
INSERT INTO public."Pacco_Premium" VALUES (299, 690, 3.6, 3.7, 299);
INSERT INTO public."Pacco_Premium" VALUES (300, 920, 3.9, 11.7, 300);
INSERT INTO public."Pacco_Premium" VALUES (301, 558, 6.8, 17.3, 301);
INSERT INTO public."Pacco_Premium" VALUES (302, 30, 3.7, 4, 302);
INSERT INTO public."Pacco_Premium" VALUES (303, 324, 4.9, 6.6, 303);
INSERT INTO public."Pacco_Premium" VALUES (304, 468, 3.8, 12.1, 304);
INSERT INTO public."Pacco_Premium" VALUES (305, 706, 3.2, 8.2, 305);
INSERT INTO public."Pacco_Premium" VALUES (306, 440, 4.3, 11.6, 306);
INSERT INTO public."Pacco_Premium" VALUES (307, 87, 2.2, 18, 307);
INSERT INTO public."Pacco_Premium" VALUES (308, 325, 7.1, 8.7, 308);
INSERT INTO public."Pacco_Premium" VALUES (309, 583, 4.2, 2.6, 309);
INSERT INTO public."Pacco_Premium" VALUES (310, 695, 5.1, 8.4, 310);
INSERT INTO public."Pacco_Premium" VALUES (311, 647, 6.1, 11.2, 311);
INSERT INTO public."Pacco_Premium" VALUES (312, 491, 6.1, 7.2, 312);
INSERT INTO public."Pacco_Premium" VALUES (313, 70, 5.7, 11.5, 313);
INSERT INTO public."Pacco_Premium" VALUES (314, 70, 5.7, 11.5, 314);
INSERT INTO public."Pacco_Premium" VALUES (315, 796, 2.3, 3.1, 315);
INSERT INTO public."Pacco_Premium" VALUES (316, 750, 2.8, 19.4, 316);
INSERT INTO public."Pacco_Premium" VALUES (317, 770, 5.8, 5.1, 317);
INSERT INTO public."Pacco_Premium" VALUES (318, 980, 3.7, 1.7, 318);
INSERT INTO public."Pacco_Premium" VALUES (319, 27, 3.4, 11.7, 319);
INSERT INTO public."Pacco_Premium" VALUES (320, 690, 3.6, 3.7, 320);
INSERT INTO public."Pacco_Premium" VALUES (321, 920, 3.9, 11.7, 321);
INSERT INTO public."Pacco_Premium" VALUES (322, 558, 6.8, 17.3, 322);
INSERT INTO public."Pacco_Premium" VALUES (323, 30, 3.7, 4, 323);
INSERT INTO public."Pacco_Premium" VALUES (324, 324, 4.9, 6.6, 324);
INSERT INTO public."Pacco_Premium" VALUES (325, 468, 3.8, 12.1, 325);
INSERT INTO public."Pacco_Premium" VALUES (326, 706, 3.2, 8.2, 326);
INSERT INTO public."Pacco_Premium" VALUES (327, 440, 4.3, 11.6, 327);
INSERT INTO public."Pacco_Premium" VALUES (328, 87, 2.2, 18, 328);
INSERT INTO public."Pacco_Premium" VALUES (329, 325, 7.1, 8.7, 329);
INSERT INTO public."Pacco_Premium" VALUES (330, 583, 4.2, 2.6, 330);
INSERT INTO public."Pacco_Premium" VALUES (331, 695, 5.1, 8.4, 331);
INSERT INTO public."Pacco_Premium" VALUES (332, 647, 6.1, 11.2, 332);
INSERT INTO public."Pacco_Premium" VALUES (333, 491, 6.1, 7.2, 333);
INSERT INTO public."Pacco_Premium" VALUES (334, 70, 5.7, 11.5, 334);
INSERT INTO public."Pacco_Premium" VALUES (335, 70, 5.7, 11.5, 335);
INSERT INTO public."Pacco_Premium" VALUES (336, 796, 2.3, 3.1, 336);
INSERT INTO public."Pacco_Premium" VALUES (337, 750, 2.8, 19.4, 337);
INSERT INTO public."Pacco_Premium" VALUES (338, 770, 5.8, 5.1, 338);
INSERT INTO public."Pacco_Premium" VALUES (339, 980, 3.7, 1.7, 339);
INSERT INTO public."Pacco_Premium" VALUES (340, 27, 3.4, 11.7, 340);
INSERT INTO public."Pacco_Premium" VALUES (341, 690, 3.6, 3.7, 341);
INSERT INTO public."Pacco_Premium" VALUES (342, 920, 3.9, 11.7, 342);
INSERT INTO public."Pacco_Premium" VALUES (343, 558, 6.8, 17.3, 343);
INSERT INTO public."Pacco_Premium" VALUES (344, 30, 3.7, 4, 344);
INSERT INTO public."Pacco_Premium" VALUES (345, 324, 4.9, 6.6, 345);
INSERT INTO public."Pacco_Premium" VALUES (346, 468, 3.8, 12.1, 346);
INSERT INTO public."Pacco_Premium" VALUES (347, 706, 3.2, 8.2, 347);
INSERT INTO public."Pacco_Premium" VALUES (348, 440, 4.3, 11.6, 348);
INSERT INTO public."Pacco_Premium" VALUES (349, 87, 2.2, 18, 349);
INSERT INTO public."Pacco_Premium" VALUES (350, 325, 7.1, 8.7, 350);
INSERT INTO public."Pacco_Premium" VALUES (351, 583, 4.2, 2.6, 351);
INSERT INTO public."Pacco_Premium" VALUES (352, 695, 5.1, 8.4, 352);
INSERT INTO public."Pacco_Premium" VALUES (353, 647, 6.1, 11.2, 353);
INSERT INTO public."Pacco_Premium" VALUES (354, 491, 6.1, 7.2, 354);
INSERT INTO public."Pacco_Premium" VALUES (355, 70, 5.7, 11.5, 355);
INSERT INTO public."Pacco_Premium" VALUES (356, 70, 5.7, 11.5, 356);
INSERT INTO public."Pacco_Premium" VALUES (357, 796, 2.3, 3.1, 357);
INSERT INTO public."Pacco_Premium" VALUES (358, 750, 2.8, 19.4, 358);
INSERT INTO public."Pacco_Premium" VALUES (359, 770, 5.8, 5.1, 359);
INSERT INTO public."Pacco_Premium" VALUES (360, 980, 3.7, 1.7, 360);
INSERT INTO public."Pacco_Premium" VALUES (361, 27, 3.4, 11.7, 361);
INSERT INTO public."Pacco_Premium" VALUES (362, 690, 3.6, 3.7, 362);
INSERT INTO public."Pacco_Premium" VALUES (363, 920, 3.9, 11.7, 363);
INSERT INTO public."Pacco_Premium" VALUES (364, 558, 6.8, 17.3, 364);
INSERT INTO public."Pacco_Premium" VALUES (365, 30, 3.7, 4, 365);
INSERT INTO public."Pacco_Premium" VALUES (366, 324, 4.9, 6.6, 366);
INSERT INTO public."Pacco_Premium" VALUES (367, 468, 3.8, 12.1, 367);
INSERT INTO public."Pacco_Premium" VALUES (368, 706, 3.2, 8.2, 368);
INSERT INTO public."Pacco_Premium" VALUES (369, 440, 4.3, 11.6, 369);
INSERT INTO public."Pacco_Premium" VALUES (370, 87, 2.2, 18, 370);
INSERT INTO public."Pacco_Premium" VALUES (371, 325, 7.1, 8.7, 371);
INSERT INTO public."Pacco_Premium" VALUES (372, 583, 4.2, 2.6, 372);
INSERT INTO public."Pacco_Premium" VALUES (373, 695, 5.1, 8.4, 373);
INSERT INTO public."Pacco_Premium" VALUES (374, 647, 6.1, 11.2, 374);
INSERT INTO public."Pacco_Premium" VALUES (375, 491, 6.1, 7.2, 375);
INSERT INTO public."Pacco_Premium" VALUES (376, 70, 5.7, 11.5, 376);
INSERT INTO public."Pacco_Premium" VALUES (377, 70, 5.7, 11.5, 377);
INSERT INTO public."Pacco_Premium" VALUES (378, 796, 2.3, 3.1, 378);
INSERT INTO public."Pacco_Premium" VALUES (379, 750, 2.8, 19.4, 379);
INSERT INTO public."Pacco_Premium" VALUES (380, 770, 5.8, 5.1, 380);
INSERT INTO public."Pacco_Premium" VALUES (381, 980, 3.7, 1.7, 381);
INSERT INTO public."Pacco_Premium" VALUES (382, 27, 3.4, 11.7, 382);
INSERT INTO public."Pacco_Premium" VALUES (383, 690, 3.6, 3.7, 383);
INSERT INTO public."Pacco_Premium" VALUES (384, 920, 3.9, 11.7, 384);
INSERT INTO public."Pacco_Premium" VALUES (385, 558, 6.8, 17.3, 385);
INSERT INTO public."Pacco_Premium" VALUES (386, 30, 3.7, 4, 386);
INSERT INTO public."Pacco_Premium" VALUES (387, 324, 4.9, 6.6, 387);
INSERT INTO public."Pacco_Premium" VALUES (388, 468, 3.8, 12.1, 388);
INSERT INTO public."Pacco_Premium" VALUES (389, 706, 3.2, 8.2, 389);
INSERT INTO public."Pacco_Premium" VALUES (390, 440, 4.3, 11.6, 390);
INSERT INTO public."Pacco_Premium" VALUES (391, 87, 2.2, 18, 391);
INSERT INTO public."Pacco_Premium" VALUES (392, 325, 7.1, 8.7, 392);
INSERT INTO public."Pacco_Premium" VALUES (393, 583, 4.2, 2.6, 393);
INSERT INTO public."Pacco_Premium" VALUES (394, 695, 5.1, 8.4, 394);
INSERT INTO public."Pacco_Premium" VALUES (395, 647, 6.1, 11.2, 395);
INSERT INTO public."Pacco_Premium" VALUES (396, 491, 6.1, 7.2, 396);
INSERT INTO public."Pacco_Premium" VALUES (397, 70, 5.7, 11.5, 397);
INSERT INTO public."Pacco_Premium" VALUES (398, 70, 5.7, 11.5, 398);
INSERT INTO public."Pacco_Premium" VALUES (399, 796, 2.3, 3.1, 399);
INSERT INTO public."Pacco_Premium" VALUES (400, 750, 2.8, 19.4, 400);
INSERT INTO public."Pacco_Premium" VALUES (401, 770, 5.8, 5.1, 401);
INSERT INTO public."Pacco_Premium" VALUES (402, 980, 3.7, 1.7, 402);
INSERT INTO public."Pacco_Premium" VALUES (403, 27, 3.4, 11.7, 403);
INSERT INTO public."Pacco_Premium" VALUES (404, 690, 3.6, 3.7, 404);
INSERT INTO public."Pacco_Premium" VALUES (405, 920, 3.9, 11.7, 405);
INSERT INTO public."Pacco_Premium" VALUES (406, 558, 6.8, 17.3, 406);
INSERT INTO public."Pacco_Premium" VALUES (407, 30, 3.7, 4, 407);
INSERT INTO public."Pacco_Premium" VALUES (408, 324, 4.9, 6.6, 408);
INSERT INTO public."Pacco_Premium" VALUES (409, 468, 3.8, 12.1, 409);
INSERT INTO public."Pacco_Premium" VALUES (410, 706, 3.2, 8.2, 410);
INSERT INTO public."Pacco_Premium" VALUES (411, 440, 4.3, 11.6, 411);
INSERT INTO public."Pacco_Premium" VALUES (412, 87, 2.2, 18, 412);
INSERT INTO public."Pacco_Premium" VALUES (413, 325, 7.1, 8.7, 413);
INSERT INTO public."Pacco_Premium" VALUES (414, 583, 4.2, 2.6, 414);
INSERT INTO public."Pacco_Premium" VALUES (415, 695, 5.1, 8.4, 415);
INSERT INTO public."Pacco_Premium" VALUES (416, 647, 6.1, 11.2, 416);
INSERT INTO public."Pacco_Premium" VALUES (417, 491, 6.1, 7.2, 417);
INSERT INTO public."Pacco_Premium" VALUES (418, 70, 5.7, 11.5, 418);
INSERT INTO public."Pacco_Premium" VALUES (419, 70, 5.7, 11.5, 419);
INSERT INTO public."Pacco_Premium" VALUES (420, 796, 2.3, 3.1, 420);
INSERT INTO public."Pacco_Premium" VALUES (421, 750, 2.8, 19.4, 421);
INSERT INTO public."Pacco_Premium" VALUES (422, 770, 5.8, 5.1, 422);
INSERT INTO public."Pacco_Premium" VALUES (423, 980, 3.7, 1.7, 423);
INSERT INTO public."Pacco_Premium" VALUES (424, 27, 3.4, 11.7, 424);
INSERT INTO public."Pacco_Premium" VALUES (425, 690, 3.6, 3.7, 425);
INSERT INTO public."Pacco_Premium" VALUES (426, 920, 3.9, 11.7, 426);
INSERT INTO public."Pacco_Premium" VALUES (427, 558, 6.8, 17.3, 427);
INSERT INTO public."Pacco_Premium" VALUES (428, 30, 3.7, 4, 428);
INSERT INTO public."Pacco_Premium" VALUES (429, 324, 4.9, 6.6, 429);
INSERT INTO public."Pacco_Premium" VALUES (430, 468, 3.8, 12.1, 430);
INSERT INTO public."Pacco_Premium" VALUES (431, 706, 3.2, 8.2, 431);
INSERT INTO public."Pacco_Premium" VALUES (432, 440, 4.3, 11.6, 432);
INSERT INTO public."Pacco_Premium" VALUES (433, 87, 2.2, 18, 433);
INSERT INTO public."Pacco_Premium" VALUES (434, 325, 7.1, 8.7, 434);
INSERT INTO public."Pacco_Premium" VALUES (435, 583, 4.2, 2.6, 435);
INSERT INTO public."Pacco_Premium" VALUES (436, 695, 5.1, 8.4, 436);
INSERT INTO public."Pacco_Premium" VALUES (437, 647, 6.1, 11.2, 437);
INSERT INTO public."Pacco_Premium" VALUES (438, 491, 6.1, 7.2, 438);
INSERT INTO public."Pacco_Premium" VALUES (439, 70, 5.7, 11.5, 439);
INSERT INTO public."Pacco_Premium" VALUES (440, 70, 5.7, 11.5, 440);
INSERT INTO public."Pacco_Premium" VALUES (441, 796, 2.3, 3.1, 441);
INSERT INTO public."Pacco_Premium" VALUES (442, 750, 2.8, 19.4, 442);
INSERT INTO public."Pacco_Premium" VALUES (443, 770, 5.8, 5.1, 443);
INSERT INTO public."Pacco_Premium" VALUES (444, 980, 3.7, 1.7, 444);
INSERT INTO public."Pacco_Premium" VALUES (445, 27, 3.4, 11.7, 445);
INSERT INTO public."Pacco_Premium" VALUES (446, 690, 3.6, 3.7, 446);
INSERT INTO public."Pacco_Premium" VALUES (447, 920, 3.9, 11.7, 447);
INSERT INTO public."Pacco_Premium" VALUES (448, 558, 6.8, 17.3, 448);
INSERT INTO public."Pacco_Premium" VALUES (449, 30, 3.7, 4, 449);
INSERT INTO public."Pacco_Premium" VALUES (450, 324, 4.9, 6.6, 450);
INSERT INTO public."Pacco_Premium" VALUES (451, 468, 3.8, 12.1, 451);
INSERT INTO public."Pacco_Premium" VALUES (452, 706, 3.2, 8.2, 452);
INSERT INTO public."Pacco_Premium" VALUES (453, 440, 4.3, 11.6, 453);
INSERT INTO public."Pacco_Premium" VALUES (454, 87, 2.2, 18, 454);
INSERT INTO public."Pacco_Premium" VALUES (455, 325, 7.1, 8.7, 455);
INSERT INTO public."Pacco_Premium" VALUES (456, 583, 4.2, 2.6, 456);
INSERT INTO public."Pacco_Premium" VALUES (457, 695, 5.1, 8.4, 457);
INSERT INTO public."Pacco_Premium" VALUES (458, 647, 6.1, 11.2, 458);
INSERT INTO public."Pacco_Premium" VALUES (459, 491, 6.1, 7.2, 459);
INSERT INTO public."Pacco_Premium" VALUES (460, 70, 5.7, 11.5, 460);
INSERT INTO public."Pacco_Premium" VALUES (461, 70, 5.7, 11.5, 461);
INSERT INTO public."Pacco_Premium" VALUES (462, 796, 2.3, 3.1, 462);
INSERT INTO public."Pacco_Premium" VALUES (463, 750, 2.8, 19.4, 463);
INSERT INTO public."Pacco_Premium" VALUES (464, 770, 5.8, 5.1, 464);
INSERT INTO public."Pacco_Premium" VALUES (465, 980, 3.7, 1.7, 465);
INSERT INTO public."Pacco_Premium" VALUES (466, 27, 3.4, 11.7, 466);
INSERT INTO public."Pacco_Premium" VALUES (467, 690, 3.6, 3.7, 467);
INSERT INTO public."Pacco_Premium" VALUES (468, 920, 3.9, 11.7, 468);
INSERT INTO public."Pacco_Premium" VALUES (469, 558, 6.8, 17.3, 469);
INSERT INTO public."Pacco_Premium" VALUES (470, 30, 3.7, 4, 470);
INSERT INTO public."Pacco_Premium" VALUES (471, 324, 4.9, 6.6, 471);
INSERT INTO public."Pacco_Premium" VALUES (472, 468, 3.8, 12.1, 472);
INSERT INTO public."Pacco_Premium" VALUES (473, 706, 3.2, 8.2, 473);
INSERT INTO public."Pacco_Premium" VALUES (474, 440, 4.3, 11.6, 474);
INSERT INTO public."Pacco_Premium" VALUES (475, 87, 2.2, 18, 475);
INSERT INTO public."Pacco_Premium" VALUES (476, 325, 7.1, 8.7, 476);
INSERT INTO public."Pacco_Premium" VALUES (477, 583, 4.2, 2.6, 477);
INSERT INTO public."Pacco_Premium" VALUES (478, 695, 5.1, 8.4, 478);
INSERT INTO public."Pacco_Premium" VALUES (479, 647, 6.1, 11.2, 479);
INSERT INTO public."Pacco_Premium" VALUES (480, 491, 6.1, 7.2, 480);
INSERT INTO public."Pacco_Premium" VALUES (481, 70, 5.7, 11.5, 481);
INSERT INTO public."Pacco_Premium" VALUES (482, 70, 5.7, 11.5, 482);
INSERT INTO public."Pacco_Premium" VALUES (483, 796, 2.3, 3.1, 483);
INSERT INTO public."Pacco_Premium" VALUES (484, 750, 2.8, 19.4, 484);
INSERT INTO public."Pacco_Premium" VALUES (485, 770, 5.8, 5.1, 485);
INSERT INTO public."Pacco_Premium" VALUES (486, 980, 3.7, 1.7, 486);
INSERT INTO public."Pacco_Premium" VALUES (487, 27, 3.4, 11.7, 487);
INSERT INTO public."Pacco_Premium" VALUES (488, 690, 3.6, 3.7, 488);
INSERT INTO public."Pacco_Premium" VALUES (489, 920, 3.9, 11.7, 489);
INSERT INTO public."Pacco_Premium" VALUES (490, 558, 6.8, 17.3, 490);
INSERT INTO public."Pacco_Premium" VALUES (491, 30, 3.7, 4, 491);
INSERT INTO public."Pacco_Premium" VALUES (492, 324, 4.9, 6.6, 492);
INSERT INTO public."Pacco_Premium" VALUES (493, 468, 3.8, 12.1, 493);
INSERT INTO public."Pacco_Premium" VALUES (494, 706, 3.2, 8.2, 494);
INSERT INTO public."Pacco_Premium" VALUES (495, 440, 4.3, 11.6, 495);
INSERT INTO public."Pacco_Premium" VALUES (496, 87, 2.2, 18, 496);
INSERT INTO public."Pacco_Premium" VALUES (497, 325, 7.1, 8.7, 497);
INSERT INTO public."Pacco_Premium" VALUES (498, 583, 4.2, 2.6, 498);
INSERT INTO public."Pacco_Premium" VALUES (499, 695, 5.1, 8.4, 499);
INSERT INTO public."Pacco_Premium" VALUES (500, 647, 6.1, 11.2, 500);
INSERT INTO public."Pacco_Premium" VALUES (501, 491, 6.1, 7.2, 501);
INSERT INTO public."Pacco_Premium" VALUES (502, 70, 5.7, 11.5, 502);
INSERT INTO public."Pacco_Premium" VALUES (503, 70, 5.7, 11.5, 503);
INSERT INTO public."Pacco_Premium" VALUES (504, 796, 2.3, 3.1, 504);
INSERT INTO public."Pacco_Premium" VALUES (505, 750, 2.8, 19.4, 505);
INSERT INTO public."Pacco_Premium" VALUES (506, 770, 5.8, 5.1, 506);
INSERT INTO public."Pacco_Premium" VALUES (507, 980, 3.7, 1.7, 507);
INSERT INTO public."Pacco_Premium" VALUES (508, 27, 3.4, 11.7, 508);
INSERT INTO public."Pacco_Premium" VALUES (509, 690, 3.6, 3.7, 509);
INSERT INTO public."Pacco_Premium" VALUES (510, 920, 3.9, 11.7, 510);
INSERT INTO public."Pacco_Premium" VALUES (511, 558, 6.8, 17.3, 511);
INSERT INTO public."Pacco_Premium" VALUES (512, 30, 3.7, 4, 512);
INSERT INTO public."Pacco_Premium" VALUES (513, 324, 4.9, 6.6, 513);
INSERT INTO public."Pacco_Premium" VALUES (514, 468, 3.8, 12.1, 514);
INSERT INTO public."Pacco_Premium" VALUES (515, 706, 3.2, 8.2, 515);
INSERT INTO public."Pacco_Premium" VALUES (516, 440, 4.3, 11.6, 516);
INSERT INTO public."Pacco_Premium" VALUES (517, 87, 2.2, 18, 517);
INSERT INTO public."Pacco_Premium" VALUES (518, 325, 7.1, 8.7, 518);
INSERT INTO public."Pacco_Premium" VALUES (519, 583, 4.2, 2.6, 519);
INSERT INTO public."Pacco_Premium" VALUES (520, 695, 5.1, 8.4, 520);
INSERT INTO public."Pacco_Premium" VALUES (521, 647, 6.1, 11.2, 521);
INSERT INTO public."Pacco_Premium" VALUES (522, 491, 6.1, 7.2, 522);
INSERT INTO public."Pacco_Premium" VALUES (523, 70, 5.7, 11.5, 523);
INSERT INTO public."Pacco_Premium" VALUES (524, 70, 5.7, 11.5, 524);
INSERT INTO public."Pacco_Premium" VALUES (527, 796, 2.3, 3.1, 527);
INSERT INTO public."Pacco_Premium" VALUES (528, 750, 2.8, 19.4, 528);
INSERT INTO public."Pacco_Premium" VALUES (529, 770, 5.8, 5.1, 529);
INSERT INTO public."Pacco_Premium" VALUES (530, 980, 3.7, 1.7, 530);
INSERT INTO public."Pacco_Premium" VALUES (531, 27, 3.4, 11.7, 531);
INSERT INTO public."Pacco_Premium" VALUES (532, 690, 3.6, 3.7, 532);
INSERT INTO public."Pacco_Premium" VALUES (533, 920, 3.9, 11.7, 533);
INSERT INTO public."Pacco_Premium" VALUES (534, 558, 6.8, 17.3, 534);
INSERT INTO public."Pacco_Premium" VALUES (535, 30, 3.7, 4, 535);
INSERT INTO public."Pacco_Premium" VALUES (536, 324, 4.9, 6.6, 536);
INSERT INTO public."Pacco_Premium" VALUES (537, 468, 3.8, 12.1, 537);
INSERT INTO public."Pacco_Premium" VALUES (538, 706, 3.2, 8.2, 538);
INSERT INTO public."Pacco_Premium" VALUES (539, 440, 4.3, 11.6, 539);
INSERT INTO public."Pacco_Premium" VALUES (540, 87, 2.2, 18, 540);
INSERT INTO public."Pacco_Premium" VALUES (541, 325, 7.1, 8.7, 541);
INSERT INTO public."Pacco_Premium" VALUES (542, 583, 4.2, 2.6, 542);
INSERT INTO public."Pacco_Premium" VALUES (543, 695, 5.1, 8.4, 543);
INSERT INTO public."Pacco_Premium" VALUES (544, 647, 6.1, 11.2, 544);
INSERT INTO public."Pacco_Premium" VALUES (545, 491, 6.1, 7.2, 545);
INSERT INTO public."Pacco_Premium" VALUES (546, 70, 5.7, 11.5, 546);
INSERT INTO public."Pacco_Premium" VALUES (547, 70, 5.7, 11.5, 547);
INSERT INTO public."Pacco_Premium" VALUES (548, 796, 2.3, 3.1, 548);
INSERT INTO public."Pacco_Premium" VALUES (549, 750, 2.8, 19.4, 549);
INSERT INTO public."Pacco_Premium" VALUES (550, 770, 5.8, 5.1, 550);
INSERT INTO public."Pacco_Premium" VALUES (551, 980, 3.7, 1.7, 551);
INSERT INTO public."Pacco_Premium" VALUES (552, 27, 3.4, 11.7, 552);
INSERT INTO public."Pacco_Premium" VALUES (553, 690, 3.6, 3.7, 553);
INSERT INTO public."Pacco_Premium" VALUES (554, 920, 3.9, 11.7, 554);
INSERT INTO public."Pacco_Premium" VALUES (555, 558, 6.8, 17.3, 555);
INSERT INTO public."Pacco_Premium" VALUES (556, 30, 3.7, 4, 556);
INSERT INTO public."Pacco_Premium" VALUES (557, 324, 4.9, 6.6, 557);
INSERT INTO public."Pacco_Premium" VALUES (558, 468, 3.8, 12.1, 558);
INSERT INTO public."Pacco_Premium" VALUES (559, 706, 3.2, 8.2, 559);
INSERT INTO public."Pacco_Premium" VALUES (560, 440, 4.3, 11.6, 560);
INSERT INTO public."Pacco_Premium" VALUES (561, 87, 2.2, 18, 561);
INSERT INTO public."Pacco_Premium" VALUES (562, 325, 7.1, 8.7, 562);
INSERT INTO public."Pacco_Premium" VALUES (563, 583, 4.2, 2.6, 563);
INSERT INTO public."Pacco_Premium" VALUES (564, 695, 5.1, 8.4, 564);
INSERT INTO public."Pacco_Premium" VALUES (565, 647, 6.1, 11.2, 565);
INSERT INTO public."Pacco_Premium" VALUES (566, 491, 6.1, 7.2, 566);
INSERT INTO public."Pacco_Premium" VALUES (567, 70, 5.7, 11.5, 567);
INSERT INTO public."Pacco_Premium" VALUES (568, 70, 5.7, 11.5, 568);
INSERT INTO public."Pacco_Premium" VALUES (569, 796, 2.3, 3.1, 569);
INSERT INTO public."Pacco_Premium" VALUES (570, 750, 2.8, 19.4, 570);
INSERT INTO public."Pacco_Premium" VALUES (571, 770, 5.8, 5.1, 571);
INSERT INTO public."Pacco_Premium" VALUES (572, 980, 3.7, 1.7, 572);
INSERT INTO public."Pacco_Premium" VALUES (573, 27, 3.4, 11.7, 573);
INSERT INTO public."Pacco_Premium" VALUES (574, 690, 3.6, 3.7, 574);
INSERT INTO public."Pacco_Premium" VALUES (575, 920, 3.9, 11.7, 575);
INSERT INTO public."Pacco_Premium" VALUES (576, 558, 6.8, 17.3, 576);
INSERT INTO public."Pacco_Premium" VALUES (577, 30, 3.7, 4, 577);
INSERT INTO public."Pacco_Premium" VALUES (578, 324, 4.9, 6.6, 578);
INSERT INTO public."Pacco_Premium" VALUES (579, 468, 3.8, 12.1, 579);
INSERT INTO public."Pacco_Premium" VALUES (580, 706, 3.2, 8.2, 580);
INSERT INTO public."Pacco_Premium" VALUES (581, 440, 4.3, 11.6, 581);
INSERT INTO public."Pacco_Premium" VALUES (582, 87, 2.2, 18, 582);
INSERT INTO public."Pacco_Premium" VALUES (583, 325, 7.1, 8.7, 583);
INSERT INTO public."Pacco_Premium" VALUES (584, 583, 4.2, 2.6, 584);
INSERT INTO public."Pacco_Premium" VALUES (585, 695, 5.1, 8.4, 585);
INSERT INTO public."Pacco_Premium" VALUES (586, 647, 6.1, 11.2, 586);
INSERT INTO public."Pacco_Premium" VALUES (587, 491, 6.1, 7.2, 587);
INSERT INTO public."Pacco_Premium" VALUES (588, 70, 5.7, 11.5, 588);
INSERT INTO public."Pacco_Premium" VALUES (589, 70, 5.7, 11.5, 589);
INSERT INTO public."Pacco_Premium" VALUES (590, 796, 2.3, 3.1, 590);
INSERT INTO public."Pacco_Premium" VALUES (591, 750, 2.8, 19.4, 591);
INSERT INTO public."Pacco_Premium" VALUES (592, 770, 5.8, 5.1, 592);
INSERT INTO public."Pacco_Premium" VALUES (593, 980, 3.7, 1.7, 593);
INSERT INTO public."Pacco_Premium" VALUES (594, 27, 3.4, 11.7, 594);
INSERT INTO public."Pacco_Premium" VALUES (595, 690, 3.6, 3.7, 595);
INSERT INTO public."Pacco_Premium" VALUES (596, 920, 3.9, 11.7, 596);
INSERT INTO public."Pacco_Premium" VALUES (597, 558, 6.8, 17.3, 597);
INSERT INTO public."Pacco_Premium" VALUES (598, 30, 3.7, 4, 598);
INSERT INTO public."Pacco_Premium" VALUES (599, 324, 4.9, 6.6, 599);
INSERT INTO public."Pacco_Premium" VALUES (600, 468, 3.8, 12.1, 600);
INSERT INTO public."Pacco_Premium" VALUES (601, 706, 3.2, 8.2, 601);
INSERT INTO public."Pacco_Premium" VALUES (602, 440, 4.3, 11.6, 602);
INSERT INTO public."Pacco_Premium" VALUES (603, 87, 2.2, 18, 603);
INSERT INTO public."Pacco_Premium" VALUES (604, 325, 7.1, 8.7, 604);
INSERT INTO public."Pacco_Premium" VALUES (605, 583, 4.2, 2.6, 605);
INSERT INTO public."Pacco_Premium" VALUES (606, 695, 5.1, 8.4, 606);
INSERT INTO public."Pacco_Premium" VALUES (607, 647, 6.1, 11.2, 607);
INSERT INTO public."Pacco_Premium" VALUES (608, 491, 6.1, 7.2, 608);
INSERT INTO public."Pacco_Premium" VALUES (609, 70, 5.7, 11.5, 609);
INSERT INTO public."Pacco_Premium" VALUES (610, 70, 5.7, 11.5, 610);
INSERT INTO public."Pacco_Premium" VALUES (611, 796, 2.3, 3.1, 611);
INSERT INTO public."Pacco_Premium" VALUES (612, 750, 2.8, 19.4, 612);
INSERT INTO public."Pacco_Premium" VALUES (613, 770, 5.8, 5.1, 613);
INSERT INTO public."Pacco_Premium" VALUES (614, 980, 3.7, 1.7, 614);
INSERT INTO public."Pacco_Premium" VALUES (615, 27, 3.4, 11.7, 615);
INSERT INTO public."Pacco_Premium" VALUES (616, 690, 3.6, 3.7, 616);
INSERT INTO public."Pacco_Premium" VALUES (617, 920, 3.9, 11.7, 617);
INSERT INTO public."Pacco_Premium" VALUES (618, 558, 6.8, 17.3, 618);
INSERT INTO public."Pacco_Premium" VALUES (619, 30, 3.7, 4, 619);
INSERT INTO public."Pacco_Premium" VALUES (620, 324, 4.9, 6.6, 620);
INSERT INTO public."Pacco_Premium" VALUES (621, 468, 3.8, 12.1, 621);
INSERT INTO public."Pacco_Premium" VALUES (622, 706, 3.2, 8.2, 622);
INSERT INTO public."Pacco_Premium" VALUES (623, 440, 4.3, 11.6, 623);
INSERT INTO public."Pacco_Premium" VALUES (624, 87, 2.2, 18, 624);
INSERT INTO public."Pacco_Premium" VALUES (625, 325, 7.1, 8.7, 625);
INSERT INTO public."Pacco_Premium" VALUES (626, 583, 4.2, 2.6, 626);
INSERT INTO public."Pacco_Premium" VALUES (627, 695, 5.1, 8.4, 627);
INSERT INTO public."Pacco_Premium" VALUES (628, 647, 6.1, 11.2, 628);
INSERT INTO public."Pacco_Premium" VALUES (629, 491, 6.1, 7.2, 629);
INSERT INTO public."Pacco_Premium" VALUES (630, 70, 5.7, 11.5, 630);
INSERT INTO public."Pacco_Premium" VALUES (631, 70, 5.7, 11.5, 631);
INSERT INTO public."Pacco_Premium" VALUES (632, 796, 2.3, 3.1, 632);
INSERT INTO public."Pacco_Premium" VALUES (633, 750, 2.8, 19.4, 633);
INSERT INTO public."Pacco_Premium" VALUES (634, 770, 5.8, 5.1, 634);
INSERT INTO public."Pacco_Premium" VALUES (635, 980, 3.7, 1.7, 635);
INSERT INTO public."Pacco_Premium" VALUES (636, 27, 3.4, 11.7, 636);
INSERT INTO public."Pacco_Premium" VALUES (637, 690, 3.6, 3.7, 637);
INSERT INTO public."Pacco_Premium" VALUES (638, 920, 3.9, 11.7, 638);
INSERT INTO public."Pacco_Premium" VALUES (639, 558, 6.8, 17.3, 639);
INSERT INTO public."Pacco_Premium" VALUES (640, 30, 3.7, 4, 640);
INSERT INTO public."Pacco_Premium" VALUES (641, 324, 4.9, 6.6, 641);
INSERT INTO public."Pacco_Premium" VALUES (642, 468, 3.8, 12.1, 642);
INSERT INTO public."Pacco_Premium" VALUES (643, 706, 3.2, 8.2, 643);
INSERT INTO public."Pacco_Premium" VALUES (644, 440, 4.3, 11.6, 644);
INSERT INTO public."Pacco_Premium" VALUES (645, 87, 2.2, 18, 645);
INSERT INTO public."Pacco_Premium" VALUES (646, 325, 7.1, 8.7, 646);
INSERT INTO public."Pacco_Premium" VALUES (647, 583, 4.2, 2.6, 647);
INSERT INTO public."Pacco_Premium" VALUES (648, 695, 5.1, 8.4, 648);
INSERT INTO public."Pacco_Premium" VALUES (649, 647, 6.1, 11.2, 649);
INSERT INTO public."Pacco_Premium" VALUES (650, 491, 6.1, 7.2, 650);
INSERT INTO public."Pacco_Premium" VALUES (651, 70, 5.7, 11.5, 651);
INSERT INTO public."Pacco_Premium" VALUES (652, 70, 5.7, 11.5, 652);
INSERT INTO public."Pacco_Premium" VALUES (653, 796, 2.3, 3.1, 653);
INSERT INTO public."Pacco_Premium" VALUES (654, 750, 2.8, 19.4, 654);
INSERT INTO public."Pacco_Premium" VALUES (655, 770, 5.8, 5.1, 655);
INSERT INTO public."Pacco_Premium" VALUES (656, 980, 3.7, 1.7, 656);
INSERT INTO public."Pacco_Premium" VALUES (657, 27, 3.4, 11.7, 657);
INSERT INTO public."Pacco_Premium" VALUES (658, 690, 3.6, 3.7, 658);
INSERT INTO public."Pacco_Premium" VALUES (659, 920, 3.9, 11.7, 659);
INSERT INTO public."Pacco_Premium" VALUES (660, 558, 6.8, 17.3, 660);
INSERT INTO public."Pacco_Premium" VALUES (661, 30, 3.7, 4, 661);
INSERT INTO public."Pacco_Premium" VALUES (662, 324, 4.9, 6.6, 662);
INSERT INTO public."Pacco_Premium" VALUES (663, 468, 3.8, 12.1, 663);
INSERT INTO public."Pacco_Premium" VALUES (664, 706, 3.2, 8.2, 664);
INSERT INTO public."Pacco_Premium" VALUES (665, 440, 4.3, 11.6, 665);
INSERT INTO public."Pacco_Premium" VALUES (666, 87, 2.2, 18, 666);
INSERT INTO public."Pacco_Premium" VALUES (667, 325, 7.1, 8.7, 667);
INSERT INTO public."Pacco_Premium" VALUES (668, 583, 4.2, 2.6, 668);
INSERT INTO public."Pacco_Premium" VALUES (669, 695, 5.1, 8.4, 669);
INSERT INTO public."Pacco_Premium" VALUES (670, 647, 6.1, 11.2, 670);
INSERT INTO public."Pacco_Premium" VALUES (671, 491, 6.1, 7.2, 671);
INSERT INTO public."Pacco_Premium" VALUES (672, 70, 5.7, 11.5, 672);
INSERT INTO public."Pacco_Premium" VALUES (673, 70, 5.7, 11.5, 673);
INSERT INTO public."Pacco_Premium" VALUES (674, 796, 2.3, 3.1, 674);
INSERT INTO public."Pacco_Premium" VALUES (675, 750, 2.8, 19.4, 675);
INSERT INTO public."Pacco_Premium" VALUES (676, 770, 5.8, 5.1, 676);
INSERT INTO public."Pacco_Premium" VALUES (677, 980, 3.7, 1.7, 677);
INSERT INTO public."Pacco_Premium" VALUES (678, 27, 3.4, 11.7, 678);
INSERT INTO public."Pacco_Premium" VALUES (679, 690, 3.6, 3.7, 679);
INSERT INTO public."Pacco_Premium" VALUES (680, 920, 3.9, 11.7, 680);
INSERT INTO public."Pacco_Premium" VALUES (681, 558, 6.8, 17.3, 681);
INSERT INTO public."Pacco_Premium" VALUES (682, 30, 3.7, 4, 682);
INSERT INTO public."Pacco_Premium" VALUES (683, 324, 4.9, 6.6, 683);
INSERT INTO public."Pacco_Premium" VALUES (684, 468, 3.8, 12.1, 684);
INSERT INTO public."Pacco_Premium" VALUES (685, 706, 3.2, 8.2, 685);
INSERT INTO public."Pacco_Premium" VALUES (686, 440, 4.3, 11.6, 686);
INSERT INTO public."Pacco_Premium" VALUES (687, 87, 2.2, 18, 687);
INSERT INTO public."Pacco_Premium" VALUES (688, 325, 7.1, 8.7, 688);
INSERT INTO public."Pacco_Premium" VALUES (689, 583, 4.2, 2.6, 689);
INSERT INTO public."Pacco_Premium" VALUES (690, 695, 5.1, 8.4, 690);
INSERT INTO public."Pacco_Premium" VALUES (691, 647, 6.1, 11.2, 691);
INSERT INTO public."Pacco_Premium" VALUES (692, 491, 6.1, 7.2, 692);
INSERT INTO public."Pacco_Premium" VALUES (693, 70, 5.7, 11.5, 693);
INSERT INTO public."Pacco_Premium" VALUES (694, 70, 5.7, 11.5, 694);
INSERT INTO public."Pacco_Premium" VALUES (695, 796, 2.3, 3.1, 695);
INSERT INTO public."Pacco_Premium" VALUES (696, 750, 2.8, 19.4, 696);
INSERT INTO public."Pacco_Premium" VALUES (697, 770, 5.8, 5.1, 697);
INSERT INTO public."Pacco_Premium" VALUES (698, 980, 3.7, 1.7, 698);
INSERT INTO public."Pacco_Premium" VALUES (699, 27, 3.4, 11.7, 699);
INSERT INTO public."Pacco_Premium" VALUES (700, 690, 3.6, 3.7, 700);
INSERT INTO public."Pacco_Premium" VALUES (701, 920, 3.9, 11.7, 701);
INSERT INTO public."Pacco_Premium" VALUES (702, 558, 6.8, 17.3, 702);
INSERT INTO public."Pacco_Premium" VALUES (703, 30, 3.7, 4, 703);
INSERT INTO public."Pacco_Premium" VALUES (704, 324, 4.9, 6.6, 704);
INSERT INTO public."Pacco_Premium" VALUES (705, 468, 3.8, 12.1, 705);
INSERT INTO public."Pacco_Premium" VALUES (706, 706, 3.2, 8.2, 706);
INSERT INTO public."Pacco_Premium" VALUES (707, 440, 4.3, 11.6, 707);
INSERT INTO public."Pacco_Premium" VALUES (708, 87, 2.2, 18, 708);
INSERT INTO public."Pacco_Premium" VALUES (709, 325, 7.1, 8.7, 709);
INSERT INTO public."Pacco_Premium" VALUES (710, 583, 4.2, 2.6, 710);
INSERT INTO public."Pacco_Premium" VALUES (711, 695, 5.1, 8.4, 711);
INSERT INTO public."Pacco_Premium" VALUES (712, 647, 6.1, 11.2, 712);
INSERT INTO public."Pacco_Premium" VALUES (713, 491, 6.1, 7.2, 713);
INSERT INTO public."Pacco_Premium" VALUES (714, 70, 5.7, 11.5, 714);
INSERT INTO public."Pacco_Premium" VALUES (715, 70, 5.7, 11.5, 715);
INSERT INTO public."Pacco_Premium" VALUES (716, 796, 2.3, 3.1, 716);
INSERT INTO public."Pacco_Premium" VALUES (717, 750, 2.8, 19.4, 717);
INSERT INTO public."Pacco_Premium" VALUES (718, 770, 5.8, 5.1, 718);
INSERT INTO public."Pacco_Premium" VALUES (719, 980, 3.7, 1.7, 719);
INSERT INTO public."Pacco_Premium" VALUES (720, 27, 3.4, 11.7, 720);
INSERT INTO public."Pacco_Premium" VALUES (721, 690, 3.6, 3.7, 721);
INSERT INTO public."Pacco_Premium" VALUES (722, 920, 3.9, 11.7, 722);
INSERT INTO public."Pacco_Premium" VALUES (723, 558, 6.8, 17.3, 723);
INSERT INTO public."Pacco_Premium" VALUES (724, 30, 3.7, 4, 724);
INSERT INTO public."Pacco_Premium" VALUES (725, 324, 4.9, 6.6, 725);
INSERT INTO public."Pacco_Premium" VALUES (726, 468, 3.8, 12.1, 726);
INSERT INTO public."Pacco_Premium" VALUES (727, 706, 3.2, 8.2, 727);
INSERT INTO public."Pacco_Premium" VALUES (728, 440, 4.3, 11.6, 728);
INSERT INTO public."Pacco_Premium" VALUES (729, 87, 2.2, 18, 729);
INSERT INTO public."Pacco_Premium" VALUES (730, 325, 7.1, 8.7, 730);
INSERT INTO public."Pacco_Premium" VALUES (731, 583, 4.2, 2.6, 731);
INSERT INTO public."Pacco_Premium" VALUES (732, 695, 5.1, 8.4, 732);
INSERT INTO public."Pacco_Premium" VALUES (733, 647, 6.1, 11.2, 733);
INSERT INTO public."Pacco_Premium" VALUES (734, 491, 6.1, 7.2, 734);
INSERT INTO public."Pacco_Premium" VALUES (735, 70, 5.7, 11.5, 735);
INSERT INTO public."Pacco_Premium" VALUES (736, 70, 5.7, 11.5, 736);
INSERT INTO public."Pacco_Premium" VALUES (737, 796, 2.3, 3.1, 737);
INSERT INTO public."Pacco_Premium" VALUES (738, 750, 2.8, 19.4, 738);
INSERT INTO public."Pacco_Premium" VALUES (739, 770, 5.8, 5.1, 739);
INSERT INTO public."Pacco_Premium" VALUES (740, 980, 3.7, 1.7, 740);
INSERT INTO public."Pacco_Premium" VALUES (741, 27, 3.4, 11.7, 741);
INSERT INTO public."Pacco_Premium" VALUES (742, 690, 3.6, 3.7, 742);
INSERT INTO public."Pacco_Premium" VALUES (743, 920, 3.9, 11.7, 743);
INSERT INTO public."Pacco_Premium" VALUES (744, 558, 6.8, 17.3, 744);
INSERT INTO public."Pacco_Premium" VALUES (745, 30, 3.7, 4, 745);
INSERT INTO public."Pacco_Premium" VALUES (746, 324, 4.9, 6.6, 746);
INSERT INTO public."Pacco_Premium" VALUES (747, 468, 3.8, 12.1, 747);
INSERT INTO public."Pacco_Premium" VALUES (748, 706, 3.2, 8.2, 748);
INSERT INTO public."Pacco_Premium" VALUES (749, 440, 4.3, 11.6, 749);
INSERT INTO public."Pacco_Premium" VALUES (750, 87, 2.2, 18, 750);
INSERT INTO public."Pacco_Premium" VALUES (751, 325, 7.1, 8.7, 751);
INSERT INTO public."Pacco_Premium" VALUES (752, 583, 4.2, 2.6, 752);
INSERT INTO public."Pacco_Premium" VALUES (753, 695, 5.1, 8.4, 753);
INSERT INTO public."Pacco_Premium" VALUES (754, 647, 6.1, 11.2, 754);
INSERT INTO public."Pacco_Premium" VALUES (755, 491, 6.1, 7.2, 755);
INSERT INTO public."Pacco_Premium" VALUES (756, 70, 5.7, 11.5, 756);
INSERT INTO public."Pacco_Premium" VALUES (757, 70, 5.7, 11.5, 757);
INSERT INTO public."Pacco_Premium" VALUES (758, 796, 2.3, 3.1, 758);
INSERT INTO public."Pacco_Premium" VALUES (759, 750, 2.8, 19.4, 759);
INSERT INTO public."Pacco_Premium" VALUES (760, 770, 5.8, 5.1, 760);
INSERT INTO public."Pacco_Premium" VALUES (761, 980, 3.7, 1.7, 761);
INSERT INTO public."Pacco_Premium" VALUES (762, 27, 3.4, 11.7, 762);
INSERT INTO public."Pacco_Premium" VALUES (763, 690, 3.6, 3.7, 763);
INSERT INTO public."Pacco_Premium" VALUES (764, 920, 3.9, 11.7, 764);
INSERT INTO public."Pacco_Premium" VALUES (765, 558, 6.8, 17.3, 765);
INSERT INTO public."Pacco_Premium" VALUES (766, 30, 3.7, 4, 766);
INSERT INTO public."Pacco_Premium" VALUES (767, 324, 4.9, 6.6, 767);
INSERT INTO public."Pacco_Premium" VALUES (768, 468, 3.8, 12.1, 768);
INSERT INTO public."Pacco_Premium" VALUES (769, 706, 3.2, 8.2, 769);
INSERT INTO public."Pacco_Premium" VALUES (770, 440, 4.3, 11.6, 770);
INSERT INTO public."Pacco_Premium" VALUES (771, 87, 2.2, 18, 771);
INSERT INTO public."Pacco_Premium" VALUES (772, 325, 7.1, 8.7, 772);
INSERT INTO public."Pacco_Premium" VALUES (773, 583, 4.2, 2.6, 773);
INSERT INTO public."Pacco_Premium" VALUES (774, 695, 5.1, 8.4, 774);
INSERT INTO public."Pacco_Premium" VALUES (775, 647, 6.1, 11.2, 775);
INSERT INTO public."Pacco_Premium" VALUES (776, 491, 6.1, 7.2, 776);
INSERT INTO public."Pacco_Premium" VALUES (777, 70, 5.7, 11.5, 777);
INSERT INTO public."Pacco_Premium" VALUES (778, 30, 3.7, 4, 778);
INSERT INTO public."Pacco_Premium" VALUES (779, 324, 4.9, 6.6, 779);
INSERT INTO public."Pacco_Premium" VALUES (780, 468, 3.8, 12.1, 780);
INSERT INTO public."Pacco_Premium" VALUES (781, 706, 3.2, 8.2, 781);
INSERT INTO public."Pacco_Premium" VALUES (782, 440, 4.3, 11.6, 782);
INSERT INTO public."Pacco_Premium" VALUES (783, 87, 2.2, 18, 783);
INSERT INTO public."Pacco_Premium" VALUES (784, 325, 7.1, 8.7, 784);
INSERT INTO public."Pacco_Premium" VALUES (785, 583, 4.2, 2.6, 785);
INSERT INTO public."Pacco_Premium" VALUES (786, 695, 5.1, 8.4, 786);
INSERT INTO public."Pacco_Premium" VALUES (787, 30, 3.7, 4, 787);
INSERT INTO public."Pacco_Premium" VALUES (788, 324, 4.9, 6.6, 788);
INSERT INTO public."Pacco_Premium" VALUES (789, 468, 3.8, 12.1, 789);
INSERT INTO public."Pacco_Premium" VALUES (790, 706, 3.2, 8.2, 790);
INSERT INTO public."Pacco_Premium" VALUES (791, 440, 4.3, 11.6, 791);
INSERT INTO public."Pacco_Premium" VALUES (795, 695, 5.1, 8.4, 791);
INSERT INTO public."Pacco_Premium" VALUES (793, 325, 7.1, 8.7, 791);
INSERT INTO public."Pacco_Premium" VALUES (794, 583, 4.2, 2.6, 791);
INSERT INTO public."Pacco_Premium" VALUES (792, 87, 2.2, 18, 791);


--
-- TOC entry 3619 (class 0 OID 18570)
-- Dependencies: 260
-- Data for Name: Reparto; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO public."Reparto" VALUES ('magazzino');
INSERT INTO public."Reparto" VALUES ('segreteria');
INSERT INTO public."Reparto" VALUES ('ufficio');


--
-- TOC entry 3620 (class 0 OID 18575)
-- Dependencies: 261
-- Data for Name: Servizi; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO public."Servizi" VALUES (55, 'costoZeroPerProve', 0, 'Other recurrent atlantoaxial dislocation');
INSERT INTO public."Servizi" VALUES (45, 'SwiftFreight', 4.8, 'taylor swift ti porta il pacco a casa');
INSERT INTO public."Servizi" VALUES (41, 'TurboDelivery', 5.9, 'un delivery turboveloce');
INSERT INTO public."Servizi" VALUES (1, 'FastTrack Express', 9, 'spedizione super veloce');
INSERT INTO public."Servizi" VALUES (29, 'TurboTransport', 16.9, 'un trasporto turboveloce');
INSERT INTO public."Servizi" VALUES (23, 'QuickMove', 10, 'ritiro veloce del pacco');
INSERT INTO public."Servizi" VALUES (51, 'QuickShip', 6.4, 'spedizione dignitosamente veloce');
INSERT INTO public."Servizi" VALUES (25, 'RapidLogistics', 3.2, 'priorità del pacco');
INSERT INTO public."Servizi" VALUES (14, 'ExpressLink', 9, 'spedizione super veloce in un punto di ritiro');
INSERT INTO public."Servizi" VALUES (46, 'InstantConnect', 9.8, 'connessione istantanea con il corriere');
INSERT INTO public."Servizi" VALUES (54, 'SwiftDelivery', 10.8, 'Taylor Swift vera ti porta il pacco a casa');
INSERT INTO public."Servizi" VALUES (52, 'SpeedyRoute', 10.8, 'il corriere evita di perdere tempo nelle consegne precedenti');
INSERT INTO public."Servizi" VALUES (50, 'ExpressDispatch', 14.3, 'qualcosa di super espresso');
INSERT INTO public."Servizi" VALUES (43, 'FastLaneTransit', 12, 'priorità super del pacco');
INSERT INTO public."Servizi" VALUES (10, 'RapidConnect', 17.2, 'visione rapida e dettagliata in ogni momento di dove si trova il pacco');
INSERT INTO public."Servizi" VALUES (53, 'RapidLogistics', 1.1, 'come l''altra rapid logistics ma costa meno');


--
-- TOC entry 3621 (class 0 OID 18580)
-- Dependencies: 262
-- Data for Name: Spedizione_Economica; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO public."Spedizione_Economica" VALUES (9, 'oobxgl21n86l160z', 'dvqwpq82d12u044j', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (26, 'rbxbrf79f09c376r', 'arllpa74i66y238j', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (19, 'bucims80t97w944z', 'echxll47x25b400a', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (32, 'magujx74u13t692j', 'dvqwpq82d12u044j', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (22, 'mfbslr80u19a742g', 'bucims80t97w944z', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (51, 'ocwhrd88a63g175v', 'yiblfs65g56k279q', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (35, 'pvgfaf41e99l262m', 'oobxgl21n86l160z', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (34, 'tzrppf44x01q376h', 'ffdwee60s61t235w', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (42, 'vmrlhf74f78j242r', 'kqwjjd23e43o622b', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (11, 'aunxad02p33x402h', 'ffdwee60s61t235w', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (16, 'echxll47x25b400a', 'jqkjfd25s12j468w', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (37, 'corzss57a06d644t', 'aunxad02p33x402h', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (15, 'awuyzn61c17c890d', 'yiblfs65g56k279q', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (33, 'dbhyzt20x58r774v', 'cvjlwx09n81j993j', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (27, 'moqyaa96b41w621l', 'ikwfcz18b86e682q', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (6, 'dvqwpq82d12u044j', 'kqwjjd23e43o622b', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (50, 'pvilho11h32q211g', 'aunxad02p33x402h', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (31, 'shnnfp42x22u151r', 'kjnlji67m42p786g', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (12, 'yiblfs65g56k279q', 'oobxgl21n86l160z', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (48, 'ceecog34d09y094c', 'oobxgl21n86l160z', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (59, 'mcsyrw69k90m893a', 'suabnl13o74w031i', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (62, 'odpsmt51i34p539x', 'fhgmof18s41j295n', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (64, 'pzgpbd57t39d363s', 'rqjqdp57p76w419r', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (65, 'fncguy16y09p079o', 'pzgpbd57t39d363s', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (68, 'ftfagh53w89t084w', 'oejkvl89k12w562d', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (69, 'uarkyi38f72r573s', 'ftfagh53w89t084w', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (72, 'uprujb40t62r387n', 'jahmzo24g76s944w', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (75, 'atbhyp35z83m686a', 'ppzecn38y37d807s', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (79, 'tefphy68k12v005m', 'fojscj13f69h621y', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (80, 'pvowth75p53j283m', 'tefphy68k12v005m', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (84, 'fpgfmz62j53v258b', 'bmvllg36p94o834q', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (85, 'edptkz65p01q097k', 'fpgfmz62j53v258b', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (86, 'rynjfz64s17v995d', 'edptkz65p01q097k', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (87, 'neuxjk34h13z966f', 'rynjfz64s17v995d', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (88, 'xztucq61z58m389z', 'neuxjk34h13z966f', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (90, 'uxzgka81u81f900v', 'czywny38u81l971j', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (95, 'qfszmm89q52l220m', 'gdrkbb46q98z701s', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (101, 'tiiflh50i08r012k', 'oouadv87n09g556b', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (103, 'voysgf92c86v824t', 'yxnaif10d79h861s', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (104, 'wzcyxj90a16i606i', 'voysgf92c86v824t', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (106, 'lwlbtz06t04n178k', 'xzkpss69s39o118k', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (112, 'wgqked19i68a969p', 'rttpav92c88i986c', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (115, 'jliean73w52o867k', 'wmmzpl91s11i675u', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (117, 'wlzdfo15l37k921k', 'baepct56e87a974t', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (118, 'ubukra69q08t009q', 'wlzdfo15l37k921k', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (121, 'pqlarh78x95c681u', 'uvrdvu49e76x287b', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (122, 'yacktw57o65u160e', 'pqlarh78x95c681u', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (125, 'lsynvw38u84v911t', 'kzvgsw10w85d287d', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (128, 'eftbvw91p58g751r', 'cimkuc40b33g393l', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (132, 'fnksxk12z31h894r', 'lrmqmu58v72g022o', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (133, 'twftbw62l90s058g', 'fnksxk12z31h894r', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (137, 'nhjzcn29m02x592d', 'nangdr55z94b355f', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (138, 'ovqwnp69g20s733t', 'nhjzcn29m02x592d', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (139, 'avixie13a53o156s', 'ovqwnp69g20s733t', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (140, 'pnxpbo53j04q846e', 'avixie13a53o156s', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (141, 'yxocqm21i97q766s', 'pnxpbo53j04q846e', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (143, 'czkdfs79m36y373n', 'pxhofa55v38m983t', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (148, 'prhpun26y68n567z', 'ldgpvv83x48q902w', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (154, 'cpqfoy83x73u061y', 'gklyzl18k69z892d', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (156, 'tyksav29f44e812h', 'wqyrsf81o90i239a', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (157, 'pmxeyj22f79q939a', 'tyksav29f44e812h', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (159, 'tgrgre42c92a215k', 'pfbnul72n73x158g', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (165, 'ynosng19p33q308s', 'hpduso80y40u629k', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (168, 'rqcnxn37i62m459v', 'jhpody16d43r836h', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (170, 'gxpvwa51v91z843a', 'gjphjf66h01r492f', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (171, 'zfvxsj03z02n196y', 'gxpvwa51v91z843a', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (174, 'cmtohz05r99b277p', 'hoxjix04w78h052i', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (175, 'wkudqr77e45y324r', 'cmtohz05r99b277p', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (178, 'hbbdtl71a93o332r', 'tdsdgt25n85t748h', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (181, 'ubhgqk91a47l249w', 'qnhjhl27o60s734b', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (185, 'inkkug20e93g176d', 'rbmdmz41d86m087i', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (186, 'fclxnj72q03i675i', 'inkkug20e93g176d', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (190, 'mtrzyg07g76q856p', 'uyheqc53x63q262p', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (191, 'fmzpzf28z43j004o', 'mtrzyg07g76q856p', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (192, 'hemeot50m73i573g', 'fmzpzf28z43j004o', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (193, 'uqzngd89k68o039y', 'hemeot50m73i573g', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (194, 'bjblph06j16d245i', 'uqzngd89k68o039y', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (196, 'biyovl42e99y464i', 'hgbzrh16u63i171y', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (201, 'vljdev57g03y090c', 'dtofbi34p99y365o', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (207, 'diojtz71g09k482b', 'qohrak59c31f972s', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (209, 'pqbyjh71p95u332w', 'twaahz52e36j670l', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (210, 'dummes59z00c736a', 'pqbyjh71p95u332w', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (212, 'otsesl75v45y509t', 'gkwlxp24b62o116h', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (218, 'vsovbt06e82k566o', 'qftkaz11f56i050v', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (221, 'qdwjuu36n94c501h', 'imccnp09o38x381t', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (223, 'xwwjzo00v04h752d', 'mqejhb39g21s907j', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (224, 'vpfjqd29o36m152p', 'xwwjzo00v04h752d', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (227, 'fymicl07g86g311z', 'vvcybr21z15j371t', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (228, 'pedxbe91i75m176m', 'fymicl07g86g311z', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (231, 'kqegmg32m29k935w', 'mkoamp49f47t875o', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (234, 'dtwigz64e10p083m', 'sonctd56f83b983b', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (238, 'bvjmam04c45s056z', 'mpucqz16x16h338y', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (239, 'xhyhhr51j99t588v', 'bvjmam04c45s056z', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (243, 'uvykyg86q63m719o', 'jjnkrf56p52e998v', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (244, 'hionfe08j30s838l', 'uvykyg86q63m719o', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (245, 'wnfbnc70h73p291z', 'hionfe08j30s838l', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (246, 'xwtrps80s90o891n', 'wnfbnc70h73p291z', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (247, 'ajidlo43u61p099h', 'xwtrps80s90o891n', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (249, 'xdywvp61j99w442z', 'qqlgsj19c62a369o', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (254, 'lxeorf85u39l996y', 'gaflzy22j28d259r', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (260, 'bbgcje71p25a045f', 'rwknhd54x94p737d', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (263, 'gbpmca29b68x702b', 'xrbejq26q15p312m', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (265, 'mhoecj38j36w784x', 'cykmvq17a37o337t', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (266, 'wiygan57q71s213z', 'mhoecj38j36w784x', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (269, 'vrlbxm76c74p195v', 'zawssc20m93t610i', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (270, 'vydrwa78d74w280l', 'vrlbxm76c74p195v', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (273, 'mrnduz12x16z223d', 'rwfaqv29l60p314v', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (276, 'ffivvv85v77v236p', 'djenxl66m93q807q', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (280, 'yzrwhf69b44t534k', 'wfbltk51o88k950q', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (281, 'ftvczh65w43l415y', 'yzrwhf69b44t534k', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (285, 'hescfp63d24r371j', 'pvesli24i05o628x', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (286, 'qkuolt71j22g986z', 'hescfp63d24r371j', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (287, 'tfbepd27f25z456b', 'qkuolt71j22g986z', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (288, 'igtgry79x29q919l', 'tfbepd27f25z456b', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (289, 'kwhebi32u53k737a', 'igtgry79x29q919l', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (291, 'dbaiib39k29d734g', 'hatoqy71b49z740w', 3, false);
INSERT INTO public."Spedizione_Economica" VALUES (203, 'ktzici06x98f179v', 'sszezk30j07n929w', 27, true);
INSERT INTO public."Spedizione_Economica" VALUES (130, 'yiqulp92v74x523w', 'glwshl40z75c831r', 9.4, true);
INSERT INTO public."Spedizione_Economica" VALUES (120, 'uvrdvu49e76x287b', 'bajcrv06p71n608e', 24.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (116, 'baepct56e87a974t', 'jliean73w52o867k', 24.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (124, 'kzvgsw10w85d287d', 'bqiccb56b92y499z', 21, true);
INSERT INTO public."Spedizione_Economica" VALUES (102, 'yxnaif10d79h861s', 'tiiflh50i08r012k', 23, true);
INSERT INTO public."Spedizione_Economica" VALUES (145, 'tfebtc60g85i970i', 'oyyiyv60r36v674q', 15.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (100, 'oouadv87n09g556b', 'luolkp90c45z532q', 21, true);
INSERT INTO public."Spedizione_Economica" VALUES (109, 'qrrqti26c27x309a', 'yyjqbv01k20u845l', 27, true);
INSERT INTO public."Spedizione_Economica" VALUES (107, 'ffooko46r26z551h', 'lwlbtz06t04n178k', 36.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (113, 'sxpitw57x28q806x', 'wgqked19i68a969p', 31.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (142, 'pxhofa55v38m983t', 'yxocqm21i97q766s', 22.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (149, 'ukyykl89k69e756x', 'prhpun26y68n567z', 24.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (147, 'ldgpvv83x48q902w', 'njpxey61x79k993r', 5.2, true);
INSERT INTO public."Spedizione_Economica" VALUES (136, 'nangdr55z94b355f', 'xsgrxt24x46l839x', 12.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (114, 'wmmzpl91s11i675u', 'sxpitw57x28q806x', 15.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (105, 'xzkpss69s39o118k', 'wzcyxj90a16i606i', 9.4, true);
INSERT INTO public."Spedizione_Economica" VALUES (127, 'cimkuc40b33g393l', 'pfjlhl23k93r751x', 21, true);
INSERT INTO public."Spedizione_Economica" VALUES (131, 'lrmqmu58v72g022o', 'yiqulp92v74x523w', 36.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (146, 'njpxey61x79k993r', 'tfebtc60g85i970i', 24.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (129, 'glwshl40z75c831r', 'eftbvw91p58g751r', 23, true);
INSERT INTO public."Spedizione_Economica" VALUES (99, 'luolkp90c45z532q', 'stdvsh45d64b133m', 37.4, true);
INSERT INTO public."Spedizione_Economica" VALUES (295, 'naxcfe43n87k487q', 'hnqwqq55k83w052b', 21, true);
INSERT INTO public."Spedizione_Economica" VALUES (123, 'bqiccb56b92y499z', 'yacktw57o65u160e', 3, true);
INSERT INTO public."Spedizione_Economica" VALUES (134, 'luitgk17d02s129y', 'twftbw62l90s058g', 14.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (111, 'rttpav92c88i986c', 'kmqkbq06h76p620e', 22.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (126, 'pfjlhl23k93r751x', 'lsynvw38u84v911t', 37.4, true);
INSERT INTO public."Spedizione_Economica" VALUES (151, 'cupmtj64w01y897u', 'mqjrqc08j12u791o', 21, true);
INSERT INTO public."Spedizione_Economica" VALUES (119, 'bajcrv06p71n608e', 'ubukra69q08t009q', 5.2, true);
INSERT INTO public."Spedizione_Economica" VALUES (135, 'xsgrxt24x46l839x', 'luitgk17d02s129y', 27, true);
INSERT INTO public."Spedizione_Economica" VALUES (150, 'mqjrqc08j12u791o', 'ukyykl89k69e756x', 3, true);
INSERT INTO public."Spedizione_Economica" VALUES (144, 'oyyiyv60r36v674q', 'czkdfs79m36y373n', 31.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (110, 'kmqkbq06h76p620e', 'qrrqti26c27x309a', 12.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (108, 'yyjqbv01k20u845l', 'ffooko46r26z551h', 14.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (152, 'ltrebm84s57p282x', 'cupmtj64w01y897u', 37.4, true);
INSERT INTO public."Spedizione_Economica" VALUES (153, 'gklyzl18k69z892d', 'ltrebm84s57p282x', 21, true);
INSERT INTO public."Spedizione_Economica" VALUES (155, 'wqyrsf81o90i239a', 'cpqfoy83x73u061y', 23, true);
INSERT INTO public."Spedizione_Economica" VALUES (158, 'pfbnul72n73x158g', 'pmxeyj22f79q939a', 9.4, true);
INSERT INTO public."Spedizione_Economica" VALUES (160, 'onfaqd30q64x811d', 'tgrgre42c92a215k', 36.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (161, 'hiinuk36j01s143y', 'onfaqd30q64x811d', 14.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (162, 'qsboqw04w60w823t', 'hiinuk36j01s143y', 27, true);
INSERT INTO public."Spedizione_Economica" VALUES (163, 'gtylvt32f54w241f', 'qsboqw04w60w823t', 12.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (164, 'hpduso80y40u629k', 'gtylvt32f54w241f', 22.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (166, 'yaclmp50h40v408v', 'ynosng19p33q308s', 31.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (167, 'jhpody16d43r836h', 'yaclmp50h40v408v', 15.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (169, 'gjphjf66h01r492f', 'rqcnxn37i62m459v', 24.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (172, 'uemrug90i48x328u', 'zfvxsj03z02n196y', 5.2, true);
INSERT INTO public."Spedizione_Economica" VALUES (173, 'hoxjix04w78h052i', 'uemrug90i48x328u', 24.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (176, 'elzydc89l17j043l', 'wkudqr77e45y324r', 3, true);
INSERT INTO public."Spedizione_Economica" VALUES (177, 'tdsdgt25n85t748h', 'elzydc89l17j043l', 21, true);
INSERT INTO public."Spedizione_Economica" VALUES (179, 'qbdnlf82x70l206u', 'hbbdtl71a93o332r', 37.4, true);
INSERT INTO public."Spedizione_Economica" VALUES (180, 'qnhjhl27o60s734b', 'qbdnlf82x70l206u', 21, true);
INSERT INTO public."Spedizione_Economica" VALUES (182, 'yfbomx14j01i414q', 'ubhgqk91a47l249w', 23, true);
INSERT INTO public."Spedizione_Economica" VALUES (183, 'rhtipe18q96t811w', 'yfbomx14j01i414q', 9.4, true);
INSERT INTO public."Spedizione_Economica" VALUES (184, 'rbmdmz41d86m087i', 'rhtipe18q96t811w', 36.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (187, 'dcfuye94g06f217q', 'fclxnj72q03i675i', 14.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (188, 'sgtzkv15v56p995o', 'dcfuye94g06f217q', 27, true);
INSERT INTO public."Spedizione_Economica" VALUES (189, 'uyheqc53x63q262p', 'sgtzkv15v56p995o', 12.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (195, 'hgbzrh16u63i171y', 'bjblph06j16d245i', 22.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (197, 'mryhnm61j46c350f', 'biyovl42e99y464i', 31.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (198, 'vhoywi16t82l695z', 'mryhnm61j46c350f', 15.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (199, 'ybfysq79y79l393y', 'vhoywi16t82l695z', 24.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (200, 'dtofbi34p99y365o', 'ybfysq79y79l393y', 5.2, true);
INSERT INTO public."Spedizione_Economica" VALUES (202, 'sszezk30j07n929w', 'vljdev57g03y090c', 24.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (204, 'rhoejr57a02m896n', 'ktzici06x98f179v', 21, true);
INSERT INTO public."Spedizione_Economica" VALUES (205, 'xxncni20g41k547d', 'rhoejr57a02m896n', 37.4, true);
INSERT INTO public."Spedizione_Economica" VALUES (206, 'qohrak59c31f972s', 'xxncni20g41k547d', 21, true);
INSERT INTO public."Spedizione_Economica" VALUES (208, 'twaahz52e36j670l', 'diojtz71g09k482b', 23, true);
INSERT INTO public."Spedizione_Economica" VALUES (211, 'gkwlxp24b62o116h', 'dummes59z00c736a', 9.4, true);
INSERT INTO public."Spedizione_Economica" VALUES (213, 'zjdfwr79p98y382c', 'otsesl75v45y509t', 36.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (214, 'xqtndg34u63l734v', 'zjdfwr79p98y382c', 14.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (215, 'mkejzs70t73i858j', 'xqtndg34u63l734v', 27, true);
INSERT INTO public."Spedizione_Economica" VALUES (216, 'vgfuyu57e66b290z', 'mkejzs70t73i858j', 12.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (217, 'qftkaz11f56i050v', 'vgfuyu57e66b290z', 22.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (219, 'ibzags87y19q846t', 'vsovbt06e82k566o', 31.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (220, 'imccnp09o38x381t', 'ibzags87y19q846t', 15.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (222, 'mqejhb39g21s907j', 'qdwjuu36n94c501h', 24.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (225, 'kmzeuu19a52h131r', 'vpfjqd29o36m152p', 5.2, true);
INSERT INTO public."Spedizione_Economica" VALUES (226, 'vvcybr21z15j371t', 'kmzeuu19a52h131r', 24.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (229, 'sfhdna30o52a171q', 'pedxbe91i75m176m', 3, true);
INSERT INTO public."Spedizione_Economica" VALUES (230, 'mkoamp49f47t875o', 'sfhdna30o52a171q', 21, true);
INSERT INTO public."Spedizione_Economica" VALUES (232, 'xlzrzk74e92m608i', 'kqegmg32m29k935w', 37.4, true);
INSERT INTO public."Spedizione_Economica" VALUES (233, 'sonctd56f83b983b', 'xlzrzk74e92m608i', 21, true);
INSERT INTO public."Spedizione_Economica" VALUES (235, 'jijwdf38e90k474z', 'dtwigz64e10p083m', 23, true);
INSERT INTO public."Spedizione_Economica" VALUES (236, 'vanpud49z85p246z', 'jijwdf38e90k474z', 9.4, true);
INSERT INTO public."Spedizione_Economica" VALUES (237, 'mpucqz16x16h338y', 'vanpud49z85p246z', 36.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (240, 'nvjvry06k80y671d', 'xhyhhr51j99t588v', 14.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (241, 'qgirmu64l92v236a', 'nvjvry06k80y671d', 27, true);
INSERT INTO public."Spedizione_Economica" VALUES (242, 'jjnkrf56p52e998v', 'qgirmu64l92v236a', 12.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (248, 'qqlgsj19c62a369o', 'ajidlo43u61p099h', 22.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (250, 'whoxlw51d31i855p', 'xdywvp61j99w442z', 31.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (251, 'jqowvl10i94z886o', 'whoxlw51d31i855p', 15.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (252, 'nzqznh45k76m471w', 'jqowvl10i94z886o', 24.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (253, 'gaflzy22j28d259r', 'nzqznh45k76m471w', 5.2, true);
INSERT INTO public."Spedizione_Economica" VALUES (255, 'iyfais63g07q982h', 'lxeorf85u39l996y', 24.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (257, 'nuztap81a26s855n', 'idurgs16p07z227n', 21, true);
INSERT INTO public."Spedizione_Economica" VALUES (258, 'pkzhol78p03a056s', 'nuztap81a26s855n', 37.4, true);
INSERT INTO public."Spedizione_Economica" VALUES (259, 'rwknhd54x94p737d', 'pkzhol78p03a056s', 21, true);
INSERT INTO public."Spedizione_Economica" VALUES (261, 'lxcpuv90t78u605u', 'bbgcje71p25a045f', 23, true);
INSERT INTO public."Spedizione_Economica" VALUES (262, 'xrbejq26q15p312m', 'lxcpuv90t78u605u', 9.4, true);
INSERT INTO public."Spedizione_Economica" VALUES (264, 'cykmvq17a37o337t', 'gbpmca29b68x702b', 36.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (267, 'biakfr95f91j747v', 'wiygan57q71s213z', 14.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (268, 'zawssc20m93t610i', 'biakfr95f91j747v', 27, true);
INSERT INTO public."Spedizione_Economica" VALUES (271, 'juqqvq79q57c343f', 'vydrwa78d74w280l', 12.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (272, 'rwfaqv29l60p314v', 'juqqvq79q57c343f', 22.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (274, 'krpijq65x88a203e', 'mrnduz12x16z223d', 31.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (275, 'djenxl66m93q807q', 'krpijq65x88a203e', 15.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (277, 'ymcvcx20r05m719x', 'ffivvv85v77v236p', 24.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (278, 'aqlrcu77s93p743t', 'ymcvcx20r05m719x', 5.2, true);
INSERT INTO public."Spedizione_Economica" VALUES (279, 'wfbltk51o88k950q', 'aqlrcu77s93p743t', 24.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (282, 'xfzwro97m90s944f', 'ftvczh65w43l415y', 3, true);
INSERT INTO public."Spedizione_Economica" VALUES (283, 'cuskrn57l47e061a', 'xfzwro97m90s944f', 21, true);
INSERT INTO public."Spedizione_Economica" VALUES (284, 'pvesli24i05o628x', 'cuskrn57l47e061a', 37.4, true);
INSERT INTO public."Spedizione_Economica" VALUES (290, 'hatoqy71b49z740w', 'kwhebi32u53k737a', 21, true);
INSERT INTO public."Spedizione_Economica" VALUES (292, 'tlxmtp31i77i820m', 'dbaiib39k29d734g', 23, true);
INSERT INTO public."Spedizione_Economica" VALUES (293, 'fcopvg30n16c914c', 'tlxmtp31i77i820m', 9.4, true);
INSERT INTO public."Spedizione_Economica" VALUES (294, 'hnqwqq55k83w052b', 'fcopvg30n16c914c', 36.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (46, 'mlnxnc18l24m114u', 'cvjlwx09n81j993j', 14.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (30, 'rcjgxa50z51h696w', 'auaggp09y68t935y', 27, true);
INSERT INTO public."Spedizione_Economica" VALUES (45, 'qssbjx39t46r976n', 'dvqwpq82d12u044j', 12.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (23, 'arllpa74i66y238j', 'tamsxh39j08d107q', 22.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (28, 'abogvl97e41a631n', 'fgceut14h98h226r', 31.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (44, 'mumnbw95f77i705t', 'kjnlji67m42p786g', 15.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (24, 'ikwfcz18b86e682q', 'hhwjqv17k50w410f', 24.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (47, 'bvsues78b56y479m', 'ffdwee60s61t235w', 5.2, true);
INSERT INTO public."Spedizione_Economica" VALUES (14, 'npyljq01s77p500h', 'aunxad02p33x402h', 24.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (21, 'hhwjqv17k50w410f', 'psfiod09k77a681u', 21, true);
INSERT INTO public."Spedizione_Economica" VALUES (41, 'ldaacb32t23p035n', 'kqupzq92g24n430p', 37.4, true);
INSERT INTO public."Spedizione_Economica" VALUES (8, 'ffdwee60s61t235w', 'kjnlji67m42p786g', 21, true);
INSERT INTO public."Spedizione_Economica" VALUES (18, 'psfiod09k77a681u', 'awuyzn61c17c890d', 23, true);
INSERT INTO public."Spedizione_Economica" VALUES (49, 'spjzpv06b62d022v', 'hmozuk35y60c790g', 9.4, true);
INSERT INTO public."Spedizione_Economica" VALUES (43, 'vrrrzs98x58u998j', 'auaggp09y68t935y', 36.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (36, 'qmogjf57a26v287q', 'hmozuk35y60c790g', 14.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (10, 'hmozuk35y60c790g', 'cvjlwx09n81j993j', 27, true);
INSERT INTO public."Spedizione_Economica" VALUES (38, 'kqupzq92g24n430p', 'yiblfs65g56k279q', 12.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (17, 'qabkgx49q61o993x', 'npyljq01s77p500h', 22.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (20, 'tamsxh39j08d107q', 'qabkgx49q61o993x', 31.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (39, 'uajvuh30u29g422t', 'jqkjfd25s12j468w', 15.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (52, 'nxrwjy67e78k983a', 'jqkjfd25s12j468w', 24.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (40, 'fdzdby16w16j502a', 'npyljq01s77p500h', 5.2, true);
INSERT INTO public."Spedizione_Economica" VALUES (55, 'zjjzzm30m46g321h', 'jxkaly72y50r152y', 24.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (56, 'noslzw34u00r539t', 'zjjzzm30m46g321h', 3, true);
INSERT INTO public."Spedizione_Economica" VALUES (57, 'zwmtwz36l77o282r', 'noslzw34u00r539t', 21, true);
INSERT INTO public."Spedizione_Economica" VALUES (58, 'suabnl13o74w031i', 'zwmtwz36l77o282r', 37.4, true);
INSERT INTO public."Spedizione_Economica" VALUES (60, 'wmdpat97i44l686t', 'mcsyrw69k90m893a', 21, true);
INSERT INTO public."Spedizione_Economica" VALUES (61, 'fhgmof18s41j295n', 'wmdpat97i44l686t', 23, true);
INSERT INTO public."Spedizione_Economica" VALUES (63, 'rqjqdp57p76w419r', 'odpsmt51i34p539x', 21, true);
INSERT INTO public."Spedizione_Economica" VALUES (66, 'knqjht86d51o896p', 'fncguy16y09p079o', 23, true);
INSERT INTO public."Spedizione_Economica" VALUES (67, 'oejkvl89k12w562d', 'knqjht86d51o896p', 9.4, true);
INSERT INTO public."Spedizione_Economica" VALUES (70, 'logntb80s01y324k', 'uarkyi38f72r573s', 36.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (5, 'kjnlji67m42p786g', 'biracl27s20m759i', 14.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (4, 'auaggp09y68t935y', 'kqwjjd23e43o622b', 27, true);
INSERT INTO public."Spedizione_Economica" VALUES (25, 'fgceut14h98h226r', 'mfbslr80u19a742g', 12.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (29, 'pqjbjt76t60z084a', 'kqwjjd23e43o622b', 22.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (3, 'kqwjjd23e43o622b', 'biracl27s20m759i', 49.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (7, 'cvjlwx09n81j993j', 'auaggp09y68t935y', 15.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (54, 'trepgg69u19k071g', 'ocwhrd88a63g175v', 5.2, true);
INSERT INTO public."Spedizione_Economica" VALUES (71, 'jahmzo24g76s944w', 'logntb80s01y324k', 24.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (73, 'fqlyin12z06e130g', 'uprujb40t62r387n', 3, true);
INSERT INTO public."Spedizione_Economica" VALUES (74, 'ppzecn38y37d807s', 'fqlyin12z06e130g', 21, true);
INSERT INTO public."Spedizione_Economica" VALUES (76, 'svcxub51l40q691d', 'atbhyp35z83m686a', 37.4, true);
INSERT INTO public."Spedizione_Economica" VALUES (77, 'cqtajq47a97e127a', 'svcxub51l40q691d', 21, true);
INSERT INTO public."Spedizione_Economica" VALUES (78, 'fojscj13f69h621y', 'cqtajq47a97e127a', 21, true);
INSERT INTO public."Spedizione_Economica" VALUES (81, 'manipu71h58q315q', 'pvowth75p53j283m', 23, true);
INSERT INTO public."Spedizione_Economica" VALUES (82, 'nqekjl98o73h568s', 'manipu71h58q315q', 9.4, true);
INSERT INTO public."Spedizione_Economica" VALUES (83, 'bmvllg36p94o834q', 'nqekjl98o73h568s', 36.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (89, 'czywny38u81l971j', 'xztucq61z58m389z', 14.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (91, 'eqikwg97h60x737f', 'uxzgka81u81f900v', 27, true);
INSERT INTO public."Spedizione_Economica" VALUES (92, 'vrvbme37u79s356u', 'eqikwg97h60x737f', 12.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (93, 'ttmofu93i63l613q', 'vrvbme37u79s356u', 22.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (94, 'gdrkbb46q98z701s', 'ttmofu93i63l613q', 31.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (96, 'bqczfk28i17g929z', 'qfszmm89q52l220m', 15.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (97, 'bkzoam73g46m558q', 'bqczfk28i17g929z', 24.6, true);
INSERT INTO public."Spedizione_Economica" VALUES (98, 'stdvsh45d64b133m', 'bkzoam73g46m558q', 5.2, true);
INSERT INTO public."Spedizione_Economica" VALUES (2, 'biracl27s20m759i', 'kqwjjd23e43o622b', 32.8, true);
INSERT INTO public."Spedizione_Economica" VALUES (13, 'jqkjfd25s12j468w', 'hmozuk35y60c790g', 27, true);
INSERT INTO public."Spedizione_Economica" VALUES (256, 'idurgs16p07z227n', 'iyfais63g07q982h', 27, true);


--
-- TOC entry 3622 (class 0 OID 18585)
-- Dependencies: 263
-- Data for Name: Spedizione_Economica_Servizi; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO public."Spedizione_Economica_Servizi" VALUES (2, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (3, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (203, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (130, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (120, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (116, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (124, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (102, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (145, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (100, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (109, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (107, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (113, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (142, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (149, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (147, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (136, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (114, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (105, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (127, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (131, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (146, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (129, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (99, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (295, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (123, 55, 'costoZeroPerProve', 0);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (134, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (111, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (126, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (151, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (119, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (135, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (150, 55, 'costoZeroPerProve', 0);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (144, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (110, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (108, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (152, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (153, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (155, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (158, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (160, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (161, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (162, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (163, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (164, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (166, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (167, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (169, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (172, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (173, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (176, 55, 'costoZeroPerProve', 0);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (177, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (179, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (180, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (182, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (183, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (184, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (187, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (188, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (189, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (195, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (197, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (198, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (199, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (200, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (202, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (204, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (205, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (206, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (208, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (211, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (213, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (214, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (215, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (216, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (217, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (219, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (220, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (222, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (225, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (226, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (229, 55, 'costoZeroPerProve', 0);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (230, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (232, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (233, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (235, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (236, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (237, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (240, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (241, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (242, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (248, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (250, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (251, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (252, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (253, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (255, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (257, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (258, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (259, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (261, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (262, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (264, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (267, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (268, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (271, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (272, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (274, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (275, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (277, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (278, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (279, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (282, 55, 'costoZeroPerProve', 0);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (283, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (284, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (290, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (292, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (293, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (294, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (46, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (30, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (45, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (23, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (28, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (44, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (24, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (47, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (14, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (21, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (41, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (8, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (18, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (49, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (43, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (36, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (10, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (38, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (17, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (20, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (39, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (52, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (40, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (55, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (56, 55, 'costoZeroPerProve', 0);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (57, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (58, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (60, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (61, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (63, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (66, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (67, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (70, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (5, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (4, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (25, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (29, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (3, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (7, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (54, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (71, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (73, 55, 'costoZeroPerProve', 0);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (74, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (76, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (77, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (78, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (81, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (82, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (83, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (89, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (91, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (92, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (93, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (94, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (96, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (97, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (98, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (2, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (13, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Economica_Servizi" VALUES (256, 43, 'FastLaneTransit', 12);


--
-- TOC entry 3623 (class 0 OID 18590)
-- Dependencies: 264
-- Data for Name: Spedizione_Premium; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO public."Spedizione_Premium" VALUES (16, 'qabkgx49q61o993x', 'echxll47x25b400a', 8.26, false);
INSERT INTO public."Spedizione_Premium" VALUES (17, 'psfiod09k77a681u', 'qabkgx49q61o993x', 7.21, false);
INSERT INTO public."Spedizione_Premium" VALUES (22, 'arllpa74i66y238j', 'mfbslr80u19a742g', 11.2, false);
INSERT INTO public."Spedizione_Premium" VALUES (7, 'ffdwee60s61t235w', 'cvjlwx09n81j993j', 12.04, false);
INSERT INTO public."Spedizione_Premium" VALUES (46, 'bvsues78b56y479m', 'mlnxnc18l24m114u', 20.76, true);
INSERT INTO public."Spedizione_Premium" VALUES (591, 'ohdfns51t00g627v', 'afevdp04e21c505z', 13.75, true);
INSERT INTO public."Spedizione_Premium" VALUES (651, 'afaelp22b25y237q', 'nbaifh35s94i306d', 20.96, true);
INSERT INTO public."Spedizione_Premium" VALUES (665, 'icyuxc92z94e999o', 'zdblid66n51o834b', 17.29, true);
INSERT INTO public."Spedizione_Premium" VALUES (15, 'echxll47x25b400a', 'awuyzn61c17c890d', 10.78, false);
INSERT INTO public."Spedizione_Premium" VALUES (491, 'qlgobk65g81v170g', 'ulkeax27i92h915i', 18.85, true);
INSERT INTO public."Spedizione_Premium" VALUES (24, 'fgceut14h98h226r', 'ikwfcz18b86e682q', 7, false);
INSERT INTO public."Spedizione_Premium" VALUES (601, 'cyyifu45e41v238s', 'rvpweg37g63x780l', 19.69, true);
INSERT INTO public."Spedizione_Premium" VALUES (619, 'skiwxa78z69t210g', 'xpcddd79t48w361c', 19.55, true);
INSERT INTO public."Spedizione_Premium" VALUES (544, 'dmjzqd59p11o659o', 'ssiftj66g31y119z', 26.3, true);
INSERT INTO public."Spedizione_Premium" VALUES (643, 'pikcfu27s86f073u', 'lngpge76v27g291n', 24.74, true);
INSERT INTO public."Spedizione_Premium" VALUES (310, 'lvjjgd59d94x491s', 'wqutbg42d49n864u', 19.78, true);
INSERT INTO public."Spedizione_Premium" VALUES (418, 'txiquk01l70j007w', 'mhnwrf04i20e165m', 23.76, true);
INSERT INTO public."Spedizione_Premium" VALUES (221, 'qdwjuu36n94c501h', 'imccnp09o38x381t', 13.91, true);
INSERT INTO public."Spedizione_Premium" VALUES (83, 'bmvllg36p94o834q', 'nqekjl98o73h568s', 12.44, true);
INSERT INTO public."Spedizione_Premium" VALUES (402, 'slmwhe14o82t696q', 'ecoami54p21v881e', 18.8, true);
INSERT INTO public."Spedizione_Premium" VALUES (353, 'cdnvpr44a27s464z', 'tiwuaw40c19x997m', 17.96, true);
INSERT INTO public."Spedizione_Premium" VALUES (330, 'lqnfji78r29w466g', 'lagtql33n53n104g', 23.17, true);
INSERT INTO public."Spedizione_Premium" VALUES (254, 'lxeorf85u39l996y', 'gaflzy22j28d259r', 19.63, true);
INSERT INTO public."Spedizione_Premium" VALUES (352, 'tiwuaw40c19x997m', 'ksjjng76l79z938v', 28.16, true);
INSERT INTO public."Spedizione_Premium" VALUES (110, 'kmqkbq06h76p620e', 'qrrqti26c27x309a', 20.76, true);
INSERT INTO public."Spedizione_Premium" VALUES (311, 'kukbjl22q01s531a', 'lvjjgd59d94x491s', 17.11, true);
INSERT INTO public."Spedizione_Premium" VALUES (389, 'nulsti82t25n734q', 'knwpnh76n28c198c', 23.33, true);
INSERT INTO public."Spedizione_Premium" VALUES (329, 'lagtql33n53n104g', 'wuzuqr03m90r746d', 13, true);
INSERT INTO public."Spedizione_Premium" VALUES (305, 'xfddve83g88c486m', 'nxwquf98b90k316c', 24.38, true);
INSERT INTO public."Spedizione_Premium" VALUES (296, 'bdgvho42a00g362s', 'naxcfe43n87k487q', 20.83, true);
INSERT INTO public."Spedizione_Premium" VALUES (29, 'rcjgxa50z51h696w', 'pqjbjt76t60z084a', 23.4, true);
INSERT INTO public."Spedizione_Premium" VALUES (325, 'eyenlv61m21t993v', 'uwqdhc51p87l159g', 28.61, true);
INSERT INTO public."Spedizione_Premium" VALUES (172, 'uemrug90i48x328u', 'zfvxsj03z02n196y', 29.66, true);
INSERT INTO public."Spedizione_Premium" VALUES (357, 'fegqwm32v83x267h', 'porhvy84b09i382t', 21.18, true);
INSERT INTO public."Spedizione_Premium" VALUES (26, 'moqyaa96b41w621l', 'rbxbrf79f09c376r', 21.88, true);
INSERT INTO public."Spedizione_Premium" VALUES (250, 'whoxlw51d31i855p', 'xdywvp61j99w442z', 14.26, true);
INSERT INTO public."Spedizione_Premium" VALUES (121, 'pqlarh78x95c681u', 'uvrdvu49e76x287b', 21.04, true);
INSERT INTO public."Spedizione_Premium" VALUES (249, 'xdywvp61j99w442z', 'qqlgsj19c62a369o', 23.89, true);
INSERT INTO public."Spedizione_Premium" VALUES (168, 'rqcnxn37i62m459v', 'jhpody16d43r836h', 22.51, true);
INSERT INTO public."Spedizione_Premium" VALUES (111, 'rttpav92c88i986c', 'kmqkbq06h76p620e', 27.61, true);
INSERT INTO public."Spedizione_Premium" VALUES (92, 'vrvbme37u79s356u', 'eqikwg97h60x737f', 18.22, true);
INSERT INTO public."Spedizione_Premium" VALUES (345, 'jvfulu96x84x763y', 'xasayf43w42h467x', 23.1, true);
INSERT INTO public."Spedizione_Premium" VALUES (39, 'fdzdby16w16j502a', 'uajvuh30u29g422t', 13.37, false);
INSERT INTO public."Spedizione_Premium" VALUES (140, 'pnxpbo53j04q846e', 'avixie13a53o156s', 15.17, true);
INSERT INTO public."Spedizione_Premium" VALUES (37, 'kqupzq92g24n430p', 'corzss57a06d644t', 14.54, true);
INSERT INTO public."Spedizione_Premium" VALUES (130, 'yiqulp92v74x523w', 'glwshl40z75c831r', 28.87, true);
INSERT INTO public."Spedizione_Premium" VALUES (109, 'qrrqti26c27x309a', 'yyjqbv01k20u845l', 22.85, true);
INSERT INTO public."Spedizione_Premium" VALUES (443, 'rejrzk24v65g139b', 'kvdahv58k62x642d', 28.16, true);
INSERT INTO public."Spedizione_Premium" VALUES (27, 'abogvl97e41a631n', 'moqyaa96b41w621l', 12.81, false);
INSERT INTO public."Spedizione_Premium" VALUES (223, 'xwwjzo00v04h752d', 'mqejhb39g21s907j', 23.75, true);
INSERT INTO public."Spedizione_Premium" VALUES (234, 'dtwigz64e10p083m', 'sonctd56f83b983b', 10.92, false);
INSERT INTO public."Spedizione_Premium" VALUES (316, 'gdvioy68s73p937c', 'aeuvnp64l72c668r', 20.41, true);
INSERT INTO public."Spedizione_Premium" VALUES (339, 'zfydjk68n10u660n', 'fyesdl93b77q178e', 22.58, true);
INSERT INTO public."Spedizione_Premium" VALUES (449, 'gzewaj59c69u483b', 'sycvaz44l40f023m', 30.06, true);
INSERT INTO public."Spedizione_Premium" VALUES (358, 'izynbo84d65q336r', 'fegqwm32v83x267h', 11.48, false);
INSERT INTO public."Spedizione_Premium" VALUES (383, 'scydrw97y70z667z', 'esaphh68t77x479l', 10.5, false);
INSERT INTO public."Spedizione_Premium" VALUES (252, 'nzqznh45k76m471w', 'jqowvl10i94z886o', 23.72, true);
INSERT INTO public."Spedizione_Premium" VALUES (131, 'lrmqmu58v72g022o', 'yiqulp92v74x523w', 16.61, true);
INSERT INTO public."Spedizione_Premium" VALUES (380, 'pttjec03n88j479e', 'jlvskz98i56n162p', 27.7, true);
INSERT INTO public."Spedizione_Premium" VALUES (462, 'vyjeea85g55s149m', 'rlhxip57i49r194d', 14.47, true);
INSERT INTO public."Spedizione_Premium" VALUES (167, 'jhpody16d43r836h', 'yaclmp50h40v408v', 24.53, true);
INSERT INTO public."Spedizione_Premium" VALUES (141, 'yxocqm21i97q766s', 'pnxpbo53j04q846e', 19.07, true);
INSERT INTO public."Spedizione_Premium" VALUES (362, 'wpuyfq29e69j026f', 'tbgjbc08x86e721k', 15.24, true);
INSERT INTO public."Spedizione_Premium" VALUES (312, 'niovlv39v26f854w', 'kukbjl22q01s531a', 17.31, true);
INSERT INTO public."Spedizione_Premium" VALUES (289, 'kwhebi32u53k737a', 'igtgry79x29q919l', 12.46, false);
INSERT INTO public."Spedizione_Premium" VALUES (346, 'stsjzy35j70y546p', 'jvfulu96x84x763y', 27.18, true);
INSERT INTO public."Spedizione_Premium" VALUES (265, 'mhoecj38j36w784x', 'cykmvq17a37o337t', 12.11, false);
INSERT INTO public."Spedizione_Premium" VALUES (290, 'hatoqy71b49z740w', 'kwhebi32u53k737a', 17.68, true);
INSERT INTO public."Spedizione_Premium" VALUES (413, 'zsorvj58e92g655d', 'alemzf73j20z028u', 22.57, true);
INSERT INTO public."Spedizione_Premium" VALUES (213, 'zjdfwr79p98y382c', 'otsesl75v45y509t', 11.97, false);
INSERT INTO public."Spedizione_Premium" VALUES (307, 'hznhdf48y67b150x', 'awsrho41j56r866f', 12.25, false);
INSERT INTO public."Spedizione_Premium" VALUES (387, 'jnxppz36y70k810k', 'fvyqbg06s80i819y', 10.78, false);
INSERT INTO public."Spedizione_Premium" VALUES (456, 'inlkab22y35r523c', 'olvtnz08k31g479l', 17.05, true);
INSERT INTO public."Spedizione_Premium" VALUES (274, 'krpijq65x88a203e', 'mrnduz12x16z223d', 14.82, true);
INSERT INTO public."Spedizione_Premium" VALUES (216, 'vgfuyu57e66b290z', 'mkejzs70t73i858j', 21.67, true);
INSERT INTO public."Spedizione_Premium" VALUES (211, 'gkwlxp24b62o116h', 'dummes59z00c736a', 16.85, true);
INSERT INTO public."Spedizione_Premium" VALUES (406, 'mmyxlq78y60c639v', 'odlgol57t91v394z', 21.86, true);
INSERT INTO public."Spedizione_Premium" VALUES (45, 'mlnxnc18l24m114u', 'qssbjx39t46r976n', 12.95, false);
INSERT INTO public."Spedizione_Premium" VALUES (367, 'bvzhtv80u41r537e', 'yfordi93z47d950m', 30.64, true);
INSERT INTO public."Spedizione_Premium" VALUES (360, 'pibudt78r16a447a', 'vwpxxv78e93p501z', 13.79, false);
INSERT INTO public."Spedizione_Premium" VALUES (122, 'yacktw57o65u160e', 'pqlarh78x95c681u', 30.43, true);
INSERT INTO public."Spedizione_Premium" VALUES (191, 'fmzpzf28z43j004o', 'mtrzyg07g76q856p', 27.54, true);
INSERT INTO public."Spedizione_Premium" VALUES (242, 'jjnkrf56p52e998v', 'qgirmu64l92v236a', 11.48, false);
INSERT INTO public."Spedizione_Premium" VALUES (157, 'pmxeyj22f79q939a', 'tyksav29f44e812h', 20.76, true);
INSERT INTO public."Spedizione_Premium" VALUES (405, 'odlgol57t91v394z', 'uxwyyw69y67w105g', 12.74, false);
INSERT INTO public."Spedizione_Premium" VALUES (384, 'aihidc26u00q341f', 'scydrw97y70z667z', 10.92, false);
INSERT INTO public."Spedizione_Premium" VALUES (41, 'vmrlhf74f78j242r', 'ldaacb32t23p035n', 20.92, true);
INSERT INTO public."Spedizione_Premium" VALUES (396, 'zkstsc58d44x407x', 'ppbocq78e39u452k', 20.72, true);
INSERT INTO public."Spedizione_Premium" VALUES (144, 'oyyiyv60r36v674q', 'czkdfs79m36y373n', 15.52, true);
INSERT INTO public."Spedizione_Premium" VALUES (376, 'apyxwu54a07y455w', 'lwolgv30o68l904b', 19.21, true);
INSERT INTO public."Spedizione_Premium" VALUES (410, 'ngucfb23c25o683b', 'hjimqc36e57w169x', 21.58, true);
INSERT INTO public."Spedizione_Premium" VALUES (169, 'gjphjf66h01r492f', 'rqcnxn37i62m459v', 18.36, true);
INSERT INTO public."Spedizione_Premium" VALUES (382, 'esaphh68t77x479l', 'iuemjb93v11o917t', 29.52, true);
INSERT INTO public."Spedizione_Premium" VALUES (473, 'hfumzf36g22g747h', 'izdinq84h61h643s', 21.06, true);
INSERT INTO public."Spedizione_Premium" VALUES (170, 'gxpvwa51v91z843a', 'gjphjf66h01r492f', 25.43, true);
INSERT INTO public."Spedizione_Premium" VALUES (404, 'uxwyyw69y67w105g', 'mlqtow03q53i339t', 12.81, false);
INSERT INTO public."Spedizione_Premium" VALUES (190, 'mtrzyg07g76q856p', 'uyheqc53x63q262p', 25.43, true);
INSERT INTO public."Spedizione_Premium" VALUES (23, 'ikwfcz18b86e682q', 'arllpa74i66y238j', 12.6, false);
INSERT INTO public."Spedizione_Premium" VALUES (10, 'aunxad02p33x402h', 'hmozuk35y60c790g', 7.42, false);
INSERT INTO public."Spedizione_Premium" VALUES (6, 'cvjlwx09n81j993j', 'dvqwpq82d12u044j', 12.46, false);
INSERT INTO public."Spedizione_Premium" VALUES (12, 'jqkjfd25s12j468w', 'yiblfs65g56k279q', 7.07, false);
INSERT INTO public."Spedizione_Premium" VALUES (11, 'yiblfs65g56k279q', 'aunxad02p33x402h', 8.61, false);
INSERT INTO public."Spedizione_Premium" VALUES (3, 'auaggp09y68t935y', 'kqwjjd23e43o622b', 13.02, false);
INSERT INTO public."Spedizione_Premium" VALUES (9, 'hmozuk35y60c790g', 'oobxgl21n86l160z', 9.03, false);
INSERT INTO public."Spedizione_Premium" VALUES (14, 'awuyzn61c17c890d', 'npyljq01s77p500h', 7.63, false);
INSERT INTO public."Spedizione_Premium" VALUES (100, 'oouadv87n09g556b', 'luolkp90c45z532q', 12.88, false);
INSERT INTO public."Spedizione_Premium" VALUES (124, 'kzvgsw10w85d287d', 'bqiccb56b92y499z', 11.2, false);
INSERT INTO public."Spedizione_Premium" VALUES (80, 'pvowth75p53j283m', 'tefphy68k12v005m', 12.11, false);
INSERT INTO public."Spedizione_Premium" VALUES (103, 'voysgf92c86v824t', 'yxnaif10d79h861s', 11.48, false);
INSERT INTO public."Spedizione_Premium" VALUES (146, 'njpxey61x79k993r', 'tfebtc60g85i970i', 11.41, false);
INSERT INTO public."Spedizione_Premium" VALUES (91, 'eqikwg97h60x737f', 'uxzgka81u81f900v', 10.57, false);
INSERT INTO public."Spedizione_Premium" VALUES (70, 'logntb80s01y324k', 'uarkyi38f72r573s', 12.95, false);
INSERT INTO public."Spedizione_Premium" VALUES (69, 'uarkyi38f72r573s', 'ftfagh53w89t084w', 13.3, false);
INSERT INTO public."Spedizione_Premium" VALUES (123, 'bqiccb56b92y499z', 'yacktw57o65u160e', 11.13, false);
INSERT INTO public."Spedizione_Premium" VALUES (51, 'nxrwjy67e78k983a', 'ocwhrd88a63g175v', 11.62, false);
INSERT INTO public."Spedizione_Premium" VALUES (171, 'zfvxsj03z02n196y', 'gxpvwa51v91z843a', 12.04, false);
INSERT INTO public."Spedizione_Premium" VALUES (108, 'yyjqbv01k20u845l', 'ffooko46r26z551h', 11.34, false);
INSERT INTO public."Spedizione_Premium" VALUES (61, 'fhgmof18s41j295n', 'wmdpat97i44l686t', 13.86, false);
INSERT INTO public."Spedizione_Premium" VALUES (138, 'ovqwnp69g20s733t', 'nhjzcn29m02x592d', 12.39, false);
INSERT INTO public."Spedizione_Premium" VALUES (165, 'ynosng19p33q308s', 'hpduso80y40u629k', 11.76, false);
INSERT INTO public."Spedizione_Premium" VALUES (291, 'dbaiib39k29d734g', 'hatoqy71b49z740w', 11.62, false);
INSERT INTO public."Spedizione_Premium" VALUES (321, 'kphrev36h15a238y', 'hwvicy98q94a895c', 14.75, true);
INSERT INTO public."Spedizione_Premium" VALUES (475, 'ykvblg18j59n847w', 'rokhme14q44r365l', 8.82, false);
INSERT INTO public."Spedizione_Premium" VALUES (247, 'ajidlo43u61p099h', 'xwtrps80s90o891n', 13.44, false);
INSERT INTO public."Spedizione_Premium" VALUES (237, 'mpucqz16x16h338y', 'vanpud49z85p246z', 12.46, false);
INSERT INTO public."Spedizione_Premium" VALUES (205, 'xxncni20g41k547d', 'rhoejr57a02m896n', 11.48, false);
INSERT INTO public."Spedizione_Premium" VALUES (351, 'ksjjng76l79z938v', 'zrosek95l32p208a', 12.04, false);
INSERT INTO public."Spedizione_Premium" VALUES (278, 'aqlrcu77s93p743t', 'ymcvcx20r05m719x', 13.37, false);
INSERT INTO public."Spedizione_Premium" VALUES (420, 'duuvwb62a67u925b', 'ubkiiv20t25x511g', 10.64, false);
INSERT INTO public."Spedizione_Premium" VALUES (189, 'uyheqc53x63q262p', 'sgtzkv15v56p995o', 12.04, false);
INSERT INTO public."Spedizione_Premium" VALUES (285, 'hescfp63d24r371j', 'pvesli24i05o628x', 11.2, false);
INSERT INTO public."Spedizione_Premium" VALUES (218, 'vsovbt06e82k566o', 'qftkaz11f56i050v', 10.64, false);
INSERT INTO public."Spedizione_Premium" VALUES (364, 'uiklzr48g15x639d', 'iykdnd08g65v463j', 11.34, false);
INSERT INTO public."Spedizione_Premium" VALUES (225, 'kmzeuu19a52h131r', 'vpfjqd29o36m152p', 12.39, false);
INSERT INTO public."Spedizione_Premium" VALUES (324, 'uwqdhc51p87l159g', 'qkibkx39w03u789n', 12.95, false);
INSERT INTO public."Spedizione_Premium" VALUES (313, 'uatgms19s89r462p', 'niovlv39v26f854w', 10.85, false);
INSERT INTO public."Spedizione_Premium" VALUES (217, 'qftkaz11f56i050v', 'vgfuyu57e66b290z', 14, false);
INSERT INTO public."Spedizione_Premium" VALUES (417, 'mhnwrf04i20e165m', 'hiyfze37r31q065s', 10.78, false);
INSERT INTO public."Spedizione_Premium" VALUES (317, 'gcjhcy92g72e134i', 'gdvioy68s73p937c', 12.95, false);
INSERT INTO public."Spedizione_Premium" VALUES (363, 'iykdnd08g65v463j', 'wpuyfq29e69j026f', 10.64, false);
INSERT INTO public."Spedizione_Premium" VALUES (318, 'wrtcwb68k39k579d', 'gcjhcy92g72e134i', 11.55, false);
INSERT INTO public."Spedizione_Premium" VALUES (361, 'tbgjbc08x86e721k', 'pibudt78r16a447a', 11.27, false);
INSERT INTO public."Spedizione_Premium" VALUES (196, 'biyovl42e99y464i', 'hgbzrh16u63i171y', 13.72, false);
INSERT INTO public."Spedizione_Premium" VALUES (282, 'xfzwro97m90s944f', 'ftvczh65w43l415y', 10.64, false);
INSERT INTO public."Spedizione_Premium" VALUES (315, 'aeuvnp64l72c668r', 'khftlv16s49y992m', 10.85, false);
INSERT INTO public."Spedizione_Premium" VALUES (270, 'vydrwa78d74w280l', 'vrlbxm76c74p195v', 13.3, false);
INSERT INTO public."Spedizione_Premium" VALUES (239, 'xhyhhr51j99t588v', 'bvjmam04c45s056z', 13.44, false);
INSERT INTO public."Spedizione_Premium" VALUES (629, 'wbekan72k84k751t', 'xgcdkf00f78o283e', 8.61, false);
INSERT INTO public."Spedizione_Premium" VALUES (660, 'pjmdlb77f82n198l', 'bcuydp17x49a157a', 8.96, false);
INSERT INTO public."Spedizione_Premium" VALUES (509, 'ldvolh68z86t839z', 'woadai55o12v734m', 7.42, false);
INSERT INTO public."Spedizione_Premium" VALUES (536, 'bwgcrg80j60z952d', 'hbbeex67w98b398p', 8.61, false);
INSERT INTO public."Spedizione_Premium" VALUES (510, 'vrcbwn53f83h885p', 'ldvolh68z86t839z', 8.4, false);
INSERT INTO public."Spedizione_Premium" VALUES (490, 'ulkeax27i92h915i', 'riaxye47m06p717k', 8.05, false);
INSERT INTO public."Spedizione_Premium" VALUES (604, 'ibtqts02v87v774z', 'jotyjq63b29u396x', 7.56, false);
INSERT INTO public."Spedizione_Premium" VALUES (656, 'lzngve90z13e311z', 'zvxods62b20v677t', 8.68, false);
INSERT INTO public."Spedizione_Premium" VALUES (588, 'asykos14a99g005u', 'bqeryb85h12e288b', 7.07, false);
INSERT INTO public."Spedizione_Premium" VALUES (537, 'hdzhzn61k44v349x', 'bwgcrg80j60z952d', 8.47, false);
INSERT INTO public."Spedizione_Premium" VALUES (451, 'opablf82b18h419i', 'hbgrck63w31e330g', 12.74, false);
INSERT INTO public."Spedizione_Premium" VALUES (444, 'qpivwa87y25e468o', 'rejrzk24v65g139b', 12.95, false);
INSERT INTO public."Spedizione_Premium" VALUES (446, 'ynpqod02y80v794g', 'owlzke29p19n961a', 12.53, false);
INSERT INTO public."Spedizione_Premium" VALUES (438, 'lzwmkk95z22u505k', 'uilegv36b88z258v', 10.71, false);
INSERT INTO public."Spedizione_Premium" VALUES (467, 'horawi15y87t226p', 'zlqfeu36e42k506v', 12.11, false);
INSERT INTO public."Spedizione_Premium" VALUES (432, 'apfaag54u56a452l', 'yjgxng37x23u723a', 12.25, false);
INSERT INTO public."Spedizione_Premium" VALUES (440, 'itzwyb58k79e957f', 'khnvqe72l87q967u', 13.86, false);
INSERT INTO public."Spedizione_Premium" VALUES (429, 'hzkqjh73f81k762o', 'zxwuth69x56e561d', 10.71, false);
INSERT INTO public."Spedizione_Premium" VALUES (448, 'sycvaz44l40f023m', 'ygwxvj79h90f093i', 13.65, false);
INSERT INTO public."Spedizione_Premium" VALUES (436, 'bmzfjy69f92a623m', 'uvkxaj86z28t312j', 13.09, false);
INSERT INTO public."Spedizione_Premium" VALUES (132, 'fnksxk12z31h894r', 'lrmqmu58v72g022o', 12.74, false);
INSERT INTO public."Spedizione_Premium" VALUES (34, 'pvgfaf41e99l262m', 'tzrppf44x01q376h', 12.11, false);
INSERT INTO public."Spedizione_Premium" VALUES (474, 'rokhme14q44r365l', 'hfumzf36g22g747h', 13.91, true);
INSERT INTO public."Spedizione_Premium" VALUES (96, 'bqczfk28i17g929z', 'qfszmm89q52l220m', 11.27, false);
INSERT INTO public."Spedizione_Premium" VALUES (151, 'cupmtj64w01y897u', 'mqjrqc08j12u791o', 10.78, false);
INSERT INTO public."Spedizione_Premium" VALUES (675, 'gittwg92z66d467x', 'iznhvu37s97b768g', 7.21, false);
INSERT INTO public."Spedizione_Premium" VALUES (64, 'pzgpbd57t39d363s', 'rqjqdp57p76w419r', 12.11, false);
INSERT INTO public."Spedizione_Premium" VALUES (178, 'hbbdtl71a93o332r', 'tdsdgt25n85t748h', 16.64, true);
INSERT INTO public."Spedizione_Premium" VALUES (272, 'rwfaqv29l60p314v', 'juqqvq79q57c343f', 27.68, true);
INSERT INTO public."Spedizione_Premium" VALUES (336, 'ddofvr13t81o964o', 'ncptgj96i29t348q', 19.34, true);
INSERT INTO public."Spedizione_Premium" VALUES (466, 'zlqfeu36e42k506v', 'pznyrv14e65y073o', 18.92, true);
INSERT INTO public."Spedizione_Premium" VALUES (143, 'czkdfs79m36y373n', 'pxhofa55v38m983t', 11.27, false);
INSERT INTO public."Spedizione_Premium" VALUES (201, 'vljdev57g03y090c', 'dtofbi34p99y365o', 19.91, true);
INSERT INTO public."Spedizione_Premium" VALUES (331, 'nykaio89f69v276n', 'lqnfji78r29w466g', 12.6, false);
INSERT INTO public."Spedizione_Premium" VALUES (293, 'fcopvg30n16c914c', 'tlxmtp31i77i820m', 17.66, true);
INSERT INTO public."Spedizione_Premium" VALUES (240, 'nvjvry06k80y671d', 'xhyhhr51j99t588v', 13.16, false);
INSERT INTO public."Spedizione_Premium" VALUES (460, 'zgvtrb42b24y747d', 'shiorv64i27v474n', 15.79, true);
INSERT INTO public."Spedizione_Premium" VALUES (295, 'naxcfe43n87k487q', 'hnqwqq55k83w052b', 22.71, true);
INSERT INTO public."Spedizione_Premium" VALUES (368, 'zdmwue93v95e125w', 'bvzhtv80u41r537e', 18.24, true);
INSERT INTO public."Spedizione_Premium" VALUES (359, 'vwpxxv78e93p501z', 'izynbo84d65q336r', 12.46, false);
INSERT INTO public."Spedizione_Premium" VALUES (428, 'zxwuth69x56e561d', 'dywuuy04i17o578j', 20.3, true);
INSERT INTO public."Spedizione_Premium" VALUES (106, 'lwlbtz06t04n178k', 'xzkpss69s39o118k', 22.88, true);
INSERT INTO public."Spedizione_Premium" VALUES (90, 'uxzgka81u81f900v', 'czywny38u81l971j', 16.29, true);
INSERT INTO public."Spedizione_Premium" VALUES (309, 'wqutbg42d49n864u', 'cywalr05h91d484m', 10.5, false);
INSERT INTO public."Spedizione_Premium" VALUES (375, 'lwolgv30o68l904b', 'wgplnz82i26j138e', 12.95, false);
INSERT INTO public."Spedizione_Premium" VALUES (372, 'rlagag37v44g548h', 'rukqys85i03o655g', 21.37, true);
INSERT INTO public."Spedizione_Premium" VALUES (427, 'dywuuy04i17o578j', 'zhuwhr15r01h823j', 11.34, false);
INSERT INTO public."Spedizione_Premium" VALUES (38, 'uajvuh30u29g422t', 'kqupzq92g24n430p', 28.02, true);
INSERT INTO public."Spedizione_Premium" VALUES (119, 'bajcrv06p71n608e', 'ubukra69q08t009q', 13.51, false);
INSERT INTO public."Spedizione_Premium" VALUES (21, 'mfbslr80u19a742g', 'hhwjqv17k50w410f', 26.3, true);
INSERT INTO public."Spedizione_Premium" VALUES (8, 'oobxgl21n86l160z', 'ffdwee60s61t235w', 22.95, true);
INSERT INTO public."Spedizione_Premium" VALUES (20, 'hhwjqv17k50w410f', 'tamsxh39j08d107q', 12.5, true);
INSERT INTO public."Spedizione_Premium" VALUES (13, 'npyljq01s77p500h', 'jqkjfd25s12j468w', 18.78, true);
INSERT INTO public."Spedizione_Premium" VALUES (18, 'bucims80t97w944z', 'psfiod09k77a681u', 19.07, true);
INSERT INTO public."Spedizione_Premium" VALUES (5, 'dvqwpq82d12u044j', 'kjnlji67m42p786g', 15.1, true);
INSERT INTO public."Spedizione_Premium" VALUES (19, 'tamsxh39j08d107q', 'bucims80t97w944z', 19.2, true);
INSERT INTO public."Spedizione_Premium" VALUES (4, 'kjnlji67m42p786g', 'auaggp09y68t935y', 41.44, true);
INSERT INTO public."Spedizione_Premium" VALUES (2, 'kqwjjd23e43o622b', 'biracl27s20m759i', 27.98, true);
INSERT INTO public."Spedizione_Premium" VALUES (284, 'pvesli24i05o628x', 'cuskrn57l47e061a', 13.51, false);
INSERT INTO public."Spedizione_Premium" VALUES (160, 'onfaqd30q64x811d', 'tgrgre42c92a215k', 28.23, true);
INSERT INTO public."Spedizione_Premium" VALUES (327, 'jzbcls28a49q907j', 'ivxmmi14g70a470t', 10.85, false);
INSERT INTO public."Spedizione_Premium" VALUES (268, 'zawssc20m93t610i', 'biakfr95f91j747v', 13.09, false);
INSERT INTO public."Spedizione_Premium" VALUES (248, 'qqlgsj19c62a369o', 'ajidlo43u61p099h', 11.13, false);
INSERT INTO public."Spedizione_Premium" VALUES (236, 'vanpud49z85p246z', 'jijwdf38e90k474z', 12.04, false);
INSERT INTO public."Spedizione_Premium" VALUES (85, 'edptkz65p01q097k', 'fpgfmz62j53v258b', 16.07, true);
INSERT INTO public."Spedizione_Premium" VALUES (25, 'rbxbrf79f09c376r', 'fgceut14h98h226r', 22.3, true);
INSERT INTO public."Spedizione_Premium" VALUES (74, 'ppzecn38y37d807s', 'fqlyin12z06e130g', 11.76, false);
INSERT INTO public."Spedizione_Premium" VALUES (35, 'qmogjf57a26v287q', 'pvgfaf41e99l262m', 30.78, true);
INSERT INTO public."Spedizione_Premium" VALUES (439, 'khnvqe72l87q967u', 'lzwmkk95z22u505k', 23.58, true);
INSERT INTO public."Spedizione_Premium" VALUES (385, 'fftdia16t21b475s', 'aihidc26u00q341f', 12.67, false);
INSERT INTO public."Spedizione_Premium" VALUES (235, 'jijwdf38e90k474z', 'dtwigz64e10p083m', 23.93, true);
INSERT INTO public."Spedizione_Premium" VALUES (426, 'zhuwhr15r01h823j', 'kchcts01v28p860a', 14, false);
INSERT INTO public."Spedizione_Premium" VALUES (87, 'neuxjk34h13z966f', 'rynjfz64s17v995d', 10.64, false);
INSERT INTO public."Spedizione_Premium" VALUES (343, 'xxkotd24d06f724r', 'ltxtuz97v18e713t', 13.65, false);
INSERT INTO public."Spedizione_Premium" VALUES (79, 'tefphy68k12v005m', 'fojscj13f69h621y', 13.79, false);
INSERT INTO public."Spedizione_Premium" VALUES (390, 'bncffp20r39h983d', 'nulsti82t25n734q', 27.96, true);
INSERT INTO public."Spedizione_Premium" VALUES (332, 'wepwcz48i94b368x', 'nykaio89f69v276n', 10.99, false);
INSERT INTO public."Spedizione_Premium" VALUES (342, 'ltxtuz97v18e713t', 'aejawf83e52u311t', 13.72, false);
INSERT INTO public."Spedizione_Premium" VALUES (94, 'gdrkbb46q98z701s', 'ttmofu93i63l613q', 13.65, false);
INSERT INTO public."Spedizione_Premium" VALUES (36, 'corzss57a06d644t', 'qmogjf57a26v287q', 26.41, true);
INSERT INTO public."Spedizione_Premium" VALUES (105, 'xzkpss69s39o118k', 'wzcyxj90a16i606i', 20.12, true);
INSERT INTO public."Spedizione_Premium" VALUES (258, 'pkzhol78p03a056s', 'nuztap81a26s855n', 13.93, false);
INSERT INTO public."Spedizione_Premium" VALUES (48, 'spjzpv06b62d022v', 'ceecog34d09y094c', 25.86, true);
INSERT INTO public."Spedizione_Premium" VALUES (129, 'glwshl40z75c831r', 'eftbvw91p58g751r', 12.95, false);
INSERT INTO public."Spedizione_Premium" VALUES (31, 'magujx74u13t692j', 'shnnfp42x22u151r', 13.07, true);
INSERT INTO public."Spedizione_Premium" VALUES (319, 'hqugrl00r46y292v', 'wrtcwb68k39k579d', 23.68, true);
INSERT INTO public."Spedizione_Premium" VALUES (337, 'zpkyga71s78b592a', 'ddofvr13t81o964o', 21.25, true);
INSERT INTO public."Spedizione_Premium" VALUES (371, 'rukqys85i03o655g', 'cbpecz68u53r533h', 12.32, false);
INSERT INTO public."Spedizione_Premium" VALUES (210, 'dummes59z00c736a', 'pqbyjh71p95u332w', 11.62, false);
INSERT INTO public."Spedizione_Premium" VALUES (461, 'rlhxip57i49r194d', 'zgvtrb42b24y747d', 11.9, false);
INSERT INTO public."Spedizione_Premium" VALUES (423, 'caztjb38w06e804g', 'tgfcls21b77t413r', 12.18, false);
INSERT INTO public."Spedizione_Premium" VALUES (431, 'yjgxng37x23u723a', 'ngyfvg51u35u829g', 11.83, false);
INSERT INTO public."Spedizione_Premium" VALUES (215, 'mkejzs70t73i858j', 'xqtndg34u63l734v', 14, false);
INSERT INTO public."Spedizione_Premium" VALUES (366, 'yfordi93z47d950m', 'bmvjla65g93v445i', 19.2, true);
INSERT INTO public."Spedizione_Premium" VALUES (53, 'trepgg69u19k071g', 'utoxrt14i21h422h', 10.5, false);
INSERT INTO public."Spedizione_Premium" VALUES (115, 'jliean73w52o867k', 'wmmzpl91s11i675u', 10.99, false);
INSERT INTO public."Spedizione_Premium" VALUES (259, 'rwknhd54x94p737d', 'pkzhol78p03a056s', 12.04, false);
INSERT INTO public."Spedizione_Premium" VALUES (411, 'jcnncy30g29e277m', 'ngucfb23c25o683b', 13.02, false);
INSERT INTO public."Spedizione_Premium" VALUES (356, 'porhvy84b09i382t', 'bwqsww05c26r955r', 13.51, false);
INSERT INTO public."Spedizione_Premium" VALUES (454, 'uqhhnr77c13u853t', 'xvucnq61o81u204r', 17.39, true);
INSERT INTO public."Spedizione_Premium" VALUES (176, 'elzydc89l17j043l', 'wkudqr77e45y324r', 11.41, false);
INSERT INTO public."Spedizione_Premium" VALUES (116, 'baepct56e87a974t', 'jliean73w52o867k', 10.78, false);
INSERT INTO public."Spedizione_Premium" VALUES (59, 'mcsyrw69k90m893a', 'suabnl13o74w031i', 22.82, true);
INSERT INTO public."Spedizione_Premium" VALUES (377, 'eitriv67y12p862u', 'apyxwu54a07y455w', 13.44, false);
INSERT INTO public."Spedizione_Premium" VALUES (378, 'hkuwbk86w12o138c', 'eitriv67y12p862u', 12.81, false);
INSERT INTO public."Spedizione_Premium" VALUES (301, 'zwoqwv41d02z602d', 'qkmoru80d64m261f', 12.67, false);
INSERT INTO public."Spedizione_Premium" VALUES (433, 'ulirgg96w70a400m', 'apfaag54u56a452l', 10.99, false);
INSERT INTO public."Spedizione_Premium" VALUES (464, 'kghtyr25x19w311r', 'ysrwwy48b48m772c', 11.69, false);
INSERT INTO public."Spedizione_Premium" VALUES (118, 'ubukra69q08t009q', 'wlzdfo15l37k921k', 12.6, false);
INSERT INTO public."Spedizione_Premium" VALUES (104, 'wzcyxj90a16i606i', 'voysgf92c86v824t', 16.64, true);
INSERT INTO public."Spedizione_Premium" VALUES (56, 'noslzw34u00r539t', 'zjjzzm30m46g321h', 13.44, false);
INSERT INTO public."Spedizione_Premium" VALUES (226, 'vvcybr21z15j371t', 'kmzeuu19a52h131r', 10.57, false);
INSERT INTO public."Spedizione_Premium" VALUES (243, 'uvykyg86q63m719o', 'jjnkrf56p52e998v', 11.13, false);
INSERT INTO public."Spedizione_Premium" VALUES (280, 'yzrwhf69b44t534k', 'wfbltk51o88k950q', 13.72, false);
INSERT INTO public."Spedizione_Premium" VALUES (260, 'bbgcje71p25a045f', 'rwknhd54x94p737d', 12.46, false);
INSERT INTO public."Spedizione_Premium" VALUES (50, 'ocwhrd88a63g175v', 'pvilho11h32q211g', 21.56, true);
INSERT INTO public."Spedizione_Premium" VALUES (114, 'wmmzpl91s11i675u', 'sxpitw57x28q806x', 12.11, false);
INSERT INTO public."Spedizione_Premium" VALUES (421, 'iaimcp27v09n390o', 'duuvwb62a67u925b', 19, true);
INSERT INTO public."Spedizione_Premium" VALUES (44, 'qssbjx39t46r976n', 'mumnbw95f77i705t', 22.84, true);
INSERT INTO public."Spedizione_Premium" VALUES (397, 'urgaqd87g05s201o', 'zkstsc58d44x407x', 13.79, false);
INSERT INTO public."Spedizione_Premium" VALUES (400, 'hzygug04l86s190x', 'jvpiug74z06q590x', 11.06, false);
INSERT INTO public."Spedizione_Premium" VALUES (416, 'hiyfze37r31q065s', 'ssywbs56x65c294e', 10.78, false);
INSERT INTO public."Spedizione_Premium" VALUES (392, 'nwbwze08u69m283a', 'cvofjy01b89a528k', 11.06, false);
INSERT INTO public."Spedizione_Premium" VALUES (78, 'fojscj13f69h621y', 'cqtajq47a97e127a', 12.46, false);
INSERT INTO public."Spedizione_Premium" VALUES (194, 'bjblph06j16d245i', 'uqzngd89k68o039y', 11.62, false);
INSERT INTO public."Spedizione_Premium" VALUES (186, 'fclxnj72q03i675i', 'inkkug20e93g176d', 11.62, false);
INSERT INTO public."Spedizione_Premium" VALUES (434, 'mqamxl68x56b775i', 'ulirgg96w70a400m', 29.71, true);
INSERT INTO public."Spedizione_Premium" VALUES (40, 'ldaacb32t23p035n', 'fdzdby16w16j502a', 16.54, true);
INSERT INTO public."Spedizione_Premium" VALUES (273, 'mrnduz12x16z223d', 'rwfaqv29l60p314v', 11.34, false);
INSERT INTO public."Spedizione_Premium" VALUES (370, 'cbpecz68u53r533h', 'grdgnl27o09y843s', 13.44, false);
INSERT INTO public."Spedizione_Premium" VALUES (447, 'ygwxvj79h90f093i', 'ynpqod02y80v794g', 13.72, false);
INSERT INTO public."Spedizione_Premium" VALUES (112, 'wgqked19i68a969p', 'rttpav92c88i986c', 26.41, true);
INSERT INTO public."Spedizione_Premium" VALUES (435, 'uvkxaj86z28t312j', 'mqamxl68x56b775i', 19.7, true);
INSERT INTO public."Spedizione_Premium" VALUES (182, 'yfbomx14j01i414q', 'ubhgqk91a47l249w', 22.63, true);
INSERT INTO public."Spedizione_Premium" VALUES (88, 'xztucq61z58m389z', 'neuxjk34h13z966f', 14.96, true);
INSERT INTO public."Spedizione_Premium" VALUES (89, 'czywny38u81l971j', 'xztucq61z58m389z', 22, true);
INSERT INTO public."Spedizione_Premium" VALUES (198, 'vhoywi16t82l695z', 'mryhnm61j46c350f', 21.88, true);
INSERT INTO public."Spedizione_Premium" VALUES (233, 'sonctd56f83b983b', 'xlzrzk74e92m608i', 13.3, false);
INSERT INTO public."Spedizione_Premium" VALUES (469, 'wgrejt00g44h946h', 'whzcvo80i63t341a', 13.79, false);
INSERT INTO public."Spedizione_Premium" VALUES (67, 'oejkvl89k12w562d', 'knqjht86d51o896p', 13.02, false);
INSERT INTO public."Spedizione_Premium" VALUES (322, 'greraz77c43v123w', 'kphrev36h15a238y', 12.18, false);
INSERT INTO public."Spedizione_Premium" VALUES (180, 'qnhjhl27o60s734b', 'qbdnlf82x70l206u', 10.99, false);
INSERT INTO public."Spedizione_Premium" VALUES (66, 'knqjht86d51o896p', 'fncguy16y09p079o', 12.39, false);
INSERT INTO public."Spedizione_Premium" VALUES (471, 'bwnbxs04b67h331p', 'nheeqv31s20m525k', 11.76, false);
INSERT INTO public."Spedizione_Premium" VALUES (229, 'sfhdna30o52a171q', 'pedxbe91i75m176m', 17.82, true);
INSERT INTO public."Spedizione_Premium" VALUES (77, 'cqtajq47a97e127a', 'svcxub51l40q691d', 20.93, true);
INSERT INTO public."Spedizione_Premium" VALUES (232, 'xlzrzk74e92m608i', 'kqegmg32m29k935w', 25.85, true);
INSERT INTO public."Spedizione_Premium" VALUES (261, 'lxcpuv90t78u605u', 'bbgcje71p25a045f', 12.11, false);
INSERT INTO public."Spedizione_Premium" VALUES (412, 'alemzf73j20z028u', 'jcnncy30g29e277m', 13.86, false);
INSERT INTO public."Spedizione_Premium" VALUES (93, 'ttmofu93i63l613q', 'vrvbme37u79s356u', 14.68, true);
INSERT INTO public."Spedizione_Premium" VALUES (347, 'nqwqhn41z22s088t', 'stsjzy35j70y546p', 23.12, true);
INSERT INTO public."Spedizione_Premium" VALUES (281, 'ftvczh65w43l415y', 'yzrwhf69b44t534k', 21.53, true);
INSERT INTO public."Spedizione_Premium" VALUES (68, 'ftfagh53w89t084w', 'oejkvl89k12w562d', 28.05, true);
INSERT INTO public."Spedizione_Premium" VALUES (187, 'dcfuye94g06f217q', 'fclxnj72q03i675i', 12.88, false);
INSERT INTO public."Spedizione_Premium" VALUES (148, 'prhpun26y68n567z', 'ldgpvv83x48q902w', 24, true);
INSERT INTO public."Spedizione_Premium" VALUES (349, 'dpjzqs24p51l454d', 'iyhzuq98f66a904e', 13.93, false);
INSERT INTO public."Spedizione_Premium" VALUES (266, 'wiygan57q71s213z', 'mhoecj38j36w784x', 30.76, true);
INSERT INTO public."Spedizione_Premium" VALUES (323, 'qkibkx39w03u789n', 'greraz77c43v123w', 12.04, false);
INSERT INTO public."Spedizione_Premium" VALUES (147, 'ldgpvv83x48q902w', 'njpxey61x79k993r', 25.51, true);
INSERT INTO public."Spedizione_Premium" VALUES (188, 'sgtzkv15v56p995o', 'dcfuye94g06f217q', 15.3, true);
INSERT INTO public."Spedizione_Premium" VALUES (300, 'qkmoru80d64m261f', 'ygjdou64c73y262u', 10.92, false);
INSERT INTO public."Spedizione_Premium" VALUES (54, 'jxkaly72y50r152y', 'trepgg69u19k071g', 12.6, false);
INSERT INTO public."Spedizione_Premium" VALUES (207, 'diojtz71g09k482b', 'qohrak59c31f972s', 12.39, false);
INSERT INTO public."Spedizione_Premium" VALUES (173, 'hoxjix04w78h052i', 'uemrug90i48x328u', 23.96, true);
INSERT INTO public."Spedizione_Premium" VALUES (137, 'nhjzcn29m02x592d', 'nangdr55z94b355f', 11.34, false);
INSERT INTO public."Spedizione_Premium" VALUES (320, 'hwvicy98q94a895c', 'hqugrl00r46y292v', 23.26, true);
INSERT INTO public."Spedizione_Premium" VALUES (422, 'tgfcls21b77t413r', 'iaimcp27v09n390o', 19.99, true);
INSERT INTO public."Spedizione_Premium" VALUES (195, 'hgbzrh16u63i171y', 'bjblph06j16d245i', 10.57, false);
INSERT INTO public."Spedizione_Premium" VALUES (369, 'grdgnl27o09y843s', 'zdmwue93v95e125w', 20.69, true);
INSERT INTO public."Spedizione_Premium" VALUES (470, 'nheeqv31s20m525k', 'wgrejt00g44h946h', 22.53, true);
INSERT INTO public."Spedizione_Premium" VALUES (334, 'fuvpvc77f80c928n', 'ezkwii39z32c350a', 13.79, false);
INSERT INTO public."Spedizione_Premium" VALUES (208, 'twaahz52e36j670l', 'diojtz71g09k482b', 30.41, true);
INSERT INTO public."Spedizione_Premium" VALUES (156, 'tyksav29f44e812h', 'wqyrsf81o90i239a', 19.9, true);
INSERT INTO public."Spedizione_Premium" VALUES (292, 'tlxmtp31i77i820m', 'dbaiib39k29d734g', 22.92, true);
INSERT INTO public."Spedizione_Premium" VALUES (463, 'ysrwwy48b48m772c', 'vyjeea85g55s149m', 16.14, true);
INSERT INTO public."Spedizione_Premium" VALUES (287, 'tfbepd27f25z456b', 'qkuolt71j22g986z', 13.02, false);
INSERT INTO public."Spedizione_Premium" VALUES (398, 'bkxwen88o85l765g', 'urgaqd87g05s201o', 12.32, false);
INSERT INTO public."Spedizione_Premium" VALUES (245, 'wnfbnc70h73p291z', 'hionfe08j30s838l', 13.79, false);
INSERT INTO public."Spedizione_Premium" VALUES (55, 'zjjzzm30m46g321h', 'jxkaly72y50r152y', 10.78, false);
INSERT INTO public."Spedizione_Premium" VALUES (275, 'djenxl66m93q807q', 'krpijq65x88a203e', 10.92, false);
INSERT INTO public."Spedizione_Premium" VALUES (212, 'otsesl75v45y509t', 'gkwlxp24b62o116h', 13.51, false);
INSERT INTO public."Spedizione_Premium" VALUES (379, 'jlvskz98i56n162p', 'hkuwbk86w12o138c', 13.23, false);
INSERT INTO public."Spedizione_Premium" VALUES (394, 'ejovqv21c74z994c', 'bxhwvl44a40p487p', 12.74, false);
INSERT INTO public."Spedizione_Premium" VALUES (125, 'lsynvw38u84v911t', 'kzvgsw10w85d287d', 11.62, false);
INSERT INTO public."Spedizione_Premium" VALUES (175, 'wkudqr77e45y324r', 'cmtohz05r99b277p', 21.55, true);
INSERT INTO public."Spedizione_Premium" VALUES (209, 'pqbyjh71p95u332w', 'twaahz52e36j670l', 11.97, false);
INSERT INTO public."Spedizione_Premium" VALUES (264, 'cykmvq17a37o337t', 'gbpmca29b68x702b', 30.48, true);
INSERT INTO public."Spedizione_Premium" VALUES (155, 'wqyrsf81o90i239a', 'cpqfoy83x73u061y', 11.55, false);
INSERT INTO public."Spedizione_Premium" VALUES (76, 'svcxub51l40q691d', 'atbhyp35z83m686a', 25.72, true);
INSERT INTO public."Spedizione_Premium" VALUES (214, 'xqtndg34u63l734v', 'zjdfwr79p98y382c', 17.26, true);
INSERT INTO public."Spedizione_Premium" VALUES (199, 'ybfysq79y79l393y', 'vhoywi16t82l695z', 11.34, false);
INSERT INTO public."Spedizione_Premium" VALUES (335, 'ncptgj96i29t348q', 'fuvpvc77f80c928n', 13.44, false);
INSERT INTO public."Spedizione_Premium" VALUES (134, 'luitgk17d02s129y', 'twftbw62l90s058g', 17.53, true);
INSERT INTO public."Spedizione_Premium" VALUES (409, 'hjimqc36e57w169x', 'vvrtat98m61u748i', 12.51, true);
INSERT INTO public."Spedizione_Premium" VALUES (86, 'rynjfz64s17v995d', 'edptkz65p01q097k', 13.86, false);
INSERT INTO public."Spedizione_Premium" VALUES (98, 'stdvsh45d64b133m', 'bkzoam73g46m558q', 21.04, true);
INSERT INTO public."Spedizione_Premium" VALUES (139, 'avixie13a53o156s', 'ovqwnp69g20s733t', 13.44, false);
INSERT INTO public."Spedizione_Premium" VALUES (57, 'zwmtwz36l77o282r', 'noslzw34u00r539t', 11.9, false);
INSERT INTO public."Spedizione_Premium" VALUES (386, 'fvyqbg06s80i819y', 'fftdia16t21b475s', 21.69, true);
INSERT INTO public."Spedizione_Premium" VALUES (163, 'gtylvt32f54w241f', 'qsboqw04w60w823t', 13.86, false);
INSERT INTO public."Spedizione_Premium" VALUES (82, 'nqekjl98o73h568s', 'manipu71h58q315q', 11.62, false);
INSERT INTO public."Spedizione_Premium" VALUES (271, 'juqqvq79q57c343f', 'vydrwa78d74w280l', 16.82, true);
INSERT INTO public."Spedizione_Premium" VALUES (297, 'vfhkee99w33c637c', 'bdgvho42a00g362s', 23.27, true);
INSERT INTO public."Spedizione_Premium" VALUES (399, 'jvpiug74z06q590x', 'bkxwen88o85l765g', 17.26, true);
INSERT INTO public."Spedizione_Premium" VALUES (238, 'bvjmam04c45s056z', 'mpucqz16x16h338y', 13.65, false);
INSERT INTO public."Spedizione_Premium" VALUES (453, 'xvucnq61o81u204r', 'ctpcvo16z19t939o', 13.16, false);
INSERT INTO public."Spedizione_Premium" VALUES (120, 'uvrdvu49e76x287b', 'bajcrv06p71n608e', 12.39, false);
INSERT INTO public."Spedizione_Premium" VALUES (302, 'ekasqk57f23p760q', 'zwoqwv41d02z602d', 23.12, true);
INSERT INTO public."Spedizione_Premium" VALUES (126, 'pfjlhl23k93r751x', 'lsynvw38u84v911t', 11.62, false);
INSERT INTO public."Spedizione_Premium" VALUES (244, 'hionfe08j30s838l', 'uvykyg86q63m719o', 22.77, true);
INSERT INTO public."Spedizione_Premium" VALUES (299, 'ygjdou64c73y262u', 'ehutcz88v97t154b', 12.25, false);
INSERT INTO public."Spedizione_Premium" VALUES (128, 'eftbvw91p58g751r', 'cimkuc40b33g393l', 29.52, true);
INSERT INTO public."Spedizione_Premium" VALUES (28, 'pqjbjt76t60z084a', 'abogvl97e41a631n', 19.78, true);
INSERT INTO public."Spedizione_Premium" VALUES (49, 'pvilho11h32q211g', 'spjzpv06b62d022v', 13.65, false);
INSERT INTO public."Spedizione_Premium" VALUES (32, 'dbhyzt20x58r774v', 'magujx74u13t692j', 15.17, true);
INSERT INTO public."Spedizione_Premium" VALUES (441, 'cxbpdi54i67k361m', 'itzwyb58k79e957f', 30.27, true);
INSERT INTO public."Spedizione_Premium" VALUES (348, 'iyhzuq98f66a904e', 'nqwqhn41z22s088t', 17.73, true);
INSERT INTO public."Spedizione_Premium" VALUES (149, 'ukyykl89k69e756x', 'prhpun26y68n567z', 23.76, true);
INSERT INTO public."Spedizione_Premium" VALUES (200, 'dtofbi34p99y365o', 'ybfysq79y79l393y', 11.27, false);
INSERT INTO public."Spedizione_Premium" VALUES (153, 'gklyzl18k69z892d', 'ltrebm84s57p282x', 10.78, false);
INSERT INTO public."Spedizione_Premium" VALUES (228, 'pedxbe91i75m176m', 'fymicl07g86g311z', 25.08, true);
INSERT INTO public."Spedizione_Premium" VALUES (303, 'tskzol42h43s526q', 'ekasqk57f23p760q', 10.85, false);
INSERT INTO public."Spedizione_Premium" VALUES (391, 'cvofjy01b89a528k', 'bncffp20r39h983d', 11.76, false);
INSERT INTO public."Spedizione_Premium" VALUES (468, 'whzcvo80i63t341a', 'horawi15y87t226p', 14.05, true);
INSERT INTO public."Spedizione_Premium" VALUES (326, 'ivxmmi14g70a470t', 'eyenlv61m21t993v', 13.86, false);
INSERT INTO public."Spedizione_Premium" VALUES (442, 'kvdahv58k62x642d', 'cxbpdi54i67k361m', 13.93, false);
INSERT INTO public."Spedizione_Premium" VALUES (415, 'ssywbs56x65c294e', 'yeidoq87h04v253n', 11.2, false);
INSERT INTO public."Spedizione_Premium" VALUES (113, 'sxpitw57x28q806x', 'wgqked19i68a969p', 19.85, true);
INSERT INTO public."Spedizione_Premium" VALUES (33, 'tzrppf44x01q376h', 'dbhyzt20x58r774v', 23.09, true);
INSERT INTO public."Spedizione_Premium" VALUES (133, 'twftbw62l90s058g', 'fnksxk12z31h894r', 11.2, false);
INSERT INTO public."Spedizione_Premium" VALUES (181, 'ubhgqk91a47l249w', 'qnhjhl27o60s734b', 29.92, true);
INSERT INTO public."Spedizione_Premium" VALUES (162, 'qsboqw04w60w823t', 'hiinuk36j01s143y', 19.41, true);
INSERT INTO public."Spedizione_Premium" VALUES (99, 'luolkp90c45z532q', 'stdvsh45d64b133m', 25.37, true);
INSERT INTO public."Spedizione_Premium" VALUES (185, 'inkkug20e93g176d', 'rbmdmz41d86m087i', 15.51, true);
INSERT INTO public."Spedizione_Premium" VALUES (279, 'wfbltk51o88k950q', 'aqlrcu77s93p743t', 23.8, true);
INSERT INTO public."Spedizione_Premium" VALUES (102, 'yxnaif10d79h861s', 'tiiflh50i08r012k', 26.97, true);
INSERT INTO public."Spedizione_Premium" VALUES (457, 'tibkqi57p42w743o', 'inlkab22y35r523c', 19.63, true);
INSERT INTO public."Spedizione_Premium" VALUES (73, 'fqlyin12z06e130g', 'uprujb40t62r387n', 10.5, false);
INSERT INTO public."Spedizione_Premium" VALUES (127, 'cimkuc40b33g393l', 'pfjlhl23k93r751x', 13.02, false);
INSERT INTO public."Spedizione_Premium" VALUES (202, 'sszezk30j07n929w', 'vljdev57g03y090c', 10.85, false);
INSERT INTO public."Spedizione_Premium" VALUES (328, 'wuzuqr03m90r746d', 'jzbcls28a49q907j', 21.6, true);
INSERT INTO public."Spedizione_Premium" VALUES (224, 'vpfjqd29o36m152p', 'xwwjzo00v04h752d', 11.06, false);
INSERT INTO public."Spedizione_Premium" VALUES (430, 'ngyfvg51u35u829g', 'hzkqjh73f81k762o', 22.58, true);
INSERT INTO public."Spedizione_Premium" VALUES (308, 'cywalr05h91d484m', 'hznhdf48y67b150x', 11.2, false);
INSERT INTO public."Spedizione_Premium" VALUES (403, 'mlqtow03q53i339t', 'slmwhe14o82t696q', 13.86, false);
INSERT INTO public."Spedizione_Premium" VALUES (58, 'suabnl13o74w031i', 'zwmtwz36l77o282r', 28.73, true);
INSERT INTO public."Spedizione_Premium" VALUES (450, 'hbgrck63w31e330g', 'gzewaj59c69u483b', 17.1, true);
INSERT INTO public."Spedizione_Premium" VALUES (197, 'mryhnm61j46c350f', 'biyovl42e99y464i', 12.18, false);
INSERT INTO public."Spedizione_Premium" VALUES (161, 'hiinuk36j01s143y', 'onfaqd30q64x811d', 11.06, false);
INSERT INTO public."Spedizione_Premium" VALUES (395, 'ppbocq78e39u452k', 'ejovqv21c74z994c', 20.44, true);
INSERT INTO public."Spedizione_Premium" VALUES (257, 'nuztap81a26s855n', 'idurgs16p07z227n', 27.67, true);
INSERT INTO public."Spedizione_Premium" VALUES (288, 'igtgry79x29q919l', 'tfbepd27f25z456b', 17.04, true);
INSERT INTO public."Spedizione_Premium" VALUES (304, 'nxwquf98b90k316c', 'tskzol42h43s526q', 23.05, true);
INSERT INTO public."Spedizione_Premium" VALUES (256, 'idurgs16p07z227n', 'iyfais63g07q982h', 12.67, false);
INSERT INTO public."Spedizione_Premium" VALUES (142, 'pxhofa55v38m983t', 'yxocqm21i97q766s', 11.62, false);
INSERT INTO public."Spedizione_Premium" VALUES (227, 'fymicl07g86g311z', 'vvcybr21z15j371t', 21.11, true);
INSERT INTO public."Spedizione_Premium" VALUES (294, 'hnqwqq55k83w052b', 'fcopvg30n16c914c', 28.12, true);
INSERT INTO public."Spedizione_Premium" VALUES (374, 'wgplnz82i26j138e', 'ouqxas01i91i264z', 20.83, true);
INSERT INTO public."Spedizione_Premium" VALUES (445, 'owlzke29p19n961a', 'qpivwa87y25e468o', 20.78, true);
INSERT INTO public."Spedizione_Premium" VALUES (75, 'atbhyp35z83m686a', 'ppzecn38y37d807s', 15.8, true);
INSERT INTO public."Spedizione_Premium" VALUES (314, 'khftlv16s49y992m', 'uatgms19s89r462p', 11.76, false);
INSERT INTO public."Spedizione_Premium" VALUES (183, 'rhtipe18q96t811w', 'yfbomx14j01i414q', 13.02, false);
INSERT INTO public."Spedizione_Premium" VALUES (373, 'ouqxas01i91i264z', 'rlagag37v44g548h', 11.41, false);
INSERT INTO public."Spedizione_Premium" VALUES (42, 'vrrrzs98x58u998j', 'vmrlhf74f78j242r', 15.79, true);
INSERT INTO public."Spedizione_Premium" VALUES (340, 'hynsmy79h38a152r', 'zfydjk68n10u660n', 12.53, false);
INSERT INTO public."Spedizione_Premium" VALUES (381, 'iuemjb93v11o917t', 'pttjec03n88j479e', 25.15, true);
INSERT INTO public."Spedizione_Premium" VALUES (174, 'cmtohz05r99b277p', 'hoxjix04w78h052i', 20.19, true);
INSERT INTO public."Spedizione_Premium" VALUES (338, 'fyesdl93b77q178e', 'zpkyga71s78b592a', 21.3, true);
INSERT INTO public."Spedizione_Premium" VALUES (388, 'knwpnh76n28c198c', 'jnxppz36y70k810k', 12.11, false);
INSERT INTO public."Spedizione_Premium" VALUES (193, 'uqzngd89k68o039y', 'hemeot50m73i573g', 13.23, false);
INSERT INTO public."Spedizione_Premium" VALUES (135, 'xsgrxt24x46l839x', 'luitgk17d02s129y', 20.41, true);
INSERT INTO public."Spedizione_Premium" VALUES (452, 'ctpcvo16z19t939o', 'opablf82b18h419i', 28.33, true);
INSERT INTO public."Spedizione_Premium" VALUES (424, 'sugoqm80w14b879j', 'caztjb38w06e804g', 13.37, false);
INSERT INTO public."Spedizione_Premium" VALUES (344, 'xasayf43w42h467x', 'xxkotd24d06f724r', 21.69, true);
INSERT INTO public."Spedizione_Premium" VALUES (231, 'kqegmg32m29k935w', 'mkoamp49f47t875o', 15.1, true);
INSERT INTO public."Spedizione_Premium" VALUES (458, 'wmwuxq55o01z838q', 'tibkqi57p42w743o', 30.76, true);
INSERT INTO public."Spedizione_Premium" VALUES (253, 'gaflzy22j28d259r', 'nzqznh45k76m471w', 16.54, true);
INSERT INTO public."Spedizione_Premium" VALUES (414, 'yeidoq87h04v253n', 'zsorvj58e92g655d', 24.11, true);
INSERT INTO public."Spedizione_Premium" VALUES (220, 'imccnp09o38x381t', 'ibzags87y19q846t', 11.2, false);
INSERT INTO public."Spedizione_Premium" VALUES (166, 'yaclmp50h40v408v', 'ynosng19p33q308s', 11.34, false);
INSERT INTO public."Spedizione_Premium" VALUES (455, 'olvtnz08k31g479l', 'uqhhnr77c13u853t', 12.95, false);
INSERT INTO public."Spedizione_Premium" VALUES (283, 'cuskrn57l47e061a', 'xfzwro97m90s944f', 12.18, false);
INSERT INTO public."Spedizione_Premium" VALUES (277, 'ymcvcx20r05m719x', 'ffivvv85v77v236p', 23.75, true);
INSERT INTO public."Spedizione_Premium" VALUES (425, 'kchcts01v28p860a', 'sugoqm80w14b879j', 11.27, false);
INSERT INTO public."Spedizione_Premium" VALUES (107, 'ffooko46r26z551h', 'lwlbtz06t04n178k', 10.71, false);
INSERT INTO public."Spedizione_Premium" VALUES (145, 'tfebtc60g85i970i', 'oyyiyv60r36v674q', 19.71, true);
INSERT INTO public."Spedizione_Premium" VALUES (81, 'manipu71h58q315q', 'pvowth75p53j283m', 11.2, false);
INSERT INTO public."Spedizione_Premium" VALUES (72, 'uprujb40t62r387n', 'jahmzo24g76s944w', 12.32, false);
INSERT INTO public."Spedizione_Premium" VALUES (269, 'vrlbxm76c74p195v', 'zawssc20m93t610i', 23.51, true);
INSERT INTO public."Spedizione_Premium" VALUES (63, 'rqjqdp57p76w419r', 'odpsmt51i34p539x', 15.1, true);
INSERT INTO public."Spedizione_Premium" VALUES (60, 'wmdpat97i44l686t', 'mcsyrw69k90m893a', 10.64, false);
INSERT INTO public."Spedizione_Premium" VALUES (276, 'ffivvv85v77v236p', 'djenxl66m93q807q', 12.88, false);
INSERT INTO public."Spedizione_Premium" VALUES (152, 'ltrebm84s57p282x', 'cupmtj64w01y897u', 23.83, true);
INSERT INTO public."Spedizione_Premium" VALUES (117, 'wlzdfo15l37k921k', 'baepct56e87a974t', 11.13, false);
INSERT INTO public."Spedizione_Premium" VALUES (43, 'mumnbw95f77i705t', 'vrrrzs98x58u998j', 13.51, false);
INSERT INTO public."Spedizione_Premium" VALUES (159, 'tgrgre42c92a215k', 'pfbnul72n73x158g', 13.93, false);
INSERT INTO public."Spedizione_Premium" VALUES (95, 'qfszmm89q52l220m', 'gdrkbb46q98z701s', 10.92, false);
INSERT INTO public."Spedizione_Premium" VALUES (251, 'jqowvl10i94z886o', 'whoxlw51d31i855p', 11.69, false);
INSERT INTO public."Spedizione_Premium" VALUES (158, 'pfbnul72n73x158g', 'pmxeyj22f79q939a', 13.02, false);
INSERT INTO public."Spedizione_Premium" VALUES (184, 'rbmdmz41d86m087i', 'rhtipe18q96t811w', 13.51, false);
INSERT INTO public."Spedizione_Premium" VALUES (472, 'izdinq84h61h643s', 'bwnbxs04b67h331p', 12.46, false);
INSERT INTO public."Spedizione_Premium" VALUES (267, 'biakfr95f91j747v', 'wiygan57q71s213z', 30.08, true);
INSERT INTO public."Spedizione_Premium" VALUES (437, 'uilegv36b88z258v', 'bmzfjy69f92a623m', 13.65, false);
INSERT INTO public."Spedizione_Premium" VALUES (354, 'nalblh07s15a394h', 'cdnvpr44a27s464z', 10.78, false);
INSERT INTO public."Spedizione_Premium" VALUES (286, 'qkuolt71j22g986z', 'hescfp63d24r371j', 12.67, false);
INSERT INTO public."Spedizione_Premium" VALUES (306, 'awsrho41j56r866f', 'xfddve83g88c486m', 28.31, true);
INSERT INTO public."Spedizione_Premium" VALUES (62, 'odpsmt51i34p539x', 'fhgmof18s41j295n', 17.59, true);
INSERT INTO public."Spedizione_Premium" VALUES (136, 'nangdr55z94b355f', 'xsgrxt24x46l839x', 13.23, false);
INSERT INTO public."Spedizione_Premium" VALUES (219, 'ibzags87y19q846t', 'vsovbt06e82k566o', 11.83, false);
INSERT INTO public."Spedizione_Premium" VALUES (407, 'rgsyok95g15q355j', 'mmyxlq78y60c639v', 23.45, true);
INSERT INTO public."Spedizione_Premium" VALUES (150, 'mqjrqc08j12u791o', 'ukyykl89k69e756x', 24.87, true);
INSERT INTO public."Spedizione_Premium" VALUES (350, 'zrosek95l32p208a', 'dpjzqs24p51l454d', 20.4, true);
INSERT INTO public."Spedizione_Premium" VALUES (419, 'ubkiiv20t25x511g', 'txiquk01l70j007w', 13.16, false);
INSERT INTO public."Spedizione_Premium" VALUES (298, 'ehutcz88v97t154b', 'vfhkee99w33c637c', 10.78, false);
INSERT INTO public."Spedizione_Premium" VALUES (154, 'cpqfoy83x73u061y', 'gklyzl18k69z892d', 10.92, false);
INSERT INTO public."Spedizione_Premium" VALUES (241, 'qgirmu64l92v236a', 'nvjvry06k80y671d', 12.67, false);
INSERT INTO public."Spedizione_Premium" VALUES (365, 'bmvjla65g93v445i', 'uiklzr48g15x639d', 13.93, false);
INSERT INTO public."Spedizione_Premium" VALUES (192, 'hemeot50m73i573g', 'fmzpzf28z43j004o', 21.6, true);
INSERT INTO public."Spedizione_Premium" VALUES (255, 'iyfais63g07q982h', 'lxeorf85u39l996y', 22.39, true);
INSERT INTO public."Spedizione_Premium" VALUES (262, 'xrbejq26q15p312m', 'lxcpuv90t78u605u', 15.94, true);
INSERT INTO public."Spedizione_Premium" VALUES (341, 'aejawf83e52u311t', 'hynsmy79h38a152r', 28.52, true);
INSERT INTO public."Spedizione_Premium" VALUES (177, 'tdsdgt25n85t748h', 'elzydc89l17j043l', 17.38, true);
INSERT INTO public."Spedizione_Premium" VALUES (65, 'fncguy16y09p079o', 'pzgpbd57t39d363s', 11.27, false);
INSERT INTO public."Spedizione_Premium" VALUES (30, 'shnnfp42x22u151r', 'rcjgxa50z51h696w', 18.03, true);
INSERT INTO public."Spedizione_Premium" VALUES (246, 'xwtrps80s90o891n', 'wnfbnc70h73p291z', 21.49, true);
INSERT INTO public."Spedizione_Premium" VALUES (355, 'bwqsww05c26r955r', 'nalblh07s15a394h', 25.64, true);
INSERT INTO public."Spedizione_Premium" VALUES (222, 'mqejhb39g21s907j', 'qdwjuu36n94c501h', 11.27, false);
INSERT INTO public."Spedizione_Premium" VALUES (206, 'qohrak59c31f972s', 'xxncni20g41k547d', 22.42, true);
INSERT INTO public."Spedizione_Premium" VALUES (203, 'ktzici06x98f179v', 'sszezk30j07n929w', 14.33, true);
INSERT INTO public."Spedizione_Premium" VALUES (263, 'gbpmca29b68x702b', 'xrbejq26q15p312m', 11.41, false);
INSERT INTO public."Spedizione_Premium" VALUES (408, 'vvrtat98m61u748i', 'rgsyok95g15q355j', 22.79, true);
INSERT INTO public."Spedizione_Premium" VALUES (204, 'rhoejr57a02m896n', 'ktzici06x98f179v', 13.86, false);
INSERT INTO public."Spedizione_Premium" VALUES (84, 'fpgfmz62j53v258b', 'bmvllg36p94o834q', 19.57, true);
INSERT INTO public."Spedizione_Premium" VALUES (459, 'shiorv64i27v474n', 'wmwuxq55o01z838q', 20.64, true);
INSERT INTO public."Spedizione_Premium" VALUES (97, 'bkzoam73g46m558q', 'bqczfk28i17g929z', 13.7, true);
INSERT INTO public."Spedizione_Premium" VALUES (393, 'bxhwvl44a40p487p', 'nwbwze08u69m283a', 10.78, false);
INSERT INTO public."Spedizione_Premium" VALUES (71, 'jahmzo24g76s944w', 'logntb80s01y324k', 11.34, false);
INSERT INTO public."Spedizione_Premium" VALUES (333, 'ezkwii39z32c350a', 'wepwcz48i94b368x', 25.51, true);
INSERT INTO public."Spedizione_Premium" VALUES (164, 'hpduso80y40u629k', 'gtylvt32f54w241f', 18.52, true);
INSERT INTO public."Spedizione_Premium" VALUES (47, 'ceecog34d09y094c', 'bvsues78b56y479m', 11.34, false);
INSERT INTO public."Spedizione_Premium" VALUES (401, 'ecoami54p21v881e', 'hzygug04l86s190x', 25.5, true);
INSERT INTO public."Spedizione_Premium" VALUES (101, 'tiiflh50i08r012k', 'oouadv87n09g556b', 11.13, false);
INSERT INTO public."Spedizione_Premium" VALUES (465, 'pznyrv14e65y073o', 'kghtyr25x19w311r', 22.35, true);
INSERT INTO public."Spedizione_Premium" VALUES (179, 'qbdnlf82x70l206u', 'hbbdtl71a93o332r', 12.37, true);
INSERT INTO public."Spedizione_Premium" VALUES (230, 'mkoamp49f47t875o', 'sfhdna30o52a171q', 13.37, false);
INSERT INTO public."Spedizione_Premium" VALUES (775, 'bdjvbi33m53t625z', 'hvndpl50h62o530m', 18.43, true);
INSERT INTO public."Spedizione_Premium" VALUES (785, 'pihtpy79q85i032p', 'kuchaa66p97a446f', 18.55, true);
INSERT INTO public."Spedizione_Premium" VALUES (788, 'vwmcbc15b97d930f', 'bpwfja33i96v369r', 7.07, false);
INSERT INTO public."Spedizione_Premium" VALUES (751, 'qoujvr86k52c518s', 'xvmxtn92n36b382i', 19.83, true);
INSERT INTO public."Spedizione_Premium" VALUES (676, 'mfbvcv67j27n744m', 'gittwg92z66d467x', 8.68, false);
INSERT INTO public."Spedizione_Premium" VALUES (778, 'nudode58l02k544a', 'zxwbwq99l80l428o', 9.03, false);
INSERT INTO public."Spedizione_Premium" VALUES (681, 'ecpgzf37z65c854l', 'nfubre77p83m535l', 18.05, true);
INSERT INTO public."Spedizione_Premium" VALUES (719, 'jdvcph01b40l237u', 'obfynz32p53w166h', 7.98, false);
INSERT INTO public."Spedizione_Premium" VALUES (703, 'hxfyhz76g34c459e', 'ipafqp15a18h244a', 7.63, false);
INSERT INTO public."Spedizione_Premium" VALUES (701, 'wzzcov47j78o537e', 'seuetv47u44n335p', 18.99, true);
INSERT INTO public."Spedizione_Premium" VALUES (677, 'hweubz49l24o935x', 'mfbvcv67j27n744m', 18.68, true);
INSERT INTO public."Spedizione_Premium" VALUES (759, 'nfhxah90f46a395y', 'fdmjxt81t90a612m', 24.67, true);
INSERT INTO public."Spedizione_Premium" VALUES (745, 'tqywah35l92r927k', 'ugaztl54m29k901u', 8.19, false);
INSERT INTO public."Spedizione_Premium" VALUES (694, 'uqmgyx68u80y009b', 'jhlccw43c64k583r', 7.14, false);
INSERT INTO public."Spedizione_Premium" VALUES (784, 'kuchaa66p97a446f', 'bfzdxl39q02f128t', 17.47, true);
INSERT INTO public."Spedizione_Premium" VALUES (732, 'llxyjv39q96r417x', 'ecodwj05p83r038c', 25.25, true);
INSERT INTO public."Spedizione_Premium" VALUES (711, 'mjqpkz49g04d758y', 'bfsurf19x35y922x', 18.22, true);
INSERT INTO public."Spedizione_Premium" VALUES (724, 'uyidwe82n70t137a', 'ohttye54b04b897u', 7.28, false);
INSERT INTO public."Spedizione_Premium" VALUES (739, 'llkhwg02z66j440f', 'khoajt31w93n563n', 7.98, false);
INSERT INTO public."Spedizione_Premium" VALUES (729, 'xngeyr38m79v548p', 'iqakur57c83w463l', 25.02, true);
INSERT INTO public."Spedizione_Premium" VALUES (534, 'eqorej11m60t194q', 'jmjxlh00n92u300n', 9.1, false);
INSERT INTO public."Spedizione_Premium" VALUES (647, 'rfsvkn71a26l304y', 'oqwmus57k63x804d', 8.33, false);
INSERT INTO public."Spedizione_Premium" VALUES (484, 'qnapty89i33c049q', 'sialkh00d96p920i', 12.99, true);
INSERT INTO public."Spedizione_Premium" VALUES (568, 'rhuulw30u78t147w', 'dqnour68u44g210s', 24.48, true);
INSERT INTO public."Spedizione_Premium" VALUES (592, 'gveczo21l43e938z', 'ohdfns51t00g627v', 16.14, true);
INSERT INTO public."Spedizione_Premium" VALUES (715, 'apyysh24a26j005e', 'bomjnq25b90q725w', 16.21, true);
INSERT INTO public."Spedizione_Premium" VALUES (543, 'ssiftj66g31y119z', 'tqqppd29p61m297o', 22.07, true);
INSERT INTO public."Spedizione_Premium" VALUES (584, 'hmujpg26i93u330r', 'wwuzik62p31a377d', 8.75, false);
INSERT INTO public."Spedizione_Premium" VALUES (685, 'vqoktq18k67t847v', 'fmvyhh44b41f640o', 8.26, false);
INSERT INTO public."Spedizione_Premium" VALUES (497, 'qzvsel04w44q253q', 'gcinjy85m76o284r', 7.14, false);
INSERT INTO public."Spedizione_Premium" VALUES (794, 'dsxund34d42t407c', 'ifjogt36j16q247p', 8.75, false);
INSERT INTO public."Spedizione_Premium" VALUES (741, 'kozzbn29q60c719k', 'quvuxp16g89r663l', 13.48, true);
INSERT INTO public."Spedizione_Premium" VALUES (585, 'oqviwu80s05h035z', 'hmujpg26i93u330r', 12.97, true);
INSERT INTO public."Spedizione_Premium" VALUES (593, 'ukjoxm64i53e143f', 'gveczo21l43e938z', 17.64, true);
INSERT INTO public."Spedizione_Premium" VALUES (557, 'gbouok44o32j057t', 'wjiqak87h56e932g', 23.26, true);
INSERT INTO public."Spedizione_Premium" VALUES (538, 'egntdi74r39o485c', 'hdzhzn61k44v349x', 7.35, false);
INSERT INTO public."Spedizione_Premium" VALUES (579, 'gbrbkr56g87g635a', 'lhylwe08j80o191j', 18.15, true);
INSERT INTO public."Spedizione_Premium" VALUES (750, 'xvmxtn92n36b382i', 'lkcnpv28m20l624y', 23.05, true);
INSERT INTO public."Spedizione_Premium" VALUES (552, 'ihgqsk40g36m748g', 'jpzdyp65t38k965w', 8.26, false);
INSERT INTO public."Spedizione_Premium" VALUES (569, 'bptjwu24n05g686j', 'rhuulw30u78t147w', 18.69, true);
INSERT INTO public."Spedizione_Premium" VALUES (500, 'usuttb14j08o865n', 'tzonvf81w29d964g', 16.28, true);
INSERT INTO public."Spedizione_Premium" VALUES (495, 'gvncjo16f80e435h', 'mbmbqy89h61y240s', 8.47, false);
INSERT INTO public."Spedizione_Premium" VALUES (746, 'tqfmrq49q16l282e', 'tqywah35l92r927k', 8.54, false);
INSERT INTO public."Spedizione_Premium" VALUES (559, 'hdshix37s83s495s', 'zatzch37y47z709a', 8.52, true);
INSERT INTO public."Spedizione_Premium" VALUES (659, 'bcuydp17x49a157a', 'klanfs50b40q297g', 7.77, false);
INSERT INTO public."Spedizione_Premium" VALUES (606, 'mstusy89h40u467h', 'npvals07a72i269e', 8.12, false);
INSERT INTO public."Spedizione_Premium" VALUES (476, 'mfrbng21o26k276n', 'ykvblg18j59n847w', 21.51, true);
INSERT INTO public."Spedizione_Premium" VALUES (482, 'phwaxu31m15b938j', 'nhfusr24m70x610v', 8.89, false);
INSERT INTO public."Spedizione_Premium" VALUES (605, 'npvals07a72i269e', 'ibtqts02v87v774z', 12.08, true);
INSERT INTO public."Spedizione_Premium" VALUES (503, 'navcdj18y88m194t', 'uuxnfb50x42p997w', 19.07, true);
INSERT INTO public."Spedizione_Premium" VALUES (764, 'npaasj13w80e840k', 'xqjqsj22s53j343w', 18.12, true);
INSERT INTO public."Spedizione_Premium" VALUES (756, 'jxwrvj41g60x674f', 'xgdlsg09d20j444f', 11.94, true);
INSERT INTO public."Spedizione_Premium" VALUES (752, 'xiumjg34l50p485k', 'qoujvr86k52c518s', 7.14, false);
INSERT INTO public."Spedizione_Premium" VALUES (733, 'uunmbh80e00a440q', 'llxyjv39q96r417x', 7.7, false);
INSERT INTO public."Spedizione_Premium" VALUES (546, 'bhlbze73l66u350d', 'zxpdvq25f01x297f', 18.41, true);
INSERT INTO public."Spedizione_Premium" VALUES (691, 'ghtwsc37j43a961m', 'elnrhz27j17b779c', 13.75, true);
INSERT INTO public."Spedizione_Premium" VALUES (668, 'howecb81u20i898y', 'djoete11x09k809f', 18.5, true);
INSERT INTO public."Spedizione_Premium" VALUES (549, 'cmzzun95i89h633u', 'mkfvlo19m69f141z', 7.42, false);
INSERT INTO public."Spedizione_Premium" VALUES (781, 'zzwqfm68z09f054y', 'lhglnt17c31l069s', 17.05, true);
INSERT INTO public."Spedizione_Premium" VALUES (518, 'wpeunt53q41t289g', 'utejkk23x45s145y', 17.7, true);
INSERT INTO public."Spedizione_Premium" VALUES (595, 'uhwycg93m35w526y', 'mpugjc76l42m611d', 18.22, true);
INSERT INTO public."Spedizione_Premium" VALUES (658, 'klanfs50b40q297g', 'hqsmlq58i17v471q', 8.89, false);
INSERT INTO public."Spedizione_Premium" VALUES (779, 'lgeelp21x54t401o', 'nudode58l02k544a', 18.78, true);
INSERT INTO public."Spedizione_Premium" VALUES (758, 'fdmjxt81t90a612m', 'iaptwh25f49g525c', 9.71, true);
INSERT INTO public."Spedizione_Premium" VALUES (523, 'gmpdjg41s85c745x', 'wjltqm70n02s381l', 8.54, false);
INSERT INTO public."Spedizione_Premium" VALUES (777, 'zxwbwq99l80l428o', 'ffcpim26n71x325n', 25.53, true);
INSERT INTO public."Spedizione_Premium" VALUES (649, 'rhwzay80o42s558w', 'macokn00k08m250l', 7.56, false);
INSERT INTO public."Spedizione_Premium" VALUES (645, 'jfhbjt01l66n806y', 'yarpnl54v88x460c', 8.12, false);
INSERT INTO public."Spedizione_Premium" VALUES (702, 'ipafqp15a18h244a', 'wzzcov47j78o537e', 8.68, false);
INSERT INTO public."Spedizione_Premium" VALUES (608, 'vlypir20b31b592e', 'rpcmio07k15z730z', 7.98, false);
INSERT INTO public."Spedizione_Premium" VALUES (710, 'bfsurf19x35y922x', 'qrrwvf24s55i034r', 7.98, false);
INSERT INTO public."Spedizione_Premium" VALUES (692, 'jkvqvi18x34n809x', 'ghtwsc37j43a961m', 22.77, true);
INSERT INTO public."Spedizione_Premium" VALUES (511, 'ubhmvs80m63r731s', 'vrcbwn53f83h885p', 17.71, true);
INSERT INTO public."Spedizione_Premium" VALUES (524, 'wgsdeu45m51x550z', 'gmpdjg41s85c745x', 14.94, true);
INSERT INTO public."Spedizione_Premium" VALUES (494, 'mbmbqy89h61y240s', 'fcgrhm71d09a266t', 8.96, false);
INSERT INTO public."Spedizione_Premium" VALUES (582, 'enqhcw67x77z834h', 'eiaprm20e01b822l', 25.46, true);
INSERT INTO public."Spedizione_Premium" VALUES (706, 'zaqqfb89l43t744e', 'bxkoad02s65q361g', 8.26, false);
INSERT INTO public."Spedizione_Premium" VALUES (735, 'olsqtg55l98o051j', 'obtvgk59k30k461l', 9.1, false);
INSERT INTO public."Spedizione_Premium" VALUES (723, 'ohttye54b04b897u', 'fkictm54k21c357e', 7.28, false);
INSERT INTO public."Spedizione_Premium" VALUES (565, 'xneehv18f10w732f', 'hmdaox79r82u251l', 8.66, true);
INSERT INTO public."Spedizione_Premium" VALUES (630, 'jguvik15v25f237h', 'wbekan72k84k751t', 19.13, true);
INSERT INTO public."Spedizione_Premium" VALUES (673, 'cnjpmm65o70g783m', 'kvynid63z16f330t', 8.96, false);
INSERT INTO public."Spedizione_Premium" VALUES (502, 'uuxnfb50x42p997w', 'npymbn76d51e227l', 9.1, false);
INSERT INTO public."Spedizione_Premium" VALUES (522, 'wjltqm70n02s381l', 'iwzazo76c40z173j', 17.71, true);
INSERT INTO public."Spedizione_Premium" VALUES (770, 'kdtfcn79s21p612q', 'rlibgl30j46v371y', 16.14, true);
INSERT INTO public."Spedizione_Premium" VALUES (570, 'barlvi05b93x209w', 'bptjwu24n05g686j', 18.43, true);
INSERT INTO public."Spedizione_Premium" VALUES (652, 'mtyqjs84i40a613b', 'afaelp22b25y237q', 7.28, false);
INSERT INTO public."Spedizione_Premium" VALUES (722, 'fkictm54k21c357e', 'auhpxk29v73u922q', 10.41, true);
INSERT INTO public."Spedizione_Premium" VALUES (679, 'zipntx83x58r802s', 'vpzjhh57a31l572a', 24.95, true);
INSERT INTO public."Spedizione_Premium" VALUES (671, 'lgbsfq57s18w797w', 'drvuoj51w00l471z', 8.75, false);
INSERT INTO public."Spedizione_Premium" VALUES (505, 'musdmi33a08v413b', 'cqvzpk85i23q219m', 17.54, true);
INSERT INTO public."Spedizione_Premium" VALUES (492, 'flindu81q13d275b', 'qlgobk65g81v170g', 17.98, true);
INSERT INTO public."Spedizione_Premium" VALUES (765, 'lzxfhf46x39c384y', 'npaasj13w80e840k', 11.04, true);
INSERT INTO public."Spedizione_Premium" VALUES (655, 'zvxods62b20v677t', 'cxpehm82s28b201q', 8.31, true);
INSERT INTO public."Spedizione_Premium" VALUES (498, 'wmpymc97t25y428q', 'qzvsel04w44q253q', 24.53, true);
INSERT INTO public."Spedizione_Premium" VALUES (587, 'bqeryb85h12e288b', 'uehnvf65j77r503u', 11.39, true);
INSERT INTO public."Spedizione_Premium" VALUES (737, 'scsktb20x18x904r', 'hftajy85d40h677v', 8.26, false);
INSERT INTO public."Spedizione_Premium" VALUES (753, 'qcqhug04u68p948h', 'xiumjg34l50p485k', 19.49, true);
INSERT INTO public."Spedizione_Premium" VALUES (749, 'lkcnpv28m20l624y', 'rzimge24f96j698f', 7.84, false);
INSERT INTO public."Spedizione_Premium" VALUES (718, 'obfynz32p53w166h', 'izteil26u86d915e', 18.2, true);
INSERT INTO public."Spedizione_Premium" VALUES (515, 'cyccyp23n61c647l', 'qfyxgs56y06g132x', 22.07, true);
INSERT INTO public."Spedizione_Premium" VALUES (744, 'ugaztl54m29k901u', 'zgbpva26u75t620w', 13.82, true);
INSERT INTO public."Spedizione_Premium" VALUES (642, 'lngpge76v27g291n', 'jxogzd07p33w688t', 19.76, true);
INSERT INTO public."Spedizione_Premium" VALUES (780, 'lhglnt17c31l069s', 'lgeelp21x54t401o', 8.33, false);
INSERT INTO public."Spedizione_Premium" VALUES (709, 'qrrwvf24s55i034r', 'xoldjt13f67k819a', 8.52, true);
INSERT INTO public."Spedizione_Premium" VALUES (713, 'lxbbns09i25h492v', 'wvofbb45r59q816j', 7.07, false);
INSERT INTO public."Spedizione_Premium" VALUES (586, 'uehnvf65j77r503u', 'oqviwu80s05h035z', 17.82, true);
INSERT INTO public."Spedizione_Premium" VALUES (612, 'bnunep49r71w996s', 'ohejlz88u45c196l', 17.89, true);
INSERT INTO public."Spedizione_Premium" VALUES (481, 'nhfusr24m70x610v', 'nfsrws52w24w953b', 7.21, false);
INSERT INTO public."Spedizione_Premium" VALUES (602, 'lofzmh73m50c278v', 'cyyifu45e41v238s', 25.95, true);
INSERT INTO public."Spedizione_Premium" VALUES (615, 'xzsvwo58s10x004x', 'iqwzzu54e82y074l', 8.96, false);
INSERT INTO public."Spedizione_Premium" VALUES (616, 'ffrkdt96a34i688u', 'xzsvwo58s10x004x', 9.03, false);
INSERT INTO public."Spedizione_Premium" VALUES (688, 'shtfay63q77a356p', 'raosmo78h47e378s', 17.33, true);
INSERT INTO public."Spedizione_Premium" VALUES (609, 'aomsdz17v94r468w', 'vlypir20b31b592e', 14.79, true);
INSERT INTO public."Spedizione_Premium" VALUES (485, 'umbayu44q37i955h', 'qnapty89i33c049q', 7.84, false);
INSERT INTO public."Spedizione_Premium" VALUES (577, 'lozcaw07a05l577a', 'zjbrmf42a64e406x', 7.14, false);
INSERT INTO public."Spedizione_Premium" VALUES (693, 'jhlccw43c64k583r', 'jkvqvi18x34n809x', 11.39, true);
INSERT INTO public."Spedizione_Premium" VALUES (664, 'zdblid66n51o834b', 'zfdloy29u91j706j', 13.67, true);
INSERT INTO public."Spedizione_Premium" VALUES (576, 'zjbrmf42a64e406x', 'dkdxql92m73y242m', 24.32, true);
INSERT INTO public."Spedizione_Premium" VALUES (790, 'mqqqmw89j20h581o', 'ardagt65d29l119c', 24.41, true);
INSERT INTO public."Spedizione_Premium" VALUES (786, 'ukoufd29b46x227v', 'pihtpy79q85i032p', 8.89, false);
INSERT INTO public."Spedizione_Premium" VALUES (648, 'macokn00k08m250l', 'rfsvkn71a26l304y', 19.77, true);
INSERT INTO public."Spedizione_Premium" VALUES (696, 'ydlbgc84q68r799c', 'wuxraa79f72p982m', 8.19, false);
INSERT INTO public."Spedizione_Premium" VALUES (682, 'qqfgsc49a12m071h', 'ecpgzf37z65c854l', 18.34, true);
INSERT INTO public."Spedizione_Premium" VALUES (499, 'tzonvf81w29d964g', 'wmpymc97t25y428q', 7.42, false);
INSERT INTO public."Spedizione_Premium" VALUES (622, 'jtupkh52a44o086z', 'alsvgn40t66i741v', 9.1, false);
INSERT INTO public."Spedizione_Premium" VALUES (793, 'ifjogt36j16q247p', 'vwkyvm19a40v432p', 16.49, true);
INSERT INTO public."Spedizione_Premium" VALUES (782, 'dqtpkh21m26b550p', 'zzwqfm68z09f054y', 8.89, false);
INSERT INTO public."Spedizione_Premium" VALUES (633, 'njvypc84o38o790p', 'qbqbdg66p89k390r', 9.36, true);
INSERT INTO public."Spedizione_Premium" VALUES (734, 'obtvgk59k30k461l', 'uunmbh80e00a440q', 7.14, false);
INSERT INTO public."Spedizione_Premium" VALUES (674, 'iznhvu37s97b768g', 'cnjpmm65o70g783m', 17.4, true);
INSERT INTO public."Spedizione_Premium" VALUES (517, 'utejkk23x45s145y', 'xmtxjt99x07q805l', 26.09, true);
INSERT INTO public."Spedizione_Premium" VALUES (548, 'mkfvlo19m69f141z', 'sudvaa64u35a304y', 8.54, false);
INSERT INTO public."Spedizione_Premium" VALUES (670, 'drvuoj51w00l471z', 'enlqky34g04n287q', 9.03, false);
INSERT INTO public."Spedizione_Premium" VALUES (532, 'jlptxn26w04f695l', 'czrdqp51k52n440u', 11.39, true);
INSERT INTO public."Spedizione_Premium" VALUES (571, 'kvxfnu83r92o803j', 'barlvi05b93x209w', 8.19, false);
INSERT INTO public."Spedizione_Premium" VALUES (513, 'cpoilh22e04c436a', 'pzonfv49l79l250m', 7.98, false);
INSERT INTO public."Spedizione_Premium" VALUES (529, 'novrai94y62t466f', 'ukoqtd42w51b987e', 19.84, true);
INSERT INTO public."Spedizione_Premium" VALUES (493, 'fcgrhm71d09a266t', 'flindu81q13d275b', 8.12, false);
INSERT INTO public."Spedizione_Premium" VALUES (624, 'rexwhh02l41h534k', 'rczdsn39i48i476x', 18.48, true);
INSERT INTO public."Spedizione_Premium" VALUES (567, 'dqnour68u44g210s', 'mphqfa89s08b688e', 22.49, true);
INSERT INTO public."Spedizione_Premium" VALUES (562, 'crlzvo43u55v574l', 'tugobv65i01e929x', 8.82, false);
INSERT INTO public."Spedizione_Premium" VALUES (566, 'mphqfa89s08b688e', 'xneehv18f10w732f', 8.75, false);
INSERT INTO public."Spedizione_Premium" VALUES (496, 'gcinjy85m76o284r', 'gvncjo16f80e435h', 7.14, false);
INSERT INTO public."Spedizione_Premium" VALUES (541, 'jvyifm99v90s449y', 'arlbqv46e30w307n', 18.01, true);
INSERT INTO public."Spedizione_Premium" VALUES (721, 'auhpxk29v73u922q', 'ludmcw24p67j143p', 17.33, true);
INSERT INTO public."Spedizione_Premium" VALUES (479, 'viutox10s69i779f', 'kudino54j21s645p', 18.1, true);
INSERT INTO public."Spedizione_Premium" VALUES (504, 'cqvzpk85i23q219m', 'navcdj18y88m194t', 25.25, true);
INSERT INTO public."Spedizione_Premium" VALUES (773, 'xfcicw80r08r100t', 'exgomz68k77t912z', 7.98, false);
INSERT INTO public."Spedizione_Premium" VALUES (766, 'oafbri03z30m987q', 'lzxfhf46x39c384y', 18.75, true);
INSERT INTO public."Spedizione_Premium" VALUES (683, 'wkazon37d86e565m', 'qqfgsc49a12m071h', 12.09, true);
INSERT INTO public."Spedizione_Premium" VALUES (556, 'wjiqak87h56e932g', 'tskfgo62n95y356w', 25.72, true);
INSERT INTO public."Spedizione_Premium" VALUES (480, 'nfsrws52w24w953b', 'viutox10s69i779f', 7.7, false);
INSERT INTO public."Spedizione_Premium" VALUES (506, 'ywwkuo29k57j644j', 'musdmi33a08v413b', 8.89, false);
INSERT INTO public."Spedizione_Premium" VALUES (787, 'bpwfja33i96v369r', 'ukoufd29b46x227v', 7.77, false);
INSERT INTO public."Spedizione_Premium" VALUES (791, 'yugnle53c26d088c', 'mqqqmw89j20h581o', 8.89, false);
INSERT INTO public."Spedizione_Premium" VALUES (620, 'fogxok13p51u595j', 'skiwxa78z69t210g', 12.08, true);
INSERT INTO public."Spedizione_Premium" VALUES (748, 'rzimge24f96j698f', 'bpnyrg47u37p879q', 7.7, false);
INSERT INTO public."Spedizione_Premium" VALUES (768, 'hhbtpk61e61o291a', 'ubfrzb37q77v680p', 22.56, true);
INSERT INTO public."Spedizione_Premium" VALUES (754, 'lqkafs68v35m039d', 'qcqhug04u68p948h', 7.07, false);
INSERT INTO public."Spedizione_Premium" VALUES (520, 'vuntfo60q79j268u', 'rfadlz54k36p085m', 18.08, true);
INSERT INTO public."Spedizione_Premium" VALUES (795, 'ctlvfg39x09m076x', 'dsxund34d42t407c', 19.62, true);
INSERT INTO public."Spedizione_Premium" VALUES (533, 'jmjxlh00n92u300n', 'jlptxn26w04f695l', 7.42, false);
INSERT INTO public."Spedizione_Premium" VALUES (646, 'oqwmus57k63x804d', 'jfhbjt01l66n806y', 8.54, false);
INSERT INTO public."Spedizione_Premium" VALUES (545, 'zxpdvq25f01x297f', 'dmjzqd59p11o659o', 7.84, false);
INSERT INTO public."Spedizione_Premium" VALUES (698, 'zrdncd83h87c914c', 'kwjsje79m04i279d', 26.16, true);
INSERT INTO public."Spedizione_Premium" VALUES (774, 'hvndpl50h62o530m', 'xfcicw80r08r100t', 16.56, true);
INSERT INTO public."Spedizione_Premium" VALUES (583, 'wwuzik62p31a377d', 'enqhcw67x77z834h', 7.14, false);
INSERT INTO public."Spedizione_Premium" VALUES (631, 'yeaolb30q53w012k', 'jguvik15v25f237h', 7.7, false);
INSERT INTO public."Spedizione_Premium" VALUES (772, 'exgomz68k77t912z', 'fristt67s63j409v', 26, true);
INSERT INTO public."Spedizione_Premium" VALUES (747, 'bpnyrg47u37p879q', 'tqfmrq49q16l282e', 7.42, false);
INSERT INTO public."Spedizione_Premium" VALUES (596, 'rdkibo76h59u110y', 'uhwycg93m35w526y', 20.96, true);
INSERT INTO public."Spedizione_Premium" VALUES (623, 'rczdsn39i48i476x', 'jtupkh52a44o086z', 12.92, true);
INSERT INTO public."Spedizione_Premium" VALUES (594, 'mpugjc76l42m611d', 'ukjoxm64i53e143f', 18.62, true);
INSERT INTO public."Spedizione_Premium" VALUES (707, 'bihrha68t94f578n', 'zaqqfb89l43t744e', 8.4, false);
INSERT INTO public."Spedizione_Premium" VALUES (720, 'ludmcw24p67j143p', 'jdvcph01b40l237u', 7.63, false);
INSERT INTO public."Spedizione_Premium" VALUES (547, 'sudvaa64u35a304y', 'bhlbze73l66u350d', 18.85, true);
INSERT INTO public."Spedizione_Premium" VALUES (550, 'llvxkg42o89c286h', 'cmzzun95i89h633u', 9.15, true);
INSERT INTO public."Spedizione_Premium" VALUES (653, 'basecz30j50w498g', 'mtyqjs84i40a613b', 19.2, true);
INSERT INTO public."Spedizione_Premium" VALUES (639, 'bnynff06n90z005d', 'jbmcux55d48d822v', 16.91, true);
INSERT INTO public."Spedizione_Premium" VALUES (783, 'bfzdxl39q02f128t', 'dqtpkh21m26b550p', 25.32, true);
INSERT INTO public."Spedizione_Premium" VALUES (564, 'hmdaox79r82u251l', 'puyeld92x63g173x', 17.12, true);
INSERT INTO public."Spedizione_Premium" VALUES (553, 'yltvxh79l69n942y', 'ihgqsk40g36m748g', 17.42, true);
INSERT INTO public."Spedizione_Premium" VALUES (561, 'tugobv65i01e929x', 'spzxsw68j24x233l', 8.61, false);
INSERT INTO public."Spedizione_Premium" VALUES (661, 'xmdgjw84o94h380n', 'pjmdlb77f82n198l', 8.68, false);
INSERT INTO public."Spedizione_Premium" VALUES (558, 'zatzch37y47z709a', 'gbouok44o32j057t', 13.6, true);
INSERT INTO public."Spedizione_Premium" VALUES (686, 'cdqmve04q28n325e', 'vqoktq18k67t847v', 19.63, true);
INSERT INTO public."Spedizione_Premium" VALUES (792, 'vwkyvm19a40v432p', 'yugnle53c26d088c', 9.71, true);
INSERT INTO public."Spedizione_Premium" VALUES (666, 'kwojjj12m53p793k', 'icyuxc92z94e999o', 13.06, true);
INSERT INTO public."Spedizione_Premium" VALUES (680, 'nfubre77p83m535l', 'zipntx83x58r802s', 17.29, true);
INSERT INTO public."Spedizione_Premium" VALUES (581, 'eiaprm20e01b822l', 'vamjmf47o58j777w', 22.91, true);
INSERT INTO public."Spedizione_Premium" VALUES (514, 'qfyxgs56y06g132x', 'cpoilh22e04c436a', 14.52, true);
INSERT INTO public."Spedizione_Premium" VALUES (512, 'pzonfv49l79l250m', 'ubhmvs80m63r731s', 17.87, true);
INSERT INTO public."Spedizione_Premium" VALUES (638, 'jbmcux55d48d822v', 'odfwld70g83z476n', 16.07, true);
INSERT INTO public."Spedizione_Premium" VALUES (507, 'brvmpm92v06z950b', 'ywwkuo29k57j644j', 24.97, true);
INSERT INTO public."Spedizione_Premium" VALUES (725, 'mdctpl49j81y925j', 'uyidwe82n70t137a', 17.33, true);
INSERT INTO public."Spedizione_Premium" VALUES (554, 'nphdhh80r81g345u', 'yltvxh79l69n942y', 7.35, false);
INSERT INTO public."Spedizione_Premium" VALUES (603, 'jotyjq63b29u396x', 'lofzmh73m50c278v', 8.61, false);
INSERT INTO public."Spedizione_Premium" VALUES (699, 'jkbajd67f27m061r', 'zrdncd83h87c914c', 8.33, false);
INSERT INTO public."Spedizione_Premium" VALUES (539, 'rvbptx01k67h766t', 'egntdi74r39o485c', 13.46, true);
INSERT INTO public."Spedizione_Premium" VALUES (632, 'qbqbdg66p89k390r', 'yeaolb30q53w012k', 20.26, true);
INSERT INTO public."Spedizione_Premium" VALUES (578, 'lhylwe08j80o191j', 'lozcaw07a05l577a', 11.94, true);
INSERT INTO public."Spedizione_Premium" VALUES (657, 'hqsmlq58i17v471q', 'lzngve90z13e311z', 18.34, true);
INSERT INTO public."Spedizione_Premium" VALUES (757, 'iaptwh25f49g525c', 'jxwrvj41g60x674f', 7.21, false);
INSERT INTO public."Spedizione_Premium" VALUES (636, 'qjcmuu79f39d249a', 'zkqxgz07n36z490p', 13.82, true);
INSERT INTO public."Spedizione_Premium" VALUES (742, 'xnfktv82w33f454u', 'kozzbn29q60c719k', 8.54, false);
INSERT INTO public."Spedizione_Premium" VALUES (625, 'xguxqy59d50k854a', 'rexwhh02l41h534k', 10.2, true);
INSERT INTO public."Spedizione_Premium" VALUES (617, 'qegtmj78x01k882t', 'ffrkdt96a34i688u', 16.63, true);
INSERT INTO public."Spedizione_Premium" VALUES (599, 'thshsv16v73p624d', 'gkhklj82m85l361x', 7.63, false);
INSERT INTO public."Spedizione_Premium" VALUES (672, 'kvynid63z16f330t', 'lgbsfq57s18w797w', 20.19, true);
INSERT INTO public."Spedizione_Premium" VALUES (627, 'jjpbfu28v46m598f', 'usilzk69c81t096c', 8.96, false);
INSERT INTO public."Spedizione_Premium" VALUES (705, 'bxkoad02s65q361g', 'mqjihf78t38p027v', 14.59, true);
INSERT INTO public."Spedizione_Premium" VALUES (489, 'riaxye47m06p717k', 'ggcmdj63y57b069x', 8.82, false);
INSERT INTO public."Spedizione_Premium" VALUES (628, 'xgcdkf00f78o283e', 'jjpbfu28v46m598f', 7.42, false);
INSERT INTO public."Spedizione_Premium" VALUES (789, 'ardagt65d29l119c', 'vwmcbc15b97d930f', 7.07, false);
INSERT INTO public."Spedizione_Premium" VALUES (650, 'nbaifh35s94i306d', 'rhwzay80o42s558w', 7.49, false);
INSERT INTO public."Spedizione_Premium" VALUES (575, 'dkdxql92m73y242m', 'ufkqrn44n72b177n', 7.49, false);
INSERT INTO public."Spedizione_Premium" VALUES (635, 'zkqxgz07n36z490p', 'voslye64y98a963z', 26.3, true);
INSERT INTO public."Spedizione_Premium" VALUES (551, 'jpzdyp65t38k965w', 'llvxkg42o89c286h', 8.19, false);
INSERT INTO public."Spedizione_Premium" VALUES (738, 'khoajt31w93n563n', 'scsktb20x18x904r', 8.75, false);
INSERT INTO public."Spedizione_Premium" VALUES (730, 'annecp02r49p479y', 'xngeyr38m79v548p', 7.77, false);
INSERT INTO public."Spedizione_Premium" VALUES (610, 'ekdixj40p79r986k', 'aomsdz17v94r468w', 8.54, false);
INSERT INTO public."Spedizione_Premium" VALUES (714, 'bomjnq25b90q725w', 'lxbbns09i25h492v', 17.15, true);
INSERT INTO public."Spedizione_Premium" VALUES (597, 'prjasj98x82r650m', 'rdkibo76h59u110y', 24.32, true);
INSERT INTO public."Spedizione_Premium" VALUES (572, 'msgzxc65z84l783v', 'kvxfnu83r92o803j', 14.65, true);
INSERT INTO public."Spedizione_Premium" VALUES (644, 'yarpnl54v88x460c', 'pikcfu27s86f073u', 7.14, false);
INSERT INTO public."Spedizione_Premium" VALUES (573, 'bojbbg69p36r021b', 'msgzxc65z84l783v', 14.52, true);
INSERT INTO public."Spedizione_Premium" VALUES (519, 'rfadlz54k36p085m', 'wpeunt53q41t289g', 8.96, false);
INSERT INTO public."Spedizione_Premium" VALUES (477, 'bbkshw81f04m459q', 'mfrbng21o26k276n', 8.54, false);
INSERT INTO public."Spedizione_Premium" VALUES (530, 'odbnpx95k95p433r', 'novrai94y62t466f', 7.21, false);
INSERT INTO public."Spedizione_Premium" VALUES (528, 'ukoqtd42w51b987e', 'lulhsf09p30x463l', 14.3, true);
INSERT INTO public."Spedizione_Premium" VALUES (684, 'fmvyhh44b41f640o', 'wkazon37d86e565m', 20.12, true);
INSERT INTO public."Spedizione_Premium" VALUES (769, 'rlibgl30j46v371y', 'hhbtpk61e61o291a', 7.14, false);
INSERT INTO public."Spedizione_Premium" VALUES (563, 'puyeld92x63g173x', 'crlzvo43u55v574l', 8.96, false);
INSERT INTO public."Spedizione_Premium" VALUES (690, 'elnrhz27j17b779c', 'tohydz28a51e989f', 10.06, true);
INSERT INTO public."Spedizione_Premium" VALUES (580, 'vamjmf47o58j777w', 'gbrbkr56g87g635a', 8.82, false);
INSERT INTO public."Spedizione_Premium" VALUES (626, 'usilzk69c81t096c', 'xguxqy59d50k854a', 16.84, true);
INSERT INTO public."Spedizione_Premium" VALUES (486, 'riwurq23j31u866w', 'umbayu44q37i955h', 17.14, true);
INSERT INTO public."Spedizione_Premium" VALUES (641, 'jxogzd07p33w688t', 'qieing39s21x343v', 8.89, false);
INSERT INTO public."Spedizione_Premium" VALUES (762, 'wrzhwr12v35v469v', 'qxfswq15q34k908d', 7.63, false);
INSERT INTO public."Spedizione_Premium" VALUES (687, 'raosmo78h47e378s', 'cdqmve04q28n325e', 10.55, true);
INSERT INTO public."Spedizione_Premium" VALUES (487, 'jpzeyo97v76g588z', 'riwurq23j31u866w', 7.77, false);
INSERT INTO public."Spedizione_Premium" VALUES (501, 'npymbn76d51e227l', 'usuttb14j08o865n', 8.33, false);
INSERT INTO public."Spedizione_Premium" VALUES (555, 'tskfgo62n95y356w', 'nphdhh80r81g345u', 19.83, true);
INSERT INTO public."Spedizione_Premium" VALUES (736, 'hftajy85d40h677v', 'olsqtg55l98o051j', 17.68, true);
INSERT INTO public."Spedizione_Premium" VALUES (689, 'tohydz28a51e989f', 'shtfay63q77a356p', 20.82, true);
INSERT INTO public."Spedizione_Premium" VALUES (600, 'rvpweg37g63x780l', 'thshsv16v73p624d', 8.82, false);
INSERT INTO public."Spedizione_Premium" VALUES (767, 'ubfrzb37q77v680p', 'oafbri03z30m987q', 13.32, true);
INSERT INTO public."Spedizione_Premium" VALUES (695, 'wuxraa79f72p982m', 'uqmgyx68u80y009b', 7.63, false);
INSERT INTO public."Spedizione_Premium" VALUES (640, 'qieing39s21x343v', 'bnynff06n90z005d', 8.61, false);
INSERT INTO public."Spedizione_Premium" VALUES (731, 'ecodwj05p83r038c', 'annecp02r49p479y', 14.45, true);
INSERT INTO public."Spedizione_Premium" VALUES (708, 'xoldjt13f67k819a', 'bihrha68t94f578n', 18.22, true);
INSERT INTO public."Spedizione_Premium" VALUES (560, 'spzxsw68j24x233l', 'hdshix37s83s495s', 8.47, false);
INSERT INTO public."Spedizione_Premium" VALUES (727, 'uaduog26g70k466x', 'bkijhc32p77m782y', 8.05, false);
INSERT INTO public."Spedizione_Premium" VALUES (611, 'ohejlz88u45c196l', 'ekdixj40p79r986k', 15.15, true);
INSERT INTO public."Spedizione_Premium" VALUES (618, 'xpcddd79t48w361c', 'qegtmj78x01k882t', 24.46, true);
INSERT INTO public."Spedizione_Premium" VALUES (607, 'rpcmio07k15z730z', 'mstusy89h40u467h', 17.94, true);
INSERT INTO public."Spedizione_Premium" VALUES (704, 'mqjihf78t38p027v', 'hxfyhz76g34c459e', 13.88, true);
INSERT INTO public."Spedizione_Premium" VALUES (531, 'czrdqp51k52n440u', 'odbnpx95k95p433r', 8.75, false);
INSERT INTO public."Spedizione_Premium" VALUES (590, 'afevdp04e21c505z', 'tcpmoo96v73g834i', 7.84, false);
INSERT INTO public."Spedizione_Premium" VALUES (728, 'iqakur57c83w463l', 'uaduog26g70k466x', 12.71, true);
INSERT INTO public."Spedizione_Premium" VALUES (771, 'fristt67s63j409v', 'kdtfcn79s21p612q', 9.29, true);
INSERT INTO public."Spedizione_Premium" VALUES (743, 'zgbpva26u75t620w', 'xnfktv82w33f454u', 8.05, false);
INSERT INTO public."Spedizione_Premium" VALUES (740, 'quvuxp16g89r663l', 'llkhwg02z66j440f', 11.25, true);
INSERT INTO public."Spedizione_Premium" VALUES (614, 'iqwzzu54e82y074l', 'zpddfs28s55o436w', 13.6, true);
INSERT INTO public."Spedizione_Premium" VALUES (669, 'enlqky34g04n287q', 'howecb81u20i898y', 14.66, true);
INSERT INTO public."Spedizione_Premium" VALUES (716, 'moesxu49c71g977y', 'apyysh24a26j005e', 25.65, true);
INSERT INTO public."Spedizione_Premium" VALUES (634, 'voslye64y98a963z', 'njvypc84o38o790p', 18.05, true);
INSERT INTO public."Spedizione_Premium" VALUES (663, 'zfdloy29u91j706j', 'hmsgpt01d84g745h', 17.33, true);
INSERT INTO public."Spedizione_Premium" VALUES (637, 'odfwld70g83z476n', 'qjcmuu79f39d249a', 18.5, true);
INSERT INTO public."Spedizione_Premium" VALUES (697, 'kwjsje79m04i279d', 'ydlbgc84q68r799c', 8.75, false);
INSERT INTO public."Spedizione_Premium" VALUES (478, 'kudino54j21s645p', 'bbkshw81f04m459q', 9.03, false);
INSERT INTO public."Spedizione_Premium" VALUES (761, 'qxfswq15q34k908d', 'fsswlb51h22r336m', 8.33, false);
INSERT INTO public."Spedizione_Premium" VALUES (542, 'tqqppd29p61m297o', 'jvyifm99v90s449y', 18.29, true);
INSERT INTO public."Spedizione_Premium" VALUES (521, 'iwzazo76c40z173j', 'vuntfo60q79j268u', 8.82, false);
INSERT INTO public."Spedizione_Premium" VALUES (776, 'ffcpim26n71x325n', 'bdjvbi33m53t625z', 17.89, true);
INSERT INTO public."Spedizione_Premium" VALUES (540, 'arlbqv46e30w307n', 'rvbptx01k67h766t', 11.95, true);
INSERT INTO public."Spedizione_Premium" VALUES (760, 'fsswlb51h22r336m', 'nfhxah90f46a395y', 18.48, true);
INSERT INTO public."Spedizione_Premium" VALUES (589, 'tcpmoo96v73g834i', 'asykos14a99g005u', 9.03, false);
INSERT INTO public."Spedizione_Premium" VALUES (717, 'izteil26u86d915e', 'moesxu49c71g977y', 12.71, true);
INSERT INTO public."Spedizione_Premium" VALUES (726, 'bkijhc32p77m782y', 'mdctpl49j81y925j', 9.1, false);
INSERT INTO public."Spedizione_Premium" VALUES (516, 'xmtxjt99x07q805l', 'cyccyp23n61c647l', 9.85, true);
INSERT INTO public."Spedizione_Premium" VALUES (700, 'seuetv47u44n335p', 'jkbajd67f27m061r', 18.61, true);
INSERT INTO public."Spedizione_Premium" VALUES (483, 'sialkh00d96p920i', 'phwaxu31m15b938j', 15.08, true);
INSERT INTO public."Spedizione_Premium" VALUES (654, 'cxpehm82s28b201q', 'basecz30j50w498g', 7.56, false);
INSERT INTO public."Spedizione_Premium" VALUES (621, 'alsvgn40t66i741v', 'fogxok13p51u595j', 18.34, true);
INSERT INTO public."Spedizione_Premium" VALUES (712, 'wvofbb45r59q816j', 'mjqpkz49g04d758y', 11.81, true);
INSERT INTO public."Spedizione_Premium" VALUES (662, 'hmsgpt01d84g745h', 'xmdgjw84o94h380n', 18.36, true);
INSERT INTO public."Spedizione_Premium" VALUES (755, 'xgdlsg09d20j444f', 'lqkafs68v35m039d', 7.14, false);
INSERT INTO public."Spedizione_Premium" VALUES (574, 'ufkqrn44n72b177n', 'bojbbg69p36r021b', 18.64, true);
INSERT INTO public."Spedizione_Premium" VALUES (488, 'ggcmdj63y57b069x', 'jpzeyo97v76g588z', 9.1, false);
INSERT INTO public."Spedizione_Premium" VALUES (613, 'zpddfs28s55o436w', 'bnunep49r71w996s', 21.72, true);
INSERT INTO public."Spedizione_Premium" VALUES (678, 'vpzjhh57a31l572a', 'hweubz49l24o935x', 9.1, false);
INSERT INTO public."Spedizione_Premium" VALUES (527, 'lulhsf09p30x463l', 'wgsdeu45m51x550z', 8.94, true);
INSERT INTO public."Spedizione_Premium" VALUES (535, 'hbbeex67w98b398p', 'eqorej11m60t194q', 7.07, false);
INSERT INTO public."Spedizione_Premium" VALUES (667, 'djoete11x09k809f', 'kwojjj12m53p793k', 8.33, false);
INSERT INTO public."Spedizione_Premium" VALUES (508, 'woadai55o12v734m', 'brvmpm92v06z950b', 18.71, true);
INSERT INTO public."Spedizione_Premium" VALUES (598, 'gkhklj82m85l361x', 'prjasj98x82r650m', 18.85, true);
INSERT INTO public."Spedizione_Premium" VALUES (763, 'xqjqsj22s53j343w', 'wrzhwr12v35v469v', 8.89, false);
INSERT INTO public."Spedizione_Premium" VALUES (1, 'biracl27s20m759i', 'wzycdo43f28d433j', 12.6, false);


--
-- TOC entry 3624 (class 0 OID 18595)
-- Dependencies: 265
-- Data for Name: Spedizione_Premium_Servizi; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO public."Spedizione_Premium_Servizi" VALUES (725, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (638, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (507, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (539, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (722, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (679, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (578, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (632, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (657, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (634, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (443, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (636, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (775, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (625, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (29, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (26, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (21, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (617, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (8, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (37, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (449, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (312, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (672, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (20, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (785, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (346, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (705, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (555, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (462, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (751, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (736, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (635, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (663, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (41, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (321, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (759, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (336, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (689, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (456, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (714, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (38, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (2, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (637, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (5, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (13, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (25, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (35, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (784, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (473, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (474, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (390, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (466, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (18, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (460, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (428, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (36, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (105, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (19, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (31, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (319, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (337, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (732, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (46, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (439, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (712, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (729, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (366, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (48, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (741, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (59, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (750, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (454, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (491, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (83, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (662, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (110, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (544, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (121, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (764, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (104, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (111, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (92, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (109, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (756, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (50, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (543, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (421, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (44, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (527, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (542, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (500, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (122, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (781, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (106, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (90, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (434, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (40, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (503, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (85, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (546, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (112, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (435, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (182, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (88, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (89, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (198, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (172, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (168, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (518, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (140, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (130, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (131, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (167, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (229, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (77, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (232, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (141, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (779, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (93, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (347, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (281, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (68, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (157, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (148, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (144, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (266, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (169, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (147, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (188, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (511, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (170, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (524, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (173, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (758, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (320, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (422, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (777, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (369, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (470, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (178, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (208, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (156, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (292, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (463, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (522, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (160, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (591, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (601, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (221, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (574, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (776, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (568, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (592, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (175, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (540, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (264, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (585, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (76, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (214, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (593, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (557, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (134, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (223, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (409, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (579, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (98, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (790, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (216, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (386, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (211, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (191, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (271, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (297, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (399, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (569, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (190, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (201, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (302, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (559, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (244, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (793, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (128, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (28, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (235, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (32, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (441, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (348, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (149, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (605, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (760, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (228, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (254, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (305, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (468, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (595, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (296, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (582, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (113, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (33, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (250, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (181, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (162, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (99, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (185, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (279, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (102, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (457, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (249, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (565, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (570, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (328, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (4, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (430, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (252, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (587, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (58, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (450, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (651, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (290, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (395, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (257, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (288, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (304, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (274, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (795, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (227, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (294, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (374, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (445, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (75, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (272, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (293, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (295, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (42, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (665, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (381, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (174, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (338, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (792, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (619, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (135, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (452, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (310, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (344, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (231, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (458, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (253, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (414, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (353, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (330, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (352, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (311, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (277, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (329, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (508, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (145, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (325, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (357, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (269, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (63, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (643, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (767, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (152, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (717, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (345, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (613, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (731, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (708, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (516, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (630, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (316, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (267, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (339, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (700, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (362, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (306, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (62, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (418, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (402, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (407, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (150, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (350, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (389, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (655, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (642, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (612, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (380, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (192, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (255, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (262, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (341, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (177, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (413, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (30, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (246, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (355, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (611, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (206, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (203, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (406, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (408, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (367, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (84, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (459, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (97, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (618, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (609, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (333, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (164, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (396, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (401, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (376, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (465, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (179, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (410, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (770, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (382, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (505, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (492, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (765, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (498, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (664, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (753, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (368, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (718, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (515, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (744, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (607, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (709, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (372, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (586, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (602, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (688, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (681, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (693, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (576, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (704, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (648, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (484, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (682, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (476, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (483, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (598, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (633, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (701, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (674, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (517, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (479, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (677, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (532, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (597, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (572, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (529, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (728, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (624, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (567, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (573, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (711, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (771, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (541, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (721, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (504, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (715, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (766, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (683, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (556, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (528, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (684, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (620, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (621, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (768, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (691, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (520, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (690, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (668, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (626, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (698, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (774, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (486, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (740, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (772, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (614, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (596, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (623, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (594, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (692, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (669, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (547, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (550, 53, 'RapidLogistics', 1.1);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (653, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (639, 1, 'FastTrack Express', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (783, 10, 'RapidConnect', 17.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (564, 14, 'ExpressLink', 9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (553, 23, 'QuickMove', 10);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (687, 25, 'RapidLogistics', 3.2);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (716, 29, 'TurboTransport', 16.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (558, 41, 'TurboDelivery', 5.9);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (686, 43, 'FastLaneTransit', 12);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (666, 45, 'SwiftFreight', 4.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (680, 46, 'InstantConnect', 9.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (581, 50, 'ExpressDispatch', 14.3);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (514, 51, 'QuickShip', 6.4);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (512, 52, 'SpeedyRoute', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (2, 54, 'SwiftDelivery', 10.8);
INSERT INTO public."Spedizione_Premium_Servizi" VALUES (4, 54, 'SwiftDelivery', 10.8);


--
-- TOC entry 3625 (class 0 OID 18600)
-- Dependencies: 266
-- Data for Name: Stato_Spedizione_Economica; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO public."Stato_Spedizione_Economica" VALUES (4, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (5, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (56, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (58, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (59, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (60, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (61, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (62, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (63, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (64, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (65, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (66, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (67, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (68, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (69, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (70, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (71, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (72, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (73, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (74, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (75, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (76, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (77, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (78, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (79, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (80, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (81, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (82, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (83, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (84, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (85, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (86, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (87, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (88, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (89, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (90, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (91, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (92, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (93, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (94, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (95, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (96, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (97, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (98, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (99, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (100, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (101, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (102, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (103, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (104, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (105, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (106, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (107, 27, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (108, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (109, 27, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (110, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (111, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (112, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (113, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (114, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (115, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (116, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (117, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (118, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (119, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (120, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (121, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (122, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (123, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (124, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (125, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (126, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (127, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (128, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (129, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (130, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (3, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (4, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (6, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (5, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (52, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (47, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (42, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (46, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (36, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (11, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (55, 27, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (57, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (8, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (9, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (12, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (13, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (14, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (16, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (17, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (18, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (19, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (21, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (22, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (24, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (26, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (27, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (30, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (32, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (35, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (36, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (37, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (38, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (41, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (43, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (44, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (45, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (46, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (49, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (50, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (52, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (54, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (6, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (7, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (10, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (11, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (15, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (20, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (23, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (25, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (28, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (29, 27, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (31, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (33, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (34, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (39, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (40, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (42, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (47, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (48, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (51, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (54, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (2, 27, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (131, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (132, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (133, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (134, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (135, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (136, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (137, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (138, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (139, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (140, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (141, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (142, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (143, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (144, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (145, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (146, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (147, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (148, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (149, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (150, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (151, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (152, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (153, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (154, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (155, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (156, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (157, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (158, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (159, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (160, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (161, 27, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (162, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (163, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (164, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (165, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (166, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (167, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (168, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (169, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (170, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (171, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (172, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (173, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (174, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (175, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (176, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (177, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (178, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (179, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (180, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (181, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (182, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (183, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (184, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (185, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (186, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (187, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (188, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (189, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (190, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (191, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (192, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (193, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (194, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (195, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (196, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (197, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (198, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (199, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (200, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (201, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (202, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (203, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (204, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (205, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (206, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (207, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (208, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (209, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (210, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (211, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (212, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (213, 27, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (214, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (215, 27, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (216, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (217, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (218, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (219, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (220, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (221, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (222, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (223, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (224, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (225, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (226, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (227, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (228, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (229, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (230, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (231, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (232, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (233, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (234, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (235, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (236, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (237, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (238, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (239, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (240, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (241, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (242, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (243, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (244, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (245, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (246, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (247, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (248, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (249, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (250, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (251, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (252, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (253, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (254, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (255, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (256, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (257, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (258, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (259, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (260, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (261, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (262, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (263, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (264, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (265, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (266, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (267, 27, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (268, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (269, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (270, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (271, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (272, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (273, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (274, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (275, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (276, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (277, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (278, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (279, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (280, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (281, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (282, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (283, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (284, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (285, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (286, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (287, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (288, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (289, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (290, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (291, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (292, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (293, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (294, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (295, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (58, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (59, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (60, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (61, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (62, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (63, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (64, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (65, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (66, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (67, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (68, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (69, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (70, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (71, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (72, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (73, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (74, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (56, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (57, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (75, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (76, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (77, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (78, 27, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (79, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (80, 27, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (81, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (82, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (83, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (84, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (85, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (86, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (87, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (88, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (89, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (90, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (91, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (92, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (93, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (94, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (95, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (96, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (97, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (98, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (99, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (100, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (101, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (102, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (103, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (104, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (105, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (106, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (107, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (108, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (109, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (110, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (111, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (112, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (113, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (114, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (115, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (116, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (117, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (118, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (119, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (120, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (121, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (122, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (123, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (124, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (125, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (126, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (127, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (128, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (129, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (130, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (131, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (132, 27, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (133, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (134, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (135, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (136, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (137, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (138, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (139, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (140, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (141, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (142, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (143, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (144, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (145, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (146, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (147, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (148, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (149, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (150, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (151, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (152, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (153, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (154, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (155, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (156, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (157, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (158, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (159, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (160, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (161, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (162, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (163, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (164, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (165, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (166, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (167, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (168, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (169, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (170, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (171, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (172, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (173, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (174, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (175, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (176, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (177, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (178, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (179, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (180, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (181, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (182, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (183, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (184, 27, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (185, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (186, 27, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (187, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (188, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (189, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (190, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (191, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (192, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (193, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (194, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (195, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (196, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (197, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (198, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (199, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (200, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (201, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (202, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (203, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (204, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (205, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (206, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (207, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (208, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (209, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (210, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (211, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (212, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (213, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (214, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (215, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (216, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (217, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (218, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (219, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (220, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (221, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (222, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (223, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (224, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (225, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (226, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (227, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (228, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (229, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (230, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (231, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (232, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (233, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (234, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (235, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (236, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (237, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (238, 27, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (239, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (240, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (241, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (242, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (243, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (244, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (245, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (246, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (247, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (248, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (249, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (250, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (251, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (252, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (253, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (254, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (255, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (256, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (257, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (258, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (259, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (260, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (261, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (262, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (263, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (264, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (265, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (266, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (267, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (268, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (269, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (270, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (271, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (272, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (273, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (274, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (275, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (276, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (277, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (278, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (279, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (280, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (281, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (282, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (283, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (284, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (285, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (286, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (287, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (288, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (289, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (290, 27, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (291, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (292, 27, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (293, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (294, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (295, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (55, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (56, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (57, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (58, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (59, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (60, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (61, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (62, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (63, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (64, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (65, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (66, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (67, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (68, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (69, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (70, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (71, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (72, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (73, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (74, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (75, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (76, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (77, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (78, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (79, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (80, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (81, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (82, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (83, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (84, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (85, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (86, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (87, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (88, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (89, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (90, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (91, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (92, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (93, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (94, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (95, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (96, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (97, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (98, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (99, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (100, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (101, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (102, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (103, 27, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (104, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (105, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (106, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (107, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (108, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (109, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (110, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (111, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (112, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (113, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (114, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (115, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (116, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (117, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (118, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (119, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (120, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (121, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (122, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (123, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (124, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (125, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (126, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (127, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (128, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (129, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (130, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (131, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (132, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (133, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (134, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (135, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (136, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (137, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (138, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (139, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (140, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (141, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (142, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (143, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (144, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (145, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (146, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (147, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (148, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (149, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (150, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (151, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (152, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (153, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (154, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (155, 27, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (156, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (157, 27, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (158, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (159, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (160, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (161, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (162, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (163, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (164, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (165, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (166, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (167, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (168, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (169, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (170, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (171, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (172, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (173, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (174, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (175, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (176, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (177, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (178, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (179, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (180, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (181, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (182, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (183, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (184, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (185, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (186, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (187, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (188, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (189, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (190, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (191, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (192, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (193, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (194, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (195, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (196, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (197, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (198, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (199, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (200, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (201, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (202, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (203, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (204, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (205, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (206, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (207, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (208, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (209, 27, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (210, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (211, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (212, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (213, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (214, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (215, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (216, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (217, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (218, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (219, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (220, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (221, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (222, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (223, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (224, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (225, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (226, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (227, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (228, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (229, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (230, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (231, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (232, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (233, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (234, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (235, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (236, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (237, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (238, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (239, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (240, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (241, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (242, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (243, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (244, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (245, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (246, 18, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (247, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (248, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (249, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (250, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (251, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (252, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (253, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (254, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (255, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (256, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (257, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (258, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (259, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (260, 25, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (261, 27, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (262, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (263, 27, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (264, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (265, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (266, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (267, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (268, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (269, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (270, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (271, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (272, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (273, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (274, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (275, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (276, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (277, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (278, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (279, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (280, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (281, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (282, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (283, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (284, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (285, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (286, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (287, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (288, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (289, 13, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (290, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (291, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (292, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (293, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (294, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (295, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (2, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (3, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (10, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (8, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (7, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (9, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (16, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (15, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (38, 9, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (14, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (50, 21, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (49, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (20, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (33, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (35, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (22, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (48, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (40, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (19, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (31, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (12, 10, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (29, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (24, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (30, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (13, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (34, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (44, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (21, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (41, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (37, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (39, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (28, 27, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (23, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (32, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (51, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (18, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (17, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (26, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (43, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (25, 24, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (45, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (55, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (118, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (118, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Economica" VALUES (27, 25, '2023-07-26');


--
-- TOC entry 3626 (class 0 OID 18604)
-- Dependencies: 267
-- Data for Name: Stato_Spedizione_Premium; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO public."Stato_Spedizione_Premium" VALUES (538, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (1, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (1, 10, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (1, 11, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (1, 13, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (2, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (2, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (2, 10, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (3, 1, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (3, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (3, 3, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (4, 2, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (4, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (4, 4, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (5, 3, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (5, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (5, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (6, 4, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (6, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (6, 6, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (7, 5, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (7, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (7, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (8, 6, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (8, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (8, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (9, 7, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (9, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (9, 9, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (10, 8, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (10, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (10, 10, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (11, 9, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (11, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (11, 11, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (12, 10, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (12, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (12, 12, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (13, 11, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (13, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (13, 13, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (14, 12, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (14, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (14, 14, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (15, 13, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (15, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (15, 15, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (16, 14, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (16, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (16, 16, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (17, 15, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (17, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (17, 17, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (18, 16, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (18, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (18, 18, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (19, 17, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (19, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (19, 19, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (20, 18, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (20, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (20, 20, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (21, 19, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (21, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (21, 21, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (22, 20, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (22, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (22, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (23, 21, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (23, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (23, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (24, 22, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (24, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (24, 24, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (25, 23, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (25, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (25, 25, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (26, 24, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (26, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (26, 26, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (27, 25, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (27, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (27, 27, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (28, 1, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (28, 26, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (28, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (29, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (29, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (29, 27, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (30, 1, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (30, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (30, 3, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (31, 2, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (31, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (31, 4, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (32, 3, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (32, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (32, 5, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (33, 4, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (33, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (33, 6, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (34, 5, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (34, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (34, 7, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (35, 6, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (35, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (35, 8, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (36, 7, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (36, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (36, 9, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (37, 8, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (37, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (37, 10, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (38, 9, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (38, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (38, 11, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (39, 10, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (39, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (39, 12, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (40, 11, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (40, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (40, 13, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (41, 12, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (41, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (41, 14, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (42, 13, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (42, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (42, 15, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (43, 14, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (43, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (43, 16, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (44, 15, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (44, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (44, 17, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (45, 16, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (45, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (45, 18, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (46, 17, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (46, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (46, 19, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (47, 18, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (47, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (47, 20, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (48, 19, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (48, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (48, 21, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (49, 20, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (49, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (49, 22, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (50, 21, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (50, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (50, 23, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (51, 22, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (51, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (51, 24, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (53, 24, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (53, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (53, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (54, 25, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (54, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (54, 27, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (55, 1, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (55, 26, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (55, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (56, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (56, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (56, 27, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (57, 1, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (57, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (57, 3, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (58, 2, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (58, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (58, 4, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (59, 3, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (59, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (59, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (60, 4, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (60, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (60, 6, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (61, 5, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (61, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (61, 7, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (62, 6, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (62, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (62, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (539, 23, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (539, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (540, 24, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (540, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (541, 25, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (541, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (542, 26, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (542, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (543, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (543, 27, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (544, 1, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (544, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (545, 2, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (545, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (546, 3, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (546, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (547, 4, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (547, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (548, 5, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (548, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (549, 6, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (549, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (550, 7, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (550, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (551, 8, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (551, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (552, 9, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (552, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (553, 10, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (553, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (554, 11, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (554, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (555, 12, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (555, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (556, 13, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (556, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (557, 14, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (557, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (558, 15, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (558, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (559, 16, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (559, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (560, 17, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (560, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (561, 18, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (561, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (562, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (562, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (563, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (563, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (564, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (564, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (565, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (565, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (566, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (566, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (567, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (567, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (568, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (568, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (569, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (569, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (570, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (570, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (571, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (571, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (572, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (572, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (573, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (573, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (574, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (574, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (575, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (575, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (576, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (576, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (577, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (577, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (578, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (578, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (579, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (579, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (580, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (580, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (581, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (581, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (582, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (582, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (583, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (583, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (584, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (584, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (585, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (585, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (586, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (586, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (587, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (587, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (588, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (588, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (589, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (589, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (590, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (590, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (591, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (591, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (592, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (592, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (593, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (593, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (594, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (594, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (595, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (595, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (596, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (596, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (597, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (597, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (598, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (598, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (599, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (599, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (600, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (600, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (601, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (601, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (602, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (602, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (603, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (603, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (604, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (604, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (605, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (605, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (606, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (606, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (607, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (607, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (608, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (608, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (609, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (609, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (610, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (610, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (611, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (611, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (612, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (612, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (613, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (613, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (614, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (614, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (615, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (615, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (616, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (616, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (617, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (617, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (618, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (618, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (619, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (619, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (620, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (620, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (621, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (621, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (622, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (622, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (623, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (623, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (624, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (624, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (625, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (625, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (626, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (626, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (627, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (627, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (628, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (628, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (629, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (629, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (630, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (630, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (631, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (631, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (632, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (632, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (633, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (633, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (634, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (634, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (635, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (635, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (636, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (636, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (637, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (637, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (638, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (638, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (639, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (639, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (640, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (640, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (641, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (641, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (642, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (642, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (643, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (643, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (644, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (644, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (645, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (645, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (646, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (646, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (647, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (647, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (648, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (648, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (649, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (649, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (650, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (650, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (651, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (651, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (652, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (652, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (653, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (653, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (654, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (654, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (655, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (655, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (656, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (656, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (657, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (657, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (658, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (658, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (659, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (659, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (660, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (660, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (661, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (661, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (662, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (662, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (663, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (663, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (664, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (664, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (665, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (665, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (666, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (666, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (667, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (667, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (668, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (668, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (669, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (669, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (670, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (670, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (671, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (671, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (672, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (672, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (673, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (673, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (674, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (674, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (675, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (675, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (676, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (676, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (677, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (677, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (678, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (678, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (679, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (679, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (680, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (680, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (681, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (681, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (682, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (682, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (683, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (683, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (684, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (684, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (685, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (685, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (686, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (686, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (687, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (687, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (688, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (688, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (689, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (689, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (690, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (690, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (691, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (691, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (692, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (692, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (693, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (693, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (694, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (694, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (695, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (695, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (696, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (696, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (697, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (697, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (698, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (698, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (699, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (699, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (700, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (700, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (701, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (701, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (702, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (702, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (703, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (703, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (704, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (704, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (705, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (705, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (706, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (706, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (707, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (707, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (708, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (708, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (709, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (709, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (710, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (710, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (711, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (711, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (712, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (712, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (713, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (713, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (714, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (714, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (715, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (715, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (716, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (716, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (717, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (717, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (718, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (718, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (719, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (719, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (720, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (720, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (721, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (721, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (722, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (722, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (723, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (723, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (724, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (724, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (725, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (725, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (726, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (726, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (727, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (727, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (728, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (728, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (729, 24, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (729, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (730, 25, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (730, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (731, 26, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (731, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (732, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (732, 27, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (733, 1, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (733, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (734, 2, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (734, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (735, 3, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (735, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (736, 4, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (736, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (737, 5, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (737, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (738, 6, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (738, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (739, 7, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (739, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (740, 8, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (740, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (741, 9, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (741, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (742, 10, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (742, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (743, 11, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (743, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (744, 12, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (744, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (745, 13, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (745, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (746, 14, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (746, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (747, 15, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (747, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (748, 16, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (748, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (749, 17, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (749, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (750, 18, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (750, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (751, 19, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (751, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (752, 20, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (752, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (753, 21, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (753, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (754, 22, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (754, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (755, 23, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (755, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (756, 24, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (756, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (757, 25, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (757, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (758, 26, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (758, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (759, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (759, 27, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (760, 1, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (760, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (761, 2, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (761, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (762, 3, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (762, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (763, 4, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (763, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (764, 5, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (764, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (765, 6, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (765, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (766, 7, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (766, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (767, 8, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (767, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (768, 9, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (768, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (769, 10, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (769, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (770, 11, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (770, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (771, 12, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (771, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (772, 13, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (772, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (773, 14, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (773, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (774, 15, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (774, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (775, 16, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (775, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (776, 17, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (776, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (777, 18, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (777, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (778, 19, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (778, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (779, 20, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (779, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (780, 21, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (780, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (781, 22, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (781, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (782, 23, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (782, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (783, 24, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (783, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (784, 25, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (784, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (785, 26, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (785, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (786, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (786, 27, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (787, 1, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (787, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (788, 2, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (788, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (63, 7, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (63, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (63, 9, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (64, 8, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (64, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (64, 10, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (65, 9, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (65, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (65, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (66, 10, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (66, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (66, 12, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (67, 11, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (67, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (67, 13, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (68, 12, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (68, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (68, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (69, 13, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (69, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (69, 15, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (70, 14, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (70, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (70, 16, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (71, 15, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (71, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (71, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (72, 16, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (72, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (72, 18, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (73, 17, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (73, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (73, 19, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (74, 18, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (74, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (74, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (75, 19, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (75, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (75, 21, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (76, 20, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (76, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (76, 22, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (77, 21, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (77, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (77, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (78, 22, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (78, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (78, 24, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (79, 23, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (79, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (79, 25, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (80, 24, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (80, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (80, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (81, 25, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (81, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (81, 27, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (82, 1, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (82, 26, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (82, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (83, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (83, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (83, 27, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (84, 1, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (84, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (84, 3, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (85, 2, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (85, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (85, 4, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (86, 3, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (86, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (86, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (87, 4, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (87, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (87, 6, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (88, 5, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (88, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (88, 7, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (89, 6, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (89, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (89, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (90, 7, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (90, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (90, 9, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (91, 8, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (91, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (91, 10, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (92, 9, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (92, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (92, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (93, 10, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (93, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (93, 12, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (94, 11, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (94, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (94, 13, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (95, 12, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (95, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (95, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (96, 13, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (96, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (96, 15, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (97, 14, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (97, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (97, 16, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (98, 15, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (98, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (98, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (99, 16, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (99, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (99, 18, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (100, 17, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (100, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (100, 19, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (101, 18, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (101, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (101, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (102, 19, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (102, 20, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (102, 21, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (103, 20, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (103, 21, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (103, 22, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (104, 21, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (104, 22, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (104, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (105, 22, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (105, 23, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (105, 24, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (106, 23, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (106, 24, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (106, 25, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (107, 24, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (107, 25, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (107, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (108, 25, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (108, 26, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (108, 27, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (109, 1, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (109, 26, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (109, 27, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (110, 1, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (110, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (110, 27, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (111, 1, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (111, 2, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (111, 3, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (112, 2, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (112, 3, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (112, 4, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (113, 3, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (113, 4, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (113, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (114, 4, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (114, 5, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (114, 6, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (115, 5, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (115, 6, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (115, 7, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (116, 6, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (116, 7, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (116, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (117, 7, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (117, 8, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (117, 9, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (118, 8, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (118, 9, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (118, 10, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (119, 9, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (119, 10, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (119, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (120, 10, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (120, 11, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (120, 12, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (121, 11, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (121, 12, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (121, 13, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (122, 12, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (122, 13, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (122, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (123, 13, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (123, 14, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (123, 15, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (124, 14, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (124, 15, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (124, 16, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (125, 15, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (125, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (125, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (126, 16, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (126, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (126, 18, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (127, 17, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (127, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (127, 19, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (128, 18, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (128, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (128, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (129, 19, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (129, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (129, 21, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (130, 20, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (130, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (130, 22, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (131, 21, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (131, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (131, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (132, 22, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (132, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (132, 24, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (133, 23, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (133, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (133, 25, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (134, 24, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (134, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (134, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (135, 25, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (135, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (135, 27, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (136, 1, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (136, 26, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (136, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (137, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (137, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (137, 27, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (138, 1, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (138, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (138, 3, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (139, 2, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (139, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (139, 4, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (140, 3, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (140, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (140, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (141, 4, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (141, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (141, 6, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (142, 5, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (142, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (142, 7, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (143, 6, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (143, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (143, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (144, 7, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (144, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (144, 9, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (145, 8, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (145, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (145, 10, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (146, 9, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (146, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (146, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (147, 10, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (147, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (147, 12, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (148, 11, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (148, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (148, 13, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (149, 12, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (149, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (149, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (150, 13, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (150, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (150, 15, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (151, 14, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (151, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (151, 16, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (152, 15, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (152, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (152, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (153, 16, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (153, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (153, 18, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (154, 17, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (154, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (154, 19, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (155, 18, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (155, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (155, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (156, 19, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (156, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (156, 21, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (157, 20, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (157, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (157, 22, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (158, 21, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (158, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (158, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (159, 22, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (159, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (159, 24, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (160, 23, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (160, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (160, 25, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (161, 24, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (161, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (161, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (162, 25, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (162, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (162, 27, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (163, 1, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (163, 26, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (163, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (164, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (164, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (164, 27, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (165, 1, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (165, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (165, 3, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (166, 2, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (166, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (166, 4, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (167, 3, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (167, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (167, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (168, 4, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (168, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (168, 6, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (169, 5, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (169, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (169, 7, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (170, 6, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (170, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (170, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (171, 7, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (171, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (171, 9, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (172, 8, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (172, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (172, 10, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (173, 9, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (173, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (173, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (174, 10, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (174, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (174, 12, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (175, 11, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (175, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (175, 13, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (176, 12, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (176, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (176, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (177, 13, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (177, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (177, 15, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (178, 14, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (178, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (178, 16, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (179, 15, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (179, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (179, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (180, 16, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (180, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (180, 18, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (181, 17, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (181, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (181, 19, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (182, 18, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (182, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (182, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (183, 19, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (183, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (183, 21, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (184, 20, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (184, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (184, 22, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (185, 21, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (185, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (185, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (186, 22, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (186, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (186, 24, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (187, 23, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (187, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (187, 25, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (188, 24, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (188, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (188, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (189, 25, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (189, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (189, 27, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (190, 1, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (190, 26, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (190, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (191, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (191, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (191, 27, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (192, 1, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (192, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (192, 3, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (193, 2, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (193, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (193, 4, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (194, 3, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (194, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (194, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (195, 4, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (195, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (195, 6, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (196, 5, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (196, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (196, 7, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (197, 6, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (197, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (197, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (198, 7, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (198, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (198, 9, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (199, 8, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (199, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (199, 10, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (200, 9, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (200, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (200, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (201, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (201, 12, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (202, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (202, 13, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (203, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (203, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (204, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (204, 15, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (205, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (205, 16, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (206, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (206, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (207, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (207, 18, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (208, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (208, 19, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (209, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (209, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (210, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (210, 21, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (211, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (211, 22, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (212, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (212, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (213, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (213, 24, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (214, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (214, 25, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (215, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (215, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (216, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (216, 27, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (217, 1, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (217, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (218, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (218, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (219, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (219, 3, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (220, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (220, 4, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (221, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (221, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (222, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (222, 6, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (223, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (223, 7, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (224, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (224, 8, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (225, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (225, 9, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (226, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (226, 10, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (227, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (227, 11, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (228, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (228, 12, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (229, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (229, 13, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (230, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (230, 14, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (231, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (231, 15, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (232, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (232, 16, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (233, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (233, 17, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (234, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (234, 18, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (235, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (235, 19, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (236, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (236, 20, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (237, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (237, 21, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (238, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (238, 22, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (239, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (239, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (240, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (240, 24, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (241, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (241, 25, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (242, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (242, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (243, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (243, 27, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (244, 1, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (244, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (245, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (245, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (246, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (246, 3, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (247, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (247, 4, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (248, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (248, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (249, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (249, 6, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (250, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (250, 7, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (251, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (251, 8, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (252, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (252, 9, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (253, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (253, 10, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (254, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (254, 11, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (255, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (255, 12, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (256, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (256, 13, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (257, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (257, 14, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (258, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (258, 15, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (259, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (259, 16, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (260, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (260, 17, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (261, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (261, 18, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (262, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (262, 19, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (263, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (263, 20, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (264, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (264, 21, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (265, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (265, 22, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (266, 22, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (266, 23, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (267, 23, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (267, 24, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (268, 24, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (268, 25, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (269, 25, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (269, 26, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (270, 26, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (270, 27, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (271, 1, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (271, 27, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (272, 1, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (272, 2, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (273, 2, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (273, 3, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (274, 3, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (274, 4, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (275, 4, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (275, 5, '2023-07-26');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (276, 5, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (276, 6, '2023-07-27');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (277, 6, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (277, 7, '2023-07-28');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (278, 7, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (278, 8, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (279, 8, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (279, 9, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (280, 9, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (280, 10, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (281, 10, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (281, 11, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (282, 11, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (282, 12, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (283, 12, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (283, 13, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (284, 13, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (284, 14, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (285, 14, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (285, 15, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (286, 15, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (286, 16, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (287, 16, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (287, 17, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (288, 17, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (288, 18, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (289, 18, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (289, 19, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (290, 19, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (290, 20, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (291, 20, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (291, 21, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (292, 21, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (292, 22, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (293, 22, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (293, 23, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (294, 23, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (294, 24, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (295, 24, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (295, 25, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (296, 25, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (296, 26, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (297, 26, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (297, 27, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (298, 1, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (298, 27, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (299, 1, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (299, 2, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (300, 2, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (300, 3, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (301, 3, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (301, 4, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (302, 4, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (302, 5, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (303, 5, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (303, 6, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (304, 6, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (304, 7, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (305, 7, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (305, 8, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (306, 8, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (306, 9, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (307, 9, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (307, 10, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (308, 10, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (308, 11, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (309, 11, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (309, 12, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (310, 12, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (310, 13, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (311, 13, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (311, 14, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (312, 14, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (312, 15, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (313, 15, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (313, 16, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (314, 16, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (314, 17, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (315, 17, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (315, 18, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (316, 18, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (316, 19, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (317, 19, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (317, 20, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (318, 20, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (318, 21, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (319, 21, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (319, 22, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (320, 22, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (320, 23, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (321, 23, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (321, 24, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (322, 24, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (322, 25, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (323, 25, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (323, 26, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (324, 26, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (324, 27, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (325, 1, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (325, 27, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (326, 1, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (326, 2, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (327, 2, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (327, 3, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (328, 3, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (328, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (329, 4, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (329, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (330, 5, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (330, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (331, 6, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (331, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (332, 7, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (332, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (333, 8, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (333, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (334, 9, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (334, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (335, 10, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (335, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (336, 11, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (336, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (337, 12, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (337, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (338, 13, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (338, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (339, 14, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (339, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (340, 15, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (340, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (341, 16, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (341, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (342, 17, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (342, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (343, 18, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (343, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (344, 19, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (344, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (345, 20, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (345, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (346, 21, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (346, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (347, 22, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (347, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (348, 23, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (348, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (349, 24, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (349, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (350, 25, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (350, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (351, 26, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (351, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (352, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (352, 27, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (353, 1, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (353, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (354, 2, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (354, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (355, 3, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (355, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (356, 4, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (356, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (357, 5, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (357, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (358, 6, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (358, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (359, 7, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (359, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (360, 8, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (360, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (361, 9, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (361, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (362, 10, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (362, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (363, 11, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (363, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (364, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (364, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (365, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (365, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (366, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (366, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (367, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (367, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (368, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (368, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (369, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (369, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (370, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (370, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (371, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (371, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (372, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (372, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (373, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (373, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (374, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (374, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (375, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (375, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (376, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (376, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (377, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (377, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (378, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (378, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (379, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (379, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (380, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (380, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (381, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (381, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (382, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (382, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (383, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (383, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (384, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (384, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (385, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (385, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (386, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (386, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (387, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (387, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (388, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (388, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (389, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (389, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (390, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (390, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (391, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (391, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (392, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (392, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (393, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (393, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (394, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (394, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (395, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (395, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (396, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (396, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (397, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (397, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (398, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (398, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (399, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (399, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (400, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (400, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (401, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (401, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (402, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (402, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (403, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (403, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (404, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (404, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (405, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (405, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (406, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (406, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (407, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (407, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (408, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (408, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (409, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (409, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (410, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (410, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (411, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (411, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (412, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (412, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (413, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (413, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (414, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (414, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (415, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (415, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (416, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (416, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (417, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (417, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (418, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (418, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (419, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (419, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (420, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (420, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (421, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (421, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (422, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (422, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (423, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (423, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (424, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (424, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (425, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (425, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (426, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (426, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (427, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (427, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (428, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (428, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (429, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (429, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (430, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (430, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (431, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (431, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (432, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (432, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (433, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (433, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (434, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (434, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (435, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (435, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (436, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (436, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (437, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (437, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (438, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (438, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (439, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (439, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (440, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (440, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (441, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (441, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (442, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (442, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (443, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (443, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (444, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (444, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (445, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (445, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (446, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (446, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (447, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (447, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (448, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (448, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (449, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (449, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (450, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (450, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (451, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (451, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (452, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (452, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (453, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (453, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (454, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (454, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (455, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (455, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (456, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (456, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (457, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (457, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (458, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (458, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (459, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (459, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (460, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (460, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (461, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (461, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (462, 2, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (462, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (463, 3, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (463, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (464, 4, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (464, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (465, 5, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (465, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (466, 6, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (466, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (467, 7, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (467, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (468, 8, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (468, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (469, 9, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (469, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (470, 10, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (470, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (471, 11, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (471, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (472, 12, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (472, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (473, 13, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (473, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (474, 14, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (474, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (475, 15, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (475, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (476, 16, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (476, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (477, 17, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (477, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (478, 18, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (478, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (479, 19, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (479, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (480, 20, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (480, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (481, 21, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (481, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (482, 22, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (482, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (483, 23, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (483, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (484, 24, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (484, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (485, 25, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (485, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (486, 26, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (486, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (487, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (487, 27, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (488, 1, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (488, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (489, 2, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (489, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (490, 3, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (490, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (491, 4, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (491, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (492, 5, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (492, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (493, 6, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (493, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (494, 7, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (494, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (495, 8, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (495, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (496, 9, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (496, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (497, 10, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (497, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (498, 11, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (498, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (499, 12, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (499, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (500, 13, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (500, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (501, 14, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (501, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (502, 15, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (502, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (503, 16, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (503, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (504, 17, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (504, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (505, 18, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (505, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (506, 19, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (506, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (507, 20, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (507, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (508, 21, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (508, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (509, 22, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (509, 23, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (510, 23, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (510, 24, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (511, 24, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (511, 25, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (512, 25, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (512, 26, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (513, 26, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (513, 27, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (514, 1, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (514, 27, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (515, 1, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (515, 2, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (516, 2, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (516, 3, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (517, 3, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (517, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (518, 4, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (518, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (519, 5, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (519, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (520, 6, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (520, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (521, 7, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (521, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (522, 8, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (522, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (523, 9, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (523, 10, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (524, 10, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (524, 11, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (527, 11, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (527, 12, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (528, 12, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (528, 13, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (529, 13, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (529, 14, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (530, 14, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (530, 15, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (531, 15, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (531, 16, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (532, 16, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (532, 17, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (533, 17, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (533, 18, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (534, 18, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (534, 19, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (535, 19, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (535, 20, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (536, 20, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (536, 21, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (537, 21, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (537, 22, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (538, 22, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (789, 3, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (789, 4, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (790, 4, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (790, 5, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (791, 5, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (791, 6, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (792, 6, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (792, 7, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (793, 7, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (793, 8, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (794, 8, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (794, 9, '2023-07-23');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (795, 9, '2023-07-30');
INSERT INTO public."Stato_Spedizione_Premium" VALUES (795, 10, '2023-07-23');


--
-- TOC entry 3627 (class 0 OID 18608)
-- Dependencies: 268
-- Data for Name: User; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO public."User" VALUES ('biracl27s20m759i', 'dtweddle6j@google.nl', 'Dreddy', 'Tweddle', '6515714034');
INSERT INTO public."User" VALUES ('kqwjjd23e43o622b', 'sbarnish6x@bluehost.com', 'Stephine', 'Barnish', '4303439980');
INSERT INTO public."User" VALUES ('auaggp09y68t935y', 'rlorne8f@ehow.com', 'Rosalia', 'Lorne', '8351640999');
INSERT INTO public."User" VALUES ('kjnlji67m42p786g', 'ahairon96@cnet.com', 'Ashton', 'Hairon', '9235210798');
INSERT INTO public."User" VALUES ('dvqwpq82d12u044j', 'mgoodbarr9x@auda.org.au', 'Magdaia', 'Goodbarr', '5954581709');
INSERT INTO public."User" VALUES ('cvjlwx09n81j993j', 'lmaffeo9z@nytimes.com', 'Lira', 'Maffeo', '5972387064');
INSERT INTO public."User" VALUES ('ffdwee60s61t235w', 'nvigneronbr@ow.ly', 'Nikkie', 'Vigneron', '1138567150');
INSERT INTO public."User" VALUES ('oobxgl21n86l160z', 'pcarthewc5@histats.com', 'Pamella', 'Carthew', '4563272623');
INSERT INTO public."User" VALUES ('hmozuk35y60c790g', 'lburgumch@livejournal.com', 'Lissy', 'Burgum', '9741335947');
INSERT INTO public."User" VALUES ('aunxad02p33x402h', 'rphilippedn@unblog.fr', 'Renae', 'Philippe', '8918898927');
INSERT INTO public."User" VALUES ('yiblfs65g56k279q', 'rstradlingdo@washingtonpost.com', 'Ruthann', 'Stradling', '7208686732');
INSERT INTO public."User" VALUES ('jqkjfd25s12j468w', 'murlich5i@weather.com', 'Mariquilla', 'Urlich', '9212575591');
INSERT INTO public."User" VALUES ('npyljq01s77p500h', 'jbernardes3e@slashdot.org', 'Jayme', 'Bernardes', '2927490558');
INSERT INTO public."User" VALUES ('awuyzn61c17c890d', 'uchestermanc0@apple.com', 'Ulberto', 'Chesterman', '2882320877');
INSERT INTO public."User" VALUES ('echxll47x25b400a', 'kshrimpton35@unblog.fr', 'Kip', 'Shrimpton', '4346095448');
INSERT INTO public."User" VALUES ('qabkgx49q61o993x', 'mgriffithebf@ucla.edu', 'Miranda', 'Griffithe', '9575144897');
INSERT INTO public."User" VALUES ('psfiod09k77a681u', 'lclarke6s@vinaora.com', 'Linn', 'Clarke', '8905294898');
INSERT INTO public."User" VALUES ('bucims80t97w944z', 'stwidell7g@comcast.net', 'Susann', 'Twidell', '9271523136');
INSERT INTO public."User" VALUES ('tamsxh39j08d107q', 'gcramptonck@theatlantic.com', 'Giulia', 'Crampton', '4582834816');
INSERT INTO public."User" VALUES ('hhwjqv17k50w410f', 'mdobkin1h@virginia.edu', 'Mirabella', 'Dobkin', '9327400477');
INSERT INTO public."User" VALUES ('mfbslr80u19a742g', 'mlorencdq@oakley.com', 'Mirelle', 'Lorenc', '1327810623');
INSERT INTO public."User" VALUES ('arllpa74i66y238j', 'nleggatta9@seattletimes.com', 'Ned', 'Leggatt', '1787646688');
INSERT INTO public."User" VALUES ('ikwfcz18b86e682q', 'ekave6o@google.fr', 'Elisa', 'Kave', '2157024874');
INSERT INTO public."User" VALUES ('fgceut14h98h226r', 'lrosenqvist6a@google.fr', 'Leif', 'Rosenqvist', '1518041577');
INSERT INTO public."User" VALUES ('rbxbrf79f09c376r', 'mmoutrayread8m@stumbleupon.com', 'Maxie', 'Moutray Read', '5924495631');
INSERT INTO public."User" VALUES ('moqyaa96b41w621l', 'xmostyn8u@blog.com', 'Xymenes', 'Mostyn', '9693616726');
INSERT INTO public."User" VALUES ('abogvl97e41a631n', 'tshawel1r@yolasite.com', 'Tedmund', 'Shawel', '1871890708');
INSERT INTO public."User" VALUES ('pqjbjt76t60z084a', 'cdidsbury5o@about.com', 'Cristabel', 'Didsbury', '9096522025');
INSERT INTO public."User" VALUES ('rcjgxa50z51h696w', 'ikoopau@slashdot.org', 'Inge', 'Koop', '4558428216');
INSERT INTO public."User" VALUES ('shnnfp42x22u151r', 'vbarnewille5r@auda.org.au', 'Valdemar', 'Barnewille', '6948867304');
INSERT INTO public."User" VALUES ('magujx74u13t692j', 'bbatters10@deliciousdays.com', 'Benedict', 'Batters', '8006558824');
INSERT INTO public."User" VALUES ('dbhyzt20x58r774v', 'dstleger12@tmall.com', 'Daryl', 'St Leger', '4786725416');
INSERT INTO public."User" VALUES ('tzrppf44x01q376h', 'tbaynes1o@spiegel.de', 'Tarrah', 'Baynes', '4246768924');
INSERT INTO public."User" VALUES ('pvgfaf41e99l262m', 'cedgley1q@cnn.com', 'Cathy', 'Edgley', '5592036222');
INSERT INTO public."User" VALUES ('qmogjf57a26v287q', 'chatherley1w@studiopress.com', 'Cyndie', 'Hatherley', '7694250466');
INSERT INTO public."User" VALUES ('corzss57a06d644t', 'sglanville24@google.ru', 'Shel', 'Glanville', '9869960917');
INSERT INTO public."User" VALUES ('kqupzq92g24n430p', 'gmeneghelli25@edublogs.org', 'Grissel', 'Meneghelli', '7077921583');
INSERT INTO public."User" VALUES ('uajvuh30u29g422t', 'kjoiner2f@state.tx.us', 'Kaela', 'Joiner', '2171771268');
INSERT INTO public."User" VALUES ('fdzdby16w16j502a', 'wewers2u@si.edu', 'Warner', 'Ewers', '8661531228');
INSERT INTO public."User" VALUES ('ldaacb32t23p035n', 'ncreech2w@engadget.com', 'Nicolas', 'Creech', '2613463269');
INSERT INTO public."User" VALUES ('vmrlhf74f78j242r', 'rcutriss38@cnn.com', 'Raine', 'Cutriss', '3532574049');
INSERT INTO public."User" VALUES ('vrrrzs98x58u998j', 'shighway3w@nih.gov', 'Samson', 'Highway', '7345620095');
INSERT INTO public."User" VALUES ('mumnbw95f77i705t', 'ftunnoch4i@cnet.com', 'Flore', 'Tunnoch', '4249845899');
INSERT INTO public."User" VALUES ('qssbjx39t46r976n', 'esains4o@dailymotion.com', 'Evyn', 'Sains', '8762412701');
INSERT INTO public."User" VALUES ('mlnxnc18l24m114u', 'loconnell4u@purevolume.com', 'Lloyd', 'O Connell', '1308854028');
INSERT INTO public."User" VALUES ('bvsues78b56y479m', 'mmacbean4v@flickr.com', 'Mellisent', 'MacBean', '4472246463');
INSERT INTO public."User" VALUES ('ceecog34d09y094c', 'klough4w@toplist.cz', 'Karissa', 'Lough', '5717571010');
INSERT INTO public."User" VALUES ('spjzpv06b62d022v', 'cyepiskov58@intel.com', 'Cassandry', 'Yepiskov', '3241228681');
INSERT INTO public."User" VALUES ('pvilho11h32q211g', 'rlunn5m@freewebs.com', 'Rab', 'Lunn', '7426634360');
INSERT INTO public."User" VALUES ('ocwhrd88a63g175v', 'bwherrettp@usa.gov', 'Billie', 'Wherrett', '3475447783');
INSERT INTO public."User" VALUES ('nxrwjy67e78k983a', 'rcroome67@shutterfly.com', 'Rina', 'Croome', '7824013286');
INSERT INTO public."User" VALUES ('utoxrt14i21h422h', 'bwhittick68@nyu.edu', 'Bjorn', 'Whittick', '1874401723');
INSERT INTO public."User" VALUES ('trepgg69u19k071g', 'lcorsellesdv@soundcloud.com', 'Licha', 'Corselles', '1899871583');
INSERT INTO public."User" VALUES ('jxkaly72y50r152y', 'bbenedit0@histats.com', 'Léana', 'Poole', 'nnxydc1aa6');
INSERT INTO public."User" VALUES ('zjjzzm30m46g321h', 'mbracknell1@xinhuanet.com', 'Séréna', 'Pratty', 'atqaus2zr5');
INSERT INTO public."User" VALUES ('noslzw34u00r539t', 'echeek2@jugem.jp', 'Océane', 'Kertess', 'lpkphx0mx6');
INSERT INTO public."User" VALUES ('zwmtwz36l77o282r', 'hcunnell3@wsj.com', 'Hélèna', 'Pahl', 'pmmynz6lb8');
INSERT INTO public."User" VALUES ('suabnl13o74w031i', 'khuchot4@cnet.com', 'Anaïs', 'Rolph', 'wumdjc4wz0');
INSERT INTO public."User" VALUES ('mcsyrw69k90m893a', 'fcopelli5@yellowbook.com', 'Marie-françoise', 'D''Adda', 'eyuipk3xe0');
INSERT INTO public."User" VALUES ('wmdpat97i44l686t', 'pdugmore6@51.la', 'Noémie', 'Hartright', 'zopsgf8nz4');
INSERT INTO public."User" VALUES ('fhgmof18s41j295n', 'kgeorger7@about.me', 'Eliès', 'Fillan', 'nhdhis3wq5');
INSERT INTO public."User" VALUES ('odpsmt51i34p539x', 'wcordel8@indiegogo.com', 'Laurélie', 'Beresfore', 'goojae5qa4');
INSERT INTO public."User" VALUES ('rqjqdp57p76w419r', 'hblissett9@hao123.com', 'Anaé', 'Simonin', 'vysxwe5lm8');
INSERT INTO public."User" VALUES ('pzgpbd57t39d363s', 'mbuttfielda@cloudflare.com', 'Josée', 'Glasard', 'ztilxa7np3');
INSERT INTO public."User" VALUES ('fncguy16y09p079o', 'sgentyb@weebly.com', 'Loïc', 'Ashby', 'btkmrw8gl1');
INSERT INTO public."User" VALUES ('knqjht86d51o896p', 'pdrowsfieldc@state.gov', 'Gisèle', 'Tathacott', 'xdqrqb5nd3');
INSERT INTO public."User" VALUES ('oejkvl89k12w562d', 'mwynrehamed@examiner.com', 'Personnalisée', 'Picker', 'tfmawo7xy7');
INSERT INTO public."User" VALUES ('ftfagh53w89t084w', 'csaterweytee@bandcamp.com', 'Cinéma', 'Caton', 'zfbdwf9zl0');
INSERT INTO public."User" VALUES ('uarkyi38f72r573s', 'dskerrettf@mysql.com', 'Crééz', 'Orteu', 'vcvmuz5xz7');
INSERT INTO public."User" VALUES ('logntb80s01y324k', 'eluckg@woothemes.com', 'Magdalène', 'Hegarty', 'eybdhe5xx7');
INSERT INTO public."User" VALUES ('jahmzo24g76s944w', 'mjouberth@yellowpages.com', 'Thérèsa', 'Densun', 'mhpmon4jt9');
INSERT INTO public."User" VALUES ('uprujb40t62r387n', 'ddumphriesi@oakley.com', 'Táng', 'Loton', 'tjbgyy0df4');
INSERT INTO public."User" VALUES ('fqlyin12z06e130g', 'mpervoej@ameblo.jp', 'Åsa', 'Pedden', 'qxwllw0sw6');
INSERT INTO public."User" VALUES ('ppzecn38y37d807s', 'kpandeyk@yellowbook.com', 'Åke', 'Bruton', 'yeesre2jn4');
INSERT INTO public."User" VALUES ('atbhyp35z83m686a', 'lrendalll@prweb.com', 'Lyséa', 'Trythall', 'gjmyqo4wo7');
INSERT INTO public."User" VALUES ('svcxub51l40q691d', 'carendm@ovh.net', 'Faîtes', 'Taggart', 'lxylpz2hu6');
INSERT INTO public."User" VALUES ('cqtajq47a97e127a', 'rcorkittn@acquirethisname.com', 'Clémentine', 'Dennert', 'iqiwae8zs1');
INSERT INTO public."User" VALUES ('fojscj13f69h621y', 'okrauseo@rakuten.co.jp', 'Célia', 'Moretto', 'ucnzqt2tt7');
INSERT INTO public."User" VALUES ('tefphy68k12v005m', 'bsmalmanp@so-net.ne.jp', 'Aurélie', 'Audiss', 'zvuiyr8rx5');
INSERT INTO public."User" VALUES ('pvowth75p53j283m', 'dlunamq@i2i.jp', 'Clémence', 'Rapinett', 'xkiwmz4jq9');
INSERT INTO public."User" VALUES ('manipu71h58q315q', 'jvaarr@devhub.com', 'Sélène', 'Penticost', 'togkrv6rk3');
INSERT INTO public."User" VALUES ('nqekjl98o73h568s', 'dmacalpines@jalbum.net', 'Intéressant', 'Tomkin', 'seckju0bb9');
INSERT INTO public."User" VALUES ('bmvllg36p94o834q', 'efacet@seattletimes.com', 'Célestine', 'Oblein', 'syzwvj4tf0');
INSERT INTO public."User" VALUES ('fpgfmz62j53v258b', 'zemmanueliu@comcast.net', 'Néhémie', 'Goscomb', 'mivlph0bd2');
INSERT INTO public."User" VALUES ('edptkz65p01q097k', 'airedellv@miibeian.gov.cn', 'Gaïa', 'Iacoviello', 'ethwso4rx1');
INSERT INTO public."User" VALUES ('rynjfz64s17v995d', 'srunnettw@feedburner.com', 'Lài', 'Cattrell', 'urxezw3ag4');
INSERT INTO public."User" VALUES ('neuxjk34h13z966f', 'ilievesleyx@spotify.com', 'Aurélie', 'Stavers', 'dlpcie3pz0');
INSERT INTO public."User" VALUES ('xztucq61z58m389z', 'dbrumbiey@google.co.uk', 'Maëlyss', 'Carling', 'ilgsmx5ps7');
INSERT INTO public."User" VALUES ('czywny38u81l971j', 'fgoublierz@cloudflare.com', 'Régine', 'Bestwick', 'otlcpa5jh8');
INSERT INTO public."User" VALUES ('uxzgka81u81f900v', 'walphonso10@shareasale.com', 'Ophélie', 'Catt', 'quysre0op4');
INSERT INTO public."User" VALUES ('eqikwg97h60x737f', 'ncoule11@nyu.edu', 'Kévina', 'Witherden', 'jqorcf5ed4');
INSERT INTO public."User" VALUES ('vrvbme37u79s356u', 'bflegg12@bandcamp.com', 'Bénédicte', 'Diemer', 'pyzife0nc1');
INSERT INTO public."User" VALUES ('ttmofu93i63l613q', 'ewalmsley13@friendfeed.com', 'Valérie', 'Stanyland', 'caxpma8am5');
INSERT INTO public."User" VALUES ('gdrkbb46q98z701s', 'ucornillot14@google.com.hk', 'Personnalisée', 'Petyakov', 'zjhxil0lg8');
INSERT INTO public."User" VALUES ('qfszmm89q52l220m', 'mkinnerk15@tiny.cc', 'Estée', 'Staries', 'upfers0ss9');
INSERT INTO public."User" VALUES ('bqczfk28i17g929z', 'gcrummy16@dell.com', 'Stéphanie', 'Wressell', 'favuca2jb5');
INSERT INTO public."User" VALUES ('bkzoam73g46m558q', 'fsargint17@bloglovin.com', 'Mélia', 'Haworth', 'dammsb4lk6');
INSERT INTO public."User" VALUES ('stdvsh45d64b133m', 'sgooders18@huffingtonpost.com', 'Styrbjörn', 'Mattielli', 'cuucwd3uu9');
INSERT INTO public."User" VALUES ('luolkp90c45z532q', 'uskoggings19@ebay.com', 'Pélagie', 'Asbrey', 'sekrjm4qr0');
INSERT INTO public."User" VALUES ('oouadv87n09g556b', 'aloomis1a@gmpg.org', 'Marie-françoise', 'Dilworth', 'dkbfit3zl4');
INSERT INTO public."User" VALUES ('tiiflh50i08r012k', 'gallday1b@moonfruit.com', 'Anaïs', 'Ceschelli', 'luyesr3kb2');
INSERT INTO public."User" VALUES ('yxnaif10d79h861s', 'rparkhouse1c@bbc.co.uk', 'Maëlle', 'Billo', 'yibyov8mn4');
INSERT INTO public."User" VALUES ('voysgf92c86v824t', 'bcheston1d@vimeo.com', 'Léonore', 'Fairlie', 'fznxdn7lc8');
INSERT INTO public."User" VALUES ('wzcyxj90a16i606i', 'gbance1e@discovery.com', 'Judicaël', 'Lovelace', 'dpeiqr9um7');
INSERT INTO public."User" VALUES ('xzkpss69s39o118k', 'rwillock1f@clickbank.net', 'Cléopatre', 'Ricardou', 'viobzp7ig5');
INSERT INTO public."User" VALUES ('lwlbtz06t04n178k', 'cbartoloma1g@thetimes.co.uk', 'Camélia', 'Beveredge', 'oncvhd5or3');
INSERT INTO public."User" VALUES ('ffooko46r26z551h', 'aadriani1h@wiley.com', 'Yè', 'Cleugh', 'vacgwc9kw9');
INSERT INTO public."User" VALUES ('yyjqbv01k20u845l', 'pbenesevich1i@washington.edu', 'Bérengère', 'Noye', 'sstfig9qt1');
INSERT INTO public."User" VALUES ('qrrqti26c27x309a', 'dlambrechts1j@mysql.com', 'Séréna', 'Diaper', 'wlkuuu0yt9');
INSERT INTO public."User" VALUES ('kmqkbq06h76p620e', 'mfillis1k@gnu.org', 'Kallisté', 'De Roberto', 'bufrkl1bx4');
INSERT INTO public."User" VALUES ('rttpav92c88i986c', 'jchetwind1l@taobao.com', 'Mélia', 'Ginty', 'clgnto3uc9');
INSERT INTO public."User" VALUES ('wgqked19i68a969p', 'meverist1m@cdbaby.com', 'Maï', 'Knotte', 'jnkfrm4ub2');
INSERT INTO public."User" VALUES ('sxpitw57x28q806x', 'sfranzoli1n@amazon.co.uk', 'Laurène', 'Soldi', 'ownqdo9lf2');
INSERT INTO public."User" VALUES ('wmmzpl91s11i675u', 'wmacellen1o@alexa.com', 'Mégane', 'Chicchelli', 'cnehfv0od2');
INSERT INTO public."User" VALUES ('jliean73w52o867k', 'chutchings1p@meetup.com', 'Erwéi', 'Rosengart', 'bmlxql9xc7');
INSERT INTO public."User" VALUES ('baepct56e87a974t', 'jsimkovich1q@wordpress.com', 'Sòng', 'O''Farris', 'eswjsk0pu5');
INSERT INTO public."User" VALUES ('wlzdfo15l37k921k', 'mbater1r@ifeng.com', 'Cécile', 'Ciccottio', 'ognnzy1dc1');
INSERT INTO public."User" VALUES ('ubukra69q08t009q', 'apersehouse1s@theglobeandmail.com', 'Åsa', 'Lorant', 'ummjig8lv8');
INSERT INTO public."User" VALUES ('bajcrv06p71n608e', 'hscoble1t@hud.gov', 'Yénora', 'Colhoun', 'xrwmyc9xb3');
INSERT INTO public."User" VALUES ('uvrdvu49e76x287b', 'brengger1u@home.pl', 'Åslög', 'MacWhan', 'kiruxo0gg2');
INSERT INTO public."User" VALUES ('pqlarh78x95c681u', 'ebassindale1v@google.co.jp', 'Yáo', 'McKeighen', 'rkpdob4ox5');
INSERT INTO public."User" VALUES ('yacktw57o65u160e', 'earmell1w@mlb.com', 'Dà', 'Moyer', 'wrpsog1uy0');
INSERT INTO public."User" VALUES ('bqiccb56b92y499z', 'etordiffe1x@qq.com', 'Östen', 'Shurlock', 'gdzcik1ds4');
INSERT INTO public."User" VALUES ('kzvgsw10w85d287d', 'mleber1y@altervista.org', 'Maëlyss', 'Bellinger', 'vwhqrj8eg1');
INSERT INTO public."User" VALUES ('lsynvw38u84v911t', 'hhapper1z@addtoany.com', 'Bérangère', 'Beagan', 'jkhctc9vb2');
INSERT INTO public."User" VALUES ('pfjlhl23k93r751x', 'aturone20@nyu.edu', 'Maëly', 'Copley', 'nduqbd1wv4');
INSERT INTO public."User" VALUES ('cimkuc40b33g393l', 'dmurrison21@tamu.edu', 'Agnès', 'Domerque', 'xcnnzw1ij5');
INSERT INTO public."User" VALUES ('eftbvw91p58g751r', 'pmacgill22@chicagotribune.com', 'Maëlyss', 'Tigwell', 'gjwdre9lk6');
INSERT INTO public."User" VALUES ('glwshl40z75c831r', 'mruperto23@virginia.edu', 'Thérèse', 'McSporon', 'emxlqr6hp2');
INSERT INTO public."User" VALUES ('yiqulp92v74x523w', 'mhandman24@marriott.com', 'Lyséa', 'Evitt', 'gfyhhq6rm4');
INSERT INTO public."User" VALUES ('lrmqmu58v72g022o', 'anoulton25@uol.com.br', 'Bénédicte', 'Sherwill', 'nslolk5dl6');
INSERT INTO public."User" VALUES ('fnksxk12z31h894r', 'matherton26@unicef.org', 'Gaétane', 'Harris', 'amtfpn9oz5');
INSERT INTO public."User" VALUES ('twftbw62l90s058g', 'pmelson27@blog.com', 'Joséphine', 'Iianon', 'asmyxq0mn8');
INSERT INTO public."User" VALUES ('luitgk17d02s129y', 'wmclean28@newyorker.com', 'Håkan', 'Roslen', 'zvoivy9va0');
INSERT INTO public."User" VALUES ('xsgrxt24x46l839x', 'rherkess29@discuz.net', 'Pénélope', 'Arne', 'sjpxuk1tj3');
INSERT INTO public."User" VALUES ('nangdr55z94b355f', 'mtofts2a@w3.org', 'Maëlys', 'Zorzini', 'uanyjc8uw9');
INSERT INTO public."User" VALUES ('nhjzcn29m02x592d', 'agwynne2b@blogtalkradio.com', 'Pénélope', 'Biddell', 'kfwbgj8wc2');
INSERT INTO public."User" VALUES ('ovqwnp69g20s733t', 'slassetter2c@google.co.uk', 'Marie-josée', 'Ambrosoli', 'baskmb5jp1');
INSERT INTO public."User" VALUES ('avixie13a53o156s', 'mmacwhirter2d@archive.org', 'Régine', 'Torrent', 'dsfdqt8ks2');
INSERT INTO public."User" VALUES ('pnxpbo53j04q846e', 'pdignum2e@gnu.org', 'Loïs', 'Hatchman', 'xrqptm7au1');
INSERT INTO public."User" VALUES ('yxocqm21i97q766s', 'msedcole2f@sfgate.com', 'Mélodie', 'Southwick', 'azgizt9to3');
INSERT INTO public."User" VALUES ('pxhofa55v38m983t', 'hkeatch2g@usda.gov', 'Laurélie', 'Darlington', 'kfpfcu5qn9');
INSERT INTO public."User" VALUES ('czkdfs79m36y373n', 'dcouser2h@answers.com', 'Desirée', 'Arnall', 'fdngau8jj4');
INSERT INTO public."User" VALUES ('oyyiyv60r36v674q', 'lmcileen2i@elpais.com', 'Zhì', 'Penfold', 'vqwsjy3jl6');
INSERT INTO public."User" VALUES ('tfebtc60g85i970i', 'jwilkie2j@telegraph.co.uk', 'Bérénice', 'Patley', 'ripgua8da0');
INSERT INTO public."User" VALUES ('njpxey61x79k993r', 'echaperlin2k@ucoz.ru', 'Vérane', 'Anthonsen', 'tutkrf4wc2');
INSERT INTO public."User" VALUES ('ldgpvv83x48q902w', 'wseagar2l@cnet.com', 'Björn', 'Ruppel', 'hkecaz8rj3');
INSERT INTO public."User" VALUES ('prhpun26y68n567z', 'agraber2m@technorati.com', 'Mahélie', 'Braisby', 'akajgp1ix7');
INSERT INTO public."User" VALUES ('ukyykl89k69e756x', 'aeckert2n@washingtonpost.com', 'Liè', 'Bjorkan', 'xrxssn9kq0');
INSERT INTO public."User" VALUES ('mqjrqc08j12u791o', 'esames2o@xing.com', 'Eléa', 'Taysbil', 'pjoacs1zi2');
INSERT INTO public."User" VALUES ('cupmtj64w01y897u', 'awasling2p@shinystat.com', 'Ruò', 'Windaybank', 'ritwxx2zz9');
INSERT INTO public."User" VALUES ('ltrebm84s57p282x', 'dtenby2q@com.com', 'Yáo', 'MacSwayde', 'pslyyq0vn6');
INSERT INTO public."User" VALUES ('gklyzl18k69z892d', 'ewaplinton2r@about.com', 'Réjane', 'Overill', 'jmrdcv9ea0');
INSERT INTO public."User" VALUES ('cpqfoy83x73u061y', 'amordin2s@wikia.com', 'Thérèsa', 'Krop', 'imghcx4sq0');
INSERT INTO public."User" VALUES ('wqyrsf81o90i239a', 'gpetersen2t@ycombinator.com', 'Görel', 'Persicke', 'snhubk2dz6');
INSERT INTO public."User" VALUES ('tyksav29f44e812h', 'elangford2u@51.la', 'Pò', 'Drever', 'synvle3kr4');
INSERT INTO public."User" VALUES ('pmxeyj22f79q939a', 'kcoots2v@privacy.gov.au', 'Björn', 'Wingate', 'yvliyn6bq4');
INSERT INTO public."User" VALUES ('pfbnul72n73x158g', 'pkoeppke2w@unesco.org', 'Yóu', 'Willacot', 'gawjsq6qe0');
INSERT INTO public."User" VALUES ('tgrgre42c92a215k', 'fkops2x@ning.com', 'Adélaïde', 'Shickle', 'egxylm4gk7');
INSERT INTO public."User" VALUES ('onfaqd30q64x811d', 'gderby2y@hud.gov', 'Méghane', 'Carwithim', 'wwxeut7zn9');
INSERT INTO public."User" VALUES ('hiinuk36j01s143y', 'bdorsett2z@redcross.org', 'Kù', 'Antonat', 'fadwtt4kx3');
INSERT INTO public."User" VALUES ('qsboqw04w60w823t', 'lboldra30@chicagotribune.com', 'Pò', 'Blazeby', 'rrkvfc9sq4');
INSERT INTO public."User" VALUES ('gtylvt32f54w241f', 'twalburn31@aboutads.info', 'Intéressant', 'Wallege', 'fypdcm9rc9');
INSERT INTO public."User" VALUES ('hpduso80y40u629k', 'acosely32@addtoany.com', 'Marie-hélène', 'Waistall', 'grttxm6gx3');
INSERT INTO public."User" VALUES ('ynosng19p33q308s', 'scoggen33@wix.com', 'Bécassine', 'Olsson', 'bbuvnb5km4');
INSERT INTO public."User" VALUES ('yaclmp50h40v408v', 'jharnes34@hp.com', 'Marie-françoise', 'Milch', 'ibziwv5wf9');
INSERT INTO public."User" VALUES ('jhpody16d43r836h', 'rstannah35@twitter.com', 'Cléopatre', 'Braunston', 'hflves5ny7');
INSERT INTO public."User" VALUES ('rqcnxn37i62m459v', 'mnewtown36@wiley.com', 'Hélène', 'Flood', 'vytdjp7hq8');
INSERT INTO public."User" VALUES ('gjphjf66h01r492f', 'skettlesting37@godaddy.com', 'Laurélie', 'McShee', 'qehteg3xf1');
INSERT INTO public."User" VALUES ('gxpvwa51v91z843a', 'gtupp38@1688.com', 'Lén', 'Peotz', 'ynptjr2sk3');
INSERT INTO public."User" VALUES ('zfvxsj03z02n196y', 'bhenaughan39@goodreads.com', 'Régine', 'Larimer', 'tfafnf3av3');
INSERT INTO public."User" VALUES ('uemrug90i48x328u', 'pdymott3a@printfriendly.com', 'Maï', 'Bamford', 'lvwriq5ol6');
INSERT INTO public."User" VALUES ('hoxjix04w78h052i', 'eharower3b@jigsy.com', 'Aurélie', 'Lowles', 'jnwilb6vc2');
INSERT INTO public."User" VALUES ('cmtohz05r99b277p', 'tforsyth3c@ifeng.com', 'Gaétane', 'Cowland', 'zghzxt4wn2');
INSERT INTO public."User" VALUES ('wkudqr77e45y324r', 'eskydall3d@wikimedia.org', 'Sélène', 'Gyorgy', 'dmayqg7sz5');
INSERT INTO public."User" VALUES ('elzydc89l17j043l', 'fsymcock3e@wikipedia.org', 'Cunégonde', 'Isherwood', 'qmrdkg4yq1');
INSERT INTO public."User" VALUES ('tdsdgt25n85t748h', 'ctreen3f@github.io', 'Garçon', 'Dilawey', 'quusly4ba1');
INSERT INTO public."User" VALUES ('hbbdtl71a93o332r', 'sdigle3g@technorati.com', 'Marie-hélène', 'Moakler', 'deqebf2ex6');
INSERT INTO public."User" VALUES ('qbdnlf82x70l206u', 'kotierney3h@yale.edu', 'Gaëlle', 'Ashman', 'lafrjw2cs7');
INSERT INTO public."User" VALUES ('qnhjhl27o60s734b', 'cdomoni3i@biblegateway.com', 'Jú', 'Kloisner', 'ofztkg1nw9');
INSERT INTO public."User" VALUES ('ubhgqk91a47l249w', 'bcopins3j@pbs.org', 'Pélagie', 'Olech', 'apxikz3uv9');
INSERT INTO public."User" VALUES ('yfbomx14j01i414q', 'ubullcock3k@narod.ru', 'Åsa', 'Godin', 'wmjxdk9hi4');
INSERT INTO public."User" VALUES ('rhtipe18q96t811w', 'jarkil3l@mtv.com', 'Françoise', 'Kenset', 'jnzses3mr7');
INSERT INTO public."User" VALUES ('rbmdmz41d86m087i', 'cwimlett3m@odnoklassniki.ru', 'Åke', 'Boal', 'fnqnfi0cv3');
INSERT INTO public."User" VALUES ('inkkug20e93g176d', 'fprantoni3n@unesco.org', 'Solène', 'Litherland', 'rymbeg0gk0');
INSERT INTO public."User" VALUES ('fclxnj72q03i675i', 'rmastrantone3o@linkedin.com', 'Esbjörn', 'Northcote', 'zfpatt5dn1');
INSERT INTO public."User" VALUES ('dcfuye94g06f217q', 'jmancell3p@businessweek.com', 'Eugénie', 'Vanacci', 'xqzkxc3fg2');
INSERT INTO public."User" VALUES ('sgtzkv15v56p995o', 'zdurham3q@biblegateway.com', 'Andrée', 'Strongman', 'lsdgqa6cb8');
INSERT INTO public."User" VALUES ('uyheqc53x63q262p', 'kstiff3r@netlog.com', 'Agnès', 'Ropkes', 'qgnbzh8uj4');
INSERT INTO public."User" VALUES ('mtrzyg07g76q856p', 'fhartly3s@state.tx.us', 'Örjan', 'Walkington', 'mjkjtj4xl4');
INSERT INTO public."User" VALUES ('fmzpzf28z43j004o', 'mluten3t@google.cn', 'Aloïs', 'Ure', 'cnswvt0vp7');
INSERT INTO public."User" VALUES ('hemeot50m73i573g', 'ncolten3u@domainmarket.com', 'Andrée', 'Grewer', 'qlhjlw7wt7');
INSERT INTO public."User" VALUES ('uqzngd89k68o039y', 'vwhillock3v@marriott.com', 'Naéva', 'Cauley', 'tnuodd7mk4');
INSERT INTO public."User" VALUES ('bjblph06j16d245i', 'jfrounks3w@discuz.net', 'Yáo', 'Zecchini', 'vjweeq9bi1');
INSERT INTO public."User" VALUES ('hgbzrh16u63i171y', 'rcreaser3x@weibo.com', 'Dorothée', 'Arbuckel', 'lkbere1cn7');
INSERT INTO public."User" VALUES ('biyovl42e99y464i', 'ccrannell3y@pbs.org', 'Annotés', 'Breach', 'ruiqdi3bf7');
INSERT INTO public."User" VALUES ('mryhnm61j46c350f', 'wfitzgilbert3z@flavors.me', 'Eléonore', 'Taill', 'ckhbiv9lf6');
INSERT INTO public."User" VALUES ('vhoywi16t82l695z', 'abosworth40@wix.com', 'Zhì', 'Garstang', 'nciuep3lb3');
INSERT INTO public."User" VALUES ('ybfysq79y79l393y', 'bhoudmont41@aboutads.info', 'Pål', 'Wigglesworth', 'febuhd3kq2');
INSERT INTO public."User" VALUES ('dtofbi34p99y365o', 'skiddey42@vkontakte.ru', 'Lén', 'Triner', 'lytseq5mu1');
INSERT INTO public."User" VALUES ('vljdev57g03y090c', 'fdurdle43@mtv.com', 'Loïca', 'Verchambre', 'weuluk1pz4');
INSERT INTO public."User" VALUES ('sszezk30j07n929w', 'gcouser44@slashdot.org', 'Wá', 'Bayle', 'tfyxjh6pv1');
INSERT INTO public."User" VALUES ('ktzici06x98f179v', 'aforrington45@goo.ne.jp', 'Gérald', 'Hodjetts', 'zcoske6op3');
INSERT INTO public."User" VALUES ('rhoejr57a02m896n', 'gwanless46@webmd.com', 'Andréa', 'Craker', 'orgqck6tn6');
INSERT INTO public."User" VALUES ('xxncni20g41k547d', 'wbenian47@state.tx.us', 'Loïs', 'Spurdens', 'suhxhb8lm2');
INSERT INTO public."User" VALUES ('qohrak59c31f972s', 'aarkcoll48@bizjournals.com', 'Dafnée', 'Hickeringill', 'fykudj9tk1');
INSERT INTO public."User" VALUES ('diojtz71g09k482b', 'mchuck49@tinypic.com', 'Annotée', 'Verring', 'flficf0wu2');
INSERT INTO public."User" VALUES ('twaahz52e36j670l', 'lcalderbank4a@unblog.fr', 'Nadège', 'Biggs', 'lxxgai0cu9');
INSERT INTO public."User" VALUES ('pqbyjh71p95u332w', 'lsangra4b@smugmug.com', 'Marie-noël', 'Cawsy', 'skxczi5cd7');
INSERT INTO public."User" VALUES ('dummes59z00c736a', 'rwarlaw4c@nyu.edu', 'Clélia', 'Oliveti', 'phhpjm0ju1');
INSERT INTO public."User" VALUES ('gkwlxp24b62o116h', 'rclarke4d@dedecms.com', 'Yú', 'Wilde', 'cgmirt2si8');
INSERT INTO public."User" VALUES ('otsesl75v45y509t', 'bhanne4e@desdev.cn', 'Océanne', 'Pinsent', 'qibfgh2ea4');
INSERT INTO public."User" VALUES ('zjdfwr79p98y382c', 'uclail4f@cnet.com', 'Loïca', 'Pawelek', 'stmggw9xx8');
INSERT INTO public."User" VALUES ('xqtndg34u63l734v', 'operham4g@wordpress.com', 'Illustrée', 'Woodberry', 'lasnkd2mr2');
INSERT INTO public."User" VALUES ('mkejzs70t73i858j', 'pkeal4h@who.int', 'Hélèna', 'Rubinlicht', 'xuntmf0in1');
INSERT INTO public."User" VALUES ('vgfuyu57e66b290z', 'ituffley4i@arstechnica.com', 'Maéna', 'Junkison', 'miucxq2yn4');
INSERT INTO public."User" VALUES ('qftkaz11f56i050v', 'fdrewclifton4j@freewebs.com', 'Mårten', 'Loughrey', 'lacbjf3ms7');
INSERT INTO public."User" VALUES ('vsovbt06e82k566o', 'hfawloe4k@soup.io', 'Mélinda', 'Firmager', 'avjzwj1nj6');
INSERT INTO public."User" VALUES ('ibzags87y19q846t', 'spetris4l@guardian.co.uk', 'Torbjörn', 'Skehens', 'nglfvb2wx3');
INSERT INTO public."User" VALUES ('imccnp09o38x381t', 'gcurnick4m@rediff.com', 'Dafnée', 'Grayne', 'cwtngr6dm7');
INSERT INTO public."User" VALUES ('qdwjuu36n94c501h', 'amcnickle4n@wisc.edu', 'Médiamass', 'Beckers', 'wsjmek9aq8');
INSERT INTO public."User" VALUES ('mqejhb39g21s907j', 'fhayto4o@imgur.com', 'Aloïs', 'Beddoe', 'dxcfva3sf0');
INSERT INTO public."User" VALUES ('xwwjzo00v04h752d', 'oiashvili4p@lulu.com', 'Loïca', 'Coleby', 'qnxtos1xb9');
INSERT INTO public."User" VALUES ('vpfjqd29o36m152p', 'scolnet4q@desdev.cn', 'Célestine', 'Carrington', 'wembqk8yw8');
INSERT INTO public."User" VALUES ('kmzeuu19a52h131r', 'cjurries4r@indiegogo.com', 'Bérangère', 'Dykes', 'pnasiq6nx9');
INSERT INTO public."User" VALUES ('vvcybr21z15j371t', 'doflaherty4s@jiathis.com', 'Åslög', 'Sacco', 'plcoxb2nr8');
INSERT INTO public."User" VALUES ('fymicl07g86g311z', 'gbaudon4t@abc.net.au', 'Personnalisée', 'Knevet', 'bdukmi7jk3');
INSERT INTO public."User" VALUES ('pedxbe91i75m176m', 'dkedwell4u@youtube.com', 'Publicité', 'Poate', 'xrzkaf0ed1');
INSERT INTO public."User" VALUES ('sfhdna30o52a171q', 'lvivyan4v@mozilla.com', 'Valérie', 'Fieldsend', 'erwkpt4lx2');
INSERT INTO public."User" VALUES ('mkoamp49f47t875o', 'zcupitt4w@disqus.com', 'Mélanie', 'Flobert', 'caoanw1pj3');
INSERT INTO public."User" VALUES ('kqegmg32m29k935w', 'sdobing4x@utexas.edu', 'Kévina', 'Brunt', 'ztiqaa4tv0');
INSERT INTO public."User" VALUES ('xlzrzk74e92m608i', 'eogilby4y@quantcast.com', 'Publicité', 'Dackombe', 'qytzvh8fn8');
INSERT INTO public."User" VALUES ('sonctd56f83b983b', 'mbolstridge4z@nps.gov', 'Estée', 'Deeman', 'fydcrs1jj8');
INSERT INTO public."User" VALUES ('dtwigz64e10p083m', 'jrowbrey50@seattletimes.com', 'Adélie', 'Congram', 'pzscog0zo3');
INSERT INTO public."User" VALUES ('jijwdf38e90k474z', 'kstrodder51@biglobe.ne.jp', 'Kallisté', 'Farnan', 'uydeez7ow7');
INSERT INTO public."User" VALUES ('vanpud49z85p246z', 'rfriedman52@deviantart.com', 'Annotée', 'Sposito', 'dibvbh4lv7');
INSERT INTO public."User" VALUES ('mpucqz16x16h338y', 'alegon53@mapy.cz', 'Thérèsa', 'Pilkington', 'jwnasg9sf6');
INSERT INTO public."User" VALUES ('bvjmam04c45s056z', 'cparvin54@quantcast.com', 'Camélia', 'Syer', 'ayaqwo2yl9');
INSERT INTO public."User" VALUES ('xhyhhr51j99t588v', 'mgrinley55@cam.ac.uk', 'Eléa', 'McAllister', 'tuslci9ci4');
INSERT INTO public."User" VALUES ('nvjvry06k80y671d', 'dtorra56@geocities.jp', 'Gaïa', 'Ivimy', 'avptru7sn2');
INSERT INTO public."User" VALUES ('qgirmu64l92v236a', 'lboylin57@theatlantic.com', 'Göran', 'Hawkeridge', 'nmajhr5xo5');
INSERT INTO public."User" VALUES ('jjnkrf56p52e998v', 'xwhistlecraft58@ask.com', 'Maï', 'O''Sherrin', 'acyith6kz7');
INSERT INTO public."User" VALUES ('uvykyg86q63m719o', 'arickman59@illinois.edu', 'Geneviève', 'Goodbody', 'vxlmjs7tt8');
INSERT INTO public."User" VALUES ('hionfe08j30s838l', 'nmennear5a@godaddy.com', 'Maëline', 'Clorley', 'yhvnvc4mc1');
INSERT INTO public."User" VALUES ('wnfbnc70h73p291z', 'tolder5b@ning.com', 'Laurène', 'Broadfoot', 'vczmlw5im5');
INSERT INTO public."User" VALUES ('xwtrps80s90o891n', 'jtonn5c@gizmodo.com', 'Rébecca', 'Eighteen', 'vzpzsu2la3');
INSERT INTO public."User" VALUES ('ajidlo43u61p099h', 'bmccaffrey5d@pbs.org', 'Esbjörn', 'Hubbart', 'shthob7ff4');
INSERT INTO public."User" VALUES ('qqlgsj19c62a369o', 'kleyninye5e@twitter.com', 'Annotée', 'Iacobetto', 'oxqfud3ee3');
INSERT INTO public."User" VALUES ('xdywvp61j99w442z', 'kcumberledge5f@topsy.com', 'Félicie', 'Neild', 'ekwpss8cm2');
INSERT INTO public."User" VALUES ('whoxlw51d31i855p', 'lwicklen5g@fda.gov', 'Adèle', 'Cherrison', 'xutgwd5kg8');
INSERT INTO public."User" VALUES ('jqowvl10i94z886o', 'rjewkes5h@google.com.au', 'Dorothée', 'Buckerfield', 'lwvqls2ay8');
INSERT INTO public."User" VALUES ('nzqznh45k76m471w', 'mwelband5i@wikia.com', 'Maïwenn', 'Dumphy', 'requvq2xf6');
INSERT INTO public."User" VALUES ('gaflzy22j28d259r', 'icolchett5j@jugem.jp', 'Géraldine', 'Creeghan', 'sidpvl1ij6');
INSERT INTO public."User" VALUES ('lxeorf85u39l996y', 'nshepherd5k@deviantart.com', 'Gisèle', 'Guiraud', 'cmukfk5xj4');
INSERT INTO public."User" VALUES ('iyfais63g07q982h', 'cdyers5l@ifeng.com', 'Aí', 'Gussin', 'ltypqj2be7');
INSERT INTO public."User" VALUES ('idurgs16p07z227n', 'mgarfath5m@tamu.edu', 'Léandre', 'Deering', 'zgvdlq0nm0');
INSERT INTO public."User" VALUES ('nuztap81a26s855n', 'mtitlow5n@deviantart.com', 'Rébecca', 'Smallcombe', 'ajpdzs7sq5');
INSERT INTO public."User" VALUES ('pkzhol78p03a056s', 'eworley5o@reverbnation.com', 'Séréna', 'Cornelisse', 'sutkqe7yf9');
INSERT INTO public."User" VALUES ('rwknhd54x94p737d', 'csmithe5p@state.tx.us', 'Naëlle', 'Drillingcourt', 'pmfigq7uk1');
INSERT INTO public."User" VALUES ('bbgcje71p25a045f', 'dbelward5q@facebook.com', 'Maïwenn', 'Cowdery', 'gxkzag8nt8');
INSERT INTO public."User" VALUES ('lxcpuv90t78u605u', 'lnorthwood5r@miibeian.gov.cn', 'Illustrée', 'Codlin', 'dgsekb4bk1');
INSERT INTO public."User" VALUES ('xrbejq26q15p312m', 'dwalder5s@google.nl', 'Åke', 'Jori', 'xhaxeb0vu2');
INSERT INTO public."User" VALUES ('gbpmca29b68x702b', 'jextal5t@g.co', 'Personnalisée', 'Noyes', 'sjfxcp4dd6');
INSERT INTO public."User" VALUES ('cykmvq17a37o337t', 'mdevonald5u@infoseek.co.jp', 'Dorothée', 'Simnell', 'jkkgez7ev9');
INSERT INTO public."User" VALUES ('mhoecj38j36w784x', 'sbullin5v@wikia.com', 'Mårten', 'Ansley', 'ftmjta5qs4');
INSERT INTO public."User" VALUES ('wiygan57q71s213z', 'zbellis5w@sphinn.com', 'Andréanne', 'Ibbison', 'bcugep9ev2');
INSERT INTO public."User" VALUES ('biakfr95f91j747v', 'lgerb5x@arstechnica.com', 'Adélaïde', 'Mitskevich', 'ronvqa6ug9');
INSERT INTO public."User" VALUES ('zawssc20m93t610i', 'jbrownsett5y@theguardian.com', 'Joséphine', 'Lazell', 'emhqui0zq8');
INSERT INTO public."User" VALUES ('vrlbxm76c74p195v', 'idrewitt5z@over-blog.com', 'Mélina', 'Birrell', 'gaxioz0yy2');
INSERT INTO public."User" VALUES ('vydrwa78d74w280l', 'krussen60@youtube.com', 'Béatrice', 'Antony', 'numbkp9xf1');
INSERT INTO public."User" VALUES ('juqqvq79q57c343f', 'cbannon61@webmd.com', 'Fèi', 'Goold', 'wkagcj1ts1');
INSERT INTO public."User" VALUES ('rwfaqv29l60p314v', 'lchallicum62@google.com.hk', 'Aí', 'Jencey', 'uqihzb3sl4');
INSERT INTO public."User" VALUES ('mrnduz12x16z223d', 'estearns63@nasa.gov', 'Thérèsa', 'Jouandet', 'whohiw8ws1');
INSERT INTO public."User" VALUES ('krpijq65x88a203e', 'tfreddi64@bigcartel.com', 'Pål', 'Caiger', 'tptvcq3mn0');
INSERT INTO public."User" VALUES ('djenxl66m93q807q', 'chanshaw65@census.gov', 'Gisèle', 'Gagg', 'hcrmcn5hi7');
INSERT INTO public."User" VALUES ('ffivvv85v77v236p', 'dshepton66@nature.com', 'Ráo', 'Dysert', 'vyornp3ur4');
INSERT INTO public."User" VALUES ('ymcvcx20r05m719x', 'mbankhurst67@pbs.org', 'Almérinda', 'Gartsyde', 'wmiefx6ca2');
INSERT INTO public."User" VALUES ('aqlrcu77s93p743t', 'llidierth68@sbwire.com', 'Marie-josée', 'Bimson', 'xsgiun3ai2');
INSERT INTO public."User" VALUES ('wfbltk51o88k950q', 'mveryard69@angelfire.com', 'Börje', 'Giraldon', 'qpoorj6tm6');
INSERT INTO public."User" VALUES ('yzrwhf69b44t534k', 'kmattsson6a@rediff.com', 'Léane', 'Nind', 'ueyuup7xv4');
INSERT INTO public."User" VALUES ('ftvczh65w43l415y', 'tgorch6b@chron.com', 'Gaïa', 'Galilee', 'esohpj7wf8');
INSERT INTO public."User" VALUES ('xfzwro97m90s944f', 'ealcorn6c@shareasale.com', 'Cinéma', 'Guidelli', 'kinhyy2wr8');
INSERT INTO public."User" VALUES ('cuskrn57l47e061a', 'cmartignoni6d@myspace.com', 'Garçon', 'Evetts', 'hzkdpb1do2');
INSERT INTO public."User" VALUES ('pvesli24i05o628x', 'eselcraig6e@alibaba.com', 'Cécilia', 'McMarquis', 'dagsye5zs2');
INSERT INTO public."User" VALUES ('hescfp63d24r371j', 'emethuen6f@yellowpages.com', 'Célestine', 'Andreuzzi', 'fgekba3fj8');
INSERT INTO public."User" VALUES ('qkuolt71j22g986z', 'gtrotter6g@buzzfeed.com', 'Méghane', 'Van Der Hoog', 'tcmymh1ah4');
INSERT INTO public."User" VALUES ('tfbepd27f25z456b', 'ablackall6h@gizmodo.com', 'Uò', 'Cino', 'sjwhpw7xp3');
INSERT INTO public."User" VALUES ('igtgry79x29q919l', 'babbie6i@spotify.com', 'Gaïa', 'Eustace', 'bodqik1wt6');
INSERT INTO public."User" VALUES ('kwhebi32u53k737a', 'trudman6j@merriam-webster.com', 'Daphnée', 'Bisiker', 'nlwhna2an4');
INSERT INTO public."User" VALUES ('hatoqy71b49z740w', 'abendik6k@springer.com', 'Lorène', 'Angliss', 'njthri3hw0');
INSERT INTO public."User" VALUES ('dbaiib39k29d734g', 'dholleran6l@soup.io', 'Lauréna', 'Crownshaw', 'wfshal3jr9');
INSERT INTO public."User" VALUES ('tlxmtp31i77i820m', 'rrobelet6m@barnesandnoble.com', 'Maïté', 'Giannassi', 'fcqwqn5mv1');
INSERT INTO public."User" VALUES ('fcopvg30n16c914c', 'dmaccook6n@xing.com', 'Yè', 'Caiger', 'wxigbp4kr4');
INSERT INTO public."User" VALUES ('hnqwqq55k83w052b', 'lwasielewski6o@wix.com', 'Lauréna', 'Caddens', 'wlzlxh3zy4');
INSERT INTO public."User" VALUES ('naxcfe43n87k487q', 'lkowal6p@google.com', 'Méline', 'Larwell', 'dstadv3tn5');
INSERT INTO public."User" VALUES ('bdgvho42a00g362s', 'cstorr6q@examiner.com', 'Anaëlle', 'Winskill', 'rnegqq0dt1');
INSERT INTO public."User" VALUES ('vfhkee99w33c637c', 'ccoffey6r@vkontakte.ru', 'Lài', 'Kybert', 'rabuxf3xj5');
INSERT INTO public."User" VALUES ('ehutcz88v97t154b', 'rroller6s@marketwatch.com', 'Clémence', 'Baumann', 'nlzfvi5ia1');
INSERT INTO public."User" VALUES ('ygjdou64c73y262u', 'fsleeny6t@ning.com', 'André', 'Maddinon', 'qqvmlx5fh3');
INSERT INTO public."User" VALUES ('qkmoru80d64m261f', 'xcameli6u@va.gov', 'Andréa', 'Penner', 'xllpwe0uk1');
INSERT INTO public."User" VALUES ('zwoqwv41d02z602d', 'hdallosso6v@chronoengine.com', 'Erwéi', 'Messager', 'nldqcu8lq1');
INSERT INTO public."User" VALUES ('ekasqk57f23p760q', 'mbroke6w@delicious.com', 'Illustrée', 'Muckersie', 'jiiszv1an3');
INSERT INTO public."User" VALUES ('tskzol42h43s526q', 'oharm6x@domainmarket.com', 'Bénédicte', 'Sazio', 'bqhgji4vu5');
INSERT INTO public."User" VALUES ('nxwquf98b90k316c', 'tlambrecht6y@zimbio.com', 'Aloïs', 'Gillhespy', 'wyhwxw7ff4');
INSERT INTO public."User" VALUES ('xfddve83g88c486m', 'lbambridge6z@pagesperso-orange.fr', 'Frédérique', 'Tustin', 'uaehbr2pg8');
INSERT INTO public."User" VALUES ('awsrho41j56r866f', 'rsarra70@icio.us', 'Maëline', 'Tranckle', 'sqvsvp2rk7');
INSERT INTO public."User" VALUES ('hznhdf48y67b150x', 'iharlock71@edublogs.org', 'Véronique', 'Sillito', 'xzncht9qp3');
INSERT INTO public."User" VALUES ('cywalr05h91d484m', 'esterke72@yale.edu', 'Wá', 'Deverill', 'ctepkn4tr9');
INSERT INTO public."User" VALUES ('wqutbg42d49n864u', 'floadsman73@ameblo.jp', 'Dafnée', 'McCreedy', 'jfvadf6ae9');
INSERT INTO public."User" VALUES ('lvjjgd59d94x491s', 'dbrummell74@dedecms.com', 'Örjan', 'Bumphrey', 'zfbedr5zm7');
INSERT INTO public."User" VALUES ('kukbjl22q01s531a', 'ebrockherst75@washingtonpost.com', 'Lóng', 'Hurdis', 'vqkorc9pm5');
INSERT INTO public."User" VALUES ('niovlv39v26f854w', 'llay76@tripadvisor.com', 'Yè', 'Peet', 'cflxgl9ry4');
INSERT INTO public."User" VALUES ('uatgms19s89r462p', 'lpatty77@hatena.ne.jp', 'Alizée', 'Tonnesen', 'cdcsmu3na1');
INSERT INTO public."User" VALUES ('khftlv16s49y992m', 'dalfonsini78@dropbox.com', 'Intéressant', 'Mattioni', 'lkrbzj0lz6');
INSERT INTO public."User" VALUES ('aeuvnp64l72c668r', 'bhalliwell79@jugem.jp', 'Gaïa', 'Lantaff', 'jtzheb9wc7');
INSERT INTO public."User" VALUES ('gdvioy68s73p937c', 'sbromwich7a@cocolog-nifty.com', 'Börje', 'Marquet', 'wtujhe5tw6');
INSERT INTO public."User" VALUES ('gcjhcy92g72e134i', 'cdecristofalo7b@utexas.edu', 'Liè', 'Keneleyside', 'zinxvi6ff7');
INSERT INTO public."User" VALUES ('wrtcwb68k39k579d', 'hstandell7c@unesco.org', 'Börje', 'Schruyer', 'twfccx2jm0');
INSERT INTO public."User" VALUES ('hqugrl00r46y292v', 'kstawell7d@scribd.com', 'Vérane', 'Mattocks', 'wrvvnu1oc0');
INSERT INTO public."User" VALUES ('hwvicy98q94a895c', 'gwallbridge7e@w3.org', 'Desirée', 'Andrusov', 'grmblv6ti7');
INSERT INTO public."User" VALUES ('kphrev36h15a238y', 'thastie7f@hp.com', 'Séréna', 'Ivatt', 'ghdcud6da7');
INSERT INTO public."User" VALUES ('greraz77c43v123w', 'kcammacke7g@vk.com', 'Béatrice', 'Kelberman', 'slsxcn8rf5');
INSERT INTO public."User" VALUES ('qkibkx39w03u789n', 'rleer7h@forbes.com', 'Håkan', 'Spriggen', 'rhvqxf1fd5');
INSERT INTO public."User" VALUES ('uwqdhc51p87l159g', 'alages7i@dailymail.co.uk', 'Josée', 'Laugharne', 'iapzwi7jb7');
INSERT INTO public."User" VALUES ('eyenlv61m21t993v', 'nblaszczak7j@tinyurl.com', 'Måns', 'Vagg', 'ldycri1sn5');
INSERT INTO public."User" VALUES ('ivxmmi14g70a470t', 'nthursfield7k@ehow.com', 'Andrée', 'Pleuman', 'usdnji9vd2');
INSERT INTO public."User" VALUES ('jzbcls28a49q907j', 'jcoule7l@lulu.com', 'Mélia', 'Comolli', 'clwzbh5ts0');
INSERT INTO public."User" VALUES ('wuzuqr03m90r746d', 'tbarrick7m@nifty.com', 'Zhì', 'Bell', 'psdqqt7hj1');
INSERT INTO public."User" VALUES ('lagtql33n53n104g', 'yjeyness7n@yellowbook.com', 'Vénus', 'Strongman', 'spuzpk2le8');
INSERT INTO public."User" VALUES ('lqnfji78r29w466g', 'cmityushkin7o@plala.or.jp', 'Mårten', 'Jurkowski', 'exwsda9ap3');
INSERT INTO public."User" VALUES ('nykaio89f69v276n', 'beasterbrook7p@freewebs.com', 'Mélys', 'Tatam', 'weiodz6cu1');
INSERT INTO public."User" VALUES ('wepwcz48i94b368x', 'mnare7q@ftc.gov', 'Cécilia', 'Savile', 'luobab4hl1');
INSERT INTO public."User" VALUES ('ezkwii39z32c350a', 'carnold7r@issuu.com', 'Estève', 'Samson', 'krrxsm0fc2');
INSERT INTO public."User" VALUES ('fuvpvc77f80c928n', 'zbramsom7s@ycombinator.com', 'Maïlys', 'Broggelli', 'ksyyei3om4');
INSERT INTO public."User" VALUES ('ncptgj96i29t348q', 'greddyhoff7t@ihg.com', 'Mén', 'Lowson', 'uidzkx7wv1');
INSERT INTO public."User" VALUES ('ddofvr13t81o964o', 'colman7u@sohu.com', 'Agnès', 'Ditch', 'xzqguu5ci5');
INSERT INTO public."User" VALUES ('zpkyga71s78b592a', 'amaciaszek7v@sbwire.com', 'Maëline', 'Testro', 'dxumha8ci0');
INSERT INTO public."User" VALUES ('fyesdl93b77q178e', 'szanetti7w@ft.com', 'Sòng', 'Crowdson', 'ggatfy7ke5');
INSERT INTO public."User" VALUES ('zfydjk68n10u660n', 'ztaplow7x@odnoklassniki.ru', 'Clémentine', 'Nickoles', 'jhzgxv4pm3');
INSERT INTO public."User" VALUES ('hynsmy79h38a152r', 'dtyrie7y@gov.uk', 'Cléopatre', 'Sagar', 'pcppkq1rm1');
INSERT INTO public."User" VALUES ('aejawf83e52u311t', 'boldershaw7z@yale.edu', 'Marlène', 'Maydwell', 'mqicun8hz1');
INSERT INTO public."User" VALUES ('ltxtuz97v18e713t', 'aamps80@ucsd.edu', 'Bérénice', 'Fuchs', 'vlevzm8cp9');
INSERT INTO public."User" VALUES ('xxkotd24d06f724r', 'cyokley81@posterous.com', 'Eléonore', 'Clatworthy', 'yupvhd7us3');
INSERT INTO public."User" VALUES ('xasayf43w42h467x', 'jweson82@chron.com', 'Pål', 'Weine', 'psfaah5hq0');
INSERT INTO public."User" VALUES ('jvfulu96x84x763y', 'ibertome83@amazonaws.com', 'Maëlys', 'Bycraft', 'syyfcp7xv1');
INSERT INTO public."User" VALUES ('stsjzy35j70y546p', 'gtidball84@parallels.com', 'Åslög', 'Breydin', 'zhbhur3xc6');
INSERT INTO public."User" VALUES ('nqwqhn41z22s088t', 'cwapplington85@mapy.cz', 'Gwenaëlle', 'Huffey', 'wuigvz1ku5');
INSERT INTO public."User" VALUES ('iyhzuq98f66a904e', 'ahamber86@dot.gov', 'Marlène', 'Gerhartz', 'byjpij2to6');
INSERT INTO public."User" VALUES ('dpjzqs24p51l454d', 'cwoolerton87@who.int', 'Méline', 'Crackett', 'nlwlic4wz6');
INSERT INTO public."User" VALUES ('zrosek95l32p208a', 'bhollingsby88@usnews.com', 'Maëlla', 'Formoy', 'wtzoyb0nu6');
INSERT INTO public."User" VALUES ('ksjjng76l79z938v', 'lness89@furl.net', 'Cécile', 'Stiffkins', 'pplkhl5qc1');
INSERT INTO public."User" VALUES ('tiwuaw40c19x997m', 'fferrer8a@goo.ne.jp', 'Aí', 'Claypoole', 'wojbup4zp9');
INSERT INTO public."User" VALUES ('cdnvpr44a27s464z', 'bsouthgate8b@histats.com', 'Ruò', 'Wildbore', 'xxzeow6rn0');
INSERT INTO public."User" VALUES ('nalblh07s15a394h', 'smarlor8c@t-online.de', 'Yáo', 'Couves', 'yxnkcf1dl3');
INSERT INTO public."User" VALUES ('bwqsww05c26r955r', 'wbrockelsby8d@jugem.jp', 'Mårten', 'Linfield', 'jwflts6ds9');
INSERT INTO public."User" VALUES ('porhvy84b09i382t', 'dhuot8e@chronoengine.com', 'Alizée', 'Noblet', 'poszxs0cm8');
INSERT INTO public."User" VALUES ('fegqwm32v83x267h', 'mvalerius8f@etsy.com', 'Mårten', 'Semechik', 'dvsllk2qr2');
INSERT INTO public."User" VALUES ('izynbo84d65q336r', 'jwalhedd8g@pen.io', 'Magdalène', 'Dotson', 'javymm2tk9');
INSERT INTO public."User" VALUES ('vwpxxv78e93p501z', 'kmasselin8h@123-reg.co.uk', 'Marlène', 'Peschka', 'jbcqsq9lz6');
INSERT INTO public."User" VALUES ('pibudt78r16a447a', 'hbraznell8i@hc360.com', 'Gaëlle', 'Folder', 'xtppda3ga6');
INSERT INTO public."User" VALUES ('tbgjbc08x86e721k', 'mraulin8j@wunderground.com', 'Josée', 'Puddicombe', 'ebnwtm4ht3');
INSERT INTO public."User" VALUES ('wpuyfq29e69j026f', 'ocatt8k@timesonline.co.uk', 'Camélia', 'Enbury', 'tcjmua6xv7');
INSERT INTO public."User" VALUES ('iykdnd08g65v463j', 'cluety8l@dailymotion.com', 'Laurène', 'Sapseed', 'dqacvk8sz4');
INSERT INTO public."User" VALUES ('uiklzr48g15x639d', 'jwaycot8m@cisco.com', 'Bénédicte', 'Wheldon', 'ilmopl6ny3');
INSERT INTO public."User" VALUES ('bmvjla65g93v445i', 'olawranson8n@yahoo.co.jp', 'Maëlann', 'McAlees', 'muulho4au3');
INSERT INTO public."User" VALUES ('yfordi93z47d950m', 'kgetsham8o@umich.edu', 'Lorène', 'Pentycross', 'gcpasj7nu4');
INSERT INTO public."User" VALUES ('bvzhtv80u41r537e', 'kjodrelle8p@vk.com', 'Méline', 'Pretswell', 'ilmngm8vx6');
INSERT INTO public."User" VALUES ('zdmwue93v95e125w', 'kbedome8q@oaic.gov.au', 'Personnalisée', 'Matashkin', 'lysmzb5qj2');
INSERT INTO public."User" VALUES ('grdgnl27o09y843s', 'tlees8r@wordpress.org', 'Crééz', 'Hartless', 'vafbdo0xw1');
INSERT INTO public."User" VALUES ('cbpecz68u53r533h', 'cladbury8s@comsenz.com', 'Eloïse', 'Di Carli', 'nlbyep6wh6');
INSERT INTO public."User" VALUES ('rukqys85i03o655g', 'wgormally8t@yandex.ru', 'Mélinda', 'Cundy', 'rufnpk3nj3');
INSERT INTO public."User" VALUES ('rlagag37v44g548h', 'eerrowe8u@ucsd.edu', 'Östen', 'Zavattiero', 'gajady2bn8');
INSERT INTO public."User" VALUES ('ouqxas01i91i264z', 'ltripett8v@upenn.edu', 'Aloïs', 'Kingswood', 'ohvssq3fm4');
INSERT INTO public."User" VALUES ('wgplnz82i26j138e', 'efawdrie8w@merriam-webster.com', 'Marie-thérèse', 'Mangeot', 'yqnmsa1jo8');
INSERT INTO public."User" VALUES ('lwolgv30o68l904b', 'dclemitt8x@hibu.com', 'Vénus', 'Werny', 'sztaio4ud1');
INSERT INTO public."User" VALUES ('apyxwu54a07y455w', 'gtop8y@myspace.com', 'Annotés', 'Botley', 'svwura9xw3');
INSERT INTO public."User" VALUES ('eitriv67y12p862u', 'kcodd8z@ft.com', 'Garçon', 'Moss', 'opnkot1rv7');
INSERT INTO public."User" VALUES ('hkuwbk86w12o138c', 'aguidetti90@blogspot.com', 'Gaétane', 'Gleaves', 'cvklvu2wf0');
INSERT INTO public."User" VALUES ('jlvskz98i56n162p', 'bcreedland91@indiegogo.com', 'Lorène', 'Wrintmore', 'mxuxsu4ij8');
INSERT INTO public."User" VALUES ('pttjec03n88j479e', 'danthoney92@aboutads.info', 'Kù', 'Willoughley', 'krrdrb9kt1');
INSERT INTO public."User" VALUES ('iuemjb93v11o917t', 'snary93@europa.eu', 'Lyséa', 'Baudinot', 'cimsve6nl5');
INSERT INTO public."User" VALUES ('esaphh68t77x479l', 'lisaq94@techcrunch.com', 'Léonie', 'Dispencer', 'kdebon7il3');
INSERT INTO public."User" VALUES ('scydrw97y70z667z', 'tduffie95@about.com', 'Hélène', 'Benstead', 'jgauky0gf1');
INSERT INTO public."User" VALUES ('aihidc26u00q341f', 'cdadge96@cam.ac.uk', 'Bécassine', 'Shute', 'qtzbas6iu0');
INSERT INTO public."User" VALUES ('fftdia16t21b475s', 'rlogsdail97@gizmodo.com', 'Dorothée', 'McElory', 'cfoxjk5gl9');
INSERT INTO public."User" VALUES ('fvyqbg06s80i819y', 'ctrahar98@naver.com', 'Laïla', 'Milmore', 'tzdgee2ow9');
INSERT INTO public."User" VALUES ('jnxppz36y70k810k', 'cmackereth99@sogou.com', 'Sòng', 'Carratt', 'wzjlcp6ho1');
INSERT INTO public."User" VALUES ('knwpnh76n28c198c', 'abebbell9a@yandex.ru', 'Ophélie', 'Heinonen', 'hnqilp7io4');
INSERT INTO public."User" VALUES ('nulsti82t25n734q', 'lduffit9b@dyndns.org', 'Agnès', 'Costley', 'opbkdy3cu9');
INSERT INTO public."User" VALUES ('bncffp20r39h983d', 'mlindores9c@redcross.org', 'Josée', 'Gludor', 'nwrrih0ml3');
INSERT INTO public."User" VALUES ('cvofjy01b89a528k', 'ascroggins9d@slate.com', 'Desirée', 'Fielders', 'uwayrb0cx3');
INSERT INTO public."User" VALUES ('nwbwze08u69m283a', 'ebalcombe9e@moonfruit.com', 'Yú', 'Bonifazio', 'cjcchu9wo6');
INSERT INTO public."User" VALUES ('bxhwvl44a40p487p', 'jtrevenu9f@redcross.org', 'Kù', 'Godthaab', 'vdlhpz1hd4');
INSERT INTO public."User" VALUES ('ejovqv21c74z994c', 'rcopley9g@ebay.com', 'Yénora', 'MacGettigen', 'nyoscx3up6');
INSERT INTO public."User" VALUES ('ppbocq78e39u452k', 'emunkley9h@dailymail.co.uk', 'Anaïs', 'Vercruysse', 'kqxdwp1lw1');
INSERT INTO public."User" VALUES ('zkstsc58d44x407x', 'gfendt9i@slideshare.net', 'Véronique', 'Tawton', 'doznpm4sa3');
INSERT INTO public."User" VALUES ('urgaqd87g05s201o', 'mscard9j@go.com', 'Börje', 'Dubber', 'tfkmty8ty0');
INSERT INTO public."User" VALUES ('bkxwen88o85l765g', 'crubinfeld9k@mashable.com', 'Maïlys', 'Gudgion', 'zouscz9na0');
INSERT INTO public."User" VALUES ('jvpiug74z06q590x', 'mwiddowes9l@privacy.gov.au', 'Yáo', 'Philpin', 'umurmg1yt3');
INSERT INTO public."User" VALUES ('hzygug04l86s190x', 'kgrinham9m@sina.com.cn', 'Clélia', 'Scolding', 'qstdqm4kj6');
INSERT INTO public."User" VALUES ('ecoami54p21v881e', 'hscriviner9n@tripod.com', 'Lén', 'Temperley', 'otjqyr0aq5');
INSERT INTO public."User" VALUES ('slmwhe14o82t696q', 'bcrighton9o@imgur.com', 'Méthode', 'Gronou', 'wsphpc5ib6');
INSERT INTO public."User" VALUES ('mlqtow03q53i339t', 'jvittery9p@paypal.com', 'Maéna', 'Peare', 'hitsul4ay9');
INSERT INTO public."User" VALUES ('uxwyyw69y67w105g', 'jrojahn9q@bbb.org', 'Judicaël', 'Kensall', 'ppivhv4uf0');
INSERT INTO public."User" VALUES ('odlgol57t91v394z', 'aglencorse9r@example.com', 'Maëline', 'Bennison', 'skapzc7rv4');
INSERT INTO public."User" VALUES ('mmyxlq78y60c639v', 'iclamp9s@typepad.com', 'Alizée', 'Grinley', 'rurqqt3xg2');
INSERT INTO public."User" VALUES ('rgsyok95g15q355j', 'gdekeep9t@amazon.co.jp', 'Jú', 'Huxley', 'ujruxz0wf0');
INSERT INTO public."User" VALUES ('vvrtat98m61u748i', 'ameaker9u@ed.gov', 'Athéna', 'Tythacott', 'uhfqbn0ne3');
INSERT INTO public."User" VALUES ('hjimqc36e57w169x', 'belleyne9v@163.com', 'Adélaïde', 'Angear', 'whjngf5qo1');
INSERT INTO public."User" VALUES ('ngucfb23c25o683b', 'ilabrenz9w@symantec.com', 'Clémentine', 'Teresia', 'qavpqi4zb3');
INSERT INTO public."User" VALUES ('jcnncy30g29e277m', 'cmcmurty9x@twitter.com', 'Lucrèce', 'Searl', 'rcpmyp1jt9');
INSERT INTO public."User" VALUES ('alemzf73j20z028u', 'dchoppin9y@cnet.com', 'Athéna', 'Harbach', 'svkyar0ya3');
INSERT INTO public."User" VALUES ('zsorvj58e92g655d', 'rviccars9z@t.co', 'Lauréna', 'Haynesford', 'appxwz9hf5');
INSERT INTO public."User" VALUES ('yeidoq87h04v253n', 'abiglanda0@acquirethisname.com', 'Marie-ève', 'Rucklesse', 'brawoc5pg7');
INSERT INTO public."User" VALUES ('ssywbs56x65c294e', 'alifea1@reference.com', 'Véronique', 'Ledwich', 'nzzwcc0fm3');
INSERT INTO public."User" VALUES ('hiyfze37r31q065s', 'jwestberga2@go.com', 'Gisèle', 'Laffling', 'dstmdo1sj3');
INSERT INTO public."User" VALUES ('mhnwrf04i20e165m', 'ncharlwooda3@moonfruit.com', 'Geneviève', 'Aikenhead', 'rwlhqe8ea7');
INSERT INTO public."User" VALUES ('txiquk01l70j007w', 'lgedneya4@independent.co.uk', 'Salomé', 'Goldie', 'grprje3ld2');
INSERT INTO public."User" VALUES ('ubkiiv20t25x511g', 'mpitmana5@ycombinator.com', 'Léone', 'Rayhill', 'rkmqyu0qu5');
INSERT INTO public."User" VALUES ('duuvwb62a67u925b', 'cshanna6@bigcartel.com', 'Danièle', 'Chattoe', 'rbmvaw5gq5');
INSERT INTO public."User" VALUES ('iaimcp27v09n390o', 'gnotleya7@google.com.br', 'Médiamass', 'Faulconbridge', 'zwooys1iz6');
INSERT INTO public."User" VALUES ('tgfcls21b77t413r', 'agaskoina8@plala.or.jp', 'Aí', 'Salisbury', 'ukovju1lr0');
INSERT INTO public."User" VALUES ('caztjb38w06e804g', 'schadneya9@skype.com', 'Célestine', 'O''Donnell', 'piqsce4lh1');
INSERT INTO public."User" VALUES ('sugoqm80w14b879j', 'fboichaa@naver.com', 'Clémence', 'Grelak', 'tduphy1zp8');
INSERT INTO public."User" VALUES ('kchcts01v28p860a', 'ckiellorab@myspace.com', 'Valérie', 'Wilkisson', 'jqmckt5by5');
INSERT INTO public."User" VALUES ('zhuwhr15r01h823j', 'dschopsac@independent.co.uk', 'Wá', 'Eldrid', 'wabdba8mr5');
INSERT INTO public."User" VALUES ('dywuuy04i17o578j', 'gecclesallad@who.int', 'Ruò', 'Wooff', 'wshuxa1kq5');
INSERT INTO public."User" VALUES ('zxwuth69x56e561d', 'ohousecroftae@furl.net', 'Cécilia', 'Girth', 'upmfba3yy8');
INSERT INTO public."User" VALUES ('hzkqjh73f81k762o', 'ehingeaf@nih.gov', 'Méryl', 'Roy', 'abixwl6lp2');
INSERT INTO public."User" VALUES ('ngyfvg51u35u829g', 'swestnedgeag@washingtonpost.com', 'Michèle', 'Jakubczyk', 'roohzn2gh4');
INSERT INTO public."User" VALUES ('yjgxng37x23u723a', 'bkellettah@reference.com', 'Renée', 'Chaplain', 'vfqwsp0mv0');
INSERT INTO public."User" VALUES ('apfaag54u56a452l', 'dcraydenai@fastcompany.com', 'Miléna', 'Auden', 'mmuidp5br9');
INSERT INTO public."User" VALUES ('ulirgg96w70a400m', 'dgabbataj@tripadvisor.com', 'Mahélie', 'Pund', 'srwxce3so1');
INSERT INTO public."User" VALUES ('mqamxl68x56b775i', 'dmckinlessak@slate.com', 'Clélia', 'Fallens', 'ebydie4qz7');
INSERT INTO public."User" VALUES ('uvkxaj86z28t312j', 'ecrinageal@cnbc.com', 'Annotés', 'MacAllaster', 'aizges5lb2');
INSERT INTO public."User" VALUES ('bmzfjy69f92a623m', 'nrigdenam@webnode.com', 'Aimée', 'Magovern', 'ulkkhr8bb4');
INSERT INTO public."User" VALUES ('uilegv36b88z258v', 'callanbyan@infoseek.co.jp', 'Lucrèce', 'Orrick', 'kthytq0hh1');
INSERT INTO public."User" VALUES ('lzwmkk95z22u505k', 'bbaertao@sourceforge.net', 'Mégane', 'Josefs', 'ojpzfw0bg8');
INSERT INTO public."User" VALUES ('khnvqe72l87q967u', 'kouchterlonyap@ihg.com', 'Léandre', 'Josephson', 'qqgwav5mm9');
INSERT INTO public."User" VALUES ('itzwyb58k79e957f', 'smasseoaq@parallels.com', 'Dù', 'MacGrath', 'uvcfcp0pz5');
INSERT INTO public."User" VALUES ('cxbpdi54i67k361m', 'myansonar@cocolog-nifty.com', 'Pélagie', 'Bew', 'iiooru4vm2');
INSERT INTO public."User" VALUES ('kvdahv58k62x642d', 'ckuhnhardtas@netscape.com', 'Fèi', 'Itscovitz', 'lhpnvt8ub7');
INSERT INTO public."User" VALUES ('rejrzk24v65g139b', 'bduggaryat@seesaa.net', 'Bécassine', 'Pennaman', 'odrxxr0ty3');
INSERT INTO public."User" VALUES ('qpivwa87y25e468o', 'zvasilchikovau@princeton.edu', 'Léana', 'Abrehart', 'sfsnht8fl1');
INSERT INTO public."User" VALUES ('owlzke29p19n961a', 'pevertonav@yandex.ru', 'Garçon', 'Ambroise', 'qesjng5pc0');
INSERT INTO public."User" VALUES ('ynpqod02y80v794g', 'gwillinghamaw@t-online.de', 'Dorothée', 'Andrault', 'xfdctk4uq9');
INSERT INTO public."User" VALUES ('ygwxvj79h90f093i', 'elambartonax@wisc.edu', 'Crééz', 'Threadgall', 'kcixqc1uw4');
INSERT INTO public."User" VALUES ('sycvaz44l40f023m', 'jsnedenay@webmd.com', 'Gwenaëlle', 'Ferenc', 'uctvnc7rj7');
INSERT INTO public."User" VALUES ('gzewaj59c69u483b', 'dgrassickaz@tuttocitta.it', 'Maëlla', 'Raywood', 'cajzel0uu5');
INSERT INTO public."User" VALUES ('hbgrck63w31e330g', 'kpeggb0@gov.uk', 'Hélèna', 'Guirardin', 'fewfkf3od9');
INSERT INTO public."User" VALUES ('opablf82b18h419i', 'gmalyjb1@meetup.com', 'Adélie', 'Crayden', 'yoytfn3kr5');
INSERT INTO public."User" VALUES ('ctpcvo16z19t939o', 'kmuffordb2@un.org', 'Anaël', 'Peach', 'gbkbap0or1');
INSERT INTO public."User" VALUES ('xvucnq61o81u204r', 'pcorseb3@biglobe.ne.jp', 'Maëlann', 'Arkley', 'buolky8xy6');
INSERT INTO public."User" VALUES ('uqhhnr77c13u853t', 'adelgardob4@oracle.com', 'Gösta', 'Skillman', 'vicvrs1ci3');
INSERT INTO public."User" VALUES ('olvtnz08k31g479l', 'cgallihawkb5@blogtalkradio.com', 'Géraldine', 'Gascoyne', 'haibti2ys5');
INSERT INTO public."User" VALUES ('inlkab22y35r523c', 'foveringtonb6@reference.com', 'Méline', 'Abethell', 'ihnzma0pq7');
INSERT INTO public."User" VALUES ('tibkqi57p42w743o', 'mfrickb7@theatlantic.com', 'Clémence', 'Mildmott', 'qqqirt8es4');
INSERT INTO public."User" VALUES ('wmwuxq55o01z838q', 'sbrownettb8@github.io', 'Almérinda', 'Aisbett', 'wvmxzs0if2');
INSERT INTO public."User" VALUES ('shiorv64i27v474n', 'mbaptyb9@icio.us', 'Cécilia', 'Meeking', 'leuumw1hz6');
INSERT INTO public."User" VALUES ('zgvtrb42b24y747d', 'afloyedba@about.me', 'Maï', 'Welling', 'cbanrx4ne6');
INSERT INTO public."User" VALUES ('rlhxip57i49r194d', 'jheeronbb@issuu.com', 'Esbjörn', 'Trelease', 'ovdzrl1mb0');
INSERT INTO public."User" VALUES ('vyjeea85g55s149m', 'cdarwentbc@trellian.com', 'Cléopatre', 'Giorgi', 'jlknvh4gc2');
INSERT INTO public."User" VALUES ('ysrwwy48b48m772c', 'scosgrivebd@walmart.com', 'Maëlla', 'Osboldstone', 'lwkiec6ah5');
INSERT INTO public."User" VALUES ('kghtyr25x19w311r', 'hmaccollbe@wix.com', 'Illustrée', 'Wordington', 'vxbqmj4rd2');
INSERT INTO public."User" VALUES ('pznyrv14e65y073o', 'rbalogunbf@arstechnica.com', 'Géraldine', 'Cordell', 'ongwsl1tj2');
INSERT INTO public."User" VALUES ('zlqfeu36e42k506v', 'mkinsmanbg@ibm.com', 'Ruì', 'Gillet', 'vbvbyk1ct3');
INSERT INTO public."User" VALUES ('horawi15y87t226p', 'mgeaneybh@redcross.org', 'Cléopatre', 'Dorin', 'rkhtok1qu4');
INSERT INTO public."User" VALUES ('whzcvo80i63t341a', 'mlawriebi@walmart.com', 'Méng', 'Marchington', 'zzlwzi1ss9');
INSERT INTO public."User" VALUES ('wgrejt00g44h946h', 'beddiebj@comsenz.com', 'Angèle', 'O''Dempsey', 'djsfgg6gp1');
INSERT INTO public."User" VALUES ('nheeqv31s20m525k', 'rbonifaciobk@msu.edu', 'Publicité', 'Eaken', 'ilqaww9zz7');
INSERT INTO public."User" VALUES ('bwnbxs04b67h331p', 'jbottomorebl@simplemachines.org', 'Mylène', 'Bahike', 'llopwm6gk4');
INSERT INTO public."User" VALUES ('izdinq84h61h643s', 'jbruckbm@europa.eu', 'Béatrice', 'Astie', 'drniqr9wf3');
INSERT INTO public."User" VALUES ('hfumzf36g22g747h', 'mpolackbn@netlog.com', 'Mélodie', 'Artis', 'jrwgac5rv4');
INSERT INTO public."User" VALUES ('rokhme14q44r365l', 'jhastwallbo@newyorker.com', 'Maëlla', 'Gannaway', 'lzmqdi3eb2');
INSERT INTO public."User" VALUES ('ykvblg18j59n847w', 'cmeynellbp@slashdot.org', 'Gwenaëlle', 'Chrichton', 'bnpfqi3af2');
INSERT INTO public."User" VALUES ('mfrbng21o26k276n', 'mcoilsbq@ebay.co.uk', 'Mahélie', 'Rampton', 'dlqgxc6bp2');
INSERT INTO public."User" VALUES ('bbkshw81f04m459q', 'rgoburnbr@who.int', 'Gaïa', 'Bellchamber', 'nirhqz1uk6');
INSERT INTO public."User" VALUES ('kudino54j21s645p', 'cwakemanbs@bluehost.com', 'Vérane', 'Milmoe', 'tmgglc1jn7');
INSERT INTO public."User" VALUES ('viutox10s69i779f', 'rsuthrenbt@cornell.edu', 'Réjane', 'Lahrs', 'dropfb2ya7');
INSERT INTO public."User" VALUES ('nfsrws52w24w953b', 'sfrankishbu@reference.com', 'Almérinda', 'Jarville', 'uellgz6ab9');
INSERT INTO public."User" VALUES ('nhfusr24m70x610v', 'wsimekbv@upenn.edu', 'Andréa', 'Panswick', 'dwmcmd3ls6');
INSERT INTO public."User" VALUES ('phwaxu31m15b938j', 'jdrydenbw@taobao.com', 'Yè', 'Sirr', 'gnyaep7hy4');
INSERT INTO public."User" VALUES ('sialkh00d96p920i', 'dbellhousebx@arstechnica.com', 'Irène', 'Peagram', 'faswln4lo9');
INSERT INTO public."User" VALUES ('qnapty89i33c049q', 'metonby@pinterest.com', 'Maïlis', 'Lorrimer', 'edtkco8zg6');
INSERT INTO public."User" VALUES ('umbayu44q37i955h', 'fgoomsbz@sphinn.com', 'Pénélope', 'Simmonds', 'poejdf3vj1');
INSERT INTO public."User" VALUES ('riwurq23j31u866w', 'mleonardc0@live.com', 'Joséphine', 'Brun', 'rnvyzq9zu4');
INSERT INTO public."User" VALUES ('jpzeyo97v76g588z', 'bsewterc1@dropbox.com', 'Méryl', 'Petrak', 'pswrdv4vp8');
INSERT INTO public."User" VALUES ('ggcmdj63y57b069x', 'gjexc2@amazon.co.jp', 'Håkan', 'Bonnyson', 'ethfgz8gl4');
INSERT INTO public."User" VALUES ('riaxye47m06p717k', 'mjagsonc3@linkedin.com', 'Torbjörn', 'Leeds', 'qjagud3ss6');
INSERT INTO public."User" VALUES ('ulkeax27i92h915i', 'rmaggillandreisc4@nba.com', 'Vénus', 'MacWhirter', 'dqwsqo9iz7');
INSERT INTO public."User" VALUES ('qlgobk65g81v170g', 'gpickinc5@drupal.org', 'Eléa', 'Georgeou', 'qoazoo5xn1');
INSERT INTO public."User" VALUES ('flindu81q13d275b', 'scostainc6@com.com', 'Clémentine', 'Baniard', 'oeslxd4li6');
INSERT INTO public."User" VALUES ('fcgrhm71d09a266t', 'oabbotc7@google.com.br', 'Ráo', 'Anand', 'ahziqg2uh8');
INSERT INTO public."User" VALUES ('mbmbqy89h61y240s', 'ecromec8@who.int', 'Estée', 'Rabidge', 'bkbzxq0nk1');
INSERT INTO public."User" VALUES ('gvncjo16f80e435h', 'kdrinanc9@simplemachines.org', 'Mélina', 'Tremble', 'lwbuvf3by8');
INSERT INTO public."User" VALUES ('gcinjy85m76o284r', 'jwedmoreca@msu.edu', 'Görel', 'Elizabeth', 'ggvrgw1vl6');
INSERT INTO public."User" VALUES ('qzvsel04w44q253q', 'cbelseycb@shinystat.com', 'Sòng', 'Hallawell', 'sbnfrh7gv3');
INSERT INTO public."User" VALUES ('wmpymc97t25y428q', 'isicelycc@umich.edu', 'Loïca', 'Lamerton', 'vwsapu7el8');
INSERT INTO public."User" VALUES ('tzonvf81w29d964g', 'swaterfieldcd@cisco.com', 'Dù', 'Birtchnell', 'sspelx5yd6');
INSERT INTO public."User" VALUES ('usuttb14j08o865n', 'fcoence@timesonline.co.uk', 'Cléopatre', 'Lewins', 'ygexyx4ib2');
INSERT INTO public."User" VALUES ('npymbn76d51e227l', 'osaladincf@ihg.com', 'Kévina', 'Deuss', 'wvsdau5vn2');
INSERT INTO public."User" VALUES ('uuxnfb50x42p997w', 'epinchencg@pinterest.com', 'Lén', 'Milland', 'vqkcxb6te2');
INSERT INTO public."User" VALUES ('navcdj18y88m194t', 'mstedech@com.com', 'Mélina', 'Ludlom', 'tplyok0oj1');
INSERT INTO public."User" VALUES ('cqvzpk85i23q219m', 'msteersci@elpais.com', 'Danièle', 'Treagus', 'izbjly7iy6');
INSERT INTO public."User" VALUES ('musdmi33a08v413b', 'dbullercj@nytimes.com', 'Östen', 'Wink', 'zbjzog5ab5');
INSERT INTO public."User" VALUES ('ywwkuo29k57j644j', 'spocockck@ca.gov', 'Stéphanie', 'Golborne', 'kdcbfg9ap0');
INSERT INTO public."User" VALUES ('brvmpm92v06z950b', 'edudnycl@creativecommons.org', 'Mélys', 'Skeel', 'lelrrg0yw6');
INSERT INTO public."User" VALUES ('woadai55o12v734m', 'rkitchinghancm@joomla.org', 'Mélinda', 'Hazlehurst', 'bwoekr4pf8');
INSERT INTO public."User" VALUES ('ldvolh68z86t839z', 'jjacobowitzcn@ucoz.ru', 'Léane', 'McGonagle', 'hbaexm8ty1');
INSERT INTO public."User" VALUES ('vrcbwn53f83h885p', 'dinchbaldco@1und1.de', 'Intéressant', 'Skellington', 'kvlbjl0rg8');
INSERT INTO public."User" VALUES ('ubhmvs80m63r731s', 'tattawaycp@oaic.gov.au', 'Intéressant', 'Niess', 'wdtltr6qc2');
INSERT INTO public."User" VALUES ('pzonfv49l79l250m', 'srisebrowcq@auda.org.au', 'Gaëlle', 'Lakenton', 'woeaty2sk6');
INSERT INTO public."User" VALUES ('cpoilh22e04c436a', 'ceydencr@1688.com', 'Clélia', 'Pigne', 'fobvfv6sd8');
INSERT INTO public."User" VALUES ('qfyxgs56y06g132x', 'abericcs@dion.ne.jp', 'Noëlla', 'Eady', 'tflzrx2po3');
INSERT INTO public."User" VALUES ('cyccyp23n61c647l', 'hmacfadyenct@mit.edu', 'Solène', 'Reekie', 'librsy4fq3');
INSERT INTO public."User" VALUES ('xmtxjt99x07q805l', 'sjostancu@clickbank.net', 'Léonie', 'Senett', 'vqjfou7qi4');
INSERT INTO public."User" VALUES ('utejkk23x45s145y', 'zfacchinicv@elpais.com', 'Eugénie', 'Haberfield', 'irqxgl5wk2');
INSERT INTO public."User" VALUES ('wpeunt53q41t289g', 'ayeomanscw@symantec.com', 'Adèle', 'Shreeves', 'azwbab0ds7');
INSERT INTO public."User" VALUES ('rfadlz54k36p085m', 'aheidencx@wordpress.com', 'Maïlys', 'Rowett', 'ephbut0cq7');
INSERT INTO public."User" VALUES ('vuntfo60q79j268u', 'jwillerstonecy@marriott.com', 'Faîtes', 'Roddick', 'xdfphc3wt6');
INSERT INTO public."User" VALUES ('iwzazo76c40z173j', 'mmclavertycz@cnn.com', 'Salomé', 'Albrooke', 'nftynh7ca2');
INSERT INTO public."User" VALUES ('wjltqm70n02s381l', 'jgannicleffd0@mysql.com', 'Laurélie', 'Wiseman', 'khdezk8zu4');
INSERT INTO public."User" VALUES ('gmpdjg41s85c745x', 'prossind1@sun.com', 'Dorothée', 'Lindley', 'mphbtn6zk3');
INSERT INTO public."User" VALUES ('wgsdeu45m51x550z', 'tjewesd2@pbs.org', 'Örjan', 'Altamirano', 'czqmvh1ox4');
INSERT INTO public."User" VALUES ('lulhsf09p30x463l', 'bwoolfootd3@uiuc.edu', 'Cléopatre', 'Giamelli', 'ebviqm8ry4');
INSERT INTO public."User" VALUES ('ukoqtd42w51b987e', 'rrackamd4@gov.uk', 'Maéna', 'Petric', 'dohciw0tg5');
INSERT INTO public."User" VALUES ('novrai94y62t466f', 'ngotthardsfd5@hud.gov', 'Åke', 'Absolem', 'biyarp1nv9');
INSERT INTO public."User" VALUES ('odbnpx95k95p433r', 'cnottinghamd6@infoseek.co.jp', 'Anaïs', 'Dudding', 'zfoalt8az0');
INSERT INTO public."User" VALUES ('czrdqp51k52n440u', 'pmcgrudderd7@google.co.jp', 'Léandre', 'Willis', 'kmgczy1wa5');
INSERT INTO public."User" VALUES ('jlptxn26w04f695l', 'twellend8@arizona.edu', 'Loïs', 'Kerner', 'ajreyv8jb1');
INSERT INTO public."User" VALUES ('jmjxlh00n92u300n', 'hsneesbyfd@imgur.com', 'Zoé', 'Frankish', 'csxxmo4jx7');
INSERT INTO public."User" VALUES ('eqorej11m60t194q', 'epetranekd9@webmd.com', 'Danièle', 'Renon', 'fhngyp9gk9');
INSERT INTO public."User" VALUES ('hbbeex67w98b398p', 'kbarkusda@wisc.edu', 'Athéna', 'Ashbrook', 'mrguyo5zv2');
INSERT INTO public."User" VALUES ('bwgcrg80j60z952d', 'msmorthitdb@yellowpages.com', 'Kù', 'Atheis', 'vcaiqj5md1');
INSERT INTO public."User" VALUES ('hdzhzn61k44v349x', 'tkinmonddc@purevolume.com', 'Aimée', 'Tilney', 'lnmhuw6ax1');
INSERT INTO public."User" VALUES ('egntdi74r39o485c', 'astrangwooddd@google.com', 'Stévina', 'Pizey', 'dzvssm4kx3');
INSERT INTO public."User" VALUES ('rvbptx01k67h766t', 'kcerithde@scientificamerican.com', 'Desirée', 'Picken', 'aguvxw6jv1');
INSERT INTO public."User" VALUES ('arlbqv46e30w307n', 'lburghdf@bloomberg.com', 'Ruò', 'Cawt', 'fvilih9ya4');
INSERT INTO public."User" VALUES ('jvyifm99v90s449y', 'awessondg@opensource.org', 'Ophélie', 'Tupman', 'fbrlez4so1');
INSERT INTO public."User" VALUES ('tqqppd29p61m297o', 'tknightdh@bloomberg.com', 'Yáo', 'Juris', 'hiywyj3gi7');
INSERT INTO public."User" VALUES ('ssiftj66g31y119z', 'ehigforddi@51.la', 'Göran', 'Trusler', 'zbkpbb0pl5');
INSERT INTO public."User" VALUES ('dmjzqd59p11o659o', 'kpeegremdj@phpbb.com', 'André', 'Climar', 'qozogw5wa1');
INSERT INTO public."User" VALUES ('zxpdvq25f01x297f', 'jroggieridk@example.com', 'Aimée', 'Origin', 'fxupbc5tq1');
INSERT INTO public."User" VALUES ('bhlbze73l66u350d', 'abattsondl@engadget.com', 'Mélina', 'Winskill', 'tswfie4qh5');
INSERT INTO public."User" VALUES ('sudvaa64u35a304y', 'dcoltmandm@miibeian.gov.cn', 'Lài', 'Reiners', 'knjjsn1eu5');
INSERT INTO public."User" VALUES ('mkfvlo19m69f141z', 'rzuponedn@bbc.co.uk', 'Wá', 'Persian', 'nuwtec0sw6');
INSERT INTO public."User" VALUES ('cmzzun95i89h633u', 'cseresdo@youtube.com', 'Cléopatre', 'Ioannou', 'ujknji8ks3');
INSERT INTO public."User" VALUES ('llvxkg42o89c286h', 'llawleydp@delicious.com', 'Naëlle', 'Olle', 'vrzxyu1uq6');
INSERT INTO public."User" VALUES ('jpzdyp65t38k965w', 'tgeatordq@printfriendly.com', 'Mårten', 'Stenning', 'thudrc0fh0');
INSERT INTO public."User" VALUES ('ihgqsk40g36m748g', 'aklaisdr@xrea.com', 'Mélissandre', 'Gummory', 'dmeafz5sg1');
INSERT INTO public."User" VALUES ('yltvxh79l69n942y', 'tstutteds@topsy.com', 'Maëline', 'Landell', 'qxwcml1jm0');
INSERT INTO public."User" VALUES ('nphdhh80r81g345u', 'gkaufmandt@unc.edu', 'Adèle', 'McLaverty', 'fuicsx6xx6');
INSERT INTO public."User" VALUES ('tskfgo62n95y356w', 'worpynedu@google.pl', 'Séverine', 'Jedrzejczak', 'oqxlvt9pc4');
INSERT INTO public."User" VALUES ('wjiqak87h56e932g', 'svignerondv@t.co', 'Danièle', 'Sayton', 'jmavfe5rk2');
INSERT INTO public."User" VALUES ('gbouok44o32j057t', 'cdefriesdw@privacy.gov.au', 'Lauréna', 'Bresner', 'mltlwb6ej6');
INSERT INTO public."User" VALUES ('zatzch37y47z709a', 'brangledx@apache.org', 'Gaëlle', 'Docharty', 'jbjbai2dn2');
INSERT INTO public."User" VALUES ('hdshix37s83s495s', 'gceceredy@sbwire.com', 'Salomé', 'Fillimore', 'bbhfow7lb3');
INSERT INTO public."User" VALUES ('spzxsw68j24x233l', 'dmarringtondz@storify.com', 'Naëlle', 'Jowett', 'xsqzia0yq0');
INSERT INTO public."User" VALUES ('tugobv65i01e929x', 'emitskeviche0@hibu.com', 'Aimée', 'Pereira', 'hzvuax0dm1');
INSERT INTO public."User" VALUES ('crlzvo43u55v574l', 'rpencotte1@house.gov', 'Vérane', 'Costard', 'ynxndf3hg7');
INSERT INTO public."User" VALUES ('puyeld92x63g173x', 'ebartone2@live.com', 'Dà', 'Tincey', 'ailgtq5iy4');
INSERT INTO public."User" VALUES ('hmdaox79r82u251l', 'cgrumelle3@ucla.edu', 'Loïs', 'Scaplehorn', 'cpmpez4ff3');
INSERT INTO public."User" VALUES ('xneehv18f10w732f', 'adunlope4@sourceforge.net', 'Lucrèce', 'Muffin', 'bsngtw2ru2');
INSERT INTO public."User" VALUES ('mphqfa89s08b688e', 'bgartelle5@myspace.com', 'Inès', 'Myles', 'lbbuwh2ux0');
INSERT INTO public."User" VALUES ('dqnour68u44g210s', 'epedlere6@163.com', 'Örjan', 'Jacobssen', 'uptwmn9kj1');
INSERT INTO public."User" VALUES ('rhuulw30u78t147w', 'igerie7@un.org', 'Pélagie', 'Hanretty', 'qcjutp9jn6');
INSERT INTO public."User" VALUES ('bptjwu24n05g686j', 'bsnazele8@kickstarter.com', 'Åsa', 'Ilson', 'kdklpq3fr2');
INSERT INTO public."User" VALUES ('barlvi05b93x209w', 'balldise9@uiuc.edu', 'Bécassine', 'Zanuciolii', 'nldjzu3mz1');
INSERT INTO public."User" VALUES ('kvxfnu83r92o803j', 'dwaneea@cbsnews.com', 'Clémence', 'Shailer', 'lrjxbj4pj4');
INSERT INTO public."User" VALUES ('msgzxc65z84l783v', 'ecicconeeb@bbb.org', 'Célia', 'Hurlestone', 'lxpjti3bc7');
INSERT INTO public."User" VALUES ('bojbbg69p36r021b', 'tdanielliec@nasa.gov', 'Célia', 'Winsome', 'nfzayg8ya4');
INSERT INTO public."User" VALUES ('ufkqrn44n72b177n', 'asedgmonded@europa.eu', 'Lauréna', 'Nertney', 'dtixan3ic7');
INSERT INTO public."User" VALUES ('dkdxql92m73y242m', 'rloffillee@clickbank.net', 'Rachèle', 'Casebourne', 'onujib5lq8');
INSERT INTO public."User" VALUES ('zjbrmf42a64e406x', 'dpaveref@ucsd.edu', 'Illustrée', 'Wannell', 'updywf5ah5');
INSERT INTO public."User" VALUES ('lozcaw07a05l577a', 'lfitzsymonseg@list-manage.com', 'Léone', 'Gebhard', 'vdbgbz5le1');
INSERT INTO public."User" VALUES ('lhylwe08j80o191j', 'cparkseh@nps.gov', 'Intéressant', 'Amesbury', 'mwwjkn4on9');
INSERT INTO public."User" VALUES ('gbrbkr56g87g635a', 'jasplingei@imgur.com', 'Angèle', 'Sillars', 'ttmetf4pk2');
INSERT INTO public."User" VALUES ('vamjmf47o58j777w', 'esandilandej@google.co.jp', 'Mélinda', 'Slatten', 'vgcguz2be7');
INSERT INTO public."User" VALUES ('eiaprm20e01b822l', 'ftunnockek@theguardian.com', 'Torbjörn', 'Gullam', 'yquojh8ox2');
INSERT INTO public."User" VALUES ('enqhcw67x77z834h', 'hrolfoel@biblegateway.com', 'Léa', 'Gatesman', 'sbgsib9di0');
INSERT INTO public."User" VALUES ('wwuzik62p31a377d', 'fwayem@un.org', 'Daphnée', 'Levings', 'thdbsd5ta7');
INSERT INTO public."User" VALUES ('hmujpg26i93u330r', 'rkosiadaen@cisco.com', 'Kuí', 'Kulas', 'aysomz9od2');
INSERT INTO public."User" VALUES ('oqviwu80s05h035z', 'ptunnockeo@creativecommons.org', 'Inès', 'Tenman', 'itolha0op3');
INSERT INTO public."User" VALUES ('uehnvf65j77r503u', 'dgerdingep@ameblo.jp', 'Maëlla', 'Costerd', 'medpna0yz1');
INSERT INTO public."User" VALUES ('bqeryb85h12e288b', 'sgolighereq@phpbb.com', 'Hélène', 'Fine', 'jbxeew4kp6');
INSERT INTO public."User" VALUES ('asykos14a99g005u', 'bsaintepauler@goodreads.com', 'Andrée', 'Emanueli', 'crlcxt9rq9');
INSERT INTO public."User" VALUES ('tcpmoo96v73g834i', 'tcorneljeses@homestead.com', 'Esbjörn', 'Peers', 'dpatog0es1');
INSERT INTO public."User" VALUES ('afevdp04e21c505z', 'zsoneet@economist.com', 'Gaïa', 'Faithorn', 'jmjloi7ha9');
INSERT INTO public."User" VALUES ('ohdfns51t00g627v', 'jcaineeu@nature.com', 'Anaïs', 'Mc Mechan', 'ukrlbl6kh4');
INSERT INTO public."User" VALUES ('gveczo21l43e938z', 'psalliereev@constantcontact.com', 'Cécile', 'Tylor', 'akydfm5ga9');
INSERT INTO public."User" VALUES ('ukjoxm64i53e143f', 'vcaberaew@theglobeandmail.com', 'Mårten', 'Pingston', 'epsvtf1ni0');
INSERT INTO public."User" VALUES ('mpugjc76l42m611d', 'kfullerdex@abc.net.au', 'Lài', 'Eyer', 'yiwlol2lt4');
INSERT INTO public."User" VALUES ('uhwycg93m35w526y', 'sburleighey@ask.com', 'Aurélie', 'Dienes', 'ujjiuf1yn7');
INSERT INTO public."User" VALUES ('rdkibo76h59u110y', 'aloweez@cnbc.com', 'Liè', 'Aisthorpe', 'huhuwr7sq8');
INSERT INTO public."User" VALUES ('prjasj98x82r650m', 'ifawlkesf0@comsenz.com', 'Aloïs', 'Antonignetti', 'xaymoq0ta3');
INSERT INTO public."User" VALUES ('gkhklj82m85l361x', 'mpaleyf1@jimdo.com', 'Vérane', 'Kingston', 'wliofj9nm0');
INSERT INTO public."User" VALUES ('thshsv16v73p624d', 'yverseyf2@webeden.co.uk', 'Adélaïde', 'Ronchka', 'xjddao7ig0');
INSERT INTO public."User" VALUES ('rvpweg37g63x780l', 'ifooksf3@google.it', 'André', 'Quinnelly', 'ihectm4rx6');
INSERT INTO public."User" VALUES ('cyyifu45e41v238s', 'heberdtf4@intel.com', 'Lyséa', 'Jeyes', 'obeaow0lc5');
INSERT INTO public."User" VALUES ('lofzmh73m50c278v', 'dtenauntf5@nhs.uk', 'Crééz', 'Comley', 'aurzuk9ib4');
INSERT INTO public."User" VALUES ('jotyjq63b29u396x', 'srossboroughf6@soup.io', 'Gaétane', 'Gilardone', 'xhzbsj8et9');
INSERT INTO public."User" VALUES ('ibtqts02v87v774z', 'esegeswoethf7@nationalgeographic.com', 'Åslög', 'Taggert', 'pwgypw0px2');
INSERT INTO public."User" VALUES ('npvals07a72i269e', 'rmatuskiewiczf8@bing.com', 'Sòng', 'Tomanek', 'jhqchs7kf6');
INSERT INTO public."User" VALUES ('mstusy89h40u467h', 'twinnettf9@opera.com', 'Maëlys', 'Goathrop', 'njbarn4uy0');
INSERT INTO public."User" VALUES ('rpcmio07k15z730z', 'dedgeonfa@ameblo.jp', 'Anaé', 'Vankeev', 'vglrxj5ih0');
INSERT INTO public."User" VALUES ('vlypir20b31b592e', 'fcrebbinfb@acquirethisname.com', 'Erwéi', 'Godon', 'ignjez9zx2');
INSERT INTO public."User" VALUES ('aomsdz17v94r468w', 'kswainefc@php.net', 'Marie-josée', 'Stanbrooke', 'vrwzlm0kv0');
INSERT INTO public."User" VALUES ('ekdixj40p79r986k', 'kwhiteheadfe@reference.com', 'Estée', 'Edis', 'rlredv9bn8');
INSERT INTO public."User" VALUES ('ohejlz88u45c196l', 'mgrimmertff@yellowpages.com', 'Aí', 'Vanshin', 'ttszvf0zu0');
INSERT INTO public."User" VALUES ('bnunep49r71w996s', 'rkorneichukfg@admin.ch', 'Renée', 'Fellow', 'bnitum5bz8');
INSERT INTO public."User" VALUES ('zpddfs28s55o436w', 'tpydcockfh@gmpg.org', 'Pò', 'Iwaszkiewicz', 'hwupjl1qh3');
INSERT INTO public."User" VALUES ('iqwzzu54e82y074l', 'emcdonoghfi@scientificamerican.com', 'Märta', 'Swanbourne', 'doklef0uw5');
INSERT INTO public."User" VALUES ('xzsvwo58s10x004x', 'fwilflingerfj@sciencedaily.com', 'Médiamass', 'Favell', 'iofphh4xd3');
INSERT INTO public."User" VALUES ('ffrkdt96a34i688u', 'lfinlowfk@instagram.com', 'Thérèsa', 'Quernel', 'xscpdg1ej8');
INSERT INTO public."User" VALUES ('qegtmj78x01k882t', 'mbirneyfl@wufoo.com', 'Dorothée', 'Huckster', 'fsqzex5dn5');
INSERT INTO public."User" VALUES ('xpcddd79t48w361c', 'lrameletfm@chronoengine.com', 'Torbjörn', 'Simone', 'rxdkpd2mu4');
INSERT INTO public."User" VALUES ('skiwxa78z69t210g', 'pclinganfn@google.com.au', 'Cécile', 'Godridge', 'nbbocw6mp7');
INSERT INTO public."User" VALUES ('fogxok13p51u595j', 'csicilyfo@xing.com', 'Séréna', 'Varley', 'cchipn0io4');
INSERT INTO public."User" VALUES ('alsvgn40t66i741v', 'abirbeckfp@netvibes.com', 'Gwenaëlle', 'Buxton', 'dfvtnc5ro9');
INSERT INTO public."User" VALUES ('jtupkh52a44o086z', 'sbonefq@1und1.de', 'Maëline', 'MacSkeagan', 'gtjyep6ro8');
INSERT INTO public."User" VALUES ('rczdsn39i48i476x', 'rscoldingfr@addtoany.com', 'Marie-noël', 'Skeech', 'wmrvxl9rj2');
INSERT INTO public."User" VALUES ('rexwhh02l41h534k', 'whargatefs@admin.ch', 'Alizée', 'Twyning', 'acoadm3mn7');
INSERT INTO public."User" VALUES ('xguxqy59d50k854a', 'ghaugenft@whitehouse.gov', 'Maïwenn', 'Gurnay', 'llhhpb3qx8');
INSERT INTO public."User" VALUES ('usilzk69c81t096c', 'mklimkiewichfu@intel.com', 'Océane', 'Mager', 'sxcfxz3wm2');
INSERT INTO public."User" VALUES ('jjpbfu28v46m598f', 'jscraggfv@statcounter.com', 'Wá', 'Endean', 'oqfnxj8se9');
INSERT INTO public."User" VALUES ('xgcdkf00f78o283e', 'opettifordfw@photobucket.com', 'Dorothée', 'Gosney', 'vyxyix2kc4');
INSERT INTO public."User" VALUES ('wbekan72k84k751t', 'mshorrockfx@about.me', 'Mélodie', 'Itzcovich', 'ihietb0jj0');
INSERT INTO public."User" VALUES ('jguvik15v25f237h', 'dmcnufffy@addtoany.com', 'Uò', 'Jedrachowicz', 'fraxnt8tq8');
INSERT INTO public."User" VALUES ('yeaolb30q53w012k', 'ecollinfz@youtu.be', 'Aurélie', 'Frays', 'puqloc9lf5');
INSERT INTO public."User" VALUES ('qbqbdg66p89k390r', 'scorkingg0@virginia.edu', 'Dorothée', 'Brainsby', 'kisqwc6mm4');
INSERT INTO public."User" VALUES ('njvypc84o38o790p', 'zmattiag1@columbia.edu', 'Pénélope', 'Catonnet', 'qeghai2sh6');
INSERT INTO public."User" VALUES ('voslye64y98a963z', 'amcilhoneg2@networkadvertising.org', 'Bécassine', 'Londing', 'wiklqe7gv9');
INSERT INTO public."User" VALUES ('zkqxgz07n36z490p', 'bmithang3@illinois.edu', 'Valérie', 'Balazs', 'xniofd8kd6');
INSERT INTO public."User" VALUES ('qjcmuu79f39d249a', 'ralgyg4@rambler.ru', 'Mélys', 'Bleythin', 'yevaqj9cn1');
INSERT INTO public."User" VALUES ('odfwld70g83z476n', 'bvinecombeg5@uiuc.edu', 'Mégane', 'Gately', 'lbnrgl6ys1');
INSERT INTO public."User" VALUES ('jbmcux55d48d822v', 'urippingaleg6@stanford.edu', 'Noëlla', 'Harmon', 'jgmtnj2rg7');
INSERT INTO public."User" VALUES ('bnynff06n90z005d', 'rbickellg7@list-manage.com', 'Simplifiés', 'Fant', 'fathyz9mz3');
INSERT INTO public."User" VALUES ('qieing39s21x343v', 'ecoppingg8@w3.org', 'Mélys', 'Joddens', 'ihfooe9wu5');
INSERT INTO public."User" VALUES ('jxogzd07p33w688t', 'mvearncombg9@dagondesign.com', 'Joséphine', 'Geall', 'vpekpm5mq1');
INSERT INTO public."User" VALUES ('lngpge76v27g291n', 'kblockleyga@ezinearticles.com', 'Yú', 'De Miranda', 'iuavau5vb6');
INSERT INTO public."User" VALUES ('pikcfu27s86f073u', 'ilumpkingb@oakley.com', 'Clémentine', 'Woollard', 'rzhgbp1bh9');
INSERT INTO public."User" VALUES ('yarpnl54v88x460c', 'kisaacsongc@sciencedaily.com', 'Faîtes', 'Hansom', 'kcafxd0da7');
INSERT INTO public."User" VALUES ('jfhbjt01l66n806y', 'elehriangd@buzzfeed.com', 'Solène', 'Nordass', 'qrfavm2se5');
INSERT INTO public."User" VALUES ('oqwmus57k63x804d', 'sporchge@uol.com.br', 'Lài', 'Streatfeild', 'xisfxc6ao0');
INSERT INTO public."User" VALUES ('rfsvkn71a26l304y', 'taddenbrookegf@army.mil', 'Jú', 'Klessmann', 'fuhrsb8fe1');
INSERT INTO public."User" VALUES ('macokn00k08m250l', 'cgiovannardigg@umn.edu', 'Cléa', 'Holbarrow', 'wktfxn1nq4');
INSERT INTO public."User" VALUES ('rhwzay80o42s558w', 'mbecarisgh@unc.edu', 'Garçon', 'Boatwright', 'ruvfbg9xs7');
INSERT INTO public."User" VALUES ('nbaifh35s94i306d', 'vnewburygi@techcrunch.com', 'Nélie', 'Kmiec', 'sfhnib2lg8');
INSERT INTO public."User" VALUES ('afaelp22b25y237q', 'msextygj@blogs.com', 'Marlène', 'Mansbridge', 'sobuux0eg4');
INSERT INTO public."User" VALUES ('mtyqjs84i40a613b', 'mbeesgk@uol.com.br', 'Marlène', 'Draayer', 'ubxire4ff2');
INSERT INTO public."User" VALUES ('basecz30j50w498g', 'nhammerberggl@smh.com.au', 'Åsa', 'Eynald', 'yvulqp8iq2');
INSERT INTO public."User" VALUES ('cxpehm82s28b201q', 'dlambirthgm@friendfeed.com', 'Stévina', 'Kehoe', 'hirlmz2ys9');
INSERT INTO public."User" VALUES ('zvxods62b20v677t', 'fhamergn@microsoft.com', 'Garçon', 'Lackner', 'zynagc7kt4');
INSERT INTO public."User" VALUES ('lzngve90z13e311z', 'whyndmango@parallels.com', 'Torbjörn', 'Dood', 'corwld8ex7');
INSERT INTO public."User" VALUES ('hqsmlq58i17v471q', 'gmckintygp@photobucket.com', 'Maëlle', 'Cavozzi', 'orippw0yl9');
INSERT INTO public."User" VALUES ('klanfs50b40q297g', 'ggissinggq@foxnews.com', 'Eloïse', 'Grisard', 'xbstbq6hr1');
INSERT INTO public."User" VALUES ('bcuydp17x49a157a', 'epicklegr@hexun.com', 'Andréanne', 'Camm', 'bzjjop4gd3');
INSERT INTO public."User" VALUES ('pjmdlb77f82n198l', 'ewyldishgs@elegantthemes.com', 'Dorothée', 'Grumell', 'fgwmey6lc9');
INSERT INTO public."User" VALUES ('xmdgjw84o94h380n', 'ccullumgt@networkadvertising.org', 'Geneviève', 'Hearfield', 'zcpbfv0vk4');
INSERT INTO public."User" VALUES ('hmsgpt01d84g745h', 'gstoppgu@wordpress.org', 'Léone', 'Knappen', 'taqqzs6zy8');
INSERT INTO public."User" VALUES ('zfdloy29u91j706j', 'ldunguygv@phpbb.com', 'Annotés', 'Blease', 'xriplu2st6');
INSERT INTO public."User" VALUES ('zdblid66n51o834b', 'lhartlesgw@123-reg.co.uk', 'Léane', 'McKellar', 'fpvkss1pq4');
INSERT INTO public."User" VALUES ('icyuxc92z94e999o', 'eocallaghangx@seattletimes.com', 'Liè', 'Baterip', 'zpmhea5lk3');
INSERT INTO public."User" VALUES ('kwojjj12m53p793k', 'cwollersgy@earthlink.net', 'Märta', 'Seys', 'phtxuw1ie9');
INSERT INTO public."User" VALUES ('djoete11x09k809f', 'mdunfordgz@newsvine.com', 'Ruò', 'Andrin', 'zwzorn6ap6');
INSERT INTO public."User" VALUES ('howecb81u20i898y', 'zrysonh0@dropbox.com', 'Jú', 'Dymond', 'jcduql8mp5');
INSERT INTO public."User" VALUES ('enlqky34g04n287q', 'pdrabbleh1@rambler.ru', 'Mà', 'Nutkins', 'mzxbhn6ef1');
INSERT INTO public."User" VALUES ('drvuoj51w00l471z', 'nkalbererh2@techcrunch.com', 'Tú', 'Elms', 'bdtcpf5qq6');
INSERT INTO public."User" VALUES ('lgbsfq57s18w797w', 'bkarslakeh3@theatlantic.com', 'Léone', 'Floyde', 'qvdluz4cz0');
INSERT INTO public."User" VALUES ('kvynid63z16f330t', 'mmugglestonh4@shinystat.com', 'Ophélie', 'McAlpin', 'jmdrxf6tx6');
INSERT INTO public."User" VALUES ('cnjpmm65o70g783m', 'vyglesiah5@nbcnews.com', 'Méghane', 'Troppmann', 'vonbgz7sy0');
INSERT INTO public."User" VALUES ('iznhvu37s97b768g', 'fgribbonh6@tripod.com', 'Maéna', 'Joberne', 'vhkmtc0ki2');
INSERT INTO public."User" VALUES ('gittwg92z66d467x', 'ncarash7@addthis.com', 'Maëlla', 'Farley', 'akcdxe1ol2');
INSERT INTO public."User" VALUES ('mfbvcv67j27n744m', 'gbrewetth8@de.vu', 'Åsa', 'Finlater', 'sqeoum2ot1');
INSERT INTO public."User" VALUES ('hweubz49l24o935x', 'jdullardh9@businessweek.com', 'Andréa', 'Steart', 'wnnvgi4lt1');
INSERT INTO public."User" VALUES ('vpzjhh57a31l572a', 'tmossopha@yale.edu', 'Félicie', 'Angerstein', 'hxepvt2th7');
INSERT INTO public."User" VALUES ('zipntx83x58r802s', 'fraitthb@myspace.com', 'Laïla', 'Riglar', 'bfykac1uk6');
INSERT INTO public."User" VALUES ('nfubre77p83m535l', 'ltapleyhc@businesswire.com', 'Mégane', 'Carbett', 'qdyhuo8js1');
INSERT INTO public."User" VALUES ('ecpgzf37z65c854l', 'mpettiforhd@hud.gov', 'Ruì', 'Fenimore', 'shrivs3yw3');
INSERT INTO public."User" VALUES ('qqfgsc49a12m071h', 'lbloorhe@unicef.org', 'Amélie', 'Bernakiewicz', 'kdoxfa7vi2');
INSERT INTO public."User" VALUES ('wkazon37d86e565m', 'dnormanvillhf@nytimes.com', 'Kuí', 'Finlator', 'pewspx9br3');
INSERT INTO public."User" VALUES ('fmvyhh44b41f640o', 'momullenhg@marriott.com', 'Séverine', 'Stutte', 'iqvpgw1ri4');
INSERT INTO public."User" VALUES ('vqoktq18k67t847v', 'csimmanshh@blog.com', 'Almérinda', 'Gregorowicz', 'kuntcm4fj6');
INSERT INTO public."User" VALUES ('cdqmve04q28n325e', 'hsapautonhi@unblog.fr', 'Régine', 'Bartelot', 'lmezsh0jp9');
INSERT INTO public."User" VALUES ('raosmo78h47e378s', 'ethalmannhj@mail.ru', 'Céline', 'Feldbau', 'xioghu4kw1');
INSERT INTO public."User" VALUES ('shtfay63q77a356p', 'wlowdenhk@behance.net', 'Eléa', 'Heinreich', 'lepivt5mb4');
INSERT INTO public."User" VALUES ('tohydz28a51e989f', 'rsloathl@google.it', 'Andrée', 'Kaming', 'guhfqz5pf4');
INSERT INTO public."User" VALUES ('elnrhz27j17b779c', 'kschabenhm@nhs.uk', 'Médiamass', 'Maltman', 'neqhhf3vf9');
INSERT INTO public."User" VALUES ('ghtwsc37j43a961m', 'tweepershn@loc.gov', 'Loïc', 'Vaneev', 'eolzni4qi0');
INSERT INTO public."User" VALUES ('jkvqvi18x34n809x', 'hhanrettyho@mapquest.com', 'Réservés', 'Roback', 'hivsct1pf4');
INSERT INTO public."User" VALUES ('jhlccw43c64k583r', 'mdiruggerohp@goo.ne.jp', 'Crééz', 'Brodhead', 'pusgyr0rp3');
INSERT INTO public."User" VALUES ('uqmgyx68u80y009b', 'gfardenhq@cisco.com', 'Geneviève', 'Mowsdale', 'qjcdse1wx3');
INSERT INTO public."User" VALUES ('wuxraa79f72p982m', 'tkickhr@miibeian.gov.cn', 'Nuó', 'Wooland', 'jykuti2ub9');
INSERT INTO public."User" VALUES ('ydlbgc84q68r799c', 'mtregennahs@is.gd', 'Maïlys', 'Nicklin', 'fuxork7hi6');
INSERT INTO public."User" VALUES ('kwjsje79m04i279d', 'jhandscombht@engadget.com', 'Görel', 'Dorrington', 'kfoulj5oz1');
INSERT INTO public."User" VALUES ('zrdncd83h87c914c', 'jnockallshu@indiegogo.com', 'Solène', 'Pybworth', 'zfwgzl1xf8');
INSERT INTO public."User" VALUES ('jkbajd67f27m061r', 'ggavaghanhv@pbs.org', 'Simplifiés', 'Zannetti', 'zcnxfj3we7');
INSERT INTO public."User" VALUES ('seuetv47u44n335p', 'jhemmingwayhw@washington.edu', 'Rachèle', 'Cluney', 'ykzedb9yn5');
INSERT INTO public."User" VALUES ('wzzcov47j78o537e', 'hdanterhx@google.it', 'Maëlla', 'Urwen', 'qbnszh8zf9');
INSERT INTO public."User" VALUES ('ipafqp15a18h244a', 'lmeusehy@amazon.co.uk', 'Pénélope', 'Showt', 'zwisej1bn5');
INSERT INTO public."User" VALUES ('hxfyhz76g34c459e', 'dalfonsettohz@mapquest.com', 'Lài', 'Borley', 'cjgkna3tt7');
INSERT INTO public."User" VALUES ('mqjihf78t38p027v', 'kkemmeti0@w3.org', 'Lucrèce', 'McAlister', 'sweeuj9ib5');
INSERT INTO public."User" VALUES ('bxkoad02s65q361g', 'wdreweti1@loc.gov', 'Clémentine', 'Styche', 'kmznxh8ao5');
INSERT INTO public."User" VALUES ('zaqqfb89l43t744e', 'ateaguei2@icio.us', 'Dà', 'Llorente', 'hhilkf4ew6');
INSERT INTO public."User" VALUES ('bihrha68t94f578n', 'llongcakei3@netlog.com', 'Mårten', 'Bertl', 'fpgijw5bp5');
INSERT INTO public."User" VALUES ('xoldjt13f67k819a', 'alewtyi4@webeden.co.uk', 'Mårten', 'Ghidini', 'temscn5ts0');
INSERT INTO public."User" VALUES ('qrrwvf24s55i034r', 'emccafferkyi5@elpais.com', 'Alizée', 'Yakovl', 'blkdfa7oi5');
INSERT INTO public."User" VALUES ('bfsurf19x35y922x', 'snestori6@fda.gov', 'Loïca', 'Worcester', 'pykflq0sl0');
INSERT INTO public."User" VALUES ('mjqpkz49g04d758y', 'lcalverdi7@pagesperso-orange.fr', 'Laurène', 'Prestidge', 'qqzjkt2ne3');
INSERT INTO public."User" VALUES ('wvofbb45r59q816j', 'wmeryetti8@yandex.ru', 'Märta', 'McGeffen', 'gkuxmc2ag3');
INSERT INTO public."User" VALUES ('lxbbns09i25h492v', 'ahotchkini9@flavors.me', 'Miléna', 'Espinet', 'dffjxq9ik0');
INSERT INTO public."User" VALUES ('bomjnq25b90q725w', 'igreenhallia@usa.gov', 'Andrée', 'Sivyer', 'kzwcwx0sc4');
INSERT INTO public."User" VALUES ('apyysh24a26j005e', 'hslyib@ibm.com', 'Yénora', 'Errigo', 'syczks8cj9');
INSERT INTO public."User" VALUES ('moesxu49c71g977y', 'phalfhydeic@quantcast.com', 'Örjan', 'Pinches', 'uwwvpw4ms9');
INSERT INTO public."User" VALUES ('izteil26u86d915e', 'gputtanid@msu.edu', 'Marie-thérèse', 'Redholes', 'qtpxmm8yc5');
INSERT INTO public."User" VALUES ('obfynz32p53w166h', 'beliassenie@discuz.net', 'Clémence', 'Allam', 'rmnreh4zo2');
INSERT INTO public."User" VALUES ('jdvcph01b40l237u', 'imiltonwhiteif@prnewswire.com', 'Kù', 'Bullan', 'hhlcfh4gw9');
INSERT INTO public."User" VALUES ('ludmcw24p67j143p', 'lkupperig@jugem.jp', 'Mélia', 'Muscat', 'ndafdx4tr8');
INSERT INTO public."User" VALUES ('auhpxk29v73u922q', 'rbridywaterih@ucoz.com', 'Mélys', 'Ochterlonie', 'xuoncq2nb3');
INSERT INTO public."User" VALUES ('fkictm54k21c357e', 'oandersonii@zimbio.com', 'Eliès', 'Warrell', 'jchisf9wl1');
INSERT INTO public."User" VALUES ('ohttye54b04b897u', 'jsowleyij@miibeian.gov.cn', 'Océanne', 'Bilney', 'lpimyk6cn4');
INSERT INTO public."User" VALUES ('uyidwe82n70t137a', 'rpogeik@howstuffworks.com', 'Lèi', 'Burkwood', 'ogyfmz5gl1');
INSERT INTO public."User" VALUES ('mdctpl49j81y925j', 'rclewettil@stanford.edu', 'Åke', 'Figgs', 'cfjfsj9bp5');
INSERT INTO public."User" VALUES ('bkijhc32p77m782y', 'hgayneim@live.com', 'Mélinda', 'Korneluk', 'djrori0ry7');
INSERT INTO public."User" VALUES ('uaduog26g70k466x', 'wwyldishin@sourceforge.net', 'Vénus', 'Hatry', 'zekxou5mc0');
INSERT INTO public."User" VALUES ('iqakur57c83w463l', 'avickario@epa.gov', 'Cinéma', 'Lamcken', 'ajelwy2bn6');
INSERT INTO public."User" VALUES ('xngeyr38m79v548p', 'tbrotherwoodip@icio.us', 'Renée', 'Want', 'drimki8iq7');
INSERT INTO public."User" VALUES ('annecp02r49p479y', 'kmatteaiq@unesco.org', 'Håkan', 'McKeaveney', 'kbdmpj3fn7');
INSERT INTO public."User" VALUES ('ecodwj05p83r038c', 'mfelsteadir@vinaora.com', 'Adélie', 'Kagan', 'mmuuvr3sd1');
INSERT INTO public."User" VALUES ('llxyjv39q96r417x', 'rpfeffelis@army.mil', 'Maëlyss', 'Safont', 'wcaviu0ak1');
INSERT INTO public."User" VALUES ('uunmbh80e00a440q', 'kconreit@uol.com.br', 'Bérengère', 'Tyrer', 'nggbdt2nf5');
INSERT INTO public."User" VALUES ('obtvgk59k30k461l', 'lunioniu@google.com.br', 'Régine', 'Pollard', 'kmmlue2pk6');
INSERT INTO public."User" VALUES ('olsqtg55l98o051j', 'hbranscombeiv@blogger.com', 'Laïla', 'Hightown', 'zwkluh0ie2');
INSERT INTO public."User" VALUES ('hftajy85d40h677v', 'tbyattiw@tripod.com', 'Anaëlle', 'Fogden', 'detxnc7km5');
INSERT INTO public."User" VALUES ('scsktb20x18x904r', 'amakinix@oaic.gov.au', 'Hélèna', 'Kells', 'gvzfcj7jj3');
INSERT INTO public."User" VALUES ('khoajt31w93n563n', 'xdoncasteriy@topsy.com', 'Anaëlle', 'Bridgnell', 'upmsfp8bz9');
INSERT INTO public."User" VALUES ('llkhwg02z66j440f', 'tboggesiz@utexas.edu', 'Lài', 'Casel', 'xcrzxs4ag1');
INSERT INTO public."User" VALUES ('quvuxp16g89r663l', 'ccalleryj0@php.net', 'Örjan', 'Dolden', 'yngidc1so9');
INSERT INTO public."User" VALUES ('kozzbn29q60c719k', 'smingaudj1@prlog.org', 'Maéna', 'MacMillan', 'ewwxje2td2');
INSERT INTO public."User" VALUES ('xnfktv82w33f454u', 'emudiej2@java.com', 'Dafnée', 'Ghirardi', 'pdnsad7fk4');
INSERT INTO public."User" VALUES ('zgbpva26u75t620w', 'fhurlestonj3@moonfruit.com', 'Maïly', 'de Nore', 'kgtamc4wz5');
INSERT INTO public."User" VALUES ('ugaztl54m29k901u', 'bpooltonj4@bigcartel.com', 'Régine', 'Bellin', 'tzalpr1kb2');
INSERT INTO public."User" VALUES ('tqywah35l92r927k', 'dhumphreyj5@ustream.tv', 'Thérèsa', 'Daubney', 'jtbtwc3lw4');
INSERT INTO public."User" VALUES ('tqfmrq49q16l282e', 'bhowoodj6@tmall.com', 'Hélène', 'Ropars', 'xajdeh2vh3');
INSERT INTO public."User" VALUES ('bpnyrg47u37p879q', 'mplacidej7@addtoany.com', 'Laurène', 'Gaylord', 'pmeicd6sh1');
INSERT INTO public."User" VALUES ('rzimge24f96j698f', 'cpickthornej8@so-net.ne.jp', 'Mélina', 'Trahar', 'ciqknj2eg5');
INSERT INTO public."User" VALUES ('lkcnpv28m20l624y', 'hbaldaccoj9@time.com', 'Gaëlle', 'Dreier', 'fejhua0pp6');
INSERT INTO public."User" VALUES ('xvmxtn92n36b382i', 'tulrikja@xinhuanet.com', 'Lyséa', 'Birdsall', 'bysspp9qt2');
INSERT INTO public."User" VALUES ('qoujvr86k52c518s', 'croisenjb@newyorker.com', 'Lài', 'Vauls', 'hoovup6ad8');
INSERT INTO public."User" VALUES ('xiumjg34l50p485k', 'cfrymanjc@over-blog.com', 'Ruò', 'Maile', 'najlhb7gp4');
INSERT INTO public."User" VALUES ('qcqhug04u68p948h', 'mmalonejd@house.gov', 'Vénus', 'Orrow', 'cytomx8kw7');
INSERT INTO public."User" VALUES ('lqkafs68v35m039d', 'akamenje@dailymail.co.uk', 'Inès', 'Castiblanco', 'bjcdnz9xp1');
INSERT INTO public."User" VALUES ('xgdlsg09d20j444f', 'bomearajf@eventbrite.com', 'Maïté', 'Coughan', 'mvdbll7ev0');
INSERT INTO public."User" VALUES ('jxwrvj41g60x674f', 'gsiblyjg@gravatar.com', 'Judicaël', 'Gowrich', 'qefbtc6hh2');
INSERT INTO public."User" VALUES ('iaptwh25f49g525c', 'nbradnickjh@ihg.com', 'Mén', 'Mawford', 'aqbxwc3oy3');
INSERT INTO public."User" VALUES ('fdmjxt81t90a612m', 'bthompkinsji@icq.com', 'Renée', 'Mawson', 'mfzfzn6rf1');
INSERT INTO public."User" VALUES ('nfhxah90f46a395y', 'awharfjj@imageshack.us', 'Maïwenn', 'Rustich', 'lkowlo0hy6');
INSERT INTO public."User" VALUES ('fsswlb51h22r336m', 'mrankinjk@accuweather.com', 'Irène', 'Hollingdale', 'xrkpfn8zg9');
INSERT INTO public."User" VALUES ('qxfswq15q34k908d', 'ccarslakejl@gnu.org', 'Björn', 'Zwicker', 'mvodcm6zm7');
INSERT INTO public."User" VALUES ('wrzhwr12v35v469v', 'lnorthernjm@kickstarter.com', 'Åsa', 'Duckels', 'ylfxtt3jz1');
INSERT INTO public."User" VALUES ('xqjqsj22s53j343w', 'bweldsjn@youku.com', 'Séréna', 'Jerschke', 'cwrtmw9ln6');
INSERT INTO public."User" VALUES ('npaasj13w80e840k', 'slaurentyjo@mail.ru', 'Andrée', 'Westmancoat', 'qcnfdh2oj5');
INSERT INTO public."User" VALUES ('lzxfhf46x39c384y', 'jhaycoxjp@elpais.com', 'Sòng', 'Gambie', 'rrfhww1ot4');
INSERT INTO public."User" VALUES ('oafbri03z30m987q', 'dmcpakejq@illinois.edu', 'Félicie', 'Baldack', 'qlscdx5pz7');
INSERT INTO public."User" VALUES ('ubfrzb37q77v680p', 'edurnelljr@issuu.com', 'Åslög', 'Levine', 'gocrdb3mr3');
INSERT INTO public."User" VALUES ('hhbtpk61e61o291a', 'khirthejs@discuz.net', 'Noémie', 'Hutcheson', 'qaqboo9yy6');
INSERT INTO public."User" VALUES ('rlibgl30j46v371y', 'mainsliejt@usnews.com', 'Océane', 'Mathe', 'oavifg3nc5');
INSERT INTO public."User" VALUES ('kdtfcn79s21p612q', 'vyeomanju@nydailynews.com', 'Rébecca', 'Cranke', 'nfvgtl1kf4');
INSERT INTO public."User" VALUES ('fristt67s63j409v', 'rtrevnajv@edublogs.org', 'Renée', 'Nequest', 'jzrppt5uc4');
INSERT INTO public."User" VALUES ('exgomz68k77t912z', 'aloomisjw@mozilla.org', 'Lorène', 'Dodle', 'dyuyki3aq7');
INSERT INTO public."User" VALUES ('xfcicw80r08r100t', 'esteinjx@nifty.com', 'Dù', 'Simcock', 'zvgwsk0ns2');
INSERT INTO public."User" VALUES ('hvndpl50h62o530m', 'mgowdridgejy@blogtalkradio.com', 'Alizée', 'Ephson', 'lzdmwm0id2');
INSERT INTO public."User" VALUES ('bdjvbi33m53t625z', 'emainstonjz@skyrock.com', 'Mélia', 'Kitchingman', 'paqhpv4zg0');
INSERT INTO public."User" VALUES ('ffcpim26n71x325n', 'rraunk0@foxnews.com', 'Mà', 'Andriulis', 'cytsjp1va1');
INSERT INTO public."User" VALUES ('zxwbwq99l80l428o', 'ysemradk1@t.co', 'Léandre', 'Sedgman', 'ljwkad0we3');
INSERT INTO public."User" VALUES ('nudode58l02k544a', 'aedmonstonek2@sakura.ne.jp', 'Marie-hélène', 'Tomsen', 'eglkvx1yo1');
INSERT INTO public."User" VALUES ('lgeelp21x54t401o', 'jmenendesk3@last.fm', 'Östen', 'Muriel', 'tyqvma2la8');
INSERT INTO public."User" VALUES ('lhglnt17c31l069s', 'mmaccaddiek4@yellowpages.com', 'Publicité', 'De Bruijn', 'mlxboi2em4');
INSERT INTO public."User" VALUES ('zzwqfm68z09f054y', 'tbirwhistlek5@networkadvertising.org', 'Maïwenn', 'Ferriman', 'rinuws2cj5');
INSERT INTO public."User" VALUES ('dqtpkh21m26b550p', 'hpoynterk6@soundcloud.com', 'Uò', 'Jakuszewski', 'kqeicc0jy0');
INSERT INTO public."User" VALUES ('bfzdxl39q02f128t', 'pdederickk7@mozilla.org', 'Méline', 'Hritzko', 'dgthub7gj4');
INSERT INTO public."User" VALUES ('kuchaa66p97a446f', 'aduckerk8@nationalgeographic.com', 'Thérèsa', 'Daniaud', 'etbqgh8io4');
INSERT INTO public."User" VALUES ('pihtpy79q85i032p', 'pantonignettik9@apple.com', 'Intéressant', 'Fleeming', 'wevpgu0sj2');
INSERT INTO public."User" VALUES ('ukoufd29b46x227v', 'gdolligonka@linkedin.com', 'Estée', 'Mealing', 'rznaeu3cq4');
INSERT INTO public."User" VALUES ('bpwfja33i96v369r', 'gklinekb@prweb.com', 'Adélaïde', 'Gouda', 'voxfgd6bp7');
INSERT INTO public."User" VALUES ('vwmcbc15b97d930f', 'mdallinkc@i2i.jp', 'Lauréna', 'Merwe', 'joydjl6ns9');
INSERT INTO public."User" VALUES ('ardagt65d29l119c', 'doaktonkd@ca.gov', 'Gérald', 'Curthoys', 'ctdihd9bh0');
INSERT INTO public."User" VALUES ('mqqqmw89j20h581o', 'vlaidlowke@hp.com', 'Mélanie', 'Ranklin', 'ogmfnb9bw2');
INSERT INTO public."User" VALUES ('yugnle53c26d088c', 'oburrilkf@guardian.co.uk', 'Dù', 'McKintosh', 'xchbvf8ws1');
INSERT INTO public."User" VALUES ('vwkyvm19a40v432p', 'babrehartkg@buzzfeed.com', 'André', 'Arnell', 'nogokt0hi8');
INSERT INTO public."User" VALUES ('ifjogt36j16q247p', 'sdecourtkh@de.vu', 'Marlène', 'Munson', 'yvzwxm5vt9');
INSERT INTO public."User" VALUES ('dsxund34d42t407c', 'smainstoneki@microsoft.com', 'Gösta', 'Taye', 'wcqftj3ai6');
INSERT INTO public."User" VALUES ('ctlvfg39x09m076x', 'balyonovkj@wix.com', 'Örjan', 'Rolfe', 'vwnpjx6je0');
INSERT INTO public."User" VALUES ('mpmeue99o05b674v', 'acunningtonkk@weibo.com', 'Judicaël', 'Neath', 'dzvkro2xu3');
INSERT INTO public."User" VALUES ('vfbypt52f96s706s', 'aikringillkl@narod.ru', 'Eléa', 'Riordan', 'ovjsut2zp1');
INSERT INTO public."User" VALUES ('xqwlht95h90b044d', 'ggattykm@printfriendly.com', 'Nélie', 'Longworthy', 'xkxuot4bt8');
INSERT INTO public."User" VALUES ('jqfekx37i88g211s', 'asillskn@dailymotion.com', 'Océane', 'Georgeou', 'xhjslq5td5');
INSERT INTO public."User" VALUES ('duloai47d32u213i', 'slippiettko@printfriendly.com', 'Åke', 'Pickard', 'vbvtxm1ns6');
INSERT INTO public."User" VALUES ('bftxht35o53q780i', 'mcrispinkp@sfgate.com', 'Léane', 'Odo', 'rlxdkz0vm3');
INSERT INTO public."User" VALUES ('zsakvr78s35n450g', 'hquakleykq@state.tx.us', 'Eloïse', 'Soot', 'hbypnv6xw2');
INSERT INTO public."User" VALUES ('mwirvs69z57q873k', 'rfoggokr@reverbnation.com', 'Médiamass', 'Jikovsky', 'kxiutf2jy5');
INSERT INTO public."User" VALUES ('ponxcc71m36d809c', 'delbournks@gravatar.com', 'Océane', 'Hibbart', 'bcqdfd5tj9');
INSERT INTO public."User" VALUES ('tbroan15r23a113p', 'glashbrookkt@japanpost.jp', 'Médiamass', 'Elbourn', 'wyahsr5if2');
INSERT INTO public."User" VALUES ('zciqgj75r12o873c', 'nsemoninku@etsy.com', 'Marie-ève', 'Statham', 'cwiilp8qc9');
INSERT INTO public."User" VALUES ('xdanfe96h55v748q', 'hpetrakkv@hc360.com', 'Andrée', 'Malins', 'mtrutq4ih6');
INSERT INTO public."User" VALUES ('trnqnk84e29u913u', 'bbileskw@odnoklassniki.ru', 'Cunégonde', 'Patriskson', 'ahyozk4ws0');
INSERT INTO public."User" VALUES ('hkijft53v60l285u', 'cattackkx@hud.gov', 'Célia', 'Bellringer', 'lzkacl0wa8');
INSERT INTO public."User" VALUES ('lzrqne35t22d761j', 'cgounyky@sphinn.com', 'Estève', 'Bewsy', 'snozzi1ry5');
INSERT INTO public."User" VALUES ('tpzqcs75b55o919j', 'jkernaghankz@senate.gov', 'Andréanne', 'Corah', 'sskohe8zp1');
INSERT INTO public."User" VALUES ('zeoiwm49h16h840r', 'lotterwelll0@creativecommons.org', 'Méthode', 'Drillingcourt', 'fqyxeg9zq2');
INSERT INTO public."User" VALUES ('ywosjj61h39i270m', 'gleavesleyl1@xrea.com', 'Maïlys', 'Kilmary', 'pwydus3ik7');
INSERT INTO public."User" VALUES ('exgxsi88u90c580g', 'mleckyl2@timesonline.co.uk', 'Aí', 'Wheal', 'iitbpv6qg8');
INSERT INTO public."User" VALUES ('gjmrrl51s40t554j', 'sfarakerl3@plala.or.jp', 'Märta', 'Landsberg', 'dsuhho2ue4');
INSERT INTO public."User" VALUES ('ezlegw36e08f986p', 'bvanoordl4@rambler.ru', 'Lèi', 'Cocks', 'gshpfo8lv3');
INSERT INTO public."User" VALUES ('rewypw84q68f439q', 'mflattmanl5@hexun.com', 'Aurélie', 'De Ambrosis', 'hcwdmc1ou3');
INSERT INTO public."User" VALUES ('tiqcnd30c04k211w', 'aceneyl6@jimdo.com', 'Bérengère', 'Aitkin', 'wmaoyr3ex0');
INSERT INTO public."User" VALUES ('skhsvx38d57j037y', 'aguntripl7@nymag.com', 'Örjan', 'Skillman', 'otfszn1qr9');
INSERT INTO public."User" VALUES ('opkdmx82q96v497g', 'akitcatl8@topsy.com', 'Yénora', 'Loynton', 'ucrdsd5ki9');
INSERT INTO public."User" VALUES ('cklkxw52x69z099b', 'dbonassl9@fastcompany.com', 'Maëlys', 'Crann', 'myvfrh5bf0');
INSERT INTO public."User" VALUES ('pfcrwp48g10v003x', 'cblakedenla@trellian.com', 'Sélène', 'Densell', 'ewxfji1jn7');
INSERT INTO public."User" VALUES ('sblzzg67b93t197x', 'nbrasnerlb@dedecms.com', 'Yú', 'Greydon', 'mtnnon4on7');
INSERT INTO public."User" VALUES ('xrralw82e08v360o', 'pmccaghanlc@nasa.gov', 'Vérane', 'Merryweather', 'zxxkzp8fw5');
INSERT INTO public."User" VALUES ('cmzjnm08o72k409o', 'ogallahueld@edublogs.org', 'Judicaël', 'Gasnoll', 'llgqba7lo5');
INSERT INTO public."User" VALUES ('gmtjsw06w80t092i', 'otumiotole@abc.net.au', 'Táng', 'Tousy', 'fbunfz0gc8');
INSERT INTO public."User" VALUES ('scpyja36l85l617n', 'dbagotlf@indiegogo.com', 'Ráo', 'Spacey', 'ukkxwz6aa1');
INSERT INTO public."User" VALUES ('pmidcj71b33m782z', 'jtindalllg@cbsnews.com', 'Mélia', 'Creer', 'xdkjsk9ab5');
INSERT INTO public."User" VALUES ('hdpesk66x89k067c', 'wdantoniolh@un.org', 'Edmée', 'St. Hill', 'czkwrn9uv6');
INSERT INTO public."User" VALUES ('ixnpuo27k37o212m', 'saleksicli@theglobeandmail.com', 'Lén', 'Urey', 'nncnjf1bt2');
INSERT INTO public."User" VALUES ('uxkikh93r19g758u', 'cchaytorlj@dropbox.com', 'Ráo', 'Rodda', 'qtgswv0is5');
INSERT INTO public."User" VALUES ('sokctb94p27q463i', 'nhoyleslk@histats.com', 'Gérald', 'Webland', 'ntbtaq4vd6');
INSERT INTO public."User" VALUES ('jgbiei29e12j485e', 'dcolbertll@twitpic.com', 'Michèle', 'Burnip', 'isvoal7nu1');
INSERT INTO public."User" VALUES ('ssulwp93d90y984m', 'acassellslm@gnu.org', 'Salomé', 'Pinhorn', 'ngakeu4lf2');
INSERT INTO public."User" VALUES ('lohckf18x62b857g', 'sgoulthorpln@yolasite.com', 'Laurène', 'Marris', 'ktwciw2oj8');
INSERT INTO public."User" VALUES ('ktxxnl90r23g348f', 'vnassielo@noaa.gov', 'Bénédicte', 'Cawsby', 'ufswli4au9');
INSERT INTO public."User" VALUES ('vhrkqt60k00v373o', 'cpietrusiaklp@netlog.com', 'Françoise', 'Yalden', 'wpfcxl5kw1');
INSERT INTO public."User" VALUES ('tbcmfh14n72w698d', 'wcattericklq@buzzfeed.com', 'Hélène', 'Robins', 'pjpmkt6qx8');
INSERT INTO public."User" VALUES ('cbsbxx56k81t090y', 'ecrimlr@thetimes.co.uk', 'Sélène', 'McCauley', 'nhvesc5wz2');
INSERT INTO public."User" VALUES ('kvqago13f81p212u', 'cscraneyls@tinyurl.com', 'Léa', 'McCullen', 'fafxlh0pk5');
INSERT INTO public."User" VALUES ('viuddp56j62v130h', 'gshillomlt@google.it', 'Anaé', 'Trett', 'drlqab4wd3');
INSERT INTO public."User" VALUES ('adxbmd30j19z192r', 'kcarefulllu@cnn.com', 'Josée', 'Kerford', 'gwtqwg3ti8');
INSERT INTO public."User" VALUES ('hpufhh51a55b097l', 'ashrivelv@berkeley.edu', 'Mylène', 'Zylbermann', 'lxzxml0hc2');
INSERT INTO public."User" VALUES ('pdghjn91g74d623z', 'ssavourylw@ow.ly', 'Marlène', 'Rubinovitsch', 'rgwnnl1fo6');
INSERT INTO public."User" VALUES ('hiofmu56s34h169w', 'ssartinlx@tinypic.com', 'Mélanie', 'Hankinson', 'ovceou7ha9');
INSERT INTO public."User" VALUES ('bftfgh93w09r166o', 'ffranchionily@360.cn', 'Stévina', 'Dreigher', 'vsahdk2qt5');
INSERT INTO public."User" VALUES ('jsmpkt16n81s383f', 'jduggetlz@google.pl', 'Audréanne', 'Brydone', 'fpldgm5hx9');
INSERT INTO public."User" VALUES ('wcqfei19b59m823g', 'mreddecliffem0@friendfeed.com', 'Pénélope', 'Eiler', 'ivhvwy0hw6');
INSERT INTO public."User" VALUES ('xngiol60e23a374x', 'khaulkhamm1@cdbaby.com', 'Cécilia', 'Biever', 'gfharb5pe2');
INSERT INTO public."User" VALUES ('hzjqaq42a55y521k', 'dkaleym2@admin.ch', 'Léone', 'Maughan', 'puzgoj0ej8');
INSERT INTO public."User" VALUES ('rcjfqb20g23f126v', 'dbexleym3@deviantart.com', 'Maëlle', 'Simecek', 'uaylqe5qc0');
INSERT INTO public."User" VALUES ('txztth11e79e970t', 'bpapacciom4@accuweather.com', 'Håkan', 'Tuffell', 'fvbxer8oc4');
INSERT INTO public."User" VALUES ('tyytql38d10y799z', 'opeterkenm5@seattletimes.com', 'Félicie', 'Verna', 'aawrwp2wp2');
INSERT INTO public."User" VALUES ('obnfnr13v91w015v', 'mraggettm6@usa.gov', 'Cinéma', 'Vennart', 'juuvfd4ep5');
INSERT INTO public."User" VALUES ('yasykf87s26b647y', 'hbewsym7@nba.com', 'Maëlyss', 'Hayball', 'stmskh0cq1');
INSERT INTO public."User" VALUES ('ebdgff96n08s127b', 'acubittm8@prnewswire.com', 'Mà', 'Mertin', 'uwcuxt6ij8');
INSERT INTO public."User" VALUES ('sjiqwc68k85w831d', 'dransomem9@shop-pro.jp', 'Jú', 'Luther', 'bagrdw4yq2');
INSERT INTO public."User" VALUES ('clgshe63e17h166k', 'nivimyma@sohu.com', 'Agnès', 'Thatcher', 'yrxjux0wq7');
INSERT INTO public."User" VALUES ('xxqcxc35d90f267z', 'ftillyermb@amazon.co.jp', 'Stévina', 'Dudlestone', 'spcoky8xp4');
INSERT INTO public."User" VALUES ('bmoobe04g61y451e', 'ssouttarmc@ucoz.ru', 'Mélodie', 'Menauteau', 'tpxqcb9my1');
INSERT INTO public."User" VALUES ('ogujsd38d81w417k', 'cbrawsonmd@nba.com', 'Yáo', 'Reuven', 'udwexd2ut8');
INSERT INTO public."User" VALUES ('equxsr90u02a345z', 'kblankhornme@xinhuanet.com', 'Eléonore', 'Minico', 'esohpo7wa3');
INSERT INTO public."User" VALUES ('nmvemu08p21v416d', 'proofemf@addthis.com', 'Desirée', 'Pennycuick', 'jufzar3kw4');
INSERT INTO public."User" VALUES ('yuumrk01g62f471r', 'nloomismg@wp.com', 'Bérengère', 'Zapata', 'hvcivd6cc7');
INSERT INTO public."User" VALUES ('kutslw34b66r609b', 'gbauducciomh@eventbrite.com', 'Amélie', 'Proschek', 'vcwfim5lk8');
INSERT INTO public."User" VALUES ('wtoryf43s81x218d', 'fkasemi@cnbc.com', 'Estève', 'Schimoni', 'sthjbg2si0');
INSERT INTO public."User" VALUES ('qaghwm17m80y113z', 'sghidonimj@wiley.com', 'Måns', 'Ubsdell', 'fmjbdc4tg3');
INSERT INTO public."User" VALUES ('evnadj38f23k500k', 'kgrumellmk@creativecommons.org', 'Estève', 'Willoway', 'pkelke1jv9');
INSERT INTO public."User" VALUES ('eqteoh21u53s314n', 'lfassbindlerml@cnn.com', 'Cunégonde', 'Proven', 'grwvih8wx6');
INSERT INTO public."User" VALUES ('qlcfhp24s85q780o', 'sclackmm@exblog.jp', 'Göran', 'Leggon', 'epzogl6nh7');
INSERT INTO public."User" VALUES ('duhlky74h12q162o', 'cbluschkemn@constantcontact.com', 'Léa', 'Amorts', 'ntgwld8nh4');
INSERT INTO public."User" VALUES ('dzmrbh92i53p453g', 'msloweymo@posterous.com', 'Thérèsa', 'Hartless', 'gdnesv7nb5');
INSERT INTO public."User" VALUES ('ixdqul09x51b555d', 'jbeacockmp@nhs.uk', 'Maëlla', 'Bauduin', 'fguhbd8dx6');
INSERT INTO public."User" VALUES ('cjtrmh44w40w192a', 'sstittmq@blog.com', 'Esbjörn', 'Lucchi', 'nfvvwz1cq9');
INSERT INTO public."User" VALUES ('einhxg53v09c321q', 'kschrinelmr@gov.uk', 'Gaétane', 'Rennebeck', 'nrsafa0fd1');
INSERT INTO public."User" VALUES ('pykimr64x12p451h', 'madnamsms@elegantthemes.com', 'Inès', 'Chapelhow', 'gsooti3kq9');
INSERT INTO public."User" VALUES ('mopsaj64h17z948p', 'iizatsonmt@wikia.com', 'Marlène', 'Dowdle', 'spdyba0sp2');
INSERT INTO public."User" VALUES ('nlotey53e41r450n', 'cniasmu@dyndns.org', 'Börje', 'Eyckelbeck', 'faoorp9kh4');
INSERT INTO public."User" VALUES ('ykrhgl94k23d143g', 'nruppelmv@accuweather.com', 'Marie-hélène', 'Shears', 'gcrgah6st3');
INSERT INTO public."User" VALUES ('axxoid02y32q285i', 'bwestollmw@vimeo.com', 'Adélaïde', 'Wetheril', 'xqadmp9nw1');
INSERT INTO public."User" VALUES ('qibewz92c69m111l', 'kwybernmx@weibo.com', 'André', 'Archbold', 'dccubq7hi1');
INSERT INTO public."User" VALUES ('bndkoa28e01c208k', 'wnorwaymy@zimbio.com', 'Nadège', 'Fowley', 'usvlxy9ni1');
INSERT INTO public."User" VALUES ('vgrvnb89j59z180k', 'lsapshedmz@google.com.hk', 'Esbjörn', 'MacSherry', 'neycng3ie9');
INSERT INTO public."User" VALUES ('dkzjmv15x11i385a', 'cmcilwrickn0@wikipedia.org', 'Thérèsa', 'Ottawell', 'dfoymk4kr6');
INSERT INTO public."User" VALUES ('nvczjf95i29t527j', 'rzamboniarin1@usnews.com', 'Åslög', 'Neath', 'ntxbrv1kz8');
INSERT INTO public."User" VALUES ('gvycuq72l12p975j', 'lseylern2@bizjournals.com', 'Zoé', 'Kilkenny', 'jvzkwx2cr6');
INSERT INTO public."User" VALUES ('shhewd06f05a102t', 'tmccathien3@unblog.fr', 'Maëlyss', 'Brazear', 'qsdtks4mi8');
INSERT INTO public."User" VALUES ('qubzoq79c04p772k', 'ghaythn4@artisteer.com', 'Clémentine', 'Cardiff', 'llvckf9tw8');
INSERT INTO public."User" VALUES ('qnsjeq08r56k988k', 'kmapplesn5@zimbio.com', 'Mélys', 'Kettleson', 'mogqiz3ns6');
INSERT INTO public."User" VALUES ('ucnkzq22m53t597p', 'pbeadmann6@state.tx.us', 'Angélique', 'Dimmack', 'tqrdmb2ed0');
INSERT INTO public."User" VALUES ('jsbudk58y24q088o', 'mchidleyn7@paginegialle.it', 'Lén', 'Tethcote', 'sxbfvy9dw8');
INSERT INTO public."User" VALUES ('mfkdog62l63d161s', 'nhayhurstn8@reuters.com', 'Åsa', 'Fawcus', 'viqtif7ln4');
INSERT INTO public."User" VALUES ('sarvux60f29y158s', 'cbaptyn9@nydailynews.com', 'Méline', 'Paten', 'cicgst2fy0');
INSERT INTO public."User" VALUES ('nohriy95k73y200k', 'vjuettna@tumblr.com', 'Dorothée', 'Cursons', 'vtyler3dl0');
INSERT INTO public."User" VALUES ('jqvewh93j68z701g', 'adorbinnb@va.gov', 'Táng', 'Gooderidge', 'blmivy4dy9');
INSERT INTO public."User" VALUES ('qhttor58x47m066c', 'ctarbornnc@vkontakte.ru', 'Maëline', 'Beedom', 'zehuof6cf2');
INSERT INTO public."User" VALUES ('xmocmt89q12t626g', 'zhodjettsnd@eventbrite.com', 'Kuí', 'Allard', 'srnenr7ff0');
INSERT INTO public."User" VALUES ('hucyov34k17v780g', 'shurndallne@wordpress.org', 'Wá', 'Blackborough', 'luqlcj8au1');
INSERT INTO public."User" VALUES ('nhwmlw44w30l702h', 'aslidesnf@facebook.com', 'Personnalisée', 'Manvelle', 'mxufdk0bz4');
INSERT INTO public."User" VALUES ('oycydh85e02p955a', 'rfillaryng@odnoklassniki.ru', 'Pénélope', 'McGavigan', 'kieppo1tf5');
INSERT INTO public."User" VALUES ('sxmwzq91u92w214b', 'ghaggarnh@rakuten.co.jp', 'Yú', 'Andrejevic', 'iyvwfs8iu2');
INSERT INTO public."User" VALUES ('wemana21i73h832m', 'vfozardni@surveymonkey.com', 'Cléa', 'Paulazzi', 'qmjgin8lu0');
INSERT INTO public."User" VALUES ('jlrrst14y70t692c', 'dfranceschnj@archive.org', 'Bérénice', 'Malham', 'uceihs5fn2');
INSERT INTO public."User" VALUES ('butwxl50p41q322s', 'fyellopnk@ucsd.edu', 'Zoé', 'Dew', 'amlpbt4ry1');
INSERT INTO public."User" VALUES ('swrnsz54x61q992o', 'gmckinnellnl@virginia.edu', 'Angèle', 'Croley', 'hbnvgd3ng3');
INSERT INTO public."User" VALUES ('ucuaeh94x90q850l', 'nspringtorpenm@ning.com', 'Magdalène', 'McEttigen', 'gqnxna6my1');
INSERT INTO public."User" VALUES ('hblxhd02x59b770o', 'abriddocknn@nba.com', 'Laurène', 'Bellini', 'xjpuqq7eg2');
INSERT INTO public."User" VALUES ('ruzbys77c77q184a', 'gixerno@hubpages.com', 'Lài', 'Bellwood', 'sucefj9vv6');
INSERT INTO public."User" VALUES ('ptocve02t66w367p', 'fgadsonnp@netvibes.com', 'Yè', 'Warden', 'aqynss0jc8');
INSERT INTO public."User" VALUES ('htvpeo39x14x967q', 'gbikkernq@eepurl.com', 'Bécassine', 'Ingre', 'ufmqch3ov5');
INSERT INTO public."User" VALUES ('emvuvv46i53d338b', 'cmattusevichnr@boston.com', 'Marie-ève', 'MacNeilley', 'nkhdat6pq5');
INSERT INTO public."User" VALUES ('mepuof28k68t372f', 'lschermens@vkontakte.ru', 'Crééz', 'Lynett', 'vmkwps1sc6');
INSERT INTO public."User" VALUES ('vftrdm62o73p533y', 'dgoomnt@admin.ch', 'Görel', 'Jirousek', 'nmkdpf7ab2');
INSERT INTO public."User" VALUES ('nsmybb45j72k928t', 'jdelayglesianu@csmonitor.com', 'Maéna', 'St. Pierre', 'iqscqj6my7');
INSERT INTO public."User" VALUES ('ydgash45g38e546d', 'cvasyunichevnv@lycos.com', 'Noëlla', 'Brightman', 'newzvd8bn0');
INSERT INTO public."User" VALUES ('prmuko49o09l616e', 'mpacknw@webs.com', 'Andrée', 'Carnson', 'djigjc2kz6');
INSERT INTO public."User" VALUES ('zorjak20b50i009d', 'jcordnernx@abc.net.au', 'Liè', 'Stonhewer', 'qlcemr9ry3');
INSERT INTO public."User" VALUES ('rsxbfz39a45f163n', 'khaithny@friendfeed.com', 'Maëlys', 'Entwisle', 'foxkzu3yt7');
INSERT INTO public."User" VALUES ('dgktbe08n06t179e', 'hmcvaughnz@ustream.tv', 'Alizée', 'Garbar', 'yvjpbz2sf0');
INSERT INTO public."User" VALUES ('drrelb03s15v059x', 'gsilleo0@diigo.com', 'Maï', 'Kochlin', 'lswlws3aj4');
INSERT INTO public."User" VALUES ('sbkise26i66t122s', 'jburrowso1@hao123.com', 'Françoise', 'Delahunt', 'vivvrt1lw8');
INSERT INTO public."User" VALUES ('laxngo38j52m700w', 'murlingo2@wisc.edu', 'Ruò', 'Corse', 'wiolsj3di4');
INSERT INTO public."User" VALUES ('kohwcz32d46l460a', 'bjelphso3@prnewswire.com', 'Lauréna', 'Jezard', 'bpyhls9gg3');
INSERT INTO public."User" VALUES ('cqcjgg58q24c831r', 'jpetrozzio4@telegraph.co.uk', 'Camélia', 'Knight', 'nfgxpm5zh0');
INSERT INTO public."User" VALUES ('xmsijg63l12s639z', 'csermino5@nasa.gov', 'Léane', 'Orpin', 'wjwmyr8cp2');
INSERT INTO public."User" VALUES ('auooaj15j88t161n', 'bbasfordo6@twitpic.com', 'Marie-noël', 'Cordy', 'ngzokw3np0');
INSERT INTO public."User" VALUES ('fwehbk26j45c940l', 'wsheddano7@amazonaws.com', 'Méghane', 'Chatell', 'vorgjv9xc9');
INSERT INTO public."User" VALUES ('cgqumv26r82p865s', 'slococko8@illinois.edu', 'Pål', 'Petrillo', 'meobjy0zu1');
INSERT INTO public."User" VALUES ('awcdpf89m62f096x', 'pdreweryo9@businesswire.com', 'Loïs', 'Fellis', 'fqtvvs5fg0');
INSERT INTO public."User" VALUES ('aylpth64k71m888d', 'lwalpoleoa@nyu.edu', 'Tú', 'Mooring', 'molxyb5lj3');
INSERT INTO public."User" VALUES ('yczqoq98j82w144n', 'tvasiliuob@wordpress.org', 'Aloïs', 'Sturdy', 'tdqnmo7dd8');
INSERT INTO public."User" VALUES ('emdafs40a07u366v', 'lbraveryoc@epa.gov', 'Andréa', 'Laffranconi', 'sotacy5ro8');
INSERT INTO public."User" VALUES ('cjdhlm49k86n410d', 'bfeyod@privacy.gov.au', 'Marie-françoise', 'Stafford', 'rygndm7jv4');
INSERT INTO public."User" VALUES ('aiotxz32z96i872v', 'ghazeupoe@diigo.com', 'Naéva', 'Allewell', 'clabzh8ez5');
INSERT INTO public."User" VALUES ('erytna23g13n127w', 'nkobischof@w3.org', 'Salomé', 'Pimblotte', 'vjwyxo7kr4');
INSERT INTO public."User" VALUES ('xudiov93e56s778y', 'solooneyog@archive.org', 'Céline', 'Pfeffle', 'luoita0xp5');
INSERT INTO public."User" VALUES ('ibbitu67x49g514i', 'mbruunoh@zimbio.com', 'Camélia', 'Derill', 'dunhkv0xx5');
INSERT INTO public."User" VALUES ('vpdqwd67q77b872r', 'crouzetoi@deviantart.com', 'Mélys', 'Lisamore', 'ubgxdw8vy0');
INSERT INTO public."User" VALUES ('crlrhn00l98g560l', 'btreadawayoj@ucoz.ru', 'Solène', 'Copcutt', 'isauum4ko3');
INSERT INTO public."User" VALUES ('qdunvq89b81w112q', 'ssalmonok@ifeng.com', 'Audréanne', 'Sailor', 'fcvmdo6ij8');
INSERT INTO public."User" VALUES ('qrdfvx26m69v020a', 'vdurol@xinhuanet.com', 'Andrée', 'Dunlap', 'iloffx2vv0');
INSERT INTO public."User" VALUES ('gbwlfo28g88g071h', 'cmithanom@army.mil', 'Josée', 'Sandbatch', 'crqfvf0je7');
INSERT INTO public."User" VALUES ('gagpuc02z52s656a', 'asproulson@skyrock.com', 'Eléa', 'Monget', 'pmvmrv9ai1');
INSERT INTO public."User" VALUES ('lmtmdc41j16j125c', 'falamoo@cnet.com', 'Styrbjörn', 'Lambotin', 'gcaapb8wh7');
INSERT INTO public."User" VALUES ('opbtsv02u98d897y', 'coferop@amazon.co.uk', 'Béatrice', 'Bovingdon', 'bmwzux9ua0');
INSERT INTO public."User" VALUES ('qxyzjc98z31k064u', 'mtabourieroq@shinystat.com', 'Rébecca', 'McKernon', 'yqcaiv7lv4');
INSERT INTO public."User" VALUES ('aavycj77e20t882g', 'gthoraldor@scribd.com', 'Marylène', 'Josephi', 'izrxjy4hz3');
INSERT INTO public."User" VALUES ('baiobm25k20s846t', 'mrooseos@comsenz.com', 'Daphnée', 'Westphal', 'egokns5ea4');
INSERT INTO public."User" VALUES ('foymmb40r90p084x', 'ncoomberot@theguardian.com', 'Bérengère', 'Boffey', 'ioqxju9ws9');
INSERT INTO public."User" VALUES ('nwxlcb98g56e528g', 'klusheyou@i2i.jp', 'Dù', 'Lotze', 'zthajh0yj3');
INSERT INTO public."User" VALUES ('vsuhjm76b27y231s', 'vdikeov@shareasale.com', 'Audréanne', 'Sarfatti', 'gmtjnc4kq3');
INSERT INTO public."User" VALUES ('xivxll79q11v923n', 'tescotow@bing.com', 'Dorothée', 'Getcliffe', 'dhtgna8pe5');
INSERT INTO public."User" VALUES ('xhlfek60f79i314l', 'isutehallox@columbia.edu', 'Camélia', 'Stealfox', 'lhspdi1li8');
INSERT INTO public."User" VALUES ('tchwfy71w28u252i', 'gimpyoy@e-recht24.de', 'Thérèse', 'Carletto', 'srehks8sw1');
INSERT INTO public."User" VALUES ('dujejn88c17t587b', 'twooffittoz@imageshack.us', 'Loïc', 'Southcombe', 'ioywvv1zu9');
INSERT INTO public."User" VALUES ('nfmdjr50z00f926x', 'bgodsilp0@newsvine.com', 'Yáo', 'Fido', 'zhzrvx7ym4');
INSERT INTO public."User" VALUES ('zjsdeq11w23x084p', 'gcolingp1@washingtonpost.com', 'Mà', 'Babinski', 'mxagnz1mb8');
INSERT INTO public."User" VALUES ('luikgu44t38y101b', 'yrispinep2@storify.com', 'Lucrèce', 'Dewhirst', 'lvgzms5bv7');
INSERT INTO public."User" VALUES ('wdehow13a10r333m', 'adulanyp3@google.com.au', 'Pål', 'Goding', 'boyqpq4oa0');
INSERT INTO public."User" VALUES ('wfxlwp66q74u047s', 'vcawtheryp4@ca.gov', 'Pélagie', 'De Gogay', 'uedebc2cq6');
INSERT INTO public."User" VALUES ('xcxwxt17c68m371i', 'aweedp5@apple.com', 'Régine', 'Foynes', 'zmadvu3vp5');
INSERT INTO public."User" VALUES ('ouviyt71a39p590d', 'ddinkinp6@is.gd', 'Yáo', 'Selkirk', 'zkdqmy1sm1');
INSERT INTO public."User" VALUES ('uxajst00k41c368h', 'tjaslemp7@ted.com', 'Maïlis', 'Meigh', 'qgpwko1ql2');
INSERT INTO public."User" VALUES ('hrcawo27o55a913t', 'omarquetp8@statcounter.com', 'Personnalisée', 'Zywicki', 'whxnwt4xy0');
INSERT INTO public."User" VALUES ('yqenom98n71d593q', 'zenglishp9@amazon.co.uk', 'Bécassine', 'Castille', 'xeqkoi4oj9');
INSERT INTO public."User" VALUES ('dusbmk05l77w576q', 'agerypa@arstechnica.com', 'Torbjörn', 'Bontoft', 'jjiuet4gn8');
INSERT INTO public."User" VALUES ('yellrl68r45d215x', 'mallsupppb@yahoo.co.jp', 'Eléonore', 'Reeson', 'cqabzz0pf7');
INSERT INTO public."User" VALUES ('tuvgag33j43w087t', 'rdeakespc@businessinsider.com', 'Naéva', 'Faulds', 'hnsxbp1lm7');
INSERT INTO public."User" VALUES ('lncazu41q98k827o', 'dmarquesspd@amazon.co.jp', 'Zoé', 'Barltrop', 'owcovl3cp6');
INSERT INTO public."User" VALUES ('wrvbbe11l86q313x', 'mvalenciape@freewebs.com', 'Dorothée', 'Ranaghan', 'appemu0un8');
INSERT INTO public."User" VALUES ('xxpevz73k16n159e', 'kmunseypf@nydailynews.com', 'Maëlla', 'Purviss', 'sipuyf6pk0');
INSERT INTO public."User" VALUES ('zlizkw43s16s121g', 'gchevespg@ow.ly', 'Yénora', 'Martel', 'zwpbyt3hk7');
INSERT INTO public."User" VALUES ('szvzil69f96t834z', 'gburletonph@wikimedia.org', 'Pò', 'Couronne', 'xyonzk6zl2');
INSERT INTO public."User" VALUES ('lzfhbt40w47w627s', 'gbirchenoughpi@amazon.de', 'Lorène', 'Denis', 'lpujlg0sr8');
INSERT INTO public."User" VALUES ('qauyzs35h04u852z', 'cmegaineypj@ycombinator.com', 'Gwenaëlle', 'Ciobutaro', 'swspcw3sa2');
INSERT INTO public."User" VALUES ('kletzv63u76f504g', 'tambrogipk@geocities.jp', 'Thérèse', 'Dingley', 'uovazq2cs8');
INSERT INTO public."User" VALUES ('cpankf96t90w819c', 'moakwellpl@example.com', 'Maëline', 'Landor', 'fxxwit8gk3');
INSERT INTO public."User" VALUES ('olwodi94y50n287g', 'fmorecombpm@wired.com', 'Maëlys', 'Kinnoch', 'qthgcx4ur3');
INSERT INTO public."User" VALUES ('bnchvj62u93c338x', 'abalshenpn@cbc.ca', 'Dorothée', 'Warhurst', 'jfhdmx0gv4');
INSERT INTO public."User" VALUES ('upojhv85v21y657j', 'bscarlinpo@nature.com', 'Kallisté', 'Cowdry', 'knagjv6at7');
INSERT INTO public."User" VALUES ('zcixqi34p90r219c', 'ssmothpp@jugem.jp', 'Félicie', 'Fey', 'qzsddu1tg7');
INSERT INTO public."User" VALUES ('qfqoer82h27z895c', 'savopq@wired.com', 'Liè', 'Firidolfi', 'jzqacz0iu0');
INSERT INTO public."User" VALUES ('stwuym84i21m794p', 'etremontepr@4shared.com', 'Åslög', 'Sheals', 'npfyej6td0');
INSERT INTO public."User" VALUES ('emhgwp09b21w292o', 'vleyburnps@theatlantic.com', 'Gaïa', 'Henstridge', 'oyjgqa9se1');
INSERT INTO public."User" VALUES ('bfopal70y89f721o', 'echeeneypt@shinystat.com', 'Maëlle', 'Osbaldstone', 'oernxp9sr6');
INSERT INTO public."User" VALUES ('ywkwmy24d62b364d', 'krozanskipu@github.com', 'Clémentine', 'Hackinge', 'dpzrpu8th0');
INSERT INTO public."User" VALUES ('moakdn93r27i302u', 'aconcannonpv@discovery.com', 'Solène', 'Swannell', 'fncjxb7xa8');
INSERT INTO public."User" VALUES ('aqvgpk54j95u014v', 'rmactrustriepw@homestead.com', 'Gaëlle', 'Mattusevich', 'zgqtow1bq3');
INSERT INTO public."User" VALUES ('bjazhh32x77u824s', 'agorrissenpx@theguardian.com', 'Céline', 'Reaveley', 'acbdbf0us5');
INSERT INTO public."User" VALUES ('viqobg96w51c209h', 'amcpheepy@google.pl', 'Lèi', 'Jirka', 'bwciae2vg4');
INSERT INTO public."User" VALUES ('uvhxyi95f98q713g', 'loraepz@google.com', 'Bénédicte', 'Loffill', 'ddmlkk6ek7');
INSERT INTO public."User" VALUES ('nkmwvt00z94g910t', 'mbagshaweq0@earthlink.net', 'Célestine', 'Turneux', 'zmgolx8xd9');
INSERT INTO public."User" VALUES ('ykzpok36z04w358y', 'rthurskeq1@squidoo.com', 'Börje', 'Paling', 'xjvgje0zz4');
INSERT INTO public."User" VALUES ('cgclth93h04n356c', 'sgoucherq2@hugedomains.com', 'Hélèna', 'Keward', 'koyvqk6ca7');
INSERT INTO public."User" VALUES ('kabfgv84w55y983e', 'cmaciejewskiq3@squidoo.com', 'Pò', 'Kinder', 'lmyjtc2af0');
INSERT INTO public."User" VALUES ('onzptx90a15x215g', 'sspaingowerq4@oracle.com', 'Bérangère', 'Radden', 'ekpnfl8pk2');
INSERT INTO public."User" VALUES ('pndokq85r17q571i', 'wwarnesq5@phpbb.com', 'Mén', 'McEachern', 'hidlxt5bc9');
INSERT INTO public."User" VALUES ('ljways94j48y740c', 'cboshersq6@posterous.com', 'Mélinda', 'Exall', 'ejvwjf8jv5');
INSERT INTO public."User" VALUES ('cvkxuv16t63j691q', 'tbarthodq7@hc360.com', 'Jú', 'Schowenburg', 'jtswvc0lm9');
INSERT INTO public."User" VALUES ('vrootv59h13l788d', 'scolbournq8@tuttocitta.it', 'Annotée', 'Edmund', 'ukmahv3qw5');
INSERT INTO public."User" VALUES ('dfqmvw42j35g373o', 'mjainq9@aboutads.info', 'Hélèna', 'Guildford', 'dajsbv9en9');
INSERT INTO public."User" VALUES ('wzycdo43f28d433j', 'dgassonqa@ucla.edu', 'Laurène', 'Pennazzi', 'pwfkww9sx9');
INSERT INTO public."User" VALUES ('aaxsin33h11b155c', 'ddabelsqb@census.gov', 'Desirée', 'Jefford', 'vjyesz9bl4');
INSERT INTO public."User" VALUES ('etaajl96j32y708o', 'hgiacopazziqc@plala.or.jp', 'Thérèse', 'Dennes', 'yxzlgc2qz7');
INSERT INTO public."User" VALUES ('rikmtj53b43e406p', 'fcrambieqd@yale.edu', 'Táng', 'Fedoronko', 'vyqwlc4np8');
INSERT INTO public."User" VALUES ('ywteze40q58a111f', 'feslingerqe@php.net', 'Françoise', 'Dallaghan', 'zudjur7oi4');
INSERT INTO public."User" VALUES ('rgvtyx61d28g732u', 'mburlandqf@livejournal.com', 'Tán', 'Issatt', 'uspnph1mj2');
INSERT INTO public."User" VALUES ('tmptmg26g52i537v', 'frogansqg@hhs.gov', 'Göran', 'Garton', 'tfvevg1qz1');
INSERT INTO public."User" VALUES ('nyhupd23o97o684q', 'rportamqh@mapquest.com', 'Stéphanie', 'Trouncer', 'swrvro0or8');
INSERT INTO public."User" VALUES ('ozbbym77d46h491n', 'ndasqi@free.fr', 'Måns', 'Cormack', 'dlkpsh4ll6');
INSERT INTO public."User" VALUES ('yiydvq30h23f343w', 'nterryqj@shinystat.com', 'Angélique', 'Morrall', 'wuiisa5ae2');
INSERT INTO public."User" VALUES ('joasbm75r57y197m', 'gscholigqk@geocities.jp', 'Célestine', 'Salomon', 'aytzim8ov3');
INSERT INTO public."User" VALUES ('xojgfy64a46d185d', 'sdyballql@freewebs.com', 'Anaëlle', 'Gwilt', 'dzkcnq0yn4');
INSERT INTO public."User" VALUES ('wedshp22l38k746n', 'deffnertqm@businessinsider.com', 'Pò', 'Buzza', 'ncnrpa7hv9');
INSERT INTO public."User" VALUES ('mwjkfi43u97k651p', 'blineenqn@webnode.com', 'Maï', 'Biskupski', 'ymvzol5tz1');
INSERT INTO public."User" VALUES ('cartat98m24h193v', 'agwilliamqo@cdbaby.com', 'Michèle', 'Geal', 'engrza4jb5');
INSERT INTO public."User" VALUES ('ddxens63k23j237z', 'ameneghiqp@cnbc.com', 'Estée', 'Burcher', 'dhelyl2qs8');
INSERT INTO public."User" VALUES ('fkhndi08i19d412x', 'ahaylandsqq@slideshare.net', 'Athéna', 'Course', 'xyqtwp2bu5');
INSERT INTO public."User" VALUES ('cdnvrs45u23a128z', 'jdellowqr@ftc.gov', 'Liè', 'Toolan', 'kzixkq5ml6');
INSERT INTO public."User" VALUES ('mbnjdj31o81q212l', 'tlockyerqs@wikia.com', 'Adèle', 'Lared', 'zpcbjr6oo1');
INSERT INTO public."User" VALUES ('iogttg46j54t827r', 'atuffinqt@elpais.com', 'Tán', 'Matuszyk', 'kluhyz1ge6');
INSERT INTO public."User" VALUES ('adrdkg89t33m427o', 'alathanqu@walmart.com', 'Maïté', 'Kennford', 'gizcuq1bp0');
INSERT INTO public."User" VALUES ('rysyjr72u70l124k', 'cmixtureqv@51.la', 'Garçon', 'MacKintosh', 'koscsm3ys1');
INSERT INTO public."User" VALUES ('qwxyuj83d69x421j', 'msoppettqw@wordpress.com', 'Cloé', 'Binns', 'djpdrb2go1');
INSERT INTO public."User" VALUES ('ihdnpg74n92b287e', 'asilburnqx@hud.gov', 'Esbjörn', 'Farlamb', 'uzhsck8oc7');
INSERT INTO public."User" VALUES ('uikiir22c44k843o', 'mpietrasikqy@economist.com', 'Åke', 'Conyard', 'ongdca7ol0');
INSERT INTO public."User" VALUES ('ezoppc54q77u142f', 'rbowllerqz@indiegogo.com', 'Maëlle', 'Slogrove', 'nincve7tg6');
INSERT INTO public."User" VALUES ('kqwwdo80j37f487n', 'cpachtar0@ox.ac.uk', 'Eléonore', 'Kitchinham', 'rrhssc0vj7');
INSERT INTO public."User" VALUES ('mflkhj48c68t573i', 'ilowingsr1@spiegel.de', 'Maïté', 'Byfford', 'ynpvex1mm0');
INSERT INTO public."User" VALUES ('ieaqoj35w04y469o', 'nmartinsonr2@mac.com', 'Léonore', 'Benyan', 'voyoyd2ky1');
INSERT INTO public."User" VALUES ('zzpdje72f60u334g', 'atrathenr3@ow.ly', 'Néhémie', 'Andriveaux', 'nitklo1tj9');
INSERT INTO public."User" VALUES ('kudner99l61l388i', 'jgraalmanr4@ft.com', 'Maïté', 'Barriball', 'cqtfto9gz1');



--
-- TOC entry 3152 (class 2606 OID 18928)
-- Name: Assicurazione Assicurazione_pk; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Assicurazione"
    ADD CONSTRAINT "Assicurazione_pk" PRIMARY KEY (id);


--
-- TOC entry 3154 (class 2606 OID 18930)
-- Name: Assicurazione Assicurazione_pk2; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Assicurazione"
    ADD CONSTRAINT "Assicurazione_pk2" UNIQUE (tracking);


--
-- TOC entry 3156 (class 2606 OID 18932)
-- Name: Dipendente Dipendente_pk; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Dipendente"
    ADD CONSTRAINT "Dipendente_pk" PRIMARY KEY (id);


--
-- TOC entry 3158 (class 2606 OID 18934)
-- Name: Filiale Filiale_Indirizzo_UniqueK; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Filiale"
    ADD CONSTRAINT "Filiale_Indirizzo_UniqueK" UNIQUE ("città", numero_civico, regione, provincia, via);


--
-- TOC entry 3160 (class 2606 OID 18936)
-- Name: Filiale Filiale_pk; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Filiale"
    ADD CONSTRAINT "Filiale_pk" PRIMARY KEY (id);


--
-- TOC entry 3162 (class 2606 OID 18938)
-- Name: Indirizzo_Utente Indirizzo_Utente_pk; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Indirizzo_Utente"
    ADD CONSTRAINT "Indirizzo_Utente_pk" PRIMARY KEY (regione, via, numero_civico, "città", provincia);


--
-- TOC entry 3164 (class 2606 OID 18940)
-- Name: Orario Orario_pk; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Orario"
    ADD CONSTRAINT "Orario_pk" PRIMARY KEY (filiali, giorno);


--
-- TOC entry 3166 (class 2606 OID 19905)
-- Name: Pacco_Economico Pacco_Economico_pk; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Pacco_Economico"
    ADD CONSTRAINT "Pacco_Economico_pk" PRIMARY KEY (id);


--
-- TOC entry 3168 (class 2606 OID 19903)
-- Name: Pacco_Premium Pacco_pk; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Pacco_Premium"
    ADD CONSTRAINT "Pacco_pk" PRIMARY KEY (id);


--
-- TOC entry 3170 (class 2606 OID 18950)
-- Name: Reparto Reparto_pk; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Reparto"
    ADD CONSTRAINT "Reparto_pk" PRIMARY KEY (nome);


--
-- TOC entry 3172 (class 2606 OID 18952)
-- Name: Servizi Servizi_pk; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Servizi"
    ADD CONSTRAINT "Servizi_pk" PRIMARY KEY (nome, id, costo);


--
-- TOC entry 3176 (class 2606 OID 18954)
-- Name: Spedizione_Economica_Servizi Spedizione_Economica_Servizi_pk; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Spedizione_Economica_Servizi"
    ADD CONSTRAINT "Spedizione_Economica_Servizi_pk" PRIMARY KEY ("Servizio", nome_servizio, costo, tracking);


--
-- TOC entry 3174 (class 2606 OID 18956)
-- Name: Spedizione_Economica Spedizione_Economica_pk; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Spedizione_Economica"
    ADD CONSTRAINT "Spedizione_Economica_pk" PRIMARY KEY (tracking);


--
-- TOC entry 3180 (class 2606 OID 18958)
-- Name: Spedizione_Premium_Servizi Spedizione_Premium_Servizi_pk; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Spedizione_Premium_Servizi"
    ADD CONSTRAINT "Spedizione_Premium_Servizi_pk" PRIMARY KEY ("Servizio", nome_servizio, tracking, costo);


--
-- TOC entry 3178 (class 2606 OID 18960)
-- Name: Spedizione_Premium Spedizione_Premium_pk; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Spedizione_Premium"
    ADD CONSTRAINT "Spedizione_Premium_pk" PRIMARY KEY (tracking);


--
-- TOC entry 3183 (class 2606 OID 18962)
-- Name: Stato_Spedizione_Economica Stato_Spedizione_Economica_pk; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Stato_Spedizione_Economica"
    ADD CONSTRAINT "Stato_Spedizione_Economica_pk" PRIMARY KEY (filiale, data, tracking);


--
-- TOC entry 3186 (class 2606 OID 18964)
-- Name: Stato_Spedizione_Premium Stato_Spedizione_Premium_pk; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Stato_Spedizione_Premium"
    ADD CONSTRAINT "Stato_Spedizione_Premium_pk" PRIMARY KEY (tracking, filiale, data);


--
-- TOC entry 3189 (class 2606 OID 18966)
-- Name: User User_pk; Type: CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_pk" PRIMARY KEY (codice_fiscale);


--
-- TOC entry 3181 (class 1259 OID 18967)
-- Name: Stato_Spedizione_Economica_data_index; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX "Stato_Spedizione_Economica_data_index" ON public."Stato_Spedizione_Economica" USING btree (data);


--
-- TOC entry 3184 (class 1259 OID 18968)
-- Name: Stato_Spedizione_Premium_data_index; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX "Stato_Spedizione_Premium_data_index" ON public."Stato_Spedizione_Premium" USING btree (data);


--
-- TOC entry 3187 (class 1259 OID 18969)
-- Name: User_numero_telefono_email_index; Type: INDEX; Schema: public; Owner: root
--

CREATE INDEX "User_numero_telefono_email_index" ON public."User" USING btree (numero_telefono, email);


--
-- TOC entry 3211 (class 2620 OID 18970)
-- Name: Spedizione_Economica_Servizi aggiorna_costo_spedizione_economica_trigger; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER aggiorna_costo_spedizione_economica_trigger AFTER INSERT OR DELETE OR UPDATE ON public."Spedizione_Economica_Servizi" FOR EACH ROW EXECUTE FUNCTION public."spedizioneEconomica_servizi_costo"();


--
-- TOC entry 3208 (class 2620 OID 18971)
-- Name: Assicurazione check_assicurazione_trigger; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER check_assicurazione_trigger BEFORE INSERT OR UPDATE ON public."Assicurazione" FOR EACH ROW EXECUTE FUNCTION public.check_percentuale_assicurata();


--
-- TOC entry 3215 (class 2620 OID 18972)
-- Name: Stato_Spedizione_Premium check_data_trigger; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER check_data_trigger BEFORE INSERT OR UPDATE ON public."Stato_Spedizione_Premium" FOR EACH ROW EXECUTE FUNCTION public.check_data_stato_spedizione_premium();


--
-- TOC entry 3213 (class 2620 OID 18973)
-- Name: Stato_Spedizione_Economica check_data_trigger_eco; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER check_data_trigger_eco BEFORE INSERT OR UPDATE ON public."Stato_Spedizione_Economica" FOR EACH ROW EXECUTE FUNCTION public.check_data_stato_spedizione_economica();


--
-- TOC entry 3209 (class 2620 OID 18974)
-- Name: Assicurazione trg_aggiorna_assicurazione; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER trg_aggiorna_assicurazione AFTER INSERT OR UPDATE ON public."Assicurazione" FOR EACH ROW EXECUTE FUNCTION public."aggiorna_Assicurazione"();


--
-- TOC entry 3210 (class 2620 OID 18975)
-- Name: Assicurazione trg_aggiorna_costo_spedizione_premium_servizi; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER trg_aggiorna_costo_spedizione_premium_servizi AFTER INSERT OR UPDATE ON public."Assicurazione" FOR EACH ROW EXECUTE FUNCTION public.aggiorna_costo_spedizione_premium_servizi();


--
-- TOC entry 3214 (class 2620 OID 18976)
-- Name: Stato_Spedizione_Economica trg_check_data_spedizione_economica; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER trg_check_data_spedizione_economica BEFORE INSERT OR UPDATE ON public."Stato_Spedizione_Economica" FOR EACH ROW EXECUTE FUNCTION public.check_data_stato_spedizione_economica();


--
-- TOC entry 3212 (class 2620 OID 18977)
-- Name: Spedizione_Premium_Servizi trig_spedizionepremium_servizi_costo; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER trig_spedizionepremium_servizi_costo AFTER INSERT OR DELETE OR UPDATE ON public."Spedizione_Premium_Servizi" FOR EACH ROW EXECUTE FUNCTION public."spedizionePremium_servizi_costo"();


--
-- TOC entry 3190 (class 2606 OID 18978)
-- Name: Assicurazione Assicurazione_Spedizione_Premium_tracking_fk; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Assicurazione"
    ADD CONSTRAINT "Assicurazione_Spedizione_Premium_tracking_fk" FOREIGN KEY (tracking) REFERENCES public."Spedizione_Premium"(tracking) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3191 (class 2606 OID 18983)
-- Name: Dipendente Dipendente_Filiale_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Dipendente"
    ADD CONSTRAINT "Dipendente_Filiale_id_fk" FOREIGN KEY (filiale) REFERENCES public."Filiale"(id) ON UPDATE CASCADE;


--
-- TOC entry 3192 (class 2606 OID 18988)
-- Name: Dipendente Dipendente_Reparto_nome_fk; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Dipendente"
    ADD CONSTRAINT "Dipendente_Reparto_nome_fk" FOREIGN KEY (reparto) REFERENCES public."Reparto"(nome) ON UPDATE CASCADE;


--
-- TOC entry 3193 (class 2606 OID 18993)
-- Name: Indirizzo_Utente Indirizzo_Utente_User_codice_fiscale_fk; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Indirizzo_Utente"
    ADD CONSTRAINT "Indirizzo_Utente_User_codice_fiscale_fk" FOREIGN KEY ("User") REFERENCES public."User"(codice_fiscale);


--
-- TOC entry 3194 (class 2606 OID 18998)
-- Name: Orario Orario_Filiale_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Orario"
    ADD CONSTRAINT "Orario_Filiale_id_fk" FOREIGN KEY (filiali) REFERENCES public."Filiale"(id) ON UPDATE CASCADE;


--
-- TOC entry 3195 (class 2606 OID 19003)
-- Name: Pacco_Economico Pacco_Economico_Spedizione_Economica_tracking_fk; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Pacco_Economico"
    ADD CONSTRAINT "Pacco_Economico_Spedizione_Economica_tracking_fk" FOREIGN KEY (spedizione) REFERENCES public."Spedizione_Economica"(tracking);


--
-- TOC entry 3196 (class 2606 OID 19008)
-- Name: Pacco_Premium Pacco_Premium_Spedizione_Premium_tracking_fk; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Pacco_Premium"
    ADD CONSTRAINT "Pacco_Premium_Spedizione_Premium_tracking_fk" FOREIGN KEY (spedizione) REFERENCES public."Spedizione_Premium"(tracking);


--
-- TOC entry 3199 (class 2606 OID 19018)
-- Name: Spedizione_Economica_Servizi Spedizione_Economica_Servizi_Spedizione_Economica_tracking_fk; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Spedizione_Economica_Servizi"
    ADD CONSTRAINT "Spedizione_Economica_Servizi_Spedizione_Economica_tracking_fk" FOREIGN KEY (tracking) REFERENCES public."Spedizione_Economica"(tracking) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3197 (class 2606 OID 19023)
-- Name: Spedizione_Economica Spedizione_Economica_User_codice_fiscale_fk; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Spedizione_Economica"
    ADD CONSTRAINT "Spedizione_Economica_User_codice_fiscale_fk" FOREIGN KEY (mittente) REFERENCES public."User"(codice_fiscale) ON UPDATE CASCADE;


--
-- TOC entry 3198 (class 2606 OID 19028)
-- Name: Spedizione_Economica Spedizione_Economica_User_codice_fiscale_fk2; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Spedizione_Economica"
    ADD CONSTRAINT "Spedizione_Economica_User_codice_fiscale_fk2" FOREIGN KEY (destinatario) REFERENCES public."User"(codice_fiscale) ON UPDATE CASCADE;


--
-- TOC entry 3202 (class 2606 OID 19033)
-- Name: Spedizione_Premium_Servizi Spedizione_Premium_Servizi_Servizi_nome_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Spedizione_Premium_Servizi"
    ADD CONSTRAINT "Spedizione_Premium_Servizi_Servizi_nome_id_fk" FOREIGN KEY (nome_servizio, "Servizio", costo) REFERENCES public."Servizi"(nome, id, costo) ON UPDATE CASCADE;


--
-- TOC entry 3203 (class 2606 OID 19038)
-- Name: Spedizione_Premium_Servizi Spedizione_Premium_Servizi_Spedizione_Premium_tracking_fk; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Spedizione_Premium_Servizi"
    ADD CONSTRAINT "Spedizione_Premium_Servizi_Spedizione_Premium_tracking_fk" FOREIGN KEY (tracking) REFERENCES public."Spedizione_Premium"(tracking) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3200 (class 2606 OID 19043)
-- Name: Spedizione_Premium Spedizione_Premium_User_codice_fiscale_fk; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Spedizione_Premium"
    ADD CONSTRAINT "Spedizione_Premium_User_codice_fiscale_fk" FOREIGN KEY (mittente) REFERENCES public."User"(codice_fiscale) ON UPDATE CASCADE;


--
-- TOC entry 3201 (class 2606 OID 19048)
-- Name: Spedizione_Premium Spedizione_Premium_User_codice_fiscale_fk2; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Spedizione_Premium"
    ADD CONSTRAINT "Spedizione_Premium_User_codice_fiscale_fk2" FOREIGN KEY (destinatario) REFERENCES public."User"(codice_fiscale) ON UPDATE CASCADE;


--
-- TOC entry 3204 (class 2606 OID 19053)
-- Name: Stato_Spedizione_Economica Stato_Spedizione_Economica_Filiale_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Stato_Spedizione_Economica"
    ADD CONSTRAINT "Stato_Spedizione_Economica_Filiale_id_fk" FOREIGN KEY (filiale) REFERENCES public."Filiale"(id) ON UPDATE CASCADE;


--
-- TOC entry 3205 (class 2606 OID 19058)
-- Name: Stato_Spedizione_Economica Stato_Spedizione_Economica_Spedizione_Economica_tracking_fk; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Stato_Spedizione_Economica"
    ADD CONSTRAINT "Stato_Spedizione_Economica_Spedizione_Economica_tracking_fk" FOREIGN KEY (tracking) REFERENCES public."Spedizione_Economica"(tracking) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3206 (class 2606 OID 19063)
-- Name: Stato_Spedizione_Premium Stato_Spedizione_Premium_Filiale_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Stato_Spedizione_Premium"
    ADD CONSTRAINT "Stato_Spedizione_Premium_Filiale_id_fk" FOREIGN KEY (filiale) REFERENCES public."Filiale"(id) ON UPDATE CASCADE;


--
-- TOC entry 3207 (class 2606 OID 19068)
-- Name: Stato_Spedizione_Premium Stato_Spedizione_Premium_Spedizione_Premium_tracking_fk; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY public."Stato_Spedizione_Premium"
    ADD CONSTRAINT "Stato_Spedizione_Premium_Spedizione_Premium_tracking_fk" FOREIGN KEY (tracking) REFERENCES public."Spedizione_Premium"(tracking) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3336 (class 0 OID 0)
-- Dependencies: 11
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;


-- Completed on 2023-08-02 14:38:05 UTC

--
-- PostgreSQL database dump complete
--



--QUERY 
-- 1.costo medio delle spedizioni premium che hanno un assicurazione totale e un numero di servizi aggiuntivi sopra la media
drop view  if exists NumeroServiziPerOgniTracking;
create view NumeroServiziPerOgniTracking(numeroDiServizi, tracking) as
select count(*), tracking
from "Spedizione_Premium_Servizi"
group by tracking;
select avg(costo)
from "Spedizione_Premium" join NumeroServiziPerOgniTracking NSPOT on "Spedizione_Premium".tracking = NSPOT.tracking
join "Assicurazione" A on "Spedizione_Premium".tracking = A.tracking
where totale = true and numeroDiServizi > (select avg(numeroDiServizi) from NumeroServiziPerOgniTracking);

-- 2. Quali sono le spedizioni economiche e i loro servizi associati che spendono più di 10€, query parametrica
select "Spedizione_Economica".tracking, "Spedizione_Economica".costo, SES.nome_servizio, SES.costo
from "Spedizione_Economica" join "Spedizione_Economica_Servizi" SES on "Spedizione_Economica".tracking = SES.tracking
where  "Spedizione_Economica".costo > 10
order by "Spedizione_Economica".costo asc;


-- . 3 trovare il reparto con il maggior numero di personale e a quale filiale è associato
drop view  if exists numeroDipendentiReparto;
create view numeroDipendentiReparto as
select count(*) as numero_di_dipendenti, sum(stipendio_annuale) as stipendi,  reparto, filiale
from "Dipendente"
group by filiale, reparto;
select ndr.numero_di_dipendenti, ndr.stipendi, ndr.reparto, f.id, regione, città, via, provincia, numero_civico
from numeroDipendentiReparto ndr
join ( select max(numero_di_dipendenti) as max_dipendenti
    from numeroDipendentiReparto
) max_ndr on ndr.numero_di_dipendenti = max_ndr.max_dipendenti
join "Filiale" as f on filiale = id;



-- 4 per ogni filiale trovare il costo medio delle spedizioni premium e economiche che sono transitate in quella filiale
drop view if exists statoSpedizione_economica_costo;
create view statoSpedizione_economica_costo(costoMedio, filiale) as
select trunc(avg(SE.costo)::numeric,2), "Stato_Spedizione_Economica".filiale
from "Stato_Spedizione_Economica" join "Spedizione_Economica" SE on SE.tracking = "Stato_Spedizione_Economica".tracking
group by filiale;
drop view if exists statoSpedizione_premium_costo;
create view statoSpedizione_premium_costo(costoMedio, filiale) as
select trunc(avg(SP.costo)::numeric,2), SSP.filiale
from "Stato_Spedizione_Premium" SSP join "Spedizione_Premium" SP on SP.tracking = SSP.tracking
group by filiale;
select trunc(avg(SSEC.costoMedio +SSEP.costoMedio)::numeric,2) costoMedioT , SSEC.filiale, F.regione, F.città, F.via, F.provincia, F.numero_civico
from statoSpedizione_economica_costo SSEC join statoSpedizione_premium_costo SSEP on SSEC.filiale = SSEP.filiale
join "Filiale" F on SSEC.filiale = F.id
group by SSEC.filiale, F.regione, F.città, F.via, F.provincia, F.numero_civico
order by costoMedioT desc;

--5 Trova  gli user che hanno fatto da mittente sia per spedizione economica che premium e che il loro pacco aveva il valore masssimo tra tutti
drop view if exists userMax;
create view userMax as
select max(greatest("Pacco_Economico".valore, "Pacco_Premium".valore)) as value, "User".codice_fiscale
from "User" join "Spedizione_Economica" on "User".codice_fiscale = "Spedizione_Economica".mittente
join "Spedizione_Premium" on "User".codice_fiscale = "Spedizione_Premium".mittente
join "Pacco_Economico" on "Spedizione_Economica".tracking = "Pacco_Economico".spedizione
join "Pacco_Premium" on "Spedizione_Premium".tracking = "Pacco_Premium".spedizione
group by codice_fiscale;
select codice_fiscale, value
from userMax
where value = (
    select max(value) as massimo_valore
    from userMax
);


--6 Trova le filiali che hanno gestito almeno una spedizione economica
-- con un costo superiore alla media dei costi delle spedizioni economiche transitate per ogni filiale
SELECT f.id, f.città, f.provincia
FROM "Filiale" f
JOIN "Stato_Spedizione_Economica" sse ON sse.filiale = f.id
JOIN "Spedizione_Economica" se ON se.tracking = sse.tracking
WHERE se.costo > (
    SELECT AVG(se.costo)
    FROM "Spedizione_Economica" se
)
GROUP BY f.id, f.città, f.provincia
order by id asc;

--7 gli utenti che hanno registrato più di un indirizzo ma nessun pacco inviato
SELECT "User", COUNT(*) AS NumeroIndirizzi
FROM public."Indirizzo_Utente" i
LEFT JOIN public."User" u ON i."User" = u.codice_fiscale
LEFT JOIN public."Spedizione_Economica" se ON u.codice_fiscale = se.mittente
LEFT JOIN public."Spedizione_Premium" sp ON u.codice_fiscale = sp.mittente
WHERE se.mittente IS NULL AND sp.mittente IS NULL
GROUP BY "User"
HAVING COUNT(*) > 1;


--8 le spedizioni economiche e premium che sono state nel maggior numero di filiali rispetto alle altre
SELECT COUNT(tracking) AS times, tracking, 'economica' as tipologia
FROM "Stato_Spedizione_Economica"
GROUP BY tracking
HAVING COUNT(tracking) = (
    SELECT COUNT(tracking) AS max_occurrences
    FROM "Stato_Spedizione_Economica"
    GROUP BY tracking
    ORDER BY max_occurrences DESC
    LIMIT 1
)
union
SELECT COUNT(tracking) AS times, tracking, 'premium' as tipologia
FROM "Stato_Spedizione_Premium"
GROUP BY tracking
HAVING COUNT(tracking) = (
    SELECT COUNT(tracking) AS max_occurrences
    FROM "Stato_Spedizione_Premium"
    GROUP BY tracking
    ORDER BY max_occurrences DESC
    LIMIT 1
)


