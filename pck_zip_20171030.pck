CREATE OR REPLACE PACKAGE pck_zip as

/*
2012/04/11 - ������� clob_aes_compress
*/

	function clob_compress(source_clob in clob character set any_cs, source_fileName in varchar2) return blob 
    as
    language java name 'ZipLob.compress(oracle.sql.CLOB, java.lang.String) return oracle.sql.BLOB';

	function blob_compress(source_blob in blob, source_fileName in varchar2) return blob 
    as
    language java name 'ZipLob.compress(oracle.sql.BLOB, java.lang.String) return oracle.sql.BLOB';
    
function clob_aes_compress(source_clob in clob character set any_cs, source_fileName in varchar2, p_password in out varchar2) return blob;
end;
/
CREATE OR REPLACE PACKAGE BODY pck_zip
as


--------------------------------------
/*
�����-1 : e-mail ������� � ������
�����-2 : ��������� �������������
�����-3 : ������� ��������������
�����-4 : �� ��-5 ��������
�����-5 : job_id
*/
function clob_aes_compress(source_clob in clob character set any_cs, source_fileName in varchar2, p_password in out varchar2) return blob
is 
  l_pass    varchar2(200) := nvl(lower(p_password), '�����-2');
  l_email   varchar2(200);
  l_msisdn  varchar2(200);
begin
  
   if sys_context('jm_ctx','job_id') is null and p_password in ('�����-1','�����-3','�����-5') then
     l_pass := '�����-2';
   else
     l_email  := lower(j_manager.getanswerable(to_number(sys_context('jm_ctx','job_id'))));
     l_msisdn := j_manager.GetMsisdnByRecip(l_email);
   end if;

   if l_pass is null then 
     return clob_compress(source_clob, source_fileName);
   elsif (l_pass='�����-1') then
     l_pass := l_email;
   elsif (l_pass='�����-2') then
     begin
       l_pass := substr(dbms_obfuscation_toolkit.md5(input=>utl_raw.cast_to_raw(source_fileName||to_char(sysdate,'yyyymmddhh24miss'))),1,8);
     exception
     when others then
       l_pass := '123';
     end;
   elsif (l_pass='�����-3') then
     l_pass := l_msisdn;
   elsif (l_pass='�����-4') then
--     log_ovart(0,'aes','����� source_clob='||length(source_clob));
     l_pass := Rawtohex(
                dbms_obfuscation_toolkit.md5(input=>utl_raw.cast_to_raw(source_clob))
               );
   elsif (l_pass='�����-5') then
     l_pass := sys_context('jm_ctx','job_id');
   end if;
 
   insert into j_pass (FILENAME, pass) values(source_fileName, l_pass);
   commit;
   p_password := l_pass;
--   j_manager.SendSms( l_msisdn, '������ � ������ "'||source_fileName||'" : '||l_pass);
   return drastvorov.zipaesutil.zipaesclob(source_clob,source_fileName,l_pass);
end;

end;
/
