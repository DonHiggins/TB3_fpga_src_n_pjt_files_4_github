Option Explicit
'- - - - - - - - - - - - - - -
' FPGA_Timestamp_TB3 -- automatically edit a Verilog file
'                       insert current date and time info
'
'- - - - - - - - - - - - - - -
Dim Original_Rev_String
Dim Original_Timestamp
Dim New_Rev_String
Dim New_Timestamp

call locate_all_timestamps_in_folder
WScript.Quit 'Normal end to script
'- - - - - - - - - - - - - - -
'
Function hex_from_char_in_string(character_string)
'
' Called with a character string
' Returns a string of 2-digit hex numbers representing characters in string

  Dim i, length, c, h

  while i < Len(character_string)
    i = i + 1
    c = Mid(character_string,i,1)
    h = Hex(Asc(c))
    if Len(h) < 2 Then h = "0" & h
    hex_from_char_in_string = hex_from_char_in_string & "0x" & h & " "
  wend


End Function

'
'- - - - - - - - - - - - - - -
'
Function yymmdd_from_FormatDate(Fmt_Date)
'
' Called with a string containing a date like 12/23/52 or 1/1/2001
' Returns a 6-character yymmdd format of the date.
' Used in creating a filename like fname_yymmdd 
'
  Dim mm
  Dim dd
  Dim yy
  Dim s_Date
  s_Date = Fmt_Date
  mm = Mid(s_Date,1,InStr(1,s_Date,"/") - 1)
  s_Date = Mid(s_Date,InStr(1,s_Date,"/") + 1)
  dd = Mid(s_Date,1,InStr(1,s_Date,"/") - 1)
  yy = Mid(s_Date,InStr(1,s_Date,"/") + 1)
  if (Len(mm) < 2) then mm = "0" & mm 
  if (Len(dd) < 2) then dd = "0" & dd 
  if (Len(yy) < 2) then yy = "0" & yy 
  if (Len(yy) > 2) then yy = Right(yy,2)
  yymmdd_from_FormatDate = yy & mm & dd
End Function

'- - - - - - - - - - - - - - -
'
Function hrmn_from_FormatDate(s_Time)
'
' Called with a string containing a time like 12:18 or 1:05
' Returns a 4-character hrmn format of the time.
' Used in creating a fixed-length timestamp. 
'
  Dim hr
  Dim mn

  hr = Mid(s_Time,1,InStr(1,s_Time,":") - 1)
  mn = Mid(s_Time,InStr(1,s_Time,":") + 1)
  if (Len(hr) < 2) then hr = "0" & hr 
  if (Len(mn) < 2) then mn = "0" & mn 
  hrmn_from_FormatDate = hr & mn

End Function
'- - - - - - - - - - - - - - -
'
Function Number_From_2_Hex_Ascii_Char(H2)

  H2 = UCase(H2)
  Number_From_2_Hex_Ascii_Char = Asc(Mid(H2,1,1)) - Asc("0")
  If (Asc(Mid(H2,1,1)) >= Asc("A")) Then
    Number_From_2_Hex_Ascii_Char = 10 + Asc(Mid(H2,1,1)) - Asc("A")
  End if
  
  Number_From_2_Hex_Ascii_Char = Number_From_2_Hex_Ascii_Char * 16
  If (Asc(Mid(H2,2,1)) >= Asc("A")) Then
    Number_From_2_Hex_Ascii_Char = Number_From_2_Hex_Ascii_Char + 10 + Asc(Mid(H2,2,1)) - Asc("A")
  Else
    Number_From_2_Hex_Ascii_Char = Number_From_2_Hex_Ascii_Char + Asc(Mid(H2,2,1)) - Asc("0")
  End if
  
  'WScript.echo "H2: " & H2 & " Num:" & Number_From_2_Hex_Ascii_Char
  
End Function
'- - - - - - - - - - - - - - -
'
Function Parse_Numeric_Info_From_Rev_String(Rev_String)
' There's got to be an easier way than this.
' Here we extract the next numeric info from Rev_String and return it,
' having also discarded leading characters from Rev_String

  Dim Num_String
  
  'Discard non-numeric lead characters 1 at a time
  While ((Len(Rev_String) > 0) And (Not IsNumeric(Mid(Rev_String,1,1))))
    Rev_String = Mid(Rev_String,2)
  Wend
  'Extract Numeric Characters
  Num_String = ""
  While ((Len(Rev_String) > 0) And (IsNumeric(Mid(Rev_String,1,1))))
    Num_String = Num_String & Mid(Rev_String,1,1)
	Rev_String = Mid(Rev_String,2)
  Wend
  Parse_Numeric_Info_From_Rev_String = Num_String
