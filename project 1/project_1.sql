
--
-- Tutorial 4
--

-- Load tutorial_4.sql database first
-- psql -h localhost -U postgres
-- Run Query
-- \i '/home/ngzhili/github/CS2102/project_1.sql'

--
-- PostgreSQL database dump
--
-- Dumped from database version 13.8 (Ubuntu 13.8-1.pgdg20.04+1)
-- Dumped by pg_dump version 13.8 (Ubuntu 13.8-1.pgdg20.04+1)

-- \i 'C:/Users/Zhili/Desktop/CS2102 Database Systems/Tutorials/tutorial4.sql'
SET statement_timeout = 0;

SET
    lock_timeout = 0;

SET
    idle_in_transaction_session_timeout = 0;

SET
    client_encoding = 'UTF8';

SET
    standard_conforming_strings = on;

SELECT
    pg_catalog.set_config('search_path', '', false);

SET
    check_function_bodies = false;

SET
    xmloption = content;

SET
    client_min_messages = warning;

SET
    row_security = off;

DROP TABLE public.test;


SET
    default_tablespace = '';

SET
    default_table_access_method = heap;

--
-- Name: bar; Type: TABLE; Schema: public; Owner: -
--
CREATE TABLE public.test (
    a INTEGER NOT NULL,
    b INTEGER NOT NULL
);

--
-- Data for Name: airports; Type: TABLE DATA; Schema: public; Owner: -
--
COPY public.test (a, b) FROM stdin (DELIMITER ',');
1,10
2,20
3,30
4,40
\.

--
-- End of DataDump
--

