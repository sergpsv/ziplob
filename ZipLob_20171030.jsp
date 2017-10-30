create or replace and compile java source named "ZipLob" as
import oracle.sql.*;
import java.sql.*;
import java.io.IOException;
import java.io.OutputStream;
import java.io.InputStream;
import java.io.Reader;
import java.io.UnsupportedEncodingException;
import java.util.Enumeration;
import java.util.Vector;
import java.util.Calendar;
import java.util.zip.CRC32;
import java.util.zip.Deflater;
import java.util.zip.DeflaterOutputStream;
import java.util.zip.ZipException;

public class ZipLob 
{
	public static BLOB compress(CLOB ob, String fileName) throws Exception 
	{
		BLOB result = null;
		Connection con = null;
		ruZipOutputStream out = null;
		Reader in = null;
		try 
		{
			con = DriverManager.getConnection("jdbc:default:connection:");
			result = BLOB.createTemporary(con, true, BLOB.DURATION_SESSION);
			out = new ruZipOutputStream(result.getBinaryOutputStream());
			in = ob.getCharacterStream();
			out.setLevel(Deflater.BEST_COMPRESSION);
			out.putNextEntry(new ZipEntry(fileName));
			char[] str = new char[8192];
			int length;
			while ((length = in.read(str)) > 0)
				out.write((new String(str)).getBytes("Cp1251"), 0, length);
			out.closeEntry();
		}
/*		catch (Exception e)
		{
			Error[0] = e.toString();
			for(int i = 0; i < e.getStackTrace().length; i++)
			{
				Error[0] = Error[0] + "\n\t";
				Error[0] = Error[0] + e.getStackTrace()[i].toString();
			}
			throw (e);
		}*/
		finally 
		{
			if (in != null) 
				in.close();
			if (out != null) 
				out.close();
			if (con != null) 
				con.close();
		}
		return result;
	}

	public static BLOB compress(BLOB ob, String fileName) throws Exception 
	{
		BLOB result = null;
		Connection con = null;
		ruZipOutputStream out = null;
		InputStream in = null;
		try 
		{
			con = DriverManager.getConnection("jdbc:default:connection:");
			result = BLOB.createTemporary(con, true, BLOB.DURATION_SESSION);
			out = new ruZipOutputStream(result.getBinaryOutputStream());
			in = ob.getBinaryStream();
			out.setLevel(Deflater.BEST_COMPRESSION);
			out.putNextEntry(new ZipEntry(fileName));
			byte[] buf = new byte[8192];
			int length;
			while ((length = in.read(buf)) > 0)
				out.write(buf, 0, length);
			out.closeEntry();
		}
		finally 
		{
			if (in != null) 
				in.close();
			if (out != null) 
				out.close();
			if (con != null) 
				con.close();
		}
		return result;
	}
}

public class ruZipOutputStream extends DeflaterOutputStream implements ZipConstants
{
 private Vector entries = new Vector();
 private CRC32 crc = new CRC32();
 private ZipEntry curEntry = null;
 private String charset;
 
 private int curMethod;
 private int size;
 private int offset = 0;

 private byte[] zipComment = new byte[0];
 private int defaultMethod = DEFLATED;

 private static final int ZIP_STORED_VERSION = 10;
 private static final int ZIP_DEFLATED_VERSION = 20;

 public static final int STORED = 0;
 
 public static final int DEFLATED = 8;

 public ruZipOutputStream(OutputStream out)
 {
   this(out, "cp866");
 }

 public ruZipOutputStream(OutputStream out, String charsetName)
 {
   super(out, new Deflater(Deflater.DEFAULT_COMPRESSION, true));
   charset = charsetName;
 }

 public void setComment(String comment)
 {
   byte[] commentBytes;
   try
   {
     commentBytes = comment.getBytes(charset);
   }
   catch (UnsupportedEncodingException uee)
   {
     throw new AssertionError(uee);
   }
   if (commentBytes.length > 0xffff)
     throw new IllegalArgumentException("Comment too long.");
   zipComment = commentBytes;
 }

 public void setMethod(int method)
 {
   if (method != STORED && method != DEFLATED)
     throw new IllegalArgumentException("Method not supported.");
   defaultMethod = method;
 }

 public void setLevel(int level)
 {
   def.setLevel(level);
 }

 private void writeLeShort(int value) throws IOException 
 {
   out.write(value & 0xff);
   out.write((value >> 8) & 0xff);
 }

 private void writeLeInt(int value) throws IOException 
 {
   writeLeShort(value);
   writeLeShort(value >> 16);
 }