End Function
'- - - - - - - - - - - - - - -
'
Function Does_User_Want_to_Change_Revision(Rev1, Rev2, Rev3, FPGA)

  Dim Rev_String
  Dim prompt_String
  
  Rev_String = "Rev: " & Rev1 & "." & Rev2 & "." & Rev3 & " F" & FPGA
  Original_Rev_String = Rev_String

  prompt_string = "Want to update FPGA Revision Info? " & Chr(13) & Chr(10)_
                & " " & Chr(13) & Chr(10)_
                & "  or CANCEL to exit." & Chr(13) & Chr(10)_
                & " " 

  Rev_String = InputBox(prompt_string, "FPGA_Timestamp_TB3",_
                 Rev_String)
  'If operator clicks CANCEL, InputBox returns zero length string ("")
  if (Rev_String = "") Then WScript.Quit 'operator CANCELED script

  ' Parse numerical revision info out of rev_string
  Rev1 = Parse_Numeric_Info_From_Rev_String(Rev_String)
  Rev2 = Parse_Numeric_Info_From_Rev_String(Rev_String)
  Rev3 = Parse_Numeric_Info_From_Rev_String(Rev_String)
  FPGA = Parse_Numeric_Info_From_Rev_String(Rev_String)
  
  Does_User_Want_to_Change_Revision = True
