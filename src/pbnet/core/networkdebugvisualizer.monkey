
Strict

Import pbnet

' Debug aid to visualize network traffic as it goes across the wire. It
' receives callbacks, and looks for a TextArea called netDebugTextArea on the
' root Application.application to display results in. This API is only used
' internally so is not heavily documented.
Class NetworkDebugVisualizer

	Field smEnabled:Bool = False
	'Field smSingleton:NetworkDebugVisualizer = Null

	' Get the Global instance of the visualizer.
	'Method GetSingleton:NetworkDebugVisualizer()

		' Don't create it unless we are enabling the visualizer.
	'	If smEnabled = False
	'		Return Null;
	'	End If

	'	If Not smSingleton
	'		smSingleton = New NetworkDebugVisualizer();
	'	End If

	'	Return smSingleton;

	'End Method
      
	'Field textDisplay:TextArea
	Field log:StringList = New StringList()

	Method NetworkDebugVisualizer:Void()

		' Find the debug text area.
		'If Application.application.hasOwnProperty("netDebugTextArea")
		'	Application.application.netDebugTextArea.htmlText = "";
		'End If

	End Method

	Method ReportTraffic:Void(outStr:String, data:Int[])
	
		Local column:Int = 0
	
		For Local i:Int = 0 Until data.Length
			'outStr += data[i] + ", "
			outStr += ToHex(data[i])
			column += 1
			If column >= 28 Then
				column = 0
				AddLog(outStr)
				outStr = "     "
			End If
		End For

		AddLog(outStr);

	End Method

	Method ReportOutgoingTraffic:Void(data:Int[])

		' Convert To a String.
		Local outStr:String = "Out] "
		ReportTraffic(outStr, data)

	End Method
      
	Method ReportIncomingTraffic:Void(data:Int[])

		If data[0] = 0 And data[1] = 1 Then
			Return
		End If

		If data[0] = 0 And data[1] = 0 Then
			Return
		End If

		' Convert To a String.
		Local outStr:String = "In]  "
		ReportTraffic(outStr, data)

	End Method

	Method AddLog:Void(s:String)
	
		log.AddLast(s)
		
		While log.Count() > 17
			log.RemoveFirst()
		End While

		'Print "Network Debug Visualizer: " + s

		' Update the log.
		'log.AddToLast(s);

		' Cap To last few entries.
		'While log.Count() > 25
		'	log.shift();
		'End While
         
		' Regenerate the text.
		'If(Application.application.hasOwnProperty("netDebugTextArea"))
		'	Application.application.netDebugTextArea.htmlText = "";
		'	For(var i:Int=log.length-1; i>=0; i--)
		'		Application.application.netDebugTextArea.htmlText += log[i];
		'	End For
		'End If

	End Method

	Method ToHex:String(i:Int)

		''p=32-bit
		Local r%=i, s%, p%=8, n:Int[p/4+1]
	
		While (p>0)
			
			s = (r&$f)+48
			If s>57 Then s+=7
			
			p-=4
			n[p Shr 2] = s
			r = r Shr 4
			 
		Wend
	
		Return String.FromChars(n)
		
	End Method

End Class