 public void putNextEntry(ZipEntry entry) throws IOException
 {
   if (entries == null)
     throw new ZipException("ruZipOutputStream was finished");

   int method = entry.getMethod();
   int flags = 0;
   if (method == -1)
     method = defaultMethod;

   if (method == STORED)
   {
     if (entry.getCompressedSize() >= 0)
     {
       if (entry.getSize() < 0)
         entry.setSize(entry.getCompressedSize());
       else if (entry.getSize() != entry.getCompressedSize())
         throw new ZipException("Method STORED, but compressed size != size");
     }
     else
       entry.setCompressedSize(entry.getSize());

     if (entry.getSize() < 0)
       throw new ZipException("Method STORED, but size not set");
     if (entry.getCrc() < 0)
       throw new ZipException("Method STORED, but crc not set");
   }
   else if (method == DEFLATED)
   {
     if (entry.getCompressedSize() < 0 || entry.getSize() < 0 || entry.getCrc() < 0)
       flags |= 8;
   }

   if (curEntry != null)
     closeEntry();

   if (entry.getTime() < 0)
     entry.setTime(System.currentTimeMillis());

   entry.flags = flags;
   entry.offset = offset;
   entry.setMethod(method);
   curMethod = method;
   writeLeInt(LOCSIG);
   writeLeShort(method == STORED ? ZIP_STORED_VERSION : ZIP_DEFLATED_VERSION);
   writeLeShort(flags);
   writeLeShort(method);
   writeLeInt(entry.getDOSTime());
   if ((flags & 8) == 0)
   {
     writeLeInt((int)entry.getCrc());
     writeLeInt((int)entry.getCompressedSize());
     writeLeInt((int)entry.getSize());
   }
   else
   {
     writeLeInt(0);
     writeLeInt(0);
     writeLeInt(0);
   }
   byte[] name;
   try
   {
     name = entry.getName().getBytes(charset);
   }
   catch (UnsupportedEncodingException uee)
   {
     throw new AssertionError(uee);
   }
   if (name.length > 0xffff)
     throw new ZipException("Name too long.");
   byte[] extra = entry.getExtra();
   if (extra == null)
     extra = new byte[0];
   writeLeShort(name.length);
   writeLeShort(extra.length);
   out.write(name);
   out.write(extra);

   offset += LOCHDR + name.length + extra.length;

   curEntry = entry;
   crc.reset();
   if (method == DEFLATED)
     def.reset();
   size = 0;
 }

 public void closeEntry() throws IOException
 {
   if (curEntry == null)
     throw new ZipException("No open entry");

   if (curMethod == DEFLATED)
     super.finish();

   int csize = curMethod == DEFLATED ? def.getTotalOut() : size;

   if (curEntry.getSize() < 0)
     curEntry.setSize(size);
   else if (curEntry.getSize() != size)
     throw new ZipException("size was " + size + ", but I expected " + curEntry.getSize());

   if (curEntry.getCompressedSize() < 0)
     curEntry.setCompressedSize(csize);
   else if (curEntry.getCompressedSize() != csize)
     throw new ZipException("compressed size was " + csize + ", but I expected " + curEntry.getSize());

   if (curEntry.getCrc() < 0)
     curEntry.setCrc(crc.getValue());
   else if (curEntry.getCrc() != crc.getValue())
     throw new ZipException("crc was " + Long.toHexString(crc.getValue()) + ", but I expected " 
       + Long.toHexString(curEntry.getCrc()));

   offset += csize;

   if (curMethod == DEFLATED && (curEntry.flags & 8) != 0)
   {
     writeLeInt(EXTSIG);
     writeLeInt((int)curEntry.getCrc());
     writeLeInt((int)curEntry.getCompressedSize());
     writeLeInt((int)curEntry.getSize());
     offset += EXTHDR;
   }

   entries.addElement(curEntry);
   curEntry = null;
 }

 public void write(byte[] b, int off, int len) throws IOException
 {
   if (curEntry == null)
     throw new ZipException("No open entry.");

   switch (curMethod)
   {
     case DEFLATED:
       super.write(b, off, len);
       break;

     case STORED:
       out.write(b, off, len);
       break;
   }

   crc.update(b, off, len);
   size += len;
 }

