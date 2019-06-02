create or replace package test_logger
as
  --%suite(Logger)
  --%rollback(manual)

  --%beforeeach
  procedure util_test_setup;

  --%aftereach
  procedure util_test_teardown;

  --%context(Internal)

  --%test
  procedure is_number;

  --%test(assert - doesn't raise on true assertion)
  procedure assert_true;

  --%test(assert - raises exception on false assertion)
  procedure assert_false;

  --%test
  procedure get_param_clob;
  --%test
  procedure save_global_context;
  --%test
  procedure set_extra_with_params;
  --%test
  procedure get_sys_context;
  --%test
  procedure admin_security_check;
  --%test
  procedure get_level_number;
  --%test
  procedure include_call_stack;
  --%test
  procedure date_text_format_base;
  --%test
  procedure log_internal;

  --%endcontext

  --%context(Public)

  --%test
  procedure null_global_contexts;
  --%test
  procedure convert_level_char_to_num;
  --%test
  procedure convert_level_num_to_char;
  --%test
  procedure get_character_codes;
  --%test
  procedure ok_to_log;
  --%test
  procedure log_error;
  --%test
  procedure log_all_logs;
  --%test
  procedure time_start;
  --%test
  procedure time_stop;
  --%test
  procedure time_stop_fn;
  --%test
  procedure time_stop_seconds;
  --%test
  procedure get_pref;
  --%test
  procedure purge_all;
  --%test
  procedure set_level;
  --%test
  procedure tochar;
  --%test
  procedure append_param;

  --%endcontext
  
end test_logger;
/
show errors
