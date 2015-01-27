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
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: audit_log_config; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE audit_log_config (
    id integer NOT NULL,
    retention_period integer DEFAULT 2592000 NOT NULL,
    last_update integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: audit_log_config_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE audit_log_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_log_config_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE audit_log_config_id_seq OWNED BY audit_log_config.id;


--
-- Name: cache; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE cache (
    id integer NOT NULL,
    hashid character varying NOT NULL,
    data json NOT NULL,
    expires integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: cache_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE cache_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cache_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE cache_id_seq OWNED BY cache.id;


--
-- Name: desmond_job_runs; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE desmond_job_runs (
    id integer NOT NULL,
    job_id character varying NOT NULL,
    job_class character varying NOT NULL,
    user_id character varying NOT NULL,
    status character varying NOT NULL,
    queued_at timestamp without time zone NOT NULL,
    executed_at timestamp without time zone,
    completed_at timestamp without time zone,
    details json NOT NULL
);


--
-- Name: desmond_job_runs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE desmond_job_runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: desmond_job_runs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE desmond_job_runs_id_seq OWNED BY desmond_job_runs.id;


--
-- Name: export_jobs; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE export_jobs (
    id integer NOT NULL,
    name character varying NOT NULL,
    user_id integer NOT NULL,
    success_email character varying,
    failure_email character varying,
    public boolean NOT NULL,
    query text NOT NULL,
    export_format character varying NOT NULL,
    export_options json NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: export_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE export_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: export_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE export_jobs_id_seq OWNED BY export_jobs.id;


--
-- Name: que_jobs; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE que_jobs (
    priority smallint DEFAULT 100 NOT NULL,
    run_at timestamp with time zone DEFAULT now() NOT NULL,
    job_id bigint NOT NULL,
    job_class text NOT NULL,
    args json DEFAULT '[]'::json NOT NULL,
    error_count integer DEFAULT 0 NOT NULL,
    last_error text,
    queue text DEFAULT ''::text NOT NULL
);


--
-- Name: TABLE que_jobs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE que_jobs IS '3';


--
-- Name: que_jobs_job_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE que_jobs_job_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: que_jobs_job_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE que_jobs_job_id_seq OWNED BY que_jobs.job_id;


--
-- Name: queries; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE queries (
    id integer NOT NULL,
    record_time integer NOT NULL,
    db character varying NOT NULL,
    "user" character varying NOT NULL,
    pid integer NOT NULL,
    userid integer NOT NULL,
    xid integer NOT NULL,
    query text NOT NULL,
    logfile character varying NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    query_type integer NOT NULL
);


--
-- Name: queries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE queries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: queries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE queries_id_seq OWNED BY queries.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE schema_migrations (
    version character varying NOT NULL
);


--
-- Name: table_reports; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE table_reports (
    id integer NOT NULL,
    schema_name character varying NOT NULL,
    table_name character varying NOT NULL,
    table_id integer NOT NULL,
    size_in_mb integer NOT NULL,
    pct_skew_across_slices double precision NOT NULL,
    pct_slices_populated double precision NOT NULL,
    dist_key character varying,
    sort_keys json NOT NULL,
    has_col_encodings boolean NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    dist_style character varying
);


--
-- Name: table_reports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE table_reports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: table_reports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE table_reports_id_seq OWNED BY table_reports.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE users (
    id integer NOT NULL,
    email character varying NOT NULL,
    google_id character varying NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY audit_log_config ALTER COLUMN id SET DEFAULT nextval('audit_log_config_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY cache ALTER COLUMN id SET DEFAULT nextval('cache_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY desmond_job_runs ALTER COLUMN id SET DEFAULT nextval('desmond_job_runs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY export_jobs ALTER COLUMN id SET DEFAULT nextval('export_jobs_id_seq'::regclass);


--
-- Name: job_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY que_jobs ALTER COLUMN job_id SET DEFAULT nextval('que_jobs_job_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY queries ALTER COLUMN id SET DEFAULT nextval('queries_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY table_reports ALTER COLUMN id SET DEFAULT nextval('table_reports_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: audit_log_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY audit_log_config
    ADD CONSTRAINT audit_log_config_pkey PRIMARY KEY (id);


--
-- Name: cache_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY cache
    ADD CONSTRAINT cache_pkey PRIMARY KEY (id);


--
-- Name: desmond_job_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY desmond_job_runs
    ADD CONSTRAINT desmond_job_runs_pkey PRIMARY KEY (id);


--
-- Name: export_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY export_jobs
    ADD CONSTRAINT export_jobs_pkey PRIMARY KEY (id);


--
-- Name: que_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY que_jobs
    ADD CONSTRAINT que_jobs_pkey PRIMARY KEY (queue, priority, run_at, job_id);


--
-- Name: queries_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY queries
    ADD CONSTRAINT queries_pkey PRIMARY KEY (id);


--
-- Name: table_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY table_reports
    ADD CONSTRAINT table_reports_pkey PRIMARY KEY (id);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_cache_on_hashid; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_cache_on_hashid ON cache USING btree (hashid);


--
-- Name: index_desmond_job_runs_on_job_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_desmond_job_runs_on_job_id ON desmond_job_runs USING btree (job_id);


--
-- Name: index_desmond_job_runs_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_desmond_job_runs_on_user_id ON desmond_job_runs USING btree (user_id);


--
-- Name: index_export_jobs_on_public; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_export_jobs_on_public ON export_jobs USING btree (public);


--
-- Name: index_export_jobs_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_export_jobs_on_user_id ON export_jobs USING btree (user_id);


--
-- Name: index_queries_on_query_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_queries_on_query_type ON queries USING btree (query_type);


--
-- Name: index_queries_on_record_time; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_queries_on_record_time ON queries USING btree (record_time DESC);


--
-- Name: index_table_reports_on_schema_name_and_table_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_table_reports_on_schema_name_and_table_name ON table_reports USING btree (schema_name, table_name);


--
-- Name: index_table_reports_on_table_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_table_reports_on_table_id ON table_reports USING btree (table_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_users_on_email ON users USING btree (email);


--
-- Name: index_users_on_google_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_users_on_google_id ON users USING btree (google_id);


--
-- Name: queries_query_fts_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX queries_query_fts_idx ON queries USING gin (to_tsvector('english'::regconfig, query));


--
-- Name: queries_user_fts_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX queries_user_fts_idx ON queries USING gin (to_tsvector('english'::regconfig, 'user'::text));


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX unique_schema_migrations ON schema_migrations USING btree (version);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user",public;

INSERT INTO schema_migrations (version) VALUES ('1');

INSERT INTO schema_migrations (version) VALUES ('10');

INSERT INTO schema_migrations (version) VALUES ('11');

INSERT INTO schema_migrations (version) VALUES ('12');

INSERT INTO schema_migrations (version) VALUES ('13');

INSERT INTO schema_migrations (version) VALUES ('14');

INSERT INTO schema_migrations (version) VALUES ('15');

INSERT INTO schema_migrations (version) VALUES ('2');

INSERT INTO schema_migrations (version) VALUES ('3');

INSERT INTO schema_migrations (version) VALUES ('4');

INSERT INTO schema_migrations (version) VALUES ('5');

INSERT INTO schema_migrations (version) VALUES ('6');

INSERT INTO schema_migrations (version) VALUES ('7');

INSERT INTO schema_migrations (version) VALUES ('8');

INSERT INTO schema_migrations (version) VALUES ('9');

