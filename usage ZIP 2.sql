alter session force parallel query parallel 5
/

begin
    execute immediate 'drop table b_temp';
exception 
    when others then null;
end;
/

create table b_temp
(
    id  number,
    d   date,
    b   blob
)
/


---------------------------------------------------
declare
  d    clob;
  err  varchar2(256);
begin
  d := to_clob('тестовая строка для архивации');
  insert into b_temp values (null, sysdate, pck_zip.clob_compress(d,'temp.txt'));
  commit;

exception when others then
    dbms_output.put_line('Error_Stack...' || CHR(10) || dbms_utility.format_error_stack());
    dbms_output.put_line('Error_Backtrace...' || CHR(10) || dbms_utility.format_error_backtrace());
    dbms_output.put_line( '----------' );
end;
/

select * from b_temp
/




---------------------------------------------------
-- Send a ascii file to a remote FTP server.
DECLARE
  l_conn  UTL_TCP.connection;
  l_clb   clob;
  l_file  varchar2(30);
BEGIN
  l_clb := to_clob('УРАААА'||chr(13)||chr(10)||'English text');
  l_conn := ftp.login('10.61.40.70', '21', 'ftp_login', 'ftp_password'); --
  ftp.put_remote_ascii_data(l_conn, 'filename.txt', l_clb);
  ftp.logout(l_conn);
  utl_tcp.close_all_connections;
END;
/