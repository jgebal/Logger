Rem    NAME
Rem      create_user.sql
Rem
Rem    DESCRIPTION
Rem      Use this file to create a user / schema in which to install the logger packages
Rem
Rem    NOTES
Rem      Assumes the SYS / SYSTEM user is connected.
Rem
Rem    REQUIREMENTS
Rem      - Oracle 10.2+
Rem
Rem
Rem    MODIFIED   (MM/DD/YYYY)
Rem       tmuth    11/02/2006 - Created

set define '&'

set verify off
prompt
prompt
prompt Logger create schema script.
prompt


set echo off
column 1 new_value 1 noprint
column 2 new_value 2 noprint
column 3 new_value 3 noprint
column 4 new_value 4 noprint
select null as "1", null as "2" , null as "3", null as "4" from dual where 1=0;
column sep new_value sep noprint

column logger_user       new_value logger_user       noprint
column logger_tablespace new_value logger_tablespace noprint
column temp_tablespace   new_value temp_tablespace   noprint
column logger_pass       new_value logger_pass       noprint

select coalesce('&&1','LOGGER_USER')      logger_user,
       coalesce('&&2','XNtxj8eEgA6X6b6f') logger_pass,
       coalesce('&&3','USERS')            logger_tablespace,
       coalesce('&&4','TEMP')             temp_tablespace
from dual;

create user &LOGGER_USER identified by &LOGGER_PASS default tablespace &LOGGER_TABLESPACE temporary tablespace &TEMP_TABLESPACE
/

alter user &LOGGER_USER quota unlimited on &LOGGER_TABLESPACE 
/

grant connect,create view, create job, create table, create sequence, create trigger, create procedure, create any context to &LOGGER_USER 
/

prompt
prompt
prompt &LOGGER_USER user successfully created.
prompt Important!!! Connect as the &LOGGER_USER user and run the logger_install.sql script.
prompt
prompt

exit
