create or replace package body test_logger
as

  -- CONTANTS
  gc_line_feed constant varchar2(1) := chr(10);
  gc_unknown_err constant varchar2(50) := 'Unknown error';
  gc_client_id constant varchar2(30) := 'test_client_id'; -- Consistent client id to use


  -- GLOBAL VARIABLES
  g_proc_name varchar2(30); -- current proc name being tested


  /**
   * Setups test
   *
   * Notes:
   *  -
   *
   * Related Tickets:
   *  -
   *
   * @author Martin D'Souza
   * @created 28-Feb-2015
   */
  procedure util_test_setup
  as
    table_does_not_exist exception;
    pragma exception_init(table_does_not_exist, -942);
  begin
    -- Drop table if it still exists
    begin
      execute immediate 'drop table logger_prefs_tmp';
    exception
      when table_does_not_exist then
        null;
    end;

    -- Create temp logger_prefs table
    execute immediate 'create table logger_prefs_tmp as select * from logger_prefs';

    -- Reset client_id
    dbms_session.set_identifier(null);

    -- Reset all contexts
    logger.null_global_contexts;

    -- Reset timers
    logger.time_reset;
    --Enable updates
    logger.g_can_update_logger_prefs := true;
  end util_test_setup;


  /**
   * Setups test
   *
   * Notes:
   *  -
   *
   * Related Tickets:
   *  -
   *
   * @author Martin D'Souza
   * @created 28-Feb-2015
   */
  procedure util_test_teardown
  as
    l_count pls_integer;
  begin
    -- Make sure logger_prefs_tmp table exists
    select count(1)
    into l_count
    from user_tables
    where table_name = 'LOGGER_PREFS_TMP';

    if l_count = 1 then

      logger.g_can_update_logger_prefs := true;
      delete from logger_prefs;

      -- Need to do an execute immediate here since logger_prefs_tmp doesn't always exist
      execute immediate 'insert into logger_prefs select * from logger_prefs_tmp';

      execute immediate 'drop table logger_prefs_tmp';
    end if;

    dbms_session.set_identifier(null);
    -- Reset timers
    logger.time_reset;
  end util_test_teardown;

  /**
   * Returns unique scope
   *
   * Notes:
   *  - This is useful when trying to back reference which log was just inserted
   *  - Should look in logger_logs_5_mins since recent
   *
   * Related Tickets:
   *  -
   *
   * @author Martin D'Souza
   * @created 2-Mar-2015
   */
  function util_get_unique_scope
    return varchar2
  as
  begin
    return lower('logger_test_' || dbms_random.string('x',20));
  end util_get_unique_scope;

  -- *** TESTS ***

  procedure is_number as
  begin
    ut.expect(logger.is_number(p_str => 'a')).to_be_false();

    ut.expect(logger.is_number(p_str => '1')).to_be_true();
  end is_number;


  procedure assert_true
  as
  begin
    --Should not raise exception
    logger.assert(1=1, 'message');
  end;

  procedure assert_false
  as
  begin
    --Assertion
    logger.assert(1=2, 'message');
    ut.fail('Expected exception but nothing raised');
  exception
    when others then
      ut.expect(sqlerrm).to_equal('ORA-20000: message');
  end;

  procedure get_param_clob
  as
    l_params logger.tab_param;
  begin

    logger.append_param(l_params, 'p_test1', 'test1');
    logger.append_param(l_params, 'p_test2', 'test2');

    ut.expect( logger.get_param_clob(p_params => l_params) ).to_equal(to_clob('p_test1: test1' || gc_line_feed || 'p_test2: test2') ) ;

  end get_param_clob;


  procedure save_global_context
  as
  begin
    -- Reset client_id
    dbms_session.set_identifier(null);
    logger.save_global_context(
      p_attribute => 'TEST',
      p_value => 'test_value',
      p_client_id => null);

    ut.expect(sys_context(logger.g_context_name, 'TEST')).to_equal('test_value');

    -- Test for client_id
    dbms_session.set_identifier(gc_client_id);
    logger.save_global_context(
      p_attribute => 'TEST',
      p_value => 'test_client_id',
      p_client_id => gc_client_id);

    ut.expect(sys_context(logger.g_context_name, 'TEST')).to_equal('test_client_id');
  end save_global_context;

  procedure set_extra_with_params
  as
    l_clob     logger_logs.extra%type;
    l_actual   logger_logs.extra%type;
    l_expected logger_logs.extra%type;
    l_params   logger.tab_param;
  begin

    -- Test empty params
    l_clob := 'test';
    l_actual := logger.set_extra_with_params(
      p_extra => l_clob,
      p_params => l_params);

    l_expected := l_clob;
    ut.expect(l_actual).to_equal(l_expected);

    -- Test one param
    logger.append_param(l_params, 'p_test1', 'test1');
    l_actual := logger.set_extra_with_params(
      p_extra => l_clob,
      p_params => l_params);

    l_expected :=