 public void finish() throws IOException
 {
   if (entries == null)
     return;
   if (curEntry != null)
     closeEntry();

   int numEntries = 0;
   int sizeEntries = 0;
  
   Enumeration e = entries.elements();
   while (e.hasMoreElements())
   {
     ZipEntry entry = (ZipEntry) e.nextElement();

     int method = entry.getMethod();
     writeLeInt(CENSIG);
     writeLeShort(method == STORED ? ZIP_STORED_VERSION : ZIP_DEFLATED_VERSION);
     writeLeShort(method == STORED ? ZIP_STORED_VERSION : ZIP_DEFLATED_VERSION);
     writeLeShort(entry.flags);
     writeLeShort(method);
     writeLeInt(entry.getDOSTime());
     writeLeInt((int)entry.getCrc());
     writeLeInt((int)entry.getCompressedSize());
     writeLeInt((int)entry.getSize());

     byte[] name;
     try
     {
       name = entry.getName().getBytes(charset);
     }
     catch (UnsupportedEncodingException uee)
     {
       throw new AssertionError(uee);
     }
     if (name.length > 0xffff)
       throw new ZipException("Name too long.");
     byte[] extra = entry.getExtra();
     if (extra == null)
       extra = new byte[0];
     String str = entry.getComment();
     byte[] comment;
     try
     {
       comment = str != null ? str.getBytes(charset) : new byte[0];
     }
     catch (UnsupportedEncodingException uee)
     {
       throw new AssertionError(uee);
     }
     if (comment.length > 0xffff)
       throw new ZipException("Comment too long.");

     writeLeShort(name.length);
     writeLeShort(extra.length);
     writeLeShort(comment.length);
     writeLeShort(0); /* disk number */
     writeLeShort(0); /* internal file attr */
     writeLeInt(0);   /* external file attr */
     writeLeInt(entry.offset);

     out.write(name);
     out.write(extra);
     out.write(comment);
     numEntries++;
     sizeEntries += CENHDR + name.length + extra.length + comment.length;
   }

   writeLeInt(ENDSIG);
   writeLeShort(0); /* disk number */
   writeLeShort(0); /* disk with start of central dir */
   writeLeShort(numEntries);
   writeLeShort(numEntries);
   writeLeInt(sizeEntries);
   writeLeInt(offset);
   writeLeShort(zipComment.length);
   out.write(zipComment);
   out.flush();
   entries = null;
 }
}

public class ZipEntry implements ZipConstants, Cloneable
{
 private static final int KNOWN_SIZE   = 1;
 private static final int KNOWN_CSIZE  = 2;
 private static final int KNOWN_CRC    = 4;
 private static final int KNOWN_TIME   = 8;
 private static final int KNOWN_EXTRA  = 16;

 private static Calendar cal;

 private String name;
 private int size;
 private long compressedSize = -1;
 private int crc;
 private int dostime;
 private int known = 0;
 private short method = -1;
 private byte[] extra = null;
 private String comment = null;

 int flags;              
 int offset;             

 public static final int STORED = 0;
 public static final int DEFLATED = 8;

 public ZipEntry(String name)
 {
   int length = name.length();
   if (length > 0xffff)
     throw new IllegalArgumentException("name length is " + length);
   this.name = name;
 }

 public ZipEntry(ZipEntry e)
 {
   this(e, e.name);
 }

 ZipEntry(ZipEntry e, String name)
 {
   this.name = name;
   known = e.known;
   size = e.size;
   compressedSize = e.compressedSize;
   crc = e.crc;
   dostime = e.dostime;
   method = e.method;
   extra = e.extra;
   comment = e.comment;
 }

 final void setDOSTime(int dostime)
 {
   this.dostime = dostime;
   known |= KNOWN_TIME;
 }

 final int getDOSTime()
 {
   if ((known & KNOWN_TIME) == 0)
     return 0;
   else
     return dostime;
 }

 public Object clone()
 {
   try
   {
     ZipEntry clone = (ZipEntry) super.clone();
     if (extra != null)
       clone.extra = (byte[]) extra.clone();
     return clone;
   }
   catch (CloneNotSupportedException ex)
   {
     throw new InternalError();
   }
 }

 public String getName()
 {
   return name;
 }

 public void setTime(long time)
 {
   Calendar cal = getCalendar();
   synchronized (cal)
   {
     cal.setTimeInMillis(time);
     dostime = (cal.get(Calendar.YEAR) - 1980 & 0x7f) << 25
       | (cal.get(Calendar.MONTH) + 1) << 21
       | (cal.get(Calendar.DAY_OF_MONTH)) << 16
       | (cal.get(Calendar.HOUR_OF_DAY)) << 11
       | (cal.get(Calendar.MINUTE)) << 5
       | (cal.get(Calendar.SECOND)) >> 1;
   }
   this.known |= KNOWN_TIME;
 }

 public long getTime()
 {
   parseExtra();

   if ((known & KNOWN_TIME) == 0)
     return -1;

   int sec = 2 * (dostime & 0x1f);
   int min = (dostime >> 5) & 0x3f;
   int hrs = (dostime >> 11) & 0x1f;
   int day = (dostime >> 16) & 0x1f;
   int mon = ((dostime >> 21) & 0xf) - 1;
   int year = ((dostime >> 25) & 0x7f) + 1980; 

   try
   {
     cal = getCalendar();
     synchronized (cal)
     {
       cal.set(year, mon, day, hrs, min, sec);
       return cal.getTimeInMillis();
     }
   }
   catch (RuntimeException ex)
   {
     known = known & (~KNOWN_TIME);  
/*     known &= (~KNOWN_TIME);  ошибка в этой строке была*/
     return -1;
   }
 }

