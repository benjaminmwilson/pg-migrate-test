--
-- PostgreSQL database dump
--

-- Dumped from database version 10.5
-- Dumped by pg_dump version 10.5


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner:
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner:
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: "uuid-ossp"; Type: EXTENSION; Schema: -; Owner:
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner:
--

COMMENT ON EXTENSION "uuid-ossp" IS 'uuid functions';

--
-- Name: clean_refresh_tokens(); Type: FUNCTION; Schema: public; Owner: bmwilson
--

CREATE OR REPLACE FUNCTION public.clean_refresh_tokens() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  DELETE FROM refresh_token WHERE expires_at < now()::timestamptz(0);
END;
$$;


--
-- Name: exchange_refresh_token(uuid, character varying, integer); Type: FUNCTION; Schema: public; Owner: bmwilson
--

CREATE OR REPLACE FUNCTION public.exchange_refresh_token(p_old_token uuid, p_email character varying, p_lifetime_seconds integer) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_now timestamptz;
  v_new_token uuid;
  v_can_refresh integer;
BEGIN
  v_now := now()::timestamptz(0);

  SELECT COUNT(1) INTO v_can_refresh FROM refresh_token WHERE id = p_old_token AND email = p_email AND expires_at >= v_now;

  IF v_can_refresh > 0 THEN
      -- old token found for user and still valid. Issue fresh token
      SELECT issue_refresh_token(p_email, p_lifetime_seconds) INTO v_new_token;

      --expire old token 3 days from now to give some grace time in case client resubmits
      --but don't allow grace time to be extended more than once
      UPDATE refresh_token SET
      exchanged_at = v_now,
      expires_at = v_now + 259200 * interval '1 second'
      WHERE id = p_old_token AND exchanged_at IS NULL;

  END IF;

  RETURN v_new_token;

  EXCEPTION WHEN others THEN
      RETURN NULL;

END;
$$;


--
-- Name: issue_refresh_token(character varying, integer); Type: FUNCTION; Schema: public; Owner: bmwilson
--

CREATE OR REPLACE FUNCTION public.issue_refresh_token(p_email character varying, p_lifetime_seconds integer) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_now timestamptz;
  v_id uuid;
BEGIN
  v_now := now()::timestamptz(0);

  INSERT INTO refresh_token
  (issued_at, expires_at, email)
  VALUES (v_now, v_now+p_lifetime_seconds * interval '1 second', p_email)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: refresh_token; Type: TABLE; Schema: public; Owner: bmwilson
--

CREATE TABLE IF NOT EXISTS public.refresh_token (
    id uuid DEFAULT public.uuid_generate_v1mc() NOT NULL,
    exchanged_at timestamp with time zone,
    issued_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone DEFAULT now() NOT NULL,
    email character varying NOT NULL,
    CONSTRAINT refresh_token_pkey PRIMARY KEY (id)
);

--
-- Name: refresh_token_expires_at; Type: INDEX; Schema: public; Owner: bmwilson
--

CREATE INDEX IF NOT EXISTS refresh_token_expires_at ON public.refresh_token USING btree (expires_at);


--
-- PostgreSQL database dump complete
--