'test

*** Parameters ***

p_test1: test1';
    ut.expect(l_actual).to_equal(l_expected);

    -- Test 2 params
    logger.append_param(l_params, 'p_test2', 'test2');
    l_actual := logger.set_extra_with_params(
      p_extra => l_clob,
      p_params => l_params);

    l_expected :=
'test

*** Parameters ***

p_test1: test1
p_test2: test2';
    ut.expect(l_actual).to_equal(l_expected);

  end set_extra_with_params;


  procedure get_sys_context
  as
    l_clob clob;
  begin
    --Does not throw an exception -> success
    l_clob := logger.get_sys_context(
      p_detail_level => 'USER',
      p_vertical => false,
      p_show_null => true);

    -- The output from this is very specific to the user/setup so just going to check for any errors raised
  end get_sys_context;


  procedure admin_security_check
  as
    l_bool boolean;
  begin

    -- Test simple case
    update logger_prefs
    set pref_value = 'FALSE'
    where 1=1
      and pref_type = logger.g_pref_type_logger
      and pref_name = 'PROTECT_ADMIN_PROCS';

    ut.expect(logger.admin_security_check).to_be_true();

    -- Test when install schema is same as current schema. This should still pass
    update logger_prefs
    set pref_value = 'TRUE'
    where 1=1
      and pref_type = logger.g_pref_type_logger
      and pref_name = 'PROTECT_ADMIN_PROCS';

    update logger_prefs
    set pref_value = sys_context('USERENV','SESSION_USER')
    where 1=1
      and pref_type = logger.g_pref_type_logger
      and pref_name = 'INSTALL_SCHEMA';

    ut.expect(logger.admin_security_check).to_be_true();

    -- Test when install schema is different as current schema (still set to TRUE)
    update logger_prefs
    set pref_value = 'DUMMY'
    where 1=1
      and pref_type = logger.g_pref_type_logger
      and pref_name = 'INSTALL_SCHEMA';

    begin
      -- This should raise an exception
      l_bool := logger.admin_security_check;

      -- If got to this point then issue
      ut.fail('TRUE failing when different schema (not raising exception)');
    exception
      when others then
        ut.expect(sqlcode).to_equal(-20000);
    end;

  end admin_security_check;


  procedure get_level_number
  as
    l_level number;
  begin

    update logger_prefs
    set pref_value = 'DEBUG'
    where 1=1
      and pref_type = logger.g_pref_type_logger
      and pref_name = 'LEVEL';

    l_level := logger.get_level_number;

    ut.expect( logger.get_level_number() ).to_equal(logger.g_debug);

    -- Client level Test
    dbms_session.set_identifier(gc_client_id);
    logger.set_level(
      p_level => logger.g_error,
      p_client_id => sys_context('userenv','client_identifier')
    );

    ut.expect( logger.get_level_number() ).to_equal(logger.g_error);

  end get_level_number;


  procedure include_call_stack
  as
  begin
    --Global config set to true
    update logger_prefs
    set pref_value = 'TRUE'
    where 1=1
      and pref_type = logger.g_pref_type_logger
      and pref_name = 'INCLUDE_CALL_STACK';

    ut.expect( logger.include_call_stack() ).to_be_true();

    --Global config set to false
    update logger_prefs
    set pref_value = 'FALSE'
    where 1=1
      and pref_type = logger.g_pref_type_logger
      and pref_name = 'INCLUDE_CALL_STACK';

    -- reset contexts so that it looks at new one (could have called Logger.configure but more than what I need here)
    logger.null_global_contexts;

    ut.expect( logger.include_call_stack() ).to_be_false();

    -- Test with client config
    dbms_session.set_identifier(gc_client_id);
    logger.set_level(
      p_level => logger.g_debug,
      p_client_id => gc_client_id,
      p_include_call_stack => 'TRUE'
    );

    ut.expect( logger.include_call_stack() ).to_be_true();

  end include_call_stack;


  procedure date_text_format_base
  as
    l_start date;
    l_stop date;
  begin

    -- Test Seconds
    l_start := to_date('10-Jan-2015 20:40:10', 'DD-MON-YYYY HH24:MI:SS');
    l_stop := to_date('10-Jan-2015 20:40:20', 'DD-MON-YYYY HH24:MI:SS');
    ut.expect( logger.date_text_format_base(  p_date_start => l_start, p_date_stop => l_stop ) ).to_equal('10 seconds ago');

    -- Test Minutes
    l_start := to_date('10-Jan-2015 20:30', 'DD-MON-YYYY HH24:MI');
    l_stop := to_date('10-Jan-2015 20:40', 'DD-MON-YYYY HH24:MI');
    ut.expect( logger.date_text_format_base(  p_date_start => l_start, p_date_stop => l_stop ) ).to_equal('10 minutes ago');

    -- Test Hours (and that it's 1 hour not 1 hours)
    l_start := to_date('10-Jan-2015 20:30', 'DD-MON-YYYY HH24:MI');
    l_stop := to_date('10-Jan-2015 21:40', 'DD-MON-YYYY HH24:MI');
    ut.expect( logger.date_text_format_base(  p_date_start => l_start, p_date_stop => l_stop ) ).to_equal('1 hour ago');

    -- Test Days
    l_start := to_date('10-Jan-2015 20:30', 'DD-MON-YYYY HH24:MI');
    l_stop := to_date('12-Jan-2015 20:40', 'DD-MON-YYYY HH24:MI');
    ut.expect( logger.date_text_format_base(  p_date_start => l_start, p_date_stop => l_stop ) ).to_equal('2 days ago');

    -- Test Weeks
    l_start := to_date('10-Jan-2015 20:30', 'DD-MON-YYYY HH24:MI');
    l_stop := to_date('30-Jan-2015 20:40', 'DD-MON-YYYY HH24:MI');
    ut.expect( logger.date_text_format_base(  p_date_start => l_start, p_date_stop => l_stop ) ).to_equal('2 weeks ago');

    -- Test Months
    l_start := to_date('10-Jan-2015 20:30', 'DD-MON-YYYY HH24:MI');
    l_stop := to_date('11-Mar-2015 20:40', 'DD-MON-YYYY HH24:MI');
    ut.expect( logger.date_text_format_base(  p_date_start => l_start, p_date_stop => l_stop ) ).to_equal('2 months ago');

    -- Test Years
    l_start := to_date('10-Jan-2015 20:30', 'DD-MON-YYYY HH24:MI');
    l_stop := to_date('11-Mar-2016 20:40', 'DD-MON-YYYY HH24:MI');
    ut.expect( logger.date_text_format_base(  p_date_start => l_start, p_date_stop => l_stop ) ).to_equal('1.2 years ago');

  end date_text_format_base;


  -- Will not test date_text_format since it's dependant on current date and uses date_text_format_base

  -- Will not test get_debug_info since it's too specific to where it's being called

  procedure log_internal
  as
    l_params   logger.tab_param;
    l_scope    logger_logs.scope%type;
    l_actual   sys_refcursor;
    l_expected sys_refcursor;

  begin

    logger.append_param(l_params, 'p_test1', 'test1');

    -- Set the level to error then log at debug.
    -- Should still register since log_internal doesn't check ok_to_log (which is as expected)
    logger.set_level(p_level => logger.g_error);

    l_scope := util_get_unique_scope;
    logger.log_internal(
      p_text => 'test',
      p_log_level => logger.g_debug,
      p_scope => l_scope,
      p_extra => 'extra',
      p_callstack => null,
      p_params => l_params);

    open l_actual for
      select text, logger_level, extra
        from logger_logs_5_min
       where scope = l_scope;

    open l_expected for
      select 'test' as text,
             logger.g_debug as logger_level,
             to_clob( 'extra

*** Parameters ***

p_test1: test1' ) as extra
        from dual;

    ut.expect(l_actual).to_equal(l_expected);

    -- Add test to make sure other columns aren't null?

  end log_internal;



  -- *** PUBLIC *** --


  procedure null_global_contexts
  as
  begin

    -- Null values
    logger.null_global_contexts();

    ut.expect(sys_context(logger.g_context_name,'level')).to_be_null();
    ut.expect(sys_context(logger.g_context_name,'include_call_stack')).to_be_null();
    ut.expect(sys_context(logger.g_context_name,'plugin_fn_error')).to_be_null();

  end null_global_contexts;


  procedure convert_level_char_to_num
  as
  begin
    ut.expect(logger.convert_level_char_to_num(p_level => logger.g_error_name)).to_equal(logger.g_error);
  end convert_level_char_to_num;


  procedure convert_level_num_to_char
  as
  begin
    ut.expect(logger.convert_level_num_to_char(p_level => logger.g_information)).to_equal(logger.g_information_name);
  end convert_level_num_to_char;


  procedure get_character_codes
  as
    l_actual   varchar2(1000);
    l_expected varchar2(1000);
  begin

    --Witout common codes
    l_actual := logger.get_character_codes(
  		p_string =>
'Test
new line',
  		p_show_common_codes => false);

    l_expected :='  84,101,115,116, 10,110,101,119, 32,108,105,110,101
   T,  e,  s,  t,  ~,  n,  e,  w,   ,  l,  i,  n,  e';

    ut.expect(l_actual).to_equal(l_expected);


    --With common codes
    l_actual := logger.get_character_codes(
  		p_string =>
'Test
new line',
  		p_show_common_codes => true);

    l_expected := 'Common Codes: 13=Line Feed, 10=Carriage Return, 32=Space, 9=Tab
  84,101,115,116, 10,110,101,119, 32,108,105,110,101
   T,  e,  s,  t,  ~,  n,  e,  w,   ,  l,  i,  n,  e';

    ut.expect(l_actual).to_equal(l_expected);

  end get_character_codes;

  -- FUTURE mdsouza: Add test for get_debug_info

  procedure ok_to_log
  as
  begin
    --Test global setting
    --Arrange
    logger.set_level(p_level => logger.g_error);

    --Assert
    ut.expect(logger.ok_to_log(p_level => logger.g_debug)).to_be_false();
    ut.expect(logger.ok_to_log(p_level => logger.g_error)).to_be_true();
    ut.expect(logger.ok_to_log(p_level => logger.g_permanent)).to_be_true();

    --Test client setting
    --Arrange
    --  (Reset global level)
    logger.set_level(p_level => logger.g_debug);

    dbms_session.set_identifier(gc_client_id);
    logger.set_level(
      p_level => logger.g_error,
      p_client_id => gc_client_id);

    --Assert
    ut.expect(logger.ok_to_log(p_level => logger.g_debug)).to_be_false();
    ut.expect(logger.ok_to_log(p_level => logger.g_error)).to_be_true();
    ut.expect(logger.ok_to_log(p_level => logger.g_permanent)).to_be_true();

  end ok_to_log;

  -- ok_to_log (varchar2): Not running since it's a wrapper


  -- snapshot_apex_items not going to be tested for now

  procedure log_error
  as
    l_scope    logger_logs.scope%type := util_get_unique_scope;
    l_actual   sys_refcursor;
    l_expected sys_refcursor;
  begin

    -- Should not log
    logger.set_level(p_level => logger.g_permanent);
    logger.log_error('test', l_scope);

    open l_actual for
      select *
        from logger_logs_5_min
       where scope = l_scope;

    ut.expect(l_actual).to_be_empty();

    --Second test
    --Arrange
    logger.set_level(p_level => logger.g_debug);
    logger.log_error('test', l_scope);

    logger.g_can_update_logger_prefs := true;
    -- Reset callstack context and set pref to false to ensure that callstack is still set even though this setting is false
    update logger_prefs
    set pref_value = 'FALSE'
    where 1=1
      and pref_type = logger.g_pref_type_logger
      and pref_name = 'INCLUDE_CALL_STACK';

    -- Wipe the sys context so that it reloads
    logger.save_global_context(
      p_attribute => 'include_call_stack',
      p_value => null);

    open l_actual for
      select call_stack
      from logger_logs_5_min
      where scope = l_scope;

    ut.expect(l_actual).to_be_empty();
  end log_error;

  -- Test all log functions (except for log_error)
  procedure log_all_logs
  as
    type test_case_data is record(
      fn_name           varchar2(30),
      enabled_log_level number,
      logging_performed varchar2(1)
    );

    l_test_cases sys_refcursor;
    l_test_case  test_case_data;

    procedure test_function_on_log_level( p_test_case test_case_data )
    is
      l_scope             logger_logs.scope%type := util_get_unique_scope();
      l_logging_performed varchar2(1);
    begin
      --Arrange
      logger.set_level(p_test_case.enabled_log_level);
      --Act
      execute immediate 'begin logger.' || p_test_case.fn_name || q'!('test', :scope); end;!'
        using l_scope;
      --Assert
      select case when count(1) = 0 then 'N' else 'Y' end
             into l_logging_performed
        from logger_logs_5_min
       where scope = l_scope;

      ut.expect(l_logging_performed, p_test_case.fn_name||', enabled log level : '||p_test_case.enabled_log_level).to_equal( p_test_case.logging_performed );
    end;

  begin

    open l_test_cases for
      select 'log_permanent'   fn_name, logger.g_off          enabled_log_level, 'N' logging_performed from dual union all
      select 'log_warning'     fn_name, logger.g_off          enabled_log_level, 'N' logging_performed from dual union all
      select 'log_information' fn_name, logger.g_off          enabled_log_level, 'N' logging_performed from dual union all
      select 'log'             fn_name, logger.g_off          enabled_log_level, 'N' logging_performed from dual union all
      select 'log_permanent'   fn_name, logger.g_permanent    enabled_log_level, 'Y' logging_performed from dual union all
      select 'log_warning'     fn_name, logger.g_permanent    enabled_log_level, 'N' logging_performed from dual union all
      select 'log_information' fn_name, logger.g_permanent    enabled_log_level, 'N' logging_performed from dual union all
      select 'log'             fn_name, logger.g_permanent    enabled_log_level, 'N' logging_performed from dual union all
      select 'log_permanent'   fn_name, logger.g_error        enabled_log_level, 'Y' logging_performed from dual union all
      select 'log_warning'     fn_name, logger.g_error        enabled_log_level, 'N' logging_performed from dual union all
      select 'log_information' fn_name, logger.g_error        enabled_log_level, 'N' logging_performed from dual union all
      select 'log'             fn_name, logger.g_error        enabled_log_level, 'N' logging_performed from dual union all
      select 'log_permanent'   fn_name, logger.g_warning      enabled_log_level, 'Y' logging_performed from dual union all
      select 'log_warning'     fn_name, logger.g_warning      enabled_log_level, 'Y' logging_performed from dual union all
      select 'log_information' fn_name, logger.g_warning      enabled_log_level, 'N' logging_performed from dual union all
      select 'log'             fn_name, logger.g_warning      enabled_log_level, 'N' logging_performed from dual union all
      select 'log_permanent'   fn_name, logger.g_information  enabled_log_level, 'Y' logging_performed from dual union all
      select 'log_warning'     fn_name, logger.g_information  enabled_log_level, 'Y' logging_performed from dual union all
      select 'log_information' fn_name, logger.g_information  enabled_log_level, 'Y' logging_performed from dual union all
      select 'log'             fn_name, logger.g_information  enabled_log_level, 'N' logging_performed from dual union all
      select 'log_permanent'   fn_name, logger.g_debug        enabled_log_level, 'Y' logging_performed from dual union all
      select 'log_warning'     fn_name, logger.g_debug        enabled_log_level, 'Y' logging_performed from dual union all
      select 'log_information' fn_name, logger.g_debug        enabled_log_level, 'Y' logging_performed from dual union all
      select 'log'             fn_name, logger.g_debug        enabled_log_level, 'Y' logging_performed from dual 
      ;

    loop
      fetch l_test_cases into l_test_case;
      exit when l_test_cases%notfound;
      test_function_on_log_level(l_test_case);
    end loop;

  end log_all_logs;


  -- get_cgi_env requires http connection so no tests for now (can simulate in future)

  -- log_userenv: Dependant on get_sys_context which varies for each system

  -- log_cgi_env: Same as above

  -- log_character_codes: covered in get_character_codes

  -- log_apex_items: Future / dependant on APEX instance

  procedure time_start
  as
    l_unit_name logger_logs.unit_name%type := util_get_unique_scope();
    l_text      logger_logs.text%type;
  begin

    logger.set_level(logger.g_timing);

    logger.time_start(
      p_unit => l_unit_name,
      p_log_in_table => true
    );

    select max(text)
      into l_text
      from logger_logs_5_min
     where unit_name = upper(l_unit_name);

    ut.expect(l_text).to_equal('START: ' || l_unit_name);

  end time_start;


  procedure time_stop
  as
    l_unit_name  logger_logs.unit_name%type := util_get_unique_scope;
    l_scope      logger_logs.scope%type := util_get_unique_scope;
    l_text       logger_logs.text%type;
    l_sleep_time number := 1;
  begin
    --Arrange
    logger.set_level(logger.g_debug); -- Time stop only requires g_debug

    logger.time_start(
      p_unit => l_unit_name,
      p_log_in_table => false
    );

    dbms_lock.sleep(l_sleep_time + 0.1);
    --Act
    logger.time_stop(
      p_unit => l_unit_name,
      p_scope => l_scope
    );
    --Assert
    select max(text)
    into l_text
    from logger_logs_5_min
    where scope = l_scope;

    ut.expect(l_text).to_be_like('STOP : ' || l_unit_name || ' - 00:00:0' || l_sleep_time || '%');

  end time_stop;


  procedure time_stop_fn
  as
    l_unit_name logger_logs.unit_name%type := util_get_unique_scope;
    l_sleep_time number := 1;
    l_text varchar2(50);
  begin

    logger.set_level(logger.g_debug);

    logger.time_start(
      p_unit => l_unit_name,
      p_log_in_table => false
    );

    dbms_lock.sleep(l_sleep_time+0.1);

    l_text := logger.time_stop(p_unit => l_unit_name);

    ut.expect(l_text).to_be_like('00:00:0' || l_sleep_time || '%');

  end time_stop_fn;


  procedure time_stop_seconds
  as
    l_unit_name logger_logs.unit_name%type := util_get_unique_scope;
    l_sleep_time number := 1;
    l_text varchar2(50);
  begin
    g_proc_name := 'time_stop_seconds';

    logger.set_level(logger.g_debug);

    logger.time_start(
      p_unit => l_unit_name,
      p_log_in_table => false
    );

    dbms_lock.sleep(l_sleep_time + 0.05);

    l_text := logger.time_stop_seconds(p_unit => l_unit_name);

    ut.expect(l_text).to_be_like(l_sleep_time || '.0%');

  end time_stop_seconds;


  -- time_reset: won't test for now

  procedure get_pref
  as
    l_pref logger_prefs.pref_value%type;
  begin
    --Arrange
    logger.set_level(p_level => logger.g_debug);
    --Act
    l_pref := nvl(logger.get_pref('LEVEL'), 'a');
    --Assert
    ut.expect(l_pref).to_equal(logger.g_debug_name);

    --Arrange
    dbms_session.set_identifier(gc_client_id);
    logger.set_level(
      p_level => logger.g_warning,
      p_client_id => gc_client_id);
    --Act
    l_pref := nvl(logger.get_pref('LEVEL'), 'a');
    --Assert
    ut.expect(l_pref).to_equal(logger.g_warning_name);

  end get_pref;

  -- purge

  procedure purge_all
  as
    l_count pls_integer;
  begin
    g_proc_name := 'purge_all';

    logger.set_level(p_level => logger.g_debug);
    logger.log('test');

    logger.purge_all;

    select count(1)
     into l_count
     from logger_logs
    where logger_level > logger.g_permanent;

    ut.expect(l_count).to_equal(0);

  end purge_all;

  -- status: Won't test since no real easy way to test output


  procedure set_level
  as
    l_scope      logger_logs.scope%type;
    l_call_stack logger_logs.call_stack%type;

    function log_and_count return integer
    as
      l_count      integer;
    begin
      l_scope := util_get_unique_scope;
      logger.log('test', l_scope);

      select count(1)
        into l_count
        from logger_logs_5_min
       where scope = l_scope;

      return l_count;
    end log_and_count;

  begin
    logger.set_level(p_level => logger.g_debug);
    ut.expect(log_and_count()).to_equal(1);

    logger.set_level(p_level => logger.g_error);
    ut.expect(log_and_count()).to_equal(0);

    -- Test client specific
    dbms_session.set_identifier(gc_client_id);
    -- Disable logging globally then set on for client
    logger.set_level(p_level => logger.g_error);
    logger.set_level(
      p_level => logger.g_debug,
      p_client_id => gc_client_id,
      p_include_call_stack => 'TRUE');

    ut.expect(log_and_count()).to_equal(1);
    -- Test callstack
    select max(call_stack)
      into l_call_stack
      from logger_logs_5_min
     where scope = l_scope;
    ut.expect(l_call_stack).not_to_be_null();


    -- Test callstack off
    logger.set_level(
      p_level => logger.g_debug,
      p_client_id => gc_client_id,
      p_include_call_stack => 'FALSE');

    ut.expect(log_and_count()).to_equal(1);
    -- Test callstack
    select max(call_stack)
      into l_call_stack
      from logger_logs_5_min
     where scope = l_scope;

    ut.expect(l_call_stack).not_to_be_null();

    -- Testing unset_client_level here since structure is in place

    logger.set_level(p_level => logger.g_error);
    logger.set_level(
      p_level => logger.g_debug,
      p_client_id => gc_client_id,
      p_include_call_stack => 'TRUE');

    logger.unset_client_level(p_client_id => gc_client_id);
    ut.expect(log_and_count()).to_equal(0);

  end set_level;


  -- unset_client_level (tested above)

  -- unset_client_level

  -- unset_client_level_all

  -- sqlplus_format

  -- Test all tochar commands
  procedure tochar
  as
    l_val varchar2(255);
  begin

    ut.expect(logger.tochar(1)).to_equal('1');

    ut.expect(logger.tochar(to_date('1-Jan-2013','dd-mon-yyyy'))).to_equal('01-JAN-2013 00:00:00');
    ut.expect(logger.tochar(to_timestamp ('10-sep-02 14:10:10.123000', 'dd-mon-rr hh24:mi:ss.ff'))).to_equal('10-SEP-2002 14:10:10:123000000');


    ut.expect(logger.tochar(to_timestamp_tz('1999-12-01 11:00:00 -8:00', 'yyyy-mm-dd hh:mi:ss tzh:tzm'))).to_equal('01-DEC-1999 11:00:00:000000000 -08:00');
    -- Local timezone based on above and is dependant on each system
    ut.expect(logger.tochar(true) || ':' || logger.tochar(false)).to_equal('TRUE:FALSE');

  end tochar;


  procedure append_param
  as
    l_params logger.tab_param;
  begin

    logger.append_param(
      p_params => l_params,
      p_name => 'test',
      p_val => 'val');

    ut.expect(l_params.count).to_equal(1);
    ut.expect(l_params(1).name).to_equal('test');
    ut.expect(l_params(1).val).to_equal('val');

  end append_param;

  -- TODO: ins_logger_logs (to test post functions)

  -- TODO: get_fmt_msg are we adding it in here?


end test_logger;
/
show errors