End Function
'- - - - - - - - - - - - - - -
'
Sub Insert_Firmware_Timestamp(modify_this_Verilog_src_file)
'
'Read the given file, looking for "firmware_timestamp1 <= X"""
'Replace the following timestamp info with current yymm ddhr & mnA5
'  for timestamps 1, 2 and 3 respectively.

  Dim contents_of_file, copy_of_contents
  Dim fso, f, Msg
  Const ForReading = 1, ForWriting = 2, ForAppending = 8
  Dim yymmdd, hrmn, i, j
  Dim rewrite
  Dim Rev1, Rev2, Rev3, FPGA
  Dim H2
  Dim Original_YYMMDDHrMn, New_YYMMDDHrMn

  'Don't rewrite unless we find a timestamp and update it
  rewrite = False

  'Read entire contents of Verilog Source file into contents_of_file
  Set fso = CreateObject("Scripting.FileSystemObject")
  Set f = fso.OpenTextFile(modify_this_Verilog_src_file, ForReading)
  contents_of_file = f.ReadAll

  'Get current yymmdd and hrmn  
  yymmdd = yymmdd_from_FormatDate(FormatDateTime(Date))
  hrmn = hrmn_from_FormatDate(FormatDateTime(Time,4))

  Original_YYMMDDHrMn = ""
  i = InStr(1,contents_of_file,"FW_TIMESTAMP_VALUE_1  = 16'h")
  if i > 0 then
    Original_YYMMDDHrMn = Original_YYMMDDHrMn & Mid(contents_of_file,I + 28, 4)
    rewrite = True 
    copy_of_contents = Mid(contents_of_file,1,I - 1) _
       & "FW_TIMESTAMP_VALUE_1  = 16'h" _
         & Left(yymmdd,4) _
     & Mid(contents_of_file,I + 32)
    contents_of_file = copy_of_contents
  end if

  i = InStr(1,contents_of_file,"FW_TIMESTAMP_VALUE_2  = 16'h")
  if i > 0 then
    Original_YYMMDDHrMn = Original_YYMMDDHrMn & Mid(contents_of_file,I + 28, 4)
    rewrite = True 
    copy_of_contents = Mid(contents_of_file,1,I - 1) _
       & "FW_TIMESTAMP_VALUE_2  = 16'h" _
       & Right(yymmdd,2) & Left(hrmn,2) _
       & Mid(contents_of_file,I + 32)
    contents_of_file = copy_of_contents
  end if

  i = InStr(1,contents_of_file,"FW_TIMESTAMP_VALUE_3  = 16'h")
  if i > 0 then
    Original_YYMMDDHrMn = Original_YYMMDDHrMn & Mid(contents_of_file,I + 28, 2)
    rewrite = True 
    copy_of_contents = Mid(contents_of_file,1,I - 1) _
       & "FW_TIMESTAMP_VALUE_3  = 16'h" _
       & Right(hrmn,2) & "A5" _
       & Mid(contents_of_file,I + 32)
    contents_of_file = copy_of_contents
  end if

  ' - - - - - - - - - - - - - - - - - - - - - - - -
  ' Find Revision information and display it
  if rewrite = True then
    i = InStr(1,contents_of_file,"FW_REVISION_VALUE_1  = 16'h")
    j = InStr(1,contents_of_file,"FW_REVISION_VALUE_2  = 16'h")
    if (i > 0) And (j > 0) then
	  H2 = mid(contents_of_file, i + 27, 2) 
	  Rev1 = Number_From_2_Hex_Ascii_Char(H2)
 	  H2 = mid(contents_of_file, i + 29, 2) 
	  Rev2 = Number_From_2_Hex_Ascii_Char(H2)
	  H2 = mid(contents_of_file, j + 27, 2) 
	  Rev3 = Number_From_2_Hex_Ascii_Char(H2)
 	  H2 = mid(contents_of_file, j + 29, 2) 
	  FPGA = Number_From_2_Hex_Ascii_Char(H2)
	  'WScript.echo "Rev " & Rev1 & "." & Rev2 & "." & Rev3 & " FPGA" & FPGA
    end if
	
	If (Does_User_Want_to_Change_Revision(Rev1, Rev2, Rev3, FPGA)) Then
	
      i = InStr(1,contents_of_file,"FW_REVISION_VALUE_1  = 16'h")
      if i > 0 then
        copy_of_contents = Mid(contents_of_file,1,I - 1) _
           & "FW_REVISION_VALUE_1  = 16'h" _
           & Right("00" & Hex(Rev1) ,2) _
           & Right("00" & Hex(Rev2) ,2) _
           & Mid(contents_of_file,I + 31)
        contents_of_file = copy_of_contents
      end if
	
      i = InStr(1,contents_of_file,"FW_REVISION_VALUE_2  = 16'h")
      if i > 0 then
        copy_of_contents = Mid(contents_of_file,1,I - 1) _
           & "FW_REVISION_VALUE_2  = 16'h" _
           & Right("00" & Hex(Rev3) ,2) _
           & Right("00" & Hex(FPGA) ,2) _
           & Mid(contents_of_file,I + 31)
        contents_of_file = copy_of_contents
      end if
	
	  New_Rev_String = "Rev " & Rev1 & "." & Rev2 & "." & Rev3 & " F" & FPGA
	End If
  end if
   
  ' - - - - - - - - - - - - - - - - - - - - - - - -
  'Write it back out to the file
  if (rewrite) then
    Set f = fso.OpenTextFile(modify_this_Verilog_src_file, ForWriting, True)
    f.Write contents_of_file
    
	'format the timestamps pretty for showing the user
	Original_Timestamp = mid(Original_YYMMDDHrMn,3,2) _
	                    & "/" & mid(Original_YYMMDDHrMn,5,2) _
	                    & "/" & mid(Original_YYMMDDHrMn,1,2) _
	                    & " " & mid(Original_YYMMDDHrMn,7,2) _
	                    & ":" & mid(Original_YYMMDDHrMn,9,2)
	New_YYMMDDHrMn = yymmdd & hrmn
	New_Timestamp = mid(New_YYMMDDHrMn,3,2) _
	                    & "/" & mid(New_YYMMDDHrMn,5,2) _
	                    & "/" & mid(New_YYMMDDHrMn,1,2) _
	                    & " " & mid(New_YYMMDDHrMn,7,2) _
	                    & ":" & mid(New_YYMMDDHrMn,9,2)
	
	Wscript.echo "FPGA_Timestamp_TB3.vbs" & Chr(13) & Chr(10) _
	   & Chr(13) & Chr(10) _
	   & "Timestamped file:" & Chr(13) & Chr(10) _
	   & " " & modify_this_Verilog_src_file & Chr(13) & Chr(10) _
	   & Chr(13) & Chr(10) _
	   & "Original:" & Chr(13) & Chr(10) _
	   & " " & Original_Timestamp & " " & Original_Rev_String & Chr(13) & Chr(10)_
	   & Chr(13) & Chr(10) _
	   & "New:" & Chr(13) & Chr(10) _
       & " " & New_Timestamp & " " & New_Rev_String
    ' Following can be used to verify we are not adding or losing charcaters as
    '  we re-write the file
    'WScript.echo hex_from_char_in_string(Right(contents_of_file,20))
  end if
  
End Sub 
'- - - - - - - - - - - - - - -
'
Sub locate_all_timestamps_in_folder()
'
'Examine all files in the current folder -- the one containing this script file.
'For each file containing a firmware timestamp: "firmware_timestamp1 <= X""",
'  call insert-firmware-timestamp( ) to update the file with the current date & time.

  Dim Script_Folder
  Dim fso, f, fc, f1

  'start with the full path\file name of the script file
  Script_Folder = WScript.ScriptFullName
  Script_Folder = Mid(Script_Folder,1,InStrRev(Script_Folder,"\"))

  'Examine all .v (Verilog source)files in the folder
  Set fso = CreateObject("Scripting.FileSystemObject")
  Set f = fso.GetFolder(Script_Folder)
  Set fc = f.Files
  For Each f1 in fc
    if UCase(Right(f1.name,2)) = ".V" Then
      'Wscript.echo "VHDL file: " & f1.name
      call Insert_Firmware_Timestamp(script_folder & f1.name)
    End If
  Next

End Sub 