 private static synchronized Calendar getCalendar()
 {
   if (cal == null)
     cal = Calendar.getInstance();
   return cal;
 }

 public void setSize(long size)
 {
   if ((size & 0xffffffff00000000L) != 0)
     throw new IllegalArgumentException();
   this.size = (int) size;
   this.known |= KNOWN_SIZE;
 }

 public long getSize()
 {
   return (known & KNOWN_SIZE) != 0 ? size & 0xffffffffL : -1L;
 }

 public void setCompressedSize(long csize)
 {
   this.compressedSize = csize;
 }

 public long getCompressedSize()
 {
   return compressedSize;
 }

 public void setCrc(long crc)
 {  
   if ((crc & 0xffffffff00000000L) != 0)
     throw new IllegalArgumentException();
   this.crc = (int) crc;
   this.known |= KNOWN_CRC;
 }

 public long getCrc()
 {
   return (known & KNOWN_CRC) != 0 ? crc & 0xffffffffL : -1L;
 }

 public void setMethod(int method)
 {
   if (method != ruZipOutputStream.STORED && method != ruZipOutputStream.DEFLATED)
     throw new IllegalArgumentException();
   this.method = (short) method;
 }

 public int getMethod()
 {
   return method;
 }

 public void setExtra(byte[] extra)
 {
   if (extra == null) 
   {
     this.extra = null;
     return;
   }
   if (extra.length > 0xffff)
     throw new IllegalArgumentException();
   this.extra = extra;
 }

 private void parseExtra()
 {
   if ((known & KNOWN_EXTRA) != 0)
     return;

   if (extra == null)
   {
     known |= KNOWN_EXTRA;
     return;
   }

   try
   {
     int pos = 0;
     while (pos < extra.length) 
     {
       int sig = (extra[pos++] & 0xff) | (extra[pos++] & 0xff) << 8;
       int len = (extra[pos++] & 0xff) | (extra[pos++] & 0xff) << 8;
       if (sig == 0x5455) 
       {
         int flags = extra[pos];
         if ((flags & 1) != 0)
         {
           long time = ((extra[pos+1] & 0xff) | (extra[pos+2] & 0xff) << 8 | (extra[pos+3] & 0xff) << 16 | (extra[pos+4] & 0xff) << 24);
           setTime(time);
         }
       }
       pos += len;
     }
   }
   catch (ArrayIndexOutOfBoundsException ex)
   {
   }

   known |= KNOWN_EXTRA;
   return;
 }

 public byte[] getExtra()
 {
   return extra;
 }

 public void setComment(String comment)
 {
   if (comment != null && comment.length() > 0xffff)
     throw new IllegalArgumentException();
   this.comment = comment;
 }

 public String getComment()
 {
   return comment;
 }

 public boolean isDirectory()
 {
   int nlen = name.length();
   return nlen > 0 && name.charAt(nlen - 1) == '/';
 }

 public String toString()
 {
   return name;
 }

 public int hashCode()
 {
   return name.hashCode();
 }
}

interface ZipConstants
{
 /* The local file header */
 int LOCHDR = 30;
 int LOCSIG = 'P'|('K'<<8)|(3<<16)|(4<<24);

 int LOCVER =  4;
 int LOCFLG =  6;
 int LOCHOW =  8;
 int LOCTIM = 10;
 int LOCCRC = 14;
 int LOCSIZ = 18;
 int LOCLEN = 22;
 int LOCNAM = 26;
 int LOCEXT = 28;

 /* The Data descriptor */
 int EXTSIG = 'P'|('K'<<8)|(7<<16)|(8<<24);
 int EXTHDR = 16;

 int EXTCRC =  4;
 int EXTSIZ =  8;
 int EXTLEN = 12;

 /* The central directory file header */
 int CENSIG = 'P'|('K'<<8)|(1<<16)|(2<<24);
 int CENHDR = 46;

 int CENVEM =  4;
 int CENVER =  6;
 int CENFLG =  8;
 int CENHOW = 10;
 int CENTIM = 12;
 int CENCRC = 16;
 int CENSIZ = 20;
 int CENLEN = 24;
 int CENNAM = 28;
 int CENEXT = 30;
 int CENCOM = 32;
 int CENDSK = 34;
 int CENATT = 36;
 int CENATX = 38;
 int CENOFF = 42;

 /* The entries in the end of central directory */
 int ENDSIG = 'P'|('K'<<8)|(5<<16)|(6<<24);
 int ENDHDR = 22;

 /* The following two fields are missing in SUN JDK */
 int ENDNRD =  4;
 int ENDDCD =  6;
 int ENDSUB =  8;
 int ENDTOT = 10;
 int ENDSIZ = 12;
 int ENDOFF = 16;
 int ENDCOM = 20;
}
/
